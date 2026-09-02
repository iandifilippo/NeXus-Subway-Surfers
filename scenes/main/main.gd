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
const CHUNK_SCENE := preload("res://scenes/chunks/ground_chunk.tscn") # Carga en memoria la escena del tramo de suelo
const CHUNK_LENGTH: float = 60.0  # Largo en Z de un tramo de suelo (60 metros)
const CHUNK_COUNT: int = 20     # Cantidad total de tramos simultáneos en escena

## --- Dificultad ---
const START_SPEED: float = 12.0   # Velocidad inicial del mundo en metros por segundo
const MAX_SPEED: float = 32.0     # Velocidad máxima a la que puede llegar el mundo
const ACCELERATION: float = 0.35  # Tasa de incremento de la velocidad por segundo

## --- Obstáculos ---
const TRAIN_SCENE := preload("res://scenes/obstacles/train.tscn") # Carga la escena del tren por separado para validar bloqueos
const OBSTACLES: Array[PackedScene] = [ # Lista de escenas de obstáculos disponibles para instanciar
	preload("res://scenes/obstacles/fence_low.tscn"), # Valla baja 1 (mayor probabilidad)
	preload("res://scenes/obstacles/fence_low.tscn"), # Valla baja 2
	preload("res://scenes/obstacles/pole.tscn"),      # Poste
	TRAIN_SCENE,                                       # Tren
]

const TRAIN_LENGTH: float = 12.0  # Longitud del tren en metros para calcular el bloqueo de carril

## --- Monedas ---
const COIN_SCENE := preload("res://scenes/collectibles/coin.tscn") # Carga la escena base de la moneda
const COIN_HEIGHT: float = 1.0     # Altura en Y a la que flotan las monedas
const COIN_SPACING: float = 2.5    # Distancia en metros entre cada moneda de una serie
const COIN_GAP: float = 45.0       # Distancia en metros entre patrones de monedas
const COIN_PATTERNS: Array[String] = ["line", "line", "zigzag", "stairs"] # Patrones de aparición de monedas

## --- Geometría de la pista ---
const LANE_WIDTH: float = 2.0   # Distancia horizontal (eje X) entre el centro de los carriles
const SPAWN_Z: float = -150.0   # Coordenada Z donde nacen los obstáculos y monedas
const SPAWN_GAP: float = 18.0   # Distancia en Z entre grupos consecutivos de obstáculos
const DESPAWN_Z: float = 15.0   # Coordenada Z donde se eliminan los nodos tras superar la cámara

## --- Seguimiento lateral de la cámara ---
const CAMERA_FOLLOW_AMOUNT: float = 0.6  # Porcentaje de movimiento lateral que la cámara imita del jugador
const CAMERA_FOLLOW_SPEED: float = 4.0   # Velocidad de interpolación (lerp) del movimiento de la cámara

# Referencias a nodos hijos en la escena
@onready var game_over: Control = $GameOver       # Referencia a la interfaz de fin de juego
@onready var hud: Control = $HUD                 # Referencia a la interfaz con contadores de juego
@onready var camera: Camera3D = $Camera3D         # Referencia a la cámara principal 3D
@onready var player: CharacterBody3D = $Player   # Referencia al personaje del jugador
@onready var pause_menu: Control = $PauseMenu     # Referencia al menú de pausa

## --- Estado de la partida ---
var speed: float = START_SPEED       # Variable para rastrear la velocidad de progresión global del mundo
var speed_multiplier: float = 1.0    # Multiplicador (1.0 = normal, 0.5 = tropiezo) para penalizar al chocar
var distance: float = 0.0            # Distancia recorrida total en metros (puntuación)
var coins: int = 0                   # Cantidad total de monedas recolectadas
var running: bool = true             # Interruptor de estado del juego (true = activo, false = detenido)
var next_spawn: float = 0.0          # Contador en metros para la aparición del próximo obstáculo
var next_coin_spawn: float = 0.0     # Contador en metros para el próximo grupo de monedas
var chunks: Array[Node3D] = []       # Arreglo que almacena los nodos de suelo activos
var blocked_lanes: Dictionary = {}   # Diccionario para rastrear la duración de carriles ocupados por trenes

## --- Estado de tropiezo y choque ---
var is_stumbled: bool = false  # Bandera que indica si el jugador tropezó recientemente
var stumble_timer: Timer       # Temporizador dinámico para contar los 10 segundos de vulnerabilidad


