extends AnimalIA
## Carnívoro pequeño (zorro): caza herbívoros pequeños y huye de los cazadores
## y del yaguareté (que puede cazarlo).

@export var distancia_miedo_cazadores := 10.0
@export var distancia_miedo_yaguarete := 7.0
@export var vision_caza := 14.0
@export var distancia_rendirse := 18.0
@export var tiempo_maximo_caza := 8.0


func _pensar() -> void:
	var amenaza := buscar_mas_cercano("cazadores", distancia_miedo_cazadores)
	if amenaza == null:
		amenaza = buscar_mas_cercano("jugador", distancia_miedo_yaguarete)
	if amenaza:
		huir_de(amenaza)
		return

	if estado == Estado.PERSEGUIR and continuar_persecucion(distancia_rendirse, tiempo_maximo_caza):
		return

	if tiene_hambre():
		var presa := buscar_mas_cercano("herbivoros_pequenos", vision_caza)
		if presa:
			perseguir(presa)
			return

	deambular()
