class_name CreatureDefinition
extends RefCounted
## Immutable-at-runtime parameters shared by creatures using the same definition.

var id: StringName
var name: String
var move_speed: float
var vision_range: float
var attack_range: float
var attack_interval: float
var max_health: float
var melee_damage: float
var source_file: String


func _init(data: Dictionary, source: String) -> void:
	id = StringName(data.id)
	name = data.name
	move_speed = float(data.move_speed)
	vision_range = float(data.vision_range)
	attack_range = float(data.attack_range)
	attack_interval = float(data.attack_interval)
	max_health = float(data.max_health)
	melee_damage = float(data.melee_damage)
	source_file = source
