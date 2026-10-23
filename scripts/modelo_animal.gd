@tool
class_name ModeloAnimal
extends Node3D
## Construye por código un cuadrúpedo hecho de cajas y anima sus patas según la velocidad.
## Gracias a @tool también se ve en el editor y se rehace al cambiar cualquier propiedad
## en el Inspector. Un solo script sirve para tapires, pecaríes, corzuelas, carpinchos,
## osos hormigueros, ocelotes y yacarés: cambian las proporciones, el hocico, la cola
## y los detalles (manchas, collar, franja, cresta).

enum TipoOrejas { CORTAS, LARGAS, PUNTIAGUDAS, NINGUNA }
enum TipoHocico { CORTO, LARGO, TROMPA, TUBO, REPTIL }
enum TipoCola { CORTA, LARGA, PELUDA, REPTIL, NINGUNA }

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

@export_group("Proporciones")
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
## Patas hacia los costados, como las de un reptil.
@export var patas_abiertas := false:
	set(valor):
		patas_abiertas = valor
		_reconstruir()
@export var tamano_cabeza := 0.45:
	set(valor):
		tamano_cabeza = valor
		_reconstruir()
## Altura de la cabeza respecto del cuerpo (0 = a la altura del centro, 0.4 = más alta).
@export var altura_cabeza := 0.4:
	set(valor):
		altura_cabeza = valor
		_reconstruir()

@export_group("Forma")
@export var orejas := TipoOrejas.CORTAS:
	set(valor):
		orejas = valor
		_reconstruir()
@export var hocico := TipoHocico.CORTO:
	set(valor):
		hocico = valor
		_reconstruir()
@export var cola := TipoCola.CORTA:
	set(valor):
		cola = valor
		_reconstruir()

@export_group("Detalles")
## Manchas oscuras sobre el lomo y los costados (ocelote).
@export var manchas := false:
	set(valor):
		manchas = valor
		_reconstruir()
@export var color_manchas := Color(0.12, 0.09, 0.06):
	set(valor):
		color_manchas = valor
		_reconstruir()
## Banda clara alrededor del cuello (pecarí de collar).
@export var collar := false:
	set(valor):
		collar = valor
		_reconstruir()
## Franja oscura en diagonal sobre el hombro (oso hormiguero).
@export var franja := false:
	set(valor):
		franja = valor
		_reconstruir()
## Fila de escamas sobre el lomo y la cola (yacaré).
@export var cresta := false:
	set(valor):
		cresta = valor
		_reconstruir()

## La IA escribe aquí la velocidad actual; las patas se mueven más rápido cuanto mayor sea.
var velocidad := 0.0
## Mientras es true, el animal baja la cabeza (está comiendo).
var comiendo := false

