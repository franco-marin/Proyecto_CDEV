class_name Rio
extends Node3D
## Río que cruza todo el mapa de un borde al otro, con una forma distinta en cada partida.
## Arma su propia malla (agua y barro de las orillas) y responde preguntas como
## "¿este punto está en el agua?" o "¿de qué lado del río está?".
## El terreno es plano: el río es una capa de agua apenas por encima del suelo. Quien nada
## se "hunde" un poco y el suelo tapa la parte de abajo del cuerpo.

const PASO := 2.0  # metros entre puntos del cauce
const ALTURA_AGUA := 0.06
const SHADER_AGUA := preload("res://recursos/agua.gdshader")

## Puntos del centro del cauce y el ancho del río en cada uno.
var puntos := PackedVector3Array()
var anchos := PackedFloat32Array()

var _a_lo_largo_de_x := true  # el río corre a lo largo del eje X (si no, del Z)
var _inicio := 0.0
var _botellas: Array[Node3D] = []


## Crea un cauce serpenteante al azar. Nunca pasa por el centro del mapa (donde empieza
## el jugador).
func generar(mitad_mapa: float, color: Color, turbidez: float, espuma: float, botellas: int) -> void:
	_a_lo_largo_de_x = randf() < 0.5
	var desvio := randf_range(18.0, 34.0) * (1.0 if randf() < 0.5 else -1.0)
	var fases := [randf() * TAU, randf() * TAU, randf() * TAU]
	var largo := mitad_mapa + 30.0  # el río sigue más allá de los bordes del mapa
	_inicio = -largo
	var t := -largo
	while t <= largo:
		var lateral: float = desvio + 7.0 * sin(t * 0.045 + fases[0]) + 4.0 * sin(t * 0.11 + fases[1])
		puntos.append(Vector3(t, 0, lateral) if _a_lo_largo_de_x else Vector3(lateral, 0, t))
		anchos.append(8.0 + 1.8 * sin(t * 0.07 + fases[2]))
		t += PASO
	_construir_mallas(color, turbidez, espuma)
	_poner_botellas(botellas)


func _process(_delta: float) -> void:
	# Las botellas se mecen en el agua.
	var tiempo := Time.get_ticks_msec() / 1000.0
	for i in _botellas.size():
		var botella := _botellas[i]
		botella.position.y = ALTURA_AGUA + 0.03 + sin(tiempo * 2.0 + i) * 0.03
		botella.rotation.z = PI / 2.0 + sin(tiempo * 1.3 + i) * 0.2


# --- Preguntas sobre el río --------------------------------------------------------

