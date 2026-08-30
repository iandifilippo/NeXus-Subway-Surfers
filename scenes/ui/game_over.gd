## Pantalla de derrota. Muestra el resultado de la partida y ofrece reiniciar.
## IMPORTANTE: el nodo raíz debe tener Process Mode = "Always" en el Inspector,
## porque al pausar el árbol todo lo demás se congela y los botones
## dejarían de responder.
extends Control

## Etiqueta donde se escribe la distancia y las monedas conseguidas.
@onready var score_label: Label = $VBoxContainer/ScoreLabel


## Se ejecuta al cargar la escena, antes de que empiece la partida.
## La pantalla arranca oculta y solo aparece al morir.
func _ready() -> void:
	hide()
	# Conectamos las señales de los botones por código en vez de por el editor.
	# "pressed" es la señal que emite un Button al ser clickeado.
	$VBoxContainer/RetryButton.pressed.connect(_on_retry)
	$VBoxContainer/MenuButton.pressed.connect(_on_menu)


## La llama main.gd cuando el jugador choca contra un obstáculo.
## Recibe los datos finales de la partida para mostrarlos.
func show_game_over(distance: float, coins: int) -> void:
	# %d formatea un número como entero (sin decimales).
	score_label.text = "%d m  •  %d monedas" % [distance, coins]
	show()
	# Congela TODO el árbol de nodos: el mundo deja de moverse,
	# el jugador deja de responder, las animaciones se detienen.
	get_tree().paused = true


## Botón "Reintentar": despausa y vuelve a cargar la escena desde cero.
## Hay que despausar ANTES de recargar, o la escena nueva nacería congelada.
func _on_retry() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


## Botón "Menú". Por ahora hace lo mismo que reintentar.
## Cuando exista un menú principal, aquí iría:
## get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
func _on_menu() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
