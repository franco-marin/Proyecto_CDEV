extends CharacterBody3D
## El jugador: un herbívoro grande que camina, corre y come fruta para no morir de hambre.

signal hambre_cambio(valor: float, maximo: float)
signal comio(total: int)
signal llego_al_destino
signal murio(motivo: String)

@export var velocidad_caminar := 3.5
@export var velocidad_correr := 7.0
@export var velocidad_giro := 8.0

@export_group("Hambre")
@export var hambre_maxima := 100.0
## Segundos que tarda la barra en vaciarse caminando (o quieto).
@export var segundos_hasta_morir := 60.0
## Cuánto más rápido baja el hambre al correr.
@export var gasto_al_correr := 3.0
@export var recuperacion_por_fruta := 35.0
@export var distancia_para_comer := 1.8

@export_group("Primera persona")
## Radianes que gira la cámara por cada píxel que se mueve el mouse.
@export var sensibilidad_mouse := 0.003
@export var angulo_maximo_abajo := 85.0
@export var angulo_maximo_arriba := 60.0
## Cuánto sube y baja la cámara al caminar.
@export var balanceo := 0.06
## Qué tan centrada tiene que estar la fruta en la mirada para poder comerla (grados).
@export var angulo_para_comer := 35.0

var hambre: float
var frutas_comidas := 0
var vivo := true
var primera_persona := false

var _yaw := 0.0  # giro horizontal de la mirada
var _pitch := 0.0  # inclinación vertical de la mirada
var _fase_balanceo := 0.0
var _moviendose := false
var _corriendo := false
var _comiendo := false
var _fruta_objetivo = null
var _gravedad: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var modelo: Node3D = $Modelo
@onready var animacion: AnimationPlayer = $AnimationPlayer
@onready var agente: NavigationAgent3D = $Agente
## La cámara de primera persona cuelga de "Ojos". No dibuja la capa visual 2
## (la cabeza del modelo) para no ver su interior. En su lugar, un hocico pegado
## a la cámara se ve siempre debajo de la vista, como la propia nariz.
@onready var ojos: Node3D = $Ojos
@onready var camara_primera_persona: Camera3D = $Ojos/Camara
@onready var hocico_primera_persona: MeshInstance3D = $Ojos/Camara/HocicoPrimeraPersona
@onready var _altura_ojos := ojos.position.y
@onready var _altura_hocico := hocico_primera_persona.position.y


func _ready() -> void:
	hambre = hambre_maxima
	animacion.play("quieto")


## La escena principal lo llama al empezar la partida.
func configurar_primera_persona(activar: bool, sensibilidad: float) -> void:
	primera_persona = activar
	sensibilidad_mouse = sensibilidad
	_yaw = modelo.rotation.y
	camara_primera_persona.current = activar
	hocico_primera_persona.visible = activar


func _unhandled_input(event: InputEvent) -> void:
	if not primera_persona or not vivo:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * sensibilidad_mouse
		_pitch = clampf(_pitch - event.relative.y * sensibilidad_mouse,
			-deg_to_rad(angulo_maximo_abajo), deg_to_rad(angulo_maximo_arriba))
	elif event.is_action_pressed("comer") and not _comiendo:
		var fruta := fruta_al_alcance()
		if fruta:
			_comer(fruta)


## Cámara de primera persona: orientación con el mouse y balanceo al caminar.
func _process(delta: float) -> void:
	if not primera_persona:
		return
	modelo.rotation.y = _yaw
	ojos.rotation.y = _yaw + PI  # la cámara mira hacia -Z y el animal hacia +Z
	camara_primera_persona.rotation.x = _pitch
	# Al mirar hacia abajo el hocico baja y sale de la vista, para dejar ver las patas.
	var mirando_abajo := clampf(-_pitch / deg_to_rad(60.0), 0.0, 1.0)
	hocico_primera_persona.position.y = _altura_hocico - 0.35 * mirando_abajo

	var rapidez := Vector2(velocity.x, velocity.z).length()
	var altura := 0.0
	var lado := 0.0
	if rapidez > 0.1 and vivo:
		_fase_balanceo += delta * rapidez * 2.0
		var intensidad := balanceo * rapidez / velocidad_caminar
		altura = sin(_fase_balanceo * 2.0) * intensidad
		lado = cos(_fase_balanceo) * intensidad * 0.5
	camara_primera_persona.position.y = lerpf(camara_primera_persona.position.y, altura, 10.0 * delta)
	camara_primera_persona.position.x = lerpf(camara_primera_persona.position.x, lado, 10.0 * delta)


## La fruta que está cerca y frente a la mirada, o null si no hay ninguna.
func fruta_al_alcance() -> Node3D:
	var frente := Vector3(sin(_yaw), 0, cos(_yaw))
	var mejor: Node3D = null
	var mejor_distancia := distancia_para_comer + 0.7
	for nodo in get_tree().get_nodes_in_group("comida"):
		var fruta := nodo as Node3D
		var hacia := fruta.global_position - global_position
		hacia.y = 0.0
		var distancia := hacia.length()
		if distancia > mejor_distancia:
			continue
		if distancia > 0.01 and rad_to_deg(frente.angle_to(hacia)) > angulo_para_comer:
			continue
		mejor = fruta
		mejor_distancia = distancia
	return mejor


