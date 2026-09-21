## Moneda coleccionable.
## Es un Area3D (no un cuerpo físico) porque no debe bloquear al jugador:
## solo necesita DETECTAR que lo tocó. El Hitbox del jugador la encuentra
## gracias a la capa de colisión 4 y al grupo "coin".
extends Area3D

## Velocidad de giro en radianes por segundo.
## El giro es puramente visual: hace que la moneda llame la atención
## sobre el suelo estático y se lea como "recogible".
const SPIN_SPEED := 3.0

## Evita que la misma moneda se cuente dos veces si por algún motivo
## el jugador la toca en dos frames seguidos antes de que se libere.
var collected := false


## Se ejecuta cada frame. Solo rota la moneda sobre su eje vertical.
## delta = segundos transcurridos desde el frame anterior; multiplicar por
## delta hace que el giro sea igual de rápido en cualquier PC.
func _process(delta: float) -> void:
	rotate_y(SPIN_SPEED * delta)


## La llama player.gd cuando el jugador entra en contacto.
## queue_free() borra el nodo al final del frame actual (no de inmediato),
## que es la forma segura de eliminar algo durante una colisión.
func collect() -> void:
	collected = true
	queue_free()
