extends SceneTree

const REGISTRY_PATH := "res://autoload/data_registry.gd"
const FACTORY_PATH := "res://scripts/items/item_factory.gd"
const INVENTORY_PATH := "res://scripts/inventory/inventory.gd"
const STATE_PATH := "res://scripts/survival/survival_state.gd"
const SERVICE_PATH := "res://scripts/consumables/consumable_use_service.gd"
const EFFECT_FAILURE_STATE := preload("res://tests/fixtures/consumables/effect_failure_survival_state.gd")
const ROLLBACK_FAILURE_INVENTORY := preload("res://tests/fixtures/consumables/rollback_failure_inventory.gd")
const DEBUG_SCENE := "res://debug/test_scenes/consumable_test.tscn"

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	var registry = root.get_node("DataRegistry")
	var factory = load(FACTORY_PATH).new(registry)
	var inventory_script = load(INVENTORY_PATH)
	var state_script = load(STATE_PATH)
	var service_script = load(SERVICE_PATH)
	check(service_script != null, "ConsumableUseService exists")
	if service_script == null:
		_finish()
		return
	var service = service_script.new(registry)
	var inventory = inventory_script.new(registry)
	var state = state_script.new()
	state.set_hunger(70.0)
	state.set_thirst(80.0)
	var beans_a = factory.create_with_condition(&"canned_beans", 0.5)
	var beans_b = factory.create(&"canned_beans")
	var hammer = factory.create(&"hammer")
	inventory.add_item(beans_a)
	inventory.add_item(beans_b)
	inventory.add_item(hammer)
	check(service.use_item(inventory, state, beans_a.instance_id), "uses the requested food instance")
	check(is_equal_approx(state.get_hunger(), 45.0) and is_equal_approx(state.get_thirst(), 85.0), "food applies its configured hunger and positive thirst deltas")
	check(not inventory.has_item(beans_a.instance_id) and inventory.get_item(beans_b.instance_id) == beans_b, "consumes exact instance and preserves same-definition sibling")
	check(inventory.has_item(hammer.instance_id), "unrelated item remains in Inventory")

	var water = factory.create(&"water_bottle")
	inventory.add_item(water)
	state.set_hunger(70.0)
	state.set_thirst(80.0)
	check(service.use_item(inventory, state, water.instance_id), "uses drink instance")
	check(is_equal_approx(state.get_hunger(), 70.0) and is_equal_approx(state.get_thirst(), 45.0), "drink applies configured thirst only")
	check(not inventory.has_item(water.instance_id), "drink instance is consumed")

	state.set_hunger(10.0)
	state.set_thirst(10.0)
	var clamp_food = factory.create(&"canned_beans")
	var clamp_drink = factory.create(&"water_bottle")
	inventory.add_item(clamp_food)
	inventory.add_item(clamp_drink)
	check(service.use_item(inventory, state, clamp_food.instance_id) and is_zero_approx(state.get_hunger()), "hunger effect clamps at zero")
	check(service.use_item(inventory, state, clamp_drink.instance_id) and is_zero_approx(state.get_thirst()), "thirst effect clamps at zero")

	var before_state: Dictionary = state.serialize()
	check(not service.use_item(inventory, state, hammer.instance_id), "non-consumable use fails")
	check(inventory.has_item(hammer.instance_id) and state.serialize() == before_state, "non-consumable failure preserves both sides")
	check(not service.use_item(inventory, state, "missing_instance_id"), "unknown instance use fails")
	check(state.serialize() == before_state, "unknown instance leaves survival unchanged")
	check(not service.use_item(null, state, hammer.instance_id), "invalid Inventory is rejected")
	var invalid_inventory = inventory_script.new(registry, -1.0)
	check(not service.use_item(invalid_inventory, state, hammer.instance_id), "misconfigured Inventory is rejected")
	check(not service.use_item(inventory, null, hammer.instance_id), "invalid SurvivalState is rejected")

	var failure_state = EFFECT_FAILURE_STATE.new()
	failure_state.set_hunger(70.0)
	failure_state.set_thirst(80.0)
	var atomic_food = factory.create(&"canned_beans")
	inventory.add_item(atomic_food)
	check(not service.use_item(inventory, failure_state, atomic_food.instance_id), "effect application failure rejects use")
	check(inventory.get_item(atomic_food.instance_id) == atomic_food, "failed effect restores the same ItemInstance")
	check(is_equal_approx(failure_state.get_hunger(), 70.0) and is_equal_approx(failure_state.get_thirst(), 80.0), "failed effect restores both survival values")

	var rollback_inventory = ROLLBACK_FAILURE_INVENTORY.new(registry)
	var rollback_item = factory.create(&"canned_beans")
	rollback_inventory.add_item(rollback_item)
	rollback_inventory.reject_readd = true
	var catastrophic_state = EFFECT_FAILURE_STATE.new()
	catastrophic_state.set_hunger(70.0)
	catastrophic_state.set_thirst(80.0)
	check(not service.use_item(rollback_inventory, catastrophic_state, rollback_item.instance_id), "rollback-add failure remains a failed use")
	check(not service.get_errors().is_empty() and "rollback" in "; ".join(service.get_errors()).to_lower(), "rollback failure is explicitly diagnosable")
	check(is_equal_approx(catastrophic_state.get_hunger(), 70.0) and is_equal_approx(catastrophic_state.get_thirst(), 80.0), "even catastrophic Inventory rollback preserves SurvivalState")

	var isolated_registry = load(REGISTRY_PATH).new()
	check(isolated_registry.load_all_data("res://data"), "isolated Registry prepares for readiness test")
	var isolated_factory = load(FACTORY_PATH).new(isolated_registry)
	var isolated_inventory = inventory_script.new(isolated_registry)
	var isolated_item = isolated_factory.create(&"canned_beans")
	isolated_inventory.add_item(isolated_item)
	var isolated_state = state_script.new()
	isolated_state.set_hunger(40.0)
	check(not isolated_registry.load_all_data("res://missing_consumable_registry"), "invalid Registry reload makes it not ready")
	var isolated_service = service_script.new(isolated_registry)
	check(not isolated_service.use_item(isolated_inventory, isolated_state, isolated_item.instance_id), "Registry-not-ready use is rejected")
	check(isolated_inventory.has_item(isolated_item.instance_id) and is_equal_approx(isolated_state.get_hunger(), 40.0), "Registry-not-ready failure leaves both sides unchanged")
	isolated_registry.free()

	var scene = load(DEBUG_SCENE)
	check(scene != null, "Consumable debug scene can be loaded")
	if scene != null:
		var debug_scene: Variant = scene.instantiate()
		root.add_child(debug_scene)
		await process_frame
		var debug_inventory = debug_scene.get_node("Player/PlayerInventoryComponent").get_inventory()
		var debug_state: SurvivalState = debug_scene.get_node("Player/SurvivalComponent").state
		check(debug_inventory.get_item_count() == 3, "debug scene creates beans, water and a non-consumable")
		var advance_event := InputEventKey.new()
		advance_event.pressed = true
		advance_event.keycode = KEY_3
		var elapsed_before: float = root.get_node("GameClock").get_elapsed_game_seconds()
		debug_scene._unhandled_key_input(advance_event)
		check(root.get_node("GameClock").get_elapsed_game_seconds() >= elapsed_before + 3600.0, "debug key advances one game hour")
		var beans_event := InputEventKey.new()
		beans_event.pressed = true
		beans_event.keycode = KEY_1
		debug_scene._unhandled_key_input(beans_event)
		check(debug_inventory.get_item_count() == 2 and not debug_inventory.has_item(debug_scene._beans_instance_id), "debug key consumes the exact bean instance")
		var water_event := InputEventKey.new()
		water_event.pressed = true
		water_event.keycode = KEY_2
		debug_scene._unhandled_key_input(water_event)
		check(debug_inventory.get_item_count() == 1 and debug_inventory.has_item(debug_scene._hammer_instance_id), "debug key consumes water while preserving the hammer")
		var hunger_before_hammer: float = debug_state.get_hunger()
		var hammer_event := InputEventKey.new()
		hammer_event.pressed = true
		hammer_event.keycode = KEY_H
		debug_scene._unhandled_key_input(hammer_event)
		check(debug_inventory.get_item_count() == 1 and is_equal_approx(debug_state.get_hunger(), hunger_before_hammer), "debug non-consumable key leaves Inventory and survival unchanged")
		debug_scene.queue_free()
		await process_frame
	_finish()


func _finish() -> void:
	print("Consumable use service: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
