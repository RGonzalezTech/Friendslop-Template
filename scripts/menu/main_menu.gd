extends Control

## UI Controller for the Main Menu.
## Serves as the entry point for hosting or joining multiplayer sessions.

@onready var join_ip_input: LineEdit = %JoinIP

func _ready() -> void:
	PeerManager.shutdown()
	
	if LobbyManager.disconnection_reason != "":
		_show_disconnection_dialog(LobbyManager.disconnection_reason)
	
	LobbyManager.reset_lobby()
	%StartGame.grab_focus()

	SceneManager.mark_scene_as_loaded(self)

func _on_start_game_pressed() -> void:
	PeerManager.set_provider(ENetNetworkProvider.new())
	PeerManager.host_game() # Note: Scene Syncing is handled by SceneManager

func _on_join_game_pressed() -> void:
	var ip = join_ip_input.text
	if ip.is_empty():
		ip = "127.0.0.1"
	
	PeerManager.set_provider(ENetNetworkProvider.new(ip))
	PeerManager.join_game() # Note: Scene Syncing is handled by SceneManager

func _on_quit_pressed() -> void:
	get_tree().quit()

func _show_disconnection_dialog(reason: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.dialog_text = reason
	dialog.title = "Disconnected"
	add_child(dialog)
	dialog.popup_centered()
	LobbyManager.disconnection_reason = ""