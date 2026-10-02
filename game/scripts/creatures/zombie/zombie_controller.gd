class_name ZombieController
extends CharacterBody2D
## Zombie perception, target memory, world-noise response and navigation requests.

signal attack_requested(attacker: Node2D, target: Node2D)

# Preserve the original values for existing scene/test contracts.
enum State { IDLE, CHASE, ATTACK, WANDER, INVESTIGATE, SEARCH }
enum SimulationTier { FULL, SIMPLIFIED, DORMANT }

const WORLD_COLLISION_MASK := 1

@export var definition_id: StringName = &"zombie_basic"
@export_range(15.0, 180.0, 1.0) var vision_cone_degrees := 110.0
@export_range(0.01, 1.0, 0.01) var hearing_threshold := 0.08
@export_range(0.0, 30.0, 0.1) var search_duration := 4.0
@export var wandering_enabled := false
@export_range(0.0, 1024.0, 1.0) var wander_radius := 160.0

var current_state: State = State.IDLE
var _simulation_tier: SimulationTier = SimulationTier.FULL
var creature_definition: CreatureDefinition
var target: Node2D
var initialized := false
var attack_cooldown_remaining := 0.0
var _has_last_known_position := false
var last_known_position := Vector2.ZERO

var _noise_system: Node
var _facing_direction := Vector2.RIGHT
var _search_remaining := 0.0
var _search_step := 0
var _wander_origin := Vector2.ZERO
var _wander_target := Vector2.ZERO
var _wander_remaining := 0.0
var _stagger_remaining := 0.0
var simplified_simulation_tick_count := 0

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D


func _ready() -> void:
	_wander_origin = global_position
	initialize_runtime()


func initialize_runtime(registry_override: Node = null) -> bool:
	var registry := registry_override
	if registry == null:
		registry = get_node_or_null("/root/DataRegistry")
	if registry == null or not registry.is_loaded():
		return _fail_initialization("DataRegistry is missing or not ready")
	if not registry.has_creature(definition_id):
		return _fail_initialization("unknown Creature definition %s" % definition_id)
	creature_definition = registry.get_creature(definition_id)
	if creature_definition == null:
		return _fail_initialization("Creature definition %s is unavailable" % definition_id)
	var health_component := get_node_or_null("CreatureHealthComponent") as CreatureHealthComponent
	if health_component == null or not health_component.configure(creature_definition):
		return _fail_initialization("CreatureHealthComponent is missing or could not initialize")
	if not health_component.health_depleted.is_connected(_on_health_depleted):
		health_component.health_depleted.connect(_on_health_depleted)
	initialized = true
	set_physics_process(true)
	return true


func set_target(new_target: Node2D) -> void:
	target = new_target if is_instance_valid(new_target) else null
	if is_instance_valid(target):
		_wander_origin = global_position


func set_noise_system(noise_system: Node) -> void:
	if is_instance_valid(_noise_system) and _noise_system.noise_emitted.is_connected(_on_noise_emitted):
		_noise_system.noise_emitted.disconnect(_on_noise_emitted)
	_noise_system = noise_system if is_instance_valid(noise_system) and noise_system.has_signal("noise_emitted") else null
	if is_instance_valid(_noise_system) and not _noise_system.noise_emitted.is_connected(_on_noise_emitted):
		_noise_system.noise_emitted.connect(_on_noise_emitted)


func set_wander_origin(origin: Vector2, radius: float = -1.0) -> void:
	if not _is_finite_position(origin):
		return
	_wander_origin = origin
	if is_finite(radius) and radius >= 0.0:
		wander_radius = radius


func set_ai_enabled(enabled: bool) -> void:
	if not enabled:
		initialized = false
		target = null
		_has_last_known_position = false
		current_state = State.IDLE
		velocity = Vector2.ZERO
		set_physics_process(false)
		return
	var receiver := get_damage_receiver()
	if creature_definition != null and receiver != null and not receiver.is_depleted():
		initialized = true
		set_physics_process(true)


func set_simulation_tier(tier: int) -> bool:
	if tier not in [SimulationTier.FULL, SimulationTier.SIMPLIFIED, SimulationTier.DORMANT]:
		return false
	match tier:
		SimulationTier.FULL:
			_simulation_tier = SimulationTier.FULL
		SimulationTier.SIMPLIFIED:
			_simulation_tier = SimulationTier.SIMPLIFIED
		SimulationTier.DORMANT:
			_simulation_tier = SimulationTier.DORMANT
	set_physics_process(initialized and _simulation_tier == SimulationTier.FULL)
	return true


