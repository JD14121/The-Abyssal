class_name DemoBuilding
extends Node2D
## Small generated residential shell with an accessible doorway and furniture containers.

const CONTAINER_SCENE := preload("res://scenes/interactables/container.tscn")
const DOOR_SCENE := preload("res://scenes/interactables/door.tscn")
const WINDOW_SCENE := preload("res://scenes/interactables/window.tscn")

var building_size := Vector2(260.0, 190.0)
var rooms: Array[Dictionary] = []
var world_seed := 1


func configure(size: Vector2, room_definitions: Array[Dictionary], seed: int) -> bool:
	if not is_finite(size.x) or not is_finite(size.y) or size.x < 160.0 or size.y < 140.0 or room_definitions.is_empty():
		return false
	building_size = size
	rooms = room_definitions.duplicate(true)
	world_seed = seed
	return true


func _ready() -> void:
	_build_wall(Vector2(0.0, -building_size.y * 0.5), Vector2(building_size.x, 12.0))
	_build_wall(Vector2(-building_size.x * 0.5, -building_size.y * 0.30), Vector2(12.0, building_size.y * 0.40))
	_build_wall(Vector2(-building_size.x * 0.5, building_size.y * 0.33), Vector2(12.0, building_size.y * 0.34))
	_build_wall(Vector2(building_size.x * 0.5, -building_size.y * 0.30), Vector2(12.0, building_size.y * 0.40))
	_build_wall(Vector2(building_size.x * 0.5, building_size.y * 0.33), Vector2(12.0, building_size.y * 0.34))
	_add_window(Vector2(-building_size.x * 0.5, 4.0), true)
	_add_window(Vector2(building_size.x * 0.5, 4.0), true)
	var door_width := 54.0
	var half_side := (building_size.x - door_width) * 0.5
	_build_wall(Vector2(-door_width * 0.5 - half_side * 0.5, building_size.y * 0.5), Vector2(half_side, 12.0))
	_build_wall(Vector2(door_width * 0.5 + half_side * 0.5, building_size.y * 0.5), Vector2(half_side, 12.0))
	_add_door(Vector2(0.0, building_size.y * 0.5))
	# This divider and doorway give the shell a second room without blocking navigation.
	_build_wall(Vector2(0.0, 26.5), Vector2(12.0, 23.0))
	_build_wall(Vector2(0.0, 90.5), Vector2(12.0, 21.0))
	_add_door(Vector2(0.0, 59.0), 42.0, true)
	_add_furniture()
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(-building_size * 0.5, building_size)
	draw_rect(rect, Color("575a4d"))
	draw_rect(Rect2(rect.position + Vector2(12.0, 12.0), rect.size - Vector2(24.0, 24.0)), Color("837b68"))
	draw_rect(Rect2(rect.position + Vector2(12.0, 12.0), Vector2(building_size.x - 24.0, building_size.y * 0.45)), Color("8e8068"))
	draw_rect(rect, Color("c0b08a"), false, 12.0)
	draw_line(Vector2(0.0, -28.0), Vector2(0.0, 15.0), Color("c0b08a"), 12.0)
	draw_line(Vector2(-building_size.x * 0.5, 4.0), Vector2(-building_size.x * 0.5, 20.0), Color("83b6b5"), 4.0)
	draw_line(Vector2(building_size.x * 0.5, 4.0), Vector2(building_size.x * 0.5, 20.0), Color("83b6b5"), 4.0)
	draw_string(ThemeDB.fallback_font, Vector2(-building_size.x * 0.5 + 18.0, -building_size.y * 0.5 + 30.0), "HOUSE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("e5dfc9"))
	for room in rooms:
		var room_pos := Vector2(float(room.get("label_position", [0.0, 0.0])[0]), float(room.get("label_position", [0.0, 0.0])[1]))
		draw_string(ThemeDB.fallback_font, room_pos, str(room.get("name", room.get("id", "ROOM"))).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("d9d1b7"))


func _build_wall(center: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = center
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	body.add_child(shape)
	add_child(body)


func _add_door(local_position: Vector2, _width := 54.0, vertical := false) -> void:
	var door := DOOR_SCENE.instantiate() as DemoDoor
	if door == null:
		return
	door.position = local_position
	if vertical:
		door.rotation = PI * 0.5
	add_child(door)


func _add_window(local_position: Vector2, vertical := false) -> void:
	var window := WINDOW_SCENE.instantiate() as DemoWindow
	if window == null:
		return
	window.position = local_position
	if vertical:
		window.rotation = PI * 0.5
	add_child(window)


func _add_furniture() -> void:
	var registry := get_tree().root.get_node_or_null("DataRegistry")
	if registry == null or not registry.is_loaded():
		return
	var factory := ItemFactory.new(registry)
	var furniture_index := 0
	for room in rooms:
		for furniture in room.get("furniture", []):
			var container := CONTAINER_SCENE.instantiate() as WorldContainer
			if container == null:
				continue
			container.name = "Furniture_%s_%s" % [room.get("id", "room"), furniture.get("id", "container")]
			container.add_to_group("demo_lootable")
			var position: Array = furniture.get("position", [0, 0])
			container.position = Vector2(float(position[0]), float(position[1]))
			container.set_meta("room_id", room.get("id", ""))
			container.set_meta("loot_profile_id", furniture.get("loot_profile_id", ""))
			add_child(container)
			var resolver := LootResolver.new(registry, factory)
			var populator := ContainerLootPopulator.new(resolver)
			var rng := RandomNumberGenerator.new()
			rng.seed = hash("%d:%d" % [world_seed, furniture_index])
			var loot_id := StringName(furniture.get("loot_profile_id", ""))
			if not populator.populate(container.get_inventory(), loot_id, rng):
				push_warning("[DemoBuilding] Loot placement failed for %s: %s" % [loot_id, "; ".join(populator.get_errors())])
			furniture_index += 1


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if building_size.x >= 160.0 and building_size.y >= 140.0 else PackedStringArray(["Building dimensions are too small for the room layout"])
