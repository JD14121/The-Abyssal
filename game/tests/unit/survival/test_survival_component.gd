extends SceneTree

const COMPONENT_PATH := "res://scripts/survival/survival_component.gd"
const PLAYER_SCENE := "res://scenes/player/player.tscn"
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func _run() -> void:
	var script = load(COMPONENT_PATH)
	check(script != null, "SurvivalComponent script exists")
	if script == null:
		_finish()
		return
	var first = script.new()
	var second = script.new()
	first.hunger_per_game_hour = 1.0
	first.thirst_per_game_hour = 2.0
	check(first.advance_game_time(3600.0), "advances one game hour")
	check(is_equal_approx(first.state.get_hunger(), 1.0) and is_equal_approx(first.state.get_thirst(), 2.0), "applies hourly need rates")
	check(second.state.get_hunger() == 0.0 and second.state.get_thirst() == 0.0, "entities have independent survival state")
	check(first.advance_game_time(6.0 * 3600.0), "advances multiple hours")
	check(is_equal_approx(first.state.get_hunger(), 7.0) and is_equal_approx(first.state.get_thirst(), 14.0), "large time step accumulates deterministically")
	check(first.advance_game_time(30.0 * 24.0 * 3600.0), "accepts large valid time step")
	check(is_equal_approx(first.state.get_hunger(), 100.0) and is_equal_approx(first.state.get_thirst(), 100.0), "needs clamp at maximum")
	check(not first.advance_game_time(-1.0), "rejects negative game time")
	check(first.advance_game_time(0.0), "zero elapsed game time is valid")
	first.state.set_hunger(0.0)
	first.state.set_thirst(0.0)
	first.hunger_per_game_hour = 0.0
	first.thirst_per_game_hour = 0.0
	check(first.advance_game_time(3600.0), "zero need rates are valid")
	check(is_zero_approx(first.state.get_hunger()) and is_zero_approx(first.state.get_thirst()), "zero rates do not change needs")
	var one_step = script.new()
	var many_steps = script.new()
	one_step.advance_game_time(3600.0)
	for _hour in range(60):
		many_steps.advance_game_time(60.0)
	check(is_equal_approx(one_step.state.get_hunger(), many_steps.state.get_hunger()), "results do not depend on frame-sized step partition")
	check(is_equal_approx(one_step.state.get_thirst(), many_steps.state.get_thirst()), "thirst remains deterministic across step partition")
	var clock_driven = script.new()
	clock_driven.hunger_per_game_hour = 1.0
	clock_driven.thirst_per_game_hour = 2.0
	var clock: Node = root.get_node("GameClock")
	root.add_child(clock_driven)
	await process_frame
	var original_clock: Dictionary = clock.serialize()
	clock.deserialize({"elapsed_game_seconds": original_clock["elapsed_game_seconds"], "time_scale": 2.0, "paused": false})
	clock.advance(1800.0)
	await process_frame
	check(absf(clock_driven.state.get_hunger() - 1.0) < 0.01 and absf(clock_driven.state.get_thirst() - 2.0) < 0.01, "component applies time-scale integration from shared clock")
	clock.set_paused(true)
	var paused_hunger: float = clock_driven.state.get_hunger()
	var paused_thirst: float = clock_driven.state.get_thirst()
	clock.advance(7200.0)
	await process_frame
	check(is_equal_approx(clock_driven.state.get_hunger(), paused_hunger) and is_equal_approx(clock_driven.state.get_thirst(), paused_thirst), "paused clock stops survival progression")
	clock.deserialize(original_clock)
	clock_driven.queue_free()
	await process_frame
	var player = load(PLAYER_SCENE).instantiate()
	var player_two = load(PLAYER_SCENE).instantiate()
	var player_survival = player.get_node_or_null("SurvivalComponent")
	var player_two_survival = player_two.get_node_or_null("SurvivalComponent")
	check(player_survival != null and player_two_survival != null, "Player scene owns a SurvivalComponent")
	if player_survival != null and player_two_survival != null:
		check(player_survival.state != player_two_survival.state, "Player instances own independent SurvivalState")
	player.free()
	player_two.free()
	first.free()
	second.free()
	one_step.free()
	many_steps.free()
	_finish()

func _finish() -> void:
	print("SurvivalComponent: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
