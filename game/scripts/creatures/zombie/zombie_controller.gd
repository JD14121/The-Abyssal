class_name ZombieController
extends CharacterBody2D
## Zombie-specific perception, state transitions, navigation movement and attack requests.

signal attack_requested(attacker: Node2D, target: Node2D)

enum State { IDLE, CHASE, ATTACK }

const CREATURE_LAYER := 4
const CREATURE_COLLISION_MASK := 3 # World + Player

@export var definition_id: StringName = &"zombie_basic"

var current_state: State = State.IDLE
var creature_definition: CreatureDefinition
var target: Node2D
var initialized := false
var attack_cooldown_remaining := 0.0

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D


func _ready() -> void:
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


func get_state_name() -> String:
	return ["IDLE", "CHASE", "ATTACK"][current_state]


func get_target_distance() -> float:
	if not is_instance_valid(target):
		return INF
	return global_position.distance_to(target.global_position)


func get_damage_receiver() -> DamageReceiver:
	return get_node_or_null("CreatureHealthComponent") as DamageReceiver


func get_melee_damage() -> float:
	return creature_definition.melee_damage if creature_definition != null else 0.0


func _physics_process(delta: float) -> void:
	physics_step(delta)


func physics_step(delta: float) -> void:
	if get_damage_receiver() != null and get_damage_receiver().is_depleted():
		_on_health_depleted()
		return
	if not initialized or creature_definition == null:
		velocity = Vector2.ZERO
		return
	attack_cooldown_remaining = maxf(attack_cooldown_remaining - delta, 0.0)
	if not is_instance_valid(target):
		target = null
		current_state = State.IDLE
	_update_state()
	match current_state:
		State.IDLE:
			velocity = Vector2.ZERO
			move_and_slide()
		State.CHASE:
			_chase_target()
		State.ATTACK:
			velocity = Vector2.ZERO
			move_and_slide()
			if attack_cooldown_remaining <= 0.0 and is_instance_valid(target):
				attack_requested.emit(self, target)
				attack_cooldown_remaining = creature_definition.attack_interval


func _update_state() -> void:
	if not is_instance_valid(target):
		current_state = State.IDLE
		return
	var distance := global_position.distance_to(target.global_position)
	if distance <= creature_definition.attack_range:
		current_state = State.ATTACK
	elif distance <= creature_definition.vision_range:
		current_state = State.CHASE
	else:
		current_state = State.IDLE


func _chase_target() -> void:
	if not is_instance_valid(navigation_agent) or not is_instance_valid(target):
		velocity = Vector2.ZERO
		move_and_slide()
		return
	navigation_agent.target_position = target.global_position
	var navigation_map := navigation_agent.get_navigation_map()
	if not navigation_map.is_valid() or NavigationServer2D.map_get_iteration_id(navigation_map) == 0:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var next_path_position := navigation_agent.get_next_path_position()
	if navigation_agent.get_current_navigation_path().size() < 2:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var direction := global_position.direction_to(next_path_position)
	if direction.is_zero_approx():
		velocity = Vector2.ZERO
	else:
		velocity = direction * creature_definition.move_speed
	move_and_slide()


func _fail_initialization(reason: String) -> bool:
	initialized = false
	creature_definition = null
	current_state = State.IDLE
	velocity = Vector2.ZERO
	set_physics_process(false)
	push_error("[ZombieController] %s: %s" % [get_path() if is_inside_tree() else name, reason])
	return false


func _on_health_depleted() -> void:
	initialized = false
	target = null
	current_state = State.IDLE
	velocity = Vector2.ZERO
	set_physics_process(false)
