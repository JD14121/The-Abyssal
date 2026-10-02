class_name EquipmentComponent
extends Node
## Tracks equipped slots by Inventory instance identity; it never duplicates items.

const SLOT_CATEGORIES := {
	&"hands": [&"weapon"],
	&"head": [&"clothing"],
	&"body": [&"clothing"],
	&"legs": [&"clothing"],
	&"backpack": [&"clothing"],
}

var _slots: Dictionary[StringName, String] = {}
var _inventory_component: Node
var _melee_component: Node


func _ready() -> void:
	_inventory_component = get_parent().get_node_or_null("PlayerInventoryComponent")
	_melee_component = get_parent().get_node_or_null("PlayerMeleeComponent")
	for slot: StringName in SLOT_CATEGORIES:
		_slots[slot] = ""


func equip_item(slot: StringName, instance_id: String) -> bool:
	if not SLOT_CATEGORIES.has(slot) or instance_id.strip_edges().is_empty():
		return false
	var inventory = _get_inventory()
	if inventory == null or not inventory.has_item(instance_id):
		return false
	var item = inventory.get_item(instance_id)
	if item == null or not item.is_valid():
		return false
	var definition = item.get_definition()
	if definition == null or definition.category not in SLOT_CATEGORIES[slot]:
		return false
	if slot == &"hands":
		var registry := get_tree().root.get_node_or_null("DataRegistry")
		var weapon = registry.get_weapon_for_item(item.definition_id) if registry != null else null
		if weapon == null:
			return false
		if weapon.kind == &"ranged":
			var ranged_component := get_parent().get_node_or_null("RangedWeaponComponent")
			if ranged_component == null or not ranged_component.equip_ranged_weapon(instance_id):
				return false
			if _melee_component != null:
				_melee_component.unequip_melee_weapon()
		else:
			if _melee_component == null or not _melee_component.equip_melee_weapon(instance_id):
				return false
			var other_ranged := get_parent().get_node_or_null("RangedWeaponComponent")
			if other_ranged != null:
				other_ranged.unequip()
	_slots[slot] = instance_id
	return true


func unequip(slot: StringName) -> bool:
	if not _slots.has(slot) or _slots[slot].is_empty():
		return false
	_slots[slot] = ""
	if slot == &"hands" and _melee_component != null:
		_melee_component.unequip_melee_weapon()
	if slot == &"hands":
		var ranged := get_parent().get_node_or_null("RangedWeaponComponent")
		if ranged != null:
			ranged.unequip()
	return true


func get_equipped_instance_id(slot: StringName) -> String:
	if not _slots.has(slot):
		return ""
	var instance_id: String = _slots[slot]
	var inventory = _get_inventory()
	if not instance_id.is_empty() and (inventory == null or not inventory.has_item(instance_id)):
		_slots[slot] = ""
		if slot == &"hands" and _melee_component != null:
			_melee_component.unequip_melee_weapon()
		if slot == &"hands":
			var ranged := get_parent().get_node_or_null("RangedWeaponComponent")
			if ranged != null:
				ranged.unequip()
		return ""
	return instance_id


func get_equipped_item(slot: StringName):
	var instance_id := get_equipped_instance_id(slot)
	var inventory = _get_inventory()
	return inventory.get_item(instance_id) if not instance_id.is_empty() and inventory != null else null


func _get_inventory():
	return _inventory_component.get_inventory() if _inventory_component != null else null
