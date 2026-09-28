extends SceneTree
## Player weapon identity, target selection and CombatService integration checks.

const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"
const ZOMBIE_SCENE_PATH := "res://scenes/creatures/zombie/zombie.tscn"
const ItemFactoryScript = preload("res://scripts/items/item_factory.gd")

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
	var registry = root.get_node_or_null("DataRegistry")
	check(registry != null and registry.has_weapon(&"weapon_kitchen_knife"), "Registry loads kitchen knife WeaponDefinition")
	if registry == null or not registry.is_loaded():
		_finish()
		return
	var weapon = registry.get_weapon_for_item(&"kitchen_knife")
	check(weapon != null and is_equal_approx(weapon.melee_damage, 20.0), "weapon item index exposes static damage")
	var player_scene: PackedScene = load(PLAYER_SCENE_PATH)
	var zombie_scene: PackedScene = load(ZOMBIE_SCENE_PATH)
	var player: CharacterBody2D = player_scene.instantiate()
	root.add_child(player)
	await process_frame
	var inventory = player.get_node("PlayerInventoryComponent").get_inventory()
	var factory = ItemFactoryScript.new(registry)
	var knife_a = factory.create(&"kitchen_knife")
	var knife_b = factory.create(&"kitchen_knife")
	check(inventory.add_item(knife_a) and inventory.add_item(knife_b), "two runtime knives enter Player inventory")
	var melee = player.get_node("PlayerMeleeComponent")
	check(melee.equip_melee_weapon(knife_a.instance_id), "equips exact owned runtime instance")
	check(not melee.equip_melee_weapon("missing-instance") and melee.equipped_instance_id == knife_a.instance_id, "failed equip preserves previous weapon")
	check(not melee.try_attack() and is_zero_approx(melee.cooldown_remaining), "no target causes no attack and consumes no cooldown")
	var zombie: ZombieController = zombie_scene.instantiate()
	zombie.position = Vector2(28.0, 0.0)
	root.add_child(zombie)
	var farther_zombie: ZombieController = zombie_scene.instantiate()
	farther_zombie.position = Vector2(40.0, 0.0)
	root.add_child(farther_zombie)
	await physics_frame
	await physics_frame
	var health = zombie.get_damage_receiver().get_current_health()
	var farther_health = farther_zombie.get_damage_receiver().get_current_health()
	check(melee.select_target(52.0) == zombie, "nearest valid Creature is selected")
	zombie.position = Vector2(28.0, 0.0)
	farther_zombie.position = Vector2(28.0, 0.0)
	melee._candidates.clear()
	melee._candidates.append(zombie)
	melee._candidates.append(farther_zombie)
	check(melee.select_target(52.0) == zombie, "equal-distance targets preserve candidate order")
	zombie.position = Vector2(28.0, 0.0)
	farther_zombie.position = Vector2(40.0, 0.0)
	check(melee.try_attack(), "legal in-range Zombie receives attack request")
	check(is_equal_approx(zombie.get_damage_receiver().get_current_health(), health - 20.0), "melee damage resolves through CombatService")
	check(is_equal_approx(farther_zombie.get_damage_receiver().get_current_health(), farther_health), "attack resolves only against the selected target")
	check(not melee.try_attack(), "cooldown prevents a second attack")
	check(is_equal_approx(melee.cooldown_remaining, 0.7), "successful attack starts weapon interval")
	inventory.remove_item(knife_a.instance_id)
	check(not melee.try_attack() and melee.equipped_instance_id.is_empty(), "removed exact instance invalidates equipment without same-definition substitution")
	check(inventory.has_item(knife_b.instance_id), "alternate same-definition instance remains untouched")
	player.queue_free()
	zombie.queue_free()
	farther_zombie.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	print("PlayerMeleeFoundation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
