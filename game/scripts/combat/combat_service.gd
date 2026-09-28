class_name CombatService
extends RefCounted
## Validates combat requests and delegates all health changes to a receiver.

const DamageEventScript = preload("res://scripts/combat/damage_event.gd")
const DamageReceiverScript = preload("res://scripts/combat/damage_receiver.gd")


func resolve_melee_attack(attacker: Object, target: Object) -> bool:
	if not is_instance_valid(attacker) or not attacker.has_method("get_melee_damage"):
		push_error("[CombatService] Cannot resolve melee attack: invalid attacker or melee data")
		return false
	if not is_instance_valid(target) or not target.has_method("get_damage_receiver"):
		push_error("[CombatService] Cannot resolve melee attack: invalid target or no DamageReceiver")
		return false
	var amount: Variant = attacker.get_melee_damage()
	if not _is_positive_finite_number(amount):
		push_error("[CombatService] Cannot resolve melee attack: invalid damage amount")
		return false
	var event: DamageEvent = DamageEventScript.new(attacker, target, float(amount))
	return apply_damage_event(event)


func apply_damage_event(event: DamageEvent) -> bool:
	if event == null or not event.is_valid():
		push_error("[CombatService] Cannot apply invalid DamageEvent")
		return false
	if not event.target.has_method("get_damage_receiver"):
		push_error("[CombatService] Target has no DamageReceiver")
		return false
	var receiver: Variant = event.target.get_damage_receiver()
	if not receiver is DamageReceiverScript or not receiver.can_receive_damage(event):
		push_error("[CombatService] Target DamageReceiver rejected the event")
		return false
	return receiver.receive_damage(event)


func _is_positive_finite_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value)) and float(value) > 0.0
