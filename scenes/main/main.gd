## Controlador principal del juego.
##
## DECISIÓN DE ARQUITECTURA: el jugador nunca avanza. Se queda fijo en Z=0
## y es este script el que mueve el mundo entero hacia él (+Z). Esto evita
## acumular coordenadas enormes (que degradan la precisión de los float en
## partidas largas), permite reusar un pool fijo de nodos, y hace que la
## cámara no necesite lógica de seguimiento EN PROFUNDIDAD (eje Z) — solo
## necesita seguir al jugador de lado a lado (eje X) cuando cambia de carril.
extends Node3D

## --- Terreno ---
const CHUNK_SCENE := preload("res://scenes/chunks/ground_chunk.tscn")
const CHUNK_LENGTH := 60.0  ## Largo en Z de un tramo. DEBE coincidir con el
							## Size Z del BoxMesh dentro de ground_chunk.tscn,
							## o aparecerán huecos o solapamientos.
const CHUNK_COUNT := 20     ## Tramos simultáneos. Cuantos más, más lejos queda
							## el punto de reciclado y menos se nota el bucle.

## --- Dificultad ---
const START_SPEED := 12.0   ## Velocidad inicial en metros por segundo.
const MAX_SPEED := 32.0     ## Techo de velocidad.
const ACCELERATION := 0.35  ## Cuánto sube la velocidad por segundo.
							## Estos tres valores SON la curva de dificultad:
							## a más velocidad, menos tiempo de reacción.

## --- Obstáculos ---
## TRAIN_SCENE se guarda aparte porque hay que compararla por identidad
## más abajo, para saber cuándo bloquear un carril.
const TRAIN_SCENE := preload("res://scenes/obstacles/train.tscn")

## La valla aparece dos veces a propósito: pick_random() elige uniformemente,
## así que duplicarla le da el doble de probabilidad que a los demás.
const OBSTACLES := [
	preload("res://scenes/obstacles/fence_low.tscn"),
	preload("res://scenes/obstacles/fence_low.tscn"),
	preload("res://scenes/obstacles/pole.tscn"),
	TRAIN_SCENE,
]

const TRAIN_LENGTH := 12.0  ## Largo del tren. Define cuántos metros queda
							## bloqueado su carril tras generarlo.

## --- Monedas ---
const COIN_SCENE := preload("res://scenes/collectibles/coin.tscn")
const COIN_HEIGHT := 1.0     ## Altura fija: todas van a ras de suelo.
const COIN_SPACING := 2.5    ## Separación entre monedas de una misma secuencia.
const COIN_GAP := 45.0       ## Metros entre una secuencia y la siguiente.
const COIN_PATTERNS := ["line", "line", "zigzag", "stairs"]
## Las monedas no se colocan al azar sino en patrones, igual que en el juego
## original: una secuencia es una instrucción visual que guía al jugador.

## --- Geometría de la pista ---
const LANE_WIDTH := 2.0   ## Separación entre carriles. Debe coincidir con la
						  ## constante del mismo nombre en player.gd.
const SPAWN_Z := -150.0   ## Dónde nacen los objetos, lejos y fuera de vista.
const SPAWN_GAP := 18.0   ## Metros entre grupos de obstáculos.
const DESPAWN_Z := 15.0   ## Pasado este punto ya quedaron detrás de la cámara
						  ## y se eliminan para no acumular nodos.

## --- Seguimiento lateral de la cámara ---
const CAMERA_FOLLOW_AMOUNT := 0.6  ## Qué tanto se mueve la cámara respecto
									## al jugador. 1.0 = la sigue exacto
									## (igual de rápido, mismo carril),
									## 0.0 = no se mueve nunca. 0.6 hace que
									## se note el movimiento sin que la
									## cámara "gire" bruscamente de golpe.
const CAMERA_FOLLOW_SPEED := 4.0   ## Qué tan rápido "alcanza" la cámara al
									## objetivo. Es la velocidad del lerp:
									## más alto = reacciona casi al instante,
									## más bajo = se queda atrás con un
									## trotecito perceptible detrás del
									## jugador (ese es el efecto que
									## buscamos, un seguimiento "leve").

@onready var game_over: Control = $GameOver
@onready var hud: Control = $HUD
@onready var camera: Camera3D = $Camera3D
@onready var player: CharacterBody3D = $Player
@onready var pause_menu: Control = $PauseMenu

## --- Estado de la partida ---
var speed := START_SPEED       ## Velocidad actual del mundo.
var distance := 0.0            ## Metros recorridos. Es la puntuación.
var coins := 0                 ## Monedas recogidas en esta partida.
var running := true            ## false al morir: congela toda la lógica.
var next_spawn := 0.0          ## Metros que faltan para el próximo obstáculo.
var next_coin_spawn := 0.0     ## Metros que faltan para la próxima secuencia.
var chunks: Array[Node3D] = [] ## Pool de tramos de suelo que se reciclan.

## Diccionario {carril: metros_restantes}. Un carril aquí está ocupado por un
## tren y no puede recibir más obstáculos hasta que el contador llegue a cero.
var blocked_lanes := {}


