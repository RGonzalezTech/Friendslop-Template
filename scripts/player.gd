extends Node2D
class_name Player

## The player that reads the input

@onready var input_relay : InputRelay = $InputRelay

func _ready() -> void:
    # input_relay.action_detected.connect(_on_action_detected)
    pass
