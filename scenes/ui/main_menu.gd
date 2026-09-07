## Menú principal del juego. Tiene una vista de inicio (HomeView) y
## cuatro paneles a pantalla completa (Misiones, Yo, Tienda,
## Configuración) que se muestran uno a la vez, nunca superpuestos.
##
## Misiones, Yo y Tienda ya tienen su contenido final (con datos y
## economía simplificados, sin sistemas reales detrás). Configuración
## todavía es un placeholder.
extends Control

## Referencia a las 5 "vistas" posibles. show_only() se encarga de que
## solo una esté visible a la vez.
@onready var home_view: Control = $HomeView
@onready var missions_panel: Control = $MissionsPanel
@onready var me_panel: Control = $MePanel
@onready var store_panel: Control = $StorePanel
@onready var config_panel: Control = $ConfigPanel

## Etiquetas de récord y monedas. El récord solo existe en Home; las
## monedas se repiten en Home, Misiones, Yo y Tienda (Configuración no
## las necesita), así que se actualizan todas juntas en un array.
@onready var record_label: Label = $HomeView/AvatarRecord/InfoBox/RecordLabel
@onready var coin_labels: Array[Label] = [
	$HomeView/AvatarRecord/InfoBox/CoinLabel,
	$MissionsPanel/Header/CoinLabel,
	$MePanel/Header/CoinLabel,
	$StorePanel/Header/CoinLabel,
]

## Las dos listas de misiones. Solo una está visible a la vez: arranca
## mostrando la diaria, igual que en el boceto original.
@onready var daily_list: VBoxContainer = $MissionsPanel/DailyList
@onready var season_list: VBoxContainer = $MissionsPanel/SeasonList

## Nodos de la tienda.
@onready var free_gift_button: Button = $StorePanel/ItemsBox/FreeGiftRow/FreeGiftButton
@onready var crate1_button: Button = $StorePanel/ItemsBox/CrateRow1/Crate1Button
@onready var crate2_button: Button = $StorePanel/ItemsBox/CrateRow2/Crate2Button
@onready var store_status_label: Label = $StorePanel/ItemsBox/StatusLabel

## Costo y recompensa de cada caja. Es una economía simplificada y
## decorativa (pagas monedas para recibir más monedas) porque el juego
## todavía no tiene potenciadores reales que vender.
const CRATE_SMALL_COST := 50
const CRATE_SMALL_REWARD := 80
const CRATE_LARGE_COST := 150
const CRATE_LARGE_REWARD := 220

## Qué vista estaba abierta antes de entrar a Configuración. Se usa
## para que la X de Configuración vuelva justo ahí, en vez de siempre
## al inicio — así, si abres Configuración desde Misiones, la X te
## regresa a Misiones, no al Home.
var previous_view: Control


func _ready() -> void:
	previous_view = home_view

	# Botones de la vista de inicio.
	$HomeView/PlayButton.pressed.connect(_on_play_pressed)
	$HomeView/SettingsButton.pressed.connect(_on_settings_pressed)
	$HomeView/BottomIcons/MissionsButton.pressed.connect(_on_missions_pressed)
	$HomeView/BottomIcons/MeButton.pressed.connect(_on_me_pressed)
	$HomeView/BottomIcons/StoreButton.pressed.connect(_on_store_pressed)

	# Cada panel (menos Configuración) tiene su propio botón de
	# engranaje: los tres llevan al mismo sitio, por eso reutilizan
	# _on_settings_pressed en vez de tener una función cada uno.
	$MissionsPanel/SettingsButton.pressed.connect(_on_settings_pressed)
	$MePanel/SettingsButton.pressed.connect(_on_settings_pressed)
	$StorePanel/SettingsButton.pressed.connect(_on_settings_pressed)

	# Las X de Misiones, Yo y Tienda siempre vuelven al inicio.
	$MissionsPanel/CloseButton.pressed.connect(_on_close_pressed)
	$MePanel/CloseButton.pressed.connect(_on_close_pressed)
	$StorePanel/CloseButton.pressed.connect(_on_close_pressed)
	# La X de Configuración es distinta: vuelve a "previous_view", no
	# siempre al inicio.
	$ConfigPanel/CloseButton.pressed.connect(_on_config_close_pressed)

	# Pestañas de Misiones: alternan entre la lista diaria y la de
	# temporada, nunca se muestran las dos a la vez.
	$MissionsPanel/TabButtons/DailyTabButton.pressed.connect(_on_daily_tab_pressed)
	$MissionsPanel/TabButtons/SeasonTabButton.pressed.connect(_on_season_tab_pressed)

	# Botones de la tienda.
	free_gift_button.pressed.connect(_on_free_gift_pressed)
	crate1_button.pressed.connect(_on_buy_crate_small_pressed)
	crate2_button.pressed.connect(_on_buy_crate_large_pressed)

	show_only(home_view)