## Prepara la partida: crea el suelo, conecta las señales del jugador
## y rellena la pista para que no empiece vacía.
func _ready() -> void:
	# Creamos los tramos en fila: 0, -60, -120, -180...
	for i in CHUNK_COUNT:
		var chunk := CHUNK_SCENE.instantiate() as Node3D
		add_child(chunk)
		chunk.position.z = -CHUNK_LENGTH * i
		chunks.append(chunk)

	# El jugador nos avisa por señales; nosotros no lo consultamos a él.
	# Así player.gd no necesita saber que main.gd existe.
	$Player.died.connect(_on_player_died)
	$Player.coin_collected.connect(_on_coin_collected)

	# Sin esto, los primeros obstáculos nacen en Z=-150 y tardan varios
	# segundos en llegar: la partida arrancaría con un tramo vacío aburrido.
	for i in 8:
		prefill(-30.0 - i * SPAWN_GAP)


## Bucle principal. Se ejecuta cada frame.
## delta = segundos desde el frame anterior. Todo se multiplica por él
## para que el juego corra igual a 30 o a 144 fps.
func _process(delta: float) -> void:
	# Al morir dejamos de procesar: el mundo se congela.
	if not running:
		return

	# La velocidad sube hasta topar en MAX_SPEED.
	speed = minf(speed + ACCELERATION * delta, MAX_SPEED)
	distance += speed * delta

	# Metros que avanza el mundo en este frame concreto.
	var step := speed * delta

	# --- Mover y reciclar el suelo ---
	for chunk in chunks:
		chunk.position.z += step
	for chunk in chunks:
		if chunk.position.z > CHUNK_LENGTH:
			recycle(chunk)

	# --- Mover obstáculos y monedas, y borrar los que ya pasaron ---
	# Se identifican por grupo, no por tipo de nodo: así se pueden añadir
	# obstáculos nuevos sin tocar esta línea.
	for child in get_children():
		if child.is_in_group("obstacle") or child.is_in_group("coin"):
			child.position.z += step
			if child.position.z > DESPAWN_Z:
				child.queue_free()

	# --- Generación por distancia, no por tiempo ---
	# Restamos metros recorridos en vez de segundos. Así la separación entre
	# obstáculos es constante aunque la velocidad suba: la dificultad viene
	# de tener menos tiempo para reaccionar, no de tener más obstáculos.
	next_spawn -= step
	if next_spawn <= 0.0:
		spawn_obstacle()
		next_spawn = SPAWN_GAP

	next_coin_spawn -= step
	if next_coin_spawn <= 0.0:
		spawn_coins()
		next_coin_spawn = COIN_GAP

	# --- Seguimiento lateral de la cámara ---
	# La cámara NO es hija del jugador (evitamos así el problema de que
	# choque contra su propia cápsula de colisión, que fue justo lo que
	# rompió el intento anterior con SpringArm3D). En su lugar, cada frame
	# la acercamos un poco más hacia una posición X calculada a partir de
	# dónde está el jugador, con lerp(): eso da un seguimiento suave, con
	# un pequeño retraso natural, en vez de un salto brusco o un enganche
	# rígido 1 a 1.
	var camera_target_x := player.position.x * CAMERA_FOLLOW_AMOUNT
	camera.position.x = lerp(camera.position.x, camera_target_x, CAMERA_FOLLOW_SPEED * delta)

	hud.update_hud(coins, distance)


## Coloca obstáculos en una posición Z concreta al iniciar la partida.
## Es una versión simplificada de spawn_obstacle() que ignora el sistema
## de bloqueo de carriles, porque al arrancar no hay trenes previos.
func prefill(z: float) -> void:
	var free_lanes := [0, 1, 2]
	var keep_free: int = free_lanes.pick_random()
	for lane in free_lanes:
		if lane == keep_free:
			continue
		if randf() < 0.6:
			var scene := OBSTACLES.pick_random() as PackedScene
			var obs := scene.instantiate() as Node3D
			add_child(obs)
			obs.position = Vector3(lane_to_x(lane), 0.0, z)


## Genera un grupo de obstáculos garantizando que la situación sea superable.
##
## Dos reglas de diseño evitan tramos imposibles:
##  1. Siempre queda al menos un carril libre (keep_free).
##  2. Los carriles ocupados por un tren quedan reservados durante 12 m,
##     porque el tren es largo y sigue ahí en los siguientes ciclos.
func spawn_obstacle() -> void:
	# Descontamos los metros avanzados desde el último ciclo y liberamos
	# los carriles cuyo tren ya quedó atrás.
	for lane in blocked_lanes.keys():
		blocked_lanes[lane] -= SPAWN_GAP
		if blocked_lanes[lane] <= 0.0:
			blocked_lanes.erase(lane)

	# Qué carriles siguen disponibles.
	var free_lanes := []
	for lane in 3:
		if not blocked_lanes.has(lane):
			free_lanes.append(lane)

	# Si solo queda uno (o ninguno), no generamos nada este ciclo.
	# Un hueco vacío es preferible a un muro infranqueable.
	if free_lanes.size() <= 1:
		return

	# Uno de los disponibles se reserva como vía de escape.
	var keep_free: int = free_lanes.pick_random()

	for lane in free_lanes:
		if lane == keep_free:
			continue
		# No todos los carriles restantes reciben obstáculo: el 40% de las
		# veces quedan libres, lo que da variedad al ritmo del juego.
		if randf() < 0.6:
			var scene := OBSTACLES.pick_random() as PackedScene
			var obs := scene.instantiate() as Node3D
			add_child(obs)
			obs.position = Vector3(lane_to_x(lane), 0.0, SPAWN_Z)
			# Si salió un tren, reservamos su carril para los próximos ciclos.
			if scene == TRAIN_SCENE:
				blocked_lanes[lane] = TRAIN_LENGTH


