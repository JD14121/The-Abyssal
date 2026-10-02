class_name NoiseEvent
extends RefCounted
## Short-lived world signal carrying a source location and audible radius.

var origin: Vector2
var radius: float
var source_id: StringName
var emitter: WeakRef
var sequence_id: int


func _init(noise_origin: Vector2, noise_radius: float, noise_source_id: StringName,
		noise_emitter: Node2D = null, noise_sequence_id: int = 0) -> void:
	origin = noise_origin
	radius = noise_radius
	source_id = noise_source_id
	if is_instance_valid(noise_emitter):
		emitter = weakref(noise_emitter)
	sequence_id = noise_sequence_id


func is_valid() -> bool:
	return is_finite(origin.x) and is_finite(origin.y) and is_finite(radius) \
		and radius > 0.0 and not source_id.is_empty() and sequence_id >= 0


func get_strength_at(position: Vector2) -> float:
	if not is_valid() or not is_finite(position.x) or not is_finite(position.y):
		return 0.0
	var distance := origin.distance_to(position)
	if not is_finite(distance) or distance >= radius:
		return 0.0
	return clampf(1.0 - distance / radius, 0.0, 1.0)


func get_emitter() -> Node2D:
	if emitter == null:
		return null
	return emitter.get_ref() as Node2D
