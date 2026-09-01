## Control del personaje jugable.
## El jugador NUNCA avanza en Z: se queda fijo en el origen y es el mundo
## el que se mueve hacia él (ver main.gd). Este script solo maneja
## el carril (X), el salto (Y) y la postura (agachado o de pie).
extends CharacterBody3D

## --- Movimiento lateral ---
const LANE_COUNT := 3      ## Número de carriles: izquierda, centro, derecha.
const LANE_WIDTH := 2.0    ## Separación en metros entre carriles.
const LANE_SNAP := 14.0    ## Qué tan rápido se acomoda al carril destino.
						   ## Más alto = más brusco. Más bajo = más resbaladizo.

## --- Salto y deslizamiento ---
const JUMP_VELOCITY := 8.0    ## Impulso vertical inicial al saltar.
const ROLL_TIME := 1.0        ## Duración del roll en segundos.
const SLAM_VELOCITY := -20.0  ## Fuerza hacia abajo al rodar en el aire.
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
var current_lane := 1     ## 0 = izquierda, 1 = centro, 2 = derecha.
var is_rolling := false   ## true mientras dura el roll.
var roll_timer := 0.0     ## Cuenta atrás del roll en segundos.
var is_dead := false      ## Evita procesar más colisiones tras morir.
var is_jumping := false   ## true desde que se pulsa saltar hasta aterrizar.
						  ## No usamos solo is_on_floor() porque tarda un frame
						  ## en actualizarse y permitiría saltos dobles.

## Medidas de la cápsula de pie. Se guardan al arrancar para poder
## restaurarlas después de encogerla durante el roll.
var stand_height: float
var stand_y: float


## Se ejecuta una vez al entrar en la escena.
func _ready() -> void:
	global_position.x = lane_to_x(current_lane)
	var shape := collision.shape as CapsuleShape3D
	stand_height = shape.height
	stand_y = collision.position.y
	play_anim(ANIM_RUN)


## Recibe las pulsaciones de teclas.
## Usa _unhandled_input (no _input) para que la UI tenga prioridad:
## si un botón del menú consume la tecla, aquí no llega.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_left"):
		current_lane = maxi(current_lane - 1, 0)
	elif event.is_action_pressed("move_right"):
		current_lane = mini(current_lane + 1, LANE_COUNT - 1)
	elif event.is_action_pressed("jump") and not is_jumping:
		if is_rolling:
			# Saltar cancela el roll a medias (como en Subway Surfers).
			cancel_roll()
			is_jumping = true
			velocity.y = JUMP_VELOCITY
			start_jump()
		elif is_on_floor():
			# Solo se puede saltar desde el suelo (no hay doble salto).
			is_jumping = true
			velocity.y = JUMP_VELOCITY
			start_jump()
	elif event.is_action_pressed("roll") and not is_rolling:
		start_roll()
		if not is_on_floor():
			# Rodar en el aire te clava contra el suelo de inmediato.
			velocity.y = SLAM_VELOCITY


## Se ejecuta a ritmo fijo de física (60 veces por segundo por defecto).
func _physics_process(delta: float) -> void:
	var was_airborne := not is_on_floor()

	if is_rolling:
		roll_timer -= delta
		if roll_timer <= 0.0:
			end_roll()

	var target_x := lane_to_x(current_lane)
	velocity.x = (target_x - global_position.x) * LANE_SNAP
	velocity.y += get_gravity().y * delta
	move_and_slide()

	# Al aterrizar liberamos el bloqueo del salto y volvemos a correr.
	if was_airborne and is_on_floor():
		is_jumping = false
		if not is_rolling:
			anim.play(ANIM_RUN, 0.1, 1.0)


## Arranca la animación de salto y la congela en el aire.
func start_jump() -> void:
	if not anim.has_animation(ANIM_JUMP):
		return
	anim.play(ANIM_JUMP, 0.1, 1.5)
	await get_tree().create_timer(0.35).timeout
	if not is_on_floor():
		anim.pause()


## Inicia el roll: encoge la cápsula a la mitad y lanza la animación.
func start_roll() -> void:
	is_rolling = true
	roll_timer = ROLL_TIME
	set_capsule(stand_height * 0.5, stand_y * 0.5)
	play_anim(ANIM_ROLL, 1.2)


## Termina el roll de forma natural (se acabó el temporizador).
func end_roll() -> void:
	is_rolling = false
	set_capsule(stand_height, stand_y)
	play_anim(ANIM_RUN)


## Interrumpe el roll a la fuerza (porque el jugador saltó).
func cancel_roll() -> void:
	is_rolling = false
	roll_timer = 0.0
	set_capsule(stand_height, stand_y)


## Cambia el tamaño de la cápsula de colisión.
func set_capsule(h: float, y: float) -> void:
	var shape := collision.shape as CapsuleShape3D
	shape.height = h
	collision.position.y = y


## Reproduce una animación con transición suave.
## El parámetro se llama "anim_name" y no "name": todo Node en Godot ya
## trae una propiedad interna llamada "name" (el nombre del nodo en el
## árbol), así que usar ese mismo nombre como parámetro la tapaba
## ("shadowing") y generaba un aviso en el depurador.
func play_anim(anim_name: String, speed: float = 1.0) -> void:
	# Si la animación no existe (librería no cargada), no hace nada
	# en vez de reventar el juego.
	if not anim.has_animation(anim_name):
		return
	# Evita reiniciar una animación que ya se está reproduciendo:
	# sin esto, cada frame que se llama a esta función la animación
	# se cortaría y arrancaría de cero.
	if anim.current_animation == anim_name and anim.is_playing():
		return
	anim.play(anim_name, 0.15, speed)


## Convierte un índice de carril (0, 1, 2) en su coordenada X.
func lane_to_x(lane: int) -> float:
	return (lane - (LANE_COUNT - 1) / 2.0) * LANE_WIDTH


## Se dispara cuando el nodo Hitbox (un Area3D hijo) toca otra Area3D.
func _on_hitbox_area_entered(area: Area3D) -> void:
	if is_dead:
		return
	if area.is_in_group("obstacle"):
		die()
	elif area.is_in_group("coin"):
		area.collect()
		coin_collected.emit()


## Termina la partida y avisa a main.gd mediante la señal.
func die() -> void:
	is_dead = true
	set_physics_process(false)
	set_process_unhandled_input(false)
	anim.pause()
	died.emit()
