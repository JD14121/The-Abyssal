extends SceneTree
## Firearms spend exact ammo instances, emit world noise, and resolve projectiles via CombatService.

const PLAYER_SCENE := "res://scenes/player/player.tscn"
const ZOMBIE_SCENE := "res://scenes/creatures/zombie/zombie.tscn"
const FACTORY := "res://scripts/items/item_factory.gd"
const NOISE_SYSTEM := "res://scripts/world/noise/noise_system.gd"
var checks := 0
var failures := 0
var noise_count := 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var noise = load(NOISE_SYSTEM).new()
	noise.name = "NoiseSystem"
	world.add_child(noise)
	noise.noise_emitted.connect(_on_noise)
	var player: CharacterBody2D = load(PLAYER_SCENE).instantiate()
	world.add_child(player)
	await process_frame
	var zombie: ZombieController = load(ZOMBIE_SCENE).instantiate()
	zombie.position = Vector2(100.0, 0.0)
	world.add_child(zombie)
	zombie.set_ai_enabled(false)
	var registry = root.get_node("DataRegistry")
	var factory = load(FACTORY).new(registry)
	var inventory = player.get_node("PlayerInventoryComponent").get_inventory()
	var gun: ItemInstance = factory.create(&"pipe_pistol")
	check(inventory.add_item(gun), "Inventory accepts ranged weapon ItemInstance")
	for index in range(8):
		check(inventory.add_item(factory.create(&"pistol_round")), "Inventory accepts pistol round %d" % index)
	check(player.get_node("EquipmentComponent").equip_item(&"hands", gun.instance_id), "ranged weapon equips in Hands")
	var ranged = player.get_node("RangedWeaponComponent")
	check(not ranged.fire(), "empty weapon cannot fire before reloading")
	check(ranged.reload() and ranged.get_loaded_ammo() == 6, "reload fills a bounded magazine from Inventory")
	ranged._process(1.5)
	var health: float = zombie.get_damage_receiver().get_current_health()
	check(ranged.fire() and ranged.get_loaded_ammo() == 5, "fire spends one magazine round and launches projectile")
	check(noise_count == 1, "gunshot emits world NoiseEvent")
	for index in range(18):
		await physics_frame
	check(zombie.get_damage_receiver().get_current_health() < health, "projectile applies damage through CombatService")
	check(ranged.reload() and ranged.get_loaded_ammo() == 6, "reload tops up magazine with exact remaining ammo")
	check(inventory.get_item_count() == 2, "reload consumes only the rounds placed into the magazine")
	player.queue_free()
	zombie.queue_free()
	world.queue_free()
	await process_frame
	print("Ranged weapon foundation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _on_noise(_event: NoiseEvent) -> void:
	noise_count += 1
