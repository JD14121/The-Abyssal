extends Interactable
## Development-only target used to verify the generic interaction pipeline.

@export var enabled: bool = true
@export var prompt: String = "Use Test Object"

var interaction_count: int = 0


func can_interact(_interactor: Node2D) -> bool:
	return enabled


func interact(_interactor: Node2D) -> void:
	interaction_count += 1
	print("[DebugInteractable] Interacted.")


func get_interaction_prompt(_interactor: Node2D) -> String:
	return prompt
