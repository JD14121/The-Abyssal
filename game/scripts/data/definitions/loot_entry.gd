class_name LootEntry
extends RefCounted
## Static selection rules referencing an ItemDefinition by ID.

var item_id: StringName
var weight: float
var chance: float
var min_quantity: int
var max_quantity: int


func _init(data: Dictionary) -> void:
	item_id = StringName(data["item_id"])
	weight = float(data["weight"])
	chance = float(data.get("chance", 1.0))
	min_quantity = int(data.get("min_quantity", 1))
	max_quantity = int(data.get("max_quantity", min_quantity))
