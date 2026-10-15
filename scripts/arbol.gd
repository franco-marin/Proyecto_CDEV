@tool
extends StaticBody3D
## Árbol de la selva (palo rosa, timbó, lapacho, pindó o chachí). La malla la arma
## FabricaFlora; acá solo se ajusta la colisión del tronco. Con @tool se ve en el editor.

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
	var forma := CylinderShape3D.new()
	forma.radius = _datos.radio_tronco
	forma.height = 4.0
	$Colision.shape = forma
	$Colision.position.y = 2.0


## Dónde se posan los pájaros: una rama baja de la copa, o la punta en palmeras y helechos.
func punto_posado() -> Vector3:
	return to_global(_datos.posado)
