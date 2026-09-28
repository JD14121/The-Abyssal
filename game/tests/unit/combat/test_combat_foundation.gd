extends SceneTree

class TestMeleeSource extends Node2D:
	var amount: Variant = 0.0

	func get_melee_damage() -> Variant:
		return amount

const EVENT_PATH := "res://scripts/combat/damage_event.gd"
const RECEIVER_PATH := "res://scripts/combat/damage_receiver.gd"
const PLAYER_RECEIVER_PATH := "res://scripts/combat/player_damage_receiver.gd"
const CREATURE_HEALTH_PATH := "res://scripts/combat/creature_health_component.gd"
const SERVICE_PATH := "res://scripts/combat/combat_service.gd"
const COORDINATOR_PATH := "res://scripts/combat/combat_coordinator.gd"
const DEBUG_SCENE := "res://debug/test_scenes/combat_test.tscn"
const DamageEventScript = preload("res://scripts/combat/damage_event.gd")
const CombatServiceScript = preload("res://scripts/combat/combat_service.gd")
const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"
const ZOMBIE_SCENE_PATH := "res://scenes/creatures/zombie/zombie.tscn"

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
	var event_script: Script = load(EVENT_PATH)
	var receiver_script: Script = load(RECEIVER_PATH)
	var player_receiver_script: Script = load(PLAYER_RECEIVER_PATH)
	var health_script: Script = load(CREATURE_HEALTH_PATH)
	var service_script: Script = load(SERVICE_PATH)
	var coordinator_script: Script = load(COORDINATOR_PATH)
	check(event_script != null, "DamageEvent script exists")
	check(receiver_script != null, "DamageReceiver contract exists")
	check(player_receiver_script != null, "PlayerDamageReceiver exists")
	check(health_script != null, "CreatureHealthComponent exists")
	check(service_script != null, "CombatService exists")
	check(coordinator_script != null, "scene-local CombatCoordinator exists")
	check(load(DEBUG_SCENE) != null, "combat debug scene exists independently")
	var registry = root.get_node_or_null("DataRegistry")
	if registry != null and registry.is_loaded():
		var definition = registry.get_creature(&"zombie_basic")
		check(definition != null and definition.get_script().get_script_property_list().any(func(p): return p.name == "max_health") and is_equal_approx(definition.max_health, 100.0), "CreatureDefinition loads max_health")
		check(definition != null and definition.get_script().get_script_property_list().any(func(p): return p.name == "melee_damage") and is_equal_approx(definition.melee_damage, 10.0), "CreatureDefinition loads melee_damage")
	_test_damage_event()
	await _test_player_damage()
	await _test_creature_health()
	await _test_scene_local_coordinator()
	_finish()


func _test_damage_event() -> void:
	var source := Node.new()
	var target := Node.new()
	var valid_event = DamageEventScript.new(source, target, 4.0)
	check(valid_event.is_valid() and is_equal_approx(valid_event.amount, 4.0), "positive finite DamageEvent is valid")
	check(not DamageEventScript.new(null, target, 4.0).is_valid() and not DamageEventScript.new(source, null, 4.0).is_valid(), "DamageEvent requires source and target")
	for amount in [0.0, -1.0, NAN, INF]:
		check(not DamageEventScript.new(source, target, amount).is_valid(), "DamageEvent rejects %s" % amount)
	source.free()
	target.free()


func _test_player_damage() -> void:
	var player_scene: PackedScene = load(PLAYER_SCENE_PATH)
	var player: CharacterBody2D = player_scene.instantiate()
	root.add_child(player)
	await process_frame
	var receiver: DamageReceiver = player.get_damage_receiver()
	var state: SurvivalState = player.get_node("SurvivalComponent").get("state")
	var service = CombatServiceScript.new()
	var attacker := Node2D.new()
	root.add_child(attacker)
	check(receiver != null and is_equal_approx(receiver.get_current_health(), 100.0), "PlayerDamageReceiver reads SurvivalState health")
	check(not receiver.get_property_list().any(func(p): return p.name == "current_health"), "PlayerDamageReceiver stores no duplicate health value")
	check(service.apply_damage_event(DamageEventScript.new(attacker, player, 23.0)), "valid event applies to Player")
	check(is_equal_approx(state.get_health(), 77.0) and is_equal_approx(receiver.get_current_health(), 77.0), "Player damage changes only SurvivalState health")
	check(service.apply_damage_event(DamageEventScript.new(attacker, player, 100.0)), "overkill damage is accepted")
	check(receiver.is_depleted() and receiver.get_current_health() == 0.0, "Player health clamps at zero and reports depletion")
	check(not service.apply_damage_event(DamageEventScript.new(attacker, player, 1.0)) and state.get_health() == 0.0, "depleted Player rejects later damage")
	check(not service.apply_damage_event(DamageEventScript.new(null, player, 1.0)) and state.get_health() == 0.0, "invalid DamageEvent source leaves health unchanged")
	var orphan := Node2D.new()
	root.add_child(orphan)
	check(not service.apply_damage_event(DamageEventScript.new(attacker, orphan, 5.0)), "target without receiver is rejected")
	check(not service.resolve_melee_attack(null, player), "invalid attacker is rejected")
	var invalid_attacker := TestMeleeSource.new()
	invalid_attacker.amount = INF
	root.add_child(invalid_attacker)
	check(not service.resolve_melee_attack(invalid_attacker, player) and state.get_health() == 0.0, "non-finite melee damage is rejected before mutation")
	invalid_attacker.queue_free()
	attacker.queue_free()
	orphan.queue_free()
	player.queue_free()
	await process_frame


