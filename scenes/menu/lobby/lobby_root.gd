class_name LobbyRoot
extends Control

## UI Controller for the multiplayer lobby.
## Responsible for managing the negotiation phase (Ready status and Map Selection).
## This UI owns the "readiness" state as it is specific to the lobby menu context.

#region Properties & Exports

#endregion

#region Node References

@onready var start_button = %StartBtn
@onready var lobby_state_label = %LobbyStateLabel
#endregion

#region Lifecycle

func _enter_tree() -> void:
	LobbyManager.current_lobby.state_changed.connect(_update_lobby_state_ui)

func _ready() -> void:
	# Ensure the lobby state is set correctly by the host
	if multiplayer.is_server():
		LobbyManager.current_lobby.state = Lobby.State.LOBBY
	
	_update_buttons_ui()
	_update_lobby_state_ui()

#endregion

#region UI Interaction

func _on_start_btn_pressed() -> void:
	if not multiplayer.is_server(): return
	
	# Transition to loading state
	LobbyManager.current_lobby.state = Lobby.State.SERVER_LOADING
	LobbyManager.current_lobby.active_scene_path = "res://scenes/level/2d/Demo2DMap.tscn"

#endregion

#region UI Drawing

func _update_buttons_ui() -> void:
	if not is_inside_tree(): return
	var is_host = multiplayer.is_server()
	start_button.visible = is_host

func _update_lobby_state_ui() -> void:
	if not is_inside_tree() or not lobby_state_label: return
	var state = LobbyManager.current_lobby.state
	var state_name = Lobby.State.keys()[state]
	lobby_state_label.text = "State: %s" % state_name.capitalize()

#endregion