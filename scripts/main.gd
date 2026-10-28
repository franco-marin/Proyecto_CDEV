extends Node3D
## Escena principal: muestra el menú de inicio, genera el nivel (río, selva, animales,
## basura y trampas), mantiene vivo el ecosistema, traduce los controles en órdenes
## para el jugador y decide cuándo se gana o se pierde.

const ESCENA_ARBOL := preload("res://escenas/arbol.tscn")
const ESCENA_ARBUSTO := preload("res://escenas/arbusto.tscn")
const ESCENA_FRUTA := preload("res://escenas/fruta.tscn")
const ESCENA_PAJARO := preload("res://escenas/pajaro.tscn")
const ESCENA_TERMITERO := preload("res://escenas/termitero.tscn")
const ESCENA_BASURA := preload("res://escenas/basura.tscn")
const ESCENA_TRAMPA := preload("res://escenas/trampa.tscn")
const ESCENA_CAZADOR := preload("res://escenas/animales/cazador.tscn")
## Especies de la selva paranaense: escena y grupo (para contar cuántas quedan).
const ESPECIES := {
	"tapir": {"escena": preload("res://escenas/animales/tapir.tscn"), "grupo": "tapires"},
	"pecari": {"escena": preload("res://escenas/animales/pecari.tscn"), "grupo": "pecaries"},
	"corzuela": {"escena": preload("res://escenas/animales/corzuela.tscn"), "grupo": "corzuelas"},
	"carpincho": {"escena": preload("res://escenas/animales/carpincho.tscn"), "grupo": "carpinchos"},
	"oso_hormiguero": {"escena": preload("res://escenas/animales/oso_hormiguero.tscn"), "grupo": "osos_hormigueros"},
	"ocelote": {"escena": preload("res://escenas/animales/ocelote.tscn"), "grupo": "ocelotes"},
	"yacare": {"escena": preload("res://escenas/animales/yacare.tscn"), "grupo": "yacares"},
}

const DISTANCIA_RAYO := 1000.0
## Capa de física 1 (Proyecto > Configuración > Nombres de Capas): el terreno.
const MASCARA_CLICK := 1
## Si se hace click a menos de esta distancia de un animal, se lo elige como presa.
const RADIO_CLICK_PRESA := 1.6
## Convierte la sensibilidad del menú (1 a 10) en radianes por píxel de mouse.
const FACTOR_SENSIBILIDAD := 0.0006
## Segundos que se ve un aviso (por ejemplo, "¡Un yacaré te mordió!").
const SEGUNDOS_MENSAJE := 2.5

const AYUDA_TERCERA := "Click derecho: caminar  ·  Click derecho sobre un animal: cazarlo y comerlo  ·  Shift: correr  ·  Rueda: zoom  ·  Esc: pausa"
const AYUDA_PRIMERA := "WASD: caminar  ·  Shift + W: correr  ·  Mouse: mirar  ·  Click izquierdo: zarpazo  ·  E: comer una presa abatida  ·  Esc: pausa"

@export_group("Selva")
## Árboles del dosel (palo rosa, timbó, lapacho): sus copas tapan el cielo.
@export var cantidad_arboles_grandes := 155
@export var cantidad_palmeras := 38
@export var cantidad_helechos_arborescentes := 70
@export var cantidad_arboles_decorativos := 80
@export var cantidad_sotobosque_decorativo := 220

@export_group("Recorte de la maleza")
## Radio (en metros) alrededor del yaguareté donde el sotobosque no se dibuja.
@export var radio_maleza := 2.6
## En tercera persona: radio del círculo en pantalla (proporción del alto de la pantalla).
@export var radio_circulo_pantalla := 0.2

@export_group("Ecosistema")
@export var cantidad_pajaros := 14

@export_group("Cámara")
## La cámara va por debajo del dosel (las copas empiezan a unos 10 m).
@export var offset_camara := Vector3(0, 6.5, 8)
@export var suavizado_camara := 4.0

## Configuración del nivel que se está jugando (ver niveles.gd).
var nivel: Dictionary
var listo := false  # el bosque y la navegación ya están creados
var jugando := false  # la partida empezó (se eligió un modo) y no terminó
var terminado := false
var primera_persona := false
var tiempo_jugado := 0.0
var zoom := 1.0
var rio: Rio

