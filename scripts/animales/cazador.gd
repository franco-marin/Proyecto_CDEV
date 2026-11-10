extends AnimalIA
## Cazador furtivo: recorre el bosque, caza animales pequeños y, si ve al jugador,
## lo prefiere antes que cualquier otra presa. Se rinde si el jugador se aleja lo suficiente
## o si escapa por el río (los cazadores no lo cruzan). Si el yaguareté está escondido
## en la maleza, lo ve desde menos distancia.
## Mientras lo persigue, si lo tiene a tiro se frena, apunta y dispara. Los tiros nunca
## lastiman: siempre pegan al costado del yaguareté (el SDD pide evitar la violencia
## explícita). Sirven para asustar. Solo se pierde si un cazador te alcanza.
## En el clímax (ver climax.gd) cambia de modo: persigue sin tregua, cerca al yaguareté,
## se le traba el arma y termina huyendo asustado.

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

@export_group("Clímax")
## Velocidad corriendo en la persecución final (el yaguareté corre a 7).
@export var velocidad_persecucion := 6.2
## Formación de la persecución final: cuánto se abren hacia el costado los que siguen al
## líder y cuántos metros van más atrás que él.
@export var separacion_lateral := 6.0
@export var atraso_respecto_del_lider := 3.0

@export_group("Sonido")
## Probabilidad de pisar una rama seca en cada paso: baja en suelo abierto y mayor al
## atravesar la maleza.
@export var probabilidad_rama := 0.05
@export var probabilidad_rama_en_maleza := 0.3
## Velocidad huyendo asustado en la caza inversa. Es mayor que la del yaguareté furioso
## (8,4): no se lo puede alcanzar hasta que se cansa (ver cansarse()).
@export var velocidad_huida := 9.0

## Capas de física (Proyecto > Configuración > Nombres de Capas): 1 = terreno, 2 = obstáculos.
const MASCARA_TERRENO := 1
const MASCARA_OBSTACULOS := 2
## A menos de esta distancia del yaguareté, el tiro se anuncia en pantalla.
const DISTANCIA_AVISO_TIRO := 4.0

## Balas que le quedan en el cargador. Al llegar a 0 recarga (ver segundos_recarga).
var balas := 0
## Modos del clímax (los activa climax.gd con las funciones de abajo).
var implacable := false
var asustado := false
## Formación de la persecución final (la reparte climax.gd): el líder (el más cercano) va
## directo al yaguareté; el resto lo sigue un poco más atrás y abierto hacia un costado
## ("lado_en_formacion": -1 o 1), como intentando rodearlo. "rango" 1 es el primero de
## cada lado; los siguientes van más atrás.
var lider: Node3D = null
var lado_en_formacion := 0.0
var rango_en_formacion := 0

var _apuntando := 0.0
## Mientras cerca al yaguareté: a qué distancia se queda (negativo = no está cercando).
var _distancia_cerco := -1.0
## Se queda mirando al yaguareté (al cercarlo y con el arma trabada).
var _mirando_al_jugador := false
var _espera_disparo := 0.0
var _recargando := 0.0

@onready var sonido_disparo: AudioStreamPlayer3D = $Disparo
@onready var sonido_gatillo: AudioStreamPlayer3D = $Gatillo
@onready var sonido_recarga: AudioStreamPlayer3D = $Recarga
## Botas: suena una de las variantes (al azar) en cada paso del modelo.
@onready var sonido_pasos: AudioStreamPlayer3D = $Pasos
@onready var sonido_rama: AudioStreamPlayer3D = $Rama


func _ready() -> void:
	super()
	balas = balas_por_cargador
	# SDD: las "pisadas pesadas de botas" anuncian a los cazadores antes de verlos.
	modelo.paso.connect(_al_pisar)


## En cada paso suena la bota y, de vez en cuando, una rama seca que se quiebra
## (más seguido si va por la maleza).
func _al_pisar() -> void:
	sonido_pasos.play()
	var en_maleza := Mundo.hay_cobertura(global_position, 1.5)
	if randf() < (probabilidad_rama_en_maleza if en_maleza else probabilidad_rama):
		sonido_rama.play()


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
	elif _mirando_al_jugador and not _moviendose:
		var jugador := _jugador()
		if jugador:
			_girar_hacia(jugador.global_position, delta)


func _pensar() -> void:
	if asustado:
		_huir_sin_parar()
		return
	if _distancia_cerco > 0.0:
		_cercar()
		return
	# Mientras apunta no hace otra cosa: se queda quieto hasta disparar.
	if _apuntando > 0.0:
		return
	if implacable:
		_perseguir_sin_tregua()
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


# --- Clímax (lo controla climax.gd) ---------------------------------------------

## Persecución final: va por el yaguareté sin rendirse y disparando. No puede atraparlo:
## si llega a su lado se queda pegado a él (el jugador no pierde en el clímax).
func perseguir_sin_tregua() -> void:
	implacable = true
	velocidad_correr = velocidad_persecucion


## Acorralado: se acerca hasta "distancia" del yaguareté, se frena y se queda mirándolo.
func cercar(distancia: float) -> void:
	implacable = false
	_distancia_cerco = distancia
	_dejar_de_apuntar()


## Le apunta al yaguareté... con el cargador vacío.
func apuntar_sin_balas() -> void:
	balas = 0
	_recargando = 0.0
	_detener()
	_mirando_al_jugador = true
	modelo.apuntando = true


