class_name AnimalIA
extends CharacterBody3D
## Comportamiento común a todos los animales que controla la computadora.
## Cada especie hereda de este script ("extends AnimalIA") y redefine _pensar()
## para decidir qué hacer; aquí están las acciones: deambular, huir, perseguir, comer.

enum Estado { DEAMBULAR, HUIR, PERSEGUIR, IR_A_COMIDA }

const INTERVALO_PENSAR := 0.25

@export var velocidad_caminar := 2.0
@export var velocidad_correr := 5.0
@export var radio_deambular := 10.0
## Distancia a la que puede comer una fruta o atrapar a una presa.
@export var radio_ataque := 1.0
## Segundos entre comidas (se elige un valor al azar entre ambos).
@export var hambre_minima := 15.0
@export var hambre_maxima := 35.0

@export_group("Como presa del yaguareté")
## Cuántos zarpazos aguanta antes de caer.
@export var vida := 1
## Cuánta hambre le quita al yaguareté comérselo.
@export var valor_alimenticio := 30.0

@export_group("Agua")
## Si puede meterse al río (carpinchos y yacarés). Los demás animales nunca lo cruzan.
@export var puede_nadar := false
## Velocidad en el agua respecto de la velocidad en tierra.
@export var multiplicador_en_agua := 0.6
## Cuánto se hunde el cuerpo al nadar.
@export var profundidad_nado := 0.3

## Segundos que queda en el suelo después de caer, si nadie se lo come.
const SEGUNDOS_ABATIDO := 60.0
## Si el yaguareté está escondido en la maleza, lo ven desde la mitad de distancia.
const FACTOR_COBERTURA := 0.5

var estado: Estado = Estado.DEAMBULAR
## Lo que está persiguiendo, de lo que huye o la fruta a la que va. Sin tipo a propósito:
## puede ser una fruta, otro animal o el jugador.
var objetivo = null
var tiempo_en_estado := 0.0
var vivo := true
## Cayó por los zarpazos del yaguareté y está en el suelo, listo para ser comido.
var abatido := false
## Está dentro del río (solo los que pueden nadar llegan a estarlo).
var en_agua := false

var _velocidad_actual := 0.0
var _moviendose := false
var _pausa := 0.0
var _tiempo_para_hambre := 0.0
var _reloj_pensar := 0.0
var _gravedad: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var agente: NavigationAgent3D = $Agente
## Sin tipo a propósito: puede ser un ModeloAnimal o un ModeloHumano (ambos tienen "velocidad").
@onready var modelo = $Modelo


func _ready() -> void:
	# Valores al azar para que no todos hagan lo mismo al mismo tiempo.
	_tiempo_para_hambre = randf_range(hambre_minima * 0.3, hambre_maxima)
	_pausa = randf_range(0.0, 2.0)
	_reloj_pensar = randf() * INTERVALO_PENSAR
	modelo.rotation.y = randf() * TAU


func _physics_process(delta: float) -> void:
	if not vivo:
		return
	tiempo_en_estado += delta
	_tiempo_para_hambre -= delta
	if not _moviendose:
		_pausa -= delta

	# Pensar 4 veces por segundo alcanza y es mucho más barato que hacerlo en cada frame.
	_reloj_pensar -= delta
	if _reloj_pensar <= 0.0:
		_reloj_pensar = INTERVALO_PENSAR
		_pensar()

	_mover(delta)


## Cada especie lo redefine con sus propias prioridades.
func _pensar() -> void:
	deambular()


# --- Acciones ------------------------------------------------------------------

func deambular() -> void:
	if estado != Estado.DEAMBULAR:
		_cambiar_estado(Estado.DEAMBULAR)
		objetivo = null
		_detener()
		_pausa = randf_range(0.5, 2.0)
	if not _moviendose and _pausa <= 0.0:
		_ir_a(Mundo.punto_aleatorio_cerca(_centro_de_deambular(), radio_deambular), velocidad_caminar)
		_pausa = randf_range(1.5, 4.0)  # descanso al llegar


## Alrededor de qué punto pasea. Las especies pueden redefinirlo (la manada, el río...).
func _centro_de_deambular() -> Vector3:
	return global_position


## Devuelve al yaguareté si lo ve a menos de "distancia". Si está escondido en la
## maleza, solo lo ve desde la mitad de esa distancia.
func ver_al_jugador(distancia: float) -> Node3D:
	var jugador = get_tree().get_first_node_in_group("jugador")
	if not es_valido(jugador):
		return null
	if jugador.oculto:
		distancia *= FACTOR_COBERTURA
	return jugador if distancia_a(jugador) <= distancia else null


