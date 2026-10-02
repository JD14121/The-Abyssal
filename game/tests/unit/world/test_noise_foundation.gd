extends SceneTree
## Noise events validate their source and apply radial signal falloff.

const NOISE_EVENT_PATH := "res://scripts/world/noise/noise_event.gd"
const NOISE_SYSTEM_PATH := "res://scripts/world/noise/noise_system.gd"

var checks := 0
var failures := 0
var received_events: Array = []


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	var event_script: Script = load(NOISE_EVENT_PATH)
	var system_script: Script = load(NOISE_SYSTEM_PATH)
	check(event_script != null and system_script != null, "NoiseEvent and NoiseSystem APIs are available")
	if event_script == null or system_script == null:
		_finish()
		return
	var event = event_script.new(Vector2.ZERO, 120.0, &"footstep")
	check(event.is_valid(), "valid NoiseEvent is accepted")
	check(is_equal_approx(event.get_strength_at(Vector2.ZERO), 1.0), "noise has full strength at its origin")
	check(is_equal_approx(event.get_strength_at(Vector2(60.0, 0.0)), 0.5), "noise strength attenuates linearly with distance")
	check(is_zero_approx(event.get_strength_at(Vector2(120.0, 0.0))), "noise reaches zero at its radius")
	check(is_zero_approx(event.get_strength_at(Vector2(121.0, 0.0))), "noise is inaudible outside its radius")
	check(not event_script.new(Vector2.ZERO, 0.0, &"footstep").is_valid(), "zero radius noise is rejected")
	check(not event_script.new(Vector2.ZERO, INF, &"footstep").is_valid(), "non-finite radius noise is rejected")
	check(not event_script.new(Vector2.ZERO, 10.0, &"").is_valid(), "empty noise source is rejected")
	var system = system_script.new()
	root.add_child(system)
	system.noise_emitted.connect(_on_noise_emitted)
	var emitted = system.emit_noise(Vector2(5.0, 7.0), 80.0, &"melee")
	check(emitted != null and emitted.is_valid(), "NoiseSystem emits a validated event")
	check(received_events.size() == 1 and received_events[0] == emitted, "world-local listeners receive the emitted event")
	check(system.emit_noise(Vector2.ZERO, -1.0, &"invalid") == null and received_events.size() == 1, "invalid noise does not propagate")
	system.free()
	_finish()


func _on_noise_emitted(event: RefCounted) -> void:
	received_events.append(event)


func _finish() -> void:
	print("Noise foundation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
