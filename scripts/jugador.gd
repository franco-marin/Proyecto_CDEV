extends CharacterBody3D
## El jugador: un yaguareté, el depredador más grande de la selva. Para no morir de
## hambre caza animales: primero los abate a zarpazos y, cuando están en el suelo,
## se los come. Puede cazar a todos los animales excepto a los cazadores.

signal hambre_cambio(valor: float, maximo: float)
signal comio(total: int)
signal llego_al_destino
signal murio(motivo: String)

@export var velocidad_caminar := 3.5
@export var velocidad_correr := 7.0
@export var velocidad_giro := 8.0

@export_group("Caza")
## Hasta dónde llega el zarpazo (medido desde el centro del yaguareté).
@export var alcance_zarpazo := 1.9
## Segundos entre un zarpazo y el siguiente.
@export var espera_entre_zarpazos := 0.5
## Qué tan centrada tiene que estar la presa en la mirada para alcanzarla (grados).
@export var angulo_de_ataque := 45.0
@export var distancia_para_comer := 1.5

@export_group("Hambre")
@export var hambre_maxima := 100.0
## Segundos que tarda la barra en vaciarse caminando (o quieto).
@export var segundos_hasta_morir := 90.0
## Cuánto más rápido baja el hambre al correr.
@export var gasto_al_correr := 3.0

@export_group("Primera persona")
## Radianes que gira la cámara por cada píxel que se mueve el mouse.
@export var sensibilidad_mouse := 0.003
@export var angulo_maximo_abajo := 85.0
@export var angulo_maximo_arriba := 60.0
## Cuánto sube y baja la cámara al caminar.
@export var balanceo := 0.06

var hambre: float
var presas_comidas := 0
var vivo := true
var primera_persona := false

var _yaw := 0.0  # giro horizontal de la mirada
var _pitch := 0.0  # inclinación vertical de la mirada
var _fase_balanceo := 0.0
var _moviendose := false
var _corriendo := false
var _comiendo := false
var _espera_zarpazo := 0.0
## Presa elegida en tercera persona: si está viva la persigue y la ataca; si está
## abatida va a comérsela. Sin tipo a propósito (es un AnimalIA).
var _presa = null
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
@onready var zarpa_primera_persona: Node3D = $Ojos/Camara/ZarpaPrimeraPersona
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
	elif event.is_action_pressed("atacar"):
		zarpazo()
	elif event.is_action_pressed("comer") and not _comiendo:
		var abatida := presa_al_alcance(false)
		if abatida:
			_comer(abatida)


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


# --- Caza ------------------------------------------------------------------------------

## Golpe con la pata delantera. Si hay una presa viva al alcance y de frente, la lastima.
func zarpazo() -> void:
	if not vivo or _comiendo or _espera_zarpazo > 0.0:
		return
	_espera_zarpazo = espera_entre_zarpazos
	animacion.speed_scale = 1.0
	animacion.play("zarpazo", 0.05)
	if primera_persona:
		_animar_zarpa_primera_persona()
	var presa := presa_al_alcance(true)
	if presa:
		presa.recibir_golpe(self)


## La presa más cercana que está al alcance y de frente, o null.
## viva = true busca presas para atacar; viva = false busca presas abatidas para comer.
func presa_al_alcance(viva: bool) -> Node3D:
	var mirada := _yaw if primera_persona else modelo.rotation.y
	var frente := Vector3(sin(mirada), 0, cos(mirada))
	var mejor: Node3D = null
	var mejor_distancia := alcance_zarpazo if viva else distancia_para_comer + 0.5
	for nodo in get_tree().get_nodes_in_group("presas" if viva else "presas_abatidas"):
		var presa := nodo as Node3D
		var hacia := presa.global_position - global_position
		hacia.y = 0.0
		var distancia := hacia.length()
		if distancia > mejor_distancia:
			continue
		if distancia > 0.3 and rad_to_deg(frente.angle_to(hacia)) > angulo_de_ataque:
			continue
		mejor = presa
		mejor_distancia = distancia
	return mejor


