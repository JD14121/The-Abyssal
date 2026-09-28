class_name DamageEvent
extends RefCounted
## Minimal immutable-by-convention request to apply positive damage to a target.

var source: Object
var target: Object
var amount: float


func _init(event_source: Object, event_target: Object, damage_amount: float) -> void:
	source = event_source
	target = event_target
	amount = damage_amount


func is_valid() -> bool:
	return is_instance_valid(source) and is_instance_valid(target) and is_finite(amount) and amount > 0.0
