extends AnimalIA
## Yacaré: vive en el río y sus orillas. Toma sol en la orilla, se mete al agua si el
## yaguareté se acerca por tierra y, si lo encuentra nadando, lo muerde (le quita hambre).
## En tierra es lento; en el agua, rápido. El yaguareté puede cazarlo.

@export var distancia_alarma := 7.0
@export var alcance_mordida := 2.2
@export var hambre_por_mordida := 15.0
@export var espera_entre_mordidas := 3.0

var _espera_mordida := 0.0


func _physics_process(delta: float) -> void:
	super(delta)
	_espera_mordida = maxf(_espera_mordida - delta, 0.0)


func _pensar() -> void:
	var jugador = get_tree().get_first_node_in_group("jugador")
	if es_valido(jugador) and Mundo.rio != null:
		var distancia := distancia_a(jugador)
		if jugador.nadando:
			# Al que nada lo muerde; y si está cerca, va por él.
			if distancia <= alcance_mordida and _espera_mordida <= 0.0:
				_morder(jugador)
				return
			if en_agua and distancia <= distancia_alarma * 1.5:
				_cambiar_estado(Estado.PERSEGUIR)
				objetivo = jugador
				_ir_a(jugador.global_position, velocidad_correr)
				return
		elif not en_agua and distancia <= distancia_alarma:
			# Si el yaguareté se acerca por tierra, se tira al agua.
			_cambiar_estado(Estado.HUIR)
			objetivo = jugador
			_ir_a(Mundo.rio.punto_de_agua_cercano(global_position), velocidad_correr)
			return
	deambular()


## Pasea por el río y sus orillas.
func _centro_de_deambular() -> Vector3:
	if Mundo.rio == null:
		return global_position
	return Mundo.rio.punto_de_agua_cercano(global_position)


func _morder(jugador) -> void:
	_espera_mordida = espera_entre_mordidas
	jugador.recibir_mordida(hambre_por_mordida)
	# Embestida corta para que se note la mordida.
	var escala: Vector3 = modelo.scale
	var tween := create_tween()
	tween.tween_property(modelo, "scale", escala * Vector3(1.0, 1.0, 1.25), 0.08)
	tween.tween_property(modelo, "scale", escala, 0.15)
