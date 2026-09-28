class_name ConsumableDefinition
extends RefCounted
## Static profile describing the survival effects for using one ItemDefinition.

var id: StringName
var item_id: StringName
var hunger_delta: float = 0.0
var thirst_delta: float = 0.0
var source_file: String


func _init(data: Dictionary, source: String) -> void:
	id = StringName(data["id"])
	item_id = StringName(data["item_id"])
	hunger_delta = float(data.get("hunger_delta", 0.0))
	thirst_delta = float(data.get("thirst_delta", 0.0))
	source_file = source