func huir_de(amenaza: Node3D) -> void:
	var ya_huia: bool = estado == Estado.HUIR and objetivo == amenaza and _moviendose
	_cambiar_estado(Estado.HUIR)
	objetivo = amenaza
	if ya_huia:
		return
	var lejos := global_position - amenaza.global_position
	lejos.y = 0.0
	if lejos.length() < 0.1:
		lejos = Vector3.FORWARD
	# Un poco de azar en la dirección para no quedar acorralado contra los bordes.
	lejos = lejos.normalized().rotated(Vector3.UP, randf_range(-0.6, 0.6))
	# Si en esa dirección hay un borde o el río (y no sabe nadar), prueba girando de a poco.
	var giro := PI / 3.0 * signf(randf() - 0.5)
	for intento in 5:
		var destino := Mundo.punto_navegable(global_position + lejos.rotated(Vector3.UP, giro * intento) * 8.0)
		if Mundo.distancia_horizontal(destino, global_position) >= 3.0 and _destino_permitido(destino):
			_ir_a(destino, velocidad_correr)
			return


## Los que no nadan solo pueden ir a puntos de su lado del río y fuera del agua.
func _destino_permitido(punto: Vector3) -> bool:
	return puede_nadar or (Mundo.mismo_lado_del_rio(global_position, punto) and not Mundo.en_agua(punto, 1.0))


func perseguir(presa: Node3D) -> void:
	if estado != Estado.PERSEGUIR or objetivo != presa:
		_cambiar_estado(Estado.PERSEGUIR)
		objetivo = presa
	_ir_a(presa.global_position, velocidad_correr)


func ir_a_comida(fruta: Node3D) -> void:
	if estado != Estado.IR_A_COMIDA or objetivo != fruta:
		_cambiar_estado(Estado.IR_A_COMIDA)
		objetivo = fruta
		_ir_a(fruta.global_position, velocidad_caminar)


## Sigue persiguiendo al objetivo. Devuelve false si lo atrapó o si se rindió.
func continuar_persecucion(distancia_rendirse: float, tiempo_maximo: float) -> bool:
	if not es_valido(objetivo) or tiempo_en_estado > tiempo_maximo \
			or distancia_a(objetivo) > distancia_rendirse:
		_tiempo_para_hambre = maxf(_tiempo_para_hambre, 6.0)  # se cansa y descansa un rato
		deambular()
		return false
	if distancia_a(objetivo) <= radio_ataque:
		_atrapar(objetivo)
		deambular()
		return false
	perseguir(objetivo)
	return true


## Sigue yendo hacia la fruta elegida. Devuelve false si se la comió o si desapareció.
func continuar_hacia_comida() -> bool:
	if not es_valido(objetivo):
		deambular()
		return false
	if distancia_a(objetivo) <= radio_ataque:
		if objetivo.comer():
			saciar()
		deambular()
		return false
	return true


## Qué pasa al alcanzar a la presa. Las especies pueden redefinirlo.
func _atrapar(presa) -> void:
	presa.morir()
	saciar()


## Muere atrapado por otro animal (zorro o cazador): desaparece enseguida.
func morir() -> void:
	if not vivo:
		return
	vivo = false
	_salir_de_los_grupos()
	$Colision.set_deferred("disabled", true)
	_desaparecer(0.4)


## Recibe un zarpazo del yaguareté. Si le quedan fuerzas, escapa corriendo.
func recibir_golpe(atacante: Node3D) -> void:
	if not vivo:
		return
	vida -= 1
	_al_ser_atacado(atacante)
	# Pequeño sacudón para que se note el golpe.
	var escala: Vector3 = modelo.scale
	var tween := create_tween()
	tween.tween_property(modelo, "scale", escala * 1.25, 0.06)
	tween.tween_property(modelo, "scale", escala, 0.1)
	if vida <= 0:
		_abatir()
	else:
		_moviendose = false
		huir_de(atacante)


## Las especies pueden redefinirlo, por ejemplo para avisarle a su manada.
func _al_ser_atacado(_atacante: Node3D) -> void:
	pass


## El yaguareté se lo come: devuelve cuánto alimenta (0 si ya no está disponible).
func ser_comido() -> float:
	if not abatido:
		return 0.0
	abatido = false
	remove_from_group("presas_abatidas")
	_desaparecer(0.8)
	return valor_alimenticio


