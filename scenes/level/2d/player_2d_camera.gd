class_name Player2DCamera
extends Camera2D

## This class takes the player's input (mouse or action-based)
## and "peaks" the camera toward that position.

## The maximum distance the camera can peak from the player.
@export var peek_distance: float = 100.0

## The speed at which the camera transitions between look positions.
@export var peek_smoothing: float = 10.0

## The action router to use for look inputs. 
var action_router: GameActionRouter2D

func _process(delta: float) -> void:
	if not is_current():
		return
	
	assert(action_router, "Action router not set")

	var target_offset: Vector2 = action_router.get_look_direction() * peek_distance
	offset = offset.lerp(target_offset, peek_smoothing * delta)
