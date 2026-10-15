extends Node3D
## Escena principal: muestra el menú de inicio, genera el bosque, mantiene vivo el
## ecosistema, traduce los controles en órdenes para el jugador y decide cuándo
## se gana o se pierde.

const ESCENA_ARBOL := preload("res://escenas/arbol.tscn")
const ESCENA_ARBUSTO := preload("res://escenas/arbusto.tscn")
const ESCENA_FRUTA := preload("res://escenas/fruta.tscn")
const ESCENA_PAJARO := preload("res://escenas/pajaro.tscn")
const ESCENA_CONEJO := preload("res://escenas/animales/conejo.tscn")
const ESCENA_ZORRO := preload("res://escenas/animales/zorro.tscn")
const ESCENA_CAZADOR := preload("res://escenas/animales/cazador.tscn")

const PRESAS_PARA_GANAR := 10
const DISTANCIA_RAYO := 1000.0
## Capa de física 1 (Proyecto > Configuración > Nombres de Capas): el terreno.
const MASCARA_CLICK := 1
## Si se hace click a menos de esta distancia de un animal, se lo elige como presa.
const RADIO_CLICK_PRESA := 1.6
## Convierte la sensibilidad del menú (1 a 10) en radianes por píxel de mouse.
const FACTOR_SENSIBILIDAD := 0.0006

const AYUDA_TERCERA := "Click derecho: caminar  ·  Click derecho sobre un animal: cazarlo y comerlo  ·  Shift: correr  ·  Rueda: zoom  ·  Esc: pausa"
const AYUDA_PRIMERA := "WASD: caminar  ·  Shift + W: correr  ·  Mouse: mirar  ·  Click izquierdo: zarpazo  ·  E: comer una presa abatida  ·  Esc: pausa"

@export_group("Selva")
## Árboles del dosel (palo rosa, timbó, lapacho): sus copas tapan el cielo.
@export var cantidad_arboles_grandes := 155
@export var cantidad_palmeras := 38
@export var cantidad_helechos_arborescentes := 70
## Plantas del sotobosque (tacuaras, helechos, caraguatás, arbustos): limitan la visión.
@export var cantidad_sotobosque := 1400
@export var cantidad_arboles_decorativos := 80
@export var cantidad_sotobosque_decorativo := 220

@export_group("Recorte de la maleza")
## Radio (en metros) alrededor del yaguareté donde el sotobosque no se dibuja.
@export var radio_maleza := 2.6
## En tercera persona: radio del círculo en pantalla (proporción del alto de la pantalla).
@export var radio_circulo_pantalla := 0.2

@export_group("Ecosistema")
## Frutas: alimento de los conejos (el yaguareté no las come).
@export var cantidad_frutas := 28
@export var poblacion_conejos := 24
@export var poblacion_zorros := 7
@export var cantidad_cazadores := 4
@export var cantidad_pajaros := 14

@export_group("Cámara")
## La cámara va por debajo del dosel (las copas empiezan a unos 10 m).
@export var offset_camara := Vector3(0, 6.5, 8)
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
@onready var contenedor_sotobosque: Node3D = $Sotobosque
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
	RenderingServer.global_shader_parameter_set("maleza_radio", radio_maleza)
	RenderingServer.global_shader_parameter_set("circulo_radio", 0.0)

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
	for i in cantidad_cazadores:
		_crear_animal(ESCENA_CAZADOR, 28.0)
	for i in cantidad_pajaros:
		_crear_pajaro()
	listo = true


func _process(delta: float) -> void:
	if not primera_persona:
		# La cámara de tercera persona sigue al jugador y siempre lo mira.
		var objetivo := jugador.global_position + offset_camara * zoom
		camara.global_position = camara.global_position.lerp(objetivo, suavizado_camara * delta)
		camara.look_at(jugador.global_position + Vector3.UP)
	_actualizar_recorte_maleza()

	if jugando and listo:
		tiempo_jugado += delta
		var cazador := _cazador_que_persigue()
		aviso.visible = cazador != null
		_actualizar_flecha(cazador)
		if primera_persona:
			aviso_comer.text = jugador.accion_disponible()
			aviso_comer.visible = aviso_comer.text != ""