var _mensaje := ""
var _segundos_mensaje := 0.0
var _proxima_manada := 0

@onready var camara: Camera3D = $Camara
@onready var sol: DirectionalLight3D = $Sol
@onready var entorno: WorldEnvironment = $WorldEnvironment
@onready var navegacion: NavigationRegion3D = $Navegacion
@onready var contenedor_arboles: Node3D = $Navegacion/Arboles
@onready var contenedor_decorativos: Node3D = $ArbolesDecorativos
@onready var contenedor_sotobosque: Node3D = $Sotobosque
@onready var contenedor_frutas: Node3D = $Frutas
@onready var contenedor_animales: Node3D = $Animales
@onready var contenedor_pajaros: Node3D = $Pajaros
@onready var contenedor_objetos: Node3D = $Objetos
@onready var jugador: CharacterBody3D = $Jugador
@onready var marcador: Node3D = $Marcador
@onready var barra_hambre: ProgressBar = $HUD/BarraHambre
@onready var contador: Label = $HUD/Contador
@onready var etiqueta_nivel: Label = $HUD/Nivel
@onready var etiqueta_estado: Label = $HUD/Estado
@onready var aviso: Label = $HUD/Aviso
@onready var ayuda: Label = $HUD/Ayuda
@onready var aviso_comer: Label = $HUD/Comer
@onready var mira: ColorRect = $HUD/Mira
@onready var flecha: Node2D = $HUD/Flecha
@onready var ojo: Control = $HUD/Ojo
@onready var menu_inicio: CanvasLayer = $MenuInicio
@onready var botones_nivel: HBoxContainer = $MenuInicio/Fondo/Centro/Caja/Niveles/Botones
@onready var deslizador_sensibilidad: HSlider = $MenuInicio/Fondo/Centro/Caja/Sensibilidad/Deslizador
@onready var valor_sensibilidad: Label = $MenuInicio/Fondo/Centro/Caja/Sensibilidad/Valor
@onready var menu_pausa: CanvasLayer = $MenuPausa
@onready var pantalla_final: CanvasLayer = $PantallaFinal
@onready var titulo_final: Label = $PantallaFinal/Fondo/Centro/Caja/Titulo
@onready var motivo_final: Label = $PantallaFinal/Fondo/Centro/Caja/Motivo
@onready var boton_siguiente: Button = $PantallaFinal/Fondo/Centro/Caja/BotonSiguiente


func _ready() -> void:
	nivel = Niveles.datos(Mundo.nivel)
	pantalla_final.visible = false
	aviso.visible = false
	aviso_comer.visible = false
	mira.visible = false
	flecha.visible = false
	ojo.visible = false
	etiqueta_estado.text = ""
	etiqueta_nivel.text = nivel.nombre
	marcador.ocultar()
	_actualizar_contador(0)
	_aplicar_ambiente()
	camara.global_position = jugador.global_position + offset_camara
	camara.look_at(jugador.global_position)
	RenderingServer.global_shader_parameter_set("maleza_radio", radio_maleza)
	RenderingServer.global_shader_parameter_set("circulo_radio", 0.0)

	# Menú de inicio: el juego queda en pausa hasta elegir un modo. Al "Reintentar" o
	# pasar de nivel no se muestra y se usa el modo elegido antes (guardado en Mundo).
	deslizador_sensibilidad.value = Mundo.sensibilidad
	valor_sensibilidad.text = str(Mundo.sensibilidad)
	_preparar_botones_de_nivel()
	if Mundo.mostrar_menu:
		menu_inicio.visible = true
		get_tree().paused = true
	else:
		menu_inicio.visible = false
		_empezar_partida(Mundo.modo)

	# 1) El río y la selva. 2) Calcular por dónde se puede caminar ("hornear" la
	# navegación). Hay que esperar a que termine antes de soltar a los animales.
	_crear_rio()
	_decorar_orillas()
	_generar_bosque()
	navegacion.bake_navigation_mesh(true)
	await navegacion.bake_finished
	# El servidor de navegación aplica la malla nueva unos frames después: esperamos a que responda.
	while not _navegacion_lista():
		await get_tree().physics_frame

	_poblar_nivel()
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
		_actualizar_estado(delta)
		# Ojo cerrado: está escondido en la maleza y cuesta verlo.
		ojo.cerrado = jugador.oculto
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
	ojo.visible = true

	jugando = true
	menu_pausa.habilitado = true
	get_tree().paused = false


