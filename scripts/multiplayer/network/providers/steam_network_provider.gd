extends BaseNetworkProvider
class_name SteamNetworkProvider

## Steam-based network provider (Skeleton).
## Intended for use with Steamworks/GodotSteam.
## 
## REQUIRES: A Steamworks wrapper for Godot (e.g., GodotSteam) to be integrated.
## The implementation should handle lobby creation, P2P handshake, and peer setup.

var lobby_id: int = 0
var steam_id: int = 0

func _init(p_lobby_id: int = 0) -> void:
	lobby_id = p_lobby_id

func host_game() -> void:
	# Logic for creating a Steam lobby and setting up peer would go here.
	connection_failed.emit("Steam host_game is not implemented.")

func join_game() -> void:
	# Logic for joining a Steam lobby would go here.
	connection_failed.emit("Steam join_game is not implemented.")

func get_class_name() -> String:
	return "SteamNetworkProvider"

func shutdown() -> void:
	# Logic for leaving Steam lobby/closing session would go here.
	pass
