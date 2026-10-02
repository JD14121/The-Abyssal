class_name InfectionComponent
extends Node
## Tracks infection progression for each Wound owned by the parent entity.

const InfectionStateScript = preload("res://scripts/wounds/infection_state.gd")

@export_range(0.0, 1.0, 0.01) var contamination_risk := 0.35
@export_range(0.0, 100.0, 0.1) var progression_per_game_hour := 12.0

var _states: Dictionary[String, InfectionState] = {}
var _damage_receiver: Node
var _last_clock_seconds := 0.0


func _ready() -> void:
	var entity := get_parent()
	var wounds := entity.get_node_or_null("WoundComponent") if entity != null else null
	_damage_receiver = entity.get_node_or_null("PlayerDamageReceiver") if entity != null else null
	if wounds == null or _damage_receiver == null or not wounds.has_signal("wound_created"):
		push_error("[InfectionComponent] WoundComponent and PlayerDamageReceiver are required")
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
	var state := InfectionStateScript.new(wound.wound_id, contamination_risk, progression_per_game_hour)
	if state.is_valid():
		_states[wound.wound_id] = state


func get_infection(wound_id: String) -> InfectionState:
	return _states.get(wound_id)


func get_all_infections() -> Array[InfectionState]:
	var result: Array[InfectionState] = []
	for state: InfectionState in _states.values():
		result.append(state)
	return result


func treat_infection(wound_id: String, reduction: float) -> bool:
	var state := get_infection(wound_id)
	return state != null and state.is_infected() and state.reduce(reduction)


func advance_game_time(game_seconds: float) -> bool:
	if not is_finite(game_seconds) or game_seconds < 0.0:
		return false
	var health_loss := 0.0
	for state: InfectionState in _states.values():
		if not state.advance_game_time(game_seconds):
			return false
		health_loss += state.get_health_loss_per_game_hour() * game_seconds / 3600.0
	if health_loss <= 0.0:
		return true
	return _damage_receiver != null and _damage_receiver.has_method("apply_infection_damage") \
		and _damage_receiver.apply_infection_damage(health_loss)
