extends Node
## Autoload (singleton): Godot lo crea al iniciar el juego y cualquier script
## puede usarlo escribiendo "Mundo." (ver Proyecto > Configuración > Globales).
## Aquí van datos y funciones de ayuda que comparten todos los personajes.

enum ModoCamara { TERCERA_PERSONA, PRIMERA_PERSONA }

## Mitad del lado del área jugable: el bosque mide 2 × MITAD_MAPA metros de lado.
const MITAD_MAPA := 60.0
## Tamaño de las celdas de la grilla que guarda dónde hay maleza (para la cobertura).
const TAMANO_CELDA := 4.0

# Un autoload no se destruye al recargar la escena, así que aquí se guardan las
# opciones que deben sobrevivir a "Reintentar".
var modo := ModoCamara.TERCERA_PERSONA
var mostrar_menu := true
## Sensibilidad del mouse en primera persona, de 1 a 10 (la elige el menú de inicio).
var sensibilidad := 5.0
## Nivel que se está jugando (1 a Niveles.CANTIDAD) y el más alto que se desbloqueó.
var nivel := 1
var nivel_desbloqueado := 1

## El río del nivel actual (lo crea main.gd). Es null mientras no exista.
var rio: Rio = null

## Grilla con las posiciones de las plantas del sotobosque, para saber rápido si hay
## maleza cerca de un punto sin recorrer las más de mil plantas.
var _cobertura := {}


## Avisa a los menús cuando se cambia entre ventana y pantalla completa (por ejemplo con F11).
signal pantalla_completa_cambiada(activa: bool)
## Se pidió pantalla completa pero no se puede (el juego corre dentro del editor).
signal pantalla_completa_no_disponible

## Cuando se prueba con F5, Godot 4.4+ ejecuta el juego dentro de la pestaña "Juego" del
## editor, y ahí no se puede poner en pantalla completa.
const AVISO_EDITOR := "En el editor el juego corre dentro de la pestaña \"Juego\" y no puede ir a pantalla completa. Desactivá \"Incrustar juego en la próxima ejecución\" en esa pestaña (o probalo exportado)."


func _ready() -> void:
	# Siempre activo, para que F11 funcione también con el juego en pausa.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pantalla_completa"):
		poner_pantalla_completa(not esta_en_pantalla_completa())
		get_viewport().set_input_as_handled()


func pantalla_completa_disponible() -> bool:
	return not Engine.is_embedded_in_editor()


## Prepara una casilla "Pantalla completa" de un menú: muestra el modo actual, lo cambia
## al marcarla y se actualiza si se usa F11. Dentro del editor queda desactivada y explica por qué.
func preparar_casilla_pantalla_completa(casilla: CheckButton) -> void:
	casilla.button_pressed = esta_en_pantalla_completa()
	if not pantalla_completa_disponible():
		casilla.disabled = true
		casilla.text = "Pantalla completa (no disponible dentro del editor)"
		casilla.tooltip_text = AVISO_EDITOR
		return
	casilla.toggled.connect(poner_pantalla_completa)
	pantalla_completa_cambiada.connect(casilla.set_pressed_no_signal)


func esta_en_pantalla_completa() -> bool:
	var modo_ventana := DisplayServer.window_get_mode()
	return modo_ventana == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or modo_ventana == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


## Cambia entre ventana y pantalla completa (sin bordes: ideal para grabar).
func poner_pantalla_completa(activar: bool) -> void:
	if activar == esta_en_pantalla_completa():
		return
	if not pantalla_completa_disponible():
		push_warning(AVISO_EDITOR)
		pantalla_completa_no_disponible.emit()
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if activar else DisplayServer.WINDOW_MODE_WINDOWED)
	pantalla_completa_cambiada.emit(activar)


## Recarga el nivel. Con volver_al_menu = true se vuelve a elegir el modo de juego.
func reiniciar(volver_al_menu: bool) -> void:
	mostrar_menu = volver_al_menu
	rio = null
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().reload_current_scene()


## Pasa al nivel siguiente (y lo deja desbloqueado en el menú).
func avanzar_nivel() -> void:
	nivel = mini(nivel + 1, Niveles.CANTIDAD)
	nivel_desbloqueado = maxi(nivel_desbloqueado, nivel)


# --- Río ---------------------------------------------------------------------------

func en_agua(punto: Vector3, margen := 0.0) -> bool:
	return rio != null and rio.en_agua(punto, margen)


## true si los dos puntos están del mismo lado del río (o si no hay río).
func mismo_lado_del_rio(a: Vector3, b: Vector3) -> bool:
	return rio == null or rio.lado(a) == rio.lado(b)


# --- Cobertura (maleza) ------------------------------------------------------------

func limpiar_cobertura() -> void:
	_cobertura.clear()


func registrar_cobertura(punto: Vector3) -> void:
	var celda := _celda(punto)
	if not _cobertura.has(celda):
		_cobertura[celda] = []
	_cobertura[celda].append(punto)


## true si hay alguna planta del sotobosque a menos de "radio" metros del punto.
func hay_cobertura(punto: Vector3, radio: float) -> bool:
	var centro := _celda(punto)
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			for planta in _cobertura.get(centro + Vector2i(dx, dz), []):
				if distancia_horizontal(planta, punto) <= radio:
					return true
	return false


func _celda(punto: Vector3) -> Vector2i:
	return Vector2i(floori(punto.x / TAMANO_CELDA), floori(punto.z / TAMANO_CELDA))


# --- Puntos del mapa ---------------------------------------------------------------

## Recorta un punto para que quede dentro del área jugable.
func limitar(punto: Vector3) -> Vector3:
	return Vector3(
		clampf(punto.x, -MITAD_MAPA, MITAD_MAPA),
		punto.y,
		clampf(punto.z, -MITAD_MAPA, MITAD_MAPA))


## Devuelve el punto caminable (sobre la malla de navegación) más cercano.
func punto_navegable(punto: Vector3) -> Vector3:
	var mapa := get_viewport().find_world_3d().navigation_map
	var resultado := NavigationServer3D.map_get_closest_point(mapa, limitar(punto))
	resultado.y = 0.0  # la malla queda un poco por encima del suelo; el terreno es plano
	return resultado


func punto_aleatorio_cerca(origen: Vector3, radio: float) -> Vector3:
	var angulo := randf() * TAU
	var distancia := randf_range(radio * 0.3, radio)
	return punto_navegable(origen + Vector3(cos(angulo), 0, sin(angulo)) * distancia)


## Punto al azar en tierra firme (fuera del río).
func punto_aleatorio_en_mapa() -> Vector3:
	var punto := Vector3.ZERO
	for intento in 20:
		punto = punto_navegable(Vector3(
			randf_range(-MITAD_MAPA, MITAD_MAPA), 0, randf_range(-MITAD_MAPA, MITAD_MAPA)))
		if not en_agua(punto, 1.0):
			break
	return punto


## Punto al azar que esté al menos a "distancia_minima" de "centro".
func punto_aleatorio_lejos_de(centro: Vector3, distancia_minima: float) -> Vector3:
	var punto := punto_aleatorio_en_mapa()
	for intento in 30:
		if distancia_horizontal(punto, centro) >= distancia_minima:
			break
		punto = punto_aleatorio_en_mapa()
	return punto


## Distancia ignorando la altura (como si se mirara el mapa desde arriba).
func distancia_horizontal(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