func _unhandled_input(event: InputEvent) -> void:
	if not listo or not jugando or primera_persona:
		return
	# Controles de tercera persona.
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = clampf(zoom - 0.1, 0.5, 1.4)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = clampf(zoom + 0.1, 0.5, 1.4)
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
	# ¿Se hizo click sobre un animal (vivo o abatido)? Entonces es una presa.
	var presa := _presa_cerca_de(golpe.position, RADIO_CLICK_PRESA)
	if presa:
		jugador.ir_a_cazar(presa, correr)
		marcador.mostrar_en(presa.global_position)
	else:
		jugador.ir_a(golpe.position, correr)
		marcador.mostrar_en(golpe.position)


## Lanza un rayo desde la cámara pasando por el mouse y devuelve dónde toca el terreno.
func _raycast_desde_mouse() -> Dictionary:
	var mouse := get_viewport().get_mouse_position()
	var origen := camara.project_ray_origin(mouse)
	var fin := origen + camara.project_ray_normal(mouse) * DISTANCIA_RAYO
	var consulta := PhysicsRayQueryParameters3D.create(origen, fin, MASCARA_CLICK)
	return get_world_3d().direct_space_state.intersect_ray(consulta)


## La presa (viva o abatida) más cercana a un punto, dentro de un radio, o null.
func _presa_cerca_de(punto: Vector3, radio: float) -> Node3D:
	var mejor: Node3D = null
	var mejor_distancia := radio
	for nodo in get_tree().get_nodes_in_group("presas") + get_tree().get_nodes_in_group("presas_abatidas"):
		var presa := nodo as Node3D
		var distancia := Mundo.distancia_horizontal(presa.global_position, punto)
		if distancia <= mejor_distancia:
			mejor = presa
			mejor_distancia = distancia
	return mejor


# --- Creación del mundo ----------------------------------------------------------------

## Genera la selva por estratos, como en la selva paranaense: primero los árboles
## grandes del dosel, después el estrato medio (palmeras y helechos arborescentes) y
## por último el sotobosque. Los troncos son obstáculos para la navegación; el
## sotobosque no (el yaguareté lo atraviesa).
func _generar_bosque() -> void:
	var E := FabricaFlora.Especie
	var troncos: Array[Vector3] = []
	var limite := Mundo.MITAD_MAPA - 1.5
	_plantar(cantidad_arboles_grandes, [E.PALO_ROSA, E.PALO_ROSA, E.TIMBO, E.LAPACHO], 5.5, limite, troncos, contenedor_arboles)
	_plantar(cantidad_palmeras, [E.PINDO], 3.0, limite, troncos, contenedor_arboles)
	_plantar(cantidad_helechos_arborescentes, [E.CHACHI], 2.5, limite, troncos, contenedor_arboles)
	var plantas_bajas := [E.ARBUSTO, E.ARBUSTO, E.ARBUSTO, E.HELECHO, E.HELECHO, E.HELECHO, E.CARAGUATA, E.CARAGUATA, E.TACUARA]
	_plantar(cantidad_sotobosque, plantas_bajas, 1.0, limite, troncos, contenedor_sotobosque)

	# Selva decorativa fuera de los límites, para que el bosque no "termine" de golpe.
	var afuera: Array[Vector3] = []
	_plantar(cantidad_arboles_decorativos, [E.PALO_ROSA, E.TIMBO, E.LAPACHO, E.PINDO], 6.0, 85.0, afuera, contenedor_decorativos, Mundo.MITAD_MAPA + 4.0)
	_plantar(cantidad_sotobosque_decorativo, plantas_bajas, 1.5, 75.0, afuera, contenedor_sotobosque, Mundo.MITAD_MAPA + 3.0)


## Planta "cantidad" plantas al azar entre "desde" y "limite" del centro, sin que queden a
## menos de "separacion" metros de otras ya plantadas. El centro queda libre: ahí empieza el jugador.
func _plantar(cantidad: int, especies: Array, separacion: float, limite: float,
		ocupados: Array[Vector3], contenedor: Node3D, desde := 0.0) -> void:
	var plantadas := 0
	for intento in cantidad * 60:
		if plantadas >= cantidad:
			break
		var punto := Vector3(randf_range(-limite, limite), 0, randf_range(-limite, limite))
		if punto.length() < 5.0 or maxf(absf(punto.x), absf(punto.z)) < desde:
			continue
		if _muy_cerca(punto, ocupados, separacion):
			continue
		var especie: FabricaFlora.Especie = especies.pick_random()
		var sotobosque := FabricaFlora.es_sotobosque(especie)
		if not sotobosque:
			ocupados.append(punto)  # el sotobosque no ocupa lugar: puede crecer junto a otro
		var planta := (ESCENA_ARBUSTO if sotobosque else ESCENA_ARBOL).instantiate()
		planta.especie = especie
		planta.variante = randi() % FabricaFlora.VARIANTES
		planta.position = punto
		planta.rotation.y = randf() * TAU
		if sotobosque:
			planta.scale = Vector3.ONE * randf_range(0.8, 1.3)
			planta.set_instance_shader_parameter("tinte", Vector3.ONE * randf_range(0.8, 1.15))
		else:
			planta.get_node("Malla").set_instance_shader_parameter("tinte", Vector3.ONE * randf_range(0.85, 1.1))
		contenedor.add_child(planta)
		plantadas += 1