func get_simulation_tier() -> int:
	return _simulation_tier


func advance_simplified_simulation(elapsed_seconds: float) -> bool:
	if not initialized or creature_definition == null or _simulation_tier != SimulationTier.SIMPLIFIED \
		or not is_finite(elapsed_seconds) or elapsed_seconds < 0.0:
		return false
	simplified_simulation_tick_count += 1
	attack_cooldown_remaining = maxf(attack_cooldown_remaining - elapsed_seconds, 0.0)
	if not is_instance_valid(target):
		target = null
	if is_instance_valid(target) and can_see_target(target.global_position):
		last_known_position = target.global_position
		_has_last_known_position = true
		current_state = State.CHASE if global_position.distance_to(target.global_position) > creature_definition.attack_range else State.ATTACK
	elif _has_last_known_position:
		_search_remaining = maxf(_search_remaining - elapsed_seconds, 0.0)
		if _search_remaining <= 0.0:
			_has_last_known_position = false
			current_state = State.IDLE
		else:
			current_state = State.INVESTIGATE
	else:
		current_state = State.IDLE
	return true


func get_simplified_simulation_tick_count() -> int:
	return simplified_simulation_tick_count


func get_state_name() -> String:
	return ["IDLE", "CHASE", "ATTACK", "WANDER", "INVESTIGATE", "SEARCH"][current_state]


func get_target_distance() -> float:
	if not is_instance_valid(target):
		return INF
	return global_position.distance_to(target.global_position)


func get_last_known_position() -> Vector2:
	return last_known_position


func set_facing_direction(direction: Vector2) -> bool:
	if not _is_finite_position(direction) or direction.is_zero_approx():
		return false
	_facing_direction = direction.normalized()
	return true


func get_facing_direction() -> Vector2:
	return _facing_direction


func apply_stagger(impulse: Vector2, duration: float) -> bool:
	if not initialized or not _is_finite_position(impulse) or not is_finite(duration) or duration < 0.0:
		return false
	_stagger_remaining = maxf(_stagger_remaining, duration)
	velocity = impulse
	return true


func has_last_known_position() -> bool:
	return _has_last_known_position


func can_see_target(target_position: Vector2) -> bool:
	if creature_definition == null or not _is_finite_position(target_position):
		return false
	var offset := target_position - global_position
	var distance := offset.length()
	if not is_finite(distance) or distance > creature_definition.vision_range:
		return false
	if distance > creature_definition.attack_range:
		var direction := offset.normalized()
		var facing := _facing_direction.normalized()
		if facing.is_zero_approx():
			facing = Vector2.RIGHT
		if facing.dot(direction) < cos(deg_to_rad(clampf(vision_cone_degrees, 15.0, 180.0) * 0.5)):
			return false
	return _has_line_of_sight(target_position)


func get_damage_receiver() -> DamageReceiver:
	return get_node_or_null("CreatureHealthComponent") as DamageReceiver


func get_melee_damage() -> float:
	return creature_definition.melee_damage if creature_definition != null else 0.0


func _physics_process(delta: float) -> void:
	physics_step(delta)


func physics_step(delta: float) -> void:
	var receiver := get_damage_receiver()
	if receiver != null and receiver.is_depleted():
		_on_health_depleted()
		return
	if not initialized or creature_definition == null:
		velocity = Vector2.ZERO
		return
	var step := maxf(delta, 0.0) if is_finite(delta) else 0.0
	if _stagger_remaining > 0.0:
		_stagger_remaining = maxf(_stagger_remaining - step, 0.0)
		velocity = velocity.move_toward(Vector2.ZERO, creature_definition.move_speed * step * 4.0)
		move_and_slide()
		if _stagger_remaining > 0.0:
			return
	attack_cooldown_remaining = maxf(attack_cooldown_remaining - step, 0.0)
	if not is_instance_valid(target):
		target = null
	if is_instance_valid(target) and can_see_target(target.global_position):
		last_known_position = target.global_position
		_has_last_known_position = true
		_search_remaining = maxf(search_duration, 0.0)
		_wander_target = Vector2.ZERO
		var toward_target := global_position.direction_to(target.global_position)
		if not toward_target.is_zero_approx():
			_facing_direction = toward_target
		var distance := global_position.distance_to(target.global_position)
		current_state = State.ATTACK if distance <= creature_definition.attack_range else State.CHASE
	elif _has_last_known_position:
		current_state = _memory_state()
	elif wandering_enabled:
		current_state = State.WANDER
	else:
		current_state = State.IDLE

	match current_state:
		State.IDLE:
			_stop_and_slide()
		State.CHASE:
			_navigate_to(target.global_position if is_instance_valid(target) else last_known_position)
		State.ATTACK:
			_stop_and_slide()
			if attack_cooldown_remaining <= 0.0 and is_instance_valid(target) \
				and can_see_target(target.global_position) \
				and global_position.distance_to(target.global_position) <= creature_definition.attack_range:
				attack_requested.emit(self, target)
				attack_cooldown_remaining = creature_definition.attack_interval
		State.INVESTIGATE:
			if global_position.distance_to(last_known_position) <= 18.0:
				current_state = State.SEARCH
				_search_remaining = maxf(_search_remaining, search_duration)
				_search_step = 0
				_stop_and_slide()
			else:
				_navigate_to(last_known_position)
		State.SEARCH:
			_advance_search(step)
		State.WANDER:
			_advance_wander(step)


