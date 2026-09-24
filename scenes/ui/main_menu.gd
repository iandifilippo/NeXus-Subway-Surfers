## Menú principal del juego. Tiene una vista de inicio (HomeView) y
## cinco paneles a pantalla completa (Misiones, Yo, Tienda,
## Configuración, Cómo jugar) que se muestran uno a la vez, nunca
## superpuestos.
extends Control

## Referencia a las 6 "vistas" posibles. show_only() se encarga de que
## solo una esté visible a la vez.
@onready var home_view: Control = $HomeView
@onready var missions_panel: Control = $MissionsPanel
@onready var me_panel: Control = $MePanel
@onready var store_panel: Control = $StorePanel
@onready var config_panel: Control = $ConfigPanel
@onready var tutorial_panel: Control = $TutorialPanel

## Etiquetas de récord y monedas. El récord solo existe en Home; las
## monedas se repiten en Home, Misiones, Yo y Tienda (Configuración y
## Cómo jugar no las necesitan), así que se actualizan todas juntas en
## un array.
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

## Pestañas de Misiones, guardadas aparte para poder resaltar cuál está
## activa cada vez que se cambia de lista (issue #31).
@onready var daily_tab_button: Button = $MissionsPanel/TabButtons/DailyTabButton
@onready var season_tab_button: Button = $MissionsPanel/TabButtons/SeasonTabButton

## Nodos de la tienda.
@onready var free_gift_button: Button = $StorePanel/ItemsBox/FreeGiftRow/FreeGiftButton
@onready var crate1_button: Button = $StorePanel/ItemsBox/CrateRow1/Crate1Button
@onready var crate2_button: Button = $StorePanel/ItemsBox/CrateRow2/Crate2Button
@onready var store_status_label: Label = $StorePanel/ItemsBox/StatusLabel

## Nodos de la pantalla "Yo" (selección de personaje).
@onready var character_image: TextureRect = $MePanel/CharacterBox/CharacterImage
@onready var character_name_label: Label = $MePanel/CharacterBox/CharacterNameLabel
@onready var coming_soon_label: Label = $MePanel/CharacterBox/ComingSoonLabel
@onready var selected_button: Button = $MePanel/CharacterBox/SelectedButton
@onready var prev_char_button: Button = $MePanel/CharacterBox/CharacterCarousel/PrevButton
@onready var next_char_button: Button = $MePanel/CharacterBox/CharacterCarousel/NextButton

## Catálogo de personajes de la pantalla "Yo". Solo "jake" tiene arte
## real disponible en el proyecto; los otros dos son placeholders
## bloqueados para dejar el sistema listo para cuando existan (issue
## #30 pedía que las flechas y los botones dejaran de estar congelados,
## no arte nuevo).
const CHARACTERS := [
	{"id": "jake", "name": "Jake", "texture": preload("res://assets/models/player/ref2.png"), "unlocked": true},
	{"id": "locked_1", "name": "Personaje 2", "texture": preload("res://assets/models/player/ref2.png"), "unlocked": false},
	{"id": "locked_2", "name": "Personaje 3", "texture": preload("res://assets/models/player/ref2.png"), "unlocked": false},
]

## Índice del personaje que se está mostrando ahora mismo en el carrusel.
var current_character_index: int = 0

## Costo y recompensa de cada caja. Es una economía simplificada y
## decorativa (pagas monedas para recibir más monedas) porque el juego
## todavía no tiene potenciadores reales que vender.
const CRATE_SMALL_COST := 50
const CRATE_SMALL_REWARD := 80
const CRATE_LARGE_COST := 150
const CRATE_LARGE_REWARD := 220

