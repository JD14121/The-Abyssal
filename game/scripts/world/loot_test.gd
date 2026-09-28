extends Node2D
## Fixed-seed visual smoke test for Loot resolution and Container placement.

const FactoryScript = preload("res://scripts/items/item_factory.gd")
const ResolverScript = preload("res://scripts/loot/loot_resolver.gd")
const PopulatorScript = preload("res://scripts/loot/container_loot_populator.gd")

@onready var _status: Label = $CanvasLayer/Status
@onready var _container_a: WorldContainer = $ContainerA
@onready var _container_b: WorldContainer = $ContainerB


func _ready() -> void:
	var registry: Node = get_tree().root.get_node("DataRegistry")
	var factory = FactoryScript.new(registry)
	var resolver = ResolverScript.new(registry, factory)
	var populator = PopulatorScript.new(resolver)
	var kitchen_rng := RandomNumberGenerator.new()
	kitchen_rng.seed = 12345
	var medical_rng := RandomNumberGenerator.new()
	medical_rng.seed = 67890
	var kitchen_ok: bool = populator.populate(_container_a.get_inventory(), &"loot_test_kitchen", kitchen_rng)
	var medical_ok: bool = populator.populate(_container_b.get_inventory(), &"loot_test_medical", medical_rng)
	var kitchen := _container_a.get_inventory()
	var medical := _container_b.get_inventory()
	_status.text = "Loot test scene (fixed seeds)\nA: loot_test_kitchen | seed 12345 | %d items | %s\n  %s\nB: loot_test_medical | seed 67890 | %d items | %s\n  %s" % [
		kitchen.get_item_count(), "ready" if kitchen_ok else "; ".join(populator.get_errors()), _definition_ids(kitchen.get_all_items()),
		medical.get_item_count(), "ready" if medical_ok else "; ".join(populator.get_errors()), _definition_ids(medical.get_all_items()),
	]


func _definition_ids(items: Array[ItemInstance]) -> String:
	var ids: Array[String] = []
	for item in items:
		ids.append(String(item.definition_id))
	return ", ".join(ids) if not ids.is_empty() else "(empty)"


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(640, 480)), Color(0.09, 0.12, 0.15))
	for x in range(32, 640, 32):
		draw_line(Vector2(x, 0), Vector2(x, 480), Color(0.14, 0.18, 0.21))
	for y in range(32, 480, 32):
		draw_line(Vector2(0, y), Vector2(640, y), Color(0.14, 0.18, 0.21))
