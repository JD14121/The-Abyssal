extends RefCounted
## Validated static melee weapon data.

var id: StringName
var item_id: StringName
var kind: StringName
var melee_damage: float
var melee_range: float
var attack_interval: float
var damage: float
var range: float
var ammo_item_id: StringName
var magazine_size: int
var reload_time: float
var noise_radius: float
var projectile_speed: float
var source_file: String


func _init(data: Dictionary, source: String = "") -> void:
	id = StringName(data.get("id", ""))
	item_id = StringName(data.get("item_id", ""))
	kind = StringName(data.get("kind", "melee"))
	melee_damage = float(data.get("melee_damage", 0.0))
	melee_range = float(data.get("melee_range", 0.0))
	attack_interval = float(data.get("attack_interval", 0.0))
	damage = float(data.get("damage", 0.0))
	range = float(data.get("range", 0.0))
	ammo_item_id = StringName(data.get("ammo_item_id", ""))
	magazine_size = int(data.get("magazine_size", 0))
	reload_time = float(data.get("reload_time", 0.0))
	noise_radius = float(data.get("noise_radius", 0.0))
	projectile_speed = float(data.get("projectile_speed", 0.0))
	source_file = source
