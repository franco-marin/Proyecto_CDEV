extends Node3D
## Escena principal: muestra el menú de inicio, genera el bosque, mantiene vivo el
## ecosistema, traduce los controles en órdenes para el jugador y decide cuándo
## se gana o se pierde.

const ESCENA_ARBOL := preload("res://escenas/arbol.tscn")
const ESCENA_FRUTA := preload("res://escenas/fruta.tscn")
const ESCENA_PAJARO := preload("res://escenas/pajaro.tscn")
const ESCENA_CONEJO := preload("res://escenas/animales/conejo.tscn")
const ESCENA_ZORRO := preload("res://escenas/animales/zorro.tscn")
const ESCENA_OSO := preload("res://escenas/animales/oso.tscn")

const FRUTAS_PARA_GANAR := 10
const DISTANCIA_RAYO := 1000.0
## Capas de física (Proyecto > Configuración > Nombres de Capas): 1 = terreno, 5 = comida.
const MASCARA_CLICK := 1 | 16
## Convierte la sensibilidad del menú (1 a 10) en radianes por píxel de mouse.
const FACTOR_SENSIBILIDAD := 0.0006

const AYUDA_TERCERA := "Click derecho: caminar  ·  Shift + click derecho: correr  ·  Click sobre un arbusto: comer  ·  Rueda: zoom  ·  Esc: pausa"
const AYUDA_PRIMERA := "WASD: caminar  ·  Shift + W: correr  ·  Mouse: mirar  ·  E: comer (cerca y mirando el arbusto)  ·  Esc: pausa"

@export_group("Bosque")
@export var cantidad_arboles := 55
@export var cantidad_arboles_decorativos := 70
@export var separacion_arboles := 3.5

@export_group("Ecosistema")
@export var cantidad_frutas := 12
@export var poblacion_conejos := 10
@export var poblacion_zorros := 3
@export var cantidad_osos := 3
@export var cantidad_pajaros := 8

@export_group("Cámara")
@export var offset_camara := Vector3(0, 13, 11)
@export var suavizado_camara := 4.0

var listo := false  # el bosque y la navegación ya están creados
var jugando := false  # la partida empezó (se eligió un modo) y no terminó
var terminado := false
var primera_persona := false
var tiempo_jugado := 0.0
var zoom := 1.0

@onready var camara: Camera3D = $Camara
@onready var navegacion: NavigationRegion3D = $Navegacion
@onready var contenedor_arboles: Node3D = $Navegacion/Arboles
@onready var contenedor_decorativos: Node3D = $ArbolesDecorativos
@onready var contenedor_frutas: Node3D = $Frutas
@onready var contenedor_animales: Node3D = $Animales
@onready var contenedor_pajaros: Node3D = $Pajaros
@onready var jugador: CharacterBody3D = $Jugador
@onready var marcador: Node3D = $Marcador
@onready var barra_hambre: ProgressBar = $HUD/BarraHambre
@onready var contador: Label = $HUD/Contador
@onready var aviso: Label = $HUD/Aviso
@onready var ayuda: Label = $HUD/Ayuda
@onready var aviso_comer: Label = $HUD/Comer
@onready var mira: ColorRect = $HUD/Mira
@onready var flecha: Node2D = $HUD/Flecha
@onready var menu_inicio: CanvasLayer = $MenuInicio
@onready var deslizador_sensibilidad: HSlider = $MenuInicio/Fondo/Centro/Caja/Sensibilidad/Deslizador
@onready var valor_sensibilidad: Label = $MenuInicio/Fondo/Centro/Caja/Sensibilidad/Valor
@onready var menu_pausa: CanvasLayer = $MenuPausa
@onready var pantalla_final: CanvasLayer = $PantallaFinal
@onready var titulo_final: Label = $PantallaFinal/Fondo/Centro/Caja/Titulo
@onready var motivo_final: Label = $PantallaFinal/Fondo/Centro/Caja/Motivo


