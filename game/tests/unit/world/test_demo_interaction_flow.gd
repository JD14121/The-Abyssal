extends SceneTree
## Exercises the generated Demo's door, window and melee target wiring.

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
	await _frames(5)
	var player: CharacterBody2D = world.player
	var interaction = player.get_node("InteractionComponent")
	var zombies: Array = world.get_population_controller().get_zombies()
	var inactive_zombie: ZombieController = zombies.back()
	var inactive_zombie_shape: CollisionShape2D = inactive_zombie.get_node("CollisionShape2D")
	inactive_zombie.global_position = Vector2(1700.0, 1100.0)
	inactive_zombie.set_simulation_tier(ZombieController.SimulationTier.DORMANT)
	check((player.collision_mask & (1 << 3)) != 0,
		"Player collision mask includes the Creature layer even while Zombies are dormant")
	check(not inactive_zombie_shape.disabled,
		"dormant Zombie retains its physical collision shape before AI activation")
	var door: DemoDoor
	for candidate: DemoDoor in get_nodes_in_group("demo_doors"):
		if candidate.position.y > 80.0:
			door = candidate
			break
	player.global_position = door.global_position + Vector2(0.0, 40.0)
	await _frames(5)
	interaction.refresh_target()
	check(interaction.get_current_target() == door, "nearby exterior Door is the selected interaction target")
	check(interaction.try_interact() and door.is_open, "E interaction opens the generated exterior Door")
	await _frames(2)
	var door_shape: CollisionShape2D = door.get_node("DoorBody/CollisionShape2D")
	check(door_shape.disabled, "open Door clears its blocking collision")
	Input.action_press(&"move_up")
	await _frames(30)
	Input.action_release(&"move_up")
	check(player.global_position.y < door.global_position.y - 12.0,
		"Player can physically pass through the opened exterior Door (player y=%0.1f, door y=%0.1f)" % [player.global_position.y, door.global_position.y])

	var window: DemoWindow = get_nodes_in_group("demo_windows")[0]
	player.global_position = window.global_position + Vector2(-40.0, 0.0)
	await _frames(5)
	interaction.refresh_target()
	check(interaction.get_current_target() == window, "nearby Window is the selected interaction target")
	check(interaction.try_interact() and window.is_open, "E interaction opens an intact Window")
	await _frames(2)
	var window_shape: CollisionShape2D = window.get_node("WindowBody/CollisionShape2D")
	check(window_shape.disabled, "open Window clears its blocking collision")
	check(interaction.try_interact() and not window.is_open, "interacting again closes the intact Window")
	await _frames(2)
	check(not window_shape.disabled, "closed intact Window restores its blocking collision")

	var melee = player.get_node("PlayerMeleeComponent")
	player.global_position = window.global_position + Vector2(0.0, -28.0)
	player.set_facing_direction(Vector2.DOWN)
	await _frames(5)
	var melee_area: Area2D = melee.get_node("MeleeTargetArea")
	check(melee.get_candidate_count() > 0, "equipped melee Area detects nearby damageable Window target")
	var window_health = window.get_damage_receiver()
	var health_before: float = window_health.get_current_health()
	check(melee.try_attack(), "equipped melee weapon can strike a generated Window")
	check(window_health.get_current_health() < health_before, "generated Window loses health from melee strike")
	for _hit_index in 12:
		if window_health.is_depleted():
			break
		melee.physics_step(2.0, false)
		melee.try_attack()
	await _frames(2)
	check(window.is_broken and window_shape.disabled, "destroyed Window remains visibly broken and nonblocking")

	var hud: CanvasLayer = world.get_node("DemoHUD")
	var zombie: ZombieController = world.get_population_controller().get_zombies()[0]
	var zombie_health = zombie.get_damage_receiver()
	player.global_position = door.global_position + Vector2(0.0, 40.0)
	await _frames(5)
	interaction.refresh_target()
	hud.set("_tutorial_index", 6)
	hud._update_tutorial_card()
	hud._process(0.0)
	check(hud.get("prompt_label").text.is_empty(),
		"melee tutorial suppresses nearby Door and Window prompts that reuse the Space attack key")
	check(hud.get("action_hint_label").text == "ATTACK: SPACE",
		"melee tutorial uses a concise attack instruction")
	var tutorial_panel: PanelContainer = hud.get("tutorial_panel")
	check(tutorial_panel.size.x <= 280.0 and tutorial_panel.size.y <= 48.0,
		"tutorial card stays compact and clear of most of the play area")
	var safety_release_count := [0]
	hud.tutorial_safety_released.connect(func() -> void: safety_release_count[0] += 1)
	hud.set("_tutorial_index", 6)
	hud._on_melee_attack_landed(zombie)
	check(hud.get("_tutorial_index") == 6 and safety_release_count[0] == 0,
		"tutorial combat keeps the training Zombie safe after a nonlethal hit")
	var fatal_hit := DamageEvent.new(player, zombie, zombie_health.get_current_health())
	check(zombie_health.receive_damage(fatal_hit), "tutorial combat fixture can deplete its Zombie")
	hud._on_melee_attack_landed(zombie)
	check(hud.get("_tutorial_index") == 7 and safety_release_count[0] == 1,
		"tutorial combat advances and releases the next threat only after a kill")
	var inventory = player.get_node("PlayerInventoryComponent").get_inventory()
	var pistol: ItemInstance
	for item: ItemInstance in inventory.get_all_items():
		if item.definition_id == &"pipe_pistol":
			pistol = item
			break
	var ranged = player.get_node("RangedWeaponComponent")
	var equipment = player.get_node("EquipmentComponent")
	var ranged_zombie: ZombieController = world.get_population_controller().get_zombies()[1]
	ranged_zombie.set_ai_enabled(false)
	player.global_position = Vector2(900.0, 900.0)
	player.set_facing_direction(Vector2.RIGHT)
	ranged_zombie.global_position = Vector2(1110.0, 900.0)
	check(pistol != null and equipment.equip_item(&"hands", pistol.instance_id),
		"Demo can equip the Pipe Pistol for ranged target practice")
	check(ranged.reload(), "Demo Pipe Pistol reloads from its carried ammunition")
	ranged._process(5.0)
	hud._update_status()
	check(hud.get("status_label").text.contains("HANDS PIPE PISTOL") and hud.get("status_label").text.contains("AMMO 6/6"),
		"HUD identifies equipped firearm and loaded ammunition")
	var ranged_health = ranged_zombie.get_damage_receiver()
	var ranged_death_count := [0]
	ranged_health.health_depleted.connect(func() -> void: ranged_death_count[0] += 1)
	for shot_index in 4:
		if ranged_health.is_depleted():
			break
		if ranged.cooldown_remaining > 0.0:
			ranged._process(5.0)
		check(ranged.fire(), "Demo firearm shot %d launches" % (shot_index + 1))
		await _frames(20)
	await process_frame
	check(ranged_death_count[0] == 1,
		"repeated Demo firearm shots deplete one Zombie (death events: %d)" % ranged_death_count[0])
	var ranged_corpse_exists := false
	for corpse: Corpse in root.find_children("*", "Corpse", true, false):
		if corpse.global_position.is_equal_approx(Vector2(1110.0, 900.0)):
			ranged_corpse_exists = true
	check(ranged_corpse_exists, "Demo firearm kill places its Corpse at the target's death position")
	var clip_root := Control.new()
	clip_root.size = Vector2(200.0, 200.0)
	root.add_child(clip_root)
	var scroll_viewport := Control.new()
	scroll_viewport.position = Vector2(20.0, 20.0)
	scroll_viewport.size = Vector2(100.0, 100.0)
	scroll_viewport.clip_contents = true
	clip_root.add_child(scroll_viewport)
	var clipped_target := Control.new()
	clipped_target.position = Vector2(0.0, 80.0)
	clipped_target.size = Vector2(80.0, 50.0)
	scroll_viewport.add_child(clipped_target)
	var pointer = load("res://scripts/ui/tutorial_pointer.gd").new()
	clip_root.add_child(pointer)
	pointer.set_target(clipped_target)
	await process_frame
	var visible_target_rect: Rect2 = pointer._get_visible_target_rect()
	check(is_equal_approx(visible_target_rect.size.y, 20.0),
		"tutorial pointer highlight is clipped to the visible portion of a scrolled target")
	clip_root.queue_free()
	hud._refresh_lists()
	var player_buttons: Dictionary = hud.get("_player_item_buttons")
	var sample_instance_id: String = player_buttons.keys()[0]
	var original_button_id: int = player_buttons[sample_instance_id].get_instance_id()
	var other_instance_id: String = player_buttons.keys()[1]
	hud._select_player_item(other_instance_id)
	player_buttons = hud.get("_player_item_buttons")
	check(original_button_id == player_buttons[sample_instance_id].get_instance_id(),
		"selecting an inventory item updates row selection without rebuilding the list")
	hud.set("_inventory_open", true)
	hud.set("_refresh_timer", 0.0)
	hud._process(0.36)
	player_buttons = hud.get("_player_item_buttons")
	var refreshed_button_id: int = player_buttons[sample_instance_id].get_instance_id()
	check(original_button_id == refreshed_button_id,
		"open Backpack keeps item buttons stable during background refresh so a single click selects them")
	hud.set("_inventory_open", false)
	hud._process(0.0)

	world.queue_free()
	await process_frame
	print("Demo interaction flow: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _frames(count: int) -> void:
	for _index in count:
		await physics_frame
