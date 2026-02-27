class_name BaseNetworkGutTest
extends GutTest

## This base class is responsible for providing a server & client network
## container in the same Scene Tree. 
##
## [IMPORTANT] Developers are expected to call `setup_server()` and 
## `setup_client()` manually within their test setup or test methods to 
## initialize the networking environment.
## 
## This allows us to test multiplayer functionality without needing to 
## run two separate instances of the game.

## The port used for running network tests
const NETWORK_TEST_PORT: int = 9001

## Add children to this node to run on the server-side
var _server_node: Node

## Add children to this node to run on the client-side
var _client_node: Node

func before_all() -> void:
	# Create parent nodes
	_server_node = Node.new()
	add_child(_server_node)
	_client_node = Node.new()
	add_child(_client_node)

func setup_server() -> void:
	assert(is_instance_valid(_server_node), "Server node must be initialized before calling setup_server.")
	
	# Setup server multiplayer
	var server_mp := SceneMultiplayer.new()
	get_tree().set_multiplayer(server_mp, _server_node.get_path())

	var server_peer = ENetMultiplayerPeer.new()
	server_peer.create_server(NETWORK_TEST_PORT)
	_server_node.multiplayer.multiplayer_peer = server_peer

func setup_client() -> void:
	assert(is_instance_valid(_client_node), "Client node must be initialized before calling setup_client.")
	
	# Setup client multiplayer
	var client_mp := SceneMultiplayer.new()
	get_tree().set_multiplayer(client_mp, _client_node.get_path())

	var client_peer = ENetMultiplayerPeer.new()
	client_peer.create_client("127.0.0.1", NETWORK_TEST_PORT)
	_client_node.multiplayer.multiplayer_peer = client_peer

func after_all() -> void:
	# Close connections
	if _client_node and _client_node.multiplayer.multiplayer_peer:
		_client_node.multiplayer.multiplayer_peer.close()
	if _server_node and _server_node.multiplayer.multiplayer_peer:
		_server_node.multiplayer.multiplayer_peer.close()

	# Remove nodes
	if _client_node:
		_client_node.queue_free()
	if _server_node:
		_server_node.queue_free()
