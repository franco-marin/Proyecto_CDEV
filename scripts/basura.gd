extends Node3D
## Montón de basura (bolsas, botellas y latas). Es chico y cuesta verlo entre la
## vegetación; si el yaguareté pasa a menos de 1 m, le baja el hambre (ver jugador.gd).


func _ready() -> void:
	var colores_bolsa := [Color(0.08, 0.08, 0.08), Color(0.15, 0.3, 0.15), Color(0.45, 0.6, 0.75)]
	for i in randi_range(1, 3):
		_pieza(_esfera(), Vector3(randf_range(-0.3, 0.3), 0.15, randf_range(-0.3, 0.3)),
			Vector3(randf_range(0.2, 0.3), randf_range(0.15, 0.22), randf_range(0.2, 0.3)), colores_bolsa.pick_random())
	var colores_botella := [Color(0.3, 0.6, 0.35), Color(0.85, 0.88, 0.9), Color(0.55, 0.35, 0.2)]
	for i in randi_range(1, 3):
		var botella := _pieza(_cilindro(0.035, 0.06, 0.28), Vector3(randf_range(-0.4, 0.4), 0.05, randf_range(-0.4, 0.4)),
			Vector3.ONE, colores_botella.pick_random())
		botella.rotation = Vector3(PI / 2.0, randf() * TAU, 0)
	var colores_lata := [Color(0.75, 0.1, 0.1), Color(0.7, 0.72, 0.75)]
	for i in randi_range(1, 2):
		var lata := _pieza(_cilindro(0.035, 0.035, 0.12), Vector3(randf_range(-0.4, 0.4), 0.035, randf_range(-0.4, 0.4)),
			Vector3.ONE, colores_lata.pick_random())
		lata.rotation = Vector3(PI / 2.0, randf() * TAU, 0)


func _pieza(malla: PrimitiveMesh, posicion: Vector3, escala: Vector3, color: Color) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.6
	malla.material = material
	var pieza := MeshInstance3D.new()
	pieza.mesh = malla
	pieza.position = posicion
	pieza.scale = escala
	pieza.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pieza)
	return pieza


func _esfera() -> SphereMesh:
	var malla := SphereMesh.new()
	malla.radial_segments = 7
	malla.rings = 4
	return malla


func _cilindro(arriba: float, abajo: float, alto: float) -> CylinderMesh:
	var malla := CylinderMesh.new()
	malla.top_radius = arriba
	malla.bottom_radius = abajo
	malla.height = alto
	malla.radial_segments = 6
	return malla
