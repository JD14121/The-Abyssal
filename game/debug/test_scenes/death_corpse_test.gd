extends Node2D
## Scene-local assembly for Player defeat and Creature-to-Corpse behavior.

const ItemFactoryScript = preload("res://scripts/items/item_factory.gd")

@onready var player: CharacterBody2D = $Player
@onready var zombie: ZombieController = $Zombie
@onready var coordinator: CombatCoordinator = $CombatCoordinator
@onready var status: Label = $CanvasLayer/Status

var last_corpse_definition_id := ""
var corpse_spawn_count := 0


func _ready() -> void:
	var navigation := NavigationPolygon.new()
	navigation.add_outline(PackedVector2Array([Vector2(-550, -350), Vector2(-550, 350), Vector2(550, 350), Vector2(550, -350)]))
	NavigationServer2D.bake_from_source_geometry_data(navigation, NavigationMeshSourceGeometryData2D.new())
	$NavigationRegion2D.navigation_polygon = navigation
	zombie.set_target(player)
	var registry := get_node("/root/DataRegistry")
	var knife = ItemFactoryScript.new(registry).create(&"kitchen_knife")
	var inventory = player.get_node("PlayerInventoryComponent").get_inventory()
	if knife != null and inventory.add_item(knife):
		player.get_node("PlayerMeleeComponent").equip_melee_weapon(knife.instance_id)
	var death_component = zombie.get_node("CreatureDeathComponent")
	death_component.corpse_spawned.connect(_on_corpse_spawned)


func _process(_delta: float) -> void:
	var player_defeat = player.get_node("PlayerDefeatComponent")
	var player_health: float = player.get_damage_receiver().get_current_health()
	var zombie_health: float = zombie.get_damage_receiver().get_current_health() if is_instance_valid(zombie) else 0.0
	var ai_status := "removed"
	var failure := ""
	if is_instance_valid(zombie):
		ai_status = "enabled" if zombie.initialized else "disabled"
		failure = zombie.get_node("CreatureDeathComponent").last_error
	var inspection_total := 0
	for corpse in find_children("*", "Corpse", true, false):
		inspection_total += corpse.inspection_count
	status.text = "Phase 12 — Death & Corpse Lifecycle\n" + \
		"Move: WASD / arrows | Attack: Space | Inspect: E\n" + \
		"Player Health: %.1f | defeated: %s | Inventory: %d items\n" % [player_health, player_defeat.is_defeated(), player.get_node("PlayerInventoryComponent").get_inventory().get_item_count()] + \
		"Zombie Health: %.1f | AI: %s | Corpse count: %d\n" % [zombie_health, ai_status, find_children("*", "Corpse", true, false).size()] + \
		"Last corpse source: %s | inspections: %d\n" % [last_corpse_definition_id, inspection_total] + \
		("Lifecycle failure: %s" % failure if not failure.is_empty() else "No death UI, loot, drops or persistence.")


func _on_corpse_spawned(corpse: Node2D) -> void:
	corpse_spawn_count += 1
	last_corpse_definition_id = String(corpse.source_creature_definition_id)