# --- Órdenes de tercera persona (las llama la escena principal) -----------------

func ir_a(punto: Vector3, correr := false) -> void:
	if not vivo or _comiendo:
		return
	_fruta_objetivo = null
	_navegar(punto, correr)


func ir_a_comer(fruta: Node3D, correr := false) -> void:
	if not vivo or _comiendo:
		return
	_fruta_objetivo = fruta
	_navegar(fruta.global_position, correr)


func ser_devorado() -> void:
	_morir("devorado")


func puede_ser_objetivo() -> bool:
	return vivo


func esta_corriendo() -> bool:
	return _moviendose and _corriendo


# --- Lógica de cada frame --------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not vivo:
		return
	if not is_on_floor():
		velocity.y -= _gravedad * delta

	_gastar_hambre(delta)
	if not vivo:
		return

	var horizontal := Vector3.ZERO
	if _comiendo:
		_moviendose = false
	elif primera_persona:
		horizontal = _movimiento_primera_persona()
	else:
		_revisar_fruta_objetivo()
		horizontal = _calcular_movimiento(delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()
	_actualizar_animacion(horizontal.length())


func _gastar_hambre(delta: float) -> void:
	var gasto := hambre_maxima / segundos_hasta_morir
	if esta_corriendo():
		gasto *= gasto_al_correr
	hambre = maxf(hambre - gasto * delta, 0.0)
	hambre_cambio.emit(hambre, hambre_maxima)
	if hambre <= 0.0:
		_morir("hambre")


func _revisar_fruta_objetivo() -> void:
	if _fruta_objetivo == null:
		return
	if not is_instance_valid(_fruta_objetivo) or not _fruta_objetivo.puede_ser_objetivo():
		# Otro animal llegó antes y se la comió.
		_fruta_objetivo = null
		_detener()
		return
	if Mundo.distancia_horizontal(global_position, _fruta_objetivo.global_position) <= distancia_para_comer:
		_comer(_fruta_objetivo)


func _calcular_movimiento(delta: float) -> Vector3:
	if not _moviendose:
		return Vector3.ZERO
	if agente.is_navigation_finished():
		_detener()
		return Vector3.ZERO
	var direccion := agente.get_next_path_position() - global_position
	direccion.y = 0.0
	if direccion.length() < 0.05:
		return Vector3.ZERO
	direccion = direccion.normalized()
	modelo.rotation.y = lerp_angle(modelo.rotation.y, atan2(direccion.x, direccion.z), velocidad_giro * delta)
	return direccion * (velocidad_correr if _corriendo else velocidad_caminar)


## WASD relativo hacia donde mira el animal. Solo se corre hacia adelante (Shift + W).
func _movimiento_primera_persona() -> Vector3:
	var entrada := Input.get_vector("izquierda", "derecha", "adelante", "atras")
	var avance := -entrada.y
	var lateral := entrada.x
	_moviendose = entrada.length() > 0.0
	_corriendo = Input.is_action_pressed("correr") and avance > 0.0
	var frente := Vector3(sin(_yaw), 0, cos(_yaw))
	var derecha := Vector3(-cos(_yaw), 0, sin(_yaw))
	var velocidad_avance := velocidad_correr if _corriendo else velocidad_caminar
	return frente * avance * velocidad_avance + derecha * lateral * velocidad_caminar


func _comer(fruta) -> void:
	_fruta_objetivo = null
	_detener()
	if not fruta.comer():
		return
	_comiendo = true
	var hacia_fruta: Vector3 = fruta.global_position - global_position
	modelo.rotation.y = atan2(hacia_fruta.x, hacia_fruta.z)
	animacion.speed_scale = 1.0
	animacion.play("comer", 0.1)
	if primera_persona:
		# La vista baja hacia la fruta y vuelve a subir, al ritmo de la animación.
		var tween := create_tween()
		tween.tween_property(ojos, "position:y", _altura_ojos - 0.45, 0.25)
		tween.tween_interval(0.3)
		tween.tween_property(ojos, "position:y", _altura_ojos, 0.25)
	await animacion.animation_finished
	_comiendo = false
	if not vivo:
		return
	hambre = minf(hambre + recuperacion_por_fruta, hambre_maxima)
	frutas_comidas += 1
	comio.emit(frutas_comidas)


func _actualizar_animacion(velocidad: float) -> void:
	if _comiendo:
		return
	if velocidad > 0.1:
		animacion.speed_scale = 1.8 if _corriendo else 1.0
		animacion.play("caminar", 0.2)
	else:
		animacion.speed_scale = 1.0
		animacion.play("quieto", 0.2)


func _navegar(punto: Vector3, correr: bool) -> void:
	agente.target_position = punto
	_corriendo = correr
	_moviendose = true


func _detener() -> void:
	if _moviendose:
		_moviendose = false
		llego_al_destino.emit()


func _morir(motivo: String) -> void:
	if not vivo:
		return
	vivo = false
	_moviendose = false
	velocity = Vector3.ZERO
	animacion.stop()
	murio.emit(motivo)