## --- Misiones reales, basadas en estadísticas del juego ---
## "Diaria" y "Temporada" son solo dos categorías visuales — como el
## proyecto no guarda nada en disco (ver GameData), ninguna se
## reinicia de verdad por día ni por temporada: ambas viven mientras
## dure la sesión. El botón "Vamos" siempre está activo — lleva al
## Home para que el jugador entre a una partida por su cuenta; el
## progreso se actualiza solo leyendo GameData.get_stat(), y al
## cumplirse la meta el botón pasa a "Completado" (checklist, sin
## recompensa en monedas).
const MISSIONS_DAILY := [
	{"id": "daily_coins_50", "desc": "Recoge 50 monedas", "stat": "lifetime_coins", "target": 50.0},
	{"id": "daily_distance_500", "desc": "Recorre 500 metros en una partida", "stat": "best_distance", "target": 500.0},
	{"id": "daily_coins_100", "desc": "Recoge 100 monedas", "stat": "lifetime_coins", "target": 100.0},
]
const MISSIONS_SEASON := [
	{"id": "season_coins_1000", "desc": "Recoge 1000 monedas", "stat": "lifetime_coins", "target": 1000.0},
	{"id": "season_distance_5000", "desc": "Recorre 5000 metros acumulados", "stat": "total_distance_traveled", "target": 5000.0},
	{"id": "season_runs_10", "desc": "Juega 10 partidas", "stat": "runs_played", "target": 10.0},
]

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
	$HomeView/BottomIcons/TutorialButton.pressed.connect(_on_tutorial_pressed)

	# Cada panel (menos Configuración y Cómo jugar) tiene su propio
	# botón de engranaje: los tres llevan al mismo sitio, por eso
	# reutilizan _on_settings_pressed en vez de tener una función cada
	# uno.
	$MissionsPanel/SettingsButton.pressed.connect(_on_settings_pressed)
	$MePanel/SettingsButton.pressed.connect(_on_settings_pressed)
	$StorePanel/SettingsButton.pressed.connect(_on_settings_pressed)

	# Las X de Misiones, Yo, Tienda y Cómo jugar siempre vuelven al
	# inicio.
	$MissionsPanel/CloseButton.pressed.connect(_on_close_pressed)
	$MePanel/CloseButton.pressed.connect(_on_close_pressed)
	$StorePanel/CloseButton.pressed.connect(_on_close_pressed)
	$TutorialPanel/CloseButton.pressed.connect(_on_close_pressed)
	# La X de Configuración es distinta: vuelve a "previous_view", no
	# siempre al inicio.
	$ConfigPanel/CloseButton.pressed.connect(_on_config_close_pressed)

	# Pestañas de Misiones: alternan entre la lista diaria y la de
	# temporada, nunca se muestran las dos a la vez.
	$MissionsPanel/TabButtons/DailyTabButton.pressed.connect(_on_daily_tab_pressed)
	$MissionsPanel/TabButtons/SeasonTabButton.pressed.connect(_on_season_tab_pressed)

	# Botones "Vamos" de cada misión, diaria y de temporada — todos
	# hacen lo mismo (cierran Misiones y dejan al jugador en el Home),
	# así que se conectan todos a la misma función.
	for i in MISSIONS_DAILY.size():
		var daily_row: HBoxContainer = daily_list.get_node("MissionRow%d" % (i + 1))
		daily_row.get_node("GoButton").pressed.connect(_on_mission_go_pressed)
	for i in MISSIONS_SEASON.size():
		var season_row: HBoxContainer = season_list.get_node("MissionRow%d" % (i + 1))
		season_row.get_node("GoButton").pressed.connect(_on_mission_go_pressed)

	# Botones de la tienda.
	free_gift_button.pressed.connect(_on_free_gift_pressed)
	crate1_button.pressed.connect(_on_buy_crate_small_pressed)
	crate2_button.pressed.connect(_on_buy_crate_large_pressed)

	# Carrusel de personajes de la pantalla "Yo".
	prev_char_button.pressed.connect(_on_char_prev_pressed)
	next_char_button.pressed.connect(_on_char_next_pressed)
	selected_button.pressed.connect(_on_select_character_pressed)
	current_character_index = _find_character_index(GameData.selected_character)
	_refresh_character_view()

	_setup_home_background()
	_setup_play_button()
	_setup_missions_style()
	refresh_missions()

	show_only(home_view)