## Para el aviso en pantalla de primera persona: qué se puede hacer ahora.
func accion_disponible() -> String:
	if _comiendo:
		return ""
	if presa_al_alcance(false):
		return "E: comer"
	if presa_al_alcance(true):
		return "Click: zarpazo"
	return ""


# --- Órdenes de tercera persona (las llama la escena principal) -----------------

func ir_a(punto: Vector3, correr := false) -> void:
	if not vivo or _comiendo:
		return
	_presa = null
	_navegar(punto, correr)


## Persigue a una presa y la ataca; cuando cae, va a comérsela.
func ir_a_cazar(presa: Node3D, correr := false) -> void:
	if not vivo or _comiendo:
		return
	_presa = presa
	_navegar(presa.global_position, correr)


func ser_capturado() -> void:
	_morir("capturado")


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
	_espera_zarpazo = maxf(_espera_zarpazo - delta, 0.0)

	_gastar_hambre(delta)
	if not vivo:
		return

	var horizontal := Vector3.ZERO
	if _comiendo:
		_moviendose = false
	elif primera_persona:
		horizontal = _movimiento_primera_persona()
	else:
		_seguir_presa()
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


## Tercera persona: persigue a la presa elegida, la ataca al alcanzarla y,
## cuando cae, se acerca y se la come.
func _seguir_presa() -> void:
	if _presa == null:
		return
	if not is_instance_valid(_presa) or not (_presa.vivo or _presa.abatido):
		# Desapareció (otro animal la cazó o ya se la comieron).
		_presa = null
		_detener()
		return
	var distancia := Mundo.distancia_horizontal(global_position, _presa.global_position)
	if _presa.abatido:
		if distancia <= distancia_para_comer:
			_comer(_presa)
		else:
			agente.target_position = _presa.global_position
			_moviendose = true
	elif distancia <= alcance_zarpazo - 0.3:
		_mirar_hacia(_presa.global_position)
		_moviendose = false
		zarpazo()
	else:
		agente.target_position = _presa.global_position  # la presa se mueve: actualizar el destino
		_moviendose = true


func _calcular_movimiento(delta: float) -> Vector3:
	if not _moviendose:
		return Vector3.ZERO
	if agente.is_navigation_finished():
		if _presa == null:
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


func _comer(abatida) -> void:
	_presa = null
	_detener()
	var alimento: float = abatida.ser_comido()
	if alimento <= 0.0:
		return  # otro llegó antes
	_comiendo = true
	_mirar_hacia(abatida.global_position)
	animacion.speed_scale = 1.0
	animacion.play("comer", 0.1)
	if primera_persona:
		# La vista baja hacia la presa y vuelve a subir, al ritmo de la animación.
		var tween := create_tween()
		tween.tween_property(ojos, "position:y", _altura_ojos - 0.45, 0.25)
		tween.tween_interval(0.3)
		tween.tween_property(ojos, "position:y", _altura_ojos, 0.25)
	await animacion.animation_finished
	_comiendo = false
	if not vivo:
		return
	hambre = minf(hambre + alimento, hambre_maxima)
	presas_comidas += 1
	comio.emit(presas_comidas)


## En primera persona se ve la pata cruzar la pantalla durante el zarpazo.
func _animar_zarpa_primera_persona() -> void:
	zarpa_primera_persona.visible = true
	zarpa_primera_persona.position = Vector3(0.45, -0.22, -0.5)
	zarpa_primera_persona.rotation = Vector3(0.3, 0.4, 0.7)
	var tween := create_tween().set_parallel()
	tween.tween_property(zarpa_primera_persona, "position", Vector3(-0.35, -0.42, -0.6), 0.16)
	tween.tween_property(zarpa_primera_persona, "rotation:z", -0.5, 0.16)
	tween.chain().tween_callback(zarpa_primera_persona.hide)


func _mirar_hacia(punto: Vector3) -> void:
	var hacia := punto - global_position
	if Vector2(hacia.x, hacia.z).length() < 0.01:
		return
	modelo.rotation.y = atan2(hacia.x, hacia.z)
	if primera_persona:
		_yaw = modelo.rotation.y


func _actualizar_animacion(velocidad: float) -> void:
	if _comiendo or (animacion.current_animation == "zarpazo" and animacion.is_playing()):
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
