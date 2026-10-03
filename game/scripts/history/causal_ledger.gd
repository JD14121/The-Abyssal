extends RefCounted
## Append-only canonical truth and stable-ID indexes. No memory-decay rules.

const Event = preload("res://scripts/history/historical_event.gd")
const V = preload("res://scripts/history/record_validation.gd")
var _events: Dictionary = {}
var _order: Array = []
var _actors: Dictionary = {}
var _objects: Dictionary = {}
var _locations: Dictionary = {}
var _effects: Dictionary = {}
var _errors: Array[String] = []

func append_event(record: Variant) -> bool:
	_errors = Event.validate(record)
	if not _errors.is_empty(): return false
	if _events.has(record.event_id):
		_errors.append("event_id %s: duplicate" % record.event_id)
	for cause in record.cause_event_ids:
		if not _events.has(cause): _errors.append("cause_event_ids: unresolved prior event %s" % cause)
		elif get_event(cause).world_time_seconds > record.world_time_seconds: _errors.append("cause %s: occurs after effect" % cause)
	if not _errors.is_empty(): return false
	var accepted = Event.new(record)
	_events[record.event_id] = accepted
	_order.append(record.event_id)
	for reference in record.actor_refs: _index(_actors,reference.entity_id,record.event_id)
	for reference in record.object_refs: _index(_objects,reference.instance_id,record.event_id)
	_index(_locations,_location_key(record.location_ref.region_id,record.location_ref.area_id),record.event_id)
	for cause in record.cause_event_ids: _index(_effects,cause,record.event_id)
	return true

func has_event(event_id: String) -> bool:
	return _events.has(event_id)

func get_event(event_id: String) -> Dictionary:
	return _events[event_id].to_data() if _events.has(event_id) else {}

func get_causes(event_id: String) -> Array:
	return get_event(event_id).get("cause_event_ids",[]).duplicate()

func get_effects(event_id: String) -> Array:
	return _effects.get(event_id,[]).duplicate()

func query_by_actor(entity_id: String) -> Array:
	return _actors.get(entity_id,[]).duplicate()

func query_by_object(instance_id: String) -> Array:
	return _objects.get(instance_id,[]).duplicate()

func query_by_location(region_id: String, area_id: String) -> Array:
	return _locations.get(_location_key(region_id,area_id),[]).duplicate()

func serialize() -> Dictionary:
	var events: Array = []
	for event_id in _order: events.append(get_event(event_id))
	return {"schema_version":1,"events":events}

func deserialize(data: Variant) -> bool:
	_errors = V.fields(data,["schema_version","events"])
	if not _errors.is_empty(): return false
	if data.schema_version != 1 or not V.integer(data.schema_version) or not data.events is Array:
		_errors.append("ledger: invalid version or event array")
		return false
	var pending = get_script().new()
	for event in data.events:
		if not pending.append_event(event):
			_errors = pending.get_errors()
			return false
	_events = pending._events
	_order = pending._order
	_actors = pending._actors
	_objects = pending._objects
	_locations = pending._locations
	_effects = pending._effects
	return true

func get_errors() -> Array[String]:
	return _errors.duplicate()

func _index(index: Dictionary, key: String, identity: String) -> void:
	if not index.has(key): index[key] = []
	if identity not in index[key]: index[key].append(identity)

func _location_key(region_id: String, area_id: String) -> String:
	return JSON.stringify([region_id,area_id])
