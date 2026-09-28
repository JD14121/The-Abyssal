extends Node
## The sole published index of validated static definitions.

const Loader = preload("res://scripts/data/data_loader.gd")
const Validator = preload("res://scripts/data/data_validator.gd")
const MaterialData = preload("res://scripts/data/definitions/material_definition.gd")
const Item = preload("res://scripts/data/definitions/item_definition.gd")

var _materials: Dictionary[StringName, MaterialData] = {}
var _items: Dictionary[StringName, Item] = {}
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
	_errors.clear()
	_warnings.clear()
	var started := Time.get_ticks_msec()
	var loader := Loader.new()
	var validator := Validator.new()
	var pending_materials: Dictionary[StringName, MaterialData] = {}
	var pending_items: Dictionary[StringName, Item] = {}
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
					var registered: Dictionary = pending_materials if group == "materials" else pending_items
					if not validator.validate(entry, Validator.GROUP_TYPES[group], "%s[%d]" % [path, index], registered, pending_materials):
						continue
					if group == "materials":
						var definition := MaterialData.new(entry, path)
						pending_materials[definition.id] = definition
					else:
						var definition := Item.new(entry, path)
						pending_items[definition.id] = definition
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
	_loaded = true
	print("[DataRegistry] Ready. Materials: %d; Items: %d; Files: %d; Errors: 0; Warnings: %d; Duration: %d ms" % [_materials.size(), _items.size(), loader.file_count, _warnings.size(), Time.get_ticks_msec() - started])
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


func get_all_materials() -> Array:
	return _materials.values()


func get_all_items() -> Array:
	return _items.values()


func get_errors() -> Array[String]:
	return _errors.duplicate()


func get_warnings() -> Array[String]:
	return _warnings.duplicate()
