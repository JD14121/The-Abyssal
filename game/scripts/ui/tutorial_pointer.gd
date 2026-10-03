extends Control
## Screen-space arrow and outline that points to the current tutorial control.

const ACCENT := Color("f2cf69")
const OUTLINE := Color("18201a")

var target_control: Control
var _pulse := 0.0


func _process(delta: float) -> void:
	if not is_instance_valid(target_control):
		visible = false
		return
	visible = target_control.is_visible_in_tree()
	_pulse = fposmod(_pulse + delta * 2.4, TAU)
	queue_redraw()


func set_target(value: Control) -> void:
	var next_target: Control = value if is_instance_valid(value) else null
	if target_control == next_target:
		return
	target_control = next_target
	visible = is_instance_valid(target_control) and target_control.is_visible_in_tree()
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(target_control) or not target_control.is_visible_in_tree():
		return
	var target_rect := _get_visible_target_rect()
	if target_rect.size.x <= 0.0 or target_rect.size.y <= 0.0:
		return
	var frame := target_rect.grow(6.0 + sin(_pulse) * 1.5)
	draw_rect(frame, OUTLINE, false, 8.0)
	draw_rect(frame, ACCENT, false, 3.0)
	var center := target_rect.get_center()
	var arrow_start := center + Vector2(-34.0, -29.0)
	var arrow_end := center + Vector2(-17.0, -14.0)
	draw_line(arrow_start, arrow_end, OUTLINE, 9.0, true)
	draw_line(arrow_start, arrow_end, ACCENT, 4.0, true)
	var direction := (arrow_end - arrow_start).normalized()
	var side := Vector2(-direction.y, direction.x) * 8.0
	var arrow_base := arrow_end - direction * 14.0
	draw_colored_polygon(PackedVector2Array([arrow_end, arrow_base + side, arrow_base - side]), ACCENT)


func _get_visible_target_rect() -> Rect2:
	var visible_rect := target_control.get_global_rect()
	var ancestor := target_control.get_parent()
	while ancestor is Control:
		var control := ancestor as Control
		if control.clip_contents:
			visible_rect = visible_rect.intersection(control.get_global_rect())
		ancestor = control.get_parent()
	return visible_rect
