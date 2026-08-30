## Interfaz superpuesta durante la partida (heads-up display).
## Muestra monedas y distancia en la esquina superior derecha.
## El nodo raíz tiene Mouse Filter = "Ignore" para que los clics
## atraviesen el HUD y no bloqueen nada.
extends Control

## Contador de monedas recogidas.
@onready var coin_label: Label = $VBoxContainer/CoinLabel

## Distancia recorrida en metros.
@onready var dist_label: Label = $VBoxContainer/DistLabel


## La llama main.gd en cada frame con los valores actualizados.
## No guarda estado propio: main.gd es el dueño de los datos y el HUD
## solo los dibuja. Así hay una única fuente de verdad.
func update_hud(coins: int, distance: float) -> void:
	coin_label.text = "🪙 %d" % coins
	dist_label.text = "%d m" % distance
