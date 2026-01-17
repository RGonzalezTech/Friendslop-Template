extends InputRelay
class_name GameInputRelay

func _init() -> void:
	actions_to_monitor = [
		"move_left",
		"move_right",
		"move_up",
		"move_down",
	]
