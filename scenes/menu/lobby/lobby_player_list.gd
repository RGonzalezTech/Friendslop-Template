class_name LobbyPlayerList
extends VBoxContainer

## Sort children by peer_id

func _sort_children() -> void:
    var children = get_children()
    children.sort_custom(func(a, b):
        return (a.peer_id < b.peer_id)
    )
    for idx in range(children.size()):
        var this_child = children[idx]
        move_child(this_child, idx)

func _on_handshake_spawner_spawned(_node: LobbyPlayerRow, _request: SpawnRequest) -> void:
    _sort_children.call_deferred()

func _on_handshake_spawner_despawned(_s_id: String) -> void:
    _sort_children.call_deferred()
