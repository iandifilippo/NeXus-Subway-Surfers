extends Node3D

const CHUNK_SCENE := preload("res://scenes/chunks/ground_chunk.tscn")
const CHUNK_LENGTH := 60.0
const CHUNK_COUNT := 3

const START_SPEED := 12.0
const MAX_SPEED := 32.0
const ACCELERATION := 0.35

const OBSTACLES := [
	preload("res://scenes/obstacles/fence_low.tscn"),
	preload("res://scenes/obstacles/bar_high.tscn"),
	preload("res://scenes/obstacles/pole.tscn"),
	preload("res://scenes/obstacles/train.tscn"),
]

const LANE_WIDTH := 2.0
const SPAWN_Z := -120.0
const SPAWN_GAP := 18.0
const DESPAWN_Z := 15.0

var speed := START_SPEED
var distance := 0.0
var next_spawn := 0.0
var chunks: Array[Node3D] = []


func _ready() -> void:
	for i in CHUNK_COUNT:
		var chunk := CHUNK_SCENE.instantiate() as Node3D
		add_child(chunk)
		chunk.position.z = -CHUNK_LENGTH * i
		chunks.append(chunk)


func _process(delta: float) -> void:
	speed = minf(speed + ACCELERATION * delta, MAX_SPEED)
	distance += speed * delta

	var step := speed * delta

	for chunk in chunks:
		chunk.position.z += step
		if chunk.position.z > CHUNK_LENGTH:
			recycle(chunk)

	for child in get_children():
		if child.is_in_group("obstacle"):
			child.position.z += step
			if child.position.z > DESPAWN_Z:
				child.queue_free()

	next_spawn -= step
	if next_spawn <= 0.0:
		spawn_obstacle()
		next_spawn = SPAWN_GAP


func spawn_obstacle() -> void:
	var free_lane := randi() % 3
	for lane in 3:
		if lane == free_lane:
			continue
		if randf() < 0.65:
			var scene := OBSTACLES.pick_random() as PackedScene
			var obs := scene.instantiate() as Node3D
			add_child(obs)
			obs.position = Vector3(lane_to_x(lane), 0.0, SPAWN_Z)


func recycle(chunk: Node3D) -> void:
	var furthest := 0.0
	for c in chunks:
		furthest = minf(furthest, c.position.z)
	chunk.position.z = furthest - CHUNK_LENGTH


func lane_to_x(lane: int) -> float:
	return (lane - 1.0) * LANE_WIDTH
