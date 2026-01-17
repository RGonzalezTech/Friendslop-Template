extends CharacterBody2D
class_name Player

## The player that reads the input

@onready var action_router: ActionRouter = $ActionRouter

const MAX_SPEED: float = 300.0

func _ready() -> void:
    # action_router.action_detected.connect(_on_action_detected)
    pass

func _physics_process(_delta: float) -> void:
    var move_input := Vector2(
        action_router.get_axis("move_left", "move_right"),
        action_router.get_axis("move_up", "move_down")
    )
    # limit_length(1.0) to make sure we normalize _ONLY IF_ the magnitude
    # is greater than 1. Prevents moving faster than max when diagonal movement
    self.velocity = move_input.limit_length(1.0) * MAX_SPEED

    move_and_slide()

# func _on_action_detected(action: String, event: InputEvent) -> void:
#     print("PRESSED: %s" % [action])