## Aprieta el gatillo y el arma no dispara.
func gatillar_trabado() -> void:
	modelo.trabar()
	if sonido_gatillo.stream:
		# Un poco distinto cada vez: al apretar rápido suena más desesperado.
		sonido_gatillo.pitch_scale = randf_range(0.92, 1.12)
		sonido_gatillo.play()


## Caza inversa: suelta el rifle y huye del yaguareté con los brazos en alto.
func huir_asustado() -> void:
	asustado = true
	implacable = false
	_distancia_cerco = -1.0
	_mirando_al_jugador = false
	_dejar_de_apuntar()
	modelo.asustado = true
	velocidad_correr = velocidad_huida
	_cambiar_estado(Estado.DEAMBULAR)  # para que huir_de() elija un destino nuevo enseguida


## Ya no da más: sigue huyendo, pero al paso (así el yaguareté lo alcanza).
func cansarse() -> void:
	velocidad_correr = velocidad_caminar
	_velocidad_actual = velocidad_caminar


## Huye del yaguareté sin frenar nunca: antes de llegar a su destino ya elige el siguiente.
## Si en ninguna dirección lejos del yaguareté hay salida (un borde, el río), escapa
## hacia cualquier punto lejano de su lado del río.
func _huir_sin_parar() -> void:
	var jugador := _jugador()
	if jugador == null:
		return
	if _moviendose and agente.distance_to_target() > 3.0:
		return
	_cambiar_estado(Estado.DEAMBULAR)  # así huir_de() elige un destino nuevo
	huir_de(jugador)
	if not _moviendose:
		_ir_a(Mundo.punto_aleatorio_lejos_de(jugador.global_position, 20.0), velocidad_correr)


func _perseguir_sin_tregua() -> void:
	var jugador := _jugador()
	if jugador == null:
		return
	perseguir(jugador)  # deja al jugador como objetivo (lo usan el aviso y la flecha del HUD)
	if _puede_disparar_a(jugador) and Mundo.mismo_lado_del_rio(global_position, jugador.global_position):
		_empezar_a_apuntar()
	elif distancia_a(jugador) <= radio_ataque + 0.5:
		_detener()  # pegado a él: no lo puede atrapar
	else:
		_seguir_en_formacion(jugador)


## Si no es el líder, en vez de ir derecho al yaguareté (todos en fila) va a su puesto:
## detrás del líder y abierto hacia su costado. Si ese puesto cae en el río o fuera del
## mapa, va directo al yaguareté.
func _seguir_en_formacion(jugador: Node3D) -> void:
	if lado_en_formacion == 0.0 or lider == self or not is_instance_valid(lider):
		return
	var hacia := jugador.global_position - lider.global_position
	hacia.y = 0.0
	if hacia.length() < 0.5:
		return
	hacia = hacia.normalized()
	var costado := Vector3(-hacia.z, 0, hacia.x)
	var atras := Mundo.distancia_horizontal(lider.global_position, jugador.global_position) \
		+ atraso_respecto_del_lider * rango_en_formacion
	var abierto := separacion_lateral * lado_en_formacion * (1.0 + 0.5 * (rango_en_formacion - 1))
	var puesto := Mundo.punto_navegable(jugador.global_position - hacia * atras + costado * abierto)
	if _destino_permitido(puesto):
		_ir_a(puesto, velocidad_correr)


func _cercar() -> void:
	var jugador := _jugador()
	if jugador == null:
		return
	if distancia_a(jugador) > _distancia_cerco + 0.5:
		perseguir(jugador)
	else:
		_detener()
		_mirando_al_jugador = true


func _jugador() -> Node3D:
	var jugador := get_tree().get_first_node_in_group("jugador") as Node3D
	return jugador if es_valido(jugador) else null


func _girar_hacia(punto: Vector3, delta: float) -> void:
	var hacia := punto - global_position
	modelo.rotation.y = lerp_angle(modelo.rotation.y, atan2(hacia.x, hacia.z), 10.0 * delta)


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
	# El click del martillo al amartillar el arma: avisa (también de oído) que viene un tiro.
	if sonido_gatillo.stream:
		sonido_gatillo.pitch_scale = 1.0
		sonido_gatillo.play()


## Quieto, girando hacia el yaguareté. Al terminar el tiempo de apuntar, dispara.
func _apuntar(delta: float) -> void:
	if not persigue_al_jugador():
		_dejar_de_apuntar()
		return
	_girar_hacia(objetivo.global_position, delta)
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
		# Un instante después del último tiro, para que no quede tapado por el disparo.
		if sonido_recarga.stream:
			get_tree().create_timer(0.5, false).timeout.connect(sonido_recarga.play)

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
	# Además del sonido, un aviso en pantalla (por si se juega sin parlantes o con poco volumen).
	if Mundo.distancia_horizontal(blanco, objetivo.global_position) <= DISTANCIA_AVISO_TIRO:
		objetivo.mensaje.emit("¡Un disparo pasó cerca!")


## true si entre los dos puntos no hay ningún obstáculo (troncos, tocones, límites).
func _linea_libre(desde: Vector3, hasta: Vector3) -> bool:
	var consulta := PhysicsRayQueryParameters3D.create(desde, hasta, MASCARA_OBSTACULOS, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(consulta).is_empty()
