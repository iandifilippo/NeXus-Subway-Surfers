## Luz de advertencia. En reposo permanece apagada (energy 0) y se
## enciende en rojo con un parpadeo breve cuando el jugador tropieza,
## usando Tween para la transición, misma técnica de "luz_reactiva.gd"
## (Sesión 17), aplicada aquí como reacción a un evento del juego en vez
## de un parpadeo constante por temporizador.
extends OmniLight3D

@export var color_alerta: Color = Color(1.0, 0.85, 0.2)  # Dorado, en vez de rojo
@export var energia_alerta: float = 3.0
@export var duracion_flash: float = 0.6

func _ready() -> void:
	light_energy = 0.0
	light_color = color_alerta

## La llama main.gd cuando el jugador tropieza contra un poste o pared.
func flash_alert() -> void:
	var tween := create_tween()
	tween.tween_property(self, "light_energy", energia_alerta, duracion_flash * 0.3)
	tween.tween_property(self, "light_energy", 0.0, duracion_flash * 0.7)
