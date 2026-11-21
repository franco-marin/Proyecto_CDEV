class_name Climax
extends Node
## El final de la experiencia (SDD: fases "Persecución" y "Caza inversa"). Es el nivel 4:
## un pasillo lineal (ver pasillo.gd). La barra de hambre está llena y no baja.
##   0) Presentación: el yaguareté, quieto, ve llegar a un cazador por el sendero; se le
##      suman dos más, uno a cada lado, y recién ahí empiezan a disparar y a seguirlo.
##   1) Persecución: hay que dar media vuelta y correr por el pasillo. Los cazadores van
##      cada vez más rápido (en 10 s ya lo alcanzan). Si a los 20 s todavía no lo alcanzaron,
##      aparece uno justo detrás de él (fuera de cámara) y lo alcanza.
##   2) Acorralado: lo rodean y el más cercano le apunta... pero el arma está trabada.
##   3) Caza inversa: todos sueltan el rifle y huyen por el pasillo, al principio tan rápido
##      como el yaguareté; en 7 segundos se van frenando de a poco hasta que los alcanza.
##   4) Final en suspenso: justo antes de alcanzar a cualquiera de ellos, la pantalla se
##      funde a negro.
## Durante todo el clímax el jugador no puede perder: todos llegan a ver la caza inversa.

enum Fase { INACTIVO, PRESENTACION, PERSECUCION, ACORRALADO, CAZA_INVERSA, FINAL }

## Cámara de tercera persona en el pasillo (desplazamiento respecto del yaguareté).
## Mirando hacia la entrada (por donde vienen los cazadores) y mirando hacia el fondo
## (hacia donde se escapa).
const CAMARA_HACIA_LA_ENTRADA := Vector3(0, 3.4, -6.0)
const CAMARA_HACIA_EL_FONDO := Vector3(0, 6.5, 8)

const AYUDA_HUIR_TERCERA := "Click derecho: moverte  ·  Shift + click derecho: correr  ·  ¡Escapá de los cazadores!  ·  Esc: pausa"
const AYUDA_HUIR_PRIMERA := "WASD: moverte  ·  Shift + W: correr  ·  ¡Escapá de los cazadores!  ·  Esc: pausa"
const AYUDA_CAZAR_TERCERA := "Click derecho sobre el cazador: perseguirlo  ·  ¡Alcanzalo!  ·  Esc: pausa"
const AYUDA_CAZAR_PRIMERA := "Shift + W: correr  ·  Mouse: mirar  ·  ¡Alcanzalo!  ·  Esc: pausa"

## Arma trabada: segundos después de cada click del gatillo (uno por click).
## Un click, una pausa de duda, otro click y después varios rápidos, desesperado.
const PAUSAS_ENTRE_CLICKS := [0.8, 0.5, 0.15, 0.13, 0.16, 0.12, 0.15, 1.0]

## Textos de la pantalla final. PROVISORIOS: los reescribe el equipo de narrativa.
## Las cifras son las mismas que las del game over (ver las fuentes en main.gd).
const TITULO_FINAL := "¿Fin?"
const TEXTO_FINAL := "El cazador corre por la selva que ayudó a destruir.\n" \
	+ "Por primera vez, sabe lo que se siente ser la presa."
const DATO_FINAL := "Fuera del juego, el yaguareté no tiene esta revancha: en Argentina quedan " \
	+ "unos 250 y está en peligro de extinción. Cuidar la selva es cuidarlo a él."

## Cuántos cazadores hay en la persecución final. Si el nivel tiene menos, llegan los que faltan.
@export var cazadores_en_persecucion := 3
## A qué distancia del yaguareté aparecen los cazadores de la persecución.
@export var distancia_aparicion := 16.0
@export var segundos_persecucion := 30.0
## En la persecución no hay escape: si el yaguareté cruza el río o se aleja más que esto,
## los cazadores que lo perdieron reaparecen cerca de él (fuera de la vista de la cámara).
@export var distancia_maxima_persecucion := 25.0
@export var segundos_entre_reubicaciones := 1.5
## En el cerco: a qué distancia se queda el que apunta y a cuál el resto.
@export var distancia_cerco_apunta := 7.0
@export var distancia_cerco_resto := 10.0
## Al empezar la caza inversa, el yaguareté se queda unos segundos mirando cómo huye el
## cazador: esa ventaja hace que la persecución dure más.
@export var segundos_de_ventaja := 2.5
## Si en tantos segundos el que apunta no llegó a su lugar en el cerco, se sigue igual.
@export var segundos_maximos_cerco := 6.0
## En la caza inversa, a esta distancia de un cazador cansado se corta a negro (antes del contacto).
@export var distancia_para_alcanzarlo := 2.5
## Segundos de caza inversa hasta que todos los cazadores se cansan. Antes son más rápidos
## que el yaguareté: no se los puede alcanzar.
@export var segundos_hasta_cansarse := 20.0

