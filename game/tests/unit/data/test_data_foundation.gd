extends SceneTree

const FIXTURES := "res://tests/fixtures/data/"
var failures: int = 0
var checks: int = 0
var scratch: String


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	# A missing implementation is an explicit failed assertion during the red phase.
	if not FileAccess.file_exists("res://autoload/data_registry.gd"):
		check(false, "DataRegistry must load and expose validated definitions")
		_finish()
		return
	var script = load("res://autoload/data_registry.gd")
	var registry = script.new()
	check(not registry.is_loaded(), "new registry starts unloaded")
	check(registry.load_all_data(FIXTURES + "valid"), "valid fixtures load")
	check(registry.is_loaded(), "successful load becomes ready")
	check(registry.get_all_materials().size() == 2, "two fixture materials")
	check(registry.get_all_items().size() == 2, "two fixture items")
	check(registry.get_all_loot().size() == 6 and registry.has_loot(&"loot_test"), "fixture loot group loads after items")
	check(registry.has_material(&"steel") and registry.has_item(&"steel"), "IDs are unique per type")
	var knife = registry.get_item(&"knife")
	check(knife != null and knife.name == "Knife" and is_equal_approx(knife.mass, 0.25), "typed item values")
	check(knife.materials == [&"steel", &"wood"], "multiple material references")
	check(knife.source_file.ends_with("items/items.json"), "source metadata retained")
	check(is_equal_approx(registry.get_material(&"wood").density, 1.0), "default density")
	check(not registry.get_material(&"steel").flammable, "default flammability")
	check(registry.get_item(&"steel").mass == 0.0 and registry.get_item(&"steel").materials.is_empty(), "item defaults")
	check(registry.get_item(&"missing") == null and not registry.has_material(&"missing"), "unknown queries")
	var listing: Array = registry.get_all_items()
	listing.clear()
	check(registry.get_all_items().size() == 2, "listing cannot alter registry membership")
	var first_ids: Array = _ids(registry.get_all_items())
	check(registry.load_all_data(FIXTURES + "valid"), "repeat load succeeds")
	check(_ids(registry.get_all_items()) == first_ids, "repeat order deterministic")
	scratch = "user://data_foundation_test_%s" % Time.get_ticks_usec()
	var cases: Array = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + "invalid_cases.json"))
	for case in cases:
		_prepare()
		_write(case.group + "/invalid.json", JSON.stringify(case.entries))
		_expect_failure(registry, case.diagnostic, case.name)
		check(registry.load_all_data(FIXTURES + "valid"), "recover after " + case.name)
	_prepare()
	_write("items/broken.json", FileAccess.get_file_as_string(FIXTURES + "malformed.json"))
	_expect_failure(registry, "broken.json", "malformed JSON")
	var malformed_cases: Array = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + "malformed_cases.json"))
	for case in malformed_cases:
		_prepare()
		_write("items/boundary.json", case.text)
		_expect_failure(registry, "boundary.json", case.name)
	for groups in [["items", "materials"], ["materials"], ["materials", "materials"], ["../items"], null]:
		_prepare()
		_write("core/load_order.json", JSON.stringify({"groups": groups}))
		_expect_failure(registry, "groups", "invalid load order")
	_prepare()
	_remove_tree(scratch.path_join("materials"))
	_expect_failure(registry, "materials", "missing group")
	_prepare()
	_write("items/nested/extra.json", JSON.stringify({"type": "item", "id": "extra", "name": "Extra", "category": "custom_category", "future_field": 1}))
	check(registry.load_all_data(scratch), "single object and nested scan")
	check(registry.has_item(&"extra") and not registry.get_warnings().is_empty(), "unknown field warning only")
	check(_ids(registry.get_all_items()) == [&"knife", &"steel", &"extra"], "lexically sorted file traversal")
	_prepare()
	var bulk: Array = []
	for index in range(100):
		bulk.append({"type": "item", "id": "sample_%d" % index, "name": "Sample", "category": "misc", "materials": ["steel"]})
	_write("items/items.json", JSON.stringify(bulk))
	_write("loot/loot.json", JSON.stringify({"type":"loot", "id":"loot_bulk", "rolls":0, "entries":[]}))
	check(registry.load_all_data(scratch) and registry.get_all_items().size() == 100, "100 items load")
	check(registry.load_all_data(), "production data loads")
	check(registry.get_all_materials().size() >= 5 and registry.get_all_items().size() >= 10, "production minimum counts")
	check(registry.has_item(&"kitchen_knife"), "documented production query")
	registry.free()
	_remove_tree(scratch)
	_finish()


func _expect_failure(registry: Node, diagnostic: String, label: String) -> void:
	check(not registry.load_all_data(scratch), label + " rejected")
	check(not registry.is_loaded(), label + " not ready")
	check(registry.get_all_items().is_empty() and registry.get_all_materials().is_empty(), label + " no partial or stale data")
	check(registry.get_item(&"knife") == null and not registry.has_material(&"steel"), label + " lookup blocked")
	check("\n".join(registry.get_errors()).to_lower().contains(diagnostic.to_lower()), label + " actionable error")


func _ids(definitions: Array) -> Array:
	var result: Array = []
	for definition in definitions:
		result.append(definition.id)
	return result


func _prepare() -> void:
	_remove_tree(scratch)
	for relative in ["core/load_order.json", "materials/materials.json", "items/items.json", "loot/loot.json"]:
		_write(relative, FileAccess.get_file_as_string(FIXTURES + "valid/" + relative))


func _write(relative: String, content: String) -> void:
	var path := scratch.path_join(relative)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()


func _remove_tree(path: String) -> void:
	if path.is_empty() or not path.begins_with("user://data_foundation_test_"):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for filename in directory.get_files():
		DirAccess.remove_absolute(path.path_join(filename))
	for subdirectory in directory.get_directories():
		_remove_tree(path.path_join(subdirectory))
	DirAccess.remove_absolute(path)


func _finish() -> void:
	print("Data foundation: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
