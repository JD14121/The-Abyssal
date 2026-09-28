extends SceneTree

const ZOMBIE_SCENE := "res://scenes/creatures/zombie/zombie.tscn"
const DEBUG_SCENE := "res://debug/test_scenes/zombie_test.tscn"
const UNREADY_REGISTRY := preload("res://tests/fixtures/creatures/unready_registry.gd")

var checks := 0
var failures := 0
var attack_requests := 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	var packed: PackedScene = load(ZOMBIE_SCENE)
	check(packed != null, "Zombie scene loads")
	if packed == null:
		_finish()
		return
	var zombie = packed.instantiate()
	root.add_child(zombie)
	await process_frame
	check(zombie is CharacterBody2D and zombie.initialized, "Zombie binds the production definition at startup")
	check(zombie.creature_definition.id == &"zombie_basic" and is_equal_approx(zombie.creature_definition.move_speed, 70.0), "definition parameters are applied")
	check(zombie.get_state_name() == "IDLE" and zombie.velocity == Vector2.ZERO, "no target remains still in IDLE")
	var unready_actor: ZombieController = packed.instantiate()
	unready_actor.set_physics_process(false)
	var unready_registry: Node = UNREADY_REGISTRY.new()
	check(not unready_actor.initialize_runtime(unready_registry) and not unready_actor.initialized, "Registry-not-ready initialization safely fails")
	unready_actor.definition_id = &"missing_creature"
	check(not unready_actor.initialize_runtime(root.get_node("DataRegistry")) and not unready_actor.initialized, "unknown definition safely disables runtime behavior")
	unready_actor.free()
	unready_registry.free()
	var target := Node2D.new()
	root.add_child(target)
	target.global_position = zombie.global_position + Vector2(500, 0)
	zombie.set_target(target)
	zombie.physics_step(0.0)
	check(zombie.get_state_name() == "IDLE", "target outside vision is ignored")
	target.global_position = zombie.global_position + Vector2(180, 0)
	zombie.physics_step(0.0)
	check(zombie.get_state_name() == "CHASE", "target inside vision enters CHASE")
	zombie.attack_requested.connect(_record_attack_request)
	var survival_state = load("res://scripts/survival/survival_state.gd").new()
	survival_state.set_health(73.0)
	var health_before: float = survival_state.get_health()
	target.global_position = zombie.global_position + Vector2(24, 0)
	zombie.physics_step(0.0)
	check(zombie.get_state_name() == "ATTACK" and zombie.velocity == Vector2.ZERO, "attack range enters ATTACK and stops movement")
	check(attack_requests == 1, "first in-range attack request is immediate")
	target.global_position = zombie.global_position + Vector2(100, 0)
	zombie.physics_step(0.2)
	check(zombie.get_state_name() == "CHASE" and attack_requests == 1, "leaving attack range stops requests without resetting cooldown")
	target.global_position = zombie.global_position + Vector2(24, 0)
	zombie.physics_step(0.2)
	check(zombie.get_state_name() == "ATTACK" and attack_requests == 1, "re-entering attack range cannot bypass remaining cooldown")
	zombie.physics_step(0.8)
	check(attack_requests == 2, "request repeats after configured interval")
	target.global_position = zombie.global_position + Vector2(100, 0)
	zombie.physics_step(0.0)
	check(zombie.get_state_name() == "CHASE", "leaving attack range returns to CHASE")
	check(attack_requests == 2, "leaving attack range stops attack requests")
	target.global_position = zombie.global_position + Vector2(500, 0)
	zombie.physics_step(0.0)
	check(zombie.get_state_name() == "IDLE", "leaving vision returns to IDLE")
	target.queue_free()
	await process_frame
	zombie.physics_step(0.0)
	check(zombie.get_state_name() == "IDLE" and zombie.target == null, "freed target is cleared safely")
	check(is_equal_approx(survival_state.get_health(), health_before), "attack requests do not access or alter SurvivalState health")
	var slow_zombie: ZombieController = packed.instantiate()
	slow_zombie.definition_id = &"zombie_slow"
	root.add_child(slow_zombie)
	await process_frame
	check(is_equal_approx(slow_zombie.creature_definition.move_speed, 45.0) and is_equal_approx(zombie.creature_definition.move_speed, 70.0), "different definitions supply independent movement speeds")
	var slow_target := Node2D.new()
	root.add_child(slow_target)
	slow_target.global_position = slow_zombie.global_position + Vector2(100, 0)
	slow_zombie.set_target(slow_target)
	slow_zombie.physics_step(0.0)
	zombie.physics_step(0.0)
	check(slow_zombie.get_state_name() == "CHASE" and zombie.get_state_name() == "IDLE", "Zombie target and state remain instance-local")
	slow_target.queue_free()
	slow_zombie.queue_free()
	await process_frame
	var debug_scene: PackedScene = load(DEBUG_SCENE)
	check(debug_scene != null, "Zombie navigation debug scene loads")
	if debug_scene != null:
		var yard = debug_scene.instantiate()
		root.add_child(yard)
		var yard_player: CharacterBody2D = yard.get_node("Player")
		var yard_zombie: ZombieController = yard.get_node("Zombie")
		var yard_state: SurvivalState = yard_player.get_node("SurvivalComponent").state
		yard_state.set_health(61.0)
		var debug_health: float = yard_state.get_health()
		yard_player.global_position = Vector2(460, 400)
		for _frame in range(30):
			await physics_frame
			if not yard_zombie.velocity.is_zero_approx():
				break
		check(yard_zombie.get_state_name() == "CHASE" and is_equal_approx(yard_zombie.velocity.length(), yard_zombie.creature_definition.move_speed), "navigation-backed chase uses definition speed")
		var start_position: Vector2 = Vector2(520, 400)
		yard_zombie.global_position = start_position
		yard_player.global_position = Vector2(680, 400)
		var moved_around_obstacle := false
		for _frame in range(420):
			await physics_frame
			if absf(yard_zombie.global_position.y - start_position.y) > 100.0:
				moved_around_obstacle = true
			if yard_zombie.current_state == ZombieController.State.ATTACK:
				break
		check(moved_around_obstacle, "NavigationAgent path goes around the solid obstacle")
		check(yard_zombie.current_state == ZombieController.State.ATTACK, "reachable target is approached to attack range")
		for _frame in range(90):
			if int(yard.get("attack_request_count")) > 1:
				break
			await physics_frame
		check(int(yard.get("attack_request_count")) > 1, "attack cadence repeats after cooldown")
		check(is_equal_approx(yard_state.get_health(), debug_health), "debug attack requests leave Player health unchanged")
		yard.queue_free()
		await process_frame
	zombie.queue_free()
	_finish()


func _record_attack_request(_attacker: Node2D, _target: Node2D) -> void:
	attack_requests += 1


func _finish() -> void:
	print("Zombie foundation: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