@export_group("Nivel 4 (pasillo)")
## Velocidad de los cazadores al empezar a perseguir y a los 10 s (el yaguareté corre a 7).
@export var velocidad_inicial_persecucion := 5.0
@export var velocidad_maxima_persecucion := 10.0
@export var segundos_para_acelerar := 10.0
## A esta distancia el cazador más cercano "lo alcanzó": empieza el cerco.
@export var distancia_para_atraparlo := 2.5
## Si en tantos segundos no lo alcanzaron, aparece un cazador justo detrás de él.
@export var segundos_hasta_el_de_atras := 20.0
## Caza inversa: en cuántos segundos se frenan los cazadores, y hasta qué velocidad.
@export var segundos_frenandose := 7.0
@export var velocidad_final_huida := 3.5
## En la caza inversa del pasillo la ventaja es más corta: el frenado ya alarga la persecución.
@export var segundos_de_ventaja_pasillo := 1.2

var fase := Fase.INACTIVO
var en_pasillo := false
## Al que se le trabó el arma: es el que hay que alcanzar en la caza inversa.
var cazador_final: Node3D = null

var _segundos_en_fase := 0.0
var _reloj_reubicar := 0.0
## Caza inversa: ya pasó el tiempo y todos los cazadores se cansaron (antes son más rápidos
## que el yaguareté y no se los puede alcanzar).
var _cansados := false
var _tween_anuncio: Tween

@onready var main = get_parent()  # sin tipo: usa nodos y funciones propios de main.gd
@onready var anuncio: Label = $"../HUD/Anuncio"
@onready var fundido: ColorRect = $"../HUD/Fundido"
@onready var ambiente: AudioStreamPlayer = $"../Ambiente"
@onready var musica_persecucion: AudioStreamPlayer = $MusicaPersecucion
@onready var musica_caza_inversa: AudioStreamPlayer = $MusicaCazaInversa


func _ready() -> void:
	anuncio.visible = false
	fundido.color.a = 0.0


func activo() -> bool:
	return fase != Fase.INACTIVO


## A quién señala la flecha del borde de la pantalla durante el clímax.
func objetivo_de_la_flecha(cazador_que_persigue: Node3D) -> Node3D:
	match fase:
		Fase.PERSECUCION:
			return cazador_que_persigue
		Fase.CAZA_INVERSA:
			return _cazador_mas_cercano()
	return null


## Caza inversa: el cazador sobre el que (o cerca del que) se hizo click, o null.
func cazador_cerca_de(punto: Vector3, radio: float) -> Node3D:
	if fase != Fase.CAZA_INVERSA:
		return null
	for nodo in get_tree().get_nodes_in_group("cazadores"):
		var cazador := nodo as Node3D
		if Mundo.distancia_horizontal(cazador.global_position, punto) <= radio:
			return cazador
	return null


func _process(delta: float) -> void:
	if fase == Fase.INACTIVO:
		return
	_segundos_en_fase += delta
	if en_pasillo:
		_process_pasillo()
		return
	match fase:
		Fase.PERSECUCION:
			_reloj_reubicar -= delta
			if _reloj_reubicar <= 0.0:
				_reloj_reubicar = segundos_entre_reubicaciones
				_reubicar_a_los_que_lo_perdieron(distancia_maxima_persecucion)
				_armar_formacion()
			# Si justo está nadando, espera a que salga del agua para acorralarlo.
			if _segundos_en_fase >= segundos_persecucion and not main.jugador.nadando:
				_acorralar()
		Fase.CAZA_INVERSA:
			# Mientras dura la ventaja el yaguareté todavía está quieto: no cuenta el tiempo.
			if main.jugador.quieto_forzado:
				return
			if get_tree().get_nodes_in_group("cazadores").is_empty():
				_final()
			elif not _cansados and _segundos_en_fase >= segundos_hasta_cansarse:
				_cansados = true
				for cazador in get_tree().get_nodes_in_group("cazadores"):
					cazador.cansarse()
				_anunciar("¡Los cazadores ya no dan más!", 2.5)
			elif _cansados:
				# Alcanzar a cualquiera de ellos termina la experiencia.
				var alcanzado := _cazador_mas_cercano()
				if Mundo.distancia_horizontal(alcanzado.global_position, main.jugador.global_position) \
						<= distancia_para_alcanzarlo:
					cazador_final = alcanzado
					_final()