## Cuál de los 4 paneles (o Home) está visible ahora mismo. Se usa para
## recordar de dónde venía el jugador antes de abrir Configuración.
func get_current_view() -> Control:
	if missions_panel.visible:
		return missions_panel
	if me_panel.visible:
		return me_panel
	if store_panel.visible:
		return store_panel
	return home_view


## Actualiza el texto del récord y de todas las etiquetas de monedas,
## leyendo el Autoload GameData. Se llama cada vez que se cambia de
## vista, para que los números nunca se queden desactualizados.
func refresh_labels() -> void:
	record_label.text = "Mejor puntuación: %d m" % GameData.best_distance
	var coin_text := "🪙 %d" % GameData.total_coins
	for label in coin_labels:
		label.text = coin_text


## Deja el botón de regalo gratis deshabilitado si ya se reclamó en
## esta sesión. Se llama al abrir la tienda, no solo al arrancar el
## juego, por si se reclamó y luego se navegó a otra pantalla.
func refresh_store() -> void:
	free_gift_button.disabled = GameData.daily_gift_claimed


## Muestra únicamente la vista indicada y oculta las otras cuatro.
func show_only(view: Control) -> void:
	refresh_labels()
	if view == store_panel:
		refresh_store()
	home_view.visible = (view == home_view)
	missions_panel.visible = (view == missions_panel)
	me_panel.visible = (view == me_panel)
	store_panel.visible = (view == store_panel)
	config_panel.visible = (view == config_panel)


## Botón "Toca para jugar": carga la escena de la partida.
func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")


## Guarda desde dónde se abrió Configuración, para que su X sepa a
## dónde volver.
func _on_settings_pressed() -> void:
	previous_view = get_current_view()
	show_only(config_panel)


func _on_missions_pressed() -> void:
	show_only(missions_panel)


func _on_me_pressed() -> void:
	show_only(me_panel)


func _on_store_pressed() -> void:
	show_only(store_panel)


## X de Misiones, Yo y Tienda: siempre vuelve al inicio.
func _on_close_pressed() -> void:
	show_only(home_view)


## X de Configuración: vuelve a la vista desde donde se abrió (Home,
## Misiones, Yo o Tienda), no siempre al inicio.
func _on_config_close_pressed() -> void:
	show_only(previous_view)


## Pestaña "Objetivo diario": muestra la lista diaria y oculta la de
## temporada.
func _on_daily_tab_pressed() -> void:
	daily_list.show()
	season_list.hide()


## Pestaña "Objetivo Temporada": muestra la lista de temporada y oculta
## la diaria.
func _on_season_tab_pressed() -> void:
	daily_list.hide()
	season_list.show()


## Botón "Reclamar" del regalo gratis. GameData decide si ya se había
## reclamado (devuelve 0 en ese caso, aunque el botón deshabilitado ya
## debería evitar que se pueda pulsar dos veces).
func _on_free_gift_pressed() -> void:
	var reward := GameData.claim_daily_gift()
	if reward > 0:
		store_status_label.text = "¡Reclamaste %d monedas!" % reward
	refresh_labels()
	refresh_store()


## Compra la caja pequeña, si alcanzan las monedas.
func _on_buy_crate_small_pressed() -> void:
	buy_crate(CRATE_SMALL_COST, CRATE_SMALL_REWARD)


## Compra la caja grande, si alcanzan las monedas.
func _on_buy_crate_large_pressed() -> void:
	buy_crate(CRATE_LARGE_COST, CRATE_LARGE_REWARD)


## Lógica compartida por las dos cajas: intenta descontar el costo y,
## si alcanzó, suma la recompensa. Es una economía decorativa (se paga
## en monedas para recibir más monedas) porque todavía no hay
## potenciadores reales que vender.
func buy_crate(cost: int, reward: int) -> void:
	if GameData.try_spend_coins(cost):
		GameData.total_coins += reward
		store_status_label.text = "¡Abriste la caja y ganaste %d monedas!" % reward
	else:
		store_status_label.text = "No tienes suficientes monedas."
	refresh_labels()
