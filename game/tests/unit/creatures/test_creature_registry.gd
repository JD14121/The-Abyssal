extends SceneTree

const REGISTRY_PATH := "res://autoload/data_registry.gd"
const INVALID_CASES := "res://tests/fixtures/creatures/invalid_cases.json"
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
	var registry = load(REGISTRY_PATH).new()
	check(registry.load_all_data(VALID_ROOT), "production Creature definitions load")
	check(registry.has_method("get_creature") and registry.has_method("has_creature") and registry.has_method("get_all_creatures"), "Creature Registry API exists")
	if registry.has_method("get_creature"):
		var basic = registry.get_creature(&"zombie_basic")
		check(basic != null and basic.name == "Basic Zombie", "Creature ID lookup returns its definition")
		check(registry.has_creature(&"zombie_basic") and not registry.has_creature(&"missing_creature"), "Creature membership query works")
		check(registry.get_all_creatures().size() == 2, "all Creature definitions are listed")
		check(registry.get_creature(&"missing_creature") == null, "unknown Creature returns null")
		check(is_equal_approx(basic.move_speed, 70.0) and is_equal_approx(basic.vision_range, 320.0) and is_equal_approx(basic.attack_range, 38.0) and is_equal_approx(basic.attack_interval, 1.2), "typed values are retained")
		check(is_equal_approx(registry.get_creature(&"zombie_slow").move_speed, 45.0), "second Creature definition retains its independent speed")

	var cases: Array = JSON.parse_string(FileAccess.get_file_as_string(INVALID_CASES))
	for case in cases:
		_prepare_scratch()
		_write("creatures/invalid.json", JSON.stringify(case.entries))
		check(not registry.load_all_data(scratch), case.name + " is rejected")
		check(not registry.is_loaded(), case.name + " makes Registry unavailable")
		check(registry.get_all_materials().is_empty() and registry.get_all_items().is_empty() and registry.get_all_loot().is_empty() and registry.get_all_consumables().is_empty() and registry.get_all_creatures().is_empty(), case.name + " clears all active definitions")
		check(case.diagnostic in "; ".join(registry.get_errors()), case.name + " has actionable diagnostic")
	_prepare_scratch()
	_write("creatures/invalid.json", "{\"type\":\"creature\",\"id\":\"overflow\",\"name\":\"Overflow\",\"move_speed\":1e999,\"vision_range\":320,\"attack_range\":38,\"attack_interval\":1.2}")
	check(not registry.load_all_data(scratch) and "move_speed" in "; ".join(registry.get_errors()), "non-finite JSON number is rejected")
	for field in ["max_health", "melee_damage"]:
		var overflow_entry := "{\"type\":\"creature\",\"id\":\"overflow_combat\",\"name\":\"Overflow\",\"move_speed\":70,\"vision_range\":320,\"attack_range\":38,\"attack_interval\":1.2,\"max_health\":100,\"melee_damage\":10}"
		overflow_entry = overflow_entry.replace("\"%s\":%s" % [field, "100" if field == "max_health" else "10"], "\"%s\":1e999" % field)
		_write("creatures/invalid.json", overflow_entry)
		check(not registry.load_all_data(scratch) and field in "; ".join(registry.get_errors()), "non-finite %s is rejected" % field)
	check(registry.load_all_data(VALID_ROOT) and registry.has_creature(&"zombie_basic"), "valid reload recovers Creature Registry")
	registry.free()
	_remove_tree(scratch)
	print("Creature registry: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _prepare_scratch() -> void:
	if scratch.is_empty():
		scratch = "user://creature_registry_%s" % Time.get_ticks_usec()
	_remove_tree(scratch)
	for directory in ["core", "materials", "items", "loot", "consumables", "creatures"]:
		DirAccess.make_dir_recursive_absolute(scratch.path_join(directory))
	for relative in ["materials/materials.json", "items/test_items.json", "loot/test_loot.json", "consumables/consumables.json"]:
		_write(relative, FileAccess.get_file_as_string(VALID_ROOT.path_join(relative)))
	_write("core/load_order.json", "{\"groups\":[\"materials\",\"items\",\"loot\",\"consumables\",\"creatures\"]}")
	_write("creatures/creatures.json", "[]")


func _write(relative: String, content: String) -> void:
	var path := scratch.path_join(relative)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()


func _remove_tree(path: String) -> void:
	if path.is_empty() or not path.begins_with("user://creature_registry_"):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for filename in directory.get_files():
		DirAccess.remove_absolute(path.path_join(filename))
	for child in directory.get_directories():
		_remove_tree(path.path_join(child))
	DirAccess.remove_absolute(path)