var _cuerpo: MeshInstance3D
var _cabeza: MeshInstance3D
var _cola: Node3D
var _patas: Array[Node3D] = []
var _y_cuerpo := 0.0
var _y_cabeza := 0.0
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
	var oscuro := _material(color_manchas)
	var negro := _material(Color(0.05, 0.05, 0.05))
	var tc := tamano_cabeza

	_y_cuerpo = largo_patas + alto_cuerpo / 2.0
	_cuerpo = _caja(self, Vector3(ancho_cuerpo, alto_cuerpo, largo_cuerpo), Vector3(0, _y_cuerpo, 0), piel)

	# Cabeza (mira hacia +Z, que es "adelante" para todos los animales del juego).
	_y_cabeza = _y_cuerpo + alto_cuerpo * altura_cabeza
	_cabeza = _caja(self, Vector3(tc, tc * (0.7 if hocico == TipoHocico.REPTIL else 1.0), tc),
		Vector3(0, _y_cabeza, largo_cuerpo / 2.0 + tc * 0.35), piel)
	_hocico(tc, piel, detalle, negro)
	for lado in [1, -1]:
		var alto_ojo := tc * (0.3 if hocico == TipoHocico.REPTIL else 0.15)
		_caja(_cabeza, Vector3.ONE * tc * 0.15, Vector3(lado * tc * 0.27, alto_ojo, tc * 0.4), negro)
		match orejas:
			TipoOrejas.CORTAS:
				_caja(_cabeza, Vector3(tc * 0.25, tc * 0.25, tc * 0.15), Vector3(lado * tc * 0.35, tc * 0.6, -tc * 0.1), piel)
			TipoOrejas.LARGAS:
				_caja(_cabeza, Vector3(tc * 0.18, tc * 0.9, tc * 0.1), Vector3(lado * tc * 0.2, tc * 0.9, -tc * 0.1), piel)
			TipoOrejas.PUNTIAGUDAS:
				_caja(_cabeza, Vector3(tc * 0.25, tc * 0.4, tc * 0.12), Vector3(lado * tc * 0.3, tc * 0.65, -tc * 0.1), piel)

	_hacer_cola(piel, detalle)
	_hacer_detalles(detalle, oscuro, piel)

	# Patas: cada una cuelga de un pivote en la "cadera". Orden: DI, DD, TI, TD.
	var separacion := 0.6 if patas_abiertas else 0.35
	for z in [1, -1]:
		for x in [1, -1]:
			var cadera := Node3D.new()
			cadera.position = Vector3(x * ancho_cuerpo * separacion, largo_patas, z * largo_cuerpo * 0.35)
			if patas_abiertas:
				cadera.rotation.z = x * 0.5
			add_child(cadera)
			_caja(cadera, Vector3(ancho_cuerpo * 0.25, largo_patas, ancho_cuerpo * 0.25),
				Vector3(0, -largo_patas / 2.0, 0), piel)
			_patas.append(cadera)


func _hocico(tc: float, piel: Material, detalle: Material, negro: Material) -> void:
	match hocico:
		TipoHocico.CORTO:
			_caja(_cabeza, Vector3(tc * 0.5, tc * 0.35, tc * 0.2), Vector3(0, -tc * 0.15, tc * 0.55), detalle)
		TipoHocico.LARGO:  # hocico de cerdo, con la nariz plana (pecarí)
			_caja(_cabeza, Vector3(tc * 0.45, tc * 0.4, tc * 0.6), Vector3(0, -tc * 0.15, tc * 0.7), piel)
			_caja(_cabeza, Vector3(tc * 0.4, tc * 0.35, tc * 0.06), Vector3(0, -tc * 0.15, tc * 1.02), detalle)
		TipoHocico.TROMPA:  # trompa corta que cuelga (tapir)
			_caja(_cabeza, Vector3(tc * 0.35, tc * 0.32, tc * 0.6), Vector3(0, -tc * 0.12, tc * 0.75), piel)
			var punta := _caja(_cabeza, Vector3(tc * 0.25, tc * 0.45, tc * 0.2), Vector3(0, -tc * 0.4, tc * 1.0), piel)
			punta.rotation.x = 0.3
		TipoHocico.TUBO:  # hocico largo y finito (oso hormiguero)
			var tubo := _caja(_cabeza, Vector3(tc * 0.3, tc * 0.3, tc * 2.2), Vector3(0, -tc * 0.3, tc * 1.4), piel)
			tubo.rotation.x = 0.25
			_caja(tubo, Vector3.ONE * tc * 0.22, Vector3(0, 0, tc * 1.1), negro)
		TipoHocico.REPTIL:  # hocico largo y chato (yacaré)
			_caja(_cabeza, Vector3(tc * 0.75, tc * 0.3, tc * 1.6), Vector3(0, -tc * 0.12, tc * 1.15), piel)
			_caja(_cabeza, Vector3(tc * 0.7, tc * 0.05, tc * 1.5), Vector3(0, -tc * 0.28, tc * 1.15), detalle)


