class_name SpawnableResource
extends Resource

## Abstract class for the implementation of a type of entity that can be spawned.
## Used by the [HandshakeSpawner] to maintain a separation of concerns between the spawner and the spawned entities.

## Responsible for creating a new instance of the entity.
func spawn(_params: Dictionary) -> Node:
    assert(false, "SpawnableResource: spawn() must be implemented")
    return Node.new()

## Responsible for cleaning up an instance of the entity.
## By default, this will queue_free() the node.
## Override this if you need special cleanup or pooling.
func teardown(node: Node) -> void:
    if is_instance_valid(node):
        node.queue_free()