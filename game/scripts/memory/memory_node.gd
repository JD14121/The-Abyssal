extends RefCounted
const V = preload("res://scripts/history/record_validation.gd")
static func validate(data: Variant) -> Array[String]:
	var errors := V.fields(data,["memory_id","memory_class","memory_state","profile_id","claim_ids","anchor_ids","source_event_ids","created_world_time","last_updated_world_time","last_reinforced_world_time","reinforcement_score","redundancy_score","accessibility","stability","fragmentation","provenance","reinforcement_sources"])
	if not errors.is_empty(): return errors
	if not V.identity(data.memory_id) or not V.tag(data.profile_id): errors.append("memory: invalid identity/profile")
	for field in ["claim_ids","anchor_ids","source_event_ids"]:
		if not V.ids(data[field]) or data[field].is_empty(): errors.append("memory %s.%s: expected nonempty unique IDs" % [data.memory_id,field])
	if data.memory_class not in ["trace","episodic","persistent"] or data.memory_state not in ["active","fading","fragmented","dormant","lost"]: errors.append("memory: invalid class/state")
	for field in ["created_world_time","last_updated_world_time","last_reinforced_world_time","reinforcement_score","redundancy_score"]:
		if not V.number(data[field]): errors.append("memory %s.%s: invalid value" % [data.memory_id,field])
	for field in ["accessibility","stability","fragmentation"]:
		if not V.number(data[field],0,1): errors.append("memory %s.%s: invalid quality" % [data.memory_id,field])
	if not errors.is_empty(): return errors
	if data.last_updated_world_time < data.created_world_time or data.last_reinforced_world_time < data.created_world_time or data.last_reinforced_world_time > data.last_updated_world_time: errors.append("memory: nonmonotonic time")
	if not data.provenance is Dictionary or not data.reinforcement_sources is Dictionary: errors.append("memory: invalid provenance/sources")
	else:
		if not V.tag(data.provenance.get("operation")) or not V.ids(data.provenance.get("source_memory_ids")): errors.append("provenance: expected operation and source memory ID array")
		if data.provenance.has("source_event_ids") and not V.ids(data.provenance.source_event_ids): errors.append("provenance: invalid source event ID array")
		for key in data.reinforcement_sources:
			if not V.integer(data.reinforcement_sources[key]): errors.append("reinforcement_sources: invalid contribution count")
	return errors
