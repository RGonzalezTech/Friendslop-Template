extends PopupPanel
## A popup dialog for players to change their display name.

## Emitted when the user confirms a new name.
signal name_submitted(new_name: String)

## UI components found via unique names
@onready var name_input: LineEdit = %NameInput
@onready var confirm_btn: Button = %ConfirmBtn
@onready var cancel_btn: Button = %CancelBtn

func _ready() -> void:
	# Connect signals for confirmation and cancellation
	confirm_btn.pressed.connect(_on_confirm_pressed)
	cancel_btn.pressed.connect(_on_cancel_pressed)
	
	# Allow pressing Enter in the text field to submit the name
	name_input.text_submitted.connect(func(_text): _on_confirm_pressed())

## Opens the popup and initializes it with the current name.
## Highlights the text for quick over-typing.
func popup_with_name(current_name: String) -> void:
	name_input.text = current_name
	popup_centered()
	name_input.grab_focus()
	name_input.select_all()

## Handles the confirm button press or Enter key submission.
## Trims whitespace and emits name_submitted if valid.
func _on_confirm_pressed() -> void:
	var new_name = name_input.text.strip_edges()
	
	# Only emit if the name is not whitespace-only
	if not new_name.is_empty():
		name_submitted.emit(new_name)
	
	hide()

## Handles the cancel button press, simply closing the popup.
func _on_cancel_pressed() -> void:
	hide()
