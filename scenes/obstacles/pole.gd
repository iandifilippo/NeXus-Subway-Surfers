extends Area3D

@onready var lightBulb = $MeshInstance3D2
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass
	
func cambiar_material(mesh_instance: MeshInstance3D, propiedad: String, valor) -> bool:
	if lightBulb == null:
		return false
	var material := mesh_instance.get_surface_override_material(0)
	if material == null:
		return false
	material.set("Color", 0000)
	return true


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