# Función inicializadora llamada al cargar la escena
func _ready() -> void:
	# Instanciación y configuración del temporizador de tropiezo
	stumble_timer = Timer.new()                               # Crea un nuevo nodo de tipo Timer
	stumble_timer.one_shot = true                             # Define que el temporizador solo se ejecute una vez por llamado
	stumble_timer.wait_time = 10.0                            # Ajusta la duración del temporizador a 10 segundos
	stumble_timer.timeout.connect(_on_stumble_timeout)        # Conecta el fin del tiempo con la función de restauración
	add_child(stumble_timer)                                  # Agrega el temporizador al árbol de nodos de la escena

	# Bucle para instanciar e ingresar los tramos iniciales del suelo
	for i in CHUNK_COUNT:                                     # Itera según la cantidad total de tramos definidos
		var chunk: Node3D = CHUNK_SCENE.instantiate() as Node3D # Instancia la escena del tramo de suelo
		add_child(chunk)                                      # Agrega el tramo instanciado a la escena principal
		chunk.position.z = -CHUNK_LENGTH * float(i)           # Asigna la posición Z alineada en fila hacia el fondo
		chunks.append(chunk)                                  # Guarda la referencia del tramo en el arreglo de suelo

	# Conexión de señales emitidas por el jugador hacia las funciones del controlador
	$Player.died.connect(_on_player_died)                     # Conecta la señal de muerte del jugador
	$Player.coin_collected.connect(_on_coin_collected)        # Conecta la señal de recolección de monedas
	if $Player.has_signal("impacted"):                        # Verifica si el Player posee la señal de impacto
		$Player.impacted.connect(register_impact)             # Conecta la señal de impacto para procesar tropiezos

	# Relleno inicial de obstáculos frente al jugador
	for i in 8:                                               # Genera 8 tandas de obstáculos por adelantado
		prefill(-30.0 - float(i) * SPAWN_GAP)                 # Coloca los obstáculos en posiciones Z negativas crecientes


# Bucle principal de actualización ejecutado en cada fotograma
func _process(delta: float) -> void:
	if not running:                                           # Si el juego no está en ejecución (por muerte o pausa)
		return                                                # Interrumpe la ejecución del código restante del frame

	# 1. Recuperación gradual de la velocidad tras un tropiezo
	if speed_multiplier < 1.0:                                # Si el multiplicador es menor a 1 (hubo penalización)
		speed_multiplier = move_toward(speed_multiplier, 1.0, delta * 0.5) # Lo recupera suavemente hacia 1.0

	# 2. Incremento de dificultad global del juego
	speed = minf(speed + ACCELERATION * delta, MAX_SPEED)     # Incrementa la velocidad según la aceleración sin superar MAX_SPEED
	
	# 3. Cálculo de la velocidad real aplicable en este frame con tipos estrictos explícitos
	var current_speed: float = speed * speed_multiplier       # Combina la progresión global con la posible penalización
	
	distance += current_speed * delta                         # Suma la distancia recorrida usando la velocidad real
	var step: float = current_speed * delta                   # Calcula con tipo estricto los metros exactos a desplazar en este frame

	# Desplazamiento y reciclaje del terreno
	for chunk in chunks:                                      # Recorre cada tramo del terreno
		chunk.position.z += step                              # Mueve el tramo hacia adelante (+Z) según la velocidad actual
	for chunk in chunks:                                      # Recorre nuevamente los tramos
		if chunk.position.z > CHUNK_LENGTH:                   # Comprueba si el tramo sobrepasó la distancia límite
			recycle(chunk)                                    # Recicla el tramo enviándolo al final de la fila

	# Desplazamiento y eliminación de objetos en el mundo
	for child in get_children():                              # Recorre todos los nodos hijos de la escena principal
		if child.is_in_group("obstacle") or child.is_in_group("coin"): # Filtra solo obstáculos y monedas
			child.position.z += step                          # Desplaza el objeto hacia adelante (+Z)
			if child.position.z > DESPAWN_Z:                  # Comprueba si el objeto sobrepasó el límite posterior
				child.queue_free()                            # Elimina el objeto de la memoria

	# Control de la frecuencia de aparición de obstáculos
	next_spawn -= step                                        # Resta la distancia recorrida al contador de obstáculos
	if next_spawn <= 0.0:                                     # Si el contador llega a cero o menos
		spawn_obstacle()                                      # Genera un nuevo obstáculo
		next_spawn = SPAWN_GAP                                # Reinicia el contador con el intervalo de separación

	# Control de la frecuencia de aparición de monedas
	next_coin_spawn -= step                                   # Resta la distancia recorrida al contador de monedas
	if next_coin_spawn <= 0.0:                                # Si el contador de monedas llega a cero o menos
		spawn_coins()                                         # Genera un nuevo conjunto de monedas
		next_coin_spawn = COIN_GAP                            # Reinicia el contador de monedas con su intervalo correspondiente

	# Interpolación de seguimiento de la cámara en el eje X
	var camera_target_x: float = player.position.x * CAMERA_FOLLOW_AMOUNT # Calcula el objetivo en X ajustado por la constante
	camera.position.x = lerp(camera.position.x, camera_target_x, CAMERA_FOLLOW_SPEED * delta) # Interpola suavemente la cámara

	hud.update_hud(coins, distance)                           # Actualiza la interfaz de usuario con monedas y metros


