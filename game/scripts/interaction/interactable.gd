class_name Interactable
extends Area2D
## Base contract for world objects that can receive interaction requests.


func can_interact(_interactor: Node2D) -> bool:
	return true


func interact(_interactor: Node2D) -> void:
	push_warning("Interactable.interact() must be implemented by a concrete target.")


func get_interaction_prompt(_interactor: Node2D) -> String:
	return "Interact"
