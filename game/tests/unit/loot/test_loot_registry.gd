extends SceneTree
## Static loot schema, registry atomicity, and load recovery.

const VALID := "res://tests/fixtures/data/valid/"
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
	var registry = load("res://autoload/data_registry.gd").new()
	check(registry.load_all_data(VALID), "valid loot fixtures load")
	check(registry.get_all_loot().size() == 6 and registry.has_loot(&"loot_test"), "loot definitions are indexed")
	check(registry.get_loot(&"loot_test").entries.size() == 1, "loot entry parsed")
	check(registry.get_loot(&"missing") == null, "missing loot lookup returns null")
	var invalid := [
		{"name":"invalid ID", "id":"Loot_Bad", "rolls":1, "entries":[]},
		{"name":"missing item reference", "id":"bad_ref", "rolls":1, "entries":[{"item_id":"missing_item", "weight":1}]},
		{"name":"zero weight", "id":"bad_weight", "rolls":1, "entries":[{"item_id":"knife", "weight":0}]},
		{"name":"negative weight", "id":"bad_weight", "rolls":1, "entries":[{"item_id":"knife", "weight":-1}]},
		{"name":"invalid chance", "id":"bad_chance", "rolls":1, "entries":[{"item_id":"knife", "weight":1, "chance":1.1}]},
		{"name":"invalid quantity", "id":"bad_quantity", "rolls":1, "entries":[{"item_id":"knife", "weight":1, "min_quantity":2, "max_quantity":1}]},
		{"name":"missing entries", "id":"bad_entries", "rolls":1},
	]
	for invalid_case in invalid:
		_prepare()
		_write("loot/invalid.json", JSON.stringify({"type":"loot", "id":invalid_case.id, "rolls":invalid_case.rolls, "entries":invalid_case.get("entries", null)}))
		if invalid_case.name == "missing entries":
			_write("loot/invalid.json", JSON.stringify({"type":"loot", "id":invalid_case.id, "rolls":invalid_case.rolls}))
		_expect_failure(registry, invalid_case.name)
	check(registry.load_all_data(VALID), "valid reload recovers all registry groups")
	_prepare()
	var duplicate := [{"type":"loot","id":"same_loot","rolls":0,"entries":[]},{"type":"loot","id":"same_loot","rolls":0,"entries":[]}]
	_write("loot/duplicate.json", JSON.stringify(duplicate))
	_expect_failure(registry, "duplicate loot ID")
	check(registry.load_all_data(VALID), "registry recovers after duplicate loot ID")
	registry.free()
	_remove_tree(scratch)
	print("Loot registry: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _expect_failure(registry: Node, label: String) -> void:
	check(not registry.load_all_data(scratch), label + " rejected")
	check(not registry.is_loaded(), label + " clears ready state")
	check(registry.get_all_materials().is_empty() and registry.get_all_items().is_empty() and registry.get_all_loot().is_empty(), label + " clears every registry")
	check(not registry.get_errors().is_empty(), label + " reports an actionable error")


func _prepare() -> void:
	if scratch.is_empty():
		scratch = "user://loot_registry_%s" % Time.get_ticks_usec()
	_remove_tree(scratch)
	for relative in ["core/load_order.json", "materials/materials.json", "items/items.json", "loot/loot.json"]:
		_write(relative, FileAccess.get_file_as_string(VALID + relative))


func _write(relative: String, content: String) -> void:
	var path := scratch.path_join(relative)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()


func _remove_tree(path: String) -> void:
	if path.is_empty() or not path.begins_with("user://loot_registry_"):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for filename in directory.get_files():
		DirAccess.remove_absolute(path.path_join(filename))
	for child in directory.get_directories():
		_remove_tree(path.path_join(child))
	DirAccess.remove_absolute(path)
