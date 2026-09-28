extends RefCounted
## Coordinates atomic use of one Inventory ItemInstance and its survival effects.

const InventoryType = preload("res://scripts/inventory/inventory.gd")
const ItemInstanceType = preload("res://scripts/items/item_instance.gd")

var _registry: WeakRef
var _errors: Array[String] = []


func _init(registry: Node) -> void:
	if is_instance_valid(registry):
		_registry = weakref(registry)


func use_item(inventory: Variant, survival_state: Variant, instance_id: String) -> bool:
	_errors.clear()
	var registry := _get_registry()
	if registry == null or not registry.is_loaded():
		return _fail("DataRegistry is unavailable or not ready")
	if not inventory is InventoryType:
		return _fail("inventory: expected a valid Inventory")
	if not survival_state is SurvivalState:
		return _fail("survival_state: expected a valid SurvivalState")
	if instance_id.strip_edges().is_empty():
		return _fail("instance_id: expected a non-empty string")
	if not survival_state.is_valid():
		return _fail("survival_state: current state is invalid")
	var inventory_weight: float = inventory.get_total_weight()
	if not is_finite(inventory_weight) or inventory_weight < 0.0:
		return _fail("inventory is invalid: %s" % "; ".join(inventory.get_errors()))
	var item: Variant = inventory.get_item(instance_id)
	if not is_instance_valid(item) or not item is ItemInstanceType or not item.is_valid():
		return _fail("unknown or invalid ItemInstance '%s'" % instance_id)
	var definition: Variant = registry.get_consumable_for_item(item.definition_id)
	if definition == null:
		return _fail("Item '%s' is not consumable" % item.definition_id)
	if not is_finite(definition.hunger_delta) or not is_finite(definition.thirst_delta):
		return _fail("Consumable '%s' has invalid non-finite effects" % definition.id)

	var previous_hunger: float = survival_state.get_hunger()
	var previous_thirst: float = survival_state.get_thirst()
	var removed: Variant = inventory.remove_item(instance_id)
	if removed != item:
		if removed != null and not inventory.add_item(removed):
			_report_rollback_failure(removed, inventory, "Inventory removed a different item and rejected its restoration")
		return _fail("Inventory changed while preparing to consume '%s'" % instance_id)
	var hunger_applied: bool = survival_state.modify_hunger(definition.hunger_delta)
	var thirst_applied: bool = hunger_applied and survival_state.modify_thirst(definition.thirst_delta)
	if not hunger_applied or not thirst_applied:
		return _rollback_use(inventory, survival_state, item, previous_hunger, previous_thirst,
			"SurvivalState rejected the Consumable effect")
	return true


func get_errors() -> Array[String]:
	return _errors.duplicate()


func _rollback_use(inventory: InventoryType, survival_state: SurvivalState, item: ItemInstanceType,
		previous_hunger: float, previous_thirst: float, reason: String) -> bool:
	var hunger_restored: bool = survival_state.set_hunger(previous_hunger)
	var thirst_restored: bool = survival_state.set_thirst(previous_thirst)
	var item_restored: bool = inventory.add_item(item)
	if not hunger_restored or not thirst_restored or not item_restored:
		var rollback_reason := "hunger restored=%s, thirst restored=%s, Inventory item restored=%s" % [hunger_restored, thirst_restored, item_restored]
		if not item_restored:
			rollback_reason += "; Inventory: " + "; ".join(inventory.get_errors())
		_report_rollback_failure(item, inventory, rollback_reason)
		return _fail("use failed and rollback was incomplete for '%s': %s" % [item.instance_id, rollback_reason])
	return _fail("use rolled back for '%s': %s" % [item.instance_id, reason])


func _report_rollback_failure(item: ItemInstanceType, inventory: InventoryType, reason: String) -> void:
	push_error("[ConsumableUseService] Rollback failed for instance_id '%s' (Inventory object %d): %s" % [item.instance_id, inventory.get_instance_id(), reason])


func _get_registry() -> Node:
	if _registry == null:
		return null
	return _registry.get_ref() as Node


func _fail(message: String) -> bool:
	_errors.append(message)
	return false