func _ready() -> void:
	pantalla_final.visible = false
	aviso.visible = false
	aviso_comer.visible = false
	mira.visible = false
	flecha.visible = false
	marcador.ocultar()
	_actualizar_contador(0)
	camara.global_position = jugador.global_position + offset_camara
	camara.look_at(jugador.global_position)

	# Menú de inicio: el juego queda en pausa hasta elegir un modo. Al "Reintentar"
	# no se muestra y se usa el modo elegido la vez anterior (guardado en Mundo).
	deslizador_sensibilidad.value = Mundo.sensibilidad
	valor_sensibilidad.text = str(Mundo.sensibilidad)
	if Mundo.mostrar_menu:
		menu_inicio.visible = true
		get_tree().paused = true
	else:
		menu_inicio.visible = false
		_empezar_partida(Mundo.modo)

	# 1) Plantar los árboles. 2) Calcular por dónde se puede caminar ("hornear" la
	# navegación). Hay que esperar a que termine antes de soltar a los animales.
	_generar_bosque()
	navegacion.bake_navigation_mesh(true)
	await navegacion.bake_finished
	# El servidor de navegación aplica la malla nueva unos frames después: esperamos a que responda.
	while not _navegacion_lista():
		await get_tree().physics_frame

	for i in cantidad_frutas:
		_crear_fruta()
	for i in poblacion_conejos:
		_crear_animal(ESCENA_CONEJO, 10.0)
	for i in poblacion_zorros:
		_crear_animal(ESCENA_ZORRO, 15.0)
	for i in cantidad_osos:
		_crear_animal(ESCENA_OSO, 28.0)
	for i in cantidad_pajaros:
		_crear_pajaro()
	listo = true


func _process(delta: float) -> void:
	if not primera_persona:
		# La cámara de tercera persona sigue al jugador y siempre lo mira.
		var objetivo := jugador.global_position + offset_camara * zoom
		camara.global_position = camara.global_position.lerp(objetivo, suavizado_camara * delta)
		camara.look_at(jugador.global_position + Vector3.UP)

	if jugando and listo:
		tiempo_jugado += delta
		var oso := _oso_que_persigue()
		aviso.visible = oso != null
		_actualizar_flecha(oso)
		if primera_persona:
			aviso_comer.visible = jugador.fruta_al_alcance() != null


func _unhandled_input(event: InputEvent) -> void:
	if not listo or not jugando or primera_persona:
		return
	# Controles de tercera persona.
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = clampf(zoom - 0.1, 0.5, 1.6)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = clampf(zoom + 0.1, 0.5, 1.6)
	if event.is_action_pressed("mover_animal"):
		_ordenar_movimiento(Input.is_action_pressed("correr"))


# --- Inicio de partida ------------------------------------------------------------

func _empezar_partida(modo: int) -> void:
	Mundo.modo = modo
	Mundo.mostrar_menu = false
	primera_persona = modo == Mundo.ModoCamara.PRIMERA_PERSONA
	menu_inicio.visible = false

	jugador.configurar_primera_persona(primera_persona, Mundo.sensibilidad * FACTOR_SENSIBILIDAD)
	if primera_persona:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED  # cursor oculto y atrapado en la ventana
		ayuda.text = AYUDA_PRIMERA
	else:
		camara.current = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		ayuda.text = AYUDA_TERCERA
	mira.visible = primera_persona

	jugando = true
	menu_pausa.habilitado = true
	get_tree().paused = false


func _on_boton_tercera_pressed() -> void:
	_empezar_partida(Mundo.ModoCamara.TERCERA_PERSONA)


func _on_boton_primera_pressed() -> void:
	_empezar_partida(Mundo.ModoCamara.PRIMERA_PERSONA)


func _on_sensibilidad_value_changed(valor: float) -> void:
	Mundo.sensibilidad = valor
	valor_sensibilidad.text = str(valor)


func _on_menu_pausa_reanudado() -> void:
	if primera_persona:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# --- Órdenes al jugador en tercera persona ------------------------------------------

func _ordenar_movimiento(correr: bool) -> void:
	var golpe := _raycast_desde_mouse()
	if golpe.is_empty():
		return
	# ¿Se hizo click sobre una fruta (o muy cerca de una)?
	var fruta = golpe.collider if golpe.collider.is_in_group("comida") else _fruta_cerca_de(golpe.position, 1.2)
	if fruta:
		jugador.ir_a_comer(fruta, correr)
		marcador.mostrar_en(fruta.global_position)
	else:
		jugador.ir_a(golpe.position, correr)
		marcador.mostrar_en(golpe.position)


