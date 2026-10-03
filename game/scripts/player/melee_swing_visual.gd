extends Node2D
## Brief facing arc showing the reach and direction of a successful melee strike.

var _remaining := 0.0
var _reach := 42.0
var _facing := Vector2.RIGHT
var _is_unarmed := true


func _process(delta: float) -> void:
	if _remaining <= 0.0:
		return
	_remaining = maxf(_remaining - delta, 0.0)
	queue_redraw()


func play_attack(facing: Vector2, reach: float, unarmed: bool) -> void:
	_facing = facing.normalized() if not facing.is_zero_approx() else Vector2.RIGHT
	_reach = maxf(reach, 12.0)
	_is_unarmed = unarmed
	_remaining = 0.2
	queue_redraw()


func _draw() -> void:
	if _remaining <= 0.0:
		return
	var fade := clampf(_remaining / 0.2, 0.0, 1.0)
	var color := Color("e5f4de", fade) if _is_unarmed else Color("f2cf69", fade)
	var half_arc := deg_to_rad(55.0)
	var center_angle := _facing.angle()
	var start_angle := center_angle - half_arc
	var end_angle := center_angle + half_arc
	var outer := _reach
	var inner := _reach * 0.62
	draw_arc(Vector2.ZERO, outer, start_angle, end_angle, 20, Color("18201a", fade), 8.0, true)
	draw_arc(Vector2.ZERO, outer, start_angle, end_angle, 20, color, 4.0, true)
	draw_arc(Vector2.ZERO, inner, start_angle, end_angle, 20, color, 2.0, true)
