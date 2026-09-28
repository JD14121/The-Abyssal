class_name PlayerInventoryComponent
extends Node
## Owns the Player's reusable Inventory and transfers existing ItemInstances.

const InventoryScript = preload("res://scripts/inventory/inventory.gd")
const WorldItemScript = preload("res://scripts/items/world_item.gd")

signal item_picked_up(instance_id: String)

@export var max_weight: float = 0.0
@export var world_item_scene: PackedScene

var _inventory: Inventory
var _errors: Array[String] = []


func _ready() -> void:
	var registry := get_tree().root.get_node_or_null("DataRegistry")
	if registry == null or not registry.is_loaded():
		_errors.append("DataRegistry is unavailable or not ready")
		return
	_inventory = InventoryScript.new(registry, max_weight)


func get_inventory() -> Inventory:
	return _inventory


func try_pickup_world_item(world_item: Variant) -> bool:
	_errors.clear()
	if _inventory == null:
		return _fail("Inventory is not ready")
	if not is_instance_valid(world_item) or not world_item.has_item():
		return _fail("WorldItem is invalid or empty")
	var item: ItemInstance = world_item.get_item()
	if not _inventory.add_item(item):
		return _fail("Inventory rejected item: %s" % "; ".join(_inventory.get_errors()))
	if world_item.take_item() != item:
		var restored := _inventory.remove_item(item.instance_id)
		if restored != item:
			push_error("[PlayerInventoryComponent] Pickup rollback failed for '%s'." % item.instance_id)
		return _fail("WorldItem changed during pickup")
	world_item.queue_free()
	item_picked_up.emit(item.instance_id)
	return true


func drop_item(instance_id: String, world_parent: Node, world_position: Vector2) -> bool:
	_errors.clear()
	if _inventory == null or not _inventory.has_item(instance_id):
		return _fail("Inventory does not contain instance_id '%s'" % instance_id)
	if not is_instance_valid(world_parent) or not world_parent.is_inside_tree():
		return _fail("world_parent must be a valid node inside the SceneTree")
	if not is_finite(world_position.x) or not is_finite(world_position.y):
		return _fail("world_position must contain finite coordinates")
	if world_item_scene == null:
		return _fail("world_item_scene is not configured")
	var world_node := world_item_scene.instantiate()
	if not world_node is WorldItemScript:
		if is_instance_valid(world_node):
			world_node.free()
		return _fail("world_item_scene root must use WorldItem")
	var world_item: Variant = world_node
	var item: ItemInstance = _inventory.get_item(instance_id)
	if not is_instance_valid(item) or not item.is_valid():
		world_item.free()
		return _fail("Inventory item '%s' is invalid" % instance_id)
	var removed := _inventory.remove_item(instance_id)
	if removed != item:
		world_item.free()
		return _fail("Inventory changed while preparing drop")
	if not world_item.initialize(item):
		world_item.free()
		return _restore_after_failed_drop(item, "WorldItem rejected ItemInstance initialization")
	world_parent.add_child(world_item)
	if world_item.get_parent() != world_parent or not is_instance_valid(world_item):
		if is_instance_valid(world_item):
			world_item.free()
		return _restore_after_failed_drop(item, "WorldItem could not be added to world_parent")
	world_item.global_position = world_position
	return true


func get_errors() -> Array[String]:
	return _errors.duplicate()


func _restore_after_failed_drop(item: ItemInstance, reason: String) -> bool:
	if not _inventory.add_item(item):
		push_error("[PlayerInventoryComponent] Drop rollback failed for '%s': %s | %s" % [item.instance_id, reason, "; ".join(_inventory.get_errors())])
		return _fail("%s; rollback failed for '%s'" % [reason, item.instance_id])
	return _fail(reason)


func _fail(message: String) -> bool:
	_errors.append(message)
	return false