## Lanza un rayo desde la cámara pasando por el mouse. Choca con el terreno y con la fruta.
func _raycast_desde_mouse() -> Dictionary:
	var mouse := get_viewport().get_mouse_position()
	var origen := camara.project_ray_origin(mouse)
	var fin := origen + camara.project_ray_normal(mouse) * DISTANCIA_RAYO
	var consulta := PhysicsRayQueryParameters3D.create(origen, fin, MASCARA_CLICK)
	consulta.collide_with_areas = true  # las frutas son Area3D
	return get_world_3d().direct_space_state.intersect_ray(consulta)


func _fruta_cerca_de(punto: Vector3, radio: float) -> Node3D:
	for nodo in get_tree().get_nodes_in_group("comida"):
		var fruta := nodo as Node3D
		if Mundo.distancia_horizontal(fruta.global_position, punto) <= radio:
			return fruta
	return null


# --- Creación del mundo ----------------------------------------------------------------

func _generar_bosque() -> void:
	# Árboles dentro del área jugable (son obstáculos para la navegación).
	var posiciones: Array[Vector3] = []
	var limite := Mundo.MITAD_MAPA - 2.0
	for intento in 3000:
		if posiciones.size() >= cantidad_arboles:
			break
		var punto := Vector3(randf_range(-limite, limite), 0, randf_range(-limite, limite))
		if punto.length() < 6.0 or _muy_cerca(punto, posiciones):
			continue  # el centro queda libre: ahí empieza el jugador
		posiciones.append(punto)
		var arbol := ESCENA_ARBOL.instantiate()
		arbol.position = punto
		contenedor_arboles.add_child(arbol)

	# Árboles decorativos fuera de los límites, para que el bosque no "termine" de golpe.
	var colocados := 0
	while colocados < cantidad_arboles_decorativos:
		var punto := Vector3(randf_range(-75, 75), 0, randf_range(-75, 75))
		if maxf(absf(punto.x), absf(punto.z)) < Mundo.MITAD_MAPA + 5.0:
			continue
		var arbol := ESCENA_ARBOL.instantiate()
		arbol.position = punto
		contenedor_decorativos.add_child(arbol)
		colocados += 1


## La navegación está lista cuando un punto lejano del centro ya tiene suelo caminable cerca.
func _navegacion_lista() -> bool:
	var mapa := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(mapa) == 0:
		return false
	var prueba := Vector3(20, 0, 20)
	return Mundo.distancia_horizontal(NavigationServer3D.map_get_closest_point(mapa, prueba), prueba) < 3.0


func _muy_cerca(punto: Vector3, otros: Array[Vector3]) -> bool:
	for otro in otros:
		if punto.distance_to(otro) < separacion_arboles:
			return true
	return false


func _crear_fruta() -> void:
	var fruta := ESCENA_FRUTA.instantiate()
	contenedor_frutas.add_child(fruta)
	fruta.global_position = Mundo.punto_aleatorio_lejos_de(jugador.global_position, 4.0)
	# Conexión de señal hecha por código (la alternativa a conectarla en el editor).
	fruta.consumida.connect(_on_fruta_consumida)


func _crear_animal(escena: PackedScene, distancia_minima_al_jugador: float) -> void:
	var animal := escena.instantiate()
	contenedor_animales.add_child(animal)
	animal.global_position = Mundo.punto_aleatorio_lejos_de(jugador.global_position, distancia_minima_al_jugador) \
		+ Vector3.UP * 0.2


func _crear_pajaro() -> void:
	var pajaro := ESCENA_PAJARO.instantiate()
	contenedor_pajaros.add_child(pajaro)
	pajaro.global_position = get_tree().get_nodes_in_group("arboles").pick_random().punto_posado()


# --- Osos y flecha de aviso ----------------------------------------------------------

