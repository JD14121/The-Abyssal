class_name LootResolver
extends RefCounted
## Converts one registered LootDefinition into newly-created ItemInstances.

const FactoryType = preload("res://scripts/items/item_factory.gd")

var _registry: WeakRef
var _item_factory: FactoryType
var _errors: Array[String] = []


func _init(registry: Node, item_factory: FactoryType) -> void:
	if is_instance_valid(registry):
		_registry = weakref(registry)
	_item_factory = item_factory


func resolve(loot_id: StringName, rng: RandomNumberGenerator) -> Dictionary:
	_errors.clear()
	var registry := _get_registry()
	if registry == null or not registry.is_loaded():
		return _fail("DataRegistry is unavailable or not ready")
	if rng == null:
		return _fail("rng: expected RandomNumberGenerator")
	var definition = registry.get_loot(loot_id)
	if definition == null:
		return _fail("unknown loot ID '%s'" % loot_id)
	if not _item_factory is FactoryType:
		return _fail("item_factory: expected ItemFactory")
	var generated: Array[ItemInstance] = []
	if definition.rolls == 0 or definition.entries.is_empty():
		return {"ok": true, "items": generated, "errors": []}
	for roll_index in range(definition.rolls):
		var entry = _select_entry(definition.entries, rng)
		if entry == null:
			return _fail("loot '%s' roll %d: weighted selection failed" % [loot_id, roll_index])
		if entry.chance <= 0.0:
			continue
		if entry.chance < 1.0 and rng.randf() >= entry.chance:
			continue
		var quantity: int = entry.min_quantity
		if entry.max_quantity > entry.min_quantity:
			quantity = rng.randi_range(entry.min_quantity, entry.max_quantity)
		for item_index in range(quantity):
			var item: ItemInstance = _item_factory.create(entry.item_id)
			if item == null or not item.is_valid():
				var reason := "; ".join(_item_factory.get_errors())
				if reason.is_empty():
					reason = "ItemFactory returned a null or invalid instance"
				return _fail("loot '%s' roll %d item %d creation failed: %s" % [loot_id, roll_index, item_index, reason])
			generated.append(item)
	return {"ok": true, "items": generated, "errors": []}


func get_errors() -> Array[String]:
	return _errors.duplicate()


func _select_entry(entries: Array, rng: RandomNumberGenerator) -> Variant:
	var total_weight := 0.0
	for entry in entries:
		total_weight += entry.weight
	if not is_finite(total_weight) or total_weight <= 0.0:
		return null
	var selected_weight := rng.randf() * total_weight
	var cumulative := 0.0
	for entry in entries:
		cumulative += entry.weight
		if selected_weight < cumulative:
			return entry
	return entries.back()


func _get_registry() -> Node:
	if _registry == null:
		return null
	return _registry.get_ref() as Node


func _fail(message: String) -> Dictionary:
	_errors.append(message)
	return {"ok": false, "items": [], "errors": _errors.duplicate()}
