extends Node3D
## Pájaro decorativo: vuela de árbol en árbol, se posa un rato y canta.
## No interactúa con nada; solo da vida al bosque.

enum Estado { VOLANDO, POSADO }

@export var velocidad := 7.0
@export var altura_vuelo := 10.0

var estado: Estado = Estado.POSADO
var destino: Vector3
var _tiempo_posado := 0.0
var _proximo_canto := 0.0
var _aleteo := 0.0

@onready var ala_izq: Node3D = $Modelo/AlaIzq
@onready var ala_der: Node3D = $Modelo/AlaDer
@onready var canto: AudioStreamPlayer3D = $Canto


func _ready() -> void:
	# Cada pájaro con un color distinto.
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.from_hsv(randf(), 0.65, 0.9)
	for parte in [$Modelo/Cuerpo, $Modelo/Cabeza, $Modelo/Cola, $Modelo/AlaIzq/Mesh, $Modelo/AlaDer/Mesh]:
		parte.material_override = material
	_tiempo_posado = randf_range(1.0, 10.0)
	_proximo_canto = randf_range(1.0, 6.0)


func _process(delta: float) -> void:
	match estado:
		Estado.POSADO:
			_estar_posado(delta)
		Estado.VOLANDO:
			_volar(delta)


func _estar_posado(delta: float) -> void:
	ala_izq.rotation.z = 0.0
	ala_der.rotation.z = 0.0
	_proximo_canto -= delta
	if _proximo_canto <= 0.0:
		_cantar()
		_proximo_canto = randf_range(3.0, 9.0)
	_tiempo_posado -= delta
	if _tiempo_posado <= 0.0:
		_volar_a_otro_arbol()


func _volar(delta: float) -> void:
	# Lejos del destino vuela alto; al acercarse, baja a posarse.
	var distancia := Mundo.distancia_horizontal(global_position, destino)
	var meta := destino if distancia < 5.0 else Vector3(destino.x, altura_vuelo, destino.z)
	var paso := meta - global_position
	if paso.length() < 0.05 and meta == destino:
		estado = Estado.POSADO
		_tiempo_posado = randf_range(5.0, 15.0)
		return
	global_position += paso.normalized() * minf(velocidad * delta, paso.length())
	if Vector2(paso.x, paso.z).length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(paso.x, paso.z), 5.0 * delta)
	_aleteo += delta * 18.0
	ala_izq.rotation.z = sin(_aleteo) * 0.8
	ala_der.rotation.z = -sin(_aleteo) * 0.8


func _volar_a_otro_arbol() -> void:
	var arboles := get_tree().get_nodes_in_group("arboles")
	if arboles.is_empty():
		return
	destino = arboles.pick_random().punto_posado()
	estado = Estado.VOLANDO


func _cantar() -> void:
	# Los sonidos se agregan más adelante: basta con asignar un "Stream" al nodo Canto.
	if canto.stream:
		canto.pitch_scale = randf_range(0.9, 1.2)
		canto.play()
