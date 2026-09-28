class_name ItemDefinition
extends RefCounted
## Shared static data, never an inventory instance or mutable gameplay state.

var id: StringName
var name: String
var category: String
var mass: float
var materials: Array[StringName] = []
var source_file: String


func _init(data: Dictionary, source: String) -> void:
	id = StringName(data["id"])
	name = data["name"]
	category = data["category"]
	mass = float(data.get("mass", 0.0))
	for material_id in data.get("materials", []):
		materials.append(StringName(material_id))
	materials.make_read_only()
	source_file = source
