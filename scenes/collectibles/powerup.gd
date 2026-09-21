## Power-up coleccionable genérico. El tipo y la duración se configuran
## desde el Inspector (Export), así que este mismo script sirve para el
## jetpack, las botas, o cualquier power-up futuro — solo cambia la
## instancia y sus valores exportados, no el código.
extends Area3D

@export var powerup_type: String = "jetpack"  # Debe coincidir con el nombre que espera activate_powerup() en player.gd
@export var duration: float = 8.0              # Segundos que dura el efecto una vez recogido

const SPIN_SPEED: float = 2.0
var collected: bool = false

func _process(delta: float) -> void:
	rotate_y(SPIN_SPEED * delta)

func collect() -> void:
	collected = true
	queue_free()
