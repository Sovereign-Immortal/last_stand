extends CharacterBody2D

@export var MAX_SPEED = 300.0
@export var ACCELERATION = 1500.0
@export var FRICTION = 1200.0
@export var max_speed: int = 500



func _physics_process(delta):
	
	# input 
	var input_vector = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if input_vector != Vector2.ZERO:
		velocity = velocity.move_toward(input_vector * MAX_SPEED, ACCELERATION * delta)
		
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
		
	move_and_slide()
	look_at(get_global_mouse_position())
	
