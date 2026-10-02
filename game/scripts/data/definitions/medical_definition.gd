extends RefCounted
## Validated static treatment profile for one Item definition.

var id: StringName
var item_id: StringName
var bleeding_reduction_per_game_hour: float
var infection_reduction_per_game_hour: float
var source_file: String


func _init(data: Dictionary, source: String = "") -> void:
	id = StringName(data.get("id", ""))
	item_id = StringName(data.get("item_id", ""))
	bleeding_reduction_per_game_hour = float(data.get("bleeding_reduction_per_game_hour", 0.0))
	infection_reduction_per_game_hour = float(data.get("infection_reduction_per_game_hour", 0.0))
	source_file = source