## El oso más cercano que está persiguiendo al jugador, o null.
func _oso_que_persigue() -> Node3D:
	var mas_cercano: Node3D = null
	for nodo in get_tree().get_nodes_in_group("carnivoros_grandes"):
		var oso := nodo as Node3D
		if not oso.call("persigue_al_jugador"):
			continue
		if mas_cercano == null or oso.global_position.distance_to(jugador.global_position) \
				< mas_cercano.global_position.distance_to(jugador.global_position):
			mas_cercano = oso
	return mas_cercano


## Si el oso no está a la vista, una flecha en el borde de la pantalla indica de dónde viene.
func _actualizar_flecha(oso: Node3D) -> void:
	var camara_activa := get_viewport().get_camera_3d()
	if oso == null or camara_activa.is_position_in_frustum(oso.global_position + Vector3.UP):
		flecha.visible = false
		return
	var hacia_oso := oso.global_position - jugador.global_position
	var frente := -camara_activa.global_transform.basis.z
	var derecha := camara_activa.global_transform.basis.x
	frente.y = 0.0
	derecha.y = 0.0
	# Ángulo del oso respecto de "adelante en la pantalla": 0 = arriba, positivo = a la derecha.
	var angulo := atan2(hacia_oso.dot(derecha.normalized()), hacia_oso.dot(frente.normalized()))
	var centro := get_viewport().get_visible_rect().size / 2.0
	flecha.position = centro + Vector2(sin(angulo) * centro.x, -cos(angulo) * centro.y) * 0.82
	flecha.rotation = angulo
	flecha.visible = true


# --- Señales -----------------------------------------------------------------------------

func _on_fruta_consumida(_fruta: Node3D) -> void:
	# Cuando alguien come una fruta, aparece otra en un lugar al azar.
	await get_tree().create_timer(2.0).timeout
	_crear_fruta()


## Cada pocos segundos repone animales pequeños para que el ecosistema no se extinga.
func _on_timer_ecosistema_timeout() -> void:
	if not listo:
		return
	if get_tree().get_nodes_in_group("herbivoros_pequenos").size() < poblacion_conejos:
		_crear_animal(ESCENA_CONEJO, 20.0)
	if get_tree().get_nodes_in_group("carnivoros_pequenos").size() < poblacion_zorros:
		_crear_animal(ESCENA_ZORRO, 20.0)


func _on_jugador_hambre_cambio(valor: float, maximo: float) -> void:
	barra_hambre.max_value = maximo
	barra_hambre.value = valor
	var proporcion := valor / maximo
	var relleno := barra_hambre.get_theme_stylebox("fill") as StyleBoxFlat
	if proporcion > 0.5:
		relleno.bg_color = Color(0.35, 0.8, 0.3)
	elif proporcion > 0.25:
		relleno.bg_color = Color(0.95, 0.75, 0.2)
	else:
		relleno.bg_color = Color(0.9, 0.25, 0.2)


func _on_jugador_llego_al_destino() -> void:
	marcador.ocultar()


func _on_jugador_comio(total: int) -> void:
	_actualizar_contador(total)
	if total >= FRUTAS_PARA_GANAR:
		_terminar(true, "Comiste %d frutas y sobreviviste al bosque." % total)


func _on_jugador_murio(motivo: String) -> void:
	if motivo == "devorado":
		_terminar(false, "Un oso te alcanzó.")
	else:
		_terminar(false, "Te moriste de hambre.")


func _on_boton_reintentar_pressed() -> void:
	Mundo.reiniciar(false)


func _on_boton_menu_pressed() -> void:
	Mundo.reiniciar(true)


func _actualizar_contador(total: int) -> void:
	contador.text = "Comida: %d / %d" % [total, FRUTAS_PARA_GANAR]


func _terminar(gano: bool, texto: String) -> void:
	if terminado:
		return
	terminado = true
	jugando = false
	menu_pausa.habilitado = false
	aviso.visible = false
	aviso_comer.visible = false
	flecha.visible = false
	titulo_final.text = "¡Ganaste!" if gano else "Perdiste"
	motivo_final.text = "%s\nTiempo: %d segundos" % [texto, int(tiempo_jugado)]
	pantalla_final.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Pausa todo el juego. La pantalla final sigue funcionando porque su
	# "Process > Mode" es "Always".
	get_tree().paused = true
