extends Node2D

const PlayerScene = preload("res://scenes/player/player.tscn")
const FactoryScript = preload("res://scripts/items/item_factory.gd")
const UseServiceScript = preload("res://scripts/consumables/consumable_use_service.gd")

@onready var _status: Label = $CanvasLayer/Status

var _player: CharacterBody2D
var _inventory: Inventory
var _survival: SurvivalState
var _factory: Variant
var _use_service: Variant
var _beans_instance_id := ""
var _water_instance_id := ""
var _hammer_instance_id := ""
var _last_result := "Ready"


func _ready() -> void:
	var registry: Node = get_tree().root.get_node("DataRegistry")
	_player = PlayerScene.instantiate()
	_player.position = Vector2(400.0, 300.0)
	add_child(_player)
	var inventory_component = _player.get_node("PlayerInventoryComponent")
	_inventory = inventory_component.get_inventory()
	_survival = _player.get_node("SurvivalComponent").state
	_factory = FactoryScript.new(registry)
	_use_service = UseServiceScript.new(registry)
	_add_starting_item(&"canned_beans", "beans")
	_add_starting_item(&"water_bottle", "water")
	_add_starting_item(&"hammer", "hammer")
	_refresh_status()


func _process(_delta: float) -> void:
	_refresh_status()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1:
			_use_instance(_beans_instance_id, "canned beans")
		KEY_2:
			_use_instance(_water_instance_id, "water bottle")
		KEY_3:
			if GameClock.advance(3600.0):
				_last_result = "Advanced one game hour"
			else:
				_last_result = "GameClock rejected one-hour advance"
		KEY_H:
			_use_instance(_hammer_instance_id, "hammer")
	_refresh_status()


func _add_starting_item(definition_id: StringName, role: String) -> void:
	var item = _factory.create(definition_id)
	if item == null or not _inventory.add_item(item):
		_last_result = "Could not add test item %s" % definition_id
		return
	match role:
		"beans": _beans_instance_id = item.instance_id
		"water": _water_instance_id = item.instance_id
		"hammer": _hammer_instance_id = item.instance_id


func _use_instance(instance_id: String, label: String) -> void:
	if instance_id.is_empty():
		_last_result = "No %s test item is available" % label
		return
	if _use_service.use_item(_inventory, _survival, instance_id):
		_last_result = "Used %s" % label
	else:
		_last_result = "Use %s failed: %s" % [label, "; ".join(_use_service.get_errors())]


func _refresh_status() -> void:
	if _inventory == null or _survival == null:
		return
	var item_lines := PackedStringArray()
	for item in _inventory.get_all_items():
		item_lines.append("%s [%s]" % [item.definition_id, item.instance_id.substr(0, 8)])
	var pause_text := "paused" if GameClock.is_paused() else "running"
	_status.text = "Phase 8 — Consumable Foundation\n" + \
		"1: use beans   2: use water   3: advance one hour   H: try non-consumable   WASD: move\n" + \
		"Clock: %.2f game hours (%s)\n" % [GameClock.get_elapsed_game_seconds() / 3600.0, pause_text] + \
		"Health: %.1f   Hunger: %.1f   Thirst: %.1f\n" % [_survival.get_health(), _survival.get_hunger(), _survival.get_thirst()] + \
		"Inventory (%d): %s\n" % [_inventory.get_item_count(), ", ".join(item_lines)] + \
		"Last result: " + _last_result
