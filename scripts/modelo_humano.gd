@tool
class_name ModeloHumano
extends Node3D
## Construye por código un humano hecho de cajas (el cazador) y anima sus piernas según
## la velocidad. Es el mismo estilo que ModeloAnimal, pero bípedo y con un rifle en las manos.
## La piel es gris a propósito: es un personaje genérico, sin rasgos ni etnia.

@export var tamano := 1.0:
	set(valor):
		tamano = valor
		_reconstruir()
@export var color_piel := Color(0.55, 0.55, 0.57):
	set(valor):
		color_piel = valor
		_reconstruir()
@export var color_camisa := Color(0.33, 0.36, 0.22):
	set(valor):
		color_camisa = valor
		_reconstruir()
@export var color_pantalon := Color(0.3, 0.25, 0.18):
	set(valor):
		color_pantalon = valor
		_reconstruir()
@export var color_sombrero := Color(0.42, 0.33, 0.2):
	set(valor):
		color_sombrero = valor
		_reconstruir()
@export var largo_piernas := 0.8:
	set(valor):
		largo_piernas = valor
		_reconstruir()

## La IA escribe aquí la velocidad actual; las piernas se mueven más rápido cuanto mayor sea.
var velocidad := 0.0

var _torso: Node3D
var _piernas: Array[Node3D] = []
var _y_torso := 0.0
var _fase := 0.0
var _fase_respirar := 0.0


func _ready() -> void:
	_reconstruir()


func _reconstruir() -> void:
	# Mientras la escena se está cargando todavía no estamos en el árbol: se construye en _ready.
	if not is_inside_tree():
		return
	for hijo in get_children():
		remove_child(hijo)
		hijo.queue_free()
	_piernas.clear()

	scale = Vector3.ONE * tamano
	var piel := _material(color_piel)
	var camisa := _material(color_camisa)
	var pantalon := _material(color_pantalon)
	var sombrero := _material(color_sombrero)
	var negro := _material(Color(0.05, 0.05, 0.05))
	var madera := _material(Color(0.35, 0.2, 0.1))

	# Piernas: cada una cuelga de un pivote en la cadera. Orden: izquierda, derecha.
	for x in [1, -1]:
		var cadera := Node3D.new()
		cadera.position = Vector3(x * 0.12, largo_piernas, 0)
		add_child(cadera)
		_caja(cadera, Vector3(0.18, largo_piernas, 0.2), Vector3(0, -largo_piernas / 2.0, 0), pantalon)
		_caja(cadera, Vector3(0.2, 0.12, 0.28), Vector3(0, -largo_piernas + 0.06, 0.04), negro)  # bota
		_piernas.append(cadera)

	# Torso: todo lo de la cintura para arriba cuelga de él, así se balancea junto al caminar.
	_y_torso = largo_piernas
	_torso = Node3D.new()
	_torso.position = Vector3(0, _y_torso, 0)
	add_child(_torso)
	_caja(_torso, Vector3(0.5, 0.6, 0.28), Vector3(0, 0.3, 0), camisa)

	# Cabeza (mira hacia +Z, que es "adelante" para todos los personajes del juego).
	var cabeza := _caja(_torso, Vector3(0.3, 0.32, 0.3), Vector3(0, 0.79, 0), piel)
	for lado in [1, -1]:
		_caja(cabeza, Vector3(0.05, 0.05, 0.02), Vector3(lado * 0.07, 0.03, 0.15), negro)
	_caja(cabeza, Vector3(0.5, 0.04, 0.5), Vector3(0, 0.17, 0), sombrero)  # ala
	_caja(cabeza, Vector3(0.32, 0.14, 0.32), Vector3(0, 0.25, 0), sombrero)  # copa

	# Brazos hacia adelante y hacia el centro, sosteniendo el rifle.
	for x in [1, -1]:
		var hombro := Node3D.new()
		hombro.position = Vector3(x * 0.31, 0.55, 0)
		hombro.rotation = Vector3(-1.3, -x * 0.35, 0)
		_torso.add_child(hombro)
		_caja(hombro, Vector3(0.14, 0.6, 0.14), Vector3(0, -0.3, 0), camisa)
		_caja(hombro, Vector3.ONE * 0.12, Vector3(0, -0.62, 0), piel)  # mano

	# Rifle: culata de madera y caño negro, apuntando hacia adelante.
	_caja(_torso, Vector3(0.08, 0.12, 0.4), Vector3(0, 0.4, 0.35), madera)
	_caja(_torso, Vector3(0.05, 0.05, 0.6), Vector3(0, 0.42, 0.85), negro)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _piernas.is_empty():
		return
	var movimiento := clampf(velocidad / 3.0, 0.0, 1.0)
	_fase += delta * (3.0 + velocidad * 2.0)
	var giro := sin(_fase) * 0.6 * movimiento
	_piernas[0].rotation.x = giro
	_piernas[1].rotation.x = -giro
	# Al caminar sube y baja con cada paso; quieto, respira despacio.
	_fase_respirar += delta * 2.0
	var respirar := sin(_fase_respirar) * 0.01 * (1.0 - movimiento)
	_torso.position.y = _y_torso + absf(sin(_fase)) * 0.04 * movimiento + respirar


func _caja(padre: Node3D, medidas: Vector3, posicion: Vector3, material: Material) -> MeshInstance3D:
	var malla := BoxMesh.new()
	malla.size = medidas
	malla.material = material
	var instancia := MeshInstance3D.new()
	instancia.mesh = malla
	instancia.position = posicion
	padre.add_child(instancia)
	return instancia


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material
