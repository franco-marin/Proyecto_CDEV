extends AnimalIA
## Cazador furtivo: recorre el bosque, caza animales pequeños y, si ve al jugador,
## lo prefiere antes que cualquier otra presa. Se rinde si el jugador se aleja lo suficiente
## o si escapa por el río (los cazadores no lo cruzan). Si el yaguareté está escondido
## en la maleza, lo ve desde menos distancia.
## Mientras lo persigue, si lo tiene a tiro se frena, apunta y dispara. Los tiros nunca
## lastiman: siempre pegan al costado del yaguareté (el SDD pide evitar la violencia
## explícita). Sirven para asustar. Solo se pierde si un cazador te alcanza.

@export var vision_jugador := 15.0
@export var distancia_rendirse_jugador := 20.0
@export var vision_caza := 12.0
@export var distancia_rendirse_caza := 16.0
@export var tiempo_maximo_caza := 10.0

@export_group("Rifle")
## Dispara si el yaguareté está entre estas distancias (más cerca prefiere atraparlo).
@export var distancia_disparo_minima := 5.0
@export var distancia_disparo_maxima := 14.0
## Segundos que se queda quieto apuntando antes del disparo: es el aviso para el jugador.
@export var segundos_apuntando := 0.7
@export var segundos_entre_disparos := 2.5
@export var balas_por_cargador := 3
@export var segundos_recarga := 4.0
## A cuántos metros del yaguareté pega el tiro (siempre al costado, nunca encima).
@export var error_minimo := 1.2
@export var error_maximo := 3.0

## Capas de física (Proyecto > Configuración > Nombres de Capas): 1 = terreno, 2 = obstáculos.
const MASCARA_TERRENO := 1
const MASCARA_OBSTACULOS := 2
## A menos de esta distancia del yaguareté, el tiro se anuncia en pantalla.
const DISTANCIA_AVISO_TIRO := 4.0

## Balas que le quedan en el cargador. Al llegar a 0 recarga (ver segundos_recarga).
var balas := 0

var _apuntando := 0.0
var _espera_disparo := 0.0
var _recargando := 0.0

@onready var sonido_disparo: AudioStreamPlayer3D = $Disparo


func _ready() -> void:
	super()
	balas = balas_por_cargador


func _physics_process(delta: float) -> void:
	super(delta)
	if not vivo:
		return
	_espera_disparo -= delta
	if _recargando > 0.0:
		_recargando -= delta
		if _recargando <= 0.0:
			balas = balas_por_cargador
	if _apuntando > 0.0:
		_apuntar(delta)


func _pensar() -> void:
	# Mientras apunta no hace otra cosa: se queda quieto hasta disparar.
	if _apuntando > 0.0:
		return

	# 1) Si ya persigue al jugador, no lo suelta hasta que se aleje demasiado.
	if persigue_al_jugador():
		if objetivo.nadando or not Mundo.mismo_lado_del_rio(global_position, objetivo.global_position):
			deambular()  # se escapó por el río: se rinde
		elif _puede_disparar_a(objetivo):
			_empezar_a_apuntar()
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


# --- Rifle ---------------------------------------------------------------------

## Le puede disparar si tiene balas, ya pasó la espera entre tiros, está a distancia de
## tiro y no hay un tronco en el medio.
func _puede_disparar_a(jugador: Node3D) -> bool:
	if balas <= 0 or _espera_disparo > 0.0:
		return false
	var distancia := distancia_a(jugador)
	if distancia < distancia_disparo_minima or distancia > distancia_disparo_maxima:
		return false
	return _linea_libre(global_position + Vector3.UP * 1.4, jugador.global_position + Vector3.UP * 0.6)


func _empezar_a_apuntar() -> void:
	_apuntando = segundos_apuntando
	_detener()
	modelo.apuntando = true


## Quieto, girando hacia el yaguareté. Al terminar el tiempo de apuntar, dispara.
func _apuntar(delta: float) -> void:
	if not persigue_al_jugador():
		_dejar_de_apuntar()
		return
	var hacia: Vector3 = objetivo.global_position - global_position
	modelo.rotation.y = lerp_angle(modelo.rotation.y, atan2(hacia.x, hacia.z), 10.0 * delta)
	_apuntando -= delta
	if _apuntando <= 0.0:
		_disparar()
		_dejar_de_apuntar()


func _dejar_de_apuntar() -> void:
	_apuntando = 0.0
	modelo.apuntando = false


## El tiro va a un punto del suelo al costado del yaguareté. Si en el camino hay un
## tronco, pega en el tronco. El jugador y los animales no están en la máscara del rayo,
## así que el tiro nunca les pega.
func _disparar() -> void:
	balas -= 1
	_espera_disparo = segundos_entre_disparos
	if balas <= 0:
		_recargando = segundos_recarga

	var canon: Vector3 = modelo.punta_del_canon()
	var al_costado := Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * randf_range(error_minimo, error_maximo)
	var blanco: Vector3 = objetivo.global_position + al_costado
	blanco.y = 0.0
	# El rayo sigue un poco más allá del blanco para asegurarse de tocar el suelo.
	var consulta := PhysicsRayQueryParameters3D.create(canon, canon + (blanco - canon) * 1.2,
		MASCARA_TERRENO | MASCARA_OBSTACULOS, [get_rid()])
	var golpe := get_world_3d().direct_space_state.intersect_ray(consulta)
	var en_un_tronco := false
	if not golpe.is_empty():
		blanco = golpe.position
		en_un_tronco = golpe.collider is CollisionObject3D \
			and ((golpe.collider as CollisionObject3D).collision_layer & MASCARA_OBSTACULOS) != 0

	modelo.disparar()
	Efectos.fogonazo(get_parent(), canon, blanco - canon)
	Efectos.impacto(get_parent(), blanco, en_un_tronco)
	if sonido_disparo.stream:
		sonido_disparo.pitch_scale = randf_range(0.9, 1.1)
		sonido_disparo.play()
	# Mientras no haya sonido, el aviso en pantalla deja claro que le dispararon.
	if Mundo.distancia_horizontal(blanco, objetivo.global_position) <= DISTANCIA_AVISO_TIRO:
		objetivo.mensaje.emit("¡Un disparo pasó cerca!")


## true si entre los dos puntos no hay ningún obstáculo (troncos, tocones, límites).
func _linea_libre(desde: Vector3, hasta: Vector3) -> bool:
	var consulta := PhysicsRayQueryParameters3D.create(desde, hasta, MASCARA_OBSTACULOS, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(consulta).is_empty()
