class_name DemoWindowHealth
extends DamageReceiver
## Demo-only breakable glass state that plugs into the shared CombatService.

signal health_changed(current_health: float, max_health: float, damage: float)
signal health_depleted

@export_range(1.0, 100.0, 1.0) var max_health := 36.0
var current_health := 36.0


func _ready() -> void:
	current_health = maxf(max_health, 1.0)


func can_receive_damage(event: DamageEvent) -> bool:
	return event != null and event.is_valid() and is_instance_valid(get_parent()) \
		and event.target == get_parent() and current_health > 0.0


func receive_damage(event: DamageEvent) -> bool:
	if not can_receive_damage(event):
		return false
	current_health = maxf(current_health - event.amount, 0.0)
	health_changed.emit(current_health, max_health, event.amount)
	if current_health <= 0.0:
		health_depleted.emit()
	return true


func get_current_health() -> float:
	return current_health


func get_max_health() -> float:
	return max_health


func is_depleted() -> bool:
	return current_health <= 0.0
