class_name RangedWeaponComponent
extends Node
## Inventory-backed firearm firing, ammunition loading, cooldown, projectile and noise.

const PROJECTILE_SCENE := preload("res://scenes/combat/projectile.tscn")

var equipped_instance_id := ""
var cooldown_remaining := 0.0
var reload_remaining := 0.0
var _ammo_by_instance: Dictionary[String, int] = {}
var _inventory_component: Node
var _equipment_component: Node
var _registry: Node
var _noise_system: Node


func _ready() -> void:
	_inventory_component = get_parent().get_node_or_null("PlayerInventoryComponent")
	_equipment_component = get_parent().get_node_or_null("EquipmentComponent")
	_registry = get_tree().root.get_node_or_null("DataRegistry")
	var world := get_parent().get_parent()
	_noise_system = world.get_node_or_null("NoiseSystem") if world != null else null


func _process(delta: float) -> void:
	if is_finite(delta) and delta > 0.0:
		cooldown_remaining = maxf(cooldown_remaining - delta, 0.0)
		reload_remaining = maxf(reload_remaining - delta, 0.0)


func equip_ranged_weapon(instance_id: String) -> bool:
	var inventory = _get_inventory()
	if inventory == null or not inventory.has_item(instance_id):
		return false
	var item = inventory.get_item(instance_id)
	var weapon = _get_weapon_for_item(item.definition_id) if item != null else null
	if weapon == null or weapon.kind != &"ranged":
		return false
	equipped_instance_id = instance_id
	if not _ammo_by_instance.has(instance_id):
		_ammo_by_instance[instance_id] = 0
	return true


func unequip() -> void:
	equipped_instance_id = ""


func reload() -> bool:
	var weapon = _get_equipped_weapon()
	var inventory = _get_inventory()
	if weapon == null or inventory == null or reload_remaining > 0.0:
		return false
	var current := get_loaded_ammo()
	var needed: int = weapon.magazine_size - current
	if needed <= 0:
		return false
	var ammo_ids: Array[String] = []
	for item in inventory.get_all_items():
		if item.definition_id == weapon.ammo_item_id:
			ammo_ids.append(item.instance_id)
			if ammo_ids.size() >= needed:
				break
	if ammo_ids.is_empty():
		return false
	var removed: Array[ItemInstance] = []
	for ammo_id in ammo_ids:
		var ammo = inventory.remove_item(ammo_id)
		if ammo == null:
			for prior in removed:
				inventory.add_item(prior)
			return false
		removed.append(ammo)
	_ammo_by_instance[equipped_instance_id] = current + removed.size()
	reload_remaining = weapon.reload_time
	return true


func fire() -> bool:
	var weapon = _get_equipped_weapon()
	if weapon == null or cooldown_remaining > 0.0 or reload_remaining > 0.0 or get_loaded_ammo() <= 0:
		return false
	var world := get_parent().get_parent()
	if world == null or not world.is_inside_tree():
		return false
	var direction: Vector2 = get_parent().get_facing_direction()
	if direction.is_zero_approx():
		return false
	var projectile := PROJECTILE_SCENE.instantiate() as CombatProjectile
	if projectile == null or not projectile.configure(get_parent(), direction, weapon.damage,
		weapon.projectile_speed, weapon.range):
		if is_instance_valid(projectile):
			projectile.free()
		return false
	world.add_child(projectile)
	projectile.global_position = get_parent().global_position + direction * 24.0
	projectile.rotation = direction.angle()
	_ammo_by_instance[equipped_instance_id] -= 1
	cooldown_remaining = weapon.attack_interval
	if is_instance_valid(_noise_system) and _noise_system.has_method("emit_noise"):
		_noise_system.emit_noise(get_parent().global_position, weapon.noise_radius, &"gunshot", get_parent())
	return true


func get_loaded_ammo() -> int:
	return int(_ammo_by_instance.get(equipped_instance_id, 0))


func get_magazine_capacity() -> int:
	var weapon = _get_equipped_weapon()
	return weapon.magazine_size if weapon != null else 0


func _get_inventory():
	return _inventory_component.get_inventory() if _inventory_component != null else null


func _get_equipped_weapon():
	var inventory = _get_inventory()
	if inventory == null or equipped_instance_id.is_empty() or not inventory.has_item(equipped_instance_id):
		equipped_instance_id = ""
		return null
	var item = inventory.get_item(equipped_instance_id)
	var weapon = _get_weapon_for_item(item.definition_id) if item != null else null
	return weapon if weapon != null and weapon.kind == &"ranged" else null


func _get_weapon_for_item(item_id: StringName):
	return _registry.get_weapon_for_item(item_id) if _registry != null and is_instance_valid(_registry) else null
