class_name InventoryTransfer
extends RefCounted
## Moves one existing ItemInstance between independent Inventories atomically.

var _errors: Array[String] = []


func transfer_item(source: Variant, destination: Variant, instance_id: String) -> bool:
	_errors.clear()
	if not source is Inventory:
		return _fail("source: expected Inventory")
	if not destination is Inventory:
		return _fail("destination: expected Inventory")
	if source == destination:
		return _fail("source and destination must be different Inventories")
	if not source.has_item(instance_id):
		return _fail("source does not contain instance_id '%s'" % instance_id)
	var item: ItemInstance = source.get_item(instance_id)
	if not is_instance_valid(item) or not item.is_valid():
		return _fail("source item '%s' is invalid" % instance_id)
	var source_weight: float = source.get_total_weight()
	if not is_finite(source_weight):
		return _fail("source Inventory is invalid: %s" % "; ".join(source.get_errors()))
	if not destination.can_add_item(item):
		return _fail("destination rejected '%s': %s" % [instance_id, "; ".join(destination.get_errors())])
	var removed: ItemInstance = source.remove_item(instance_id)
	if removed != item:
		return _fail("source changed while removing '%s'" % instance_id)
	if destination.add_item(item):
		return true

	var destination_reason := "; ".join(destination.get_errors())
	if not source.add_item(item):
		var rollback_reason := "; ".join(source.get_errors())
		var message := "[InventoryTransfer] Rollback failed for instance_id '%s' (source=%d, destination=%d): destination rejected item (%s); source rejected restoration (%s)" % [
			instance_id,
		source.get_instance_id(),
		destination.get_instance_id(),
		destination_reason,
		rollback_reason,
		]
		push_error(message)
		return _fail(message)
	return _fail("destination rejected '%s' after source removal: %s; source restored the original instance" % [instance_id, destination_reason])


func get_errors() -> Array[String]:
	return _errors.duplicate()


func _fail(message: String) -> bool:
	_errors.append(message)
	return false
