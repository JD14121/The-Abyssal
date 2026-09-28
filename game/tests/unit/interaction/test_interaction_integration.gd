extends SceneTree
## Verify actual Area2D detection, nearest-target changes, E input and range exit.

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	var packed: PackedScene = load("res://debug/test_scenes/interaction_test.tscn")
	check(packed != null, "integration test scene loads")
	if packed == null:
		_finish()
		return
	var world := packed.instantiate()
	root.add_child(world)
	var player: CharacterBody2D = world.get_node("Player")
	var interaction: Area2D = player.get_node("InteractionComponent")
	var target_a: Interactable = world.get_node("DebugInteractableA")
	var target_b: Interactable = world.get_node("DebugInteractableB")
	await _frames(5)
	check(interaction.get_current_target() == target_a, "physics detects the nearest in-range target")
	check(interaction.get_candidates().size() == 2, "both in-range interaction areas are tracked")
	player.global_position = Vector2(260, 240)
	await _frames(5)
	check(interaction.get_current_target() == target_b, "moving changes selection to the closer target")
	check(target_b.get_interaction_prompt(player) == "Use Test Object", "debug target supplies a prompt")
	Input.action_press(&"interact")
	await _frames(6)
	Input.action_release(&"interact")
	check(target_b.interaction_count == 1, "one E action press makes one interaction request")
	player.global_position = Vector2(500, 240)
	await _frames(5)
	check(interaction.get_candidates().is_empty(), "leaving range removes all candidates")
	check(interaction.get_current_target() == null, "leaving range clears current target")
	Input.action_press(&"interact")
	await _frames(3)
	Input.action_release(&"interact")
	check(target_b.interaction_count == 1, "E with no target does nothing")
	target_a.queue_free()
	target_b.queue_free()
	await process_frame
	world.queue_free()
	_finish()


func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame
	await process_frame


func _finish() -> void:
	print("Interaction integration: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
