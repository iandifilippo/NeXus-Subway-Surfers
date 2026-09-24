## Autoload (Singleton) — datos del jugador que sobreviven entre escenas
## mientras el juego está abierto: el total de monedas (la "billetera",
## gastable en la tienda), el mejor récord de distancia alcanzado, y si
## ya se reclamó el regalo gratis y cada caja de la tienda.
##
## IMPORTANTE: esto NO se guarda en disco. Se reinicia a cero (y todo
## vuelve a estar disponible) cada vez que se cierra el juego por
## completo — es memoria compartida entre escenas durante una misma
## sesión, no un sistema de guardado permanente.
extends Node

## Monedas acumuladas, disponibles para gastar en la tienda.
var total_coins: int = 0

## Mejor distancia recorrida en una partida, en esta sesión de juego.
var best_distance: float = 0.0

## true si ya se reclamó el regalo gratis de la tienda en esta sesión.
## Al no guardarse en disco, vuelve a false automáticamente la próxima
## vez que se abra el juego.
var daily_gift_claimed: bool = false

## true si ya se compró cada caja en esta sesión, por su id ("small",
## "large"). Igual que el regalo gratis: una vez por sesión, vuelve a
## estar disponible al reabrir el juego, no hay temporizador.
var crate_purchased: Dictionary = {}

## Id del personaje elegido en la pantalla "Yo" (ver main_menu.gd). Por
## defecto "jake", el único desbloqueado por ahora.
var selected_character: String = "jake"

## --- Estadísticas para las misiones ---
## Monedas recolectadas en total, sumando TODAS las partidas de esta
## sesión — a diferencia de total_coins, esta nunca baja al gastar en
## la tienda, porque una misión de "recoge X monedas" no debería
## deshacerse por haber comprado algo.
var lifetime_coins: int = 0

## Suma de la distancia de TODAS las partidas jugadas en esta sesión
## (a diferencia de best_distance, que solo guarda la mejor).
var total_distance_traveled: float = 0.0

## Cuántas partidas se han jugado (terminado, por muerte) en esta
## sesión.
var runs_played: int = 0


## La llama main.gd cuando el jugador muere, con el resultado de la
## partida que acaba de terminar. Suma las monedas ganadas a la
## billetera y a las estadísticas de misiones, actualiza el récord si
## corresponde, y cuenta la partida jugada.
func report_run_result(distance: float, coins_earned: int) -> void:
	total_coins += coins_earned
	lifetime_coins += coins_earned
	total_distance_traveled += distance
	runs_played += 1
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


## true si esta caja ya se compró en esta sesión.
func is_crate_purchased(crate_id: String) -> bool:
	return crate_purchased.get(crate_id, false)


## Registra que se acaba de comprar esta caja — no se podrá volver a
## comprar hasta que se reabra el juego.
func mark_crate_purchased(crate_id: String) -> void:
	crate_purchased[crate_id] = true


## Devuelve el valor actual de una estadística por su nombre, para que
## main_menu.gd pueda calcular el progreso de cualquier misión sin
## tener que conocer cada variable por separado — solo el nombre.
func get_stat(stat_name: String) -> float:
	match stat_name:
		"lifetime_coins":
			return float(lifetime_coins)
		"best_distance":
			return best_distance
		"total_distance_traveled":
			return total_distance_traveled
		"runs_played":
			return float(runs_played)
	return 0.0
