class_name DemoExtraction
extends Interactable

signal extraction_requested


func get_interaction_prompt(_interactor: Node2D) -> String:
	return "Extract to Safety"


func interact(_interactor: Node2D) -> void:
	extraction_requested.emit()
