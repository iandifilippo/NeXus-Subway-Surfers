## Control del personaje jugable.
## El jugador NUNCA avanza en Z: se queda fijo en el origen y es el mundo
## el que se mueve hacia él (ver main.gd). Este script solo maneja
## el carril (X), el salto (Y) y la postura (agachado o de pie).
extends CharacterBody3D # Inherita de CharacterBody3D para manejar la física del personaje

## --- Movimiento lateral ---
const LANE_COUNT := 3      # Número de carriles totales: izquierda (0), centro (1), derecha (2)
const LANE_WIDTH := 2.0    # Separación en metros entre carriles
const LANE_SNAP := 14.0    # Velocidad de ajuste de posición horizontal hacia el carril destino

## --- Salto y deslizamiento ---
const JUMP_VELOCITY := 8.0    # Fuerza del impulso vertical al saltar
const ROLL_TIME := 1.0        # Tiempo total del deslizamiento en segundos
const SLAM_VELOCITY := -40.0  # Impulso descendente rápido para caer de golpe si se rueda en el aire

## --- Vuelo (jetpack) ---
const FLIGHT_HEIGHT := 3.5  # Altura en Y a la que vuela el jugador, por encima de trenes/vallas
const FLIGHT_SNAP := 6.0    # Velocidad de ajuste hacia la altura de vuelo (como LANE_SNAP, pero en Y)

## --- Golpe frontal vs. lateral/diagonal contra obstáculos sólidos ---
## Si el golpe queda a menos de este valor del centro del obstáculo (en
## X), se considera de frente (mortal). Más lejos —típicamente porque te
## alcanzó a medio cambiar de carril, rozándolo de costado— es un
## tropiezo, no muerte. Cada tipo tiene su propio umbral porque son de
## anchos muy distintos (afinables jugando, no son valores exactos).
const TRAIN_FRONTAL_THRESHOLD := 0.5   # El tren mide 1.8 de ancho
const FENCE_FRONTAL_THRESHOLD := 0.4   # La valla mide 1.6 de ancho
const POLE_FRONTAL_THRESHOLD := 0.1    # El poste mide solo 0.3 de ancho

## --- Aterrizar/viajar encima de un obstáculo ---
## Alturas reales de cada uno (tope superior) y su profundidad en Z —
## esta última decide cuánto dura "viajando" encima antes de que el
## obstáculo termine de pasar y el jugador caiga de vuelta al suelo.
const FENCE_TOP_HEIGHT := 0.8
const FENCE_LENGTH := 0.4      # Profundidad real de la valla — el viaje dura muy poco, es angosta
const POLE_TOP_HEIGHT := 3.0
const POLE_LENGTH := 0.3       # Profundidad real del poste — el viaje dura muy poco, es angosto
const TRAIN_TOP_HEIGHT := 3.0
const TRAIN_LENGTH := 12.0     # Debe coincidir con TRAIN_LENGTH en main.gd
const CLEAR_HEIGHT_MARGIN := 0.15  # Margen de tolerancia para considerar que ya está "arriba"

## --- Nombres de las animaciones ---
const ANIM_RUN := "mixamo_com"        # Nombre de la animación base al correr
const ANIM_JUMP := "jump/mixamo_com"  # Nombre de la animación al saltar
const ANIM_ROLL := "roll/mixamo_com"  # Nombre de la animación al rodar/deslizarse

## --- Referencias a nodos hijos ---
@onready var collision: CollisionShape3D = $CollisionShape3D # Referencia al nodo de colisión física
@onready var model: Node3D = $Model                         # Referencia al nodo contenedor del modelo 3D
@onready var anim: AnimationPlayer = $Model/run/AnimationPlayer # Referencia al reproductor de animaciones

## --- Señales que este nodo emite hacia main.gd ---
signal died            # Señal enviada al morir el personaje
signal coin_collected  # Señal enviada al recoger una moneda

## --- Señales del sistema de power-ups (para que el HUD las use más adelante) ---
signal powerup_activated(type: String, duration: float)
signal powerup_ended(type: String)

