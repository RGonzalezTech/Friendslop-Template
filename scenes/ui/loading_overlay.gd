class_name LoadingOverlay
extends Control

## A full-screen UI overlay shown during scene transitions.
## Displays a "Loading..." message and tracks background loading progress.

@onready var _loading_label: Label = $LoadingText
var _current_tween: Tween

## Fades the overlay in to cover the screen.
func fade_in() -> void:
    _loading_label.text = "Loading..."
    if modulate.a > 0.99:
        return

    if _current_tween:
        _current_tween.stop()
    _current_tween = create_tween()
    _current_tween.tween_property(self, "modulate:a", 1.0, 0.2)
    await _current_tween.finished
    _current_tween = null

## Fades the overlay out to reveal the loaded scene.
func fade_out() -> void:
    if modulate.a < 0.01:
        return

    if _current_tween:
        _current_tween.stop()
    _current_tween = create_tween()
    _current_tween.tween_property(self, "modulate:a", 0.0, 0.2)
    await _current_tween.finished
    _current_tween = null

## Updates the loading text with a percentage based on [param progress] (0.0 to 1.0).
func update_progress(progress: float) -> void:
    _loading_label.text = "Loading: %d%%" % int(progress * 100)
