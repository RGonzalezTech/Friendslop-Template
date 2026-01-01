extends InputRelay
class_name GameInputRelay

func _init() -> void:
    actions_to_monitor = [
        "ui_left",
        "ui_right",
        "ui_up",
        "ui_down",
        "fire"
    ]