extends SceneTree
## Exercises Container interaction, access lifetime and Player/container transfer.

const TransferScript = preload("res://scripts/inventory/inventory_transfer.gd")
const InventoryScript = preload("res://scripts/inventory/inventory.gd")
const ComponentScript = preload("res://scripts/player/player_inventory_component.gd")

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
	var scene: PackedScene = load("res://debug/test_scenes/container_test.tscn")
	check(scene != null, "Container integration scene loads")
	if scene == null:
		_finish()
		return
	var world := scene.instantiate()
	root.add_child(world)
	var player: CharacterBody2D = world.get_node("Player")
	var player_inventory: PlayerInventoryComponent = player.get_node("PlayerInventoryComponent")
	var access: Variant = player.get_node("ContainerAccessComponent")
	var interaction: Variant = player.get_node("InteractionComponent")
	var container_a: WorldContainer = world.get_node("ContainerA")
	var container_b: WorldContainer = world.get_node("ContainerB")
	await _frames(6)
	check(interaction.get_candidates().size() == 2, "Player detects both nearby Containers")
	check(interaction.get_current_target() == container_a, "nearest Container is selected")
	check(container_a.get_interaction_prompt(player) == "Access Container", "Container exposes a useful interaction prompt")
	Input.action_press(&"interact")
	await _frames(4)
	Input.action_release(&"interact")
	check(access.get_active_container() == container_a, "E starts access to selected Container")

	var transfer := TransferScript.new()
	var knife: ItemInstance = player_inventory.get_inventory().get_all_items()[0]
	var beans: ItemInstance = container_a.get_inventory().get_all_items()[0]
	var total_count: int = player_inventory.get_inventory().get_item_count() + container_a.get_inventory().get_item_count()
	check(transfer.transfer_item(player_inventory.get_inventory(), access.get_active_container().get_inventory(), knife.instance_id), "Player to active Container transfer succeeds")
	check(not player_inventory.get_inventory().has_item(knife.instance_id) and container_a.get_inventory().get_item(knife.instance_id) == knife, "Player to Container moves the same instance")
	check(transfer.transfer_item(container_a.get_inventory(), player_inventory.get_inventory(), beans.instance_id), "active Container to Player transfer succeeds")
	check(not container_a.get_inventory().has_item(beans.instance_id) and player_inventory.get_inventory().get_item(beans.instance_id) == beans, "Container to Player moves the same instance")
	check(is_equal_approx(beans.condition, 0.37) and is_equal_approx(knife.condition, 0.37), "both directions preserve runtime condition")
	check(player_inventory.get_inventory().get_item_count() + container_a.get_inventory().get_item_count() == total_count, "Player/container combined count is invariant")

	var limited_player: Variant = ComponentScript.new()
	limited_player.max_weight = 0.1
	world.add_child(limited_player)
	var bottle: ItemInstance = container_b.get_inventory().get_all_items()[0]
	check(not transfer.transfer_item(container_b.get_inventory(), limited_player.get_inventory(), bottle.instance_id), "Player capacity rejects Container transfer")
	check(container_b.get_inventory().get_item(bottle.instance_id) == bottle and limited_player.get_inventory().get_item_count() == 0, "capacity failure keeps item in Container")

	player.global_position = Vector2(600, 240)
	await _frames(6)
	check(access.get_active_container() == null, "leaving interaction range clears active Container")
	player.global_position = Vector2(270, 240)
	await _frames(6)
	check(access.set_active_container(container_b), "nearby second Container can become active")
	container_b.queue_free()
	await _frames(2)
	check(access.get_active_container() == null, "freed active Container clears safely")
	world.queue_free()
	await process_frame
	_finish()


func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame
	await process_frame


func _finish() -> void:
	print("Container interaction integration: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
