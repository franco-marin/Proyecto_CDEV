extends CanvasLayer
## Menú de pausa (tecla Esc). Sigue funcionando con el juego pausado porque
## su "Process > Mode" es "Always".

signal reanudado

## La escena principal lo activa mientras la partida está en curso.
var habilitado := false


func _ready() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if habilitado and event.is_action_pressed("pausa"):
		if visible:
			reanudar()
		else:
			pausar()
		get_viewport().set_input_as_handled()


func pausar() -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func reanudar() -> void:
	visible = false
	get_tree().paused = false
	reanudado.emit()


func _on_boton_continuar_pressed() -> void:
	reanudar()


func _on_boton_menu_pressed() -> void:
	Mundo.reiniciar(true)


func _on_boton_salir_pressed() -> void:
	get_tree().quit()
