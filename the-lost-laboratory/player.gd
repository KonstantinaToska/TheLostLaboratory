extends CharacterBody3D

@export var speed := 4.0
@export var gravity := 9.8


func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta

	var input_direction := Input.get_vector(
		"ui_left",
		"ui_right",
		"ui_up",
		"ui_down"
	)

	var direction := Vector3(
		input_direction.x,
		0,
		input_direction.y
	).normalized()

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	move_and_slide()
