extends SceneTree
## Exercises empty-by-default Container runtime state and independence.

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
	var scene: PackedScene = load("res://scenes/interactables/container.tscn")
	check(scene != null, "generic Container scene exists")
	if scene == null:
		_finish()
		return
	var first: WorldContainer = scene.instantiate()
	var second: WorldContainer = scene.instantiate()
	root.add_child(first)
	root.add_child(second)
	check(first.get_inventory() != null, "Container owns an Inventory")
	check(first.get_inventory().get_item_count() == 0, "new production Container starts empty")
	check(first.get_inventory() != second.get_inventory(), "each Container owns an independent Inventory")
	var interactor := Node2D.new()
	check(first.can_interact(interactor), "Container follows Interactable eligibility")
	check(first.get_interaction_prompt(interactor) == "Access Container", "Container provides access prompt")
	check(first.get_inventory().get_item_count() == 0 and second.get_inventory().get_item_count() == 0, "separate Containers remain independently empty")
	interactor.free()
	first.queue_free()
	second.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	print("Container foundation: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