func _memory_state() -> State:
	if not _has_last_known_position:
		return State.IDLE
	if global_position.distance_to(last_known_position) > 18.0:
		return State.INVESTIGATE
	return State.SEARCH


func _has_line_of_sight(target_position: Vector2) -> bool:
	if not is_inside_tree():
		return true
	var query := PhysicsRayQueryParameters2D.create(global_position, target_position, WORLD_COLLISION_MASK, [get_rid()])
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _navigate_to(destination: Vector2) -> void:
	if not is_instance_valid(navigation_agent) or not _is_finite_position(destination):
		_stop_and_slide()
		return
	navigation_agent.target_position = destination
	var navigation_map := navigation_agent.get_navigation_map()
	if not navigation_map.is_valid() or NavigationServer2D.map_get_iteration_id(navigation_map) == 0:
		_stop_and_slide()
		return
	var next_path_position := navigation_agent.get_next_path_position()
	var path := navigation_agent.get_current_navigation_path()
	if path.size() < 2:
		_stop_and_slide()
		return
	var direction := global_position.direction_to(next_path_position)
	velocity = direction * creature_definition.move_speed if not direction.is_zero_approx() else Vector2.ZERO
	if not direction.is_zero_approx():
		_facing_direction = direction
	move_and_slide()


func _advance_search(delta: float) -> void:
	_search_remaining = maxf(_search_remaining - delta, 0.0)
	if _search_remaining <= 0.0:
		_has_last_known_position = false
		if not is_instance_valid(target):
			target = null
		current_state = State.WANDER if wandering_enabled else State.IDLE
		_stop_and_slide()
		return
	if global_position.distance_to(_wander_target) <= 12.0 or _wander_target == Vector2.ZERO:
		var angle := float(_search_step % 4) * PI * 0.5
		_wander_target = last_known_position + Vector2.RIGHT.rotated(angle) * 24.0
		_search_step += 1
	_navigate_to(_wander_target)


func _advance_wander(delta: float) -> void:
	if not wandering_enabled or wander_radius <= 0.0:
		current_state = State.IDLE
		_stop_and_slide()
		return
	_wander_remaining = maxf(_wander_remaining - delta, 0.0)
	if _wander_remaining <= 0.0 or global_position.distance_to(_wander_target) <= 12.0:
		var offset := Vector2.RIGHT.rotated(float(get_instance_id() % 8) * PI / 4.0) * wander_radius * 0.5
		_wander_target = _wander_origin + offset
		_wander_remaining = 3.0
	_navigate_to(_wander_target)


func _on_noise_emitted(event: NoiseEvent) -> void:
	if not initialized or event == null or not event.is_valid():
		return
	if event.get_emitter() == self:
		return
	if event.get_strength_at(global_position) < hearing_threshold:
		return
	if is_instance_valid(target) and can_see_target(target.global_position):
		return
	last_known_position = event.origin
	_has_last_known_position = true
	_search_remaining = maxf(search_duration, 0.0)
	_wander_target = Vector2.ZERO
	current_state = State.INVESTIGATE


func _stop_and_slide() -> void:
	velocity = Vector2.ZERO
	move_and_slide()


func _is_finite_position(position: Vector2) -> bool:
	return is_finite(position.x) and is_finite(position.y)


func _fail_initialization(reason: String) -> bool:
	initialized = false
	creature_definition = null
	current_state = State.IDLE
	velocity = Vector2.ZERO
	set_physics_process(false)
	push_error("[ZombieController] %s: %s" % [get_path() if is_inside_tree() else name, reason])
	return false


func _on_health_depleted() -> void:
	set_ai_enabled(false)