## --- Estado interno ---
var current_lane := 1     # Carril actual (0 = izquierda, 1 = centro, 2 = derecha)
var is_rolling := false   # Define si el personaje está actualmente rodando
var roll_timer := 0.0     # Temporizador para controlar la duración del rodamiento
var is_dead := false      # Bloquea las colisiones y controles tras morir
var is_jumping := false   # Indica si el personaje está en medio de un salto

## --- Estado del power-up activo ---
var active_powerup: String = ""        # "" = ninguno activo
var powerup_timer: float = 0.0         # Segundos restantes del efecto activo
var jump_force_multiplier: float = 1.0 # Lo usarán las botas de salto potenciado (ver TODO en activate_powerup)

## --- Estado de "viaje" encima de un obstáculo (tren, valla o poste) ---
var is_riding: bool = false              # true mientras está parado/corriendo encima de algo
var current_ride_area: Area3D = null     # A qué obstáculo está "pegado" ahora mismo
var current_ride_top_height: float = 0.0 # A qué altura fija se mantiene mientras dura el viaje
var current_ride_length: float = 0.0     # Profundidad en Z de ese obstáculo, para saber cuándo se acaba

## Medidas de la cápsula de pie. Se guardan al arrancar para poder
## restaurarlas después de encogerla durante el roll.
var stand_height: float   # Almacena la altura original de la cápsula de colisión
var stand_y: float        # Almacena la posición Y original de la cápsula de colisión


# Se ejecuta una sola vez cuando el nodo entra al árbol de la escena
func _ready() -> void:
	global_position.x = lane_to_x(current_lane)        # Ubica al jugador en la posición X del carril inicial
	var shape := collision.shape as CapsuleShape3D     # Obtiene la forma de la cápsula de colisión
	stand_height = shape.height                        # Guarda la altura inicial de la cápsula
	stand_y = collision.position.y                     # Guarda la posición vertical inicial de la cápsula
	play_anim(ANIM_RUN)                               # Inicia la animación de correr por defecto


# Cuenta regresiva del power-up activo, si hay alguno
func _process(delta: float) -> void:
	if active_powerup != "":                            # Si hay un power-up activo ahora mismo
		powerup_timer -= delta                          # Descuenta el tiempo transcurrido
		if powerup_timer <= 0.0:                        # Si se agotó el tiempo
			_end_powerup()                              # Desactiva el efecto


# Escucha la entrada de controles no procesada previamente por la interfaz (UI)
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_left"):            # Si presiona la tecla para mover a la izquierda
		current_lane = maxi(current_lane - 1, 0)        # Cambia al carril izquierdo sin bajar de 0
	elif event.is_action_pressed("move_right"):         # Si presiona la tecla para mover a la derecha
		current_lane = mini(current_lane + 1, LANE_COUNT - 1) # Cambia al carril derecho sin superar el máximo
	elif active_powerup == "jetpack":                   # Volando no se salta ni se rueda, solo se cambia de carril
		return
	elif event.is_action_pressed("jump") and not is_jumping: # Si presiona saltar y no está saltando
		if is_rolling:                                  # Si presiona saltar mientras está rodando
			cancel_roll()                               # Cancela el rodamiento inmediatamente
			is_jumping = true                           # Activa el estado de salto
			velocity.y = JUMP_VELOCITY * jump_force_multiplier # Aplica la fuerza del salto (potenciado si hay botas)
			start_jump()                                # Inicia la animación de salto
		elif is_on_floor() or is_riding:                # Si está firme en el suelo real, o parado sobre algo
			is_jumping = true                           # Activa el estado de salto
			is_riding = false                           # Se baja de lo que estaba montando al saltar
			current_ride_area = null
			velocity.y = JUMP_VELOCITY * jump_force_multiplier # Aplica la fuerza del salto (potenciado si hay botas)
			start_jump()                                # Inicia la animación de salto
	elif event.is_action_pressed("roll") and not is_rolling: # Si presiona rodar y no está rodando
		start_roll()                                    # Inicia la rutina de rodar
		if not is_on_floor() and not is_riding:         # Si presiona rodar estando en el aire de verdad
			velocity.y = SLAM_VELOCITY                  # Aplica fuerza vertical hacia abajo para caer de golpe


