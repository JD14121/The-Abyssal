class_name ZombiePopulationController
extends Node2D
## World-owned bounded Zombie population and distance-based simulation tiers.

const ZombieControllerType = preload("res://scripts/creatures/zombie/zombie_controller.gd")
const CombatCoordinatorType = preload("res://scripts/combat/combat_coordinator.gd")

@export_range(0.1, 10.0, 0.1) var simulation_update_interval := 0.5

var _zombie_scene: PackedScene
var _target: Node2D
var _noise_system: Node
var _max_population := 0
var _activation_radius := 0.0
var _simulation_radius := 0.0
var _zombies: Array[ZombieControllerType] = []
var _errors: Array[String] = []
var _time_until_update := 0.0
var _simulation_tick_phase := 0
var _simplified_elapsed: Dictionary[int, float] = {}
var _combat_coordinator: CombatCoordinator


func configure(zombie_scene: PackedScene, target: Node2D, noise_system: Node,
		max_population: int, activation_radius: float, simulation_radius: float) -> bool:
	_errors.clear()
	if zombie_scene == null or not is_instance_valid(target):
		return _fail("zombie_scene and a live target are required")
	if max_population <= 0 or not is_finite(activation_radius) or not is_finite(simulation_radius) \
		or activation_radius <= 0.0 or simulation_radius < activation_radius:
		return _fail("population cap and radii must be positive; simulation_radius must cover activation_radius")
	var probe := zombie_scene.instantiate()
	var is_zombie := probe is ZombieControllerType
	if is_instance_valid(probe):
		probe.free()
	if not is_zombie:
		return _fail("zombie_scene root must use ZombieController")
	_zombie_scene = zombie_scene
	_target = target
	_noise_system = noise_system if is_instance_valid(noise_system) and noise_system.has_signal("noise_emitted") else null
	_combat_coordinator = CombatCoordinatorType.new()
	_combat_coordinator.name = "CombatCoordinator"
	add_child(_combat_coordinator)
	_max_population = max_population
	_activation_radius = activation_radius
	_simulation_radius = simulation_radius
	return true


func populate(spawn_points: Array) -> int:
	_errors.clear()
	if _zombie_scene == null or not is_instance_valid(_target):
		_fail("population controller is not configured")
		return 0
	for spawn_position in spawn_points:
		if _zombies.size() >= _max_population:
			break
		if not spawn_position is Vector2 or not is_finite(spawn_position.x) or not is_finite(spawn_position.y):
			_errors.append("spawn point must be Vector2 with finite coordinates")
			continue
		var zombie := _zombie_scene.instantiate() as ZombieControllerType
		if zombie == null:
			_errors.append("Zombie scene failed to create ZombieController")
			continue
		add_child(zombie)
		zombie.global_position = spawn_position
		zombie.set_target(_target)
		zombie.set_noise_system(_noise_system)
		zombie.set_wander_origin(spawn_position)
		if not zombie.attack_requested.is_connected(_on_attack_requested):
			zombie.attack_requested.connect(_on_attack_requested)
		_zombies.append(zombie)
	refresh_simulation_tiers(0.0)
	return _zombies.size()


func refresh_simulation_tiers(elapsed_seconds: float) -> void:
	if not is_finite(elapsed_seconds) or elapsed_seconds < 0.0 or not is_instance_valid(_target):
		return
	for index in range(_zombies.size()):
		var zombie := _zombies[index]
		if not is_instance_valid(zombie):
			continue
		var distance := zombie.global_position.distance_to(_target.global_position)
		if distance <= _activation_radius:
			zombie.set_simulation_tier(ZombieControllerType.SimulationTier.FULL)
			_simplified_elapsed[zombie.get_instance_id()] = 0.0
		elif distance <= _simulation_radius:
			zombie.set_simulation_tier(ZombieControllerType.SimulationTier.SIMPLIFIED)
			var instance_id := zombie.get_instance_id()
			_simplified_elapsed[instance_id] = _simplified_elapsed.get(instance_id, 0.0) + elapsed_seconds
			if index % 3 == _simulation_tick_phase:
				zombie.advance_simplified_simulation(_simplified_elapsed[instance_id])
				_simplified_elapsed[instance_id] = 0.0
		else:
			zombie.set_simulation_tier(ZombieControllerType.SimulationTier.DORMANT)
			_simplified_elapsed[zombie.get_instance_id()] = 0.0
	if elapsed_seconds > 0.0:
		_simulation_tick_phase = (_simulation_tick_phase + 1) % 3


func get_population_count() -> int:
	return _zombies.filter(func(zombie): return is_instance_valid(zombie)).size()


func get_full_simulation_count() -> int:
	return _count_tier(ZombieControllerType.SimulationTier.FULL)


func get_simplified_simulation_count() -> int:
	return _count_tier(ZombieControllerType.SimulationTier.SIMPLIFIED)


func get_dormant_count() -> int:
	return _count_tier(ZombieControllerType.SimulationTier.DORMANT)


func get_errors() -> Array[String]:
	return _errors.duplicate()


func _on_attack_requested(attacker: Node2D, target: Node2D) -> void:
	if _combat_coordinator != null:
		_combat_coordinator.handle_attack_requested(attacker, target)


func _process(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	_time_until_update -= delta
	if _time_until_update <= 0.0:
		var interval := clampf(simulation_update_interval, 0.1, 10.0)
		_time_until_update = interval
		refresh_simulation_tiers(interval)


func _count_tier(tier: int) -> int:
	var count := 0
	for zombie in _zombies:
		if is_instance_valid(zombie) and zombie.get_simulation_tier() == tier:
			count += 1
	return count


func _fail(message: String) -> bool:
	_errors.append(message)
	return false
