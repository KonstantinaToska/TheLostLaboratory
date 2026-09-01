extends CollisionObject3D
class_name Interactable

@export var prompt_message := "Interact"
@export var is_interactive := true

signal interacted(player)

func log_debug(message: String) -> void:
	var path := "res://interactable_debug.log"
	var file = FileAccess.open(path, FileAccess.READ_WRITE)
	if not file:
		file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.seek_end()
		file.store_line(str(Time.get_time_string_from_system()) + " [" + name + "]: " + message)
		file.close()

func interact(player) -> void:
	log_debug("interact() called")
	if is_interactive:
		log_debug("emitting interacted signal")
		interacted.emit(player)
	else:
		log_debug("is_interactive is false, doing nothing")