func _test_scene_local_coordinator() -> void:
	var debug_scene: PackedScene = load(DEBUG_SCENE)
	var combat_world = debug_scene.instantiate()
	root.add_child(combat_world)
	await process_frame
	var zombie: ZombieController = combat_world.get_node("Zombie")
	var player: CharacterBody2D = combat_world.get_node("Player")
	var coordinator: CombatCoordinator = combat_world.get_node("CombatCoordinator")
	var player_receiver: DamageReceiver = player.get_damage_receiver()
	check(zombie.attack_requested.is_connected(coordinator.handle_attack_requested), "Combat scene connects attack intent to local coordinator")
	zombie.set_physics_process(false)
	player.global_position = zombie.global_position + Vector2(24.0, 0.0)
	var before: float = player_receiver.get_current_health()
	zombie.physics_step(0.0)
	check(is_equal_approx(player_receiver.get_current_health(), before - zombie.get_melee_damage()), "one attack request applies melee damage exactly once")
	zombie.physics_step(0.2)
	check(is_equal_approx(player_receiver.get_current_health(), before - zombie.get_melee_damage()), "no damage is applied again before the AI cooldown")
	player.global_position = zombie.global_position + Vector2(100.0, 0.0)
	zombie.physics_step(0.2)
	player.global_position = zombie.global_position + Vector2(24.0, 0.0)
	zombie.physics_step(0.7)
	check(is_equal_approx(player_receiver.get_current_health(), before - zombie.get_melee_damage()), "re-entering range cannot bypass remaining attack cooldown")
	zombie.physics_step(0.11)
	check(is_equal_approx(player_receiver.get_current_health(), before - zombie.get_melee_damage() * 2.0), "next request resolves once when AI cooldown expires")
	player.global_position = zombie.global_position + Vector2(100.0, 0.0)
	zombie.physics_step(0.0)
	zombie.physics_step(2.0)
	check(is_equal_approx(player_receiver.get_current_health(), before - zombie.get_melee_damage() * 2.0), "leaving attack range stops further combat damage")
	combat_world.queue_free()
	await process_frame


func _test_creature_health() -> void:
	var zombie_scene: PackedScene = load(ZOMBIE_SCENE_PATH)
	var zombie: ZombieController = zombie_scene.instantiate()
	root.add_child(zombie)
	await process_frame
	var health: CreatureHealthComponent = zombie.get_damage_receiver()
	var attacker := Node2D.new()
	root.add_child(attacker)
	var service = CombatServiceScript.new()
	var depleted_events := [0]
	var attacks_after_depletion := [0]
	health.health_depleted.connect(func(): depleted_events[0] += 1)
	zombie.attack_requested.connect(func(_attacker: Node2D, _target: Node2D): attacks_after_depletion[0] += 1)
	check(health != null and is_equal_approx(health.get_max_health(), 100.0) and is_equal_approx(health.get_current_health(), 100.0), "Creature health initializes from definition")
	check(service.apply_damage_event(DamageEventScript.new(attacker, zombie, 95.0)), "generic DamageEvent can damage Creature")
	check(is_equal_approx(health.get_current_health(), 5.0), "Creature health decreases by damage amount")
	var player: CharacterBody2D = load(PLAYER_SCENE_PATH).instantiate()
	root.add_child(player)
	check(service.resolve_melee_attack(zombie, player), "valid Creature melee attack resolves")
	check(is_equal_approx(player.get_node("SurvivalComponent").get("state").get_health(), 90.0), "melee amount comes from CreatureDefinition")
	player.queue_free()
	var target := Node2D.new()
	root.add_child(target)
	zombie.set_target(target)
	check(service.apply_damage_event(DamageEventScript.new(attacker, zombie, 10.0)), "lethal Creature damage applies")
	check(health.get_current_health() == 0.0 and health.is_depleted(), "Creature health clamps and reports depletion")
	check(depleted_events[0] == 1 and not zombie.initialized and zombie.target == null and zombie.velocity == Vector2.ZERO, "depletion emits once and disables Zombie AI")
	zombie.physics_step(0.0)
	check(zombie.get_parent() == root and not zombie.is_physics_processing() and attacks_after_depletion[0] == 0, "depleted Zombie stays in tree and cannot request more attacks")
	check(not service.apply_damage_event(DamageEventScript.new(attacker, zombie, 1.0)) and depleted_events[0] == 1, "depleted Creature ignores later damage and does not repeat depletion")
	attacker.queue_free()
	target.queue_free()
	zombie.queue_free()
	await process_frame


func _finish() -> void:
	print("Combat foundation: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
