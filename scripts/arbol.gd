@tool
extends StaticBody3D
## Árbol de la selva (palo rosa, timbó, lapacho, pindó o chachí) o lo que queda de él
## después de la tala (tocón o árbol caído). La malla la arma FabricaFlora; acá solo se
## ajusta la colisión. Con @tool se ve en el editor.

@export var especie := FabricaFlora.Especie.PALO_ROSA:
	set(valor):
		especie = valor
		_construir()
@export_range(0, 3) var variante := 0:
	set(valor):
		variante = valor
		_construir()

var _datos := {}


func _ready() -> void:
	_construir()


func _construir() -> void:
	if not is_inside_tree():
		return
	_datos = FabricaFlora.planta(especie, variante)
	$Malla.mesh = _datos.malla
	var alto: float = _datos.get("alto_colision", 4.0)
	var forma := CylinderShape3D.new()
	forma.radius = _datos.radio_tronco
	forma.height = alto
	$Colision.shape = forma
	$Colision.position.y = alto / 2.0

	# El árbol talado tiene además el tronco caído en el suelo, que también es un obstáculo.
	if has_node("ColisionTronco"):
		var vieja := $ColisionTronco
		remove_child(vieja)
		vieja.queue_free()
	if _datos.has("caja"):
		var caja := BoxShape3D.new()
		caja.size = _datos.caja.medidas
		var colision := CollisionShape3D.new()
		colision.name = "ColisionTronco"
		colision.shape = caja
		colision.position = _datos.caja.centro
		colision.rotation.y = _datos.caja.giro
		add_child(colision)

	# Sin copa no hay dónde posarse: los pájaros eligen solo entre los del grupo "arboles".
	if FabricaFlora.es_talado(especie) and not Engine.is_editor_hint():
		remove_from_group("arboles")


## Dónde se posan los pájaros: una rama baja de la copa, o la punta en palmeras y helechos.
func punto_posado() -> Vector3:
	return to_global(_datos.posado)
