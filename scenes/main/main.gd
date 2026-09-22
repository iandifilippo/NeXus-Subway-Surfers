## Controlador principal del juego.
##
## DECISIÓN DE ARQUITECTURA: el jugador nunca avanza. Se queda fijo en Z=0
## y es este script el que mueve el mundo entero hacia él (+Z). Esto evita
## acumular coordenadas enormes (que degradan la precisión de los float en
## partidas largas), permite reusar un pool fijo de nodos, y hace que la
## cámara no necesite lógica de seguimiento EN PROFUNDIDAD (eje Z) — solo
## necesita seguir al jugador de lado a lado (eje X) cuando cambia de carril.
extends Node3D # Define que este nodo hereda de Node3D para manejar espacio tridimensional

## --- Terreno ---
const CHUNK_SCENE := preload("res://scenes/chunks/ground_chunk.tscn")
const CHUNK_LENGTH: float = 60.0
const CHUNK_COUNT: int = 20

## --- Dificultad ---
const START_SPEED: float = 12.0
const MAX_SPEED: float = 32.0
const ACCELERATION: float = 0.35

## --- Obstáculos ---
const TRAIN_SCENE := preload("res://scenes/obstacles/train.tscn")
const OBSTACLES: Array[PackedScene] = [
	preload("res://scenes/obstacles/fence_low.tscn"),
	preload("res://scenes/obstacles/fence_low.tscn"),
	preload("res://scenes/obstacles/pole.tscn"),
	preload("res://scenes/obstacles/bar_high.tscn"),
	TRAIN_SCENE,
]

const TRAIN_LENGTH: float = 12.0

## --- Monedas ---
const COIN_SCENE := preload("res://scenes/collectibles/coin.tscn")
const COIN_HEIGHT: float = 1.0
const COIN_SPACING: float = 2.5
const COIN_GAP: float = 45.0
const COIN_PATTERNS: Array[String] = ["line", "line", "zigzag", "stairs"]
const AIR_COIN_HEIGHT: float = 3.5   # Debe coincidir con FLIGHT_HEIGHT en player.gd — altura de las monedas aéreas del jetpack

## --- Power-ups ---
const POWERUPS: Array[PackedScene] = [ # Lista de power-ups disponibles, mismo patrón que OBSTACLES: agregar uno es agregar una línea aquí
	preload("res://scenes/collectibles/powerupJetpack.tscn"),
	# Cuando existan las botas, se agregan aquí:
	# preload("res://scenes/collectibles/powerup_boots.tscn"),
]
const POWERUP_GAP: float = 220.0     # Metros entre cada intento de generar un power-up (poco frecuente a propósito)
const POWERUP_CHANCE: float = 0.5    # Probabilidad de que, al cumplirse el gap, sí aparezca alguno

## --- Geometría de la pista ---
const LANE_WIDTH: float = 2.0
const SPAWN_Z: float = -150.0
const SPAWN_GAP: float = 18.0
const SAFE_LANE_DURATION: int = 3  # Cuántos ciclos seguidos (de SPAWN_GAP cada uno) se mantiene el mismo carril libre antes de poder cambiar a otro. Le da al jugador un tramo real para reaccionar, en vez de que el único carril libre cambie de golpe cada 18 metros — la causa más probable del softlock del #27.
const DESPAWN_Z: float = 15.0

## --- Seguimiento lateral de la cámara ---
const CAMERA_FOLLOW_AMOUNT: float = 0.6
const CAMERA_FOLLOW_SPEED: float = 4.0

@onready var game_over: Control = $GameOver
@onready var hud: Control = $HUD
@onready var camera: Camera3D = $Camera3D
@onready var player: CharacterBody3D = $Player
@onready var pause_menu: Control = $PauseMenu

## --- Estado de la partida ---
var speed: float = START_SPEED
var speed_multiplier: float = 1.0
var distance: float = 0.0
var coins: int = 0
var running: bool = true
var next_spawn: float = 0.0
var next_coin_spawn: float = 0.0
var next_powerup_spawn: float = POWERUP_GAP
var chunks: Array[Node3D] = []
var blocked_lanes: Dictionary = {}
var safe_lane: int = 1              # Carril que se mantiene libre de forma sostenida, varios ciclos seguidos
var safe_lane_cycles_left: int = 0  # Cuántos ciclos más se mantiene igual antes de poder sortear otro

## --- Estado de tropiezo y choque ---
var is_stumbled: bool = false
var stumble_timer: Timer


