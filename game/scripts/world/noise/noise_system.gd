class_name NoiseSystem
extends Node
## World-local synchronous noise propagation. Listeners decide how to react.

signal noise_emitted(event: NoiseEvent)

var _sequence_id := 0


func emit_noise(origin: Vector2, radius: float, source_id: StringName,
		emitter: Node2D = null) -> NoiseEvent:
	var event := NoiseEvent.new(origin, radius, source_id, emitter, _sequence_id + 1)
	if not event.is_valid():
		return null
	_sequence_id += 1
	noise_emitted.emit(event)
	return event
