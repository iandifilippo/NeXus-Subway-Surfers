## Control del personaje jugable.
## El jugador NUNCA avanza en Z: se queda fijo en el origen y es el mundo
## el que se mueve hacia él (ver main.gd). Este script solo maneja
## el carril (X), el salto (Y) y la postura (agachado o de pie).
extends CharacterBody3D
<<<<<<< HEAD
## Comentario para solucionar error del merge en GitHub
=======

>>>>>>> fda6fd6 (Agregué colisiones, monedas, HUD y el game over)
## --- Movimiento lateral ---
const LANE_COUNT := 3      ## Número de carriles: izquierda, centro, derecha.
const LANE_WIDTH := 2.0    ## Separación en metros entre carriles.
const LANE_SNAP := 14.0    ## Qué tan rápido se acomoda al carril destino.
						   ## Más alto = más brusco. Más bajo = más resbaladizo.

## --- Salto y deslizamiento ---
const JUMP_VELOCITY := 8.0    ## Impulso vertical inicial al saltar.
const ROLL_TIME := 1.0        ## Duración del roll en segundos.
const SLAM_VELOCITY := -40.0  ## Fuerza hacia abajo al rodar en el aire.
							  ## Permite cancelar un salto y caer de golpe.

## --- Nombres de las animaciones ---
## Vienen de Mixamo. "mixamo_com" es el nombre que trae el FBX principal;
## "jump/" y "roll/" son librerías cargadas aparte en el AnimationPlayer.
const ANIM_RUN := "mixamo_com"
const ANIM_JUMP := "jump/mixamo_com"
const ANIM_ROLL := "roll/mixamo_com"

## --- Referencias a nodos hijos ---
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var model: Node3D = $Model
@onready var anim: AnimationPlayer = $Model/run/AnimationPlayer

## --- Señales que este nodo emite hacia main.gd ---
signal died            ## Se emite al chocar con un obstáculo. Termina la partida.
signal coin_collected  ## Se emite al recoger una moneda. main.gd suma +1.

## --- Estado interno ---
<<<<<<< HEAD
var current_lane := 1
var is_rolling := false
var roll_timer := 0.0
var is_dead := false
var is_jumping := false   ## true desde que se pulsa saltar hasta aterrizar.
						  ## No usamos solo is_on_floor() porque tarda un frame
						  ## en actualizarse y permitiría saltos dobles.
=======
var current_lane := 1     ## 0 = izquierda, 1 = centro, 2 = derecha.
var is_rolling := false   ## true mientras dura el roll.
var roll_timer := 0.0     ## Cuenta atrás del roll en segundos.
var is_dead := false      ## Evita procesar más colisiones tras morir.
>>>>>>> fda6fd6 (Agregué colisiones, monedas, HUD y el game over)

## Medidas de la cápsula de pie. Se guardan al arrancar para poder
## restaurarlas después de encogerla durante el roll.
var stand_height: float
var stand_y: float


## Se ejecuta una vez al entrar en la escena.
func _ready() -> void:
	# Colocamos al jugador en su carril inicial.
	global_position.x = lane_to_x(current_lane)
	# Guardamos las medidas originales de la cápsula para el roll.
	var shape := collision.shape as CapsuleShape3D
	stand_height = shape.height
	stand_y = collision.position.y
	play_anim(ANIM_RUN)


## Recibe las pulsaciones de teclas.
## Usa _unhandled_input (no _input) para que la UI tenga prioridad:
## si un botón del menú consume la tecla, aquí no llega.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_left"):
		# maxi() evita salirse por la izquierda del carril 0.
		current_lane = maxi(current_lane - 1, 0)
	elif event.is_action_pressed("move_right"):
		# mini() evita pasarse del último carril.
		current_lane = mini(current_lane + 1, LANE_COUNT - 1)
<<<<<<< HEAD
	elif event.is_action_pressed("jump") and not is_jumping:
		if is_rolling:
			cancel_roll()
			is_jumping = true
			velocity.y = JUMP_VELOCITY
			start_jump()
		elif is_on_floor():
			is_jumping = true
=======
	elif event.is_action_pressed("jump"):
		if is_rolling:
			# Saltar cancela el roll a medias (como en Subway Surfers).
			cancel_roll()
			velocity.y = JUMP_VELOCITY
			start_jump()
		elif is_on_floor():
			# Solo se puede saltar desde el suelo (no hay doble salto).
>>>>>>> fda6fd6 (Agregué colisiones, monedas, HUD y el game over)
			velocity.y = JUMP_VELOCITY
			start_jump()
	elif event.is_action_pressed("roll") and not is_rolling:
		start_roll()
		if not is_on_floor():
			# Rodar en el aire te clava contra el suelo de inmediato.
			velocity.y = SLAM_VELOCITY


