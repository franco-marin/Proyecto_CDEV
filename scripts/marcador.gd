extends Node3D
## Anillo que marca en el suelo el destino del animal.


func _process(delta: float) -> void:
	rotate_y(2.0 * delta)


func mostrar_en(punto: Vector3) -> void:
	global_position = punto + Vector3(0, 0.05, 0)
	visible = true


func ocultar() -> void:
	visible = false
