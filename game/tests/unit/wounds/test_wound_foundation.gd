extends SceneTree
## Wound record identity, bleeding state and strict runtime-record checks.

const WOUND_STATE_PATH := "res://scripts/wounds/wound_state.gd"
const UUID_PATTERN := "^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"

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
	var wound_script: Script = load(WOUND_STATE_PATH)
	check(wound_script != null, "WoundState runtime record exists")
	if wound_script == null:
		_finish()
		return
	var first = wound_script.new(2.0)
	var second = wound_script.new(1.0)
	var expression := RegEx.new()
	expression.compile(UUID_PATTERN)
	check(expression.search(first.wound_id) != null and expression.search(second.wound_id) != null, "new Wounds receive UUID v4 identities")
	check(first.wound_id != second.wound_id, "separate Wounds receive distinct identities")
	check(is_equal_approx(first.get_bleeding_rate_per_game_hour(), 2.0), "Wound retains its bleeding rate")
	var expected := {"wound_id": first.wound_id, "bleeding_rate_per_game_hour": 2.0}
	check(first.serialize() == expected, "Wound exposes a stable runtime record")
	var json_record: Dictionary = JSON.parse_string(JSON.stringify(expected))
	var restored = wound_script.new(0.0)
	check(restored.deserialize(json_record), "Wound restores a valid JSON record")
	check(restored.serialize() == expected, "Wound record round trips without changing identity")
	check(restored.reduce_bleeding(0.5), "Wound accepts bleeding reduction")
	check(is_equal_approx(restored.get_bleeding_rate_per_game_hour(), 1.5), "bleeding reduction changes only the selected Wound")
	check(not restored.reduce_bleeding(-0.1), "Wound rejects negative bleeding reduction")
	check(not restored.reduce_bleeding(INF), "Wound rejects non-finite bleeding reduction")
	check(not restored.reduce_bleeding(0.0), "Wound rejects a no-op bleeding reduction")
	check(restored.reduce_bleeding(5.0) and is_zero_approx(restored.get_bleeding_rate_per_game_hour()), "bleeding reduction cannot produce a negative rate")
	check(not restored.is_bleeding(), "zero bleeding rate marks the Wound as no longer bleeding")
	check(not restored.reduce_bleeding(1.0), "stopped Wound rejects redundant bleeding reduction")
	for invalid_record in [
		{"wound_id": "", "bleeding_rate_per_game_hour": 1.0},
		{"wound_id": first.wound_id, "bleeding_rate_per_game_hour": -1.0},
		{"wound_id": first.wound_id, "bleeding_rate_per_game_hour": true},
		{"wound_id": first.wound_id, "bleeding_rate_per_game_hour": INF},
		{"wound_id": first.wound_id, "bleeding_rate_per_game_hour": 10.1},
		{"wound_id": first.wound_id},
		{"wound_id": first.wound_id, "bleeding_rate_per_game_hour": 1.0, "extra": 1},
	]:
		check(not restored.deserialize(invalid_record), "Wound rejects malformed runtime record")
	check(restored.serialize() == {"wound_id": first.wound_id, "bleeding_rate_per_game_hour": 0.0}, "failed restore leaves existing Wound unchanged")
	_finish()


func _finish() -> void:
	print("Wound foundation: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
