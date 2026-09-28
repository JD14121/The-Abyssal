class_name ContainerLootPopulator
extends RefCounted
## Atomically adds resolved loot to one Inventory, preserving its prior contents.

const InventoryType = preload("res://scripts/inventory/inventory.gd")
const ResolverType = preload("res://scripts/loot/loot_resolver.gd")
const CAPACITY_EPSILON := 0.000001

var _resolver: ResolverType
var _errors: Array[String] = []


func _init(resolver: ResolverType) -> void:
	_resolver = resolver


func populate(inventory: Variant, loot_id: StringName, rng: RandomNumberGenerator) -> bool:
	_errors.clear()
	if not inventory is InventoryType:
		return _fail("inventory: expected Inventory")
	if not _resolver is ResolverType:
		return _fail("resolver: expected LootResolver")
	var resolution: Dictionary = _resolver.resolve(loot_id, rng)
	if not resolution.ok:
		return _fail("loot resolution failed: %s" % "; ".join(resolution.errors))
	var items: Array = resolution.items
	if items.is_empty():
		return true
	var prior_weight: float = inventory.get_total_weight()
	if not is_finite(prior_weight):
		return _fail("inventory is invalid: %s" % "; ".join(inventory.get_errors()))
	var combined_weight := prior_weight
	var known_ids := {}
	for existing in inventory.get_all_items():
		known_ids[existing.instance_id] = true
	for index in range(items.size()):
		var item: Variant = items[index]
		if not item is ItemInstance or not item.is_valid():
			return _fail("generated items[%d]: expected valid ItemInstance" % index)
		if known_ids.has(item.instance_id):
			return _fail("generated items[%d]: duplicate instance_id '%s'" % [index, item.instance_id])
		known_ids[item.instance_id] = true
		if not inventory.can_add_item(item):
			return _fail("generated items[%d] rejected: %s" % [index, "; ".join(inventory.get_errors())])
		var item_definition: Variant = item.get_definition()
		if item_definition == null:
			return _fail("generated items[%d]: ItemDefinition is unavailable" % index)
		combined_weight += item_definition.mass
		if not is_finite(combined_weight):
			return _fail("generated items[%d]: combined mass is not finite" % index)
	if inventory.max_weight > 0.0 and combined_weight > inventory.max_weight + CAPACITY_EPSILON:
		return _fail("capacity exceeded: %.6f > %.6f" % [combined_weight, inventory.max_weight])

	var added_ids: Array[String] = []
	for item in items:
		if not inventory.add_item(item):
			var reason := "; ".join(inventory.get_errors())
			var rollback_failures: Array[String] = []
			for instance_id in added_ids:
				if inventory.remove_item(instance_id) == null:
					rollback_failures.append(instance_id)
			if rollback_failures.is_empty():
				return _fail("add failed; this population was rolled back: %s" % reason)
			return _fail("add failed (%s); rollback could not remove new IDs: %s" % [reason, ", ".join(rollback_failures)])
		added_ids.append(item.instance_id)
	return true


func get_errors() -> Array[String]:
	return _errors.duplicate()


func _fail(message: String) -> bool:
	_errors.append(message)
	return false