# Se ejecuta en el ciclo de actualización de física (60 veces por segundo)
func _physics_process(delta: float) -> void:
	var was_airborne := not is_on_floor()               # Registra si el jugador no estaba tocando el suelo en este frame

	if is_riding:                                       # Si está montado sobre algo
		_check_ride()                                   # Revisa si ya se acabó (el obstáculo ya pasó por completo)

	if is_rolling:                                      # Si está actualmente en estado de rodar
		roll_timer -= delta                             # Descuenta el tiempo transcurrido al temporizador
		if roll_timer <= 0.0:                           # Si el tiempo llegó a cero
			end_roll()                                  # Termina el rodamiento y regresa la cápsula a su tamaño

	var target_x := lane_to_x(current_lane)            # Obtiene la posición objetivo en X para el carril actual
	velocity.x = (target_x - global_position.x) * LANE_SNAP # Calcula la velocidad horizontal requerida

	if active_powerup == "jetpack":                     # Volando: ignora la gravedad, se ajusta hacia la altura de vuelo
		velocity.y = (FLIGHT_HEIGHT - global_position.y) * FLIGHT_SNAP
	elif is_riding:                                     # Montado en algo: fijo a su altura, sin gravedad
		velocity.y = 0.0
		global_position.y = current_ride_top_height
	else:
		velocity.y += get_gravity().y * delta           # Aplica la fuerza de la gravedad a la velocidad Y

	move_and_slide()                                    # Mueve el personaje ejecutando la física del motor

	if was_airborne and is_on_floor():                  # Si el personaje acaba de aterrizar en el suelo
		is_jumping = false                              # Desactiva la bandera de salto
		if not is_rolling:                              # Si no aterrizó rodando
			anim.play(ANIM_RUN, 0.1, 1.0)               # Vuelve a reproducir la animación de correr


## Sube al jugador encima de un obstáculo: fija su altura al tope del
## obstáculo e ignora la gravedad mientras dure el viaje, en vez de caer
## atravesándolo. Sirve para tren, valla o poste por igual — solo
## cambian los números que le pasa cada uno.
func _start_riding(area: Area3D, top_height: float, length: float) -> void:
	is_riding = true
	current_ride_area = area
	current_ride_top_height = top_height
	current_ride_length = length
	is_jumping = false        # Se considera "de pie", no en medio de un salto
	velocity.y = 0.0
	global_position.y = top_height
	play_anim(ANIM_RUN)


## Revisa cada frame si lo que se está montando ya pasó por completo
## debajo del jugador. Recordar: el jugador siempre está fijo en Z=0, es
## el mundo (y el obstáculo) el que se mueve en +Z hacia él.
func _check_ride() -> void:
	if current_ride_area == null or not is_instance_valid(current_ride_area):
		is_riding = false                                # Ya no existe (se recicló/borró): se acabó el viaje
		current_ride_area = null
		return
	var half_length: float = current_ride_length * 0.5
	if current_ride_area.global_position.z - half_length > 0.0:
		# El borde trasero ya pasó Z=0: ya no hay nada debajo, se suelta
		# la sujeción y la gravedad retoma el control.
		is_riding = false
		current_ride_area = null


# Maneja el arranque de la animación de salto y su pausa momentánea en el aire
func start_jump() -> void:
	if not anim.has_animation(ANIM_JUMP):               # Verifica si existe la animación de salto
		return                                          # Si no existe, cancela la ejecución de la función
	anim.play(ANIM_JUMP, 0.1, 1.5)                      # Reproduce la animación de salto acelerada
	await get_tree().create_timer(0.35).timeout          # Pausa la ejecución de esta función por 0.35 segundos
	if not is_on_floor() and not is_riding:             # Si transcurrido ese tiempo sigue en el aire de verdad
		anim.pause()                                    # Congela la animación de salto temporalmente


