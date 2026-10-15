@tool
extends MeshInstance3D
## Planta del sotobosque (tacuara, helecho, caraguatá o arbusto). No tiene colisión:
## el yaguareté la atraviesa, y el shader de vegetación la recorta a su alrededor.

@export var especie := FabricaFlora.Especie.ARBUSTO:
	set(valor):
		especie = valor
		_construir()
@export_range(0, 3) var variante := 0:
	set(valor):
		variante = valor
		_construir()


func _ready() -> void:
	_construir()


func _construir() -> void:
	if not is_inside_tree():
		return
	mesh = FabricaFlora.planta(especie, variante).malla
