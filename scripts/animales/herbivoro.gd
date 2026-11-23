extends AnimalIA
## Herbívoro de la selva (tapir, pecarí, corzuela, carpincho, oso hormiguero).
## Huye de los cazadores, de los carnívoros y del yaguareté; cuando tiene hambre busca
## su comida (fruta o termiteros) y, si no encuentra, mordisquea lo que haya (pasta).
## Opciones para cada especie:
##   - en_manada: anda en grupo y, si atacan a uno, huye toda la manada (pecarí).
##   - vive_cerca_del_rio: pasea junto al río y se mete al agua para escapar (carpincho).

@export var distancia_miedo_jugador := 7.0
@export var distancia_miedo_carnivoros := 6.0
@export var distancia_miedo_cazadores := 12.0
@export var vision_comida := 15.0
## Grupo de lo que come: "comida" (fruta) o "termiteros" (oso hormiguero).
@export var grupo_comida := "comida"
@export var en_manada := false
@export var vive_cerca_del_rio := false

## Número de manada (lo asigna main.gd). Los de la misma manada andan juntos.
var manada := -1

var _segundos_pastando := 0.0


func _pensar() -> void:
	# 1) Lo más importante: sobrevivir.
	var amenaza := buscar_mas_cercano("cazadores", distancia_miedo_cazadores)
	if amenaza == null and distancia_miedo_carnivoros > 0.0:
		amenaza = buscar_mas_cercano("carnivoros", distancia_miedo_carnivoros)
	if amenaza == null:
		amenaza = ver_al_jugador(distancia_miedo_jugador)
	if amenaza:
		_dejar_de_pastar()
		huir_de(amenaza)
		return

	# 2) Si está comiendo, sigue un rato con la cabeza gacha.
	if _segundos_pastando > 0.0:
		_segundos_pastando -= INTERVALO_PENSAR
		if _segundos_pastando <= 0.0:
			_dejar_de_pastar()
		return

	# 3) Si ya iba hacia su comida, seguir.
	if estado == Estado.IR_A_COMIDA:
		if continuar_hacia_comida():
			return
		if not tiene_hambre():
			_pastar(2.0)  # llegó y comió: se queda un momento comiendo
			return

	# 4) Si tiene hambre, buscar su comida; si no hay cerca, pastar lo que encuentre.
	if tiene_hambre():
		var comida := buscar_mas_cercano(grupo_comida, vision_comida)
		if comida:
			ir_a_comida(comida)
			return
		if randf() < 0.3:
			_pastar(randf_range(2.0, 4.0))
			saciar()
			return

	# 5) Si no, pasear.
	deambular()


## Los carpinchos escapan metiéndose al río.
func huir_de(amenaza: Node3D) -> void:
	if vive_cerca_del_rio and Mundo.rio != null and not en_agua:
		_cambiar_estado(Estado.HUIR)
		objetivo = amenaza
		_ir_a(Mundo.rio.punto_de_agua_cercano(global_position), velocidad_correr)
		return
	super(amenaza)


## La manada pasea alrededor de su centro; los carpinchos, alrededor del río.
func _centro_de_deambular() -> Vector3:
	if en_manada:
		var suma := Vector3.ZERO
		var cuantos := 0
		for nodo in get_tree().get_nodes_in_group("pecaries"):
			var otro = nodo  # sin tipo: es otro herbívoro
			if otro.manada == manada:
				suma += otro.global_position
				cuantos += 1
		if cuantos > 0:
			return suma / cuantos
	if vive_cerca_del_rio and Mundo.rio != null:
		var agua := Mundo.rio.punto_de_agua_cercano(global_position)
		if Mundo.distancia_horizontal(agua, global_position) > 10.0:
			return agua
	return global_position


## Si atacan a un pecarí, huye toda su manada.
func _al_ser_atacado(atacante: Node3D) -> void:
	if not en_manada:
		return
	for nodo in get_tree().get_nodes_in_group("pecaries"):
		var otro = nodo  # sin tipo: es otro herbívoro
		if otro != self and otro.manada == manada and otro.vivo:
			otro.huir_de(atacante)


func _pastar(segundos: float) -> void:
	_segundos_pastando = segundos
	_detener()
	modelo.comiendo = true


func _dejar_de_pastar() -> void:
	_segundos_pastando = 0.0
	modelo.comiendo = false