## Se ejecuta a ritmo fijo de física (60 veces por segundo por defecto).
## Aquí va todo lo que afecta a posición y colisiones.
func _physics_process(delta: float) -> void:
	# Guardamos si estábamos en el aire ANTES de mover, para detectar
	# el momento exacto del aterrizaje más abajo.
	var was_airborne := not is_on_floor()

	# Cuenta atrás del roll.
	if is_rolling:
		roll_timer -= delta
		if roll_timer <= 0.0:
			end_roll()

	# Movimiento lateral: en vez de teletransportar, calculamos una
	# velocidad proporcional a la distancia que falta. Eso da un
	# deslizamiento suave que se frena solo al llegar.
	var target_x := lane_to_x(current_lane)
	velocity.x = (target_x - global_position.x) * LANE_SNAP

	# Gravedad. get_gravity() lee el valor de Project Settings.
	velocity.y += get_gravity().y * delta

	# Aplica la velocidad y resuelve colisiones con el suelo.
	move_and_slide()

	# Si acabamos de tocar el suelo, volvemos a la animación de correr.
<<<<<<< HEAD
	if was_airborne and is_on_floor():
		is_jumping = false
		if not is_rolling:
			anim.play(ANIM_RUN, 0.1, 1.0)
=======
	if was_airborne and is_on_floor() and not is_rolling:
		anim.play(ANIM_RUN, 0.1, 1.0)
>>>>>>> fda6fd6 (Agregué colisiones, monedas, HUD y el game over)


## Arranca la animación de salto y la congela en el aire.
## Sin esto, la animación termina antes que el salto físico y el
## personaje "corre" mientras cae, que se ve mal.
func start_jump() -> void:
	if not anim.has_animation(ANIM_JUMP):
		return
	anim.play(ANIM_JUMP, 0.1, 1.5)
	# Espera hasta el punto alto del salto y pausa la pose.
	await get_tree().create_timer(0.35).timeout
	if not is_on_floor():
		anim.pause()


## Inicia el roll: encoge la cápsula a la mitad para poder pasar
## por debajo de obstáculos altos, y lanza la animación.
func start_roll() -> void:
	is_rolling = true
	roll_timer = ROLL_TIME
	set_capsule(stand_height * 0.5, stand_y * 0.5)
	play_anim(ANIM_ROLL, 1.2)


## Termina el roll de forma natural (se acabó el temporizador).
## Restaura la cápsula y vuelve a correr.
func end_roll() -> void:
	is_rolling = false
	set_capsule(stand_height, stand_y)
	play_anim(ANIM_RUN)


## Interrumpe el roll a la fuerza (porque el jugador saltó).
## A diferencia de end_roll(), NO lanza la animación de correr,
## porque start_jump() va a poner la de saltar justo después.
func cancel_roll() -> void:
	is_rolling = false
	roll_timer = 0.0
	set_capsule(stand_height, stand_y)


## Cambia el tamaño de la cápsula de colisión.
## h = altura total, y = posición vertical del centro.
## Al encoger hay que bajar también el centro, o la cápsula
## quedaría flotando con los pies en el aire.
func set_capsule(h: float, y: float) -> void:
	var shape := collision.shape as CapsuleShape3D
	shape.height = h
	collision.position.y = y


## Reproduce una animación con transición suave.
## - Si la animación no existe (librería no cargada), no hace nada
##   en vez de reventar el juego.
## - Si ya se está reproduciendo esa misma animación, no la reinicia.
##   Sin esta guarda, llamarla cada frame la dejaría congelada en el frame 0.
## - El 0.15 es el tiempo de mezcla entre la animación anterior y la nueva.
func play_anim(name: String, speed: float = 1.0) -> void:
	if not anim.has_animation(name):
		return
	if anim.current_animation == name and anim.is_playing():
		return
	anim.play(name, 0.15, speed)


## Convierte un índice de carril (0, 1, 2) en su coordenada X.
## Con 3 carriles y ancho 2: carril 0 → -2, carril 1 → 0, carril 2 → +2.
## Calcularlo en vez de usar una lista fija permite cambiar el número
## de carriles tocando solo LANE_COUNT.
func lane_to_x(lane: int) -> float:
	return (lane - (LANE_COUNT - 1) / 2.0) * LANE_WIDTH


## Se dispara cuando el nodo Hitbox (un Area3D hijo) toca otra Area3D.
## Distingue qué tocamos usando grupos, no tipos de nodo, porque así
## se pueden añadir obstáculos nuevos sin tocar este código.
func _on_hitbox_area_entered(area: Area3D) -> void:
	if is_dead:
		return
	if area.is_in_group("obstacle"):
		die()
	elif area.is_in_group("coin"):
		area.collect()
		coin_collected.emit()


## Termina la partida: apaga el procesamiento del jugador para que
## deje de moverse y de responder a teclas, congela la animación,
## y avisa a main.gd mediante la señal para que muestre el Game Over.
func die() -> void:
	is_dead = true
	set_physics_process(false)
	set_process_unhandled_input(false)
	anim.pause()
	died.emit()
