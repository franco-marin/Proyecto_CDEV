extends Area3D
## Un arbusto con frutas. Cualquier herbívoro puede comérselo (el jugador también).

signal consumida(fruta: Node3D)

var disponible := true


func _ready() -> void:
	# Aparece "creciendo". Un Tween es una animación hecha por código.
	scale = Vector3.ONE * 0.01
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.5) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func puede_ser_objetivo() -> bool:
	return disponible


## Devuelve true si se la pudo comer, o false si otro llegó antes.
func comer() -> bool:
	if not disponible:
		return false
	disponible = false
	remove_from_group("comida")
	consumida.emit(self)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 0.01, 0.4)
	tween.tween_callback(queue_free)
	return true
