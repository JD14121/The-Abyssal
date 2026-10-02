class_name InjuryComponent
extends Node
## Owns wound-linked pain, severity, fracture state, and movement penalties.

const InjuryStateScript = preload("res://scripts/wounds/injury_state.gd")

var _states: Dictionary[String, InjuryState] = {}
var _last_clock_seconds := 0.0


func _ready() -> void:
	var entity := get_parent()
	var wounds := entity.get_node_or_null("WoundComponent") if entity != null else null
	if wounds == null or not wounds.has_signal("wound_created"):
		push_error("[InjuryComponent] WoundComponent is required")
		set_process(false)
		return
	if not wounds.wound_created.is_connected(_on_wound_created):
		wounds.wound_created.connect(_on_wound_created)
	_last_clock_seconds = GameClock.get_elapsed_game_seconds()


func _process(_delta: float) -> void:
	var current := GameClock.get_elapsed_game_seconds()
	var elapsed := current - _last_clock_seconds
	_last_clock_seconds = current
	if elapsed > 0.0:
		advance_game_time(elapsed)


func _on_wound_created(wound: WoundState) -> void:
	if wound == null or not wound.is_valid() or _states.has(wound.wound_id):
		return
	var severity := clampf(wound.get_bleeding_rate_per_game_hour() * 4.0, 1.0, 10.0)
	var state := InjuryStateScript.new(wound.wound_id, severity, severity * 8.0, severity >= 8.0)
	if state.is_valid():
		_states[wound.wound_id] = state


func get_injury(wound_id: String) -> InjuryState:
	return _states.get(wound_id)


func get_movement_multiplier() -> float:
	var multiplier := 1.0
	for state: InjuryState in _states.values():
		multiplier = minf(multiplier, state.get_movement_multiplier())
	return multiplier


func advance_game_time(game_seconds: float) -> bool:
	if not is_finite(game_seconds) or game_seconds < 0.0:
		return false
	for state: InjuryState in _states.values():
		if not state.advance_game_time(game_seconds):
			return false
	return true
