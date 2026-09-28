extends SceneTree
## Exercises WorldItem ownership and PlayerInventoryComponent transfers.

const FactoryScript = preload("res://scripts/items/item_factory.gd")
const WorldItemScript = preload("res://scripts/items/world_item.gd")
const ComponentScript = preload("res://scripts/player/player_inventory_component.gd")

var checks := 0
var failures := 0
var groups: Dictionary[String, int] = {}


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String, group: String = "WorldItem unit") -> void:
	checks += 1
	groups[group] = groups.get(group, 0) + 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	var registry = root.get_node_or_null("DataRegistry")
	check(registry != null and registry.is_loaded(), "DataRegistry is ready")
	if registry == null or not registry.is_loaded():
		_finish()
		return
	var factory = FactoryScript.new(registry)
	var world_item: Variant = WorldItemScript.new()
	check(not world_item.has_item(), "new WorldItem is empty")
	check(not world_item.can_interact(null), "empty WorldItem cannot be interacted with")
	var item = factory.create_with_condition(&"kitchen_knife", 0.37)
	check(world_item.initialize(item), "valid ItemInstance initializes WorldItem")
	check(world_item.get_item() == item, "WorldItem stores the original reference")
	check(not world_item.initialize(factory.create(&"hammer")), "double initialization is rejected")
	check(world_item.get_item() == item, "failed reinitialization keeps original item")
	var interactor := Node2D.new()
	check(not world_item.can_interact(interactor), "non-interactor nodes are not eligible for pickup")
	interactor.free()
	var player_like := CharacterBody2D.new()
	player_like.set_script(load("res://scripts/player/player_controller.gd"))
	check(world_item.can_interact(player_like), "initialized WorldItem is eligible for Player interaction")
	check(world_item.take_item() == item, "take_item returns original runtime instance")
	check(not world_item.has_item() and world_item.take_item() == null, "take_item empties WorldItem safely")
	check(not world_item.initialize(factory.create(&"hammer")), "released WorldItem cannot be initialized a second time")
	player_like.free()
	world_item.free()

	var player_component: Variant = ComponentScript.new()
	player_component.world_item_scene = load("res://scenes/items/world_item.tscn")
	root.add_child(player_component)
	var inventory = player_component.get_inventory()
	var pickup: Variant = WorldItemScript.new()
	var pickup_item = factory.create_with_condition(&"water_bottle", 0.37)
	pickup.initialize(pickup_item)
	root.add_child(pickup)
	check(player_component.try_pickup_world_item(pickup), "valid pickup succeeds", "Pickup")
	check(inventory.get_item(pickup_item.instance_id) == pickup_item, "pickup transfers same instance reference", "Pickup")
	check(is_equal_approx(inventory.get_item(pickup_item.instance_id).condition, 0.37), "pickup preserves runtime condition", "Pickup")
	check(not pickup.has_item() and pickup.is_queued_for_deletion(), "successful pickup empties and removes WorldItem", "Pickup")
	check(is_equal_approx(inventory.get_total_weight(), 0.55), "pickup adds definition-backed weight", "Pickup")
	check(not player_component.try_pickup_world_item(pickup), "same WorldItem cannot be picked up twice", "Pickup")

	var heavy_component: Variant = ComponentScript.new()
	heavy_component.max_weight = 0.1
	heavy_component.world_item_scene = load("res://scenes/items/world_item.tscn")
	root.add_child(heavy_component)
	var blocked: Variant = WorldItemScript.new()
	var blocked_item = factory.create(&"water_bottle")
	blocked.initialize(blocked_item)
	root.add_child(blocked)
	check(not heavy_component.try_pickup_world_item(blocked), "capacity rejects pickup", "Pickup")
	check(blocked.get_item() == blocked_item and heavy_component.get_inventory().get_item_count() == 0, "failed pickup preserves both holders", "Pickup")

	var duplicate_inventory = player_component.get_inventory()
	var duplicate_world: Variant = WorldItemScript.new()
	var duplicate_item = factory.deserialize(pickup_item.serialize())
	duplicate_world.initialize(duplicate_item)
	root.add_child(duplicate_world)
	check(not player_component.try_pickup_world_item(duplicate_world), "duplicate instance ID rejects pickup", "Pickup")
	check(duplicate_world.get_item() == duplicate_item, "duplicate-ID failure preserves world item", "Pickup")

	var drop_parent := Node2D.new()
	root.add_child(drop_parent)
	var before_weight: float = inventory.get_total_weight()
	check(player_component.drop_item(pickup_item.instance_id, drop_parent, Vector2(123, 45)), "drop succeeds", "Drop")
	check(not inventory.has_item(pickup_item.instance_id), "drop removes inventory identity", "Drop")
	check(drop_parent.get_child_count() == 1, "drop adds one WorldItem to requested parent", "Drop")
	var dropped = drop_parent.get_child(0)
	check(dropped.has_item() and dropped.get_item() == pickup_item, "drop keeps exact ItemInstance reference", "Drop")
	check(dropped.global_position == Vector2(123, 45), "drop uses caller-provided world position", "Drop")
	check(is_equal_approx(dropped.get_item().condition, 0.37), "drop keeps condition unchanged", "Drop")
	check(inventory.get_total_weight() < before_weight, "drop reduces Inventory weight", "Drop")
	check(not player_component.drop_item("unknown", drop_parent, Vector2.ZERO), "unknown ID cannot be dropped", "Drop")
	check(not player_component.drop_item(pickup_item.instance_id, drop_parent, Vector2.ZERO), "already dropped identity cannot be dropped again", "Drop")

	var rollback_item = factory.create_with_condition(&"kitchen_knife", 0.37)
	inventory.add_item(rollback_item)
	player_component.world_item_scene = load("res://scenes/interactables/debug_interactable.tscn")
	check(not player_component.drop_item(rollback_item.instance_id, drop_parent, Vector2.ZERO), "invalid WorldItem scene rejects drop", "Drop")
	check(inventory.get_item(rollback_item.instance_id) == rollback_item and drop_parent.get_child_count() == 1, "invalid scene leaves inventory and world unchanged", "Drop")
	player_component.world_item_scene = load("res://scenes/items/world_item.tscn")
	var invalid_parent := Node.new()
	check(not player_component.drop_item(rollback_item.instance_id, invalid_parent, Vector2.ZERO), "invalid parent rejects drop", "Drop")
	invalid_parent.free()
	check(inventory.get_item(rollback_item.instance_id) == rollback_item, "invalid parent preserves Inventory")
	check(not player_component.drop_item(rollback_item.instance_id, drop_parent, Vector2(NAN, 0.0)), "non-finite drop position rejects drop", "Drop")
	check(inventory.get_item(rollback_item.instance_id) == rollback_item and drop_parent.get_child_count() == 1, "invalid drop position leaves both holders unchanged", "Drop")
	player_component.world_item_scene = load("res://tests/fixtures/runtime/failing_world_item.tscn")
	check(not player_component.drop_item(rollback_item.instance_id, drop_parent, Vector2.ZERO), "WorldItem initialization failure rejects drop", "Rollback")
	check(inventory.get_item(rollback_item.instance_id) == rollback_item and drop_parent.get_child_count() == 1, "failed WorldItem initialization restores original instance", "Rollback")
	player_component.world_item_scene = null
	check(not player_component.drop_item(rollback_item.instance_id, drop_parent, Vector2.ZERO), "missing WorldItem scene rejects drop", "Drop")
	check(inventory.get_item(rollback_item.instance_id) == rollback_item, "missing scene leaves Inventory unchanged", "Drop")

	var roundtrip = factory.create_with_condition(&"wooden_board", 0.37)
	var roundtrip_inventory: Variant = ComponentScript.new()
	roundtrip_inventory.world_item_scene = load("res://scenes/items/world_item.tscn")
	root.add_child(roundtrip_inventory)
	roundtrip_inventory.get_inventory().add_item(roundtrip)
	var roundtrip_start_weight: float = roundtrip_inventory.get_inventory().get_total_weight()
	var roundtrip_parent := Node2D.new()
	root.add_child(roundtrip_parent)
	check(roundtrip_inventory.drop_item(roundtrip.instance_id, roundtrip_parent, Vector2(70, 80)), "round-trip drop succeeds", "Round-trip")
	var roundtrip_world_item = roundtrip_parent.get_child(0)
	check(roundtrip_world_item.get_item() == roundtrip, "drop does not create a replacement ItemInstance", "Round-trip")
	check(roundtrip_inventory.try_pickup_world_item(roundtrip_world_item), "round-trip pickup succeeds", "Round-trip")
	var restored = roundtrip_inventory.get_inventory().get_item(roundtrip.instance_id)
	check(restored == roundtrip and restored.definition_id == &"wooden_board", "round-trip keeps reference and definition identity", "Round-trip")
	check(is_equal_approx(restored.condition, 0.37), "round-trip keeps non-default condition", "Round-trip")
	check(is_equal_approx(roundtrip_inventory.get_inventory().get_total_weight(), roundtrip_start_weight), "round-trip restores Inventory weight", "Round-trip")
	check(roundtrip_world_item.is_queued_for_deletion(), "picked-up dropped WorldItem is freed", "Round-trip")

	for node in [world_item, player_component, pickup, heavy_component, blocked, duplicate_world, drop_parent, roundtrip_inventory, roundtrip_parent]:
		if is_instance_valid(node):
			node.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	for group in groups:
		print("%s: %d checks" % [group, groups[group]])
	print("WorldItem foundation: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
