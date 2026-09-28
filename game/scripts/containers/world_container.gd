class_name WorldContainer
extends Interactable
## Reusable world entity owning an independent, initially empty Inventory.

@export var max_weight: float = 0.0

var _inventory: Inventory


func _ready() -> void:
	var registry := get_tree().root.get_node_or_null("DataRegistry")
	if registry == null or not registry.is_loaded():
		push_error("[WorldContainer] DataRegistry is unavailable or not ready.")
		return
	_inventory = Inventory.new(registry, max_weight)


func get_inventory() -> Inventory:
	return _inventory


func can_interact(_interactor: Node2D) -> bool:
	return _inventory != null


func interact(interactor: Node2D) -> void:
	if not can_interact(interactor) or not interactor.has_method("set_active_container"):
		return
	interactor.call("set_active_container", self)


func get_interaction_prompt(_interactor: Node2D) -> String:
	return "Access Container" if _inventory != null else ""