# Inicia el estado de rodamiento, achica la colisión e inicia la animación
func start_roll() -> void:
	is_rolling = true                                   # Marca la bandera de rodamiento como activa
	roll_timer = ROLL_TIME                              # Carga el tiempo total del rodamiento
	set_capsule(stand_height * 0.5, stand_y * 0.5)      # Encoge la cápsula de colisión a la mitad
	play_anim(ANIM_ROLL, 1.2)                          # Inicia la animación de rodar


# Termina el rodamiento de forma natural al agotarse el tiempo
func end_roll() -> void:
	is_rolling = false                                  # Desactiva la bandera de rodamiento
	set_capsule(stand_height, stand_y)                  # Restablece el tamaño y posición original de la cápsula
	play_anim(ANIM_RUN)                                 # Vuelve a la animación de correr


# Interrumpe el rodamiento por una acción obligatoria como un salto
func cancel_roll() -> void:
	is_rolling = false                                  # Desactiva la bandera de rodamiento
	roll_timer = 0.0                                    # Resetea el contador de tiempo
	set_capsule(stand_height, stand_y)                  # Restablece la cápsula a su tamaño normal


# Ajusta la altura y la posición Y de la cápsula de colisión
func set_capsule(h: float, y: float) -> void:
	var shape := collision.shape as CapsuleShape3D     # Obtiene la referencia a la forma de la cápsula
	shape.height = h                                    # Modifica la altura de la cápsula
	collision.position.y = y                            # Modifica la posición vertical Y de la cápsula


# Reproduce una animación aplicando una transición suave entre estados
func play_anim(anim_name: String, speed: float = 1.0) -> void:
	if not anim.has_animation(anim_name):               # Revisa si la animación solicitada existe
		return                                          # Sale si no existe la animación
	if anim.current_animation == anim_name and anim.is_playing(): # Si la animación ya se está reproduciendo
		return                                          # Evita cortarla o reiniciarla
	anim.play(anim_name, 0.15, speed)                   # Ejecuta la animación con una mezcla suave de 0.15s


# Calcula la coordenada X en metros basándose en el carril indicado (0, 1, 2)
func lane_to_x(lane: int) -> float:
	return (lane - (LANE_COUNT - 1) / 2.0) * LANE_WIDTH # Convierte el índice a coordenada X (-2.0, 0.0, 2.0)


# Se ejecuta automáticamente cuando la Hitbox del jugador colisiona con un Area3D
func _on_hitbox_area_entered(area: Area3D) -> void:
	if is_dead:                                         # Si el jugador ya está muerto
		return                                          # Ignora el procesamiento de la colisión

	# Volando (jetpack), el jugador ignora todo lo del suelo — obstáculos,
	# postes, paredes, Y también otros power-ups. El jetpack es exclusivo:
	# mientras dura, nada más se recoge ni se activa. Las botas no tienen
	# esta restricción: como el jugador sigue en el suelo, un power-up
	# nuevo sí puede reemplazarlas con normalidad.
	if active_powerup == "jetpack" and (area.is_in_group("obstacle") or area.is_in_group("pole") or area.is_in_group("wall") or area.is_in_group("powerup")):
		return

	# Los tres tipos de obstáculo sólido (tren, valla, poste) comparten
	# ahora la misma lógica: aterrizar encima = viajar sobre él; frente =
	# muerte; lateral/diagonal = tropiezo + empujón al carril libre.
	if area.is_in_group("train"):
		_handle_solid_obstacle(area, TRAIN_FRONTAL_THRESHOLD, TRAIN_TOP_HEIGHT, TRAIN_LENGTH)

	elif area.is_in_group("fence"):
		_handle_solid_obstacle(area, FENCE_FRONTAL_THRESHOLD, FENCE_TOP_HEIGHT, FENCE_LENGTH)

	elif area.is_in_group("pole"):
		_handle_solid_obstacle(area, POLE_FRONTAL_THRESHOLD, POLE_TOP_HEIGHT, POLE_LENGTH)

	elif area.is_in_group("obstacle"):                  # Cualquier obstáculo sin tipo específico sigue matando directo
		die()

	elif area.is_in_group("wall"):                      # Paredes laterales de los 3 carriles
		if get_parent().has_method("register_impact"):  # Llama a main.gd para bajar la velocidad
			get_parent().register_impact()              # Tropieza, pero se queda en el mismo carril

	elif area.is_in_group("coin"):                      # Si la colisión es con una moneda
		area.collect()                                  # Ejecuta la lógica propia de la moneda
		coin_collected.emit()                           # Emite la señal de moneda recolectada hacia main.gd

	elif area.is_in_group("powerup"):                   # Si la colisión es con un power-up (jetpack, botas...)
		var p_type: String = area.powerup_type          # Lee qué tipo de power-up es
		var p_duration: float = area.duration           # Lee cuánto debe durar su efecto
		area.collect()                                  # Elimina el coleccionable del mundo
		activate_powerup(p_type, p_duration)             # Activa el efecto correspondiente


