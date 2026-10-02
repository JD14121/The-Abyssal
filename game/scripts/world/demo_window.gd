class_name DemoWindow
extends Interactable
## Openable window that toggles its collision and can be crossed when open.

var is_open := false
var _blocking_shape: CollisionShape2D
var _visual: Polygon2D


func _ready() -> void:
	add_to_group("demo_windows")
	_blocking_shape = get_node_or_null("WindowBody/CollisionShape2D") as CollisionShape2D
	_visual = get_node_or_null("Visual") as Polygon2D
	set_open(false)


func interact(_interactor: Node2D) -> void:
	set_open(not is_open)


func set_open(value: bool) -> void:
	is_open = value
	if _blocking_shape != null:
		_blocking_shape.set_deferred("disabled", is_open)
	if _visual != null:
		_visual.color = Color("647e72") if is_open else Color("83b6b5")


func get_interaction_prompt(_interactor: Node2D) -> String:
	return "Close Window" if is_open else "Open Window"
