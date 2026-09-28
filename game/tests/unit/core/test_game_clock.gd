extends SceneTree

const CLOCK_PATH := "res://autoload/game_clock.gd"
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
	var script = load(CLOCK_PATH)
	check(script != null, "GameClock script exists")
	if script == null:
		_finish()
		return
	var clock = script.new()
	check(is_zero_approx(clock.get_elapsed_game_seconds()), "clock starts at zero")
	check(clock.advance(2.0), "real time advances")
	check(is_equal_approx(clock.get_elapsed_game_seconds(), 2.0), "default scale is one")
	check(clock.set_time_scale(3.0), "sets time scale")
	check(clock.advance(2.0), "scaled time advances")
	check(is_equal_approx(clock.get_elapsed_game_seconds(), 8.0), "scale multiplies elapsed time")
	check(clock.set_paused(true), "pauses clock")
	check(clock.advance(10.0), "paused advance is a valid no-op")
	check(is_equal_approx(clock.get_elapsed_game_seconds(), 8.0), "pause freezes elapsed time")
	check(not clock.set_time_scale(-1.0), "rejects negative time scale")
	check(not clock.advance(-1.0), "rejects negative real delta")
	var saved: Dictionary = clock.serialize()
	var restored = script.new()
	check(restored.deserialize(saved), "clock state restores")
	check(restored.serialize() == saved, "clock round trips exactly")
	check(not restored.deserialize({"elapsed_game_seconds": -1.0, "time_scale": 1.0, "paused": false}), "rejects invalid saved state")
	check(restored.serialize() == saved, "failed restore leaves state unchanged")
	clock.free()
	restored.free()
	_finish()

func _finish() -> void:
	print("GameClock: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