## Genera una secuencia de monedas siguiendo uno de los patrones definidos.
## El carril de inicio es aleatorio, pero la forma de la secuencia no:
## cada patrón comunica algo al jugador sobre qué hacer.
func spawn_coins() -> void:
	var pattern: String = COIN_PATTERNS.pick_random()
	var lane := randi() % 3

	match pattern:
		# Fila recta: premia quedarse en el carril.
		"line":
			for i in 8:
				try_place_coin(lane, SPAWN_Z - i * COIN_SPACING)
		# Zigzag: obliga a cambiar de carril cada tres monedas.
		"zigzag":
			for i in 9:
				# La división entera es intencional: agrupa las monedas
				# de a 3 en 3 para el patrón en zigzag. Por eso se silencia
				# el aviso de "integer division" en vez de cambiarla.
				@warning_ignore("integer_division")
				var l: int = clampi(lane + (i / 3) % 3 - 1, 0, 2)
				try_place_coin(l, SPAWN_Z - i * COIN_SPACING)
		# Escalera: desplazamiento progresivo hacia un lado.
		"stairs":
			for i in 6:
				# Misma razón: división entera intencional, agrupa de a 2
				# para que el desplazamiento avance cada dos monedas.
				@warning_ignore("integer_division")
				var l: int = clampi(lane + i / 2, 0, 2)
				try_place_coin(l, SPAWN_Z - i * COIN_SPACING)


## Coloca una moneda solo si no hay un obstáculo cerca en el mismo carril.
##
## Obstáculos y monedas se generan de forma independiente, así que sin esta
## comprobación aparecerían monedas dentro de los trenes: visibles pero
## imposibles de recoger sin morir. Cuando una secuencia cruza un obstáculo,
## simplemente se parte en dos, que es lo que hace el juego original.
func try_place_coin(lane: int, z: float) -> void:
	var x := lane_to_x(lane)
	for child in get_children():
		if not child.is_in_group("obstacle"):
			continue
		# Distinto carril: no estorba.
		if absf(child.position.x - x) > 1.0:
			continue
		# Mismo carril y a menos de 8 m: el tren mide 12 m de largo
		# (±6 desde su centro), así que 8 deja algo de margen.
		if absf(child.position.z - z) < 8.0:
			return
	place_coin(lane, COIN_HEIGHT, z)


## Instancia una moneda en el carril, altura y profundidad indicados.
func place_coin(lane: int, height: float, z: float) -> void:
	var coin := COIN_SCENE.instantiate() as Node3D
	add_child(coin)
	coin.position = Vector3(lane_to_x(lane), height, z)


## Reengancha un tramo de suelo al final de la fila.
##
## Busca cuál es el tramo más lejano (Z más negativo) y coloca este
## justo un CHUNK_LENGTH por detrás. Así los mismos nodos rotan
## indefinidamente sin crear ninguno nuevo.
##
## CUIDADO: hay que excluir el propio chunk del cálculo (el `continue`),
## porque en este momento está en Z positivo, delante de todos los demás.
## Incluirlo daba solapamientos y huecos visibles en la pista.
func recycle(chunk: Node3D) -> void:
	var furthest := INF
	for c in chunks:
		if c == chunk:
			continue
		furthest = minf(furthest, c.position.z)
	chunk.position.z = furthest - CHUNK_LENGTH


## Responde a la señal `died` del jugador.
## Detiene el mundo y muestra la pantalla de resultados.
func _on_player_died() -> void:
	running = false
	game_over.show_game_over(distance, coins)


## Responde a la señal `coin_collected` del jugador.
## El jugador detecta el contacto, pero es main.gd quien lleva la cuenta:
## una sola fuente de verdad para la puntuación.
func _on_coin_collected() -> void:
	coins += 1


## Convierte un índice de carril (0, 1, 2) en su coordenada X.
## Carril 0 → -2, carril 1 → 0, carril 2 → +2.
func lane_to_x(lane: int) -> float:
	return (lane - 1.0) * LANE_WIDTH
	## Escucha la tecla de pausa (P) durante la partida. Solo abre el menú
## si se sigue jugando (running) — si ya murió, no tiene sentido: ya
## está la pantalla de GameOver, que también pausa el árbol.
func _unhandled_input(event: InputEvent) -> void:
	if running and event.is_action_pressed("pause"):
		pause_menu.open()
