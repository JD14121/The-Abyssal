class_name MaterialDefinition
extends RefCounted
## Shared static data. Consumers must treat definitions as read-only.

var id: StringName
var name: String
var density: float
var flammable: bool
var source_file: String


func _init(data: Dictionary, source: String) -> void:
	id = StringName(data["id"])
	name = data["name"]
	density = float(data.get("density", 1.0))
	flammable = data.get("flammable", false)
	source_file = source
