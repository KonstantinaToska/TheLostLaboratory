extends CharacterBody3D

@export var speed := 4.0
@export var gravity := 9.8
@export var mouse_sensitivity := 0.15

var raycast: RayCast3D
var prompt_label: Label
var victory_screen: Control
var debug_label: Label
var crosshair_label: Label

func log_debug(message: String) -> void:
	var path := "res://player_debug.log"
	var file = FileAccess.open(path, FileAccess.READ_WRITE)
	if not file:
		file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.seek_end()
		file.store_line(str(Time.get_time_string_from_system()) + " [Player]: " + message)
		file.close()

func _ready() -> void:
	log_debug("Ready started")
	# Capture mouse
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Create RayCast3D for interaction
	raycast = RayCast3D.new()
	raycast.enabled = true
	raycast.target_position = Vector3(0, 0, -2.5) # 2.5 meters range
	raycast.collision_mask = 1 # Default layer
	raycast.collide_with_areas = true
	raycast.collide_with_bodies = true
	
	var camera = $Camera3D
	if camera:
		camera.add_child(raycast)
		
	# Find UI elements dynamically (relative to Player node)
	prompt_label = get_node_or_null("../UI/InteractionPrompt")
	victory_screen = get_node_or_null("../UI/VictoryScreen")
	debug_label = get_node_or_null("../UI/DebugLabel")
	crosshair_label = get_node_or_null("../UI/Crosshair")
	
	if victory_screen:
		victory_screen.visible = false

func _input(event: InputEvent) -> void:
	# Mouse look
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
		
		var camera = $Camera3D
		if camera:
			camera.rotate_x(deg_to_rad(-event.relative.y * mouse_sensitivity))
			# Clamp camera pitch (look up/down limits)
			camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80.0), deg_to_rad(80.0))

func _unhandled_input(event: InputEvent) -> void:
	# Click inside the window to capture the mouse again
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			log_debug("Capturing mouse cursor")
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
			return
			
	# Press ESC to release/capture mouse cursor
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			log_debug("Releasing mouse cursor")
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			log_debug("Capturing mouse cursor")
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			
	# Interact with E (handling layout-independent physical keycode for Greek layouts) or Left Mouse Click
	var is_interact_key = false
	if event is InputEventKey and event.pressed:
		is_interact_key = (event.keycode == KEY_E or event.physical_keycode == KEY_E)
		if is_interact_key:
			log_debug("E key pressed (keycode: " + str(event.keycode) + ", physical: " + str(event.physical_keycode) + ")")
			
	var is_mouse_click = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if is_mouse_click:
		log_debug("Left mouse click interaction")
	
	if is_interact_key or is_mouse_click:
		# Play first-person hand reach animation
		var hand_pivot = get_node_or_null("Camera3D/HandPivot")
		if hand_pivot:
			var tween := create_tween()
			# Reach forward
			tween.tween_property(hand_pivot, "position:z", -0.7, 0.1).set_trans(Tween.TRANS_SINE)
			tween.tween_property(hand_pivot, "position:x", 0.12, 0.1).set_trans(Tween.TRANS_SINE)
			# Return back
			tween.tween_property(hand_pivot, "position:z", -0.45, 0.15).set_trans(Tween.TRANS_SINE).set_delay(0.08)
			tween.tween_property(hand_pivot, "position:x", 0.2, 0.15).set_trans(Tween.TRANS_SINE).set_delay(0.08)

		if raycast and raycast.is_colliding():
			var collider = raycast.get_collider()
			if collider and collider.has_method("interact"):
				log_debug("Calling interact() on " + collider.name)
				collider.interact(self)
			else:
				log_debug("Collider has no interact() method")
		else:
			log_debug("Raycast is not colliding with anything on press")

func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Foolproof input detection for WASD and Arrow Keys
	var input_direction := Vector2.ZERO
	
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_direction.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_direction.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_direction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_direction.x += 1.0
		
	# Normalize to prevent diagonal speed boost
	if input_direction.length() > 0:
		input_direction = input_direction.normalized()

	# Calculate movement direction relative to camera rotation
	var direction := Vector3(input_direction.x, 0, input_direction.y)
	direction = direction.rotated(Vector3.UP, rotation.y).normalized()

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	move_and_slide()
	
	# Update Interaction UI and Debug Overlay
	if raycast and raycast.is_colliding():
		var collider = raycast.get_collider()
		
		# Update debug text on screen
		if debug_label and collider:
			debug_label.text = "Looking at: " + collider.name + " (Class: " + collider.get_class() + ")"
			
		if collider and collider.has_method("interact") and collider.get("is_interactive") == true:
			if prompt_label:
				prompt_label.text = "[E] " + str(collider.get("prompt_message"))
				prompt_label.visible = true
			if crosshair_label:
				crosshair_label.text = "🫱"
				crosshair_label.set("theme_override_font_sizes/font_size", 28)
		else:
			if prompt_label:
				prompt_label.visible = false
			if crosshair_label:
				crosshair_label.text = "+"
				crosshair_label.set("theme_override_font_sizes/font_size", 20)
	else:
		if debug_label:
			debug_label.text = "Looking at: Nothing"
		if prompt_label:
			prompt_label.visible = false
		if crosshair_label:
			crosshair_label.text = "+"
			crosshair_label.set("theme_override_font_sizes/font_size", 20)

func escape(body: Node3D = null) -> void:
	log_debug("Escaped!")
	# Release mouse and show victory screen
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if victory_screen:
		victory_screen.visible = true
	
	# Wait 3 seconds and terminate/quit the game
	await get_tree().create_timer(3.0).timeout
	get_tree().quit()
