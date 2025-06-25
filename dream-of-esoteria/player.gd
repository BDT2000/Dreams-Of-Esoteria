extends CharacterBody2D

const SPEED = 5000.0

@export var starting_direction : Vector2 = Vector2(0,1)
var direction : Vector2
@onready var anim_player = $AnimationPlayer

func _ready():
	update_animation(starting_direction)

func _physics_process(delta):
	if Input.is_action_pressed("move_down"):
		direction.y = 1
	elif Input.is_action_pressed("move_up"):
		direction.y = -1
	else:
		direction.y = 0
	if Input.is_action_pressed("move_right"):
		direction.x = 1
	elif Input.is_action_pressed("move_left"):
		direction.x = -1
	else:
		direction.x = 0
		
	update_animation(direction)
		
	velocity = direction * delta * SPEED
	
	move_and_slide()
	
func update_animation(dir:Vector2):
	if (dir) != Vector2.ZERO:
		if dir.y == 1:
			anim_player.play("walk-down")
		elif dir.y == -1:
			anim_player.play("walk-up")
		elif dir.x == 1:
			anim_player.play("walk-right")
		elif dir.x == -1:
			anim_player.play("walk-left")
	else:
		anim_player.play("RESET")
