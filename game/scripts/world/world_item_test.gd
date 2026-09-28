extends Node2D
## Deterministic development scene for pickup and Inventory feedback.

const FactoryScript = preload("res://scripts/items/item_factory.gd")
const WorldItemScene: PackedScene = preload("res://scenes/items/world_item.tscn")

@onready var _player_inventory: PlayerInventoryComponent = $Player/PlayerInventoryComponent
@onready var _status: Label = $CanvasLayer/Status

var _last_item_id := ""


func _ready() -> void:
	var factory = FactoryScript.new(get_tree().root.get_node("DataRegistry"))
	_player_inventory.item_picked_up.connect(_on_item_picked_up)
	_spawn_item(factory, &"kitchen_knife", Vector2(260, 240))
	_spawn_item(factory, &"water_bottle", Vector2(295, 240))


func _process(_delta: float) -> void:
	var inventory := _player_inventory.get_inventory()
	if inventory == null:
		_status.text = "Inventory unavailable"
		return
	var weight := inventory.get_total_weight()
	_status.text = "Inventory Count: %d\nWeight: %.2f kg\nLast Pickup ID: %s\nInteract: E" % [inventory.get_item_count(), weight, _last_item_id]


func _spawn_item(factory: RefCounted, definition_id: StringName, position: Vector2) -> void:
	var item = factory.create(definition_id)
	if item == null:
		push_error("[WorldItemTest] Could not create test item '%s'." % definition_id)
		return
	var world_item := WorldItemScene.instantiate() as WorldItem
	if world_item == null or not world_item.initialize(item):
		push_error("[WorldItemTest] Could not initialize test WorldItem '%s'." % definition_id)
		return
	world_item.position = position
	add_child(world_item)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(640, 480)), Color(0.09, 0.12, 0.15))
	for x in range(32, 640, 32):
		draw_line(Vector2(x, 0), Vector2(x, 480), Color(0.14, 0.18, 0.21))
	for y in range(32, 480, 32):
		draw_line(Vector2(0, y), Vector2(640, y), Color(0.14, 0.18, 0.21))


func _on_item_picked_up(instance_id: String) -> void:
	_last_item_id = instance_id
