class_name CombatCoordinator
extends Node
## Scene-local adapter from attack intent signals to CombatService.

var combat_service := CombatService.new()


func handle_attack_requested(attacker: Node2D, target: Node2D) -> bool:
	return combat_service.resolve_melee_attack(attacker, target)
