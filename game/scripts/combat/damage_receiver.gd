class_name DamageReceiver
extends Node
## Shared contract for objects that own mutable health.


func can_receive_damage(_event: DamageEvent) -> bool:
	return false


func receive_damage(_event: DamageEvent) -> bool:
	return false


func get_current_health() -> float:
	return -1.0


func get_max_health() -> float:
	return -1.0


func is_depleted() -> bool:
	return true
