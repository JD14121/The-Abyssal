extends Node
## The sole published index of validated static definitions.

const Loader = preload("res://scripts/data/data_loader.gd")
const Validator = preload("res://scripts/data/data_validator.gd")
const MaterialData = preload("res://scripts/data/definitions/material_definition.gd")
const Item = preload("res://scripts/data/definitions/item_definition.gd")
const Loot = preload("res://scripts/data/definitions/loot_definition.gd")
const Consumable = preload("res://scripts/data/definitions/consumable_definition.gd")
const Creature = preload("res://scripts/data/definitions/creature_definition.gd")

var _materials: Dictionary[StringName, MaterialData] = {}
var _items: Dictionary[StringName, Item] = {}
var _loot: Dictionary[StringName, Loot] = {}
var _consumables: Dictionary[StringName, Consumable] = {}
var _consumables_by_item_id: Dictionary[StringName, Consumable] = {}
var _creatures: Dictionary[StringName, Creature] = {}
var _loaded: bool = false
var _errors: Array[String] = []
var _warnings: Array[String] = []


func _ready() -> void:
	load_all_data()


func load_all_data(data_root: String = "res://data") -> bool:
	# Clear old state before loading; publish staging dictionaries only on success.
	_loaded = false
	_materials.clear()
	_items.clear()
	_loot.clear()
	_consumables.clear()
	_consumables_by_item_id.clear()
	_creatures.clear()
	_errors.clear()
	_warnings.clear()
	var started := Time.get_ticks_msec()
	var loader := Loader.new()
	var validator := Validator.new()
	var pending_materials: Dictionary[StringName, MaterialData] = {}
	var pending_items: Dictionary[StringName, Item] = {}
	var pending_loot: Dictionary[StringName, Loot] = {}
	var pending_consumables: Dictionary[StringName, Consumable] = {}
	var pending_consumables_by_item_id: Dictionary[StringName, Consumable] = {}
	var pending_creatures: Dictionary[StringName, Creature] = {}
	print("[DataRegistry] Starting data load: " + data_root)
	var order_path := data_root.path_join("core/load_order.json")
	var order: Dictionary = loader.read_json(order_path)
	if order.ok and validator.validate_load_order(order.value, order_path):
		for group in order.value.groups:
			var files: Array[String] = loader.scan_json(data_root.path_join(group))
			print("[DataLoader] %s files: %d" % [group, files.size()])
			for path in files:
				var parsed: Dictionary = loader.read_json(path)
				if not parsed.ok:
					continue
				var entries: Array = validator.entries(parsed.value, path)
				for index in range(entries.size()):
					var entry: Variant = entries[index]
					var registered: Dictionary
					var references: Dictionary
					match group:
						"materials":
							registered = pending_materials
							references = pending_materials
						"items":
							registered = pending_items
							references = pending_materials
						"loot":
							registered = pending_loot
							references = pending_items
						"consumables":
							registered = pending_consumables
							references = pending_items
						"creatures":
							registered = pending_creatures
							references = pending_creatures
					if not validator.validate(entry, Validator.GROUP_TYPES[group], "%s[%d]" % [path, index], registered, references, pending_consumables_by_item_id):
						continue
					match group:
						"materials":
							var material := MaterialData.new(entry, path)
							pending_materials[material.id] = material
						"items":
							var item := Item.new(entry, path)
							pending_items[item.id] = item
						"loot":
							var loot := Loot.new(entry, path)
							pending_loot[loot.id] = loot
						"consumables":
							var consumable := Consumable.new(entry, path)
							pending_consumables[consumable.id] = consumable
							pending_consumables_by_item_id[consumable.item_id] = consumable
						"creatures":
							var creature := Creature.new(entry, path)
							pending_creatures[creature.id] = creature
	_errors.append_array(loader.errors)
	_errors.append_array(validator.errors)
	_warnings.append_array(validator.warnings)
	for message in _warnings:
		push_warning("[DataValidator] " + message)
	for message in _errors:
		push_error("[DataFoundation] " + message)
	if not _errors.is_empty():
		print("[DataRegistry] FAILED: %d errors; no definitions published." % _errors.size())
		return false
	_materials = pending_materials
	_items = pending_items
	_loot = pending_loot
	_consumables = pending_consumables
	_consumables_by_item_id = pending_consumables_by_item_id
	_creatures = pending_creatures
	_loaded = true
	print("[DataRegistry] Ready. Materials: %d; Items: %d; Loot: %d; Consumables: %d; Creatures: %d; Files: %d; Errors: 0; Warnings: %d; Duration: %d ms" % [_materials.size(), _items.size(), _loot.size(), _consumables.size(), _creatures.size(), loader.file_count, _warnings.size(), Time.get_ticks_msec() - started])
	return true


func is_loaded() -> bool:
	return _loaded


func get_material(id: StringName) -> MaterialData:
	return _materials.get(id)


func has_material(id: StringName) -> bool:
	return _materials.has(id)


func get_item(id: StringName) -> Item:
	return _items.get(id)


func has_item(id: StringName) -> bool:
	return _items.has(id)


func get_loot(id: StringName) -> Loot:
	return _loot.get(id)


func has_loot(id: StringName) -> bool:
	return _loot.has(id)


func get_all_materials() -> Array:
	return _materials.values()


func get_all_items() -> Array:
	return _items.values()


func get_all_loot() -> Array:
	return _loot.values()


func get_consumable(id: StringName) -> Consumable:
	return _consumables.get(id)


func has_consumable(id: StringName) -> bool:
	return _consumables.has(id)


func get_all_consumables() -> Array:
	return _consumables.values()


func get_creature(id: StringName) -> Creature:
	return _creatures.get(id)


func has_creature(id: StringName) -> bool:
	return _creatures.has(id)


func get_all_creatures() -> Array:
	return _creatures.values()


func get_consumable_for_item(item_id: StringName) -> Consumable:
	return _consumables_by_item_id.get(item_id)


func get_errors() -> Array[String]:
	return _errors.duplicate()


func get_warnings() -> Array[String]:
	return _warnings.duplicate()