## Nivel 4: aceleración de los cazadores, el que aparece detrás a los 20 s, y el frenado
## de la caza inversa.
func _process_pasillo() -> void:
	var jugador = main.jugador
	match fase:
		Fase.PERSECUCION:
			# Cada vez más rápidos: en "segundos_para_acelerar" ya corren más que el yaguareté.
			var avance := clampf(_segundos_en_fase / segundos_para_acelerar, 0.0, 1.0)
			_poner_velocidad(lerpf(velocidad_inicial_persecucion, velocidad_maxima_persecucion, avance))
			if fmod(_segundos_en_fase, 1.5) < get_process_delta_time():
				_armar_formacion()
			var cercano := _cazador_mas_cercano()
			# El que va adelante corre derecho, sin frenarse a disparar; los demás sí disparan.
			for cazador in get_tree().get_nodes_in_group("cazadores"):
				cazador.no_dispara = cazador == cercano
			if cercano and Mundo.distancia_horizontal(cercano.global_position, jugador.global_position) <= distancia_para_atraparlo:
				_acorralar(cercano)
			elif _segundos_en_fase >= segundos_hasta_el_de_atras:
				_aparecer_detras()
		Fase.CAZA_INVERSA:
			if jugador.quieto_forzado:
				return  # todavía mira cómo huyen (la ventaja)
			# Huyen tan rápido como el yaguareté y se van frenando, de forma que se note.
			var avance := clampf(_segundos_en_fase / segundos_frenandose, 0.0, 1.0)
			_poner_velocidad(lerpf(_velocidad_furia(), velocidad_final_huida, avance))
			if get_tree().get_nodes_in_group("cazadores").is_empty():
				_final()
				return
			var alcanzado := _cazador_mas_cercano()
			if Mundo.distancia_horizontal(alcanzado.global_position, jugador.global_position) <= distancia_para_alcanzarlo:
				cazador_final = alcanzado
				_final()


func _poner_velocidad(velocidad: float) -> void:
	for cazador in get_tree().get_nodes_in_group("cazadores"):
		cazador.velocidad_correr = velocidad
		if cazador._moviendose:
			cazador._velocidad_actual = velocidad


## Velocidad del yaguareté furioso en la caza inversa.
func _velocidad_furia() -> float:
	return main.jugador.velocidad_correr * main.jugador.MULTIPLICADOR_FURIA


## Si no lo alcanzaron a tiempo, aparece un cazador justo detrás del yaguareté: del lado de
## la entrada (desde ahí lo persiguen) y más atrás que la cámara, así no se lo ve aparecer.
func _aparecer_detras() -> void:
	var jugador = main.jugador
	var punto: Vector3 = Mundo.punto_navegable(jugador.global_position + Vector3(0, 0, 13.0))
	var nuevo: Node3D = main.crear_cazador_en(punto)
	nuevo.perseguir_sin_tregua()
	_acorralar(nuevo)


# --- Fases ---------------------------------------------------------------------

