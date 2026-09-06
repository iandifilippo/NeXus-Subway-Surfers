## Autoload (Singleton) — datos del jugador que sobreviven entre escenas
## mientras el juego está abierto: el total de monedas (la "billetera",
## gastable en la tienda) y el mejor récord de distancia alcanzado.
##
## IMPORTANTE: esto NO se guarda en disco. Se reinicia a cero cada vez
## que se cierra el juego por completo — es memoria compartida entre
## escenas durante una misma sesión, no un sistema de guardado
## permanente.
extends Node

## Monedas acumuladas, disponibles para gastar en la tienda.
var total_coins: int = 0

## Mejor distancia recorrida en una partida, en esta sesión de juego.
var best_distance: float = 0.0


## La llama main.gd cuando el jugador muere, con el resultado de la
## partida que acaba de terminar. Suma las monedas ganadas a la
## billetera y actualiza el récord si corresponde.
func report_run_result(distance: float, coins_earned: int) -> void:
	total_coins += coins_earned
	if distance > best_distance:
		best_distance = distance


## Intenta gastar monedas (por ejemplo, al comprar algo en la tienda).
## Devuelve true si había suficientes y se descontaron, o false si no
## alcanzaba — así quien llama puede decidir qué hacer (mostrar un
## aviso de "no tienes monedas suficientes", por ejemplo).
func try_spend_coins(amount: int) -> bool:
	if total_coins < amount:
		return false
	total_coins -= amount
	return true
