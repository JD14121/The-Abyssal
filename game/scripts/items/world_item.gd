class_name WorldItem
extends Interactable
## Spatial runtime holder for one existing ItemInstance.

var _item: ItemInstance
var _initialized := false


func initialize(value: Variant) -> bool:
	if _initialized or not value is ItemInstance:
		return false
	var item := value as ItemInstance
	if not is_instance_valid(item) or not item.is_valid():
		return false
	_item = item
	_initialized = true
	return true


func has_item() -> bool:
	return is_instance_valid(_item) and _item.is_valid()


func get_item() -> ItemInstance:
	return _item if has_item() else null


func take_item() -> ItemInstance:
	if not has_item():
		return null
	var item := _item
	_item = null
	return item


func can_interact(interactor: Node2D) -> bool:
	return has_item() and is_instance_valid(interactor) and interactor.has_method("try_pickup_world_item")


func interact(interactor: Node2D) -> void:
	if not can_interact(interactor):
		return
	if not interactor.has_method("try_pickup_world_item"):
		return
	interactor.call("try_pickup_world_item", self)


func get_interaction_prompt(_interactor: Node2D) -> String:
	return "Pick up" if has_item() else ""
