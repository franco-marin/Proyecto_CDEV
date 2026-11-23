extends Control
## Ícono de un ojo en el HUD: abierto cuando al yaguareté lo pueden ver y cerrado
## cuando está escondido en la maleza. Se dibuja con código en _draw().

const COLOR_LINEA := Color(1, 1, 1, 0.95)
const COLOR_SOMBRA := Color(0, 0, 0, 0.6)
const COLOR_BLANCO := Color(0.95, 0.95, 0.9, 0.9)
const COLOR_IRIS := Color(0.85, 0.62, 0.15)  # ámbar, como el ojo del yaguareté

var cerrado := false:
	set(valor):
		if valor != cerrado:
			cerrado = valor
			queue_redraw()


func _draw() -> void:
	var centro := size / 2.0
	var ancho := size.x * 0.45
	var alto := size.y * 0.3
	if cerrado:
		_ojo_cerrado(centro, ancho, alto)
	else:
		_ojo_abierto(centro, ancho, alto)


func _ojo_abierto(centro: Vector2, ancho: float, alto: float) -> void:
	# Forma de almendra: un arco arriba y otro abajo.
	var arriba := _arco(centro, ancho, -alto)
	var abajo := _arco(centro, ancho, alto)
	var contorno := arriba.duplicate()
	for i in range(abajo.size() - 1, -1, -1):
		contorno.append(abajo[i])
	draw_colored_polygon(contorno, COLOR_BLANCO)
	draw_circle(centro, alto * 0.85, COLOR_IRIS)
	draw_circle(centro, alto * 0.42, Color.BLACK)
	draw_circle(centro + Vector2(-alto * 0.25, -alto * 0.25), alto * 0.15, Color.WHITE)
	for arco in [arriba, abajo]:
		draw_polyline(arco, COLOR_SOMBRA, 5.0, true)
		draw_polyline(arco, COLOR_LINEA, 2.5, true)


func _ojo_cerrado(centro: Vector2, ancho: float, alto: float) -> void:
	# Párpado cerrado: un arco hacia abajo con pestañas.
	var parpado := _arco(centro, ancho, alto * 0.6)
	draw_polyline(parpado, COLOR_SOMBRA, 6.0, true)
	draw_polyline(parpado, COLOR_LINEA, 3.0, true)
	for t in [0.2, 0.4, 0.6, 0.8]:
		var x := lerpf(-ancho, ancho, t)
		var base := centro + Vector2(x, alto * 0.6 * sin(t * PI))
		var punta := base + Vector2(x * 0.25, alto * 0.7)
		draw_line(base, punta, COLOR_SOMBRA, 4.0, true)
		draw_line(base, punta, COLOR_LINEA, 2.0, true)


## Puntos de un arco de lado a lado; "altura" negativa curva hacia arriba.
func _arco(centro: Vector2, ancho: float, altura: float) -> PackedVector2Array:
	var puntos := PackedVector2Array()
	for i in 17:
		var t := i / 16.0
		puntos.append(centro + Vector2(lerpf(-ancho, ancho, t), altura * sin(t * PI)))
	return puntos