# Función encargada de procesar los choques secundarios o tropiezos del jugador
func register_impact() -> void:
	if not running:                                           # Si el juego está detenido, ignora el impacto
		return                                                # Sale de la función

	if is_stumbled:                                           # Si el jugador ya estaba en estado de tropiezo (dentro de los 10 segundos)
		_on_player_died()                                     # Ejecuta la lógica de muerte del jugador (Game Over)
	else:                                                     # Si es el primer impacto recibido
		is_stumbled = true                                    # Activa la bandera de estado tropezado
		speed_multiplier = 0.5                                # Reduce la velocidad actual a la mitad instantáneamente
		stumble_timer.start()                                 # Inicia la cuenta regresiva de 10 segundos del temporizador

		if player.has_method("play_stumble_anim"):            # Comprueba si el script del jugador tiene una animación de tropiezo
			player.play_stumble_anim()                        # Ejecuta la animación de tropiezo en el jugador


# Callback invocado automáticamente al finalizar los 10 segundos del temporizador
func _on_stumble_timeout() -> void:
	is_stumbled = false                                       # Restablece la bandera para salir del estado de vulnerabilidad


# Rellena el mapa con obstáculos iniciales al arrancar la escena
func prefill(z: float) -> void:
	var free_lanes: Array[int] = [0, 1, 2]                    # Define los tres carriles posibles (0, 1, 2)
	var keep_free: int = free_lanes.pick_random() as int      # Selecciona un carril al azar que permanecerá libre
	for lane in free_lanes:                                   # Recorre los tres carriles
		if lane == keep_free:                                 # Si es el carril designado como libre
			continue                                          # Salta la iteración para no colocar nada
		if randf() < 0.6:                                     # Con una probabilidad del 60%
			var scene: PackedScene = OBSTACLES.pick_random() as PackedScene # Escoge un obstáculo aleatorio de la lista
			var obs: Node3D = scene.instantiate() as Node3D   # Instancia el nodo del obstáculo
			add_child(obs)                                    # Lo añade a la escena principal
			obs.position = Vector3(lane_to_x(lane), 0.0, z)   # Posiciona el obstáculo en el carril y coordenada Z indicada


# Genera obstáculos dinámicamente durante el avance del juego
func spawn_obstacle() -> void:
	for lane in blocked_lanes.keys():                         # Recorre los carriles actualmente bloqueados por trenes
		blocked_lanes[lane] -= SPAWN_GAP                      # Descuenta el avance del terreno a la duración del bloqueo
		if blocked_lanes[lane] <= 0.0:                        # Si el tren ya sobrepasó la distancia necesaria
			blocked_lanes.erase(lane)                         # Desbloquea el carril

	var free_lanes: Array[int] = []                           # Crea un arreglo para listar los carriles disponibles
	for lane in 3:                                            # Recorre los índices de carril 0, 1 y 2
		if not blocked_lanes.has(lane):                       # Si el carril no está en la lista de bloqueados
			free_lanes.append(lane)                           # Lo agrega a los carriles disponibles

	if free_lanes.size() <= 1:                                # Si solo queda 1 o ningún carril libre
		return                                                # Cancela la generación para no crear un muro imposible

	var keep_free: int = free_lanes.pick_random() as int      # Elige un carril disponible al azar para dejar libre como vía de escape

	for lane in free_lanes:                                   # Recorre todos los carriles disponibles
		if lane == keep_free:                                 # Si es el carril reservado como libre
			continue                                          # Salta a la siguiente iteración
		if randf() < 0.6:                                     # Con un 60% de probabilidad
			var scene: PackedScene = OBSTACLES.pick_random() as PackedScene # Elige una escena de obstáculo al azar
			var obs: Node3D = scene.instantiate() as Node3D   # Instancia la escena
			add_child(obs)                                    # Agrega el obstáculo al árbol de la escena
			obs.position = Vector3(lane_to_x(lane), 0.0, SPAWN_Z) # Posiciona el obstáculo en X y en la profundidad SPAWN_Z
			if scene == TRAIN_SCENE:                          # Si el obstáculo instanciado es un tren
				blocked_lanes[lane] = TRAIN_LENGTH            # Registra el carril como bloqueado durante la longitud del tren


