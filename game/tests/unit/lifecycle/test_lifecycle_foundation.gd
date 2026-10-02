extends SceneTree
## Player defeat and Corpse placeholder contract checks.

class TestAttacker extends Node2D:
	func get_melee_damage() -> float:
		return 100.0

const PlayerPath := "res://scenes/player/player.tscn"
const CorpsePath := "res://scenes/lifecycle/corpse.tscn"
const CorpseScriptPath := "res://scripts/lifecycle/corpse.gd"
const ContainerPath := "res://scenes/interactables/container.tscn"
const ZombiePath := "res://scenes/creatures/zombie/zombie.tscn"
const ItemFactoryScript = preload("res://scripts/items/item_factory.gd")
const DamageEventScript = preload("res://scripts/combat/damage_event.gd")
const CombatServiceScript = preload("res://scripts/combat/combat_service.gd")

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
	await _test_player_defeat()
	_test_corpse_contract()
	print("LifecycleFoundation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _test_player_defeat() -> void:
	var registry = root.get_node("DataRegistry")
	var player_scene: PackedScene = load(PlayerPath)
	var container_scene: PackedScene = load(ContainerPath)
	var player: CharacterBody2D = player_scene.instantiate()
	root.add_child(player)
	await process_frame
	var defeat = player.get_node("PlayerDefeatComponent")
	var receiver = player.get_damage_receiver()
	check(not defeat.is_defeated(), "Player begins not defeated")
	check(not receiver.is_depleted() and receiver.get_current_health() > 0.0, "positive Player Health does not defeat")
	var factory = ItemFactoryScript.new(registry)
	var knife = factory.create(&"kitchen_knife")
	var water = factory.create(&"water_bottle")
	var inventory = player.get_node("PlayerInventoryComponent").get_inventory()
	check(inventory.add_item(knife) and inventory.add_item(water), "test items enter Player Inventory")
	var melee = player.get_node("PlayerMeleeComponent")
	check(melee.equip_melee_weapon(knife.instance_id), "test knife equips before defeat")
	var container: Node = container_scene.instantiate()
	container.position = Vector2(48.0, 0.0)
	root.add_child(container)
	var zombie_scene: PackedScene = load(ZombiePath)
	var zombie: ZombieController = zombie_scene.instantiate()
	zombie.position = Vector2(32.0, 0.0)
	root.add_child(zombie)
	await physics_frame
	await physics_frame
	var interaction = player.get_node("InteractionComponent")
	var access = player.get_node("ContainerAccessComponent")
	check(access.set_active_container(container), "Player can access nearby test Container before defeat")
	var zombie_health_before = zombie.get_damage_receiver().get_current_health()
	check(melee.try_attack() and zombie.get_damage_receiver().get_current_health() < zombie_health_before, "equipped Player can attack before defeat")
	var defeated_signal_count := [0]
	defeat.defeated.connect(func(): defeated_signal_count[0] += 1)
	var attacker := TestAttacker.new()
	root.add_child(attacker)
	var lethal = DamageEventScript.new(attacker, player, 100.0)
	check(CombatServiceScript.new().apply_damage_event(lethal), "lethal damage resolves through CombatService")
	await process_frame
	check(defeat.is_defeated() and receiver.get_current_health() == 0.0, "depletion triggers defeated while Health remains zero")
	check(defeated_signal_count[0] == 1 and player.is_inside_tree(), "defeat signals once and preserves Player node")
	check(player.velocity.is_zero_approx(), "defeat clears Player velocity")
	Input.action_press(&"move_right")
	player._physics_process(1.0 / 60.0)
	Input.action_release(&"move_right")
	check(player.velocity.is_zero_approx(), "disabled Player controller produces no movement")
	melee.cooldown_remaining = 0.0
	var zombie_health_after_defeat = zombie.get_damage_receiver().get_current_health()
	check(not melee.is_combat_enabled() and not melee.try_attack(), "melee is disabled after defeat")
	check(zombie.get_damage_receiver().get_current_health() == zombie_health_after_defeat, "defeated Player cannot damage Creature")
	check(not interaction.try_interact(), "interaction cannot run after defeat")
	check(access.get_active_container() == null, "active Container access clears on defeat")
	check(inventory.get_item(knife.instance_id) == knife and inventory.get_item(water.instance_id) == water, "exact Inventory instances remain after defeat")
	check(not receiver.receive_damage(lethal), "additional damage remains rejected after defeat")
	check(defeated_signal_count[0] == 1, "repeated lethal request does not repeat defeat transition")
	check(root.find_children("*", "Corpse", true, false).is_empty(), "Player defeat does not create a Corpse")
	attacker.free()
	container.queue_free()
	zombie.queue_free()
	player.queue_free()
	await process_frame


func _test_corpse_contract() -> void:
	var script: Script = load(CorpseScriptPath)
	var scene: PackedScene = load(CorpsePath)
	check(script != null and scene != null, "Corpse runtime script and scene exist")
	var corpse: Node = scene.instantiate()
	check(not corpse.initialize(&""), "Corpse rejects missing source definition ID")
	check(corpse.initialize(&"zombie_basic"), "Corpse accepts stable source creature ID")
	root.add_child(corpse)
	var inspections := [0]
	corpse.inspected.connect(func(_corpse): inspections[0] += 1)
	check(corpse.get_interaction_prompt(null) == "Inspect Corpse", "Corpse prompt is a placeholder inspect action")
	corpse.interact(null)
	check(corpse.inspection_count == 1 and inspections[0] == 1, "Corpse inspection only increments and signals")
	check(corpse.source_creature_definition_id == &"zombie_basic", "Corpse retains source Creature definition ID")
	check(corpse.get_node_or_null("DamageReceiver") == null and corpse.get_node_or_null("Inventory") == null, "Corpse has no Health receiver or Inventory")
	check(corpse.get("loot") == null and corpse.get_collision_layer_value(3), "Corpse has no Loot field and occupies Interactable layer")
	check(corpse.get_collision_mask() == 0 and not corpse.get_collision_layer_value(4), "Corpse is not a Creature-layer collider")
	check(corpse is Area2D and not corpse is PhysicsBody2D, "Corpse does not block Player movement")
	corpse.free()