## Decide qué hacer con un obstáculo sólido: si el jugador ya está a la
## altura de su tope (o más arriba), se sube y viaja sobre él; si no,
## decide entre golpe de frente (muerte) o lateral/diagonal (tropiezo +
## empujón), según qué tan centrado quedó respecto al obstáculo en X.
func _handle_solid_obstacle(area: Area3D, threshold: float, top_height: float, length: float) -> void:
	if global_position.y >= top_height - CLEAR_HEIGHT_MARGIN:
		_start_riding(area, top_height, length)
		return

	var offset_x: float = absf(area.global_position.x - global_position.x)
	if offset_x < threshold:
		die()
	else:
		if get_parent().has_method("register_impact"):
			get_parent().register_impact()
		_push_to_free_lane(area)


## Empuja al jugador hacia el carril libre más cercano al que ocupa el
## obstáculo. Sin esto, como estos obstáculos son Area3D (no bloquean
## físicamente el movimiento), el jugador quedaba metido dentro de su
## malla en vez de rebotar hacia un lado.
func _push_to_free_lane(area: Area3D) -> void:
	if current_lane == 0:
		current_lane = 1
	elif current_lane == 2:
		current_lane = 1
	elif current_lane == 1:
		if area.global_position.x > global_position.x:
			current_lane = 0
		else:
			current_lane = 2


## Activa un power-up genérico durante un tiempo determinado. Si ya había
## uno activo, este lo reemplaza (no se acumulan duraciones ni efectos).
func activate_powerup(type: String, duration: float) -> void:
	active_powerup = type
	powerup_timer = duration

	match type:
		"jetpack":
			play_anim(ANIM_RUN)  # Sigue corriendo en el aire: se ve más dinámico que una pose
								  # de salto congelada, y evita que la luz de advertencia quede
								  # visualmente "atrapada" dentro de esa pose recogida.
			if has_node("WarningLight"):
				get_node("WarningLight").flash_alert(Color(0.2, 0.6, 1.0), 5.5) # Destello azul, más intenso que el de monedas (3.0) para compensar que el azul se ve más débil a simple vista
		# TODO (botas): cuando se implementen, agregar aquí:
		# "boots":
		#     jump_force_multiplier = 1.5

	powerup_activated.emit(type, duration)


## Termina el efecto del power-up activo y restaura los valores normales.
func _end_powerup() -> void:
	match active_powerup:
		"jetpack":
			anim.play(ANIM_RUN, 0.2, 1.0)  # Confirma que quede corriendo normal al aterrizar
		# TODO (botas):
		# "boots":
		#     jump_force_multiplier = 1.0

	powerup_ended.emit(active_powerup)
	active_powerup = ""
	powerup_timer = 0.0


# Procesa la muerte del jugador, bloquea controles y notifica a main.gd
func die() -> void:
	is_dead = true                                      # Define el estado del personaje a muerto
	set_physics_process(false)                          # Desactiva la actualización de físicas
	set_process_unhandled_input(false)                  # Desactiva la lectura de botones e insumos del usuario
	anim.pause()                                        # Pausa la animación actual
	died.emit()                                         # Emite la señal de muerte hacia main.gd
