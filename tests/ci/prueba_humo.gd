extends SceneTree
## Pipeline, paso 3: prueba de humo. Arranca el juego en cada modo de cámara,
## simula unos segundos de partida (moverse, correr, comer) y comprueba que todo
## funcione. Termina con código 1 si algo falla.
## Uso: godot --headless --path . --fixed-fps 60 -s res://tests/ci/prueba_humo.gd

const TERCERA_PERSONA := 0
const PRIMERA_PERSONA := 1
const MAXIMO_FRAMES_ESPERANDO_MUNDO := 1800

# Sin tipo a propósito: se usan propiedades y funciones propias de sus scripts.
var mundo
var main
var jugador
var modo := TERCERA_PERSONA
var frames := 0
var t := -1  # frames desde que el mundo quedó listo
var inicio := Vector3.ZERO
var fallos: Array[String] = []


func _initialize() -> void:
	mundo = root.get_node("Mundo")
	_iniciar_modo()


func _process(_delta: float) -> bool:
	frames += 1
	if t < 0:
		_esperar_mundo()
		return false
	t += 1
	if main.terminado:
		print("  AVISO  la partida terminó antes de tiempo (%s); se pasa al siguiente modo" % main.motivo_final.text)
		_siguiente_modo()
	elif modo == TERCERA_PERSONA:
		_guion_tercera_persona()
	else:
		_guion_primera_persona()
	return false


func _iniciar_modo() -> void:
	paused = false
	mundo.mostrar_menu = false
	mundo.modo = modo
	main = load("res://escenas/main.tscn").instantiate()
	root.add_child(main)
	jugador = main.get_node("Jugador")
	frames = 0
	t = -1
	print("== Modo: %s ==" % ("tercera persona" if modo == TERCERA_PERSONA else "primera persona"))


func _esperar_mundo() -> void:
	if main.listo:
		t = 0
		inicio = jugador.global_position
		_verificar_mundo()
	elif frames > MAXIMO_FRAMES_ESPERANDO_MUNDO:
		_comprobar(false, "el bosque y la navegación no terminaron de generarse")
		_siguiente_modo()


func _verificar_mundo() -> void:
	_comprobar(main.get_node("Navegacion/Arboles").get_child_count() > 20, "se generaron los árboles")
	_comprobar(get_nodes_in_group("comida").size() > 0, "hay frutas")
	_comprobar(get_nodes_in_group("herbivoros_pequenos").size() > 0, "hay conejos")
	_comprobar(get_nodes_in_group("carnivoros_pequenos").size() > 0, "hay zorros")
	_comprobar(get_nodes_in_group("carnivoros_grandes").size() > 0, "hay osos")
	_comprobar(main.get_node("Pajaros").get_child_count() > 0, "hay pájaros")
	var oso_cerca := false
	for oso in get_nodes_in_group("carnivoros_grandes"):
		if _distancia(oso.global_position, jugador.global_position) < 20.0:
			oso_cerca = true
	_comprobar(not oso_cerca, "ningún oso aparece encima del jugador")
	# Esta prueba revisa los controles: los osos no ven al jugador para que el
	# resultado no dependa del azar (que uno se cruce en el camino).
	for oso in get_nodes_in_group("carnivoros_grandes"):
		oso.vision_jugador = 0.0


func _guion_tercera_persona() -> void:
	match t:
		1:
			jugador.ir_a_comer(_colocar_fruta(Vector3.RIGHT * 5.0), false)
		300:
			_comprobar(jugador.frutas_comidas >= 1, "click sobre un arbusto: el jugador va y lo come")
			jugador.ir_a(mundo.punto_navegable(inicio + Vector3(-10, 0, 0)), true)
		330:
			_comprobar(jugador.esta_corriendo(), "Shift + click derecho: el jugador corre")
		600:
			_comprobar(_distancia(jugador.global_position, inicio) > 5.0, "click derecho: el jugador camina hasta el destino")
			_comprobar(jugador.hambre < jugador.hambre_maxima, "la barra de hambre baja con el tiempo")
			_siguiente_modo()


func _guion_primera_persona() -> void:
	match t:
		1:
			_comprobar(jugador.camara_primera_persona.current, "la cámara de primera persona está activa")
			_colocar_fruta(Vector3(sin(jugador._yaw), 0, cos(jugador._yaw)) * 1.6)
		10:
			_evento_accion("comer", true)
		11:
			_evento_accion("comer", false)
		90:
			_comprobar(jugador.frutas_comidas >= 1, "E: el jugador come la fruta que mira")
			Input.action_press("adelante")
		250:
			Input.action_press("correr")
		270:
			_comprobar(jugador.esta_corriendo(), "Shift + W: el jugador corre")
		400:
			_comprobar(_distancia(jugador.global_position, inicio) > 5.0, "W: el jugador camina hacia adelante")
			_comprobar(jugador.hambre < jugador.hambre_maxima, "la barra de hambre baja con el tiempo")
			_siguiente_modo()


func _siguiente_modo() -> void:
	for accion in ["adelante", "atras", "izquierda", "derecha", "correr"]:
		Input.action_release(accion)
	main.queue_free()
	if modo == TERCERA_PERSONA:
		modo = PRIMERA_PERSONA
		_iniciar_modo()
	else:
		_terminar()


func _terminar() -> void:
	if fallos.is_empty():
		print("Prueba de humo superada.")
		quit(0)
	else:
		printerr("Prueba de humo FALLIDA (%d):" % fallos.size())
		for fallo in fallos:
			printerr("  - " + fallo)
		quit(1)


# --- Utilidades --------------------------------------------------------------

## Mueve una fruta disponible a una posición relativa al jugador y la devuelve.
func _colocar_fruta(desplazamiento: Vector3) -> Node3D:
	for fruta in get_nodes_in_group("comida"):
		if fruta.puede_ser_objetivo():
			var posicion: Vector3 = mundo.punto_navegable(jugador.global_position + desplazamiento)
			fruta.global_position = posicion
			return fruta
	_comprobar(false, "hay una fruta disponible para la prueba")
	return null


func _evento_accion(accion: String, presionada: bool) -> void:
	var evento := InputEventAction.new()
	evento.action = accion
	evento.pressed = presionada
	Input.parse_input_event(evento)


func _comprobar(condicion: bool, descripcion: String) -> void:
	if condicion:
		print("  OK     ", descripcion)
	else:
		printerr("  FALLO  ", descripcion)
		fallos.append(descripcion)


func _distancia(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
