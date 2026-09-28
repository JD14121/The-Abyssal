extends SceneTree
## Weapon static data, cross-reference and atomic reload checks.

const RegistryScript = preload("res://autoload/data_registry.gd")
const VALID_ROOT := "res://data"

var checks := 0
var failures := 0
var scratch := ""


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	var registry = RegistryScript.new()
	check(registry.load_all_data(VALID_ROOT), "production Weapon data loads")
	check(registry.has_weapon(&"weapon_kitchen_knife") and registry.get_all_weapons().size() == 1, "Weapon registry ID APIs work")
	check(registry.get_weapon_for_item(&"kitchen_knife") == registry.get_weapon(&"weapon_kitchen_knife"), "item index resolves Weapon definition")
	var valid := '{"type":"weapon","id":"weapon_kitchen_knife","item_id":"kitchen_knife","melee_damage":20,"melee_range":52,"attack_interval":0.7}'
	_prepare_scratch()
	_write("weapons/weapons.json", "[%s]" % valid.replace("kitchen_knife", "canned_beans"))
	check(registry.load_all_data(scratch) and registry.get_weapon_for_item(&"canned_beans") != null and registry.get_consumable_for_item(&"canned_beans") != null, "one Item can map to both Weapon and Consumable")
	var bad_cases := [
		[valid.replace("\"melee_damage\":20", "\"melee_damage\":0"), "melee_damage"],
		[valid.replace("\"melee_range\":52", "\"melee_range\":1e999"), "melee_range"],
		[valid.replace("\"item_id\":\"kitchen_knife\"", "\"item_id\":\"missing_item\""), "unknown item ID"],
		[valid + "," + valid.replace("weapon_kitchen_knife", "weapon_duplicate"), "already maps to Weapon"]
	]
	for case in bad_cases:
		_prepare_scratch()
		_write("weapons/weapons.json", "[%s]" % case[0])
		check(not registry.load_all_data(scratch), "invalid weapon is rejected: %s" % case[1])
		check(not registry.is_loaded() and registry.get_all_weapons().is_empty() and registry.get_weapon_for_item(&"kitchen_knife") == null, "failed load clears Weapon indexes")
		check(case[1] in "; ".join(registry.get_errors()), "weapon validation error identifies %s" % case[1])
	_prepare_scratch()
	_write("weapons/weapons.json", "[" + valid + "]")
	check(registry.load_all_data(scratch) and registry.has_weapon(&"weapon_kitchen_knife"), "valid reload restores Weapon indexes")
	registry.free()
	_remove_tree(scratch)
	print("Weapon registry: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _prepare_scratch() -> void:
	if scratch.is_empty():
		scratch = "user://weapon_registry_%s" % Time.get_ticks_usec()
	_remove_tree(scratch)
	for directory in ["core", "materials", "items", "loot", "consumables", "creatures", "weapons"]:
		DirAccess.make_dir_recursive_absolute(scratch.path_join(directory))
	for relative in ["materials/materials.json", "items/test_items.json", "loot/test_loot.json", "consumables/consumables.json", "creatures/creatures.json"]:
		_write(relative, FileAccess.get_file_as_string(VALID_ROOT.path_join(relative)))
	_write("core/load_order.json", "{\"groups\":[\"materials\",\"items\",\"loot\",\"consumables\",\"creatures\",\"weapons\"]}")
	_write("weapons/weapons.json", "[]")


func _write(relative: String, content: String) -> void:
	var path := scratch.path_join(relative)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()


func _remove_tree(path: String) -> void:
	if path.is_empty() or not path.begins_with("user://weapon_registry_"):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for filename in directory.get_files():
		DirAccess.remove_absolute(path.path_join(filename))
	for child in directory.get_directories():
		_remove_tree(path.path_join(child))
	DirAccess.remove_absolute(path)
