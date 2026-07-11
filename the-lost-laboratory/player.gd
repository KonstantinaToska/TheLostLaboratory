extends CharacterBody3D

@export var speed := 4.0
@export var gravity := 9.8
@export var mouse_sensitivity := 0.002

@onready var camera: Camera3D = $Camera3D
@onready var interaction_ray: RayCast3D = $Camera3D/InteractionRay
@onready var camera_hand := get_node_or_null("Camera3D/CameraHand") as Sprite3D
@onready var old_hand_hint := get_node_or_null("../UI/HandHint") as TextureRect
@onready var switch_focus_label := get_node_or_null("../UI/SwitchFocusLabel") as Label
@onready var switch_pressed_label := get_node_or_null("../UI/SwitchPressedLabel") as Label
@onready var game_manager := get_node_or_null("../GameManager")

var camera_pitch := 0.0
var focused_switch_number := 0
var pressed_message_timer := 0.0
var hand_feedback_timer := 0.0
var hand_feedback_color := Color.WHITE

const HAND_NORMAL_COLOR := Color(1, 1, 1, 1)
const HAND_CORRECT_COLOR := Color(0.35, 1.0, 0.45, 1)
const HAND_WRONG_COLOR := Color(1.0, 0.12, 0.12, 1)


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_hide_switch_ui()

	# We now use a Sprite3D attached to the camera, so the hand looks like it belongs to the player.
	if camera_hand:
		camera_hand.visible = false
		camera_hand.modulate = HAND_NORMAL_COLOR

	# Keep the old UI hand hidden in case it still exists in the scene.
	if old_hand_hint:
		old_hand_hint.visible = false
		old_hand_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if switch_focus_label:
		switch_focus_label.visible = false
		switch_focus_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if switch_pressed_label:
		switch_pressed_label.visible = false
		switch_pressed_label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta):
	_update_switch_hint()
	_update_hand_feedback(delta)

	if pressed_message_timer > 0.0:
		pressed_message_timer -= delta
		if pressed_message_timer <= 0.0 and switch_pressed_label:
			switch_pressed_label.visible = false


func _unhandled_input(event):
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)

		camera_pitch -= event.relative.y * mouse_sensitivity
		camera_pitch = clamp(camera_pitch, deg_to_rad(-80), deg_to_rad(80))
		camera.rotation.x = camera_pitch

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if event is InputEventMouseButton and event.pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and event.keycode == KEY_E):
		_try_interact()


func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta

	var input_direction := Vector2.ZERO

	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_direction.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_direction.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_direction.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_direction.y += 1

	input_direction = input_direction.normalized()

	var direction := (
		transform.basis * Vector3(input_direction.x, 0, input_direction.y)
	).normalized()

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	move_and_slide()


func _try_interact():
	interaction_ray.force_raycast_update()

	if not interaction_ray.is_colliding():
		print("Nothing to interact with")
		return

	var collider = interaction_ray.get_collider()
	if collider == null:
		print("Nothing to interact with")
		return

	print("Looking at: ", collider.name)
	if collider.get_parent() != null:
		print("Parent: ", collider.get_parent().name)

	var switch_number := _get_switch_number(collider)
	if switch_number > 0:
		_show_pressed_switch(switch_number)
		if game_manager and game_manager.has_method("on_switch_pressed"):
			game_manager.on_switch_pressed(switch_number)


func _update_switch_hint():
	_hide_switch_ui()
	focused_switch_number = 0

	interaction_ray.force_raycast_update()
	if not interaction_ray.is_colliding():
		return

	var collider = interaction_ray.get_collider()
	if collider == null:
		return

	var switch_number := _get_switch_number(collider)
	if switch_number <= 0:
		return

	focused_switch_number = switch_number

	# The hand is now a 3D sprite attached to the camera.
	# It stays in the lower-right area of the view, like the player's own hand.
	if camera_hand:
		camera_hand.visible = true
		if hand_feedback_timer <= 0.0:
			camera_hand.modulate = HAND_NORMAL_COLOR

	if switch_focus_label:
		switch_focus_label.text = "Κουμπί %d  |  Πάτα E" % switch_number
		switch_focus_label.position = Vector2(760, 615)
		switch_focus_label.size = Vector2(360, 42)
		switch_focus_label.visible = true


func _update_hand_feedback(delta: float):
	if hand_feedback_timer <= 0.0:
		return

	hand_feedback_timer -= delta
	if camera_hand:
		camera_hand.modulate = hand_feedback_color

	if hand_feedback_timer <= 0.0:
		if camera_hand:
			camera_hand.modulate = HAND_NORMAL_COLOR
		if switch_pressed_label:
			switch_pressed_label.modulate = Color.WHITE


func show_correct_feedback(switch_number: int):
	hand_feedback_color = HAND_CORRECT_COLOR
	hand_feedback_timer = 0.75

	if camera_hand:
		camera_hand.modulate = HAND_CORRECT_COLOR

	if switch_pressed_label:
		switch_pressed_label.text = "Σωστό κουμπί: %d" % switch_number
		switch_pressed_label.modulate = Color(0.35, 1.0, 0.45, 1)
		switch_pressed_label.visible = true
		pressed_message_timer = 1.2


func show_wrong_feedback():
	hand_feedback_color = HAND_WRONG_COLOR
	hand_feedback_timer = 1.2

	if camera_hand:
		camera_hand.visible = true
		camera_hand.modulate = HAND_WRONG_COLOR

	if switch_pressed_label:
		switch_pressed_label.text = "Λάθος σειρά!"
		switch_pressed_label.modulate = HAND_WRONG_COLOR
		switch_pressed_label.visible = true
		pressed_message_timer = 1.6


func show_complete_feedback():
	hand_feedback_color = HAND_CORRECT_COLOR
	hand_feedback_timer = 1.0

	if camera_hand:
		camera_hand.modulate = HAND_CORRECT_COLOR

	if switch_pressed_label:
		switch_pressed_label.text = "Ο γρίφος ολοκληρώθηκε!"
		switch_pressed_label.modulate = Color(0.35, 1.0, 0.45, 1)
		switch_pressed_label.visible = true
		pressed_message_timer = 2.2


func _show_pressed_switch(switch_number: int):
	print("Pressed switch: ", switch_number)


func _hide_switch_ui():
	if old_hand_hint:
		old_hand_hint.visible = false
	if camera_hand:
		camera_hand.visible = false
	if switch_focus_label:
		switch_focus_label.visible = false


func _get_switch_number(collider) -> int:
	if collider == null:
		return 0

	var names_to_check: Array[String] = [str(collider.name)]
	if collider.get_parent() != null:
		names_to_check.append(str(collider.get_parent().name))

	for node_name in names_to_check:
		if node_name.begins_with("Switch1"):
			return 1
		if node_name.begins_with("Switch2"):
			return 2
		if node_name.begins_with("Switch3"):
			return 3

	return 0
