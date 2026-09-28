extends SceneTree

const STATE_PATH := "res://scripts/survival/survival_state.gd"
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
	var script = load(STATE_PATH)
	check(script != null, "SurvivalState script exists")
	if script == null:
		_finish()
		return
	var state = script.new()
	check(is_equal_approx(state.get_health(), 100.0), "health starts full")
	check(is_zero_approx(state.get_hunger()) and is_zero_approx(state.get_thirst()), "needs start empty")
	check(state.set_health(25.0) and state.set_hunger(40.0) and state.set_thirst(80.0), "sets valid state values")
	check(state.serialize() == {"health": 25.0, "hunger": 40.0, "thirst": 80.0}, "serializes three values")
	check(state.set_hunger(200.0) and is_equal_approx(state.get_hunger(), 100.0), "clamps needs to maximum")
	check(state.set_health(-5.0) and is_zero_approx(state.get_health()), "clamps health to zero")
	check(not state.set_thirst(INF) and not state.set_hunger(NAN), "rejects non-finite values")
	var saved := {"health": 10.0, "hunger": 20.0, "thirst": 30.0}
	check(state.deserialize(saved), "restores valid state")
	check(state.serialize() == saved, "state round trips")
	var json_state: Dictionary = JSON.parse_string(JSON.stringify(state.serialize()))
	check(state.deserialize(json_state), "state survives JSON stringify and parse round-trip")
	check(not state.deserialize({"health": 1.0, "hunger": 2.0}), "rejects missing fields")
	check(not state.deserialize({"health": "1", "hunger": 2.0, "thirst": 3.0}), "rejects wrong field types")
	check(not state.deserialize({"health": 1.0, "hunger": 2.0, "thirst": 3.0, "extra": 4.0}), "rejects unknown fields")
	check(not state.deserialize({"health": 101.0, "hunger": 2.0, "thirst": 3.0}), "rejects out-of-range persisted state")
	check(not state.deserialize({"health": NAN, "hunger": 2.0, "thirst": 3.0}), "rejects non-finite persisted values")
	check(state.serialize() == saved, "failed restore leaves state unchanged")
	_finish()

func _finish() -> void:
	print("SurvivalState: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
