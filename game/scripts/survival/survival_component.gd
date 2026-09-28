extends Node
## Advances the owning entity's needs from shared game time.

const SurvivalStateScript = preload("res://scripts/survival/survival_state.gd")

@export_range(0.0, 1000.0, 0.1, "or_greater") var hunger_per_game_hour: float = 1.0
@export_range(0.0, 1000.0, 0.1, "or_greater") var thirst_per_game_hour: float = 2.0

var state = SurvivalStateScript.new()
var _last_clock_seconds: float = 0.0


func _ready() -> void:
	_last_clock_seconds = GameClock.get_elapsed_game_seconds()


func _process(_delta: float) -> void:
	var current_seconds: float = GameClock.get_elapsed_game_seconds()
	var elapsed := current_seconds - _last_clock_seconds
	_last_clock_seconds = current_seconds
	if elapsed > 0.0:
		advance_game_time(elapsed)


func advance_game_time(game_seconds: float) -> bool:
	if not is_finite(game_seconds) or game_seconds < 0.0:
		return false
	if not _is_valid_rate(hunger_per_game_hour) or not _is_valid_rate(thirst_per_game_hour):
		return false
	var hours := game_seconds / 3600.0
	var next_hunger := state.get_hunger() + hunger_per_game_hour * hours
	var next_thirst := state.get_thirst() + thirst_per_game_hour * hours
	if not is_finite(next_hunger) or not is_finite(next_thirst):
		return false
	state.set_hunger(next_hunger)
	state.set_thirst(next_thirst)
	return true


func _is_valid_rate(value: float) -> bool:
	return is_finite(value) and value >= 0.0
