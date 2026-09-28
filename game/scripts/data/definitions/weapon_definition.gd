extends RefCounted
## Validated static melee weapon data.

var id: StringName
var item_id: StringName
var melee_damage: float
var melee_range: float
var attack_interval: float
var source_file: String


func _init(data: Dictionary, source: String = "") -> void:
	id = StringName(data.get("id", ""))
	item_id = StringName(data.get("item_id", ""))
	melee_damage = float(data.get("melee_damage", 0.0))
	melee_range = float(data.get("melee_range", 0.0))
	attack_interval = float(data.get("attack_interval", 0.0))
	source_file = source
