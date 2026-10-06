extends Node
## Autoload (singleton): Godot lo crea al iniciar el juego y cualquier script
## puede usarlo escribiendo "Mundo." (ver Proyecto > Configuración > Globales).
## Aquí van datos y funciones de ayuda que comparten todos los personajes.

enum ModoCamara { TERCERA_PERSONA, PRIMERA_PERSONA }

## Mitad del lado del área jugable: el bosque mide 2 × MITAD_MAPA metros de lado.
const MITAD_MAPA := 38.0

# Un autoload no se destruye al recargar la escena, así que aquí se guardan las
# opciones que deben sobrevivir a "Reintentar".
var modo := ModoCamara.TERCERA_PERSONA
var mostrar_menu := true
## Sensibilidad del mouse en primera persona, de 1 a 10 (la elige el menú de inicio).
var sensibilidad := 5.0


## Recarga el nivel. Con volver_al_menu = true se vuelve a elegir el modo de juego.
func reiniciar(volver_al_menu: bool) -> void:
	mostrar_menu = volver_al_menu
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().reload_current_scene()


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


func punto_aleatorio_en_mapa() -> Vector3:
	return punto_navegable(Vector3(
		randf_range(-MITAD_MAPA, MITAD_MAPA), 0, randf_range(-MITAD_MAPA, MITAD_MAPA)))


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
