extends Node

# GameManager handles the first escape-room puzzle.
# Correct sequence: Button 2 -> Button 1 -> Button 3.
# Wrong sequence resets the puzzle and gives red feedback.
# Correct inputs turn the indicators green; completion unlocks the door panel.

const CORRECT_SEQUENCE := [2, 1, 3]

@onready var indicator_1: MeshInstance3D = $"../ControlConsole/Indicator1"
@onready var indicator_2: MeshInstance3D = $"../ControlConsole/Indicator2"
@onready var indicator_3: MeshInstance3D = $"../ControlConsole/Indicator3"
@onready var panel_indicator: MeshInstance3D = $"../AccessPanel/PanelIndicator"
@onready var status_label := get_node_or_null("../UI/SwitchPressedLabel") as Label
@onready var player := get_node_or_null("../Player")

var current_step := 0
var puzzle_completed := false
var status_timer := 0.0

var red_material: StandardMaterial3D
var green_material: StandardMaterial3D
var yellow_material: StandardMaterial3D


func _ready():
	red_material = _create_emissive_material(Color(1.0, 0.08, 0.08), 2.8)
	green_material = _create_emissive_material(Color(0.1, 1.0, 0.35), 3.2)
	yellow_material = _create_emissive_material(Color(1.0, 0.78, 0.18), 2.8)

	_reset_indicators()
	_show_status("Σειρά γρίφου: 2 → 1 → 3", 2.5, Color.WHITE)


func _process(delta):
	if status_timer > 0.0:
		status_timer -= delta
		if status_timer <= 0.0 and status_label:
			status_label.visible = false
			status_label.modulate = Color.WHITE


func on_switch_pressed(switch_number: int):
	if puzzle_completed:
		_show_status("Ο γρίφος έχει ήδη ολοκληρωθεί.", 1.5, Color(0.35, 1.0, 0.45, 1))
		return

	var expected_switch: int = CORRECT_SEQUENCE[current_step]

	if switch_number == expected_switch:
		_mark_switch_correct(switch_number)
		_notify_player_correct(switch_number)
		current_step += 1

		if current_step >= CORRECT_SEQUENCE.size():
			_complete_puzzle()
		else:
			_show_status("Σωστό! Επόμενο βήμα: %d" % CORRECT_SEQUENCE[current_step], 1.5, Color(0.35, 1.0, 0.45, 1))
	else:
		# Wrong button: everything becomes red and the sequence starts again.
		_show_status("Λάθος σειρά! Ξεκίνα ξανά.", 2.0, Color(1.0, 0.1, 0.1, 1))
		_notify_player_wrong()
		_reset_puzzle()


func _mark_switch_correct(switch_number: int):
	var indicator := _get_indicator(switch_number)
	if indicator:
		indicator.set_surface_override_material(0, green_material)

	_show_status("Σωστό κουμπί: %d" % switch_number, 1.2, Color(0.35, 1.0, 0.45, 1))


func _complete_puzzle():
	puzzle_completed = true
	current_step = CORRECT_SEQUENCE.size()

	if panel_indicator:
		panel_indicator.set_surface_override_material(0, green_material)

	_notify_player_complete()
	_show_status("Ο γρίφος ολοκληρώθηκε! Η πόρτα ξεκλειδώθηκε.", 3.0, Color(0.35, 1.0, 0.45, 1))
	print("Puzzle completed. Door is now unlocked.")


func _reset_puzzle():
	current_step = 0
	_reset_indicators()


func _reset_indicators():
	if indicator_1:
		indicator_1.set_surface_override_material(0, red_material)
	if indicator_2:
		indicator_2.set_surface_override_material(0, red_material)
	if indicator_3:
		indicator_3.set_surface_override_material(0, red_material)
	if panel_indicator:
		panel_indicator.set_surface_override_material(0, red_material)


func _get_indicator(switch_number: int) -> MeshInstance3D:
	match switch_number:
		1:
			return indicator_1
		2:
			return indicator_2
		3:
			return indicator_3
		_:
			return null


func _show_status(message: String, duration: float, color: Color = Color.WHITE):
	print(message)

	if status_label == null:
		return

	status_label.text = message
	status_label.modulate = color
	status_label.visible = true
	status_timer = duration


func _notify_player_correct(switch_number: int):
	if player and player.has_method("show_correct_feedback"):
		player.show_correct_feedback(switch_number)


func _notify_player_wrong():
	if player and player.has_method("show_wrong_feedback"):
		player.show_wrong_feedback()


func _notify_player_complete():
	if player and player.has_method("show_complete_feedback"):
		player.show_complete_feedback()


func _create_emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
