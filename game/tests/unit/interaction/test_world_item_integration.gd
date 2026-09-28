extends SceneTree
## Runs the real Player Area2D, WorldItem target and E-key pickup flow.

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
	var scene: PackedScene = load("res://debug/test_scenes/world_item_test.tscn")
	check(scene != null, "WorldItem manual test scene loads")
	if scene == null:
		_finish()
		return
	var world := scene.instantiate()
	root.add_child(world)
	var player: CharacterBody2D = world.get_node("Player")
	var component: PlayerInventoryComponent = player.get_node("PlayerInventoryComponent")
	var interaction: Variant = player.get_node("InteractionComponent")
	await _frames(6)
	check(interaction.get_candidates().size() == 2, "Area2D detects both real WorldItems")
	var first = _find_item(world, &"kitchen_knife")
	var second = _find_item(world, &"water_bottle")
	check(interaction.get_current_target() == first, "nearest WorldItem becomes selected target")
	var first_id: String = first.get_item().instance_id
	Input.action_press(&"interact")
	await _frames(6)
	check(component.get_inventory().get_item_count() == 1, "E picks up exactly one ItemInstance")
	check(component.get_inventory().has_item(first_id), "pickup preserves first WorldItem identity")
	check(not is_instance_valid(first), "picked-up WorldItem is freed from the SceneTree")
	check(interaction.get_current_target() == second, "freed target is pruned and next WorldItem is selected")
	await _frames(5)
	check(component.get_inventory().get_item_count() == 1, "holding E does not duplicate pickup")
	Input.action_release(&"interact")
	await _frames(2)
	Input.action_press(&"interact")
	await _frames(4)
	Input.action_release(&"interact")
	check(component.get_inventory().get_item_count() == 2, "second E press picks up the second WorldItem")
	check(interaction.get_current_target() == null, "both removed WorldItems leave no stale interaction target")
	world.queue_free()
	await process_frame
	_finish()


func _find_item(world: Node, definition_id: StringName) -> WorldItem:
	for child in world.get_children():
		if child is WorldItem and child.has_item() and child.get_item().definition_id == definition_id:
			return child
	return null


func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame
	await process_frame


func _finish() -> void:
	print("WorldItem interaction integration: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
