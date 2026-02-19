class_name HandshakeRetryTimer
extends Timer

## Emitted when the client should send a sync request RPC.
signal sync_requested()

## Emitted when the handshake is complete and the client is synced.
signal handshake_complete()

var _is_synced: bool = false

func _enter_tree() -> void:
    self.timeout.connect(_on_sync_timer_timeout)
    self.autostart = true
    self.one_shot = false
    self.wait_time = 0.25

## Call this when the server acknowledges the sync request.
func ack() -> void:
    _is_synced = true
    stop()
    handshake_complete.emit()

func _on_sync_timer_timeout() -> void:
    if _is_synced:
        stop()
        return

    sync_requested.emit()
