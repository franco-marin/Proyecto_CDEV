extends AnimalIA
## Carnívoro pequeño (zorro): caza herbívoros pequeños, ignora al jugador
## y huye de los carnívoros grandes.

@export var distancia_miedo_grandes := 7.0
@export var vision_caza := 14.0
@export var distancia_rendirse := 18.0
@export var tiempo_maximo_caza := 8.0


func _pensar() -> void:
	var grande := buscar_mas_cercano("carnivoros_grandes", distancia_miedo_grandes)
	if grande:
		huir_de(grande)
		return

	if estado == Estado.PERSEGUIR and continuar_persecucion(distancia_rendirse, tiempo_maximo_caza):
		return

	if tiene_hambre():
		var presa := buscar_mas_cercano("herbivoros_pequenos", vision_caza)
		if presa:
			perseguir(presa)
			return

	deambular()
