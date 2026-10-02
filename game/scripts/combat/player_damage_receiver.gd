class_name PlayerDamageReceiver
extends DamageReceiver
## Exposes the Player's SurvivalState health without storing a second value.

const SurvivalStateScript = preload("res://scripts/survival/survival_state.gd")

signal health_depleted
signal damage_received(event: DamageEvent)

var survival_component: Node


func _ready() -> void:
	if survival_component == null:
		survival_component = get_parent().get_node_or_null("SurvivalComponent")


func configure(component: Node) -> bool:
	if component == null or component.get("state") == null:
		return false
	survival_component = component
	return true


func can_receive_damage(event: DamageEvent) -> bool:
	var state = _get_state()
	return event != null and event.is_valid() and is_instance_valid(get_parent()) \
		and event.target == get_parent() and state != null and state.is_valid() \
		and state.get_health() > 0.0


func receive_damage(event: DamageEvent) -> bool:
	if not can_receive_damage(event):
		return false
	var applied: bool = _get_state().modify_health(-event.amount)
	if applied:
		damage_received.emit(event)
		if is_depleted():
			health_depleted.emit()
	return applied


func apply_bleeding_damage(amount: float) -> bool:
	if not is_finite(amount) or amount <= 0.0 or is_depleted():
		return false
	var state = _get_state()
	if state == null or not state.is_valid():
		return false
	var applied: bool = state.modify_health(-amount)
	if applied and is_depleted():
		health_depleted.emit()
	return applied


func get_current_health() -> float:
	var state = _get_state()
	return state.get_health() if state != null else -1.0


func get_max_health() -> float:
	return SurvivalStateScript.MAX_VALUE


func is_depleted() -> bool:
	return get_current_health() == 0.0


func _get_state():
	if not is_instance_valid(survival_component):
		return null
	return survival_component.get("state")
