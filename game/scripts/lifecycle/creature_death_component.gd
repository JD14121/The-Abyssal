extends Node
## Owns the Creature-to-Corpse lifecycle transition, not Health arithmetic.

signal death_transition_started
signal corpse_spawned(corpse: Node2D)

const CorpseScript = preload("res://scripts/lifecycle/corpse.gd")

@export var corpse_scene: PackedScene

var transition_started := false
var transition_completed := false
var transition_failed := false
var last_error := ""


func _ready() -> void:
	var creature := get_parent()
	if creature == null or not creature.has_method("get_damage_receiver"):
		push_error("[CreatureDeathComponent] Parent must expose get_damage_receiver()")
		return
	var receiver = creature.get_damage_receiver()
	if receiver == null or not receiver.has_signal("health_depleted"):
		push_error("[CreatureDeathComponent] Creature Health depletion signal is unavailable")
		return
	if not receiver.health_depleted.is_connected(handle_health_depleted):
		receiver.health_depleted.connect(handle_health_depleted)
	if receiver.is_depleted():
		handle_health_depleted()


func handle_health_depleted() -> bool:
	if transition_started:
		return transition_completed
	transition_started = true
	var creature := get_parent()
	death_transition_started.emit()
	if corpse_scene == null:
		return _fail("corpse_scene is not configured")
	if creature == null or not is_instance_valid(creature) or not creature is Node2D:
		return _fail("Creature parent is invalid")
	var world_parent := creature.get_parent()
	if world_parent == null or not is_instance_valid(world_parent) or not world_parent.is_inside_tree():
		return _fail("Creature parent must be inside the SceneTree")
	var source_id: Variant = creature.get("definition_id")
	if not source_id is StringName and not source_id is String:
		return _fail("Creature definition_id is unavailable")
	var death_position: Vector2 = creature.global_position
	_stop_creature(creature)
	var corpse_node: Node = corpse_scene.instantiate()
	if not corpse_node is Corpse:
		if is_instance_valid(corpse_node):
			corpse_node.free()
		return _fail("corpse_scene root must use Corpse")
	var corpse: Corpse = corpse_node
	if not corpse.initialize(source_id):
		corpse.free()
		return _fail("Corpse rejected source Creature definition ID '%s'" % String(source_id))
	world_parent.add_child(corpse)
	if not is_instance_valid(corpse) or corpse.get_parent() != world_parent or not corpse.is_inside_tree():
		if is_instance_valid(corpse):
			corpse.free()
		return _fail("Corpse could not be added to the Creature's world parent")
	corpse.global_position = death_position
	if not corpse.global_position.is_equal_approx(death_position):
		corpse.queue_free()
		return _fail("Corpse could not be placed at the Creature's death position")
	transition_completed = true
	corpse_spawned.emit(corpse)
	creature.queue_free()
	return true


func _stop_creature(creature: Node) -> void:
	if creature == null or not is_instance_valid(creature):
		return
	if creature.has_method("set_ai_enabled"):
		creature.set_ai_enabled(false)
	else:
		creature.set_physics_process(false)
	if creature is CharacterBody2D:
		creature.velocity = Vector2.ZERO
		creature.collision_layer = 0
		creature.collision_mask = 0
		var collision_shape := creature.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collision_shape != null:
			collision_shape.set_deferred("disabled", true)


func _fail(reason: String) -> bool:
	_stop_creature(get_parent())
	transition_failed = true
	last_error = reason
	push_error("[CreatureDeathComponent] %s: %s" % [get_parent().name if get_parent() != null else "<missing Creature>", reason])
	return false
