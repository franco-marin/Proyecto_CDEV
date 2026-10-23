extends AnimalIA
## Cazador furtivo: recorre el bosque, caza animales pequeños y, si ve al jugador,
## lo prefiere antes que cualquier otra presa. Se rinde si el jugador se aleja lo suficiente
## o si escapa por el río (los cazadores no lo cruzan). Si el yaguareté está escondido
## en la maleza, lo ve desde menos distancia.

@export var vision_jugador := 15.0
@export var distancia_rendirse_jugador := 20.0
@export var vision_caza := 12.0
@export var distancia_rendirse_caza := 16.0
@export var tiempo_maximo_caza := 10.0


func _pensar() -> void:
	# 1) Si ya persigue al jugador, no lo suelta hasta que se aleje demasiado.
	if persigue_al_jugador():
		if objetivo.nadando or not Mundo.mismo_lado_del_rio(global_position, objetivo.global_position):
			deambular()  # se escapó por el río: se rinde
		else:
			continuar_persecucion(distancia_rendirse_jugador, INF)
		return

	# 2) Si ve al jugador, va por él (aunque estuviera cazando otra cosa).
	var jugador = ver_al_jugador(vision_jugador)  # sin tipo: se usa "nadando", propio del jugador
	if jugador and not jugador.nadando and Mundo.mismo_lado_del_rio(global_position, jugador.global_position):
		perseguir(jugador)
		return

	# 3) Seguir cazando lo que estaba cazando.
	if estado == Estado.PERSEGUIR and continuar_persecucion(distancia_rendirse_caza, tiempo_maximo_caza):
		return

	# 4) Buscar presa pequeña si quiere cazar.
	if tiene_hambre():
		var presa := buscar_mas_cercano("presas", vision_caza)
		if presa:
			perseguir(presa)
			return

	deambular()


func persigue_al_jugador() -> bool:
	return estado == Estado.PERSEGUIR and es_valido(objetivo) and objetivo.is_in_group("jugador")


func _atrapar(presa) -> void:
	if presa.is_in_group("jugador"):
		presa.ser_capturado()
	else:
		super(presa)
