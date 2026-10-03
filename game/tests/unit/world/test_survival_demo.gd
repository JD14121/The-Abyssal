extends SceneTree
## Launch assembly smoke coverage for the bounded Survival Demo.

const DEMO_SCENE := "res://scenes/world/survival_demo.tscn"
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
	var world: Node2D = load(DEMO_SCENE).instantiate()
	world.world_seed = 78231
	root.add_child(world)
	await process_frame
	await physics_frame
	check(world.get_node_or_null("Player") != null and world.get_node_or_null("DemoHUD") != null, "demo scene assembles Player and HUD")
	check(world.world_grid != null and world.world_grid.is_valid(), "demo owns a valid world coordinate grid")
	check(world.get_node_or_null("House_01") != null and world.get_node_or_null("House_03") != null, "seeded map creates bounded buildings")
	var first_house: DemoBuilding = world.get_node("House_01") as DemoBuilding
	var view_size: Vector2 = get_root().get_viewport().get_visible_rect().size
	var half_view := view_size * 0.5
	var bounds := world.get_node("WorldGroundVisual").get("world_bounds") as Vector2
	var view_origin := Vector2(
		clampf(world.player.global_position.x - half_view.x, 0.0, bounds.x - view_size.x),
		clampf(world.player.global_position.y - half_view.y, 0.0, bounds.y - view_size.y))
	var house_rect := Rect2(first_house.global_position - first_house.building_size * 0.5, first_house.building_size)
	check(Rect2(view_origin, view_size).encloses(house_rect),
		"initial camera shows the full first house outline, entrance, windows and interior")
	var world_ground: Node2D = world.get_node_or_null("WorldGroundVisual") as Node2D
	check(world_ground != null and world_ground.z_index < world.get_node("House_01").z_index,
		"world ground is rendered behind visible Building shells")
	check(world.get_node("House_01").z_index < world.player.z_index,
		"building floor is rendered below Player so interior navigation remains visible")
	check(get_nodes_in_group("demo_lootable").size() == 9, "three room and furniture loot placements exist per building")
	check(get_nodes_in_group("demo_doors").size() == 6, "generated building exteriors and room dividers have doors")
	check(get_nodes_in_group("demo_windows").size() == 6, "generated houses have openable windows")
	check(world.get_population_controller().get_population_count() == 7, "seeded Zombie population respects the configured cap")
	for zombie: ZombieController in world.get_population_controller().get_zombies():
		check(zombie.global_position.distance_to(world.player.global_position) >= 400.0,
			"tutorial starts with each Zombie outside the immediate danger radius")
	var inventory = world.player.get_node("PlayerInventoryComponent").get_inventory()
	check(inventory.has_item(inventory.get_all_items()[0].instance_id), "Player starts with valid runtime Items")
	check(inventory.get_item_count() >= 15, "starting kit provides survival, melee and ranged supplies")
	check(world.extraction != null and world.extraction.is_inside_tree(), "safe extraction point is interactable")
	var stable_position: Vector2 = world.get_node("House_01").position
	var second: Node2D = load(DEMO_SCENE).instantiate()
	second.world_seed = 78231
	root.add_child(second)
	await process_frame
	await physics_frame
	check(second.get_node("House_01").position.is_equal_approx(stable_position), "same map seed reproduces building placement")
	world.queue_free()
	second.queue_free()
	await process_frame
	print("Survival demo assembly: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
