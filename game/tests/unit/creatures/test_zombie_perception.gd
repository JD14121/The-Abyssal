extends SceneTree
## Zombie cone vision and NoiseEvent hearing preserve target memory.

const ZOMBIE_SCENE_PATH := "res://scenes/creatures/zombie/zombie.tscn"
const NOISE_SYSTEM_PATH := "res://scripts/world/noise/noise_system.gd"

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
	var zombie_scene: PackedScene = load(ZOMBIE_SCENE_PATH)
	var zombie = zombie_scene.instantiate()
	root.add_child(zombie)
	await physics_frame
	zombie.global_position = Vector2.ZERO
	if _has_property(zombie, "vision_cone_degrees"):
		zombie.vision_cone_degrees = 100.0
	check(zombie.set_facing_direction(Vector2.RIGHT) and zombie.get_facing_direction().is_equal_approx(Vector2.RIGHT), "Zombie facing direction is normalized and exposed")
	check(zombie.has_method("can_see_target"), "Zombie exposes line-of-sight perception")
	if zombie.has_method("can_see_target") and _has_property(zombie, "vision_cone_degrees"):
		check(zombie.can_see_target(Vector2(100.0, 0.0)), "target in the facing vision cone is visible")
		check(not zombie.can_see_target(Vector2(-100.0, 0.0)), "target behind the Zombie is outside its vision cone")
	var target := Node2D.new()
	root.add_child(target)
	target.global_position = Vector2(100.0, 0.0)
	var noise_script: Script = load(NOISE_SYSTEM_PATH)
	var noise_system = noise_script.new()
	root.add_child(noise_system)
	check(zombie.has_method("set_noise_system"), "Zombie accepts an injected world NoiseSystem")
	if zombie.has_method("set_noise_system"):
		zombie.set_noise_system(noise_system)
		noise_system.emit_noise(Vector2(70.0, 0.0), 150.0, &"footstep_run", target)
		check(zombie.has_last_known_position() and zombie.get_last_known_position().is_equal_approx(Vector2(70.0, 0.0)), "heard NoiseEvent updates last known position")
		zombie.set_target(target)
		target.global_position = Vector2(-100.0, 0.0)
		zombie.physics_step(0.1)
		check(zombie.get_state_name() == "INVESTIGATE" or zombie.get_state_name() == "SEARCH", "lost visual contact becomes investigation instead of attack")
	noise_system.free()
	target.free()
	zombie.free()
	print("Zombie perception: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _has_property(object: Object, property_name: String) -> bool:
	for property in object.get_property_list():
		if property.name == property_name:
			return true
	return false
