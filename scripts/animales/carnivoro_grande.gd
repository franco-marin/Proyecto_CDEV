extends AnimalIA
## Carnívoro grande (oso): lento, caza animales pequeños y, si ve al jugador,
## lo prefiere antes que cualquier otra presa. Se rinde si el jugador se aleja lo suficiente.

@export var vision_jugador := 15.0
@export var distancia_rendirse_jugador := 20.0
@export var vision_caza := 12.0
@export var distancia_rendirse_caza := 16.0
@export var tiempo_maximo_caza := 10.0


func _pensar() -> void:
	# 1) Si ya persigue al jugador, no lo suelta hasta que se aleje demasiado.
	if persigue_al_jugador():
		continuar_persecucion(distancia_rendirse_jugador, INF)
		return

	# 2) Si ve al jugador, va por él (aunque estuviera cazando otra cosa).
	var jugador := buscar_mas_cercano("jugador", vision_jugador)
	if jugador:
		perseguir(jugador)
		return

	# 3) Seguir cazando lo que estaba cazando.
	if estado == Estado.PERSEGUIR and continuar_persecucion(distancia_rendirse_caza, tiempo_maximo_caza):
		return

	# 4) Buscar presa pequeña si tiene hambre.
	if tiene_hambre():
		var presa := buscar_mas_cercano("animales_pequenos", vision_caza)
		if presa:
			perseguir(presa)
			return

	deambular()


func persigue_al_jugador() -> bool:
	return estado == Estado.PERSEGUIR and es_valido(objetivo) and objetivo.is_in_group("jugador")


func _atrapar(presa) -> void:
	if presa.is_in_group("jugador"):
		presa.ser_devorado()
	else:
		super(presa)