## 0) Nivel 4. Presentación: quieto, el yaguareté ve llegar a un cazador por el sendero;
## se le suman dos, uno a cada lado, y recién ahí empieza la persecución.
func empezar_en_pasillo() -> void:
	en_pasillo = true
	_cambiar_fase(Fase.PRESENTACION)
	var jugador = main.jugador
	var pasillo = main.pasillo
	jugador.modo_climax = true
	jugador.quieto_forzado = true
	jugador.llenar_hambre()  # en este nivel el hambre no importa: barra llena y no baja
	main.offset_camara = CAMARA_HACIA_LA_ENTRADA
	main.etiqueta_nivel.text = "La persecución"
	main.contador.text = ""
	main.ayuda.text = ""

	# Primero, uno solo por el sendero.
	var lugar: Vector3 = pasillo.punto_en_sendero(jugador.global_position.z + 8.0)
	# Aparecen a unos metros de su puesto, saliendo de la niebla del sendero.
	var aparicion: Vector3 = pasillo.punto_en_sendero(minf(lugar.z + 9.0, Pasillo.Z_ENTRADA - 1.0))
	var primero: Node3D = main.crear_cazador_en(aparicion)
	primero.ponerse_en(lugar)
	await _esperar_que_lleguen([primero], 6.0)
	await _esperar(1.2)

	# Se le suman dos más, uno a cada lado.
	var otros := []
	for lado in [-1.0, 1.0]:
		var otro: Node3D = main.crear_cazador_en(aparicion + Vector3(lado * 2.0, 0, 0))
		otro.ponerse_en(lugar + Vector3(lado * 2.8, 0, 0.8))
		otros.append(otro)
	await _esperar_que_lleguen(otros, 6.0)
	await _esperar(1.0)
	_empezar_persecucion_en_pasillo()


## El yaguareté mira a los cazadores mientras caminan a su lugar (con un tiempo máximo).
func _esperar_que_lleguen(cazadores: Array, maximo: float) -> void:
	var espera := 0.0
	while espera < maximo:
		var llegaron := true
		for cazador in cazadores:
			if is_instance_valid(cazador) and not cazador.llego_a_su_puesto():
				llegaron = false
		if is_instance_valid(cazadores[0]):
			main.jugador.punto_de_atencion = cazadores[0].global_position
		if llegaron:
			return
		await _esperar(0.1)
		espera += 0.1


## 1) Nivel 4: los tres empiezan a disparar y a seguirlo. Hay que dar media vuelta y correr.
func _empezar_persecucion_en_pasillo() -> void:
	_cambiar_fase(Fase.PERSECUCION)
	var jugador = main.jugador
	jugador.quieto_forzado = false
	jugador.punto_de_atencion = null
	main.contador.text = "¡Escapá!"
	main.ayuda.text = AYUDA_HUIR_PRIMERA if main.primera_persona else AYUDA_HUIR_TERCERA
	ambiente.stop()
	_tocar(musica_persecucion)
	for cazador in get_tree().get_nodes_in_group("cazadores"):
		cazador.perseguir_sin_tregua()
	_poner_velocidad(velocidad_inicial_persecucion)
	_armar_formacion()
	# La cámara pasa al otro lado, mirando hacia el fondo: hacia donde hay que escapar.
	main.offset_camara = CAMARA_HACIA_EL_FONDO
	_anunciar("¡Cazadores! ¡Huí!", 3.0)



## 1) Persecución. La llama main.gd al comer la última presa del último nivel.
func empezar() -> void:
	if fase != Fase.INACTIVO:
		return
	_cambiar_fase(Fase.PERSECUCION)
	main.jugador.modo_climax = true
	main.etiqueta_nivel.text = "La persecución"
	main.contador.text = "¡Escapá!"
	main.ayuda.text = AYUDA_HUIR_PRIMERA if main.primera_persona else AYUDA_HUIR_TERCERA
	# SDD: el sonido de la naturaleza se apaga de golpe y entra la música de persecución.
	ambiente.stop()
	_tocar(musica_persecucion)
	var faltan := cazadores_en_persecucion - get_tree().get_nodes_in_group("cazadores").size()
	for i in maxi(faltan, 0):
		main.crear_cazador_en(_punto_fuera_de_vista(distancia_aparicion))
	for cazador in get_tree().get_nodes_in_group("cazadores"):
		cazador.perseguir_sin_tregua()
	# Los del nivel que andaban lejos llegan enseguida (sin que se los vea aparecer).
	_reubicar_a_los_que_lo_perdieron(distancia_maxima_persecucion)
	_armar_formacion()
	_anunciar("¡Cazadores! ¡Huí!", 3.0)


