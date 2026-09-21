## Autoload (Singleton) — datos del jugador que sobreviven entre escenas
## mientras el juego está abierto: el total de monedas (la "billetera",
## gastable en la tienda), el mejor récord de distancia alcanzado, y si
## ya se reclamó el regalo gratis de la tienda.
##
## IMPORTANTE: esto NO se guarda en disco. Se reinicia a cero (y el
## regalo gratis vuelve a estar disponible) cada vez que se cierra el
## juego por completo — es memoria compartida entre escenas durante
## una misma sesión, no un sistema de guardado permanente.
extends Node

## Monedas acumuladas, disponibles para gastar en la tienda.
var total_coins: int = 0

## Mejor distancia recorrida en una partida, en esta sesión de juego.
var best_distance: float = 0.0

## true si ya se reclamó el regalo gratis de la tienda en esta sesión.
## Al no guardarse en disco, vuelve a false automáticamente la próxima
## vez que se abra el juego.
var daily_gift_claimed: bool = false


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
## aviso de "no tienes suficientes monedas", por ejemplo).
func try_spend_coins(amount: int) -> bool:
	if total_coins < amount:
		return false
	total_coins -= amount
	return true


## Reclama el regalo gratis de la tienda, si no se había reclamado ya
## en esta sesión. Devuelve las monedas ganadas (0 si ya se había
## reclamado, para que quien llama sepa que no pasó nada).
func claim_daily_gift() -> int:
	if daily_gift_claimed:
		return 0
	daily_gift_claimed = true
	var reward := 20
	total_coins += reward
	return reward
