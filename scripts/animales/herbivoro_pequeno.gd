extends AnimalIA
## Herbívoro pequeño (conejo): come fruta, compite con el jugador por ella
## y huye tanto del jugador como de cualquier carnívoro.

@export var distancia_miedo_jugador := 6.0
@export var distancia_miedo_carnivoros := 9.0
@export var vision_comida := 15.0


func _pensar() -> void:
	# 1) Lo más importante: sobrevivir.
	var amenaza := buscar_mas_cercano("carnivoros", distancia_miedo_carnivoros)
	if amenaza == null:
		amenaza = buscar_mas_cercano("jugador", distancia_miedo_jugador)
	if amenaza:
		huir_de(amenaza)
		return

	# 2) Si ya iba hacia una fruta, seguir.
	if estado == Estado.IR_A_COMIDA and continuar_hacia_comida():
		return

	# 3) Si tiene hambre, buscar fruta.
	if tiene_hambre():
		var fruta := buscar_mas_cercano("comida", vision_comida)
		if fruta:
			ir_a_comida(fruta)
			return

	# 4) Si no, pasear.
	deambular()
