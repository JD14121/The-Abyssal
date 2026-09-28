extends SceneTree
## Optional-scale check for 1000 independent instances and serialized reconstruction.

const RegistryScript = preload("res://autoload/data_registry.gd")
const FactoryScript = preload("res://scripts/items/item_factory.gd")
const InventoryScript = preload("res://scripts/inventory/inventory.gd")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var registry = RegistryScript.new()
	if not registry.load_all_data():
		_fail("registry loads")
		return
	var factory = FactoryScript.new(registry)
	var inventory = InventoryScript.new(registry)
	var ids: Dictionary = {}
	for index in range(1000):
		var item = factory.create(&"kitchen_knife")
		if item == null or ids.has(item.instance_id) or not inventory.add_item(item):
			failures += 1
		else:
			ids[item.instance_id] = true
		checks += 1
	var expected_weight := 250.0
	var state: Dictionary = inventory.serialize()
	var restored = InventoryScript.new(registry)
	var restore_ok: bool = restored.deserialize(JSON.parse_string(JSON.stringify(state)), factory)
	var all_ids_preserved: bool = restore_ok and restored.get_item_count() == 1000
	if all_ids_preserved:
		for id in ids:
			if not restored.has_item(id):
				all_ids_preserved = false
				break
	_check(inventory.get_item_count() == 1000 and ids.size() == 1000, "1000 distinct instances retained")
	_check(is_equal_approx(inventory.get_total_weight(), expected_weight), "1000-item weight is correct")
	_check(restore_ok and all_ids_preserved, "1000-item JSON round-trip preserves IDs")
	registry.free()
	print("Inventory stress: 1000 instances, %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _fail(message: String) -> void:
	printerr("FAIL: " + message)
	failures += 1
	quit(1)
