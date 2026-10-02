extends SceneTree
## Creature death transaction, Corpse interaction and failure safety checks.

class TestAttacker extends Node2D:
	func get_melee_damage() -> float:
		return 1000.0


class InvalidDefinitionSource extends Node2D:
	signal health_depleted

	var definition_id: StringName = &""
	var ai_enabled := true

	func get_damage_receiver() -> Node:
		return self

	func is_depleted() -> bool:
		return true

	func set_ai_enabled(enabled: bool) -> void:
		ai_enabled = enabled

const ZombiePath := "res://scenes/creatures/zombie/zombie.tscn"
const CorpsePath := "res://scenes/lifecycle/corpse.tscn"
const CorpseScriptPath := "res://scripts/lifecycle/corpse.gd"
const PlayerPath := "res://scenes/player/player.tscn"
const DeathComponentScript = preload("res://scripts/lifecycle/creature_death_component.gd")
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
	await _test_successful_death_transaction()
	await _test_failure_paths()
	print("LifecycleIntegration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _make_zombie(parent: Node, position: Vector2) -> ZombieController:
	var scene: PackedScene = load(ZombiePath)
	var zombie: ZombieController = scene.instantiate()
	zombie.position = position
	var lifecycle = DeathComponentScript.new()
	lifecycle.name = "CreatureDeathComponent"
	lifecycle.corpse_scene = load(CorpsePath)
	zombie.add_child(lifecycle)
	parent.add_child(zombie)
	return zombie


func _kill(zombie: Node2D) -> void:
	var attacker := TestAttacker.new()
	root.add_child(attacker)
	var event = DamageEventScript.new(attacker, zombie, 1000.0)
	CombatServiceScript.new().apply_damage_event(event)
	attacker.free()


func _test_successful_death_transaction() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var zombie := _make_zombie(world, Vector2(80.5, 44.25))
	await process_frame
	var lifecycle = zombie.get_node("CreatureDeathComponent")
	var health = zombie.get_damage_receiver()
	var attack_count := 0
	zombie.attack_requested.connect(func(_attacker, _target): attack_count += 1)
	check(not health.is_depleted() and world.get_child_count() == 1, "living Creature has no Corpse")
	zombie.set_target(world)
	_kill(zombie)
	check(health.is_depleted() and not zombie.initialized and zombie.target == null and zombie.velocity.is_zero_approx(), "depletion immediately disables Zombie AI")
	check(lifecycle.transition_started and lifecycle.transition_completed, "Creature death lifecycle completes")
	check(world.get_child_count() == 2, "Corpse is added before Zombie removal is deferred")
	var corpse = world.get_child(1)
	check(corpse.source_creature_definition_id == &"zombie_basic", "Corpse stores source definition ID")
	check(corpse.global_position.is_equal_approx(Vector2(80.5, 44.25)), "Corpse preserves death world position")
	lifecycle.handle_health_depleted()
	zombie.get_damage_receiver().health_depleted.emit()
	check(world.get_child_count() == 2, "repeated lifecycle calls do not create another Corpse")
	await process_frame
	check(not is_instance_valid(zombie) and world.get_child_count() == 1, "Zombie is removed after Corpse is initialized and in tree")
	check(attack_count == 0, "dead Zombie emits no future attack requests")
	var corpse_interaction = world.get_child(0)
	check(corpse_interaction.can_interact(world) and corpse_interaction.get_interaction_prompt(world) == "Inspect Corpse", "Corpse participates in generic Interaction contract")
	var player_scene: PackedScene = load(PlayerPath)
	var player: CharacterBody2D = player_scene.instantiate()
	player.position = corpse_interaction.position
	world.add_child(player)
	await physics_frame
	await physics_frame
	var interaction = player.get_node("InteractionComponent")
	check(interaction.get_candidates().has(corpse_interaction) and interaction.get_current_prompt() == "Inspect Corpse", "Player InteractionComponent detects the Corpse")
	check(interaction.try_interact() and corpse_interaction.inspection_count == 1, "Corpse placeholder interaction increments inspection count")
	var melee = player.get_node("PlayerMeleeComponent")
	check(not melee._is_legal_target(corpse_interaction), "Corpse is excluded from Player melee targets")
	check(world.get_child_count() == 2 and corpse_interaction.get_node_or_null("Inventory") == null, "inspection creates neither Loot nor Inventory")
	world.queue_free()
	await process_frame


func _test_failure_paths() -> void:
	await _assert_transition_failure("missing_scene", func(component): component.corpse_scene = null)
	var invalid_scene := PackedScene.new()
	var invalid_root := Node2D.new()
	invalid_scene.pack(invalid_root)
	invalid_root.free()
	await _assert_transition_failure("invalid_scene", func(component): component.corpse_scene = invalid_scene)
	var detached := _make_zombie(root, Vector2.ZERO)
	await process_frame
	var detached_component = detached.get_node("CreatureDeathComponent")
	detached.get_parent().remove_child(detached)
	detached.get_damage_receiver().current_health = 0.0
	check(not detached_component.handle_health_depleted(), "invalid parent rejects transition")
	check(is_instance_valid(detached) and detached.get_damage_receiver().get_current_health() == 0.0 and not detached.initialized, "invalid-parent failure preserves inert zero-health Zombie")
	detached.free()
	var invalid_source_world := Node2D.new()
	root.add_child(invalid_source_world)
	var invalid_source := InvalidDefinitionSource.new()
	invalid_source_world.add_child(invalid_source)
	var invalid_source_component = DeathComponentScript.new()
	invalid_source_component.corpse_scene = load(CorpsePath)
	invalid_source.add_child(invalid_source_component)
	check(invalid_source_component.transition_failed and invalid_source_world.get_child_count() == 1, "invalid Corpse source metadata fails without spawning or deleting the Creature")
	check(not invalid_source.ai_enabled, "invalid metadata leaves its Creature inert")
	invalid_source_world.queue_free()
	await process_frame


func _assert_transition_failure(case_name: String, configure: Callable) -> void:
	var world := Node2D.new()
	root.add_child(world)
	var zombie := _make_zombie(world, Vector2(12.0, 18.0))
	await process_frame
	var component = zombie.get_node("CreatureDeathComponent")
	configure.call(component)
	zombie.get_damage_receiver().current_health = 0.0
	check(not component.handle_health_depleted(), "%s does not complete death transition" % case_name)
	check(is_instance_valid(zombie) and zombie.is_inside_tree() and world.get_child_count() == 1, "%s keeps Zombie and spawns no Corpse" % case_name)
	check(not zombie.initialized and zombie.target == null and zombie.velocity.is_zero_approx(), "%s leaves zero-health Zombie inert" % case_name)
	check(component.transition_failed and not component.transition_completed, "%s records failed transition" % case_name)
	check(not component.handle_health_depleted() and world.get_child_count() == 1, "%s failure is idempotent without implicit retry" % case_name)
	world.queue_free()
	await process_frame


func _test_source_script_presence() -> void:
	check(load(CorpseScriptPath) != null and load(CorpsePath) != null, "lifecycle resources load")