## Botones "Nivel 1/2/3" del menú: solo se pueden elegir los niveles desbloqueados.
func _preparar_botones_de_nivel() -> void:
	for i in botones_nivel.get_child_count():
		var boton := botones_nivel.get_child(i) as Button
		var numero := i + 1
		boton.disabled = numero > Mundo.nivel_desbloqueado
		boton.button_pressed = numero == Mundo.nivel
		boton.pressed.connect(_elegir_nivel.bind(numero))


## Elegir otro nivel en el menú vuelve a generar el mundo con esa configuración.
func _elegir_nivel(numero: int) -> void:
	if numero != Mundo.nivel:
		Mundo.nivel = numero
		Mundo.reiniciar(true)


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

## Color de la niebla y fuerza de la luz según el nivel (más gris en la selva degradada).
func _aplicar_ambiente() -> void:
	var ambiente := entorno.environment.duplicate() as Environment
	ambiente.fog_light_color = nivel.niebla
	entorno.environment = ambiente
	sol.light_energy = nivel.luz


func _crear_rio() -> void:
	rio = Rio.new()
	rio.name = "Rio"
	add_child(rio)
	rio.generar(Mundo.MITAD_MAPA, nivel.rio_color, nivel.rio_turbidez, nivel.rio_espuma, nivel.botellas_en_rio)
	Mundo.rio = rio


## Pasto y piedras a lo largo de las orillas (algunas piedras quedan dentro del agua).
## Son decoración: no tienen colisión ni esconden al yaguareté. Como son cientos, se
## dibujan con MultiMesh: una sola instancia dibuja todas las copias de una malla.
func _decorar_orillas() -> void:
	var E := FabricaFlora.Especie
	var pastos := {}  # variante -> lista de Transform3D
	var piedras := {}
	for i in rio.puntos.size():
		var centro: Vector3 = rio.puntos[i]
		if absf(centro.x) > Mundo.MITAD_MAPA + 20.0 or absf(centro.z) > Mundo.MITAD_MAPA + 20.0:
			continue
		var normal := rio.normal_en(i)
		var a_lo_largo := rio.direccion_en(i)
		var medio: float = rio.anchos[i] / 2.0
		for lado in [-1.0, 1.0]:
			for k in randi_range(2, 4):
				var punto: Vector3 = centro + normal * lado * (medio + randf_range(-0.2, 3.5)) \
					+ a_lo_largo * randf_range(-1.0, 1.0)
				_agregar_copia(pastos, punto, randf_range(0.8, 1.4))
			if randf() < 0.35:
				var punto: Vector3 = centro + normal * lado * (medio + randf_range(-1.5, 1.2))
				_agregar_copia(piedras, punto, randf_range(0.7, 1.6))
	for variante in pastos:
		_multimalla(FabricaFlora.planta(E.PASTO, variante).malla, pastos[variante], false)
	for variante in piedras:
		_multimalla(FabricaFlora.planta(E.PIEDRA, variante).malla, piedras[variante], true)


## Agrega una copia (en una variante al azar) con un giro y un tamaño al azar.
func _agregar_copia(copias: Dictionary, punto: Vector3, escala: float) -> void:
	var variante := randi() % FabricaFlora.VARIANTES
	if not copias.has(variante):
		copias[variante] = []
	copias[variante].append(Transform3D(Basis(Vector3.UP, randf() * TAU).scaled(Vector3.ONE * escala), punto))


func _multimalla(malla: Mesh, transformaciones: Array, con_sombra: bool) -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = malla
	multi.instance_count = transformaciones.size()
	for i in transformaciones.size():
		multi.set_instance_transform(i, transformaciones[i])
	var instancia := MultiMeshInstance3D.new()
	instancia.multimesh = multi
	instancia.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if con_sombra \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rio.add_child(instancia)


