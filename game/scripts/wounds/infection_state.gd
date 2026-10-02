class_name InfectionState
extends RefCounted
## Per-Wound contamination progression and treatment state.

const INFECTION_THRESHOLD := 10.0
const MAX_LEVEL := 100.0

var wound_id: String
var contamination_risk: float
var progression_per_game_hour: float
var _level := 0.0


func _init(target_wound_id: String, risk: float, progression: float) -> void:
	wound_id = target_wound_id
	contamination_risk = risk
	progression_per_game_hour = progression


func is_valid() -> bool:
	return not wound_id.is_empty() and is_finite(contamination_risk) and contamination_risk >= 0.0 \
		and contamination_risk <= 1.0 and is_finite(progression_per_game_hour) \
		and progression_per_game_hour >= 0.0 and is_finite(_level) and _level >= 0.0 and _level <= MAX_LEVEL


func advance_game_time(game_seconds: float) -> bool:
	if not is_valid() or not is_finite(game_seconds) or game_seconds < 0.0:
		return false
	_level = minf(MAX_LEVEL, _level + game_seconds / 3600.0 * contamination_risk * progression_per_game_hour)
	return true


func reduce(amount: float) -> bool:
	if not is_valid() or not is_finite(amount) or amount <= 0.0:
		return false
	_level = maxf(0.0, _level - amount)
	return true


func get_level() -> float:
	return _level


func is_infected() -> bool:
	return _level >= INFECTION_THRESHOLD


func get_health_loss_per_game_hour() -> float:
	return maxf(0.0, _level - INFECTION_THRESHOLD) * 0.01
