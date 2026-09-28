class_name ContainerAccessComponent
extends Node
## Holds a Player-local reference to the currently accessed nearby Container.

var _active_container: WorldContainer
var _interaction_component: Area2D


func _ready() -> void:
	_interaction_component = get_parent().get_node_or_null("InteractionComponent") as Area2D


func _process(_delta: float) -> void:
	get_active_container()


func set_active_container(value: Variant) -> bool:
	if not value is WorldContainer or not is_instance_valid(value):
		return false
	var container := value as WorldContainer
	if not container.is_inside_tree() or _interaction_component == null:
		return false
	if not _interaction_component.get_candidates().has(container):
		return false
	_active_container = container
	return true


func get_active_container() -> WorldContainer:
	if not is_instance_valid(_active_container):
		_active_container = null
		return null
	if _interaction_component == null or not _interaction_component.get_candidates().has(_active_container):
		_active_container = null
	return _active_container
