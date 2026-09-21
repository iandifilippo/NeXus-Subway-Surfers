## Luz de advertencia. En reposo permanece apagada (energy 0) y se
## enciende con un parpadeo breve en respuesta a eventos del juego,
## usando Tween para la transición, misma técnica de "luz_reactiva.gd"
## (Sesión 17).
extends OmniLight3D

@export var color_alerta: Color = Color(1.0, 0.85, 0.2)  # Dorado: color por defecto (monedas, tropiezo)
@export var energia_alerta: float = 3.0
@export var duracion_flash: float = 0.6

func _ready() -> void:
	light_energy = 0.0
	light_color = color_alerta

## color y energy son opcionales — si no se pasan, usan los valores por
## defecto (color_alerta, energia_alerta), así las llamadas existentes
## (monedas, tropiezo) no cambian. El jetpack pide su propio color y una
## energía más alta, porque el azul se percibe más débil que el dorado
## a la misma intensidad.
func flash_alert(color: Color = color_alerta, energy: float = energia_alerta) -> void:
	light_color = color
	var tween := create_tween()
	tween.tween_property(self, "light_energy", energy, duracion_flash * 0.3)
	tween.tween_property(self, "light_energy", 0.0, duracion_flash * 0.7)
