extends SceneTree
## Population caps and distance tiers are deterministic and scene local.

const ZOMBIE_SCENE_PATH := "res://scenes/creatures/zombie/zombie.tscn"
const CONTROLLER_PATH := "res://scripts/creatures/zombie_population_controller.gd"

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
	var controller_script: Script = load(CONTROLLER_PATH)
	check(controller_script != null, "ZombiePopulationController exists")
	if controller_script == null:
		_finish()
		return
	var target := Node2D.new()
	root.add_child(target)
	var controller = controller_script.new()
	root.add_child(controller)
	var zombie_scene: PackedScene = load(ZOMBIE_SCENE_PATH)
	check(controller.configure(zombie_scene, target, null, 2, 400.0, 1200.0), "population accepts a valid bounded rule set")
	check(controller.populate([Vector2(100.0, 0.0), Vector2(700.0, 0.0), Vector2(1500.0, 0.0)]) == 2, "spawn cap limits population")
	check(controller.get_population_count() == 2, "population count reports spawned actors")
	var spawned_zombie: ZombieController = controller.get_children().filter(func(actor): return actor is ZombieController)[0]
	check(spawned_zombie.attack_requested.get_connections().size() == 1, "world-local combat coordinator receives Zombie attack intent")
	controller.refresh_simulation_tiers(1.0)
	check(controller.get_full_simulation_count() == 1, "near actors use full simulation")
	check(controller.get_simplified_simulation_count() == 1, "mid-range actors use simplified simulation")
	check(controller.get_dormant_count() == 0, "population beyond configured radius is dormant")
	var simplified_zombie: ZombieController = controller.get_children().filter(func(actor): return actor is ZombieController and actor.get_simulation_tier() == ZombieController.SimulationTier.SIMPLIFIED)[0]
	check(simplified_zombie.get_simplified_simulation_tick_count() == 0, "simplified AI ticks are staggered across population actors")
	controller.refresh_simulation_tiers(1.0)
	check(simplified_zombie.get_simplified_simulation_tick_count() == 1, "staggered simplified actor advances on its assigned tick")
	target.global_position = Vector2(-3000.0, 0.0)
	controller.refresh_simulation_tiers(2.0)
	check(controller.get_dormant_count() == 2, "moving the Player changes distance-based simulation tiers")
	controller.queue_free()
	target.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	print("Zombie population: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
