class_name DemoWorldGround
extends Node2D
## Static town ground, drawn behind the roofless building shells and actors.

var world_bounds := Vector2(1800.0, 1200.0)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, world_bounds), Color("343b35"))
	draw_rect(Rect2(Vector2(0.0, 500.0), Vector2(world_bounds.x, 160.0)), Color("625e53"))
	draw_rect(Rect2(Vector2(0.0, 576.0), Vector2(world_bounds.x, 4.0)), Color("8f896f"))
	for x in range(32, int(world_bounds.x), 64):
		draw_line(Vector2(x, 0), Vector2(x, world_bounds.y), Color("465047"), 1.0)
	for y in range(32, int(world_bounds.y), 64):
		draw_line(Vector2(0, y), Vector2(world_bounds.x, y), Color("465047"), 1.0)
	for x in [80.0, 860.0, 1720.0]:
		for y in [90.0, 1110.0]:
			draw_circle(Vector2(x, y), 18.0, Color("40543c"))
			draw_circle(Vector2(x - 3, y - 4), 12.0, Color("58734d"))
