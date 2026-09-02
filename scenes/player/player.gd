## Control del personaje jugable.
## El jugador NUNCA avanza en Z: se queda fijo en el origen y es el mundo
## el que se mueve hacia él (ver main.gd). Este script solo maneja
## el carril (X), el salto (Y) y la postura (agachado o de pie).
extends CharacterBody3D # Inherita de CharacterBody3D para manejar la física del personaje

## --- Movimiento lateral ---
const LANE_COUNT := 3      # Número de carriles totales: izquierda (0), centro (1), derecha (2)
const LANE_WIDTH := 2.0    # Separación en metros entre carriles
const LANE_SNAP := 14.0    # Velocidad de ajuste de posición horizontal hacia el carril destino

## --- Salto y deslizamiento ---
const JUMP_VELOCITY := 8.0    # Fuerza del impulso vertical al saltar
const ROLL_TIME := 1.0        # Tiempo total del deslizamiento en segundos
const SLAM_VELOCITY := -40.0  # Impulso descendente rápido para caer de golpe si se rueda en el aire

## --- Nombres de las animaciones ---
const ANIM_RUN := "mixamo_com"        # Nombre de la animación base al correr
const ANIM_JUMP := "jump/mixamo_com"  # Nombre de la animación al saltar
const ANIM_ROLL := "roll/mixamo_com"  # Nombre de la animación al rodar/deslizarse

## --- Referencias a nodos hijos ---
@onready var collision: CollisionShape3D = $CollisionShape3D # Referencia al nodo de colisión física
@onready var model: Node3D = $Model                         # Referencia al nodo contenedor del modelo 3D
@onready var anim: AnimationPlayer = $Model/run/AnimationPlayer # Referencia al reproductor de animaciones

## --- Señales que este nodo emite hacia main.gd ---
signal died            # Señal enviada al morir el personaje
signal coin_collected  # Señal enviada al recoger una moneda

## --- Estado interno ---
var current_lane := 1     # Carril actual (0 = izquierda, 1 = centro, 2 = derecha)
var is_rolling := false   # Define si el personaje está actualmente rodando
var roll_timer := 0.0     # Temporizador para controlar la duración del rodamiento
var is_dead := false      # Bloquea las colisiones y controles tras morir
var is_jumping := false   # Indica si el personaje está en medio de un salto

## Medidas de la cápsula de pie. Se guardan al arrancar para poder
## restaurarlas después de encogerla durante el roll.
var stand_height: float   # Almacena la altura original de la cápsula de colisión
var stand_y: float        # Almacena la posición Y original de la cápsula de colisión


# Se ejecuta una sola vez cuando el nodo entra al árbol de la escena
func _ready() -> void:
	global_position.x = lane_to_x(current_lane)        # Ubica al jugador en la posición X del carril inicial
	var shape := collision.shape as CapsuleShape3D     # Obtiene la forma de la cápsula de colisión
	stand_height = shape.height                        # Guarda la altura inicial de la cápsula
	stand_y = collision.position.y                     # Guarda la posición vertical inicial de la cápsula
	play_anim(ANIM_RUN)                               # Inicia la animación de correr por defecto


# Escucha la entrada de controles no procesada previamente por la interfaz (UI)
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_left"):            # Si presiona la tecla para mover a la izquierda
		current_lane = maxi(current_lane - 1, 0)        # Cambia al carril izquierdo sin bajar de 0
	elif event.is_action_pressed("move_right"):         # Si presiona la tecla para mover a la derecha
		current_lane = mini(current_lane + 1, LANE_COUNT - 1) # Cambia al carril derecho sin superar el máximo
	elif event.is_action_pressed("jump") and not is_jumping: # Si presiona saltar y no está saltando
		if is_rolling:                                  # Si presiona saltar mientras está rodando
			cancel_roll()                               # Cancela el rodamiento inmediatamente
			is_jumping = true                           # Activa el estado de salto
			velocity.y = JUMP_VELOCITY                  # Aplica la fuerza del salto a la velocidad Y
			start_jump()                                # Inicia la animación de salto
		elif is_on_floor():                             # Si está firme sobre el suelo
			is_jumping = true                           # Activa el estado de salto
			velocity.y = JUMP_VELOCITY                  # Aplica la fuerza del salto a la velocidad Y
			start_jump()                                # Inicia la animación de salto
	elif event.is_action_pressed("roll") and not is_rolling: # Si presiona rodar y no está rodando
		start_roll()                                    # Inicia la rutina de rodar
		if not is_on_floor():                           # Si presiona rodar estando en el aire
			velocity.y = SLAM_VELOCITY                  # Aplica fuerza vertical hacia abajo para caer de golpe


# Se ejecuta en el ciclo de actualización de física (60 veces por segundo)
func _physics_process(delta: float) -> void:
	var was_airborne := not is_on_floor()               # Registra si el jugador no estaba tocando el suelo en este frame

	if is_rolling:                                      # Si está actualmente en estado de rodar
		roll_timer -= delta                             # Descuenta el tiempo transcurrido al temporizador
		if roll_timer <= 0.0:                           # Si el tiempo llegó a cero
			end_roll()                                  # Termina el rodamiento y regresa la cápsula a su tamaño

	var target_x := lane_to_x(current_lane)            # Obtiene la posición objetivo en X para el carril actual
	velocity.x = (target_x - global_position.x) * LANE_SNAP # Calcula la velocidad horizontal requerida
	velocity.y += get_gravity().y * delta               # Aplica la fuerza de la gravedad a la velocidad Y
	move_and_slide()                                    # Mueve el personaje ejecutando la física del motor

	if was_airborne and is_on_floor():                  # Si el personaje acaba de aterrizar en el suelo
		is_jumping = false                              # Desactiva la bandera de salto
		if not is_rolling:                              # Si no aterrizó rodando
			anim.play(ANIM_RUN, 0.1, 1.0)               # Vuelve a reproducir la animación de correr


