## Menú de pausa. Se abre con la tecla (P) durante la partida y
## ofrece continuar, salir del juego o abandonar la partida actual.
## IMPORTANTE: el nodo raíz debe tener Process Mode = "Always" en el
## Inspector, igual que GameOver, porque al pausar el árbol todo lo demás
## se congela y los botones dejarían de responder.
extends Control

func _ready() -> void:
	# Arranca oculto: solo aparece cuando main.gd llama a open().
	hide()
	$VBoxContainer/ContinueButton.pressed.connect(_on_continue)
	$VBoxContainer/ExitButton.pressed.connect(_on_exit)
	$VBoxContainer/AbandonButton.pressed.connect(_on_abandon)


## Este nodo, al ser Process Mode = Always, sigue recibiendo input aunque
## el árbol esté pausado. Por eso también puede escuchar la tecla "pause"
## aquí para CERRAR el menú, no solo main.gd para abrirlo.
## El "if not visible: return" evita que reaccione con el menú oculto,
## que es cuando main.gd es quien debe abrirlo, no este script.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause"):
		_on_continue()


## La llama main.gd cuando el jugador presiona P durante la partida.
func open() -> void:
	show()
	get_tree().paused = true


## Botón "Continuar" (y la tecla P, si el menú ya está abierto).
func _on_continue() -> void:
	hide()
	get_tree().paused = false


## Botón "Salir": cierra el juego completamente.
func _on_exit() -> void:
	get_tree().quit()


## Botón "Abandonar". Debería volver al menú principal, pero como todavía
## no existe, por ahora reinicia la partida actual como reemplazo temporal.
## Cuando exista el menú, cambiar esta línea por:
## get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
func _on_abandon() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
