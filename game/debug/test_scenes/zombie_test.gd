extends Node2D

var attack_request_count := 0

@onready var player: CharacterBody2D = $Player
@onready var zombie: ZombieController = $Zombie
@onready var status: Label = $CanvasLayer/Status


func _ready() -> void:
	var navigation_polygon := NavigationPolygon.new()
	navigation_polygon.add_outline(PackedVector2Array([Vector2(-550, -350), Vector2(-550, 350), Vector2(550, 350), Vector2(550, -350)]))
	navigation_polygon.add_outline(PackedVector2Array([Vector2(-50, -130), Vector2(50, -130), Vector2(50, 130), Vector2(-50, 130)]))
	NavigationServer2D.bake_from_source_geometry_data(navigation_polygon, NavigationMeshSourceGeometryData2D.new())
	$NavigationRegion2D.navigation_polygon = navigation_polygon
	zombie.set_target(player)
	zombie.attack_requested.connect(_on_attack_requested)


func _process(_delta: float) -> void:
	status.text = "Phase 9 — Creature / Zombie Foundation\n" + \
		"Player: WASD / arrows  |  Zombie state: %s\n" % zombie.get_state_name() + \
		"Distance: %.1f  |  Vision: %.0f  |  Attack: %.0f\n" % [zombie.get_target_distance(), zombie.creature_definition.vision_range, zombie.creature_definition.attack_range] + \
		"Attack requests: %d  |  Cooldown: %.2f s\n" % [attack_request_count, zombie.attack_cooldown_remaining] + \
		"No combat or damage is resolved in this phase."


func _on_attack_requested(_attacker: Node2D, _target: Node2D) -> void:
	attack_request_count += 1
