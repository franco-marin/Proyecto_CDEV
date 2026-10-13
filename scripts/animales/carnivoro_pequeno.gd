extends AnimalIA
## Carnívoro pequeño (zorro): caza herbívoros pequeños, ignora al jugador
## y huye de los cazadores.

@export var distancia_miedo_cazadores := 10.0
@export var vision_caza := 14.0
@export var distancia_rendirse := 18.0
@export var tiempo_maximo_caza := 8.0


func _pensar() -> void:
	var cazador := buscar_mas_cercano("cazadores", distancia_miedo_cazadores)
	if cazador:
		huir_de(cazador)
		return

	if estado == Estado.PERSEGUIR and continuar_persecucion(distancia_rendirse, tiempo_maximo_caza):
		return

	if tiene_hambre():
		var presa := buscar_mas_cercano("herbivoros_pequenos", vision_caza)
		if presa:
			perseguir(presa)
			return

	deambular()
