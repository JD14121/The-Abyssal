extends SceneTree
## Equipment slots point to exact ItemInstances still owned by Inventory.

const PLAYER_SCENE := "res://scenes/player/player.tscn"
const FACTORY := "res://scripts/items/item_factory.gd"
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
	var player: Node = load(PLAYER_SCENE).instantiate()
	root.add_child(player)
	await process_frame
	var equipment = player.get_node_or_null("EquipmentComponent")
	check(equipment != null, "Player has EquipmentComponent")
	if equipment != null:
		var factory = load(FACTORY).new(root.get_node("DataRegistry"))
		var knife: ItemInstance = factory.create(&"kitchen_knife")
		var shirt: ItemInstance = factory.create(&"cotton_shirt")
		var inventory = player.get_node("PlayerInventoryComponent").get_inventory()
		check(inventory.add_item(knife) and inventory.add_item(shirt), "Items remain inventory-owned while being equipped")
		check(equipment.equip_item(&"hands", knife.instance_id), "weapon can be equipped in Hands")
		check(equipment.get_equipped_instance_id(&"hands") == knife.instance_id and inventory.has_item(knife.instance_id), "equipment references exact owned instance")
		check(equipment.equip_item(&"body", shirt.instance_id), "clothing can be equipped in Body")
		check(not equipment.equip_item(&"head", knife.instance_id), "weapon cannot be equipped in a clothing slot")
		check(not equipment.equip_item(&"hands", "missing"), "unknown item instance is rejected")
		inventory.remove_item(knife.instance_id)
		check(equipment.get_equipped_instance_id(&"hands").is_empty(), "removed ItemInstance clears stale equipment reference")
	player.queue_free()
	await process_frame
	print("Equipment foundation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
