extends SceneTree
## Real factories and registries; no mocks or production data mutation.

const Registry = preload("res://autoload/data_registry.gd")
const FIXTURES := "res://tests/fixtures/runtime/"
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	if not FileAccess.file_exists("res://scripts/items/item_factory.gd"):
		check(false, "ItemFactory must create independent serializable runtime items")
		_finish()
		return
	var factory_script = load("res://scripts/items/item_factory.gd")
	if factory_script == null or not factory_script.can_instantiate():
		check(false, "ItemFactory must compile")
		_finish()
		return
	var registry := Registry.new()
	var factory = factory_script.new(registry)
	var valid_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + "valid_item_instance.json"))
	check(factory.create(&"kitchen_knife") == null, "creation rejects unloaded registry")
	check("\n".join(factory.get_errors()).contains("registry"), "unloaded error is actionable")
	check(factory.deserialize(valid_data) == null, "restore rejects unloaded registry")
	check(registry.load_all_data(), "real production registry loads")
	var definition = registry.get_item(&"kitchen_knife")
	var static_before: Array = [definition.id, definition.name, definition.category, definition.mass, definition.materials.duplicate(), definition.source_file]
	var first = factory.create(&"kitchen_knife")
	var second = factory.create(&"kitchen_knife")
	check(first != null and second != null, "valid creation")
	if first == null or second == null:
		registry.free()
		_finish()
		return
	check(first is RefCounted and not first is Node, "instance is plain RefCounted data")
	check(first.is_valid() and first.condition == 1.0, "valid default state")
	check(first.definition_id == &"kitchen_knife", "stable definition ID")
	check(first.instance_id != first.definition_id and first.instance_id != second.instance_id, "distinct runtime identity")
	check(first.get_definition() == definition and second.get_definition() == definition, "shared original definition")
	check(first.set_condition(0.5), "valid mutation accepted")
	check(first.condition == 0.5 and second.condition == 1.0, "instance states independent")
	check(static_before == [definition.id, definition.name, definition.category, definition.mass, definition.materials, definition.source_file], "runtime does not mutate definition")
	var first_id: String = first.instance_id
	first.instance_id = "replacement"
	first.definition_id = &"hammer"
	check(first.instance_id == first_id and first.definition_id == &"kitchen_knife", "identity properties cannot be reassigned")
	for value in [-0.1, 1.1, NAN, INF, -INF, "good", true, null]:
		check(not first.set_condition(value), "invalid mutation rejected: " + str(value))
		check(first.condition == 0.5, "rejected mutation leaves previous value")
		check(factory.create_with_condition(&"kitchen_knife", value) == null, "invalid initial condition rejected")
	first.condition = -1.0
	check(first.condition == 0.5, "direct property assignment cannot bypass range checks")
	for value in [0, 1, 0.73]:
		var instance = factory.create_with_condition(&"kitchen_knife", value)
		check(instance != null and is_equal_approx(instance.condition, float(value)), "condition endpoints and fraction accepted")
	check(factory.create(&"nonexistent_item") == null, "unknown definition rejected")
	check("\n".join(factory.get_errors()).contains("nonexistent_item"), "unknown definition error contains ID")
	check(factory.create(&"") == null, "empty definition rejected")
	check(factory.create(&"steel") == null, "material ID is not an item definition")
	var payload: Dictionary = first.serialize()
	check(payload.size() == 3 and payload.has_all(["instance_id", "definition_id", "condition"]), "only identity and mutable state serialized")
	check(typeof(payload.instance_id) == TYPE_STRING and typeof(payload.definition_id) == TYPE_STRING and typeof(payload.condition) == TYPE_FLOAT, "JSON primitive types, not StringName or objects")
	var parsed: Variant = JSON.parse_string(JSON.stringify(payload))
	var restored = factory.deserialize(parsed)
	check(restored != null, "actual JSON round-trip")
	if restored != null:
		check(restored.instance_id == first.instance_id and restored.definition_id == first.definition_id and restored.condition == first.condition, "round-trip preserves identity and state")
		check(restored != first and restored.get_definition() == definition, "restore makes new object sharing definition")
		restored.set_condition(0.2)
		check(first.condition == 0.5, "restored mutable state remains independent")
	payload.condition = 0.1
	check(first.condition == 0.5, "serialized output is detached")
	var fixture_instance = factory.deserialize(valid_data)
	check(fixture_instance != null and fixture_instance.instance_id == "550e8400-e29b-41d4-a716-446655440000" and is_equal_approx(fixture_instance.condition, 0.73), "hand-authored fixture restores original ID")
	valid_data.condition = 0.25
	check(is_equal_approx(fixture_instance.condition, 0.73), "restored state does not alias input dictionary")
	var cases: Array = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + "invalid_item_instances.json"))
	for case in cases:
		check(factory.deserialize(case.data) == null, case.name + " rejected")
		check("\n".join(factory.get_errors()).contains(case.field), case.name + " diagnostic names field")
	for value in [NAN, INF, -INF]:
		var invalid: Dictionary = valid_data.duplicate()
		invalid.condition = value
		check(factory.deserialize(invalid) == null, "non-finite serialized condition rejected")
	var legacy: Dictionary = valid_data.duplicate()
	legacy.instance_id = "existing-runtime-identity"
	check(factory.deserialize(legacy).instance_id == "existing-runtime-identity", "restore accepts opaque nonempty ID without regeneration")
	check(factory.get_errors().is_empty(), "success clears old diagnostics")
	_stress(factory, factory_script.new(registry))
	# Reload the real registry with a different valid dataset: old definitions vanish.
	check(registry.load_all_data("res://tests/fixtures/data/valid"), "reload alternate definitions")
	check(first.get_definition() == null and not first.is_valid(), "instance resolves current registry, not stale definition cache")
	check(first.serialize().is_empty(), "invalid instance cannot serialize as valid state")
	check(factory.deserialize(first.serialize()) == null, "invalid serialized state cannot restore")
	check(registry.load_all_data(), "restore production registry")
	check(first.is_valid() and first.get_definition() == registry.get_item(&"kitchen_knife"), "instance follows successful reload")
	check(not registry.load_all_data("res://tests/fixtures/runtime/missing_root"), "simulate data failure")
	check(factory.create(&"kitchen_knife") == null and factory.deserialize(valid_data) == null, "failed registry blocks create and restore")
	registry.free()
	check(first.get_definition() == null and not first.is_valid(), "freed registry fails safely")
	check(factory.create(&"kitchen_knife") == null, "factory handles freed registry")
	var missing_factory = factory_script.new(null)
	check(missing_factory.create(&"kitchen_knife") == null, "factory handles absent registry")
	_finish()


func _stress(first_factory: RefCounted, second_factory: RefCounted) -> void:
	var ids: Dictionary = {}
	var duplicates: int = 0
	var invalid: int = 0
	var instances: Array = []
	var uuid := RegEx.create_from_string("^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$")
	for index in range(10000):
		var factory: RefCounted = first_factory if index % 2 == 0 else second_factory
		var instance = factory.create(&"kitchen_knife")
		if instance == null:
			invalid += 1
			continue
		instances.append(instance)
		if ids.has(instance.instance_id):
			duplicates += 1
		if uuid.search(instance.instance_id) == null:
			invalid += 1
		ids[instance.instance_id] = true
	check(instances.size() == 10000 and ids.size() == 10000 and duplicates == 0 and invalid == 0, "10000 live instances across factories have unique UUID v4 IDs")
	print("Runtime IDs: %d instances; %d duplicates; %d invalid" % [instances.size(), duplicates, invalid])


func _finish() -> void:
	print("Runtime foundation: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
