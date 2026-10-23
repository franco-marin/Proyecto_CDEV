class_name Efectos
extends RefCounted
## Efectos de sangre:
##   - salpicadura(): partículas rojas que saltan cuando un zarpazo acierta.
##   - gota(): mancha en el suelo. Los animales heridos van dejando un rastro de gotas
##     y, al caer, un charco. Las manchas se borran solas después de un rato.

const COLOR_SANGRE := Color(0.68, 0.03, 0.04)
## Como mucho tantas manchas a la vez: si hay más, se borran las más viejas.
const MAXIMO_GOTAS := 250
const SEGUNDOS_GOTA := 20.0

static var _material_particula: StandardMaterial3D
static var _material_gota: StandardMaterial3D
static var _gotas: Array[Node3D] = []


## Partículas rojas que saltan desde "posicion", sobre todo hacia "direccion".
static func salpicadura(padre: Node, posicion: Vector3, direccion: Vector3) -> void:
	var particulas := CPUParticles3D.new()
	particulas.one_shot = true
	particulas.emitting = false
	particulas.amount = 45
	particulas.lifetime = 0.7
	particulas.explosiveness = 0.95
	particulas.direction = (direccion.normalized() + Vector3.UP * 0.6).normalized()
	particulas.spread = 55.0
	particulas.initial_velocity_min = 2.0
	particulas.initial_velocity_max = 4.5
	particulas.gravity = Vector3(0, -9.8, 0)
	particulas.scale_amount_min = 0.5
	particulas.scale_amount_max = 1.3
	var malla := SphereMesh.new()
	malla.radius = 0.055
	malla.height = 0.11
	malla.radial_segments = 4
	malla.rings = 2
	malla.material = _particula()
	particulas.mesh = malla
	padre.add_child(particulas)
	particulas.global_position = posicion
	particulas.emitting = true
	# Se borra sola cuando terminan de caer las partículas.
	particulas.create_tween().tween_interval(particulas.lifetime + 0.5).finished.connect(particulas.queue_free)
	# Algunas gotas caen al suelo alrededor.
	for i in 4:
		var salto := Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6)) + direccion.normalized() * 0.4
		gota(padre, posicion + salto, randf_range(0.6, 1.2))


## Mancha de sangre en el suelo. "tamano" 1 es una gota; un charco es más grande.
static func gota(padre: Node, posicion: Vector3, tamano := 1.0) -> void:
	if Mundo.en_agua(posicion):
		return  # en el río no quedan manchas
	var malla := CylinderMesh.new()
	malla.top_radius = 0.13
	malla.bottom_radius = 0.13
	malla.height = 0.005
	malla.radial_segments = 8
	malla.rings = 1
	malla.material = _gota()
	var mancha := MeshInstance3D.new()
	mancha.mesh = malla
	mancha.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	padre.add_child(mancha)
	mancha.global_position = Vector3(posicion.x, 0.012 + randf() * 0.004, posicion.z)
	mancha.rotation.y = randf() * TAU
	mancha.scale = Vector3(tamano * randf_range(0.7, 1.3), 1.0, tamano * randf_range(0.5, 1.0))
	# Después de un rato se achica hasta desaparecer.
	var tween := mancha.create_tween()
	tween.tween_interval(SEGUNDOS_GOTA)
	tween.tween_property(mancha, "scale", Vector3(0.01, 1.0, 0.01), 2.0)
	tween.tween_callback(mancha.queue_free)
	_gotas.append(mancha)
	while _gotas.size() > MAXIMO_GOTAS:
		var vieja = _gotas.pop_front()
		if is_instance_valid(vieja):
			vieja.queue_free()


static func _particula() -> StandardMaterial3D:
	if _material_particula == null:
		_material_particula = StandardMaterial3D.new()
		_material_particula.albedo_color = Color(0.85, 0.04, 0.05)
		_material_particula.emission_enabled = true
		_material_particula.emission = Color(0.5, 0.0, 0.0)
		_material_particula.roughness = 0.3
	return _material_particula


static func _gota() -> StandardMaterial3D:
	if _material_gota == null:
		_material_gota = StandardMaterial3D.new()
		_material_gota.albedo_color = COLOR_SANGRE
		_material_gota.roughness = 0.25  # húmeda: brilla un poco
	return _material_gota