## Genera la selva por estratos, como en la selva paranaense: primero los árboles
## grandes del dosel, después el estrato medio (palmeras y helechos arborescentes) y
## por último el sotobosque. Los troncos son obstáculos para la navegación; el
## sotobosque no (el yaguareté lo atraviesa). Nada crece dentro del río.
func _generar_bosque() -> void:
	var E := FabricaFlora.Especie
	var troncos: Array[Vector3] = []
	var limite := Mundo.MITAD_MAPA - 1.5
	Mundo.limpiar_cobertura()
	_plantar(cantidad_arboles_grandes, [E.PALO_ROSA, E.PALO_ROSA, E.TIMBO, E.LAPACHO], 5.5, limite, troncos, contenedor_arboles)
	_plantar(cantidad_palmeras, [E.PINDO], 3.0, limite, troncos, contenedor_arboles)
	_plantar(cantidad_helechos_arborescentes, [E.CHACHI], 2.5, limite, troncos, contenedor_arboles)
	var plantas_bajas := [E.ARBUSTO, E.ARBUSTO, E.ARBUSTO, E.HELECHO, E.HELECHO, E.HELECHO, E.CARAGUATA, E.CARAGUATA, E.TACUARA]
	_plantar(nivel.sotobosque, plantas_bajas, 1.0, limite, troncos, contenedor_sotobosque)

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
		var especie: FabricaFlora.Especie = especies.pick_random()
		var sotobosque := FabricaFlora.es_sotobosque(especie)
		# Los árboles quedan lejos del agua; el sotobosque puede crecer en la orilla.
		if rio.en_agua(punto, 0.3 if sotobosque else 2.5):
			continue
		if _muy_cerca(punto, ocupados, separacion):
			continue
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
			Mundo.registrar_cobertura(punto)  # sirve para esconderse
		else:
			planta.get_node("Malla").set_instance_shader_parameter("tinte", Vector3.ONE * randf_range(0.85, 1.1))
		contenedor.add_child(planta)
		plantadas += 1


## Pone frutas, termiteros, basura, trampas, animales, cazadores y pájaros según el nivel.
func _poblar_nivel() -> void:
	for i in nivel.frutas:
		_crear_fruta()
	for i in nivel.termiteros:
		_crear_objeto(ESCENA_TERMITERO, 8.0)
	for i in nivel.basura:
		_crear_objeto(ESCENA_BASURA, 6.0)
	for i in nivel.trampas:
		_crear_objeto(ESCENA_TRAMPA, 10.0)
	for especie in nivel.animales:
		if especie == "pecari":
			# Los pecaríes andan en manadas.
			var restantes: int = nivel.animales.pecari
			while restantes > 0:
				var tamano := mini(restantes, nivel.tamano_manada)
				_crear_manada(tamano)
				restantes -= tamano
		else:
			for i in nivel.animales[especie]:
				_crear_animal(especie)
	for i in nivel.cazadores:
		_crear_en(ESCENA_CAZADOR, Mundo.punto_aleatorio_lejos_de(jugador.global_position, 30.0))
	for i in cantidad_pajaros:
		_crear_pajaro()


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


func _crear_objeto(escena: PackedScene, distancia_minima_al_jugador: float) -> void:
	var objeto := escena.instantiate()
	contenedor_objetos.add_child(objeto)
	objeto.global_position = Mundo.punto_aleatorio_lejos_de(jugador.global_position, distancia_minima_al_jugador)
	objeto.rotation.y = randf() * TAU


## Crea un animal de la especie dada lejos del jugador. Carpinchos y yacarés aparecen en la orilla.
func _crear_animal(especie: String) -> Node3D:
	var punto: Vector3
	if especie in ["carpincho", "yacare"]:
		punto = rio.punto_en_orilla(Mundo.MITAD_MAPA)
		for intento in 10:
			if Mundo.distancia_horizontal(punto, jugador.global_position) > 15.0:
				break
			punto = rio.punto_en_orilla(Mundo.MITAD_MAPA)
	else:
		punto = Mundo.punto_aleatorio_lejos_de(jugador.global_position, 15.0)
	return _crear_en(ESPECIES[especie].escena, punto)


