extends SceneTree
## Exercises the real registry/factory/item pipeline and Inventory runtime contract.

const RegistryScript = preload("res://autoload/data_registry.gd")
const FactoryScript = preload("res://scripts/items/item_factory.gd")
const RuntimeItemScript = preload("res://scripts/items/item_instance.gd")
const INVENTORY_PATH := "res://scripts/inventory/inventory.gd"

var core_checks: int = 0
var serialization_checks: int = 0
var invalid_checks: int = 0
var failures: int = 0
var registry: Node
var factory: RefCounted


func _initialize() -> void:
	call_deferred("_run")


func check(group: String, condition: bool, message: String) -> void:
	match group:
		"core": core_checks += 1
		"serialization": serialization_checks += 1
		"invalid": invalid_checks += 1
	if not condition:
		failures += 1
		printerr("FAIL [%s]: %s" % [group, message])


func _run() -> void:
	var inventory_script = load(INVENTORY_PATH)
	check("core", inventory_script != null, "Inventory runtime script exists")
	if inventory_script == null:
		_finish()
		return
	registry = RegistryScript.new()
	check("core", registry.load_all_data(), "production definitions load")
	factory = FactoryScript.new(registry)
	_core_cases(inventory_script)
	_serialization_cases(inventory_script)
	_invalid_cases(inventory_script)
	_registry_lifecycle_case(inventory_script)
	registry.free()
	_finish()


func _core_cases(inventory_script: Script) -> void:
	var inventory = inventory_script.new(registry)
	check("core", inventory is RefCounted and not inventory is Node, "Inventory is plain runtime data")
	check("core", inventory.get_item_count() == 0, "new Inventory is empty")
	check("core", is_zero_approx(inventory.get_total_weight()), "empty Inventory weight is zero")
	var knife = factory.create(&"kitchen_knife")
	var beans_a = factory.create_with_condition(&"canned_beans", 0.4)
	var beans_b = factory.create_with_condition(&"canned_beans", 0.9)
	check("core", inventory.add_item(knife), "valid ItemInstance adds")
	check("core", inventory.has_item(knife.instance_id), "contains checks instance ID")
	check("core", inventory.get_item(knife.instance_id) == knife, "lookup returns same ItemInstance reference")
	check("core", not inventory.add_item(knife), "duplicate instance is rejected")
	check("core", inventory.add_item(beans_a) and inventory.add_item(beans_b), "different instances of same definition are accepted")
	check("core", inventory.get_item_count() == 3, "count reflects unique instances")
	check("core", not is_equal_approx(beans_a.condition, beans_b.condition), "same-definition runtime state remains independent")
	check("core", is_equal_approx(inventory.get_total_weight(), 1.15), "weight uses live ItemDefinition masses")
	var item_copy: Array = inventory.get_all_items()
	item_copy.clear()
	check("core", inventory.get_item_count() == 3, "contents accessor returns a detached array")
	var removed = inventory.remove_item(beans_a.instance_id)
	check("core", removed == beans_a and not inventory.has_item(beans_a.instance_id), "remove returns item and removes its identity")
	check("core", is_equal_approx(inventory.get_total_weight(), 0.7), "remove updates calculated weight")
	check("core", inventory.remove_item("missing-instance") == null, "unknown removal fails safely")
	check("core", inventory.get_item_count() == 2, "unknown removal preserves contents")
	var exact = inventory_script.new(registry, 0.7)
	check("core", exact.add_item(knife) and exact.add_item(beans_b), "capacity allows exact weight")
	var too_heavy = factory.create(&"water_bottle")
	var before_count: int = exact.get_item_count()
	var before_weight: float = exact.get_total_weight()
	check("core", not exact.add_item(too_heavy), "capacity rejects over-weight item")
	check("core", exact.get_item_count() == before_count and is_equal_approx(exact.get_total_weight(), before_weight), "failed add is atomic")
	var unlimited = inventory_script.new(registry, 0.0)
	check("core", unlimited.add_item(too_heavy), "zero capacity means unlimited")
	var invalid_instance = RuntimeItemScript.new(registry, "invalid-id", &"unknown_item", 1.0)
	check("core", not inventory.add_item(null), "null item rejected")
	check("core", not inventory.add_item("not-an-item"), "wrong runtime type rejected")
	check("core", not inventory.add_item(invalid_instance), "invalid ItemInstance rejected")
	check("core", inventory.get_item_count() == 2, "invalid adds do not change existing Inventory")
	var invalid_capacity = inventory_script.new(registry, -1.0)
	check("core", not invalid_capacity.add_item(factory.create(&"hammer")), "negative constructor capacity rejects operations")
	check("core", is_nan(invalid_capacity.get_total_weight()), "invalid Inventory configuration reports invalid weight")


