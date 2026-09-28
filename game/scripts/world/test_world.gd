extends Node2D
## Development-only collision yard; all geometry is authored in test_world.tscn.

const FLOOR_SIZE := Vector2(1600, 1000)
const GRID_SPACING: int = 64


func _ready() -> void:
	if not DataRegistry.is_loaded():
		push_error("[PlayerFoundation] DataRegistry failed to load; stopping startup.")
		get_tree().quit(1)
		return
	print("[PlayerFoundation] Test world ready. Move with WASD or arrow keys.")


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, FLOOR_SIZE), Color(0.09, 0.12, 0.15))
	var grid_color := Color(0.14, 0.18, 0.21)
	for x in range(GRID_SPACING, int(FLOOR_SIZE.x), GRID_SPACING):
		draw_line(Vector2(x, 0), Vector2(x, FLOOR_SIZE.y), grid_color)
	for y in range(GRID_SPACING, int(FLOOR_SIZE.y), GRID_SPACING):
		draw_line(Vector2(0, y), Vector2(FLOOR_SIZE.x, y), grid_color)
	# Draw directly from collision rectangles so placeholder surfaces match walls.
	for body in $Geometry.get_children():
		var collision: CollisionShape2D = body.get_node("CollisionShape2D")
		var shape: RectangleShape2D = collision.shape
		var rectangle := Rect2(body.position - shape.size * 0.5, shape.size)
		draw_rect(rectangle, Color(0.33, 0.39, 0.44))
		draw_rect(rectangle, Color(0.52, 0.61, 0.66), false, 2.0)
