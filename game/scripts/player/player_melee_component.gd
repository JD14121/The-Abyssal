extends Node
## Selects an owned weapon instance and submits bounded melee requests to CombatService.

const CombatServiceScript = preload("res://scripts/combat/combat_service.gd")
const DamageReceiverScript = preload("res://scripts/combat/damage_receiver.gd")

@export var detection_area_path: NodePath = ^"MeleeTargetArea"

var equipped_instance_id := ""
var cooldown_remaining := 0.0
var _candidates: Array[Node2D] = []
var _inventory_component: Node
var _registry: Node
var _combat_service := CombatServiceScript.new()
var _area: Area2D


func _ready() -> void:
	_inventory_component = get_parent().get_node_or_null("PlayerInventoryComponent")
	_registry = get_tree().root.get_node_or_null("DataRegistry")
	_area = get_node_or_null(detection_area_path) as Area2D
	if _area != null:
		_area.body_entered.connect(_on_body_entered)
		_area.body_exited.connect(_on_body_exited)


func _physics_process(delta: float) -> void:
	physics_step(delta, Input.is_action_just_pressed(&"melee_attack"))


func physics_step(delta: float, attack_pressed: bool) -> bool:
	if is_finite(delta) and delta > 0.0:
		cooldown_remaining = maxf(cooldown_remaining - delta, 0.0)
	if attack_pressed:
		return try_attack()
	return false


func equip_melee_weapon(instance_id: String) -> bool:
	var inventory = _get_inventory()
	if inventory == null or not inventory.has_item(instance_id):
		return false
	var instance = inventory.get_item(instance_id)
	if not is_instance_valid(instance) or not instance.is_valid() or _get_weapon_for_item(instance.definition_id) == null:
		return false
	equipped_instance_id = instance_id
	_sync_detection_range()
	return true


func unequip_melee_weapon() -> void:
	equipped_instance_id = ""
	_sync_detection_range()


func get_current_melee_damage() -> float:
	var weapon = _get_equipped_weapon()
	return weapon.melee_damage if weapon != null else 0.0


func try_attack() -> bool:
	var weapon = _get_equipped_weapon()
	if weapon == null:
		return false
	if cooldown_remaining > 0.0:
		return false
	var target := select_target(weapon.melee_range)
	if target == null:
		return false
	if _get_player_position().distance_to(target.global_position) > weapon.melee_range:
		return false
	if not _combat_service.resolve_melee_attack(get_parent(), target):
		return false
	cooldown_remaining = weapon.attack_interval
	return true


func select_target(max_range: float) -> Node2D:
	var best: Node2D
	var best_distance := INF
	for candidate in _candidates:
		if not is_instance_valid(candidate) or not _is_legal_target(candidate):
			continue
		var distance: float = _get_player_position().distance_to(candidate.global_position)
		if distance <= max_range and distance < best_distance:
			best = candidate
			best_distance = distance
	return best


func get_candidate_count() -> int:
	return _candidates.size()


func _get_equipped_weapon():
	var inventory = _get_inventory()
	if inventory == null or equipped_instance_id.is_empty() or not inventory.has_item(equipped_instance_id):
		_clear_equipped_selection()
		return null
	var instance = inventory.get_item(equipped_instance_id)
	if not is_instance_valid(instance) or not instance.is_valid():
		_clear_equipped_selection()
		return null
	var weapon = _get_weapon_for_item(instance.definition_id)
	if weapon == null:
		_clear_equipped_selection()
	return weapon


func _get_inventory():
	if _inventory_component == null or not is_instance_valid(_inventory_component):
		return null
	return _inventory_component.get_inventory()


func _get_player_position() -> Vector2:
	var player := get_parent() as Node2D
	return player.global_position if player != null else Vector2.ZERO


func _get_weapon_for_item(item_id: StringName):
	if _registry == null or not is_instance_valid(_registry):
		return null
	return _registry.get_weapon_for_item(item_id)


func _is_legal_target(target: Node2D) -> bool:
	if not target.has_method("get_damage_receiver"):
		return false
	var receiver: Variant = target.get_damage_receiver()
	return receiver is DamageReceiverScript and not receiver.is_depleted()


func _sync_detection_range() -> void:
	var weapon = _get_equipped_weapon()
	_set_detection_radius(weapon.melee_range if weapon != null else 0.0)


func _clear_equipped_selection() -> void:
	equipped_instance_id = ""
	_set_detection_radius(0.0)


func _set_detection_radius(radius: float) -> void:
	if _area == null:
		return
	var shape_node := _area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node != null and shape_node.shape is CircleShape2D:
		(shape_node.shape as CircleShape2D).radius = radius


func _on_body_entered(body: Node2D) -> void:
	if not _candidates.has(body):
		_candidates.append(body)


func _on_body_exited(body: Node2D) -> void:
	_candidates.erase(body)