# Maneja el arranque de la animación de salto y su pausa momentánea en el aire
func start_jump() -> void:
	if not anim.has_animation(ANIM_JUMP):               # Verifica si existe la animación de salto
		return                                          # Si no existe, cancela la ejecución de la función
	anim.play(ANIM_JUMP, 0.1, 1.5)                      # Reproduce la animación de salto acelerada
	await get_tree().create_timer(0.35).timeout          # Pausa la ejecución de esta función por 0.35 segundos
	if not is_on_floor():                               # Si transcurrido ese tiempo sigue en el aire
		anim.pause()                                    # Congela la animación de salto temporalmente


# Inicia el estado de rodamiento, achica la colisión e inicia la animación
func start_roll() -> void:
	is_rolling = true                                   # Marca la bandera de rodamiento como activa
	roll_timer = ROLL_TIME                              # Carga el tiempo total del rodamiento
	set_capsule(stand_height * 0.5, stand_y * 0.5)      # Encoge la cápsula de colisión a la mitad
	play_anim(ANIM_ROLL, 1.2)                          # Inicia la animación de rodar


# Termina el rodamiento de forma natural al agotarse el tiempo
func end_roll() -> void:
	is_rolling = false                                  # Desactiva la bandera de rodamiento
	set_capsule(stand_height, stand_y)                  # Restablece el tamaño y posición original de la cápsula
	play_anim(ANIM_RUN)                                 # Vuelve a la animación de correr


# Interrumpe el rodamiento por una acción obligatoria como un salto
func cancel_roll() -> void:
	is_rolling = false                                  # Desactiva la bandera de rodamiento
	roll_timer = 0.0                                    # Resetea el contador de tiempo
	set_capsule(stand_height, stand_y)                  # Restablece la cápsula a su tamaño normal


# Ajusta la altura y la posición Y de la cápsula de colisión
func set_capsule(h: float, y: float) -> void:
	var shape := collision.shape as CapsuleShape3D     # Obtiene la referencia a la forma de la cápsula
	shape.height = h                                    # Modifica la altura de la cápsula
	collision.position.y = y                            # Modifica la posición vertical Y de la cápsula


# Reproduce una animación aplicando una transición suave entre estados
func play_anim(anim_name: String, speed: float = 1.0) -> void:
	if not anim.has_animation(anim_name):               # Revisa si la animación solicitada existe
		return                                          # Sale si no existe la animación
	if anim.current_animation == anim_name and anim.is_playing(): # Si la animación ya se está reproduciendo
		return                                          # Evita cortarla o reiniciarla
	anim.play(anim_name, 0.15, speed)                   # Ejecuta la animación con una mezcla suave de 0.15s


# Calcula la coordenada X en metros basándose en el carril indicado (0, 1, 2)
func lane_to_x(lane: int) -> float:
	return (lane - (LANE_COUNT - 1) / 2.0) * LANE_WIDTH # Convierte el índice a coordenada X (-2.0, 0.0, 2.0)


# Se ejecuta automáticamente cuando la Hitbox del jugador colisiona con un Area3D
func _on_hitbox_area_entered(area: Area3D) -> void:
	if is_dead:                                         # Si el jugador ya está muerto
		return                                          # Ignora el procesamiento de la colisión
		
	if area.is_in_group("obstacle"):                    # Obstáculos mortales (trenes, vallas altas, etc.)
		die()                                           # Muerte de un golpe
		
	elif area.is_in_group("pole"):                      # Poste específico (baja velocidad y te mueve de carril)
		if get_parent().has_method("register_impact"):  # Llama a main.gd para bajar la velocidad general
			get_parent().register_impact()
		
		# Lógica para empujar al jugador al carril libre sin sacarlo del mapa
		if current_lane == 0:                           # Si chocó en el carril izquierdo
			current_lane = 1                            # Lo empuja a salvo hacia el centro
		elif current_lane == 2:                         # Si chocó en el carril derecho
			current_lane = 1                            # Lo empuja a salvo hacia el centro
		elif current_lane == 1:                         # Si chocó en el carril central
			if area.global_position.x > global_position.x: # Si el poste está a su derecha
				current_lane = 0                        # Lo empuja hacia la izquierda
			else:                                       # Si el poste está a su izquierda
				current_lane = 2                        # Lo empuja hacia la derecha

	elif area.is_in_group("wall"):                      # Paredes laterales de los 3 carriles
		if get_parent().has_method("register_impact"):  # Llama a main.gd para bajar la velocidad
			get_parent().register_impact()              # Tropieza, pero se queda en el mismo carril
			
	elif area.is_in_group("coin"):                      # Si la colisión es con una moneda
		area.collect()                                  # Ejecuta la lógica propia de la moneda
		coin_collected.emit()                           # Emite la señal de moneda recolectada hacia main.gd


# Procesa la muerte del jugador, bloquea controles y notifica a main.gd
func die() -> void:
	is_dead = true                                      # Define el estado del personaje a muerto
	set_physics_process(false)                          # Desactiva la actualización de físicas
	set_process_unhandled_input(false)                  # Desactiva la lectura de botones e insumos del usuario
	anim.pause()                                        # Pausa la animación actual
	died.emit()                                         # Emite la señal de muerte hacia main.gd
