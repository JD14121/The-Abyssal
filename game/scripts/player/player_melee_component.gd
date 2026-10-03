extends Node2D
## Selects an owned weapon instance and submits bounded melee requests to CombatService.

signal attack_landed(target: Node2D)

const CombatServiceScript = preload("res://scripts/combat/combat_service.gd")
const DamageReceiverScript = preload("res://scripts/combat/damage_receiver.gd")

const UNARMED_DAMAGE := 8.0
const UNARMED_RANGE := 42.0
const UNARMED_INTERVAL := 0.65

@export var detection_area_path: NodePath = ^"MeleeTargetArea"
@export_range(15.0, 180.0, 1.0) var attack_arc_degrees := 100.0
@export_range(0.0, 500.0, 1.0) var stagger_impulse := 105.0
@export_range(0.0, 2.0, 0.01) var stagger_duration := 0.22

var equipped_instance_id := ""
var cooldown_remaining := 0.0
var _combat_enabled := true
var _candidates: Array[Node2D] = []
var _inventory_component: Node
var _registry: Node
var _noise_system: Node
var _combat_service := CombatServiceScript.new()
var _area: Area2D
var _swing_visual: Node2D


func _ready() -> void:
	_inventory_component = get_parent().get_node_or_null("PlayerInventoryComponent")
	_registry = get_tree().root.get_node_or_null("DataRegistry")
	_noise_system = get_parent().get_parent().get_node_or_null("NoiseSystem") \
		if get_parent().get_parent() != null else null
	_swing_visual = get_parent().get_node_or_null("MeleeSwingVisual") as Node2D
	_area = get_node_or_null(detection_area_path) as Area2D
	if _area != null:
		_area.body_entered.connect(_on_body_entered)
		_area.body_exited.connect(_on_body_exited)
		_area.area_entered.connect(_on_area_entered)
		_area.area_exited.connect(_on_area_exited)
	_sync_detection_range()


func _physics_process(delta: float) -> void:
	physics_step(delta, Input.is_action_just_pressed(&"melee_attack"))


func physics_step(delta: float, attack_pressed: bool) -> bool:
	if is_finite(delta) and delta > 0.0:
		cooldown_remaining = maxf(cooldown_remaining - delta, 0.0)
	if attack_pressed and _combat_enabled:
		return try_attack()
	return false


func set_combat_enabled(enabled: bool) -> void:
	_combat_enabled = enabled


func is_combat_enabled() -> bool:
	return _combat_enabled


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
	if weapon != null:
		return weapon.melee_damage if weapon.kind != &"ranged" else 0.0
	return UNARMED_DAMAGE if _hands_are_empty() else 0.0


func try_attack() -> bool:
	if not _combat_enabled:
		return false
	var weapon = _get_equipped_weapon()
	var is_unarmed := weapon == null and _hands_are_empty()
	if (weapon == null and not is_unarmed) or (weapon != null and weapon.kind == &"ranged"):
		return false
	if cooldown_remaining > 0.0:
		return false
	var max_range: float = UNARMED_RANGE if is_unarmed else float(weapon.melee_range)
	var interval: float = UNARMED_INTERVAL if is_unarmed else float(weapon.attack_interval)
	var target := select_target(max_range)
	if target == null:
		return false
	if _get_player_position().distance_to(target.global_position) > max_range:
		return false
	if not _combat_service.resolve_melee_attack(get_parent(), target):
		return false
	attack_landed.emit(target)
	if _swing_visual != null and _swing_visual.has_method("play_attack"):
		_swing_visual.call("play_attack", get_facing_direction(), max_range, is_unarmed)
	var player_position := _get_player_position()
	if target.has_method("apply_stagger"):
		target.apply_stagger((target.global_position - player_position).normalized() * stagger_impulse, stagger_duration)
	if is_instance_valid(_noise_system) and _noise_system.has_method("emit_noise"):
		_noise_system.emit_noise(player_position, 220.0, &"melee_attack", get_parent())
	cooldown_remaining = interval
	return true


func select_target(max_range: float) -> Node2D:
	var best: Node2D
	var best_distance := INF
	for candidate in _candidates:
		if not is_instance_valid(candidate) or not _is_legal_target(candidate):
			continue
		var distance: float = _get_player_position().distance_to(candidate.global_position)
		var offset := candidate.global_position - _get_player_position()
		var direction := offset.normalized()
		var facing := get_facing_direction()
		var arc_dot := cos(deg_to_rad(clampf(attack_arc_degrees, 15.0, 180.0) * 0.5))
		if distance <= max_range and not direction.is_zero_approx() and facing.dot(direction) >= arc_dot \
			and distance < best_distance:
			best = candidate
			best_distance = distance
	return best


func get_candidate_count() -> int:
	return _candidates.size()


func set_facing_direction(direction: Vector2) -> bool:
	return get_parent().set_facing_direction(direction) if get_parent().has_method("set_facing_direction") else false


func get_facing_direction() -> Vector2:
	return get_parent().get_facing_direction() if get_parent().has_method("get_facing_direction") else Vector2.RIGHT


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
	if weapon != null:
		_set_detection_radius(weapon.melee_range if weapon.kind != &"ranged" else 0.0)
	else:
		_set_detection_radius(UNARMED_RANGE if _hands_are_empty() else 0.0)


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


func _on_area_entered(area: Area2D) -> void:
	if area.has_method("get_damage_receiver") and not _candidates.has(area):
		_candidates.append(area)


func _on_area_exited(area: Area2D) -> void:
	_candidates.erase(area)


func _hands_are_empty() -> bool:
	var equipment = get_parent().get_node_or_null("EquipmentComponent")
	return equipment != null and equipment.get_equipped_instance_id(&"hands").is_empty()
