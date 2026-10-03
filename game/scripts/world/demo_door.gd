class_name DemoDoor
extends Interactable
## Interactable blocking door, opened or closed by nearby E interaction.

@export var starts_open := false
var is_open := false
var _blocking_shape: CollisionShape2D
var _visual: Polygon2D


func _ready() -> void:
	add_to_group("demo_doors")
	interaction_priority = 20
	_blocking_shape = get_node_or_null("DoorBody/CollisionShape2D") as CollisionShape2D
	_visual = get_node_or_null("Visual") as Polygon2D
	set_open(starts_open)


func interact(_interactor: Node2D) -> void:
	set_open(not is_open)


func set_open(value: bool) -> void:
	is_open = value
	if _blocking_shape != null:
		_blocking_shape.set_deferred("disabled", is_open)
	if _visual != null:
		_visual.color = Color("576b54") if is_open else Color("a97646")


func get_interaction_prompt(_interactor: Node2D) -> String:
	return "Close Door" if is_open else "Open Door"
