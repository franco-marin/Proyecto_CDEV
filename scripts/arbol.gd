extends StaticBody3D
## Árbol: varía un poco su tamaño para que el bosque no se vea repetido.

@onready var copa: MeshInstance3D = $Copa


func _ready() -> void:
	var tamano := randf_range(0.8, 1.3)
	copa.scale = Vector3.ONE * tamano
	copa.position.y = 1.3 + 1.2 * tamano  # la base de la copa queda sobre el tronco
	rotation.y = randf() * TAU


## Dónde se posan los pájaros: la punta de la copa.
func punto_posado() -> Vector3:
	return global_position + Vector3(0, copa.position.y + 1.2 * copa.scale.y, 0)
