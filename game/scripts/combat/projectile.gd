class_name CombatProjectile
extends Area2D
## Short-lived physical projectile that resolves through the shared CombatService.

const CombatServiceScript := preload("res://scripts/combat/combat_service.gd")
const DamageEventScript := preload("res://scripts/combat/damage_event.gd")

var _source: Node2D
var _direction := Vector2.RIGHT
var _damage := 0.0
var _speed := 0.0
var _max_distance := 0.0
var _travelled := 0.0


func configure(source: Node2D, direction: Vector2, damage: float, speed: float, max_distance: float) -> bool:
	if not is_instance_valid(source) or direction.is_zero_approx() or not is_finite(damage) or damage <= 0.0 \
		or not is_finite(speed) or speed <= 0.0 or not is_finite(max_distance) or max_distance <= 0.0:
		return false
	_source = source
	_direction = direction.normalized()
	_damage = damage
	_speed = speed
	_max_distance = max_distance
	return true


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	var step_distance := _speed * delta
	global_position += _direction * step_distance
	_travelled += step_distance
	if _travelled >= _max_distance:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body == _source:
		return
	if body.has_method("get_damage_receiver"):
		var event := DamageEventScript.new(_source, body, _damage)
		CombatServiceScript.new().apply_damage_event(event)
	queue_free()