## Cae al suelo, de costado. Queda ahí para que el yaguareté se lo coma.
func _abatir() -> void:
	vivo = false
	abatido = true
	_salir_de_los_grupos()
	add_to_group("presas_abatidas")
	$Colision.set_deferred("disabled", true)
	velocity = Vector3.ZERO
	modelo.velocidad = 0.0
	modelo.set_process(false)  # deja de mover las patas y la cola
	var tween := create_tween().set_parallel()
	tween.tween_property(modelo, "rotation:z", PI / 2.0, 0.35)
	tween.tween_property(modelo, "position:y", 0.12, 0.35)
	# Si nadie se lo come, después de un rato desaparece.
	var espera := create_tween()
	espera.tween_interval(SEGUNDOS_ABATIDO)
	espera.tween_callback(_vencer_abatido)


func _vencer_abatido() -> void:
	if abatido:
		abatido = false
		remove_from_group("presas_abatidas")
		_desaparecer(1.0)


## Salir de los grupos para que nadie más lo elija como presa.
func _salir_de_los_grupos() -> void:
	for grupo in get_groups():
		if not String(grupo).begins_with("_"):
			remove_from_group(grupo)


func _desaparecer(segundos: float) -> void:
	var tween := create_tween()
	tween.tween_property(modelo, "scale", Vector3.ONE * 0.01, segundos)
	tween.tween_callback(queue_free)


# --- Utilidades ----------------------------------------------------------------

func puede_ser_objetivo() -> bool:
	return vivo


func tiene_hambre() -> bool:
	return _tiempo_para_hambre <= 0.0


func saciar() -> void:
	_tiempo_para_hambre = randf_range(hambre_minima, hambre_maxima)


## El nodo más cercano de un grupo dentro de un radio, o null si no hay ninguno.
func buscar_mas_cercano(grupo: String, radio: float) -> Node3D:
	var mejor: Node3D = null
	var mejor_distancia := radio
	for nodo in get_tree().get_nodes_in_group(grupo):
		if nodo == self or not es_valido(nodo):
			continue
		var distancia := distancia_a(nodo)
		if distancia < mejor_distancia:
			mejor = nodo
			mejor_distancia = distancia
	return mejor


func es_valido(nodo) -> bool:
	return nodo != null and is_instance_valid(nodo) and nodo.puede_ser_objetivo()


func distancia_a(nodo: Node3D) -> float:
	return Mundo.distancia_horizontal(global_position, nodo.global_position)


# --- Movimiento ----------------------------------------------------------------

func _cambiar_estado(nuevo: Estado) -> void:
	if nuevo != estado:
		estado = nuevo
		tiempo_en_estado = 0.0


func _ir_a(punto: Vector3, velocidad: float) -> void:
	# Los que no nadan nunca eligen un destino al otro lado del río.
	if not _destino_permitido(punto):
		_moviendose = false
		return
	agente.target_position = punto
	_velocidad_actual = velocidad
	_moviendose = true


func _detener() -> void:
	_moviendose = false


func _mover(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravedad * delta

	var horizontal := Vector3.ZERO
	if _moviendose:
		if agente.is_navigation_finished():
			_moviendose = false
		else:
			# El agente de navegación nos da el próximo punto del camino que esquiva árboles.
			var direccion := agente.get_next_path_position() - global_position
			direccion.y = 0.0
			if direccion.length() > 0.05:
				direccion = direccion.normalized()
				horizontal = direccion * _velocidad_actual
				modelo.rotation.y = lerp_angle(modelo.rotation.y, atan2(direccion.x, direccion.z), 8.0 * delta)

	# Agua: los que no nadan se frenan en la orilla; los que nadan cambian de velocidad.
	if Mundo.rio != null and horizontal != Vector3.ZERO:
		if puede_nadar:
			en_agua = Mundo.en_agua(global_position)
			if en_agua:
				horizontal *= multiplicador_en_agua
		elif Mundo.en_agua(global_position + horizontal.normalized() * 0.8, 0.3):
			horizontal = Vector3.ZERO
			_moviendose = false
	if puede_nadar:
		var hundido := -profundidad_nado if en_agua else 0.0
		modelo.position.y = lerpf(modelo.position.y, hundido, 5.0 * delta)

	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()
	modelo.velocidad = horizontal.length()