func _ready() -> void:
	stumble_timer = Timer.new()
	stumble_timer.one_shot = true
	stumble_timer.wait_time = 10.0
	stumble_timer.timeout.connect(_on_stumble_timeout)
	add_child(stumble_timer)

	for i in CHUNK_COUNT:
		var chunk: Node3D = CHUNK_SCENE.instantiate() as Node3D
		add_child(chunk)
		chunk.position.z = -CHUNK_LENGTH * float(i)
		chunks.append(chunk)

	$Player.died.connect(_on_player_died)
	$Player.coin_collected.connect(_on_coin_collected)
	$Player.powerup_activated.connect(_on_powerup_activated) # Genera monedas aéreas cuando arranca el jetpack
	if $Player.has_signal("impacted"):
		$Player.impacted.connect(register_impact)

	for i in 8:
		prefill(-30.0 - float(i) * SPAWN_GAP)


func _process(delta: float) -> void:
	if not running:
		return

	if speed_multiplier < 1.0:
		speed_multiplier = move_toward(speed_multiplier, 1.0, delta * 0.5)

	speed = minf(speed + ACCELERATION * delta, MAX_SPEED)

	var current_speed: float = speed * speed_multiplier

	distance += current_speed * delta
	var step: float = current_speed * delta

	for chunk in chunks:
		chunk.position.z += step
	for chunk in chunks:
		if chunk.position.z > CHUNK_LENGTH:
			recycle(chunk)

	for child in get_children():
		if child.is_in_group("obstacle") or child.is_in_group("coin") or child.is_in_group("powerup"):
			child.position.z += step
			if child.position.z > DESPAWN_Z:
				child.queue_free()

	next_spawn -= step
	if next_spawn <= 0.0:
		spawn_obstacle()
		next_spawn = SPAWN_GAP

	next_coin_spawn -= step
	if next_coin_spawn <= 0.0:
		spawn_coins()
		next_coin_spawn = COIN_GAP

	next_powerup_spawn -= step
	if next_powerup_spawn <= 0.0:
		spawn_powerup()
		next_powerup_spawn = POWERUP_GAP

	var camera_target_x: float = player.position.x * CAMERA_FOLLOW_AMOUNT
	camera.position.x = lerp(camera.position.x, camera_target_x, CAMERA_FOLLOW_SPEED * delta)

	hud.update_hud(coins, distance)


func register_impact() -> void:
	if not running:
		return

	if is_stumbled:
		_on_player_died()
	else:
		is_stumbled = true
		speed_multiplier = 0.5
		stumble_timer.start()
		if player.has_node("WarningLight"):        # Si el jugador tiene la luz de advertencia
			player.get_node("WarningLight").flash_alert() # La hace destellar (color por defecto)

		if player.has_method("play_stumble_anim"):
			player.play_stumble_anim()


func _on_stumble_timeout() -> void:
	is_stumbled = false


func prefill(z: float) -> void:
	var free_lanes: Array[int] = [0, 1, 2]
	var keep_free: int = free_lanes.pick_random() as int
	for lane in free_lanes:
		if lane == keep_free:
			continue
		if randf() < 0.6:
			var scene: PackedScene = OBSTACLES.pick_random() as PackedScene
			var obs: Node3D = scene.instantiate() as Node3D
			add_child(obs)
			obs.position = Vector3(lane_to_x(lane), 0.0, z)


func spawn_obstacle() -> void:
	for lane in blocked_lanes.keys():
		blocked_lanes[lane] -= SPAWN_GAP
		if blocked_lanes[lane] <= 0.0:
			blocked_lanes.erase(lane)

	# El carril "seguro" se mantiene el mismo varios ciclos seguidos, en
	# vez de sortearse de nuevo cada vez — así el jugador tiene un tramo
	# real para reaccionar, en vez de que el único carril libre cambie
	# de golpe cada 18 metros.
	if safe_lane_cycles_left <= 0:
		safe_lane = randi() % 3
		safe_lane_cycles_left = SAFE_LANE_DURATION
	safe_lane_cycles_left -= 1

	var free_lanes: Array[int] = []
	for lane in 3:
		if not blocked_lanes.has(lane):
			free_lanes.append(lane)

	if free_lanes.size() <= 1:
		return

	# El carril seguro normalmente está libre. Si por casualidad quedó
	# bloqueado por un tren, se usa igual uno libre solo para este ciclo,
	# sin gastar el contador de "cuántos ciclos lleva siendo seguro".
	var keep_free: int = safe_lane if free_lanes.has(safe_lane) else free_lanes.pick_random() as int

	for lane in free_lanes:
		if lane == keep_free:
			continue
		if randf() < 0.6:
			var scene: PackedScene = OBSTACLES.pick_random() as PackedScene
			var obs: Node3D = scene.instantiate() as Node3D
			add_child(obs)
			obs.position = Vector3(lane_to_x(lane), 0.0, SPAWN_Z)
			if scene == TRAIN_SCENE:
				blocked_lanes[lane] = TRAIN_LENGTH


