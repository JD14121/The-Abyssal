extends SceneTree
## Deterministic weighted loot resolution and transactional Inventory population.

const Resolver = preload("res://scripts/loot/loot_resolver.gd")
const Populator = preload("res://scripts/loot/container_loot_populator.gd")
const Factory = preload("res://scripts/items/item_factory.gd")
const FailingFactory = preload("res://tests/fixtures/runtime/failing_item_factory.gd")
const InventoryScript = preload("res://scripts/inventory/inventory.gd")
const FailingInventory = preload("res://tests/fixtures/runtime/failing_add_inventory.gd")
const ContainerScene = preload("res://scenes/interactables/container.tscn")
var checks := 0
var failures := 0
var registry: Node


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	registry = root.get_node("DataRegistry")
	var factory := Factory.new(registry)
	var resolver := Resolver.new(registry, factory)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var resolved: Dictionary = resolver.resolve(&"loot_test_fixed", rng)
	check(resolved.ok and resolved.items.size() == 6, "fixed quantity across rolls creates expected count")
	var seen := {}
	for item in resolved.items:
		check(item is ItemInstance and item.is_valid() and item.condition == 1.0, "generated item is valid with factory defaults")
		check(not seen.has(item.instance_id), "quantity creates independent UUIDs")
		seen[item.instance_id] = true
		check(registry.get_item(item.definition_id) != null, "generated definition resolves in registry")
	var empty: Dictionary = resolver.resolve(&"loot_test_empty", rng)
	check(empty.ok and empty.items.is_empty(), "empty loot entries resolve to no items")
	var zero: Dictionary = resolver.resolve(&"loot_test_zero_rolls", rng)
	check(zero.ok and zero.items.is_empty(), "zero rolls resolves to no items")
	check(not resolver.resolve(&"missing_loot", rng).ok, "unknown loot fails clearly")
	var first_rng := RandomNumberGenerator.new()
	var second_rng := RandomNumberGenerator.new()
	first_rng.seed = 20260928
	second_rng.seed = 20260928
	var sequence_a := _definitions(resolver.resolve(&"loot_test_kitchen", first_rng).items)
	var sequence_b := _definitions(resolver.resolve(&"loot_test_kitchen", second_rng).items)
	check(sequence_a == sequence_b, "same seed produces same definition sequence and quantity")
	var seed_sequences := {}
	for seed_value in [2, 5, 17, 29, 101, 2026, 31415, 65535]:
		var sample_rng := RandomNumberGenerator.new()
		sample_rng.seed = seed_value
		seed_sequences[str(_definitions(resolver.resolve(&"loot_test_kitchen", sample_rng).items))] = true
	check(seed_sequences.size() > 1, "different seeds can produce different group selections")
	var chance_rng := RandomNumberGenerator.new()
	chance_rng.seed = 1
	check(resolver.resolve(&"loot_test_chance_zero", chance_rng).items.is_empty(), "chance zero never creates an item")
	check(resolver.resolve(&"loot_test_chance_one", chance_rng).items.size() == 1, "chance one always creates an item")
	var failing_factory = FailingFactory.new(registry)
	failing_factory.fail_after_successes = 2
	var failing_resolver := Resolver.new(registry, failing_factory)
	var factory_rng := RandomNumberGenerator.new()
	factory_rng.seed = 44
	var failed_resolution: Dictionary = failing_resolver.resolve(&"loot_test_fixed", factory_rng)
	check(not failed_resolution.ok and failed_resolution.items.is_empty(), "ItemFactory failure discards partial resolution results")
	var weighted_rng := RandomNumberGenerator.new()
	weighted_rng.seed = 9
	var weighted: Dictionary = resolver.resolve(&"loot_test_weighted", weighted_rng)
	var common_count := 0
	for item in weighted.items:
		if item.definition_id == &"canned_beans":
			common_count += 1
	check(weighted.items.size() == 10000 and common_count > 8500 and common_count < 9500, "fixed-seed 9:1 weighted distribution stays within broad bounds")
	var container: WorldContainer = ContainerScene.instantiate()
	root.add_child(container)
	var inventory: Inventory = container.get_inventory()
	var old_item: ItemInstance = factory.create(&"hammer")
	inventory.add_item(old_item)
	var before_weight := inventory.get_total_weight()
	var populate_rng := RandomNumberGenerator.new()
	populate_rng.seed = 12345
	var populator := Populator.new(resolver)
	check(populator.populate(inventory, &"loot_test_fixed", populate_rng), "valid population succeeds")
	check(inventory.get_item_count() == 7 and inventory.has_item(old_item.instance_id), "existing content remains and generated count is added")
	check(is_equal_approx(inventory.get_total_weight(), before_weight + 2.7), "population adds expected combined weight")
	var limited := InventoryScript.new(registry, 0.5)
	var limited_old: ItemInstance = factory.create(&"clean_bandage")
	limited.add_item(limited_old)
	var capacity_rng := RandomNumberGenerator.new()
	capacity_rng.seed = 12345
	check(not populator.populate(limited, &"loot_test_fixed", capacity_rng), "capacity failure rejects population")
	check(limited.get_item_count() == 1 and limited.has_item(limited_old.instance_id), "capacity failure preserves original state")
	var failing = FailingInventory.new(registry, 0.0)
	var protected: ItemInstance = factory.create(&"hammer")
	failing.add_item(protected)
	failing.reject_after_successful_adds = 2
	var failure_rng := RandomNumberGenerator.new()
	failure_rng.seed = 12345
	check(not populator.populate(failing, &"loot_test_fixed", failure_rng), "unexpected mid-add rejection fails population")
	check(failing.get_item_count() == 1 and failing.has_item(protected.instance_id), "rollback removes only newly added loot")
	var empty_rng := RandomNumberGenerator.new()
	empty_rng.seed = 1
	var empty_before: int = inventory.get_item_count()
	check(populator.populate(inventory, &"loot_test_empty", empty_rng), "empty loot population succeeds")
	check(inventory.get_item_count() == empty_before, "empty population leaves existing contents unchanged")
	container.queue_free()
	await process_frame
	print("Loot resolution and population: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _definitions(items: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for item in items:
		result.append(item.definition_id)
	return result
