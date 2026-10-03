class_name CreatureHealthComponent
extends DamageReceiver
## Runtime health owned by one Creature entity.

signal health_depleted
signal health_changed(current_health: float, max_health: float, damage: float)

var max_health: float = 0.0
var current_health: float = 0.0
var initialized := false


func configure(definition: CreatureDefinition) -> bool:
	if definition == null or not is_finite(definition.max_health) or definition.max_health <= 0.0:
		return false
	max_health = definition.max_health
	current_health = max_health
	initialized = true
	return true


func can_receive_damage(event: DamageEvent) -> bool:
	return initialized and event != null and event.is_valid() \
		and is_instance_valid(get_parent()) and event.target == get_parent() \
		and current_health > 0.0


func receive_damage(event: DamageEvent) -> bool:
	if not can_receive_damage(event):
		return false
	var was_alive := current_health > 0.0
	current_health = maxf(current_health - event.amount, 0.0)
	health_changed.emit(current_health, max_health, event.amount)
	if was_alive and current_health == 0.0:
		health_depleted.emit()
	return true


func get_current_health() -> float:
	return current_health if initialized else -1.0


func get_max_health() -> float:
	return max_health if initialized else -1.0


func is_depleted() -> bool:
	return initialized and current_health <= 0.0
