class_name WoundComponent
extends Node
## Owns one entity's Wounds and advances bleeding against logical game time.

const WoundStateScript = preload("res://scripts/wounds/wound_state.gd")

signal wound_created(wound: WoundState)

@export_range(0.0, 10.0, 0.01) var bleeding_rate_per_damage_per_game_hour: float = 0.1

var _wounds: Array[WoundState] = []
var _damage_receiver: Node
var _last_clock_seconds := 0.0


func _ready() -> void:
	var entity := get_parent()
	if entity == null:
		push_error("[WoundComponent] Missing entity parent")
		set_process(false)
		return
	_damage_receiver = entity.get_node_or_null("PlayerDamageReceiver")
	if _damage_receiver == null or not _damage_receiver.has_signal("damage_received"):
		push_error("[WoundComponent] Parent PlayerDamageReceiver damage_received signal is unavailable")
		set_process(false)
		return
	if not _damage_receiver.damage_received.is_connected(handle_damage_received):
		_damage_receiver.damage_received.connect(handle_damage_received)
	_last_clock_seconds = GameClock.get_elapsed_game_seconds()


func _process(_delta: float) -> void:
	var current_seconds: float = GameClock.get_elapsed_game_seconds()
	var elapsed := current_seconds - _last_clock_seconds
	_last_clock_seconds = current_seconds
	if elapsed > 0.0:
		advance_game_time(elapsed)


func handle_damage_received(event: DamageEvent) -> bool:
	if event == null or not event.is_valid() or event.target != get_parent():
		return false
	if not is_finite(bleeding_rate_per_damage_per_game_hour) or bleeding_rate_per_damage_per_game_hour < 0.0:
		return false
	var initial_rate := event.amount * bleeding_rate_per_damage_per_game_hour
	initial_rate = minf(initial_rate, WoundStateScript.MAX_BLEEDING_RATE_PER_GAME_HOUR)
	var wound: WoundState = WoundStateScript.new(initial_rate)
	if not wound.is_valid():
		return false
	_wounds.append(wound)
	wound_created.emit(wound)
	return true


func get_wounds() -> Array[WoundState]:
	return _wounds.duplicate()


func get_wound(wound_id: String) -> WoundState:
	if wound_id.is_empty():
		return null
	for wound: WoundState in _wounds:
		if wound.wound_id == wound_id:
			return wound
	return null


func advance_game_time(game_seconds: float) -> bool:
	if not is_finite(game_seconds) or game_seconds < 0.0:
		return false
	if game_seconds == 0.0 or _wounds.is_empty():
		return true
	if _damage_receiver == null or not is_instance_valid(_damage_receiver):
		return false
	if not _damage_receiver.has_method("apply_bleeding_damage"):
		return false
	if _damage_receiver.is_depleted():
		return true
	var total_rate := 0.0
	for wound: WoundState in _wounds:
		if wound == null or not wound.is_valid():
			return false
		total_rate += wound.get_bleeding_rate_per_game_hour()
	if not is_finite(total_rate):
		return false
	var health_loss := total_rate * game_seconds / 3600.0
	if not is_finite(health_loss):
		return false
	if health_loss == 0.0:
		return true
	return _damage_receiver.apply_bleeding_damage(health_loss)
