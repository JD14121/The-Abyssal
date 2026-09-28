extends Node2D
## Minimal two-way Player melee and Zombie combat test assembly.

const ItemFactoryScript = preload("res://scripts/items/item_factory.gd")

@onready var player: CharacterBody2D = $Player
@onready var status: Label = $CanvasLayer/Status
var zombies: Array[ZombieController] = []
var knife_instance_id := ""


func _ready() -> void:
	var nav := NavigationPolygon.new()
	nav.add_outline(PackedVector2Array([Vector2(-550, -350), Vector2(-550, 350), Vector2(550, 350), Vector2(550, -350)]))
	NavigationServer2D.bake_from_source_geometry_data(nav, NavigationMeshSourceGeometryData2D.new())
	$NavigationRegion2D.navigation_polygon = nav
	var registry := get_node("/root/DataRegistry")
	var item = ItemFactoryScript.new(registry).create(&"kitchen_knife")
	var inventory = player.get_node("PlayerInventoryComponent").get_inventory()
	if item != null and inventory.add_item(item):
		knife_instance_id = item.instance_id
		player.get_node("PlayerMeleeComponent").equip_melee_weapon(knife_instance_id)
	for zombie in [$ZombieA, $ZombieB]:
		zombie.set_target(player)
		zombies.append(zombie)


func _process(_delta: float) -> void:
	var melee = player.get_node("PlayerMeleeComponent")
	var rows := ["Phase 11 — Player Melee & Weapon Foundation", "Move with WASD / arrows; press Space to attack.",
		"Equipped runtime item: %s | Candidates: %d | Cooldown: %.2f" % [knife_instance_id, melee.get_candidate_count(), melee.cooldown_remaining],
		"Player health: %.1f" % player.get_damage_receiver().get_current_health()]
	for index in zombies.size():
		rows.append("Zombie %d health: %.1f | state: %s" % [index + 1, zombies[index].get_damage_receiver().get_current_health(), zombies[index].get_state_name()])
	rows.append("Health zero is depleted only; no death or corpse behavior.")
	status.text = "\n".join(rows)
