# Input Routing

The input system in this template is designed to handle local multiplayer efficiently by isolating input actions per device.

## ActionRouter

The `ActionRouter` ([action_router.gd](./action_router.gd)) is a [Node](https://docs.godotengine.org/en/stable/classes/class_node.html) that clones [InputMap](https://docs.godotengine.org/en/stable/classes/class_inputmap.html) actions to isolate inputs per device. This allows multiple players (Keyboard/Mouse or Gamepads) to use the same action names without interference.

### Usage

1. **Inherit**: Create a class (e.g., [GameActionRouter](./game_action_router.gd)) and list actions to monitor in `_init`.
2. **Device ID**: Set `device_id` (`-1` for MKB, `0+` for Joypads) to filter inputs.
3. **Polling**: Use `get_axis()` or `get_strength()` instead of the global `Input` class.
4. **Signals**: Connect to `action_detected(action_name: String, event: InputEvent)` for event-based input.

### Example: Player Input

```gdscript
# scripts/player.gd
@onready var action_router: ActionRouter = $ActionRouter

const MAX_SPEED = 10.0

func _physics_process(_delta: float) -> void:
    var move_input := Vector2(
        action_router.get_axis("move_left", "move_right"),
        action_router.get_axis("move_up", "move_down")
    )
    velocity = move_input.limit_length(1.0) * MAX_SPEED
    move_and_slide()
```

- [InputEvent](https://docs.godotengine.org/en/stable/classes/class_inputevent.html) documentation.
- [CharacterBody2D](https://docs.godotengine.org/en/stable/classes/class_characterbody2d.html) documentation.
