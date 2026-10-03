extends Node2D
## Bounded, seed-reproducible survival demo world composed from local runtime services.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const ZOMBIE_SCENE := preload("res://scenes/creatures/zombie/zombie.tscn")
const BUILDING_SCRIPT := preload("res://scripts/world/demo_building.gd")
const POPULATION_SCRIPT := preload("res://scripts/creatures/zombie_population_controller.gd")
const NOISE_SCRIPT := preload("res://scripts/world/noise/noise_system.gd")
const GRID_SCRIPT := preload("res://scripts/world/world_grid.gd")
const GROUND_SCRIPT := preload("res://scripts/world/demo_world_ground.gd")
const EXTRACTION_SCENE := preload("res://scenes/world/extraction.tscn")
const CORPSE_SCENE := preload("res://scenes/lifecycle/corpse.tscn")
const CREATURE_DEATH_SCRIPT := preload("res://scripts/lifecycle/creature_death_component.gd")
const HUD_SCRIPT := preload("res://scripts/ui/demo_hud.gd")
const LAYOUT_PATH := "res://data/world/demo_town.json"
const HISTORY_ADAPTER := preload("res://scripts/history/world_history_adapter.gd")

@export var world_seed := 14028

var player: CharacterBody2D
var noise_system: Node
var population: Node
var extraction: DemoExtraction
var world_grid: WorldGrid
var history_adapter: Node
var _layout: Dictionary = {}
var _victory := false


