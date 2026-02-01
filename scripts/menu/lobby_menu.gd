extends Control

## UI Controller for the multiplayer lobby.
## Handles displaying the list of players, ready status, and allows the host to start the game.

const PLAYER_ITEM_SCENE = preload("res://scenes/ui/LobbyPlayerItem.tscn")
const NAME_CHANGE_POPUP_SCENE = preload("res://scenes/ui/NameChangePopup.tscn")

@onready var player_list = %PlayerList
@onready var start_button = %StartBtn
@onready var status_label = %StatusLabel
@onready var lobby_state_label = %LobbyStateLabel


func _ready() -> void:
	LobbyManager.player_joined.connect(func(_id: int): _update_lobby_ui.call_deferred())
	LobbyManager.player_left.connect(func(_id: int): _update_lobby_ui.call_deferred())
	LobbyManager.current_lobby.state_changed.connect(func(): _update_lobby_ui.call_deferred())

	LobbyManager.current_lobby.state = Lobby.State.LOBBY
	_update_lobby_ui()
	
	# Only host can start
	start_button.visible = multiplayer.is_server()

	SceneManager.mark_scene_as_loaded(self)

func _update_lobby_ui() -> void:
	# 1. Clear existing items
	for child in player_list.get_children():
		child.queue_free()
	
	var all_players = LobbyManager.get_all_players()
	
	# 2. Add items for current players
	for p_node in all_players:
		var item = PLAYER_ITEM_SCENE.instantiate()
		player_list.add_child(item)
		item.listen_for_updates(p_node)
	
	# 3. Update status label
	if all_players.is_empty():
		status_label.text = "Waiting for players..."
	else:
		status_label.text = "Connected: %d players" % all_players.size()
	
	# 4. Update lobby state label
	var current_state = LobbyManager.current_lobby.state
	var state_name = Lobby.State.keys()[current_state]
	lobby_state_label.text = "State: %s" % state_name.capitalize()

func _on_ready_btn_pressed() -> void:
	LobbyManager.toggle_ready()

func _on_change_name_btn_pressed() -> void:
	var local_player = LobbyManager.get_local_player()
	if not local_player: return
	
	var popup = NAME_CHANGE_POPUP_SCENE.instantiate()
	
	# Subscribe to signals BEFORE adding as child
	popup.name_submitted.connect(func(new_name):
		LobbyManager.update_player_name(new_name)
	)
	popup.popup_hide.connect(popup.queue_free)
	
	add_child(popup)
	popup.popup_with_name(local_player.player_name)

func _on_start_btn_pressed() -> void:
	if not multiplayer.is_server():
		return
	
	# Load the game map (SceneManager handles the actual loading)
	LobbyManager.current_lobby.state = Lobby.State.SERVER_LOADING
	LobbyManager.current_lobby.active_scene_path = "res://scenes/world/Map1.tscn"

func _on_leave_btn_pressed() -> void:
	SceneManager.go_to_main_menu()