## Cuál de las 5 vistas (o Home) está visible ahora mismo. Se usa para
## recordar de dónde venía el jugador antes de abrir Configuración.
func get_current_view() -> Control:
	if missions_panel.visible:
		return missions_panel
	if me_panel.visible:
		return me_panel
	if store_panel.visible:
		return store_panel
	if tutorial_panel.visible:
		return tutorial_panel
	return home_view


## Actualiza el texto del récord y de todas las etiquetas de monedas,
## leyendo el Autoload GameData. Se llama cada vez que se cambia de
## vista, para que los números nunca se queden desactualizados.
func refresh_labels() -> void:
	record_label.text = "Mejor puntuación: %d m" % GameData.best_distance
	var coin_text := "🪙 %d" % GameData.total_coins
	for label in coin_labels:
		label.text = coin_text


## Deja el botón de regalo gratis y los de las dos cajas deshabilitados
## si ya se reclamaron/compraron en esta sesión. Se llama al abrir la
## tienda, no solo al arrancar el juego, por si se compró algo y luego
## se navegó a otra pantalla.
func refresh_store() -> void:
	free_gift_button.disabled = GameData.daily_gift_claimed
	_update_crate_button(crate1_button, "small")
	_update_crate_button(crate2_button, "large")


## Deja un botón de caja listo para comprar ("Comprar", habilitado) o
## ya usado ("Ya comprada", deshabilitado) según GameData, igual que ya
## se hacía con el regalo gratis.
func _update_crate_button(button: Button, crate_id: String) -> void:
	if GameData.is_crate_purchased(crate_id):
		button.disabled = true
		button.text = "Ya comprada"
	else:
		button.disabled = false
		button.text = "Comprar"


## Actualiza el texto y el botón "Vamos"/"Completado" de cada fila de
## misión, diarias y de temporada, leyendo el progreso real desde
## GameData. Se llama al entrar a Misiones y al volver de una partida.
func refresh_missions() -> void:
	_refresh_mission_list(MISSIONS_DAILY, daily_list)
	_refresh_mission_list(MISSIONS_SEASON, season_list)


## Recorre una lista de misiones (diarias o de temporada) y actualiza
## su fila correspondiente: el texto con el progreso actual sobre la
## meta, y el botón — "Vamos" si falta progreso, "Completado"
## (deshabilitado, solo checklist) si ya se cumplió.
func _refresh_mission_list(missions: Array, list: VBoxContainer) -> void:
	for i in missions.size():
		var mission: Dictionary = missions[i]
		var row: HBoxContainer = list.get_node("MissionRow%d" % (i + 1))
		var desc_label: Label = row.get_node("DescLabel")
		var go_button: Button = row.get_node("GoButton")

		var progress: float = GameData.get_stat(mission.stat)
		var target: float = mission.target
		var shown_progress: int = int(minf(progress, target))
		desc_label.text = "%s (%d/%d)" % [mission.desc, shown_progress, int(target)]

		if progress >= target:
			go_button.text = "Completado"
			go_button.disabled = true
		else:
			go_button.text = "Vamos"
			go_button.disabled = false


## Muestra únicamente la vista indicada y oculta las otras cinco.
func show_only(view: Control) -> void:
	refresh_labels()
	if view == store_panel:
		refresh_store()
	if view == missions_panel:
		refresh_missions()
	home_view.visible = (view == home_view)
	missions_panel.visible = (view == missions_panel)
	me_panel.visible = (view == me_panel)
	store_panel.visible = (view == store_panel)
	config_panel.visible = (view == config_panel)
	tutorial_panel.visible = (view == tutorial_panel)


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
	_refresh_character_view()
	show_only(me_panel)


func _on_store_pressed() -> void:
	show_only(store_panel)


## Botón "❓ Cómo jugar": muestra la lista de controles.
func _on_tutorial_pressed() -> void:
	show_only(tutorial_panel)


