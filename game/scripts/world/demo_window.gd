class_name DemoWindow
extends Interactable
## Openable window that toggles its collision and can be crossed when open.

var is_open := false
var is_broken := false
var _blocking_shape: CollisionShape2D
var _visual: Polygon2D
var _health: DemoWindowHealth


func _ready() -> void:
	add_to_group("demo_windows")
	interaction_priority = 20
	_blocking_shape = get_node_or_null("WindowBody/CollisionShape2D") as CollisionShape2D
	_visual = get_node_or_null("Visual") as Polygon2D
	_health = get_node_or_null("DemoWindowHealth") as DemoWindowHealth
	if _health != null:
		_health.health_depleted.connect(_on_health_depleted)
	set_open(false)


func interact(_interactor: Node2D) -> void:
	if is_broken:
		return
	set_open(not is_open)


func set_open(value: bool) -> void:
	if is_broken:
		return
	is_open = value
	if _blocking_shape != null:
		_blocking_shape.set_deferred("disabled", is_open)
	if _visual != null:
		_visual.color = Color("647e72") if is_open else Color("83b6b5")


func break_window() -> void:
	if is_broken:
		return
	is_broken = true
	is_open = true
	if _blocking_shape != null:
		_blocking_shape.set_deferred("disabled", true)
	if _visual != null:
		_visual.visible = false
	queue_redraw()


func get_damage_receiver() -> DamageReceiver:
	return _health


func get_interaction_prompt(_interactor: Node2D) -> String:
	if is_broken:
		return "Broken Window"
	return "Close Window" if is_open else "Open Window · Space to break"


func _draw() -> void:
	if not is_broken:
		return
	var glass_color := Color("d9e7df")
	draw_line(Vector2(-20.0, -4.0), Vector2(-9.0, 3.0), glass_color, 2.0, true)
	draw_line(Vector2(-8.0, -4.0), Vector2(1.0, 4.0), glass_color, 2.0, true)
	draw_line(Vector2(7.0, 3.0), Vector2(20.0, -4.0), glass_color, 2.0, true)
	draw_line(Vector2(-3.0, -4.0), Vector2(3.0, 4.0), Color("b9c3b4"), 1.5, true)


func _on_health_depleted() -> void:
	break_window()