func _crear_manada(tamano: int, centro := Vector3.INF) -> void:
	if centro == Vector3.INF:
		centro = Mundo.punto_aleatorio_lejos_de(jugador.global_position, 20.0)
	var numero := _proxima_manada
	_proxima_manada += 1
	for i in tamano:
		var punto := Mundo.punto_navegable(centro + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)))
		var pecari := ESPECIES.pecari.escena.instantiate()
		pecari.manada = numero
		contenedor_animales.add_child(pecari)
		pecari.global_position = punto + Vector3.UP * 0.2


func _crear_en(escena: PackedScene, punto: Vector3) -> Node3D:
	var animal := escena.instantiate()
	contenedor_animales.add_child(animal)
	animal.global_position = punto + Vector3.UP * 0.2
	return animal


func _crear_pajaro() -> void:
	var pajaro := ESCENA_PAJARO.instantiate()
	contenedor_pajaros.add_child(pajaro)
	pajaro.global_position = get_tree().get_nodes_in_group("arboles").pick_random().punto_posado()


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


# --- HUD ----------------------------------------------------------------------------

## Debajo del contador: lo que le pasa al yaguareté (oculto, nadando, trampa, basura)
## y los avisos momentáneos (mordidas, trampas).
func _actualizar_estado(delta: float) -> void:
	var lineas: Array[String] = []
	if _segundos_mensaje > 0.0:
		_segundos_mensaje -= delta
		lineas.append(_mensaje)
	lineas.append_array(jugador.estados_activos())
	etiqueta_estado.text = "\n".join(lineas)


func _on_jugador_mensaje(texto: String) -> void:
	_mensaje = texto
	_segundos_mensaje = SEGUNDOS_MENSAJE


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


## Cada pocos segundos repone animales para que el ecosistema no se extinga.
func _on_timer_ecosistema_timeout() -> void:
	if not listo:
		return
	for especie in nivel.animales:
		var cuantos := get_tree().get_nodes_in_group(ESPECIES[especie].grupo).size()
		if cuantos >= nivel.animales[especie]:
			continue
		if especie == "pecari":
			_crear_manada(mini(nivel.tamano_manada, nivel.animales.pecari - cuantos))
		else:
			_crear_animal(especie)
		return  # de a un animal (o una manada) por vez


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
	if total >= nivel.presas_para_ganar:
		if Mundo.nivel < Niveles.CANTIDAD:
			_terminar(true, "Comiste %d presas: superaste el nivel." % total)
		else:
			_terminar(true, "Sobreviviste a los tres niveles de la selva.")


func _on_jugador_murio(motivo: String) -> void:
	if motivo == "capturado":
		_terminar(false, "Un cazador te atrapó.")
	else:
		_terminar(false, "Te moriste de hambre.")


func _on_boton_reintentar_pressed() -> void:
	Mundo.reiniciar(false)


func _on_boton_siguiente_pressed() -> void:
	Mundo.avanzar_nivel()
	Mundo.reiniciar(false)


func _on_boton_menu_pressed() -> void:
	Mundo.reiniciar(true)


func _actualizar_contador(total: int) -> void:
	contador.text = "Presas: %d / %d" % [total, nivel.presas_para_ganar]


func _terminar(gano: bool, texto: String) -> void:
	if terminado:
		return
	terminado = true
	jugando = false
	menu_pausa.habilitado = false
	aviso.visible = false
	aviso_comer.visible = false
	flecha.visible = false
	var hay_siguiente := gano and Mundo.nivel < Niveles.CANTIDAD
	if gano:
		Mundo.nivel_desbloqueado = maxi(Mundo.nivel_desbloqueado, mini(Mundo.nivel + 1, Niveles.CANTIDAD))
	if not gano:
		titulo_final.text = "Perdiste"
	elif hay_siguiente:
		titulo_final.text = "¡Nivel superado!"
	else:
		titulo_final.text = "¡Ganaste!"
	motivo_final.text = "%s\nTiempo: %d segundos" % [texto, int(tiempo_jugado)]
	boton_siguiente.visible = hay_siguiente
	pantalla_final.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Pausa todo el juego. La pantalla final sigue funcionando porque su
	# "Process > Mode" es "Always".
	get_tree().paused = true
