extends Node2D
## Combat-enabled test assembly; unlike zombie_test, this scene connects resolution.

const DamageEventScript = preload("res://scripts/combat/damage_event.gd")

var attack_request_count := 0

@onready var player: CharacterBody2D = $Player
@onready var zombie: ZombieController = $Zombie
@onready var status: Label = $CanvasLayer/Status


func _ready() -> void:
	var navigation_polygon := NavigationPolygon.new()
	navigation_polygon.add_outline(PackedVector2Array([Vector2(-550, -350), Vector2(-550, 350), Vector2(550, 350), Vector2(550, -350)]))
	NavigationServer2D.bake_from_source_geometry_data(navigation_polygon, NavigationMeshSourceGeometryData2D.new())
	$NavigationRegion2D.navigation_polygon = navigation_polygon
	zombie.set_target(player)
	zombie.attack_requested.connect(_on_attack_requested)


func _process(_delta: float) -> void:
	var player_health: float = player.get_damage_receiver().get_current_health()
	var zombie_health: float = zombie.get_damage_receiver().get_current_health()
	status.text = "Phase 10 — Combat Foundation\n" + \
		"Move with WASD / arrows. Zombie state: %s\n" % zombie.get_state_name() + \
		"Player health: %.1f / %.1f  |  Zombie health: %.1f / %.1f\n" % [player_health, player.get_damage_receiver().get_max_health(), zombie_health, zombie.get_damage_receiver().get_max_health()] + \
		"Attack requests: %d  |  Damage per request: %.1f\n" % [attack_request_count, zombie.get_melee_damage()] + \
		"Press H to apply 25 test damage to the Zombie. No death/corpse behavior."


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_H:
		var test_event = DamageEventScript.new(player, zombie, 25.0)
		CombatService.new().apply_damage_event(test_event)


func _on_attack_requested(_attacker: Node2D, _target: Node2D) -> void:
	attack_request_count += 1
