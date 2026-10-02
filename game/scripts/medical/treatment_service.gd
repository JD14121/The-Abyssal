extends RefCounted
## Applies one static Medical effect to one runtime Wound and consumes one Item.

const InventoryType = preload("res://scripts/inventory/inventory.gd")
const ItemInstanceType = preload("res://scripts/items/item_instance.gd")
const WoundStateType = preload("res://scripts/wounds/wound_state.gd")

var _registry: WeakRef
var _errors: Array[String] = []


func _init(registry: Node) -> void:
	if is_instance_valid(registry):
		_registry = weakref(registry)


func treat_wound(inventory: Variant, wound_component: Variant, instance_id: String, wound_id: String,
		infection_component: Variant = null) -> bool:
	_errors.clear()
	var registry := _get_registry()
	if registry == null or not registry.is_loaded():
		return _fail("DataRegistry is unavailable or not ready")
	if not inventory is InventoryType:
		return _fail("inventory: expected a valid Inventory")
	if not is_instance_valid(wound_component) or not wound_component is Node or not wound_component.has_method("get_wound"):
		return _fail("wound_component: expected a valid WoundComponent-like Node")
	if instance_id.strip_edges().is_empty() or wound_id.strip_edges().is_empty():
		return _fail("instance_id and wound_id must be non-empty")
	var weight: float = inventory.get_total_weight()
	if not is_finite(weight) or weight < 0.0:
		return _fail("inventory is invalid: %s" % "; ".join(inventory.get_errors()))
	var item: Variant = inventory.get_item(instance_id)
	if not is_instance_valid(item) or not item is ItemInstanceType or not item.is_valid():
		return _fail("unknown or invalid ItemInstance '%s'" % instance_id)
	var medical: Variant = registry.get_medical_for_item(item.definition_id)
	if medical == null:
		return _fail("Item '%s' has no Medical profile" % item.definition_id)
	var wound: Variant = wound_component.get_wound(wound_id)
	if not is_instance_valid(wound) or not wound is WoundStateType or not wound.is_valid():
		return _fail("unknown or invalid Wound '%s'" % wound_id)
	var treats_bleeding: bool = medical.bleeding_reduction_per_game_hour > 0.0 and wound.is_bleeding()
	var infection: Variant = infection_component.get_infection(wound_id) if is_instance_valid(infection_component) \
		and infection_component.has_method("get_infection") else null
	var treats_infection: bool = medical.infection_reduction_per_game_hour > 0.0 \
		and is_instance_valid(infection) and infection.is_infected()
	if not treats_bleeding and not treats_infection:
		return _fail("Wound '%s' has no condition treated by Item '%s'" % [wound_id, item.definition_id])

	var removed: Variant = inventory.remove_item(instance_id)
	if removed != item:
		if removed != null and not inventory.add_item(removed):
			_report_rollback_failure(removed, inventory, "Inventory removed a different ItemInstance and rejected restoration")
		return _fail("Inventory changed while preparing to treat Wound '%s'" % wound_id)
	var treated := false
	if treats_bleeding:
		treated = wound.reduce_bleeding(medical.bleeding_reduction_per_game_hour)
	elif treats_infection:
		treated = infection_component.treat_infection(wound_id, medical.infection_reduction_per_game_hour)
	if not treated:
		var restored: bool = inventory.add_item(item)
		if not restored:
			_report_rollback_failure(item, inventory, "Wound rejected treatment and Inventory rejected restoration")
			return _fail("treatment failed and rollback was incomplete for '%s'" % item.instance_id)
		return _fail("Wound '%s' rejected treatment; ItemInstance was restored" % wound_id)
	return true


func get_errors() -> Array[String]:
	return _errors.duplicate()


func _get_registry() -> Node:
	if _registry == null:
		return null
	return _registry.get_ref() as Node


func _report_rollback_failure(item: ItemInstanceType, inventory: InventoryType, reason: String) -> void:
	push_error("[TreatmentService] Rollback failed for instance_id '%s' (Inventory object %d): %s" % [item.instance_id, inventory.get_instance_id(), reason])


func _fail(message: String) -> bool:
	_errors.append(message)
	return false
