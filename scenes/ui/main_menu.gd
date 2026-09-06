## Menú principal del juego. Tiene una vista de inicio (HomeView) y
## cuatro paneles a pantalla completa (Misiones, Yo, Tienda,
## Configuración) que se muestran uno a la vez, nunca superpuestos.
##
## Por ahora los cuatro paneles solo tienen un título, un botón de
## cerrar y un texto de "Próximamente" — el contenido real de cada uno
## se agrega en commits separados más adelante.
extends Control

## Referencia a las 5 "vistas" posibles. show_only() se encarga de que
## solo una esté visible a la vez.
@onready var home_view: Control = $HomeView
@onready var missions_panel: Control = $MissionsPanel
@onready var me_panel: Control = $MePanel
@onready var store_panel: Control = $StorePanel
@onready var config_panel: Control = $ConfigPanel

@onready var record_label: Label = $HomeView/AvatarRecord/RecordLabel


func _ready() -> void:
	# Botones de la vista de inicio.
	$HomeView/PlayButton.pressed.connect(_on_play_pressed)
	$HomeView/SettingsButton.pressed.connect(_on_settings_pressed)
	$HomeView/BottomIcons/MissionsButton.pressed.connect(_on_missions_pressed)
	$HomeView/BottomIcons/MeButton.pressed.connect(_on_me_pressed)
	$HomeView/BottomIcons/StoreButton.pressed.connect(_on_store_pressed)

	# Cada panel (menos Configuración) tiene su propio botón de
	# engranaje: los tres llevan al mismo sitio, por eso reutilizan
	# _on_settings_pressed en vez de tener una función cada uno.
	$MissionsPanel/Header/SettingsButton.pressed.connect(_on_settings_pressed)
	$MePanel/Header/SettingsButton.pressed.connect(_on_settings_pressed)
	$StorePanel/Header/SettingsButton.pressed.connect(_on_settings_pressed)

	# Los cuatro botones "X" hacen exactamente lo mismo: volver al inicio.
	$MissionsPanel/Header/CloseButton.pressed.connect(_on_close_pressed)
	$MePanel/Header/CloseButton.pressed.connect(_on_close_pressed)
	$StorePanel/Header/CloseButton.pressed.connect(_on_close_pressed)
	$ConfigPanel/Header/CloseButton.pressed.connect(_on_close_pressed)

	update_record_label()
	show_only(home_view)


## Actualiza el texto del récord leyendo el Autoload GameData. Se llama
## al abrir el menú y también al volver de cualquier panel, por si
## acaso el valor cambió mientras tanto (por ejemplo, después de jugar
## una partida y volver aquí).
func update_record_label() -> void:
	record_label.text = "Mejor puntuación: %d m" % GameData.best_distance


## Muestra únicamente la vista indicada y oculta las otras cuatro.
## Centralizarlo en una sola función evita tener que acordarse de
## ocultar manualmente cada panel en cada botón que cambia de vista.
func show_only(view: Control) -> void:
	home_view.visible = (view == home_view)
	missions_panel.visible = (view == missions_panel)
	me_panel.visible = (view == me_panel)
	store_panel.visible = (view == store_panel)
	config_panel.visible = (view == config_panel)


## Botón "Toca para jugar": carga la escena de la partida.
func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")


func _on_settings_pressed() -> void:
	show_only(config_panel)


func _on_missions_pressed() -> void:
	show_only(missions_panel)


func _on_me_pressed() -> void:
	show_only(me_panel)


func _on_store_pressed() -> void:
	show_only(store_panel)


## Cualquiera de los cuatro botones "X" llama aquí: vuelve al inicio y
## refresca el récord por si cambió.
func _on_close_pressed() -> void:
	update_record_label()
	show_only(home_view)
