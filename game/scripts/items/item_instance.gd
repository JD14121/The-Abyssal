class_name ItemInstance
extends RefCounted
## Identity and mutable condition only. Construct validated objects via ItemFactory.

const Validator = preload("res://scripts/items/item_instance_validator.gd")
const Definition = preload("res://scripts/data/definitions/item_definition.gd")

var _instance_id: String = ""
var _definition_id: StringName = &""
var _condition: float = 1.0
var _registry: WeakRef

var instance_id: String:
	get:
		return _instance_id
	set(_value):
		push_error("[ItemInstance] instance_id is read-only; create or restore through ItemFactory.")

var definition_id: StringName:
	get:
		return _definition_id
	set(_value):
		push_error("[ItemInstance] definition_id is read-only; create or restore through ItemFactory.")

var condition: float:
	get:
		return _condition
	set(value):
		set_condition(value)


func _init(registry: Node, identity: String, definition: StringName, initial_condition: float = 1.0) -> void:
	var errors: Array[String] = Validator.validate({
		"instance_id": identity, "definition_id": String(definition), "condition": initial_condition,
	}, registry)
	if not errors.is_empty():
		push_error("[ItemInstance] Cannot initialize: " + "; ".join(errors))
		return
	_registry = weakref(registry)
	_instance_id = identity
	_definition_id = definition
	_condition = initial_condition


func get_definition() -> Definition:
	var registry := _get_registry()
	if registry == null or not registry.is_loaded():
		return null
	return registry.get_item(_definition_id)


func is_valid() -> bool:
	return Validator.validate(_state(), _get_registry()).is_empty()


func set_condition(value: Variant) -> bool:
	if not Validator.valid_condition(value):
		push_error("[ItemInstance] %s | field condition: expected finite number in [0.0, 1.0], not bool" % _instance_id)
		return false
	_condition = float(value)
	return true


func serialize() -> Dictionary:
	var state := _state()
	var errors: Array[String] = Validator.validate(state, _get_registry())
	if not errors.is_empty():
		push_error("[ItemInstance] %s | Cannot serialize: %s" % [_instance_id, "; ".join(errors)])
		return {}
	return state


func _state() -> Dictionary:
	return {
		"instance_id": _instance_id,
		"definition_id": String(_definition_id),
		"condition": _condition,
	}


func _get_registry() -> Node:
	if _registry == null:
		return null
	return _registry.get_ref() as Node
