class_name InjuryState
extends RefCounted
## Injury severity, pain, fracture and slow recovery for one Wound identity.

var wound_id: String
var severity: float
var _pain: float
var _fracture: bool
var _healing_progress := 0.0


func _init(target_wound_id: String, initial_severity: float, initial_pain: float,
		fracture: bool = false) -> void:
	wound_id = target_wound_id
	severity = initial_severity
	_pain = initial_pain
	_fracture = fracture


func is_valid() -> bool:
	return not wound_id.is_empty() and is_finite(severity) and severity >= 0.0 and severity <= 10.0 \
		and is_finite(_pain) and _pain >= 0.0 and _pain <= 100.0 \
		and is_finite(_healing_progress) and _healing_progress >= 0.0 and _healing_progress <= 100.0


func is_fracture() -> bool:
	return _fracture


func get_pain() -> float:
	return _pain


func get_healing_progress() -> float:
	return _healing_progress


func get_movement_multiplier() -> float:
	var penalty := severity * 0.035 + (0.3 if _fracture else 0.0)
	return clampf(1.0 - penalty, 0.35, 1.0)


func reduce_pain(amount: float) -> bool:
	if not is_valid() or not is_finite(amount) or amount <= 0.0:
		return false
	_pain = maxf(0.0, _pain - amount)
	return true


func advance_game_time(game_seconds: float) -> bool:
	if not is_valid() or not is_finite(game_seconds) or game_seconds < 0.0:
		return false
	var hours := game_seconds / 3600.0
	_pain = maxf(0.0, _pain - 10.0 * hours)
	_healing_progress = minf(100.0, _healing_progress + hours * (0.005 if _fracture else 0.02))
	if _healing_progress >= 100.0:
		_fracture = false
		severity = maxf(0.0, severity - 1.0)
		_healing_progress = 0.0
	return true
