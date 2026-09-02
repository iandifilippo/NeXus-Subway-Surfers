## Menú de pausa. Se abre con la tecla "pause" (P) o (esc) durante la partida.
## Tiene tres opciones:
##  - Continuar: cierra el menú con una cuenta regresiva de 3 segundos
##    antes de reanudar (le da al jugador un momento para ubicarse).
##  - Salir: pide confirmación y, si se confirma, intenta ir al menú
##    principal (por ahora, reinicia la partida como reemplazo temporal).
##  - Abandonar: pide confirmación y, si se confirma, cierra el juego.
##
## IMPORTANTE: el nodo raíz debe tener Process Mode = "Always" en el
## Inspector, porque al pausar el árbol todo lo demás se congela y los
## botones dejarían de responder.
extends Control

## Referencias a los tres bloques de la interfaz. Solo uno está visible
## a la vez: los botones principales, la cuenta regresiva, o el diálogo
## de confirmación.
@onready var main_buttons: VBoxContainer = $MainButtons
@onready var countdown_label: Label = $CountdownLabel
@onready var confirm_dialog: VBoxContainer = $ConfirmDialog
@onready var confirm_label: Label = $ConfirmDialog/ConfirmLabel

## Mensaje fijo que se muestra en AMBAS confirmaciones (Salir y Abandonar).
## Al ser el mismo texto en los dos casos, lo dejamos como constante en
## vez de repetirlo, así solo hay que cambiarlo en un lugar si se ajusta.
const CONFIRM_MESSAGE := "¿Te vas? Perderás el progreso de la partida, ¿seguro que quieres hacerlo?"

## Cuántos segundos dura la cuenta regresiva de "Continuar".
const COUNTDOWN_SECONDS := 3

## Guarda qué función ejecutar si el jugador confirma en el diálogo de
## advertencia. Se define justo antes de mostrar el diálogo (en
## _on_exit_pressed o _on_abandon_pressed), porque "Salir" y "Abandonar"
## comparten el mismo diálogo visual pero cada uno confirma algo distinto.
var pending_confirm_action: Callable

## true mientras la cuenta regresiva de "Continuar" está corriendo.
## Evita que se dispare dos veces si el jugador insiste con la tecla P.
var is_counting_down := false


func _ready() -> void:
	hide()
	main_buttons.hide()
	countdown_label.hide()
	confirm_dialog.hide()

	$MainButtons/ContinueButton.pressed.connect(_on_continue_pressed)
	$MainButtons/ExitButton.pressed.connect(_on_exit_pressed)
	$MainButtons/AbandonButton.pressed.connect(_on_abandon_pressed)
	$ConfirmDialog/ConfirmButtons/ConfirmAbandonButton.pressed.connect(_on_confirm_abandon_pressed)
	$ConfirmDialog/ConfirmButtons/ConfirmContinueButton.pressed.connect(_on_confirm_seguir_pressed)


## Este nodo, al ser Process Mode = Always, sigue recibiendo input aunque
## el árbol esté pausado. Por eso también puede escuchar la tecla "pause"
## aquí para cerrar el menú, no solo main.gd para abrirlo.
## Solo reacciona si el menú está visible Y se están mostrando los
## botones principales (no durante la cuenta regresiva ni el diálogo de
## confirmación, para no interrumpirlos a medias).
func _unhandled_input(event: InputEvent) -> void:
	if not visible or not main_buttons.visible:
		return
	if event.is_action_pressed("pause"):
		_on_continue_pressed()


## La llama main.gd cuando el jugador presiona P durante la partida.
func open() -> void:
	show()
	main_buttons.show()
	countdown_label.hide()
	confirm_dialog.hide()
	get_tree().paused = true


## Botón "Continuar": en vez de reanudar de inmediato, muestra una
## cuenta regresiva. El juego SIGUE pausado mientras cuenta (get_tree().paused
## no cambia todavía), y recién al llegar a 0 se reanuda de verdad.
func _on_continue_pressed() -> void:
	if is_counting_down:
		return
	is_counting_down = true
	main_buttons.hide()
	countdown_label.show()

	var seconds_left := COUNTDOWN_SECONDS
	while seconds_left > 0:
		countdown_label.text = str(seconds_left)
		# create_timer() con process_always = true (su valor por defecto)
		# sigue corriendo aunque el árbol esté pausado — por eso funciona
		# para contar mientras el juego sigue congelado.
		await get_tree().create_timer(1.0).timeout
		seconds_left -= 1

	is_counting_down = false
	countdown_label.hide()
	hide()
	get_tree().paused = false


## Botón "Salir": pide confirmación. Si se confirma, la acción pendiente
## es ir al menú principal (placeholder por ahora).
func _on_exit_pressed() -> void:
	show_confirm(_confirm_go_to_menu)


## Botón "Abandonar": pide confirmación. Si se confirma, la acción
## pendiente es cerrar el juego.
func _on_abandon_pressed() -> void:
	show_confirm(_confirm_quit_game)


## Oculta los botones principales y muestra el diálogo de advertencia,
## guardando qué hacer si el jugador confirma.
func show_confirm(action: Callable) -> void:
	pending_confirm_action = action
	confirm_label.text = CONFIRM_MESSAGE
	main_buttons.hide()
	confirm_dialog.show()


## Botón "Abandonar" DENTRO del diálogo de confirmación (distinto del
## botón "Abandonar" del menú principal). Ejecuta la acción que se
## guardó al abrir el diálogo.
func _on_confirm_abandon_pressed() -> void:
	confirm_dialog.hide()
	pending_confirm_action.call()


## Botón "Seguir": cancela, vuelve al menú de pausa normal.
func _on_confirm_seguir_pressed() -> void:
	confirm_dialog.hide()
	main_buttons.show()


## Acción pendiente de "Salir" confirmado. Debería ir al menú principal,
## pero como todavía no existe, reinicia la partida actual como
## reemplazo temporal. Cuando exista el menú, reemplazar por:
## get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
func _confirm_go_to_menu() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


## Acción pendiente de "Abandonar" confirmado: cierra el juego.
func _confirm_quit_game() -> void:
	get_tree().quit()
