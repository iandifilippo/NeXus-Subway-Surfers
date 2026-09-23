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
## --- Botas de salto ---
const BOOTS_JUMP_MULTIPLIER := 1.5  # Multiplica la velocidad del salto; 1.5 ≈ 2.25x de altura

## --- Golpe frontal vs. lateral/diagonal contra obstáculos sólidos ---
## Si el golpe queda a menos de este valor del centro del obstáculo (en
## X), se considera de frente (mortal). Más lejos —típicamente porque te
## alcanzó a medio cambiar de carril, rozándolo de costado— es un
## tropiezo, no muerte. Cada tipo tiene su propio umbral porque son de
## anchos muy distintos (afinables jugando, no son valores exactos).
const TRAIN_FRONTAL_THRESHOLD := 0.5   # El tren mide 1.8 de ancho
const FENCE_FRONTAL_THRESHOLD := 0.4   # La valla mide 1.6 de ancho
const POLE_FRONTAL_THRESHOLD := 0.1    # El poste mide solo 0.3 de ancho
const BAR_FRONTAL_THRESHOLD := 0.4     # La barra alta mide 1.6 de ancho, igual que la valla

## --- Aterrizar/viajar encima de un obstáculo ---
## Alturas reales de cada uno (tope superior) y su profundidad en Z —
## esta última decide cuánto dura "viajando" encima antes de que el
## obstáculo termine de pasar y el jugador caiga de vuelta al suelo. La
## barra alta no aparece aquí: flota en el aire, no hay "encima" donde
## pararse, así que no participa de este sistema — solo del de frente/
## lateral, y de la regla de pasar agachado por debajo.
const FENCE_TOP_HEIGHT := 0.8
const FENCE_LENGTH := 0.4
const POLE_TOP_HEIGHT := 3.0
const POLE_LENGTH := 0.3
const TRAIN_TOP_HEIGHT := 3.0
const TRAIN_LENGTH := 12.0
const CLEAR_HEIGHT_MARGIN := 0.15

## --- Nombres de las animaciones ---
const ANIM_RUN := "mixamo_com"
const ANIM_JUMP := "jump/mixamo_com"
const ANIM_ROLL := "roll/mixamo_com"

## --- Referencias a nodos hijos ---
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var model: Node3D = $Model
@onready var anim: AnimationPlayer = $Model/run/AnimationPlayer

## --- Señales que este nodo emite hacia main.gd ---
signal died
signal coin_collected

## --- Señales del sistema de power-ups (para que el HUD las use más adelante) ---
signal powerup_activated(type: String, duration: float)
signal powerup_ended(type: String)

## --- Estado interno ---
var current_lane := 1
var is_rolling := false
var roll_timer := 0.0
var is_dead := false
var is_jumping := false

## --- Estado del power-up activo ---
var active_powerup: String = ""
var powerup_timer: float = 0.0
var jump_force_multiplier: float = 1.0

## --- Estado de "viaje" encima de un obstáculo (tren, valla o poste) ---
var is_riding: bool = false
var current_ride_area: Area3D = null
var current_ride_top_height: float = 0.0
var current_ride_length: float = 0.0

## Medidas de la cápsula de pie.
var stand_height: float
var stand_y: float


func _ready() -> void:
	global_position.x = lane_to_x(current_lane)
	var shape := collision.shape as CapsuleShape3D
	stand_height = shape.height
	stand_y = collision.position.y
	play_anim(ANIM_RUN)


func _process(delta: float) -> void:
	if active_powerup != "":
		powerup_timer -= delta
		if powerup_timer <= 0.0:
			_end_powerup()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_left"):
		current_lane = maxi(current_lane - 1, 0)
	elif event.is_action_pressed("move_right"):
		current_lane = mini(current_lane + 1, LANE_COUNT - 1)
	elif active_powerup == "jetpack":
		return
	elif event.is_action_pressed("jump") and not is_jumping:
		if is_rolling:
			cancel_roll()
			is_jumping = true
			velocity.y = JUMP_VELOCITY * jump_force_multiplier
			start_jump()
		elif is_on_floor() or is_riding:
			is_jumping = true
			is_riding = false
			current_ride_area = null
			velocity.y = JUMP_VELOCITY * jump_force_multiplier
			start_jump()
	elif event.is_action_pressed("roll") and not is_rolling:
		start_roll()
		if not is_on_floor() and not is_riding:
			velocity.y = SLAM_VELOCITY


func _physics_process(delta: float) -> void:
	var was_airborne := not is_on_floor()

	if is_riding:
		_check_ride()

	if is_rolling:
		roll_timer -= delta
		if roll_timer <= 0.0:
			end_roll()

	var target_x := lane_to_x(current_lane)
	velocity.x = (target_x - global_position.x) * LANE_SNAP

	if active_powerup == "jetpack":
		velocity.y = (FLIGHT_HEIGHT - global_position.y) * FLIGHT_SNAP
	elif is_riding:
		velocity.y = 0.0
		global_position.y = current_ride_top_height
	else:
		velocity.y += get_gravity().y * delta

	move_and_slide()

	if was_airborne and is_on_floor():
		is_jumping = false
		if not is_rolling:
			anim.play(ANIM_RUN, 0.1, 1.0)