## 2) Acorralado: lo rodean, el más cercano (o "elegido") le apunta y el arma se traba.
func _acorralar(elegido: Node3D = null) -> void:
	_cambiar_fase(Fase.ACORRALADO)
	var jugador = main.jugador
	jugador.quieto_forzado = true
	main.contador.text = "¡Acorralado!"
	if en_pasillo:
		# Los cazadores vienen de atrás: la cámara da media vuelta para verlos.
		main.offset_camara = CAMARA_HACIA_LA_ENTRADA
	else:
		# Para que el cerco se arme cerca, los que quedaron lejos o del otro lado se acercan.
		_reubicar_a_los_que_lo_perdieron(distancia_cerco_resto + 8.0)
	cazador_final = elegido if elegido else _cazador_mas_cercano()
	for cazador in get_tree().get_nodes_in_group("cazadores"):
		cazador.cercar(distancia_cerco_apunta if cazador == cazador_final else distancia_cerco_resto)
	_anunciar("¡Te rodearon!", 2.5)
	if cazador_final == null:
		_empezar_caza_inversa()
		return

	# Espera a que el que va a apuntar llegue a su lugar (con un tiempo máximo).
	var espera := 0.0
	while espera < segundos_maximos_cerco and is_instance_valid(cazador_final) \
			and Mundo.distancia_horizontal(cazador_final.global_position, jugador.global_position) \
				> distancia_cerco_apunta + 1.0:
		jugador.punto_de_atencion = cazador_final.global_position
		await _esperar(0.1)
		espera += 0.1
	if not is_instance_valid(cazador_final):
		_empezar_caza_inversa()
		return

	jugador.punto_de_atencion = cazador_final.global_position
	cazador_final.apuntar_sin_balas()
	await _esperar(1.3)
	# Aprieta el gatillo y no sale el tiro: un click, una pausa de duda y otros dos seguidos.
	# (Solo sonido y el sacudón del rifle, sin texto en pantalla.)
	for pausa in PAUSAS_ENTRE_CLICKS:
		if not is_instance_valid(cazador_final):
			break
		cazador_final.gatillar_trabado()
		await _esperar(pausa)
	_empezar_caza_inversa()


## 3) Caza inversa: los cazadores huyen asustados y el yaguareté, furioso, los persigue.
func _empezar_caza_inversa() -> void:
	_cambiar_fase(Fase.CAZA_INVERSA)
	var jugador = main.jugador
	for cazador in get_tree().get_nodes_in_group("cazadores"):
		cazador.huir_asustado()
		if en_pasillo:
			cazador.eje_de_huida = Vector3(0, 0, 1)  # huyen por el pasillo, nunca hacia los costados
	if en_pasillo:
		_poner_velocidad(_velocidad_furia())
	# SDD: la tensión se rompe con una música animada, casi cómica.
	musica_persecucion.stop()
	_tocar(musica_caza_inversa)
	main.etiqueta_nivel.text = "La caza inversa"
	main.contador.text = "¡Alcanzalo!"
	main.ayuda.text = AYUDA_CAZAR_PRIMERA if main.primera_persona else AYUDA_CAZAR_TERCERA

	# Ventaja: el yaguareté todavía no se mueve; mira cómo el cazador suelta el rifle y huye.
	var ventaja := segundos_de_ventaja_pasillo if en_pasillo else segundos_de_ventaja
	var espera := 0.0
	while espera < ventaja and is_instance_valid(cazador_final):
		jugador.punto_de_atencion = cazador_final.global_position
		await _esperar(0.1)
		espera += 0.1
	jugador.quieto_forzado = false
	jugador.punto_de_atencion = null
	jugador.furia = true
	_segundos_en_fase = 0.0  # el cansancio del cazador se cuenta desde que lo empieza a perseguir
	_anunciar("¡Ahora cazás vos!", 3.0)


## 4) Final en suspenso: justo antes del contacto, fundido a negro y pantalla final.
func _final() -> void:
	_cambiar_fase(Fase.FINAL)
	main.jugador.quieto_forzado = true
	anuncio.visible = false
	var tween := create_tween()
	tween.tween_property(fundido, "color:a", 1.0, 0.8)
	await tween.finished
	await _esperar(0.6)
	main.terminar_climax(TITULO_FINAL, TEXTO_FINAL, DATO_FINAL)


# --- Utilidades ----------------------------------------------------------------

func _cambiar_fase(nueva: Fase) -> void:
	fase = nueva
	_segundos_en_fase = 0.0


## Los cazadores que quedaron del otro lado del río o más lejos que "distancia" del
## yaguareté reaparecen cerca de él. Así cruzar el río o correr lejos no lo salva.
func _reubicar_a_los_que_lo_perdieron(distancia: float) -> void:
	var centro: Vector3 = main.jugador.global_position
	for nodo in get_tree().get_nodes_in_group("cazadores"):
		var cazador := nodo as Node3D
		if Mundo.mismo_lado_del_rio(cazador.global_position, centro) \
				and Mundo.distancia_horizontal(cazador.global_position, centro) <= distancia:
			continue
		# Mientras nada no hay "su lado": se espera a que salga del agua.
		if main.jugador.nadando:
			return
		cazador.global_position = _punto_fuera_de_vista(distancia_aparicion) + Vector3.UP * 0.2