## Le pasa al shader de la vegetación dónde está el jugador, para que recorte la maleza.
func _actualizar_recorte_maleza() -> void:
	RenderingServer.global_shader_parameter_set("jugador_posicion", jugador.global_position)
	var camara_activa := get_viewport().get_camera_3d()
	if primera_persona or camara_activa == null:
		RenderingServer.global_shader_parameter_set("circulo_radio", 0.0)
		return
	var centro := jugador.global_position + Vector3.UP * 0.6
	var pantalla := get_viewport().get_visible_rect().size
	RenderingServer.global_shader_parameter_set("jugador_pantalla", camara_activa.unproject_position(centro) / pantalla)
	RenderingServer.global_shader_parameter_set("jugador_distancia_camara", camara_activa.global_position.distance_to(centro))
	RenderingServer.global_shader_parameter_set("circulo_radio", radio_circulo_pantalla)


## La navegación está lista cuando un punto lejano del centro ya tiene suelo caminable cerca.
func _navegacion_lista() -> bool:
	var mapa := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(mapa) == 0:
		return false
	var prueba := Vector3(20, 0, 20)
	return Mundo.distancia_horizontal(NavigationServer3D.map_get_closest_point(mapa, prueba), prueba) < 3.0


func _muy_cerca(punto: Vector3, otros: Array[Vector3], separacion: float) -> bool:
	for otro in otros:
		if punto.distance_to(otro) < separacion:
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


# --- Cazadores y flecha de aviso -----------------------------------------------------

## El cazador más cercano que está persiguiendo al jugador, o null.
func _cazador_que_persigue() -> Node3D:
	var mas_cercano: Node3D = null
	for nodo in get_tree().get_nodes_in_group("cazadores"):
		var cazador := nodo as Node3D
		if not cazador.call("persigue_al_jugador"):
			continue
		if mas_cercano == null or cazador.global_position.distance_to(jugador.global_position) \
				< mas_cercano.global_position.distance_to(jugador.global_position):
			mas_cercano = cazador
	return mas_cercano


## Si el cazador no está a la vista, una flecha en el borde de la pantalla indica de dónde viene.
func _actualizar_flecha(cazador: Node3D) -> void:
	var camara_activa := get_viewport().get_camera_3d()
	if cazador == null or camara_activa.is_position_in_frustum(cazador.global_position + Vector3.UP):
		flecha.visible = false
		return
	var hacia_cazador := cazador.global_position - jugador.global_position
	var frente := -camara_activa.global_transform.basis.z
	var derecha := camara_activa.global_transform.basis.x
	frente.y = 0.0
	derecha.y = 0.0
	# Ángulo del cazador respecto de "adelante en la pantalla": 0 = arriba, positivo = a la derecha.
	var angulo := atan2(hacia_cazador.dot(derecha.normalized()), hacia_cazador.dot(frente.normalized()))
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
	if total >= PRESAS_PARA_GANAR:
		_terminar(true, "Cazaste y comiste %d presas: sobreviviste a la selva." % total)


func _on_jugador_murio(motivo: String) -> void:
	if motivo == "capturado":
		_terminar(false, "Un cazador te atrapó.")
	else:
		_terminar(false, "Te moriste de hambre.")


func _on_boton_reintentar_pressed() -> void:
	Mundo.reiniciar(false)


func _on_boton_menu_pressed() -> void:
	Mundo.reiniciar(true)


func _actualizar_contador(total: int) -> void:
	contador.text = "Presas: %d / %d" % [total, PRESAS_PARA_GANAR]


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
