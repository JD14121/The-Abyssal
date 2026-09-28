extends SceneTree
## Unit-level checks for candidate filtering, stable nearest selection and requests.

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
	var component_script = load("res://scripts/interaction/interaction_component.gd")
	var target_scene: PackedScene = load("res://scenes/interactables/debug_interactable.tscn")
	check(component_script != null, "InteractionComponent script exists")
	check(target_scene != null, "DebugInteractable scene exists")
	if component_script == null or target_scene == null:
		_finish()
		return
	var component = component_script.new()
	var target_a = target_scene.instantiate()
	var target_b = target_scene.instantiate()
	var disabled = target_scene.instantiate()
	var interactor := Node2D.new()
	check(InputMap.has_action(&"interact"), "interact action exists")
	var has_e_binding := false
	for event in InputMap.action_get_events(&"interact"):
		if event is InputEventKey and (event.keycode == KEY_E or event.physical_keycode == KEY_E):
			has_e_binding = true
	check(has_e_binding, "interact action is bound to E")
	root.add_child(interactor)
	root.add_child(component)
	root.add_child(target_a)
	root.add_child(target_b)
	root.add_child(disabled)
	component.interactor = interactor
	target_a.position = Vector2(30, 0)
	target_b.position = Vector2(10, 0)
	disabled.position = Vector2(1, 0)
	disabled.enabled = false
	check(component.get_current_target() == null, "no candidates produces a null target")
	component._register_candidate(target_a)
	component._register_candidate(target_a)
	check(component.get_candidates().size() == 1, "duplicate candidates are ignored")
	check(component.get_current_target() == target_a, "one valid candidate becomes current target")
	component._register_candidate(disabled)
	check(component.get_current_target() == target_a, "disabled candidate is ignored")
	component._register_candidate(target_b)
	check(component.get_current_target() == target_b, "nearest valid candidate wins")
	check(component.get_current_prompt() == target_b.get_interaction_prompt(interactor), "current prompt comes from target")
	check(component.try_interact(), "valid current target handles request")
	check(target_b.interaction_count == 1, "one request calls target once")
	component._remove_candidate(target_b)
	check(component.get_current_target() == target_a, "leaving current target selects remaining candidate")
	component._register_candidate(target_b)
	check(component.get_current_target() == target_b, "re-entering candidate updates nearest target")
	component._remove_candidate(target_a)
	check(component.get_current_target() == target_b, "removing a non-current candidate preserves target")
	component._remove_candidate(target_b)
	check(not component.try_interact(), "no target request is safe and returns false")
	component._register_candidate(target_a)
	check(component.get_current_target() == target_a, "candidate can become current again")
	target_a.queue_free()
	await process_frame
	component.refresh_target()
	check(component.get_current_target() == null, "freed candidate is pruned")
	component.free()
	interactor.free()
	target_b.free()
	disabled.free()
	_finish()


func _finish() -> void:
	print("Interaction unit: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