func spawn_coins() -> void:
	var pattern: String = COIN_PATTERNS.pick_random() as String
	var lane: int = randi() % 3

	match pattern:
		"line":
			for i in 8:
				try_place_coin(lane, SPAWN_Z - float(i) * COIN_SPACING)
		"zigzag":
			for i in 9:
				@warning_ignore("integer_division")
				var l: int = clampi(lane + (i / 3) % 3 - 1, 0, 2)
				try_place_coin(l, SPAWN_Z - float(i) * COIN_SPACING)
		"stairs":
			for i in 6:
				@warning_ignore("integer_division")
				var l: int = clampi(lane + i / 2, 0, 2)
				try_place_coin(l, SPAWN_Z - float(i) * COIN_SPACING)


func spawn_powerup() -> void:
	if randf() > POWERUP_CHANCE:
		return
	var lane: int = randi() % 3
	var scene: PackedScene = POWERUPS.pick_random() as PackedScene
	var pu: Node3D = scene.instantiate() as Node3D
	add_child(pu)
	pu.position = Vector3(lane_to_x(lane), COIN_HEIGHT, SPAWN_Z)


## Reacciona a cualquier power-up que se active en el jugador. Por ahora
## solo el jetpack necesita hacer algo especial (generar su propia fila
## de monedas aéreas), pero queda listo para que las botas u otro
## power-up futuro reaccionen aquí también si algún día lo necesitan.
func _on_powerup_activated(type: String, duration: float) -> void:
	if type == "jetpack":
		spawn_air_coin_line(duration)


## Genera una fila de monedas en el aire, en zigzag (cambia de carril
## cada 3 monedas, misma fórmula que el patrón "zigzag" normal), calculada
## para que todas queden al alcance del jugador exactamente durante lo
## que dura el vuelo — ni una se queda flotando después de que aterriza.
func spawn_air_coin_line(duration: float) -> void:
	var lane: int = randi() % 3
	var coin_count: int = 12
	var flight_distance: float = speed * duration # Metros que recorrerá el mundo mientras dura el vuelo
	var spacing: float = flight_distance / float(coin_count)
	for i in coin_count:
		@warning_ignore("integer_division")
		var l: int = clampi(lane + (i / 3) % 3 - 1, 0, 2)
		place_coin(l, AIR_COIN_HEIGHT, -5.0 - float(i) * spacing) # Empieza cerca (ya alcanzable) y se reparte hasta el final del vuelo


func try_place_coin(lane: int, z: float, height: float = COIN_HEIGHT) -> void:
	var x: float = lane_to_x(lane)
	for child in get_children():
		if not child.is_in_group("obstacle"):
			continue
		if absf(child.position.x - x) > 1.0:
			continue
		if absf(child.position.z - z) < 8.0:
			return
	place_coin(lane, height, z)


func place_coin(lane: int, height: float, z: float) -> void:
	var coin: Node3D = COIN_SCENE.instantiate() as Node3D
	add_child(coin)
	coin.position = Vector3(lane_to_x(lane), height, z)


func recycle(chunk: Node3D) -> void:
	var furthest: float = INF
	for c in chunks:
		if c == chunk:
			continue
		furthest = minf(furthest, c.position.z)
	chunk.position.z = furthest - CHUNK_LENGTH


func _on_player_died() -> void:
	running = false
	GameData.report_run_result(distance, coins)
	game_over.show_game_over(distance, coins)


func _on_coin_collected() -> void:
	coins += 1
	if player.has_node("WarningLight"):        # Reutilizamos la misma luz
		player.get_node("WarningLight").flash_alert() # Destella al recoger una moneda (color por defecto)


func lane_to_x(lane: int) -> float:
	return (float(lane) - 1.0) * LANE_WIDTH


func _unhandled_input(event: InputEvent) -> void:
	if running and event.is_action_pressed("pause"):
		pause_menu.open()
