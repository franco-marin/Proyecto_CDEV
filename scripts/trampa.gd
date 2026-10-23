extends Node3D
## Trampa de cepo escondida entre la hojarasca. Solo se distingue de cerca (unos 5 m).
## Si el yaguareté la pisa, se cierra y no puede correr durante un rato. Solo funciona una vez.

const DISTANCIA_PARA_PISARLA := 0.7
const SEGUNDOS_SIN_CORRER := 10.0
const DISTANCIA_VISIBLE := 5.5

var disparada := false

var _mandibulas: Array[Node3D] = []


func _ready() -> void:
	var metal := _material(Color(0.32, 0.25, 0.2), 0.5)
	var hoja := _material(Color(0.36, 0.3, 0.16), 1.0)
	_pieza(self, _cilindro(0.3, 0.03), Vector3(0, 0.015, 0), metal)
	# Dos mandíbulas con dientes, abiertas (acostadas) a cada lado.
	for lado in [1, -1]:
		var bisagra := Node3D.new()
		bisagra.position = Vector3(0, 0.03, 0)
		bisagra.rotation.x = lado * 1.45
		add_child(bisagra)
		_pieza(bisagra, _caja(Vector3(0.55, 0.03, 0.03)), Vector3(0, 0.25, 0), metal)
		for i in 5:
			_pieza(bisagra, _caja(Vector3(0.03, 0.06, 0.03)), Vector3(-0.2 + i * 0.1, 0.21, 0), metal)
		_mandibulas.append(bisagra)
	# Hojas secas encima, para disimularla.
	for i in 6:
		var hoja_seca := _pieza(self, _caja(Vector3(0.18, 0.01, 0.1)),
			Vector3(randf_range(-0.3, 0.3), 0.05, randf_range(-0.3, 0.3)), hoja)
		hoja_seca.rotation.y = randf() * TAU


func _physics_process(_delta: float) -> void:
	if disparada:
		return
	var jugador = get_tree().get_first_node_in_group("jugador")
	if jugador == null or not jugador.vivo:
		return
	if Mundo.distancia_horizontal(jugador.global_position, global_position) <= DISTANCIA_PARA_PISARLA:
		_disparar(jugador)


func _disparar(jugador) -> void:
	disparada = true
	jugador.atrapar_en_trampa(SEGUNDOS_SIN_CORRER)
	var tween := create_tween().set_parallel()
	for bisagra in _mandibulas:
		tween.tween_property(bisagra, "rotation:x", signf(bisagra.rotation.x) * 0.15, 0.08)


func _pieza(padre: Node3D, malla: PrimitiveMesh, posicion: Vector3, material: Material) -> MeshInstance3D:
	malla.material = material
	var pieza := MeshInstance3D.new()
	pieza.mesh = malla
	pieza.position = posicion
	pieza.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Solo se ve de cerca.
	pieza.visibility_range_end = DISTANCIA_VISIBLE
	padre.add_child(pieza)
	return pieza


func _material(color: Color, aspereza: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = aspereza
	material.metallic = 0.4 if aspereza < 1.0 else 0.0
	return material


func _caja(medidas: Vector3) -> BoxMesh:
	var malla := BoxMesh.new()
	malla.size = medidas
	return malla


func _cilindro(radio: float, alto: float) -> CylinderMesh:
	var malla := CylinderMesh.new()
	malla.top_radius = radio
	malla.bottom_radius = radio
	malla.height = alto
	malla.radial_segments = 10
	return malla