## X de Misiones, Yo, Tienda y Cómo jugar: siempre vuelve al inicio.
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
	_style_tab(daily_tab_button, true)
	_style_tab(season_tab_button, false)


## Pestaña "Objetivo Temporada": muestra la lista de temporada y oculta
## la diaria.
func _on_season_tab_pressed() -> void:
	daily_list.hide()
	season_list.show()
	_style_tab(daily_tab_button, false)
	_style_tab(season_tab_button, true)


## --- Issue #32: fondo plano y botón de jugar sin prominencia ---

## Reemplaza el ColorRect casi invisible por un degradado (sin depender
## de un asset ilustrativo nuevo), para que la pantalla de inicio deje
## de verse como un gris plano vacío.
func _setup_home_background() -> void:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(0.06, 0.08, 0.2),
		Color(0.16, 0.06, 0.24),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	$Background.texture = texture


## Le da al botón central un color de acento, esquinas redondeadas y una
## animación de pulso continua para que llame la atención desde el
## primer contacto, en vez de ser un botón más entre otros.
func _setup_play_button() -> void:
	var button: Button = $HomeView/PlayButton

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.95, 0.4, 0.1)
	normal_style.set_corner_radius_all(18)
	normal_style.shadow_size = 10
	normal_style.shadow_color = Color(0, 0, 0, 0.35)

	var hover_style := normal_style.duplicate()
	hover_style.bg_color = normal_style.bg_color.lightened(0.12)

	var pressed_style := normal_style.duplicate()
	pressed_style.bg_color = normal_style.bg_color.darkened(0.12)

	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_color_override("font_color", Color(1, 1, 1))

	# El pivote tiene que quedar en el centro del botón para que el
	# pulso escale hacia adentro/afuera en vez de desplazarse.
	await get_tree().process_frame
	button.pivot_offset = button.size / 2.0

	var tween := create_tween().set_loops()
	tween.tween_property(button, "scale", Vector2(1.05, 1.05), 0.7)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.7)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## --- Issue #31: falta de jerarquía visual y lecturabilidad en Misiones ---

## Sube el contraste del panel de Misiones (fondo oscuro semitransparente
## en vez de casi invisible, texto claro, botones "Vamos" más grandes) y
## dobla las pestañas en un ButtonGroup para que la activa quede resaltada.
func _setup_missions_style() -> void:
	var panel_bg: ColorRect = $MissionsPanel/ColorRect
	panel_bg.color = Color(0.05, 0.06, 0.1, 0.75)

	var title: Label = $MissionsPanel/Header/TitleLabel
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.add_theme_font_size_override("font_size", 26)

	for list in [daily_list, season_list]:
		for row in list.get_children():
			var desc: Label = row.get_node("DescLabel")
			desc.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
			desc.add_theme_font_size_override("font_size", 16)
			var go_button: Button = row.get_node("GoButton")
			go_button.custom_minimum_size = Vector2(96, 40)
			go_button.add_theme_font_size_override("font_size", 16)

	var tab_group := ButtonGroup.new()
	daily_tab_button.toggle_mode = true
	season_tab_button.toggle_mode = true
	daily_tab_button.button_group = tab_group
	season_tab_button.button_group = tab_group
	daily_tab_button.button_pressed = true
	_style_tab(daily_tab_button, true)
	_style_tab(season_tab_button, false)


## Resalta la pestaña activa (más grande y en color de acento) y atenúa
## la inactiva, para que siempre sea obvio cuál lista se está viendo.
func _style_tab(tab: Button, active: bool) -> void:
	if active:
		tab.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		tab.add_theme_font_size_override("font_size", 16)
	else:
		tab.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		tab.add_theme_font_size_override("font_size", 14)


## Busca en CHARACTERS el índice del personaje con este id (el que venga
## de GameData.selected_character). Si no lo encuentra, empieza en 0.
func _find_character_index(character_id: String) -> int:
	for i in CHARACTERS.size():
		if CHARACTERS[i].id == character_id:
			return i
	return 0


## --- Issue #30: selección de personaje sin interactividad en "Yo" ---

