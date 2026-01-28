class_name PeerManagerCode
extends Node

## Abstracted manager for network peer creation and destruction.
## Supports ENet initially, but structured to allow other providers (Steam, etc).
## 
## Example:
## [code]
## PeerManager.set_provider(ENetNetworkProvider.new())
## PeerManager.host_game()
## PeerManager.join_game()
## PeerManager.shutdown()
## [/code]

## Emitted when a connection attempt begins.
signal connection_attempt_started

## Emitted when a connection is established (Server started, or client connected)
## We centralize the signal here so that other systems can handle their own logic
## when setting up or joining a game.
signal connection_established

## Emitted when a connection is shut down (Server stopped, or client disconnected)
## We centralize the signal here so that other systems can handle their own logic
## when leaving or ending a hosted game.
signal connection_shutdown(reason: String)

var _provider: BaseNetworkProvider

func _ready() -> void:
	# Automatically emit connection_established when the client connects to a server
	multiplayer.connected_to_server.connect(func(): connection_established.emit())
	multiplayer.server_disconnected.connect(func(): connection_shutdown.emit("Server disconnected."))
	multiplayer.connection_failed.connect(func(): connection_shutdown.emit("Connection failed."))

#region API

## Sets the active network provider.
func set_provider(provider: BaseNetworkProvider) -> void:
	if _provider == provider:
		return
		
	if _provider:
		_disconnect_provider_signals()
		shutdown()
		
	_provider = provider
	
	if _provider:
		_connect_provider_signals()

## Starts a server using the active provider.
func host_game() -> void:
	var host_action: Callable = _provider.host_game if _provider else Callable()
	_init_connection(host_action)

## Connects to a server using the active provider.
func join_game() -> void:
	var join_action: Callable = _provider.join_game if _provider else Callable()
	_init_connection(join_action)

## Destroys the current multiplayer peer and cleans up.
func shutdown() -> void:
	if _provider:
		_provider.shutdown()
		
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer = null

#endregion

#region Provider Signals

func _on_provider_connection_created(peer: MultiplayerPeer) -> void:
	multiplayer.multiplayer_peer = peer
	
	if multiplayer.is_server():
		# Starting a server does not automatically trigger the connected_to_server signal
		# so we emit it manually
		connection_established.emit()

func _on_provider_connection_failed(reason: String) -> void:
	connection_shutdown.emit(reason)

#endregion

#region Private Methods

# Wraps an anonymous function that relies on the provider to set the multiplayer peer
func _init_connection(provider_action: Callable) -> void:
	if not provider_action or not provider_action.is_valid():
		push_error("PeerManager: No valid provider provider_action set.")
		connection_shutdown.emit("No provider set.")
		return
	
	shutdown()
	connection_attempt_started.emit()
	provider_action.call()

func _connect_provider_signals() -> void:
	if not _provider:
		return
		
	_provider.connection_created.connect(_on_provider_connection_created)
	_provider.connection_failed.connect(_on_provider_connection_failed)

func _disconnect_provider_signals() -> void:
	if _provider.connection_created.is_connected(_on_provider_connection_created):
		_provider.connection_created.disconnect(_on_provider_connection_created)
	if _provider.connection_failed.is_connected(_on_provider_connection_failed):
		_provider.connection_failed.disconnect(_on_provider_connection_failed)

#endregion
