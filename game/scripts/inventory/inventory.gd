class_name Inventory
extends RefCounted
## Holds ItemInstance references and serializes only runtime inventory state.

const ItemFactoryType = preload("res://scripts/items/item_factory.gd")
const CAPACITY_EPSILON := 0.000001

var _registry: WeakRef
var _max_weight: float = 0.0
var _configuration_valid: bool = true
var _items: Array[ItemInstance] = []
var _item_index: Dictionary[String, ItemInstance] = {}
var _errors: Array[String] = []

var max_weight: float:
	get:
		return _max_weight


func _init(registry: Node, capacity: Variant = 0.0) -> void:
	if is_instance_valid(registry):
		_registry = weakref(registry)
	if not _is_valid_capacity(capacity):
		_configuration_valid = false
		_errors.append("max_weight: expected finite number >= 0 (0 means unlimited)")
		return
	_max_weight = float(capacity)


func add_item(value: Variant) -> bool:
	_errors.clear()
	if not _validate_add_item(value):
		return false
	var item := value as ItemInstance
	var instance_id := item.instance_id
	_items.append(item)
	_item_index[instance_id] = item
	return true


func can_add_item(value: Variant) -> bool:
	_errors.clear()
	return _validate_add_item(value)


func remove_item(instance_id: String) -> ItemInstance:
	_errors.clear()
	if not _item_index.has(instance_id):
		return null
	var item: ItemInstance = _item_index[instance_id]
	_item_index.erase(instance_id)
	_items.erase(item)
	return item


func has_item(instance_id: String) -> bool:
	return _item_index.has(instance_id)


func get_item(instance_id: String) -> ItemInstance:
	return _item_index.get(instance_id)


func get_all_items() -> Array[ItemInstance]:
	return _items.duplicate()


func get_item_count() -> int:
	return _items.size()


func get_total_weight() -> float:
	_errors.clear()
	if not _configuration_valid:
		_fail("inventory: invalid construction settings")
		return NAN
	return _calculate_total_weight()


func serialize() -> Dictionary:
	_errors.clear()
	if not _configuration_valid:
		_fail("inventory: invalid construction settings")
		return {}
	var weight := _calculate_total_weight()
	if is_nan(weight):
		return {}
	var records: Array[Dictionary] = []
	for index in range(_items.size()):
		var record := _items[index].serialize()
		if record.is_empty():
			_fail("items[%d]: ItemInstance could not serialize" % index)
			return {}
		records.append(record)
	return {"max_weight": _max_weight, "items": records}


func deserialize(data: Variant, item_factory: Variant) -> bool:
	_errors.clear()
	if not _configuration_valid:
		return _fail("inventory: invalid construction settings")
	if not data is Dictionary:
		return _fail("root: expected an Inventory Dictionary")
	if not item_factory is ItemFactoryType:
		return _fail("item_factory: expected ItemFactory")
	for field in data:
		if not field is String or field not in ["max_weight", "items"]:
			return _fail("field %s: unsupported Inventory field" % str(field))
	if not data.has("max_weight"):
		return _fail("field max_weight: missing required field")
	if not data.has("items"):
		return _fail("field items: missing required field")
	if not _is_valid_capacity(data.max_weight):
		return _fail("field max_weight: expected finite number >= 0")
	if not data.items is Array:
		return _fail("field items: expected Array")
	var registry := _get_registry()
	if registry == null or not registry.is_loaded():
		return _fail("registry: unavailable or not ready")

	var restored_items: Array[ItemInstance] = []
	var restored_index: Dictionary[String, ItemInstance] = {}
	var restored_weight := 0.0
	for index in range(data.items.size()):
		var record: Variant = data.items[index]
		if record is Dictionary and record.get("instance_id") is String:
			var restored_id: String = record.instance_id
			if restored_index.has(restored_id):
				return _fail("items[%d]: duplicate instance_id '%s'" % [index, restored_id])
		var item: Variant = item_factory.deserialize(record)
		if item == null:
			var factory_errors: Array[String] = item_factory.get_errors()
			var reason := "; ".join(factory_errors)
			return _fail("items[%d]: ItemFactory rejected record: %s" % [index, reason])
		var item_mass := _get_item_mass(item, "items[%d]" % index)
		if is_nan(item_mass):
			return false
		restored_weight += item_mass
		var restored_id: String = item.instance_id
		if restored_index.has(restored_id):
			return _fail("items[%d]: duplicate instance_id '%s'" % [index, restored_id])
		restored_items.append(item)
		restored_index[restored_id] = item
	var restored_capacity := float(data.max_weight)
	if restored_capacity > 0.0 and restored_weight > restored_capacity + CAPACITY_EPSILON:
		return _fail("capacity exceeded while restoring: %.6f > %.6f" % [restored_weight, restored_capacity])

	# Publish only after every record, identity, definition and capacity is valid.
	_items = restored_items
	_item_index = restored_index
	_max_weight = restored_capacity
	return true


func get_errors() -> Array[String]:
	return _errors.duplicate()


func _validate_add_item(value: Variant) -> bool:
	if not _configuration_valid:
		return _fail("inventory: invalid construction settings")
	if not value is ItemInstance:
		return _fail("item: expected a valid ItemInstance")
	var item := value as ItemInstance
	if not item.is_valid():
		return _fail("item: ItemInstance is invalid")
	var instance_id := item.instance_id
	if _item_index.has(instance_id):
		return _fail("duplicate instance_id: %s" % instance_id)
	var item_mass := _get_item_mass(item, "item '%s'" % instance_id)
	if is_nan(item_mass):
		return false
	var current_weight := _calculate_total_weight()
	if is_nan(current_weight):
		return false
	if _max_weight > 0.0 and current_weight + item_mass > _max_weight + CAPACITY_EPSILON:
		return _fail("capacity exceeded: %.6f + %.6f > %.6f" % [current_weight, item_mass, _max_weight])
	return true


func _calculate_total_weight() -> float:
	var total := 0.0
	for item in _items:
		if not is_instance_valid(item):
			_fail("item: Inventory contains an invalid ItemInstance")
			return NAN
		var item_mass := _get_item_mass(item, "item '%s'" % item.instance_id)
		if is_nan(item_mass):
			return NAN
		if not item.is_valid():
			_fail("item '%s': ItemInstance is invalid" % item.instance_id)
			return NAN
		total += item_mass
	return total


func _get_item_mass(item: ItemInstance, context: String) -> float:
	var registry := _get_registry()
	if registry == null or not registry.is_loaded():
		_fail("%s: DataRegistry is unavailable or not ready" % context)
		return NAN
	var definition = registry.get_item(item.definition_id)
	if definition == null:
		_fail("%s: unknown item definition '%s'" % [context, item.definition_id])
		return NAN
	if not is_finite(definition.mass) or definition.mass < 0.0:
		_fail("%s: invalid mass for item definition '%s'" % [context, item.definition_id])
		return NAN
	return definition.mass


func _get_registry() -> Node:
	if _registry == null:
		return null
	return _registry.get_ref() as Node


func _is_valid_capacity(value: Variant) -> bool:
	if not (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT):
		return false
	return is_finite(float(value)) and value >= 0.0


func _fail(message: String) -> bool:
	_errors.append(message)
	return false