func _serialization_cases(inventory_script: Script) -> void:
	var empty = inventory_script.new(registry, 4.5)
	var empty_data: Dictionary = empty.serialize()
	check("serialization", empty_data.size() == 2 and empty_data.items.is_empty(), "empty Inventory serializes")
	check("serialization", typeof(empty_data.max_weight) == TYPE_FLOAT, "capacity serializes as a JSON number")
	var first = factory.create_with_condition(&"kitchen_knife", 0.73)
	var second = factory.create_with_condition(&"water_bottle", 0.5)
	var source = inventory_script.new(registry, 2.0)
	source.add_item(first)
	source.add_item(second)
	var data: Dictionary = source.serialize()
	check("serialization", data.items.size() == 2 and data.max_weight == 2.0, "populated state contains capacity and instance records")
	var record: Dictionary = data.items[0]
	check("serialization", record.keys().size() == 3 and record.has_all(["instance_id", "definition_id", "condition"]), "ItemInstance serialization is reused without static fields")
	for prohibited in ["name", "mass", "materials", "category"]:
		check("serialization", not record.has(prohibited) and not data.has(prohibited), "static field is absent: " + prohibited)
	var json_data: Variant = JSON.parse_string(JSON.stringify(data))
	var restored = inventory_script.new(registry)
	check("serialization", restored.deserialize(json_data, factory), "valid JSON-compatible state restores")
	check("serialization", restored.get_item_count() == 2 and is_equal_approx(restored.get_total_weight(), source.get_total_weight()), "round-trip preserves count and weight")
	check("serialization", is_equal_approx(restored.max_weight, 2.0), "round-trip preserves configured capacity")
	var restored_first = restored.get_item(first.instance_id)
	check("serialization", restored_first != null and restored_first != first, "restore creates new ItemInstance objects")
	check("serialization", restored_first.instance_id == first.instance_id and restored_first.definition_id == first.definition_id and is_equal_approx(restored_first.condition, first.condition), "round-trip preserves identity and mutable state")


func _invalid_cases(inventory_script: Script) -> void:
	var seed_item = factory.create(&"hammer")
	var baseline = inventory_script.new(registry)
	baseline.add_item(seed_item)
	var valid_item = factory.create(&"kitchen_knife").serialize()
	var duplicate_id: Dictionary = {"max_weight": 0.0, "items": [valid_item, valid_item.duplicate()]}
	_expect_restore_failure(inventory_script, baseline, duplicate_id, "duplicate instance_id", "duplicate restored identity")
	var unknown_definition: Dictionary = valid_item.duplicate()
	unknown_definition.definition_id = "unknown_item"
	_expect_restore_failure(inventory_script, baseline, {"max_weight": 0.0, "items": [unknown_definition]}, "definition_id", "unknown definition")
	var invalid_condition: Dictionary = valid_item.duplicate()
	invalid_condition.condition = 1.1
	_expect_restore_failure(inventory_script, baseline, {"max_weight": 0.0, "items": [invalid_condition]}, "condition", "invalid ItemInstance state")
	for bad_data in [
		{"max_weight": 0.0},
		{"max_weight": 0.0, "items": "not_array"},
		{"max_weight": 0.0, "items": [], "future": 1},
		{"max_weight": -1.0, "items": []},
		{"max_weight": true, "items": []},
		{"max_weight": "2", "items": []},
		{"max_weight": NAN, "items": []},
		{"max_weight": 0.1, "items": [valid_item, factory.create(&"wooden_board").serialize()]},
	]:
		_expect_restore_failure(inventory_script, baseline, bad_data, "", "invalid Inventory state")
	var partial: Dictionary = {"max_weight": 0.0, "items": [valid_item, {"instance_id": "broken"}]}
	_expect_restore_failure(inventory_script, baseline, partial, "items[1]", "all-or-nothing restore")
	var valid_again: Dictionary = {"max_weight": 0.0, "items": [valid_item]}
	check("invalid", baseline.deserialize(valid_again, factory), "valid restore succeeds after rejected payloads")
	check("invalid", baseline.get_errors().is_empty(), "successful operation clears diagnostics")


func _registry_lifecycle_case(inventory_script: Script) -> void:
	var inventory = inventory_script.new(registry)
	var knife = factory.create(&"kitchen_knife")
	check("core", inventory.add_item(knife), "valid item enters inventory before registry reload")
	check("core", registry.load_all_data("res://tests/fixtures/data/valid"), "registry can reload without production definition")
	check("core", is_nan(inventory.get_total_weight()), "missing definition fails weight calculation")
	check("core", "\n".join(inventory.get_errors()).contains("kitchen_knife"), "missing definition error identifies stable ID")
	check("core", registry.load_all_data(), "production definitions restore after lifecycle check")


func _expect_restore_failure(inventory_script: Script, inventory, data: Variant, diagnostic: String, label: String) -> void:
	var before_count: int = inventory.get_item_count()
	var before_id: String = inventory.get_all_items()[0].instance_id
	check("invalid", not inventory.deserialize(data, factory), label + " rejected")
	check("invalid", inventory.get_item_count() == before_count and inventory.has_item(before_id), label + " leaves old state untouched")
	if not diagnostic.is_empty():
		check("invalid", "\n".join(inventory.get_errors()).to_lower().contains(diagnostic.to_lower()), label + " diagnostic includes context")


func _finish() -> void:
	print("Inventory core: %d checks" % core_checks)
	print("Inventory serialization: %d checks" % serialization_checks)
	print("Inventory invalid-data: %d checks" % invalid_checks)
	print("Inventory foundation: %d checks, %d failures" % [core_checks + serialization_checks + invalid_checks, failures])
	quit(0 if failures == 0 else 1)