## Distancia horizontal desde un punto hasta el centro del cauce.
func distancia_al_cauce(punto: Vector3) -> float:
	var i := _indice_cercano(punto)
	var p := Vector2(punto.x, punto.z)
	var mejor := INF
	for j in range(maxi(i - 4, 0), mini(i + 4, puntos.size() - 1)):
		var a := Vector2(puntos[j].x, puntos[j].z)
		var b := Vector2(puntos[j + 1].x, puntos[j + 1].z)
		mejor = minf(mejor, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
	return mejor


func medio_ancho(punto: Vector3) -> float:
	return anchos[_indice_cercano(punto)] / 2.0


## true si el punto está dentro del agua (con "margen" se agranda o achica el río).
func en_agua(punto: Vector3, margen := 0.0) -> bool:
	return distancia_al_cauce(punto) < medio_ancho(punto) + margen


## -1 o 1 según de qué lado del río está el punto.
func lado(punto: Vector3) -> int:
	var i := _indice_cercano(punto)
	var lateral_rio := puntos[i].z if _a_lo_largo_de_x else puntos[i].x
	var lateral_punto := punto.z if _a_lo_largo_de_x else punto.x
	return 1 if lateral_punto >= lateral_rio else -1


## Punto en el centro del agua, cerca del punto dado.
func punto_de_agua_cercano(punto: Vector3) -> Vector3:
	return puntos[_indice_cercano(punto)]


## Punto al azar sobre la orilla (dentro del mapa).
func punto_en_orilla(mitad_mapa: float) -> Vector3:
	for intento in 30:
		var i := randi_range(0, puntos.size() - 1)
		var normal := _normal(i)
		var lado_elegido := 1.0 if randf() < 0.5 else -1.0
		var punto := puntos[i] + normal * lado_elegido * (anchos[i] / 2.0 + randf_range(1.0, 3.5))
		if absf(punto.x) < mitad_mapa - 2.0 and absf(punto.z) < mitad_mapa - 2.0:
			return punto
	return puntos[puntos.size() / 2]


func _indice_cercano(punto: Vector3) -> int:
	var a_lo_largo := punto.x if _a_lo_largo_de_x else punto.z
	return clampi(int(round((a_lo_largo - _inicio) / PASO)), 0, puntos.size() - 1)


## Dirección perpendicular al cauce en el punto i (hacia una de las orillas).
func normal_en(i: int) -> Vector3:
	return _normal(i)


## Dirección en la que corre el río en el punto i.
func direccion_en(i: int) -> Vector3:
	var normal := _normal(i)
	return Vector3(normal.z, 0, -normal.x)


## Dirección perpendicular al cauce en el punto i (en el plano del suelo).
func _normal(i: int) -> Vector3:
	var antes := puntos[maxi(i - 1, 0)]
	var despues := puntos[mini(i + 1, puntos.size() - 1)]
	var direccion := (despues - antes).normalized()
	return Vector3(-direccion.z, 0, direccion.x)


# --- Malla ----------------------------------------------------------------------------

func _construir_mallas(color: Color, turbidez: float, espuma: float) -> void:
	# Barro de las orillas (y del fondo): una franja más ancha que el agua.
	var barro := StandardMaterial3D.new()
	barro.albedo_color = Color(0.33, 0.27, 0.18)
	barro.roughness = 1.0
	barro.cull_mode = BaseMaterial3D.CULL_DISABLED
	add_child(_franja(1.6, 0.02, barro))

	var agua := ShaderMaterial.new()
	agua.shader = SHADER_AGUA
	agua.set_shader_parameter("color_agua", color)
	agua.set_shader_parameter("turbidez", turbidez)
	agua.set_shader_parameter("espuma", espuma)
	var malla_agua := _franja(0.0, ALTURA_AGUA, agua)
	malla_agua.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(malla_agua)


## Arma una cinta que sigue el cauce, de ancho "ancho del río + 2 × extra".
func _franja(extra: float, altura: float, material: Material) -> MeshInstance3D:
	var superficie := SurfaceTool.new()
	superficie.begin(Mesh.PRIMITIVE_TRIANGLES)
	var recorrido := 0.0
	for i in puntos.size() - 1:
		var esquinas := []
		for k in [i, i + 1]:
			var normal := _normal(k)
			var medio := anchos[k] / 2.0 + extra
			esquinas.append(puntos[k] + normal * medio + Vector3(0, altura, 0))
			esquinas.append(puntos[k] - normal * medio + Vector3(0, altura, 0))
		var largo := puntos[i].distance_to(puntos[i + 1])
		var uv := [Vector2(0, recorrido), Vector2(1, recorrido), Vector2(0, recorrido + largo), Vector2(1, recorrido + largo)]
		for indice in [0, 2, 1, 1, 2, 3]:
			superficie.set_normal(Vector3.UP)
			superficie.set_uv(uv[indice])
			superficie.add_vertex(esquinas[indice])
		recorrido += largo
	var instancia := MeshInstance3D.new()
	instancia.mesh = superficie.commit()
	instancia.material_override = material
	return instancia


## Botellas de plástico flotando (niveles con basura).
func _poner_botellas(cantidad: int) -> void:
	var colores := [Color(0.3, 0.6, 0.35), Color(0.85, 0.88, 0.9), Color(0.55, 0.35, 0.2)]
	for n in cantidad:
		var i := randi_range(0, puntos.size() - 1)
		var malla := CylinderMesh.new()
		malla.top_radius = 0.035
		malla.bottom_radius = 0.06
		malla.height = 0.28
		malla.radial_segments = 6
		var material := StandardMaterial3D.new()
		material.albedo_color = colores.pick_random()
		malla.material = material
		var botella := MeshInstance3D.new()
		botella.mesh = malla
		botella.position = puntos[i] + _normal(i) * randf_range(-anchos[i] * 0.35, anchos[i] * 0.35)
		botella.rotation.y = randf() * TAU
		add_child(botella)
		_botellas.append(botella)
