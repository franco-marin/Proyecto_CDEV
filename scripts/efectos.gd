class_name Efectos
extends RefCounted
## Efectos de sangre:
##   - salpicadura(): partículas rojas que saltan cuando un zarpazo acierta.
##   - gota(): mancha en el suelo. Los animales heridos van dejando un rastro de gotas
##     y, al caer, un charco. Las manchas se borran solas después de un rato.
## Efectos de los disparos del cazador (nunca lastiman: el tiro siempre pega al costado):
##   - fogonazo(): destello de luz y chispas en la punta del caño.
##   - impacto(): polvo que salta del suelo, o astillas si el tiro pega en un tronco.

const COLOR_SANGRE := Color(0.68, 0.03, 0.04)
## Como mucho tantas manchas a la vez: si hay más, se borran las más viejas.
const MAXIMO_GOTAS := 250
const SEGUNDOS_GOTA := 20.0
const COLOR_FOGONAZO := Color(1.0, 0.78, 0.35)
const COLOR_POLVO := Color(0.5, 0.43, 0.33)
const COLOR_ASTILLAS := Color(0.76, 0.62, 0.42)

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


## Destello en la punta del caño: una luz que se apaga enseguida y unas chispas hacia adelante.
static func fogonazo(padre: Node, posicion: Vector3, direccion: Vector3) -> void:
	var luz := OmniLight3D.new()
	luz.light_color = COLOR_FOGONAZO
	luz.light_energy = 6.0
	luz.omni_range = 5.0
	padre.add_child(luz)
	luz.global_position = posicion
	var tween := luz.create_tween()
	tween.tween_property(luz, "light_energy", 0.0, 0.12)
	tween.tween_callback(luz.queue_free)
	_rafaga(padre, posicion, direccion, COLOR_FOGONAZO, true, 10, 0.12, 25.0, 4.0, 7.0, 0.035, Vector3.ZERO)


## Donde pega el tiro: polvo que salta del suelo o astillas de madera si pegó en un tronco.
static func impacto(padre: Node, posicion: Vector3, en_un_tronco: bool) -> void:
	if en_un_tronco:
		_rafaga(padre, posicion, Vector3.UP, COLOR_ASTILLAS, false, 12, 0.6, 70.0, 1.5, 3.0, 0.04, Vector3(0, -9.8, 0))
	elif not Mundo.en_agua(posicion):
		_rafaga(padre, posicion, Vector3.UP, COLOR_POLVO, false, 18, 0.8, 35.0, 1.5, 3.0, 0.07, Vector3(0, -4.0, 0))


## Partículas que salen de golpe desde "posicion" hacia "direccion" y se borran solas.
static func _rafaga(padre: Node, posicion: Vector3, direccion: Vector3, color: Color, brilla: bool,
		cantidad: int, duracion: float, apertura: float, velocidad_min: float, velocidad_max: float,
		radio: float, gravedad: Vector3) -> void:
	var particulas := CPUParticles3D.new()
	particulas.one_shot = true
	particulas.emitting = false
	particulas.amount = cantidad
	particulas.lifetime = duracion
	particulas.explosiveness = 0.95
	particulas.direction = direccion.normalized()
	particulas.spread = apertura
	particulas.initial_velocity_min = velocidad_min
	particulas.initial_velocity_max = velocidad_max
	particulas.gravity = gravedad
	particulas.scale_amount_min = 0.6
	particulas.scale_amount_max = 1.4
	var malla := SphereMesh.new()
	malla.radius = radio
	malla.height = radio * 2.0
	malla.radial_segments = 4
	malla.rings = 2
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	if brilla:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 3.0
	malla.material = material
	particulas.mesh = malla
	padre.add_child(particulas)
	particulas.global_position = posicion
	particulas.emitting = true
	particulas.create_tween().tween_interval(duracion + 0.5).finished.connect(particulas.queue_free)


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