func _start_riding(area: Area3D, top_height: float, length: float) -> void:
	is_riding = true
	current_ride_area = area
	current_ride_top_height = top_height
	current_ride_length = length
	is_jumping = false
	velocity.y = 0.0
	global_position.y = top_height
	play_anim(ANIM_RUN)


func _check_ride() -> void:
	if current_ride_area == null or not is_instance_valid(current_ride_area):
		is_riding = false
		current_ride_area = null
		return
	var half_length: float = current_ride_length * 0.5
	if current_ride_area.global_position.z - half_length > 0.0:
		is_riding = false
		current_ride_area = null


func start_jump() -> void:
	if not anim.has_animation(ANIM_JUMP):
		return
	anim.play(ANIM_JUMP, 0.1, 1.5)
	await get_tree().create_timer(0.35).timeout
	if not is_on_floor() and not is_riding:
		anim.pause()


func start_roll() -> void:
	is_rolling = true
	roll_timer = ROLL_TIME
	set_capsule(stand_height * 0.5, stand_y * 0.5)
	play_anim(ANIM_ROLL, 1.2)


func end_roll() -> void:
	is_rolling = false
	set_capsule(stand_height, stand_y)
	play_anim(ANIM_RUN)


func cancel_roll() -> void:
	is_rolling = false
	roll_timer = 0.0
	set_capsule(stand_height, stand_y)


func set_capsule(h: float, y: float) -> void:
	var shape := collision.shape as CapsuleShape3D
	shape.height = h
	collision.position.y = y


func play_anim(anim_name: String, speed: float = 1.0) -> void:
	if not anim.has_animation(anim_name):
		return
	if anim.current_animation == anim_name and anim.is_playing():
		return
	anim.play(anim_name, 0.15, speed)


func lane_to_x(lane: int) -> float:
	return (lane - (LANE_COUNT - 1) / 2.0) * LANE_WIDTH


func _on_hitbox_area_entered(area: Area3D) -> void:
	if is_dead:
		return

	if active_powerup == "jetpack" and (area.is_in_group("obstacle") or area.is_in_group("pole") or area.is_in_group("wall") or area.is_in_group("powerup")):
		return

	if area.is_in_group("train"):
		_handle_solid_obstacle(area, TRAIN_FRONTAL_THRESHOLD, TRAIN_TOP_HEIGHT, TRAIN_LENGTH)

	elif area.is_in_group("fence"):
		_handle_solid_obstacle(area, FENCE_FRONTAL_THRESHOLD, FENCE_TOP_HEIGHT, FENCE_LENGTH)

	elif area.is_in_group("pole"):
		_handle_solid_obstacle(area, POLE_FRONTAL_THRESHOLD, POLE_TOP_HEIGHT, POLE_LENGTH)

	elif area.is_in_group("bar"):
		# La barra alta solo se pasa agachado/rodando por debajo — no
		# tiene "encima" donde pararse (flota en el aire), así que no
		# usa _handle_solid_obstacle (esa maneja el "viajar encima", que
		# aquí no aplica). Sí comparte el mismo criterio de frente vs.
		# lateral/diagonal que tren/valla/poste.
		if is_rolling:
			pass  # La estás pasando agachada, no pasa nada
		else:
			var offset_x: float = absf(area.global_position.x - global_position.x)
			if offset_x < BAR_FRONTAL_THRESHOLD:
				die()
			else:
				if get_parent().has_method("register_impact"):
					get_parent().register_impact()
				_push_to_free_lane(area)

	elif area.is_in_group("obstacle"):
		die()

	elif area.is_in_group("wall"):
		if get_parent().has_method("register_impact"):
			get_parent().register_impact()

	elif area.is_in_group("coin"):
		area.collect()
		coin_collected.emit()

	elif area.is_in_group("powerup"):
		var p_type: String = area.powerup_type
		var p_duration: float = area.duration
		area.collect()
		activate_powerup(p_type, p_duration)


## Decide qué hacer con un obstáculo sólido con "encima" (tren, valla o
## poste): si el jugador ya está a la altura de su tope, se sube y
## viaja sobre él; si no, decide entre golpe de frente (muerte) o
## lateral/diagonal (tropiezo + empujón), según qué tan centrado quedó
## respecto al obstáculo en X.
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


func activate_powerup(type: String, duration: float) -> void:
	active_powerup = type
	powerup_timer = duration

	match type:
		"jetpack":
			play_anim(ANIM_RUN)
			if has_node("WarningLight"):
				get_node("WarningLight").flash_alert(Color(0.2, 0.6, 1.0), 5.5)
		"boots":
			jump_force_multiplier = BOOTS_JUMP_MULTIPLIER

	powerup_activated.emit(type, duration)


func _end_powerup() -> void:
	match active_powerup:
		"jetpack":
			anim.play(ANIM_RUN, 0.2, 1.0)
		# TODO (botas):
		# "boots":
		#     jump_force_multiplier = 1.0

	powerup_ended.emit(active_powerup)
	active_powerup = ""
	powerup_timer = 0.0


func die() -> void:
	is_dead = true
	set_physics_process(false)
	set_process_unhandled_input(false)
	anim.pause()
	died.emit()
