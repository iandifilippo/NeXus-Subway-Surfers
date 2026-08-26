extends CharacterBody3D

const LANE_COUNT := 3
const LANE_WIDTH := 2.0
const LANE_SNAP := 14.0

const JUMP_VELOCITY := 6.0
const ROLL_TIME := 0.6

@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var model: Node3D = $Model

var current_lane := 1
var is_rolling := false
var roll_timer := 0.0

var stand_height: float
var stand_y: float

func _ready() -> void:
	global_position.x = lane_to_x(current_lane)
	var shape := collision.shape as CapsuleShape3D
	stand_height = shape.height
	stand_y = collision.position.y

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_left"):
		current_lane = maxi(current_lane - 1, 0)
	elif event.is_action_pressed("move_right"):
		current_lane = mini(current_lane + 1, LANE_COUNT - 1)
	elif event.is_action_pressed("jump") and is_on_floor() and not is_rolling:
		velocity.y = JUMP_VELOCITY
	elif event.is_action_pressed("roll") and is_on_floor() and not is_rolling:
		start_roll()

func _physics_process(delta: float) -> void:
	if is_rolling:
		roll_timer -= delta
		if roll_timer <= 0.0:
			end_roll()

	var target_x := lane_to_x(current_lane)
	velocity.x = (target_x - global_position.x) * LANE_SNAP
	velocity.y += get_gravity().y * delta
	move_and_slide()

func start_roll() -> void:
	is_rolling = true
	roll_timer = ROLL_TIME
	set_capsule(stand_height * 0.5, stand_y * 0.5)
	model.rotation_degrees.x = -75.0

func end_roll() -> void:
	is_rolling = false
	set_capsule(stand_height, stand_y)
	model.rotation_degrees.x = 0.0

func set_capsule(h: float, y: float) -> void:
	var shape := collision.shape as CapsuleShape3D
	shape.height = h
	collision.position.y = y

func lane_to_x(lane: int) -> float:
	return (lane - (LANE_COUNT - 1) / 2.0) * LANE_WIDTH