## Flecha "<": retrocede al personaje anterior, dando la vuelta al llegar
## al primero.
func _on_char_prev_pressed() -> void:
	current_character_index = wrapi(current_character_index - 1, 0, CHARACTERS.size())
	_refresh_character_view()


## Flecha ">": avanza al siguiente personaje, dando la vuelta al llegar
## al último.
func _on_char_next_pressed() -> void:
	current_character_index = wrapi(current_character_index + 1, 0, CHARACTERS.size())
	_refresh_character_view()


## Botón principal del carrusel: solo hace algo si el personaje mostrado
## está desbloqueado y no es ya el que está en uso. Guarda la elección en
## GameData para que se recuerde mientras dure la sesión.
func _on_select_character_pressed() -> void:
	var data: Dictionary = CHARACTERS[current_character_index]
	if not data.unlocked or data.id == GameData.selected_character:
		return
	GameData.selected_character = data.id
	_refresh_character_view()


## Redibuja el carrusel completo: imagen, nombre, y el botón en uno de
## sus tres estados ("Seleccionar", "En uso" o "Bloqueado"), según el
## personaje que toque mostrar y cuál esté elegido en GameData.
func _refresh_character_view() -> void:
	var data: Dictionary = CHARACTERS[current_character_index]

	character_image.texture = data.texture
	character_image.modulate = Color(1, 1, 1) if data.unlocked else Color(0.35, 0.35, 0.35)
	character_name_label.text = data.name if data.unlocked else "🔒 %s" % data.name
	coming_soon_label.visible = not data.unlocked

	if not data.unlocked:
		selected_button.text = "Bloqueado"
		selected_button.disabled = true
	elif data.id == GameData.selected_character:
		selected_button.text = "En uso"
		selected_button.disabled = true
	else:
		selected_button.text = "Seleccionar"
		selected_button.disabled = false


## Botón "Reclamar" del regalo gratis. GameData decide si ya se había
## reclamado (devuelve 0 en ese caso, aunque el botón deshabilitado ya
## debería evitar que se pueda pulsar dos veces).
func _on_free_gift_pressed() -> void:
	var reward := GameData.claim_daily_gift()
	if reward > 0:
		store_status_label.text = "¡Reclamaste %d monedas!" % reward
	refresh_labels()
	refresh_store()


## Compra la caja pequeña, si alcanzan las monedas y no se había
## comprado ya en esta sesión.
func _on_buy_crate_small_pressed() -> void:
	buy_crate("small", CRATE_SMALL_COST, CRATE_SMALL_REWARD)


## Compra la caja grande, si alcanzan las monedas y no se había
## comprado ya en esta sesión.
func _on_buy_crate_large_pressed() -> void:
	buy_crate("large", CRATE_LARGE_COST, CRATE_LARGE_REWARD)


## Lógica compartida por las dos cajas: revisa que no se haya comprado
## ya esta sesión, intenta descontar el costo y, si alcanzó, suma la
## recompensa y la marca como comprada. Es una economía decorativa (se
## paga en monedas para recibir más monedas) porque todavía no hay
## potenciadores reales que vender.
func buy_crate(crate_id: String, cost: int, reward: int) -> void:
	if GameData.is_crate_purchased(crate_id):
		# El botón ya debería estar deshabilitado en este caso, pero se
		# revisa igual por seguridad.
		store_status_label.text = "Ya compraste esta caja en esta partida."
		refresh_store()
		return
	if GameData.try_spend_coins(cost):
		GameData.total_coins += reward
		GameData.mark_crate_purchased(crate_id)
		store_status_label.text = "¡Abriste la caja y ganaste %d monedas!" % reward
	else:
		store_status_label.text = "No tienes suficientes monedas."
	refresh_labels()
	refresh_store()


## Botón "Vamos" de cualquier misión: cierra el panel de Misiones y
## deja al jugador en el menú principal, listo para darle a "Toca para
## jugar" por su cuenta.
func _on_mission_go_pressed() -> void:
	show_only(home_view)
