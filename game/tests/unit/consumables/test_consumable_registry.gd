extends SceneTree

const REGISTRY_PATH := "res://autoload/data_registry.gd"
const VALID_ROOT := "res://data"
const VALIDATOR_PATH := "res://scripts/data/data_validator.gd"

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
	check(registry.load_all_data(VALID_ROOT), "production content with consumables loads")
	var has_registry_api: bool = registry.has_method("get_all_consumables") and registry.has_method("get_consumable") and registry.has_method("has_consumable") and registry.has_method("get_consumable_for_item")
	check(has_registry_api, "Registry exposes Consumable lookup APIs")
	if has_registry_api:
		check(registry.get_all_consumables().size() == 2, "both test Consumable definitions are loaded")
		check(registry.get_consumable(&"consumable_canned_beans") != null, "lookup by Consumable ID works")
		check(registry.has_consumable(&"consumable_water_bottle"), "Consumable ID membership works")
		check(registry.get_consumable_for_item(&"canned_beans").id == &"consumable_canned_beans", "Item ID index finds its Consumable")
		check(registry.get_consumable_for_item(&"hammer") == null, "ordinary Item has no Consumable mapping")
		check(registry.get_consumable(&"missing") == null, "unknown Consumable returns null")

	var validator = load(VALIDATOR_PATH).new()
	var item_refs := {&"canned_beans": true, &"water_bottle": true}
	check(not validator.validate({"type":"consumable", "id":"bad_nan", "item_id":"canned_beans", "hunger_delta":NAN}, "consumable", "nan fixture", {}, item_refs), "GDScript schema rejects NaN effect")
	validator = load(VALIDATOR_PATH).new()
	check(not validator.validate({"type":"consumable", "id":"bad_inf", "item_id":"canned_beans", "thirst_delta":INF}, "consumable", "inf fixture", {}, item_refs), "GDScript schema rejects INF effect")

	var invalid_cases := [
		{"name":"invalid Consumable ID", "diagnostic":"lowercase_snake_case", "entries":[{"type":"consumable", "id":"Bad_ID", "item_id":"glass_bottle"}]},
		{"name":"missing item_id", "diagnostic":"missing required field", "entries":[{"type":"consumable", "id":"missing_item_id"}]},
		{"name":"unknown item_id", "diagnostic":"unknown item ID", "entries":[{"type":"consumable", "id":"unknown_item", "item_id":"no_such_item"}]},
		{"name":"duplicate item mapping", "diagnostic":"already maps", "entries":[{"type":"consumable", "id":"profile_one", "item_id":"glass_bottle"}, {"type":"consumable", "id":"profile_two", "item_id":"glass_bottle"}]},
		{"name":"wrong hunger type", "diagnostic":"hunger_delta", "entries":[{"type":"consumable", "id":"bad_hunger", "item_id":"glass_bottle", "hunger_delta":true}]},
		{"name":"wrong thirst type", "diagnostic":"thirst_delta", "entries":[{"type":"consumable", "id":"bad_thirst", "item_id":"hammer", "thirst_delta":"-5"}]},
		{"name":"duplicate definition ID", "diagnostic":"duplicate ID", "entries":[{"type":"consumable", "id":"same_profile", "item_id":"glass_bottle"}, {"type":"consumable", "id":"same_profile", "item_id":"hammer"}]},
	]
	for invalid_case in invalid_cases:
		_prepare_scratch()
		_write("consumables/invalid.json", JSON.stringify(invalid_case.entries))
		_expect_failure(registry, invalid_case.name, invalid_case.diagnostic)
	check(registry.load_all_data(VALID_ROOT), "Registry recovers after fatal Consumable data and reloads valid content")

	_prepare_scratch()
	_write("consumables/zero_effect.json", JSON.stringify({"type":"consumable", "id":"consumable_no_effect_test", "item_id":"glass_bottle", "hunger_delta":0.0, "thirst_delta":0.0}))
	check(registry.load_all_data(scratch), "zero-effect definition remains loadable")
	check(registry.get_warnings().any(func(message: String) -> bool: return "zero" in message.to_lower()), "zero-effect definition emits a warning")
	var no_effect_service = load("res://scripts/consumables/consumable_use_service.gd").new(registry)
	var no_effect_factory = load("res://scripts/items/item_factory.gd").new(registry)
	var no_effect_inventory = load("res://scripts/inventory/inventory.gd").new(registry)
	var no_effect_state = load("res://scripts/survival/survival_state.gd").new()
	no_effect_state.set_hunger(35.0)
	no_effect_state.set_thirst(45.0)
	var no_effect_item = no_effect_factory.create(&"glass_bottle")
	no_effect_inventory.add_item(no_effect_item)
	check(no_effect_service.use_item(no_effect_inventory, no_effect_state, no_effect_item.instance_id), "zero-effect Consumable can still be used")
	check(not no_effect_inventory.has_item(no_effect_item.instance_id) and is_equal_approx(no_effect_state.get_hunger(), 35.0) and is_equal_approx(no_effect_state.get_thirst(), 45.0), "zero-effect use consumes only the item and leaves needs unchanged")
	_prepare_scratch()
	_write("consumables/unknown_field.json", JSON.stringify({"type":"consumable", "id":"consumable_unknown_field_test", "item_id":"glass_bottle", "future_field":1}))
	check(registry.load_all_data(scratch), "unknown static field follows warning policy")
	check(not registry.get_warnings().is_empty(), "unknown static field produces a warning")
	check(registry.load_all_data(VALID_ROOT), "Registry returns to production definitions")
	registry.free()
	_remove_tree(scratch)
	print("Consumable registry: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _expect_failure(registry: Node, label: String, diagnostic: String) -> void:
	check(not registry.load_all_data(scratch), label + " rejected")
	check(not registry.is_loaded(), label + " clears Registry ready state")
	check(registry.get_all_materials().is_empty() and registry.get_all_items().is_empty() and registry.get_all_loot().is_empty(), label + " clears existing definition registries")
	check(registry.get_all_consumables().is_empty(), label + " clears Consumable registries")
	check(registry.get_consumable(&"consumable_canned_beans") == null and registry.get_consumable_for_item(&"canned_beans") == null, label + " clears Consumable lookup indexes")
	check(not registry.get_errors().is_empty() and diagnostic in "; ".join(registry.get_errors()), label + " reports the expected actionable error")


func _prepare_scratch() -> void:
	if scratch.is_empty():
		scratch = "user://consumable_registry_%s" % Time.get_ticks_usec()
	_remove_tree(scratch)
	for directory in ["core", "materials", "items", "loot", "consumables"]:
		DirAccess.make_dir_recursive_absolute(scratch.path_join(directory))
	for relative in ["core/load_order.json", "materials/materials.json", "items/test_items.json", "loot/test_loot.json", "consumables/consumables.json"]:
		var content := FileAccess.get_file_as_string(VALID_ROOT.path_join(relative))
		if content.is_empty() and relative == "consumables/consumables.json":
			continue
		_write(relative, content)
	_write("core/load_order.json", "{\"groups\":[\"materials\",\"items\",\"loot\",\"consumables\"]}")


func _write(relative: String, content: String) -> void:
	var path := scratch.path_join(relative)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()


func _remove_tree(path: String) -> void:
	if path.is_empty() or not path.begins_with("user://consumable_registry_"):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for filename in directory.get_files():
		DirAccess.remove_absolute(path.path_join(filename))
	for child in directory.get_directories():
		_remove_tree(path.path_join(child))
	DirAccess.remove_absolute(path)
