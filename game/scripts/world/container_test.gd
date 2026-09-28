extends Node2D
## Deterministic test scene for Container access and single-item transfers.

const FactoryScript = preload("res://scripts/items/item_factory.gd")
const TransferScript = preload("res://scripts/inventory/inventory_transfer.gd")
const ContainerScene: PackedScene = preload("res://scenes/interactables/container.tscn")

@onready var _player: CharacterBody2D = $Player
@onready var _player_inventory: PlayerInventoryComponent = $Player/PlayerInventoryComponent
@onready var _access: ContainerAccessComponent = $Player/ContainerAccessComponent
@onready var _status: Label = $CanvasLayer/Status

var _transfer := TransferScript.new()
var _last_transfer_result := "No transfer yet"
var _one_was_down := false
var _two_was_down := false


func _ready() -> void:
	var factory = FactoryScript.new(get_tree().root.get_node("DataRegistry"))
	var knife = factory.create_with_condition(&"kitchen_knife", 0.37)
	_player_inventory.get_inventory().add_item(knife)
	_spawn_container("ContainerA", Vector2(260, 240), &"canned_beans")
	_spawn_container("ContainerB", Vector2(300, 240), &"water_bottle")


func _process(_delta: float) -> void:
	var active := _access.get_active_container()
	var one_down := Input.is_key_pressed(KEY_1)
	var two_down := Input.is_key_pressed(KEY_2)
	if one_down and not _one_was_down:
		_transfer_first(_player_inventory.get_inventory(), active.get_inventory() if active != null else null)
	if two_down and not _two_was_down:
		_transfer_first(active.get_inventory() if active != null else null, _player_inventory.get_inventory())
	_one_was_down = one_down
	_two_was_down = two_down
	var player_items: Inventory = _player_inventory.get_inventory()
	var active_name: String = active.name if active != null else "None"
	var active_count: int = active.get_inventory().get_item_count() if active != null else 0
	var active_weight: float = active.get_inventory().get_total_weight() if active != null else 0.0
	_status.text = "Active Container: %s\nPlayer: %d items, %.2f kg\nContainer: %d items, %.2f kg\nLast Transfer: %s\nDebug transfer: 1 to container / 2 to player" % [
		active_name,
		player_items.get_item_count(),
		player_items.get_total_weight(),
		active_count,
		active_weight,
		_last_transfer_result,
	]


func _spawn_container(node_name: String, position: Vector2, test_definition_id: StringName) -> void:
	var container := ContainerScene.instantiate() as WorldContainer
	container.name = node_name
	container.position = position
	add_child(container)
	var factory = FactoryScript.new(get_tree().root.get_node("DataRegistry"))
	var item = factory.create_with_condition(test_definition_id, 0.37)
	if item == null or not container.get_inventory().add_item(item):
		push_error("[ContainerTest] Failed to seed test Container '%s'." % node_name)


func _transfer_first(source: Inventory, destination: Inventory) -> void:
	if source == null or destination == null or source.get_all_items().is_empty():
		_last_transfer_result = "No active Container or source item"
		return
	var item := source.get_all_items()[0]
	var succeeded: bool = _transfer.transfer_item(source, destination, item.instance_id)
	_last_transfer_result = "Transferred %s" % item.definition_id if succeeded else "; ".join(_transfer.get_errors())


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(640, 480)), Color(0.09, 0.12, 0.15))
	for x in range(32, 640, 32):
		draw_line(Vector2(x, 0), Vector2(x, 480), Color(0.14, 0.18, 0.21))
	for y in range(32, 480, 32):
		draw_line(Vector2(0, y), Vector2(640, y), Color(0.14, 0.18, 0.21))
