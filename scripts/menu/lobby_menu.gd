extends Control

## UI Controller for the multiplayer lobby.
## Responsible for managing the negotiation phase (Ready status and Map Selection).
## This UI owns the "readiness" state as it is specific to the lobby menu context.

#region Constants & Enums

const PLAYER_ROW_SCENE = preload("res://scenes/ui/LobbyPlayerItem.tscn")
const NAME_CHANGE_POPUP_SCENE = preload("res://scenes/ui/NameChangePopup.tscn")

enum WorldMap {
	NONE,
	WORLD_2D,
	WORLD_3D
}

#endregion

#region Properties & Exports

## The currently selected map. Synced via MultiplayerSynchronizer.
@export var current_map: WorldMap = WorldMap.NONE:
	set(value):
		if value == current_map: return
		current_map = value
		_update_selected_map_ui.call_deferred()

## Truth for player readiness in this lobby session. Synced via MultiplayerSynchronizer.
@export var player_ready_states: Dictionary = {}:
	set(value):
		player_ready_states = value
		_update_all_ready_status.call_deferred()

#endregion

#region Node References

@onready var player_list = %PlayerList
@onready var start_button = %StartBtn
@onready var status_label = %StatusLabel
@onready var lobby_state_label = %LobbyStateLabel
@onready var lobby_map_label = %LobbyMapLabel
@onready var lobby_map_select = %LobbyMapSelect

#endregion

#region Internal Variables

var _spawned_player_rows: Dictionary = {} # [peer_id: int] -> LobbyPlayerItem
var _lobby_sync: MultiplayerSynchronizer

#endregion

#region Lifecycle

func _enter_tree() -> void:
	_setup_network_sync()
	
	# Listen to persistent game state from the LobbyManager
	LobbyManager.player_joined.connect(_on_player_joined)
	LobbyManager.player_left.connect(_on_player_left)
	LobbyManager.current_lobby.state_changed.connect(_update_lobby_state_ui)

func _ready() -> void:
	lobby_map_select.item_selected.connect(_on_map_selected)
	
	# Populate initial players already in the session
	for player in LobbyManager.get_all_players():
		_on_player_joined(player.peer_id)
	
	# Ensure the lobby state is set correctly by the host
	if multiplayer.is_server():
		LobbyManager.current_lobby.state = Lobby.State.LOBBY
	
	_update_buttons_ui()
	_update_selected_map_ui()
	_update_lobby_state_ui()

#endregion

#region Setup

func _setup_network_sync() -> void:
	_lobby_sync = MultiplayerSynchronizer.new()
	_lobby_sync.name = "LobbySync"
	_lobby_sync.root_path = get_path()
	
	_lobby_sync.add_visibility_filter(func(id):
		return LobbyManager.is_player_ready_for_gameplay(id)
	)

	# Configure replication for negotiation data
	var config = SceneReplicationConfig.new()
	config.add_property(NodePath(":current_map"))
	config.add_property(NodePath(":player_ready_states"))
	_lobby_sync.replication_config = config
	
	add_child(_lobby_sync)

#endregion

#region Lobby Events

## Adds a player row without rebuilding the entire list.
func _on_player_joined(peer_id: int) -> void:
	if _spawned_player_rows.has(peer_id): return
	
	var row = PLAYER_ROW_SCENE.instantiate()
	player_list.add_child(row)
	
	var player_node = LobbyManager.get_player(peer_id)
	if player_node:
		row.listen_for_updates(player_node)
	
	_spawned_player_rows[peer_id] = row
	
	# Use call_deferred to ensure the item node is ready before we update its labels
	_update_player_ready_status.call_deferred(peer_id)
	_update_player_count_label.call_deferred()

## Removes a player row gracefully.
func _on_player_left(peer_id: int) -> void:
	if _spawned_player_rows.has(peer_id):
		var row = _spawned_player_rows[peer_id]
		row.queue_free()
		_spawned_player_rows.erase(peer_id)
	
	if multiplayer.is_server():
		player_ready_states.erase(peer_id)
		_sync_ready_states()
	
	_update_player_count_label.call_deferred()

#endregion

#region UI Interaction

func _on_ready_btn_pressed() -> void:
	toggle_ready.rpc_id(1)

func _on_map_selected(index: int) -> void:
	current_map = index as WorldMap

func _on_start_btn_pressed() -> void:
	if not multiplayer.is_server(): return
	
	# Transition to loading state
	LobbyManager.current_lobby.state = Lobby.State.SERVER_LOADING
	
	# TODO: Logic to determine actual scene path based on selection
	LobbyManager.current_lobby.active_scene_path = "res://scenes/world/Map1.tscn"

func _on_leave_btn_pressed() -> void:
	SceneManager.go_to_main_menu()

func _on_change_name_btn_pressed() -> void:
	var local_player = LobbyManager.get_local_player()
	if not local_player: return
	
	var popup = NAME_CHANGE_POPUP_SCENE.instantiate()
	popup.name_submitted.connect(func(new_name):
		LobbyManager.update_player_name(new_name)
	)
	popup.popup_hide.connect(popup.queue_free)
	
	add_child(popup)
	popup.popup_with_name(local_player.player_name)

#endregion

#region UI Updates

func _update_buttons_ui() -> void:
	if not is_inside_tree(): return
	var is_host = multiplayer.is_server()
	start_button.visible = is_host
	lobby_map_select.visible = is_host
	lobby_map_label.visible = !is_host

func _update_lobby_state_ui() -> void:
	if not is_inside_tree() or not lobby_state_label: return
	var state = LobbyManager.current_lobby.state
	var state_name = Lobby.State.keys()[state]
	lobby_state_label.text = "State: %s" % state_name.capitalize()

func _update_selected_map_ui() -> void:
	if not is_inside_tree() or not lobby_map_label: return
	var map_name = WorldMap.keys()[current_map]
	lobby_map_label.text = "SELECTED MAP: %s" % map_name.capitalize()
	if multiplayer.is_server():
		lobby_map_select.selected = current_map

func _update_all_ready_status() -> void:
	for peer_id in _spawned_player_rows:
		_update_player_ready_status(peer_id)

func _update_player_ready_status(peer_id: int) -> void:
	if not _spawned_player_rows.has(peer_id): return
	
	var row = _spawned_player_rows[peer_id]
	# Safety check: if the item isn't ready yet, defer this specific update
	if not row.is_node_ready():
		_update_player_ready_status.call_deferred(peer_id)
		return
		
	var is_ready = player_ready_states.get(peer_id, false)
	row.set_ready_status(is_ready)

func _update_player_count_label() -> void:
	var count = _spawned_player_rows.size()
	if is_inside_tree() and status_label:
		status_label.text = "Waiting for players..." if count == 0 else "Connected: %d players" % count

#endregion

#region Networking

func _sync_ready_states() -> void:
	# Boilerplate to trigger Godot 4 MultiplayerSynchronizer setter for Dictionaries
	player_ready_states = player_ready_states

@rpc("any_peer", "call_local", "reliable")
func toggle_ready() -> void:
	if not multiplayer.is_server(): return
	var id = multiplayer.get_remote_sender_id()
	player_ready_states[id] = !player_ready_states.get(id, false)
	_sync_ready_states()

#endregion