## Persecución en "V" en vez de en fila: el más cercano es el líder y va directo; los demás
## se reparten a los costados (uno de cada lado, alternando) y un poco más atrás.
## Cada uno se queda del costado en el que ya está, para que no se crucen.
func _armar_formacion() -> void:
	var centro: Vector3 = main.jugador.global_position
	var cazadores := get_tree().get_nodes_in_group("cazadores")
	if cazadores.is_empty():
		return
	var distancia_al_centro := func(cazador: Node3D) -> float:
		return Mundo.distancia_horizontal(cazador.global_position, centro)
	cazadores.sort_custom(func(a, b): return distancia_al_centro.call(a) < distancia_al_centro.call(b))
	var lider: Node3D = cazadores[0]
	var hacia := centro - lider.global_position
	hacia.y = 0.0
	var costado := Vector3(-hacia.z, 0, hacia.x).normalized()
	var lado_anterior := 0.0
	for i in cazadores.size():
		var cazador = cazadores[i]
		cazador.lider = lider
		if i == 0:
			cazador.lado_en_formacion = 0.0
			continue
		var lado := -lado_anterior
		if lado == 0.0:
			lado = signf((cazador.global_position - centro).dot(costado))
			if lado == 0.0:
				lado = 1.0
		cazador.lado_en_formacion = lado
		cazador.rango_en_formacion = ceili(i / 2.0)
		lado_anterior = lado


## Un punto a "distancia" del yaguareté, de su lado del río, fuera del agua y, si se puede,
## fuera de la vista de la cámara (para que no se vea a nadie aparecer de la nada).
func _punto_fuera_de_vista(distancia: float) -> Vector3:
	var centro: Vector3 = main.jugador.global_position
	var camara := get_viewport().get_camera_3d()
	var respaldo := Vector3.INF
	var angulo := randf() * TAU
	for intento in 12:
		var punto := Mundo.punto_navegable(centro + Vector3.FORWARD.rotated(Vector3.UP, angulo) * distancia)
		angulo += TAU / 12.0
		if not Mundo.mismo_lado_del_rio(punto, centro) or Mundo.en_agua(punto, 1.0):
			continue
		if camara == null or not camara.is_position_in_frustum(punto + Vector3.UP):
			return punto
		if respaldo == Vector3.INF:
			respaldo = punto  # de su lado del río, aunque se vea
	if respaldo != Vector3.INF:
		return respaldo
	return Mundo.punto_aleatorio_lejos_de(centro, distancia * 0.75)


## El cazador más cercano al yaguareté, prefiriendo los de su mismo lado del río.
func _cazador_mas_cercano() -> Node3D:
	var centro: Vector3 = main.jugador.global_position
	var mejor: Node3D = null
	var mejor_puntaje := INF
	for nodo in get_tree().get_nodes_in_group("cazadores"):
		var cazador := nodo as Node3D
		var puntaje := Mundo.distancia_horizontal(cazador.global_position, centro)
		if not Mundo.mismo_lado_del_rio(cazador.global_position, centro):
			puntaje += 1000.0
		if puntaje < mejor_puntaje:
			mejor = cazador
			mejor_puntaje = puntaje
	return mejor


## Texto grande en el centro de la pantalla que se desvanece solo.
func _anunciar(texto: String, segundos: float) -> void:
	if _tween_anuncio:
		_tween_anuncio.kill()
	anuncio.text = texto
	anuncio.modulate.a = 1.0
	anuncio.visible = true
	_tween_anuncio = create_tween()
	_tween_anuncio.tween_interval(segundos)
	_tween_anuncio.tween_property(anuncio, "modulate:a", 0.0, 0.4)


## Los sonidos los carga el equipo de audio: si el nodo no tiene "Stream", no suena nada.
func _tocar(reproductor: AudioStreamPlayer) -> void:
	if reproductor.stream:
		reproductor.play()


## Espera que se frena con la pausa (Esc), a diferencia de un timer común.
func _esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos, false).timeout
