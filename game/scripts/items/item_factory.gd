class_name ItemFactory
extends RefCounted
## Explicitly create a new identity or restore an existing one; no world ownership.

const RuntimeItem = preload("res://scripts/items/item_instance.gd")
const Validator = preload("res://scripts/items/item_instance_validator.gd")

var _registry: WeakRef
var _crypto := Crypto.new()
var _errors: Array[String] = []


func _init(registry: Node) -> void:
	if is_instance_valid(registry):
		_registry = weakref(registry)


func create(definition_id: StringName) -> RuntimeItem:
	return create_with_condition(definition_id, 1.0)


func create_with_condition(definition_id: StringName, initial_condition: Variant) -> RuntimeItem:
	var registry := _get_registry()
	_errors = Validator.definition_errors(definition_id, registry)
	if not Validator.valid_condition(initial_condition):
		_errors.append("field condition: expected finite number in [0.0, 1.0], not bool")
	if not _errors.is_empty():
		_report_errors("create '%s'" % definition_id)
		return null
	var identity := _new_instance_id()
	if identity.is_empty():
		_errors.append("instance_id: random byte generation failed")
		_report_errors("create '%s'" % definition_id)
		return null
	return RuntimeItem.new(registry, identity, definition_id, float(initial_condition))


func deserialize(data: Variant) -> RuntimeItem:
	var registry := _get_registry()
	_errors = Validator.validate(data, registry)
	if not _errors.is_empty():
		_report_errors("deserialize")
		return null
	# Restoration preserves the supplied identity; it never calls the ID generator.
	return RuntimeItem.new(registry, data.instance_id, StringName(data.definition_id), float(data.condition))


func get_errors() -> Array[String]:
	return _errors.duplicate()


func _new_instance_id() -> String:
	var bytes := _crypto.generate_random_bytes(16)
	if bytes.size() != 16:
		return ""
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]


func _get_registry() -> Node:
	if _registry == null:
		return null
	return _registry.get_ref() as Node


func _report_errors(operation: String) -> void:
	for message in _errors:
		push_error("[ItemFactory] %s | %s" % [operation, message])
