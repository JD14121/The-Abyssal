extends Node
## Shared logical world clock. Runtime time is serialized independently from wall time.

const SAVE_KEYS := [&"elapsed_game_seconds", &"time_scale", &"paused"]

var _elapsed_game_seconds: float = 0.0
var _time_scale: float = 1.0
var _paused: bool = false


func _process(real_delta_seconds: float) -> void:
	advance(real_delta_seconds)


func advance(real_delta_seconds: float) -> bool:
	if not _is_finite_non_negative(real_delta_seconds):
		return false
	if _paused or _time_scale == 0.0 or real_delta_seconds == 0.0:
		return true
	var game_delta := real_delta_seconds * _time_scale
	if not _is_finite_non_negative(game_delta) or not _is_finite_non_negative(_elapsed_game_seconds + game_delta):
		return false
	_elapsed_game_seconds += game_delta
	return true


func get_elapsed_game_seconds() -> float:
	return _elapsed_game_seconds


func set_time_scale(value: float) -> bool:
	if not _is_finite_non_negative(value):
		return false
	_time_scale = value
	return true


func get_time_scale() -> float:
	return _time_scale


func set_paused(value: bool) -> bool:
	_paused = value
	return true


func is_paused() -> bool:
	return _paused


func serialize() -> Dictionary:
	return {
		"elapsed_game_seconds": _elapsed_game_seconds,
		"time_scale": _time_scale,
		"paused": _paused,
	}


func deserialize(data: Dictionary) -> bool:
	if data.size() != SAVE_KEYS.size():
		return false
	for key: StringName in SAVE_KEYS:
		if not data.has(key):
			return false
	var elapsed: Variant = data[&"elapsed_game_seconds"]
	var scale: Variant = data[&"time_scale"]
	var paused_value: Variant = data[&"paused"]
	if typeof(elapsed) not in [TYPE_INT, TYPE_FLOAT] or typeof(scale) not in [TYPE_INT, TYPE_FLOAT] or typeof(paused_value) != TYPE_BOOL:
		return false
	var elapsed_float := float(elapsed)
	var scale_float := float(scale)
	if not _is_finite_non_negative(elapsed_float) or not _is_finite_non_negative(scale_float):
		return false
	_elapsed_game_seconds = elapsed_float
	_time_scale = scale_float
	_paused = paused_value
	return true


func _is_finite_non_negative(value: float) -> bool:
	return is_finite(value) and value >= 0.0
