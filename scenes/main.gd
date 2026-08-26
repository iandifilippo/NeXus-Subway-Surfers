extends Node3D

const CHUNK_SCENE := preload("res://scenes/chunks/ground_chunk.tscn")
const CHUNK_LENGTH := 60.0
const CHUNK_COUNT := 3

const START_SPEED := 12.0
const MAX_SPEED := 32.0
const ACCELERATION := 0.35

var speed := START_SPEED
var distance := 0.0
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

	for chunk in chunks:
		chunk.position.z += speed * delta
		if chunk.position.z > CHUNK_LENGTH:
			recycle(chunk)

func recycle(chunk: Node3D) -> void:
	var furthest := 0.0
	for c in chunks:
		furthest = minf(furthest, c.position.z)
	chunk.position.z = furthest - CHUNK_LENGTH