# Genera patrones de monedas en el mapa
func spawn_coins() -> void:
	var pattern: String = COIN_PATTERNS.pick_random() as String # Elige un patrón de monedas al azar
	var lane: int = randi() % 3                               # Elige un carril inicial al azar (0, 1 o 2)

	match pattern:                                            # Selecciona la estructura a construir según el patrón elegido
		"line":                                               # Patrón en línea recta
			for i in 8:                                       # Genera 8 monedas consecutivas
				try_place_coin(lane, SPAWN_Z - float(i) * COIN_SPACING) # Intenta colocar la moneda en el carril fijo y con espacio Z
		"zigzag":                                             # Patrón en zigzag
			for i in 9:                                       # Genera 9 monedas alternando carril
				@warning_ignore("integer_division")           # Desactiva la advertencia de división entera de Godot
				var l: int = clampi(lane + (i / 3) % 3 - 1, 0, 2) # Calcula el carril oscilante manteniéndolo entre 0 y 2
				try_place_coin(l, SPAWN_Z - float(i) * COIN_SPACING) # Intenta colocar la moneda en la posición calculada
		"stairs":                                             # Patrón en escalera
			for i in 6:                                       # Genera 6 monedas desplazándose
				@warning_ignore("integer_division")           # Desactiva la advertencia de división entera
				var l: int = clampi(lane + i / 2, 0, 2)       # Calcula el carril progresivo en bloques de 2 monedas
				try_place_coin(l, SPAWN_Z - float(i) * COIN_SPACING) # Intenta colocar la moneda


# Valida si se puede colocar una moneda sin que choque contra un obstáculo existente
func try_place_coin(lane: int, z: float) -> void:
	var x: float = lane_to_x(lane)                            # Convierte el índice de carril a su coordenada horizontal X
	for child in get_children():                              # Examina cada nodo presente en la escena
		if not child.is_in_group("obstacle"):                 # Si el nodo no pertenece al grupo de obstáculos
			continue                                          # Lo ignora y pasa al siguiente
		if absf(child.position.x - x) > 1.0:                  # Si el obstáculo está en otro carril distante en X
			continue                                          # No interfiere, pasa al siguiente
		if absf(child.position.z - z) < 8.0:                  # Si el obstáculo está en el mismo carril a menos de 8 metros
			return                                            # Cancela la colocación de la moneda en esta coordenada
	place_coin(lane, COIN_HEIGHT, z)                          # Si la zona está libre, instancia la moneda


# Instancia e inserta la moneda en la escena
func place_coin(lane: int, height: float, z: float) -> void:
	var coin: Node3D = COIN_SCENE.instantiate() as Node3D     # Instancia el nodo de la moneda
	add_child(coin)                                           # Agrega la moneda a la escena principal
	coin.position = Vector3(lane_to_x(lane), height, z)       # Establece las coordenadas en X, Y (altura) y Z


# Recoloca un tramo de suelo que quedó atrás para enviarlo al fondo
func recycle(chunk: Node3D) -> void:
	var furthest: float = INF                                 # Inicializa la distancia más lejana en infinito positivo
	for c in chunks:                                          # Recorre todos los tramos de suelo guardados
		if c == chunk:                                        # Si es el propio tramo que se está reciclando
			continue                                          # Ignora su posición actual para no falsear el cálculo
		furthest = minf(furthest, c.position.z)               # Encuentra el valor de Z más negativo (el tramo más lejano)
	chunk.position.z = furthest - CHUNK_LENGTH                # Coloca este tramo justo detrás del tramo más lejano


# Gestiona la muerte del jugador y la interrupción de la partida
func _on_player_died() -> void:
	running = false                                           # Detiene el bucle principal cambiando la bandera a false
	game_over.show_game_over(distance, coins)                 # Muestra la interfaz de Game Over enviando el puntaje final


# Suma las monedas recolectadas cuando el jugador emite la señal
func _on_coin_collected() -> void:
	coins += 1                                                # Incrementa el contador global de monedas en 1


# Convierte un carril (0, 1, 2) a su posición real en metros en el eje X
func lane_to_x(lane: int) -> float:
	return (float(lane) - 1.0) * LANE_WIDTH                   # Mapea 0 a -2.0, 1 a 0.0, y 2 a 2.0


# Captura las entradas globales del teclado para el menú de pausa
func _unhandled_input(event: InputEvent) -> void:
	if running and event.is_action_pressed("pause"):          # Si el juego está en marcha y se presiona la tecla asignada a "pause"
		pause_menu.open()                                     # Despliega el menú de pausa