func _ready() -> void:
	GameClock.set_paused(false)
	GameClock.set_time_scale(60.0)
	if not DataRegistry.is_loaded() or not _load_layout():
		push_error("[DemoWorld] Startup validation failed")
		get_tree().quit(1)
		return
	world_grid = GRID_SCRIPT.new(32.0, 16)
	history_adapter = HISTORY_ADAPTER.new()
	history_adapter.name = "WorldHistoryAdapter"
	add_child(history_adapter)
	if not history_adapter.configure(self, GameClock, "demo_town"):
		push_error("[DemoWorld] World history configuration failed")
		get_tree().quit(1)
		return
	var ground := GROUND_SCRIPT.new() as Node2D
	ground.name = "WorldGroundVisual"
	ground.set("world_bounds", Vector2(float(_layout.bounds[0]), float(_layout.bounds[1])))
	ground.z_index = -2
	add_child(ground)
	noise_system = Node.new()
	noise_system.name = "NoiseSystem"
	noise_system.set_script(NOISE_SCRIPT)
	add_child(noise_system)
	player = PLAYER_SCENE.instantiate()
	player.name = "Player"
	player.position = Vector2(120.0, 590.0)
	var camera := player.get_node("Camera2D") as Camera2D
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(_layout.bounds[0])
	camera.limit_bottom = int(_layout.bounds[1])
	camera.limit_enabled = true
	add_child(player)
	var survival_state = player.get_node("SurvivalComponent").state
	survival_state.set_hunger(42.0)
	survival_state.set_thirst(58.0)
	y_sort_enabled = true
	_add_boundaries()
	_build_city()
	var tutorial_house := get_node_or_null("House_01") as DemoBuilding
	if tutorial_house != null:
		# Frame the whole house and place the Player just outside its entrance.
		# This gives the first interaction lesson an obvious visual destination.
		player.position = tutorial_house.position + Vector2(0.0, tutorial_house.building_size.y * 0.5 + 96.0)
	_build_extraction()
	_grant_starting_loadout()
	_build_navigation()
	population = POPULATION_SCRIPT.new()
	population.name = "ZombiePopulationController"
	add_child(population)
	var hud := CanvasLayer.new()
	hud.name = "DemoHUD"
	hud.set_script(HUD_SCRIPT)
	hud.connect(&"tutorial_safety_released", _on_tutorial_safety_released)
	add_child(hud)
	await get_tree().physics_frame
	if not population.configure(ZOMBIE_SCENE, player, noise_system, 10, 620.0, 1180.0):
		push_error("[DemoWorld] Population configuration failed: %s" % "; ".join(population.get_errors()))
		return
	population.set_tutorial_single_active_mode(true)
	population.set_tutorial_safety_enabled(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed
	var spawn_positions: Array = []
	for spawn_site: Array in _layout["zombie_spawn_sites"]:
		var spawn_position := Vector2(float(spawn_site[0]), float(spawn_site[1]))
		if spawn_position.distance_to(player.global_position) >= 400.0:
			spawn_positions.append(spawn_site)
	if spawn_positions.size() < 7:
		push_error("[DemoWorld] Need at least 7 Zombie spawn sites outside the tutorial danger radius")
		return
	_shuffle_with_rng(spawn_positions, rng)
	var spawned: Array[Vector2] = []
	for index in range(mini(7, spawn_positions.size())):
		spawned.append(Vector2(spawn_positions[index][0], spawn_positions[index][1]))
	population.populate(spawned)
	for zombie: ZombieController in population.get_zombies():
		var death_component := Node.new()
		death_component.name = "CreatureDeathComponent"
		death_component.set_script(CREATURE_DEATH_SCRIPT)
		death_component.set("corpse_scene", CORPSE_SCENE)
		zombie.add_child(death_component)
	print("[DemoWorld] Playable town ready | seed=%d | zombies=%d" % [world_seed, population.get_population_count()])


func get_seed() -> int:
	return world_seed


func get_population_controller() -> Node:
	return population


func has_won() -> bool:
	return _victory


func _load_layout() -> bool:
	if not FileAccess.file_exists(LAYOUT_PATH):
		return _layout_fail("missing %s" % LAYOUT_PATH)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	if not parsed is Dictionary or parsed.get("version") != 1:
		return _layout_fail("expected version 1 JSON object")
	for field in ["bounds", "building_sites", "room_definitions", "zombie_spawn_sites", "extraction"]:
		if not parsed.has(field):
			return _layout_fail("missing field %s" % field)
	if not parsed.bounds is Array or parsed.bounds.size() != 2 or not parsed.building_sites is Array \
		or parsed.building_sites.size() < 3 or not parsed.room_definitions is Array or parsed.room_definitions.is_empty() \
		or not parsed.zombie_spawn_sites is Array or not parsed.extraction is Array or parsed.extraction.size() != 2:
		return _layout_fail("layout vectors/sites are malformed")
	var room_ids: Dictionary = {}
	for room_index in range(parsed.room_definitions.size()):
		var room: Variant = parsed.room_definitions[room_index]
		if not room is Dictionary or not room.get("id", "") is String or not room.get("name", "") is String \
			or not room.get("furniture", []) is Array or room.get("furniture", []).is_empty():
			return _layout_fail("room_definitions[%d] is malformed" % room_index)
		if room_ids.has(room.id) or not _is_valid_id(room.id):
			return _layout_fail("room_definitions[%d].id is invalid or duplicated" % room_index)
		room_ids[room.id] = true
		for furniture_index in range(room.furniture.size()):
			var furniture: Variant = room.furniture[furniture_index]
			if not furniture is Dictionary or not furniture.get("id", "") is String or not _is_valid_id(furniture.id):
				return _layout_fail("room %s furniture[%d].id is invalid" % [room.id, furniture_index])
			if not furniture.get("position", null) is Array or furniture.position.size() != 2 \
				or not _is_finite_number(furniture.position[0]) or not _is_finite_number(furniture.position[1]):
				return _layout_fail("room %s furniture[%d].position is invalid" % [room.id, furniture_index])
			if absf(float(furniture.position[0])) > 100.0 or absf(float(furniture.position[1])) > 75.0:
				return _layout_fail("room %s furniture[%d] lies outside the building interior" % [room.id, furniture_index])
			var loot_id: Variant = furniture.get("loot_profile_id", "")
			if not loot_id is String or not DataRegistry.has_loot(StringName(loot_id)):
				return _layout_fail("room %s furniture[%d] references unknown loot profile %s" % [room.id, furniture_index, loot_id])
	for field in ["building_sites", "zombie_spawn_sites"]:
		for index in range(parsed[field].size()):
			var site: Variant = parsed[field][index]
			if not site is Array or site.size() != 2 or not _is_finite_number(site[0]) or not _is_finite_number(site[1]):
				return _layout_fail("%s[%d] must be a finite [x, y]" % [field, index])
	if not _is_finite_number(parsed.bounds[0]) or not _is_finite_number(parsed.bounds[1]) \
		or parsed.bounds[0] < 900 or parsed.bounds[1] < 700:
		return _layout_fail("bounds must be finite and at least 900 by 700")
	for field in ["building_sites", "zombie_spawn_sites"]:
		for index in range(parsed[field].size()):
			var site: Array = parsed[field][index]
			if site[0] < 0.0 or site[1] < 0.0 or site[0] > parsed.bounds[0] or site[1] > parsed.bounds[1]:
				return _layout_fail("%s[%d] falls outside world bounds" % [field, index])
	if parsed.extraction[0] < 0.0 or parsed.extraction[1] < 0.0 \
		or parsed.extraction[0] > parsed.bounds[0] or parsed.extraction[1] > parsed.bounds[1]:
		return _layout_fail("extraction position falls outside world bounds")
	_layout = parsed
	return true


func _build_city() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed
	var sites: Array = _layout["building_sites"].duplicate()
	_shuffle_with_rng(sites, rng)
	var rooms: Array[Dictionary] = []
	for room: Dictionary in _layout["room_definitions"]:
		rooms.append(room)
	var bounds := Vector2(float(_layout.bounds[0]), float(_layout.bounds[1]))
	for building_index in range(mini(3, sites.size())):
		var building := BUILDING_SCRIPT.new() as DemoBuilding
		building.name = "House_%02d" % (building_index + 1)
		building.configure(Vector2(250.0, 184.0), rooms, hash("%d:%d" % [world_seed, building_index]))
		var base_site: Array = sites[building_index]
		building.position = Vector2(
			clampf(float(base_site[0]) + rng.randf_range(-28.0, 28.0), 140.0, bounds.x - 140.0),
			clampf(float(base_site[1]) + rng.randf_range(-24.0, 24.0), 110.0, bounds.y - 110.0))
		add_child(building)


func _add_boundaries() -> void:
	var bounds := Vector2(float(_layout.bounds[0]), float(_layout.bounds[1]))
	_add_boundary(Vector2(bounds.x * 0.5, -8.0), Vector2(bounds.x, 16.0))
	_add_boundary(Vector2(bounds.x * 0.5, bounds.y + 8.0), Vector2(bounds.x, 16.0))
	_add_boundary(Vector2(-8.0, bounds.y * 0.5), Vector2(16.0, bounds.y))
	_add_boundary(Vector2(bounds.x + 8.0, bounds.y * 0.5), Vector2(16.0, bounds.y))


func _add_boundary(center: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = center
	body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	body.add_child(shape)
	add_child(body)


func _build_extraction() -> void:
	extraction = EXTRACTION_SCENE.instantiate() as DemoExtraction
	if extraction == null:
		return
	extraction.name = "ExtractionPoint"
	extraction.position = Vector2(_layout.extraction[0], _layout.extraction[1])
	extraction.extraction_requested.connect(_on_extraction_requested)
	add_child(extraction)


func _grant_starting_loadout() -> void:
	var inventory_component := player.get_node("PlayerInventoryComponent")
	var inventory = inventory_component.get_inventory()
	var factory := ItemFactory.new(DataRegistry)
	for item_id in [&"kitchen_knife", &"water_bottle", &"canned_beans", &"clean_bandage", &"pipe_pistol"]:
		var item := factory.create(item_id)
		if item != null and inventory.add_item(item) and item_id == &"kitchen_knife":
			player.get_node("EquipmentComponent").equip_item(&"hands", item.instance_id)
	for round_index in range(10):
		var round_item := factory.create(&"pistol_round")
		if round_item != null:
			inventory.add_item(round_item)


func _build_navigation() -> void:
	var region := NavigationRegion2D.new()
	region.name = "NavigationRegion2D"
	var polygon := NavigationPolygon.new()
	polygon.vertices = PackedVector2Array([Vector2(20, 20), Vector2(1780, 20), Vector2(1780, 1180), Vector2(20, 1180)])
	polygon.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	region.navigation_polygon = polygon
	add_child(region)


func _on_extraction_requested() -> void:
	_victory = true
	player.set_control_enabled(false)
	GameClock.set_paused(true)
	print("[DemoWorld] Extraction successful. Survival demo complete.")


func _on_tutorial_safety_released() -> void:
	if population != null:
		population.set_tutorial_safety_enabled(false)


func _layout_fail(message: String) -> bool:
	push_error("[DemoWorld] %s | %s" % [LAYOUT_PATH, message])
	return false


func _is_finite_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))


func _is_valid_id(value: String) -> bool:
	return not value.is_empty() and value == value.to_lower() and value.is_valid_identifier() and not value.contains(" ")


func _shuffle_with_rng(values: Array, rng: RandomNumberGenerator) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var value: Variant = values[index]
		values[index] = values[swap_index]
		values[swap_index] = value