func _hacer_cola(piel: Material, detalle: Material) -> void:
	# La cola cuelga de un pivote para poder moverla.
	_cola = Node3D.new()
	_cola.position = Vector3(0, _y_cuerpo + alto_cuerpo * 0.3, -largo_cuerpo / 2.0)
	add_child(_cola)
	match cola:
		TipoCola.CORTA:
			var largo := largo_cuerpo * 0.15
			_caja(_cola, Vector3(ancho_cuerpo * 0.25, ancho_cuerpo * 0.25, largo), Vector3(0, 0, -largo / 2.0), piel)
		TipoCola.LARGA:
			var largo := largo_cuerpo * 0.7
			_caja(_cola, Vector3(ancho_cuerpo * 0.18, ancho_cuerpo * 0.18, largo), Vector3(0, -0.05, -largo / 2.0), piel)
			_caja(_cola, Vector3(ancho_cuerpo * 0.2, ancho_cuerpo * 0.2, largo * 0.2), Vector3(0, -0.05, -largo * 0.95), detalle)
		TipoCola.PELUDA:  # cola enorme y peluda (oso hormiguero)
			var largo := largo_cuerpo * 0.8
			var pelo := _caja(_cola, Vector3(ancho_cuerpo * 0.3, alto_cuerpo * 1.1, largo), Vector3(0, -alto_cuerpo * 0.2, -largo / 2.0), piel)
			pelo.rotation.x = -0.15
		TipoCola.REPTIL:  # cola larga y gruesa que se afina (yacaré)
			_cola.position.y = _y_cuerpo
			var largo := largo_cuerpo * 0.6
			_caja(_cola, Vector3(ancho_cuerpo * 0.55, alto_cuerpo * 0.7, largo), Vector3(0, 0, -largo / 2.0), piel)
			_caja(_cola, Vector3(ancho_cuerpo * 0.3, alto_cuerpo * 0.45, largo), Vector3(0, -alto_cuerpo * 0.1, -largo * 1.45), piel)
			if cresta:
				for i in 6:
					_caja(_cola, Vector3(0.06, 0.08, 0.1), Vector3(0, alto_cuerpo * 0.4 - i * 0.02, -0.15 - i * largo * 0.3), detalle)


func _hacer_detalles(detalle: Material, oscuro: Material, piel: Material) -> void:
	if manchas:
		# Siempre las mismas manchas (semilla fija), sobre el lomo y los costados.
		var azar := RandomNumberGenerator.new()
		azar.seed = 7
		for i in 14:
			var en_lomo := i % 2 == 0
			var z := azar.randf_range(-0.45, 0.45) * largo_cuerpo
			if en_lomo:
				_caja(_cuerpo, Vector3(0.12, 0.02, 0.12), Vector3(azar.randf_range(-0.3, 0.3) * ancho_cuerpo, alto_cuerpo / 2.0 + 0.005, z), oscuro)
			else:
				var lado := 1.0 if i % 4 == 1 else -1.0
				_caja(_cuerpo, Vector3(0.02, 0.1, 0.13), Vector3(lado * (ancho_cuerpo / 2.0 + 0.005), azar.randf_range(-0.25, 0.25) * alto_cuerpo, z), oscuro)
	if collar:
		_caja(_cuerpo, Vector3(ancho_cuerpo * 1.06, alto_cuerpo * 0.4, largo_cuerpo * 0.08),
			Vector3(0, alto_cuerpo * 0.15, largo_cuerpo * 0.42), detalle)
	if franja:
		var banda := _caja(_cuerpo, Vector3(ancho_cuerpo * 1.06, alto_cuerpo * 0.3, largo_cuerpo * 0.12),
			Vector3(0, 0, largo_cuerpo * 0.25), detalle)
		banda.rotation.x = 0.7
	if cresta:
		for i in 8:
			_caja(_cuerpo, Vector3(0.07, 0.08, 0.1), Vector3(0, alto_cuerpo / 2.0 + 0.03, largo_cuerpo * (0.4 - i * 0.11)), detalle)


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
	_cola.rotation.y = sin(_fase_cola) * (0.15 if cola == TipoCola.REPTIL else 0.4)
	# Bajar la cabeza al comer.
	var baja := tamano_cabeza * 0.6 if comiendo else 0.0
	_cabeza.position.y = lerpf(_cabeza.position.y, _y_cabeza - baja, 6.0 * delta)
	_cabeza.rotation.x = lerpf(_cabeza.rotation.x, 0.6 if comiendo else 0.0, 6.0 * delta)


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
