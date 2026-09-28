class_name SurvivalState
extends RefCounted
## Per-entity needs and health. This value object has no scene or world dependency.

const MIN_VALUE := 0.0
const MAX_VALUE := 100.0
const SAVE_KEYS := [&"health", &"hunger", &"thirst"]

var _health: float = MAX_VALUE
var _hunger: float = MIN_VALUE
var _thirst: float = MIN_VALUE


func get_health() -> float:
	return _health


func get_hunger() -> float:
	return _hunger


func get_thirst() -> float:
	return _thirst


func set_health(value: float) -> bool:
	if not _is_finite(value):
		return false
	_health = clampf(value, MIN_VALUE, MAX_VALUE)
	return true


func set_hunger(value: float) -> bool:
	if not _is_finite(value):
		return false
	_hunger = clampf(value, MIN_VALUE, MAX_VALUE)
	return true


func set_thirst(value: float) -> bool:
	if not _is_finite(value):
		return false
	_thirst = clampf(value, MIN_VALUE, MAX_VALUE)
	return true


func modify_hunger(delta: float) -> bool:
	if not _is_finite(delta):
		return false
	return set_hunger(_hunger + delta)


func modify_thirst(delta: float) -> bool:
	if not _is_finite(delta):
		return false
	return set_thirst(_thirst + delta)


func is_valid() -> bool:
	return _is_valid_current_value(_health) and _is_valid_current_value(_hunger) and _is_valid_current_value(_thirst)


func serialize() -> Dictionary:
	return {"health": _health, "hunger": _hunger, "thirst": _thirst}


func deserialize(data: Dictionary) -> bool:
	if data.size() != SAVE_KEYS.size():
		return false
	for key: StringName in SAVE_KEYS:
		if not data.has(key):
			return false
	var health_value: Variant = data[&"health"]
	var hunger_value: Variant = data[&"hunger"]
	var thirst_value: Variant = data[&"thirst"]
	if not _is_valid_saved_value(health_value) or not _is_valid_saved_value(hunger_value) or not _is_valid_saved_value(thirst_value):
		return false
	_health = float(health_value)
	_hunger = float(hunger_value)
	_thirst = float(thirst_value)
	return true


func _is_valid_saved_value(value: Variant) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	var number := float(value)
	return _is_finite(number) and number >= MIN_VALUE and number <= MAX_VALUE


func _is_valid_current_value(value: float) -> bool:
	return _is_finite(value) and value >= MIN_VALUE and value <= MAX_VALUE


func _is_finite(value: float) -> bool:
	return is_finite(value)
