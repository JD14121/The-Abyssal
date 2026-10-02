class_name Corpse
extends Interactable
## Non-blocking world representation of a depleted Creature.

signal inspected(corpse: Node)

var source_creature_definition_id: StringName = &""
var inspection_count := 0
var _initialized := false
var _id_pattern := RegEx.create_from_string("^[a-z][a-z0-9_]*$")


func initialize(source_id: Variant) -> bool:
	if not (source_id is String or source_id is StringName):
		return false
	var value := String(source_id)
	if _id_pattern.search(value) == null:
		return false
	source_creature_definition_id = StringName(value)
	_initialized = true
	return true


func can_interact(_interactor: Node2D) -> bool:
	return _initialized and is_inside_tree()


func interact(interactor: Node2D) -> void:
	if not can_interact(interactor):
		return
	inspection_count += 1
	inspected.emit(self)


func get_interaction_prompt(_interactor: Node2D) -> String:
	return "Inspect Corpse" if _initialized else ""
