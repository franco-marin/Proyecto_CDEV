@tool
class_name ModeloAnimal
extends Node3D
## Construye por código un cuadrúpedo hecho de cajas y anima sus patas según la velocidad.
## Gracias a @tool también se ve en el editor y se rehace al cambiar cualquier propiedad
## en el Inspector. Así un solo script sirve para conejos, zorros y osos.

enum TipoOrejas { CORTAS, LARGAS, PUNTIAGUDAS }

@export var tamano := 1.0:
	set(valor):
		tamano = valor
		_reconstruir()
@export var color_cuerpo := Color(0.6, 0.6, 0.6):
	set(valor):
		color_cuerpo = valor
		_reconstruir()
@export var color_detalle := Color(0.9, 0.9, 0.9):
	set(valor):
		color_detalle = valor
		_reconstruir()
@export var largo_cuerpo := 1.0:
	set(valor):
		largo_cuerpo = valor
		_reconstruir()
@export var ancho_cuerpo := 0.6:
	set(valor):
		ancho_cuerpo = valor
		_reconstruir()
@export var alto_cuerpo := 0.5:
	set(valor):
		alto_cuerpo = valor
		_reconstruir()
@export var largo_patas := 0.4:
	set(valor):
		largo_patas = valor
		_reconstruir()
@export var tamano_cabeza := 0.45:
	set(valor):
		tamano_cabeza = valor
		_reconstruir()
@export var orejas := TipoOrejas.CORTAS:
	set(valor):
		orejas = valor
		_reconstruir()
@export var hocico_largo := false:
	set(valor):
		hocico_largo = valor
		_reconstruir()
@export var cola_larga := false:
	set(valor):
		cola_larga = valor
		_reconstruir()

## La IA escribe aquí la velocidad actual; las patas se mueven más rápido cuanto mayor sea.
var velocidad := 0.0

var _cuerpo: MeshInstance3D
var _cola: Node3D
var _patas: Array[Node3D] = []
var _y_cuerpo := 0.0
var _fase := 0.0
var _fase_cola := 0.0


func _ready() -> void:
	_reconstruir()


func _reconstruir() -> void:
	# Mientras la escena se está cargando todavía no estamos en el árbol: se construye en _ready.
	if not is_inside_tree():
		return
	for hijo in get_children():
		remove_child(hijo)
		hijo.queue_free()
	_patas.clear()

	scale = Vector3.ONE * tamano
	var piel := _material(color_cuerpo)
	var detalle := _material(color_detalle)
	var negro := _material(Color(0.05, 0.05, 0.05))
	var tc := tamano_cabeza

	_y_cuerpo = largo_patas + alto_cuerpo / 2.0
	_cuerpo = _caja(self, Vector3(ancho_cuerpo, alto_cuerpo, largo_cuerpo), Vector3(0, _y_cuerpo, 0), piel)

	# Cabeza (mira hacia +Z, que es "adelante" para todos los animales del juego).
	var cabeza := _caja(self, Vector3.ONE * tc,
		Vector3(0, _y_cuerpo + alto_cuerpo * 0.4, largo_cuerpo / 2.0 + tc * 0.35), piel)
	if hocico_largo:
		_caja(cabeza, Vector3(tc * 0.45, tc * 0.4, tc * 0.6), Vector3(0, -tc * 0.15, tc * 0.7), detalle)
		_caja(cabeza, Vector3.ONE * tc * 0.14, Vector3(0, -tc * 0.02, tc * 1.0), negro)
	else:
		_caja(cabeza, Vector3(tc * 0.5, tc * 0.35, tc * 0.2), Vector3(0, -tc * 0.15, tc * 0.55), detalle)
	for lado in [1, -1]:
		_caja(cabeza, Vector3.ONE * tc * 0.15, Vector3(lado * tc * 0.27, tc * 0.15, tc * 0.5), negro)
		match orejas:
			TipoOrejas.CORTAS:
				_caja(cabeza, Vector3(tc * 0.25, tc * 0.25, tc * 0.15), Vector3(lado * tc * 0.35, tc * 0.6, -tc * 0.1), piel)
			TipoOrejas.LARGAS:
				_caja(cabeza, Vector3(tc * 0.18, tc * 0.9, tc * 0.1), Vector3(lado * tc * 0.2, tc * 0.9, -tc * 0.1), piel)
			TipoOrejas.PUNTIAGUDAS:
				_caja(cabeza, Vector3(tc * 0.25, tc * 0.4, tc * 0.12), Vector3(lado * tc * 0.3, tc * 0.65, -tc * 0.1), negro)

	# Cola: cuelga de un pivote para poder moverla.
	_cola = Node3D.new()
	_cola.position = Vector3(0, _y_cuerpo + alto_cuerpo * 0.3, -largo_cuerpo / 2.0)
	add_child(_cola)
	var largo_cola := largo_cuerpo * (0.6 if cola_larga else 0.15)
	_caja(_cola, Vector3(ancho_cuerpo * 0.25, ancho_cuerpo * 0.25, largo_cola),
		Vector3(0, 0, -largo_cola / 2.0), detalle if cola_larga else piel)

	# Patas: cada una cuelga de un pivote en la "cadera". Orden: DI, DD, TI, TD.
	for z in [1, -1]:
		for x in [1, -1]:
			var cadera := Node3D.new()
			cadera.position = Vector3(x * ancho_cuerpo * 0.35, largo_patas, z * largo_cuerpo * 0.35)
			add_child(cadera)
			_caja(cadera, Vector3(ancho_cuerpo * 0.25, largo_patas, ancho_cuerpo * 0.25),
				Vector3(0, -largo_patas / 2.0, 0), piel)
			_patas.append(cadera)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _patas.is_empty():
		return
	var movimiento := clampf(velocidad / 3.0, 0.0, 1.0)
	_fase += delta * (3.0 + velocidad * 2.5)
	var giro := sin(_fase) * 0.7 * movimiento
	# Patas en diagonal se mueven juntas, como al trotar.
	_patas[0].rotation.x = giro
	_patas[3].rotation.x = giro
	_patas[1].rotation.x = -giro
	_patas[2].rotation.x = -giro
	_cuerpo.position.y = _y_cuerpo + absf(sin(_fase)) * 0.05 * movimiento
	_fase_cola += delta * (4.0 if movimiento < 0.1 else 10.0)
	_cola.rotation.y = sin(_fase_cola) * 0.4


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
