extends RefCounted
## Canonical event -> semantic claims. Encoding is one graph transaction.
var _config: RefCounted
var _errors: Array[String] = []
func _init(config: RefCounted) -> void: _config = config

func encode(ledger: RefCounted, graph: RefCounted, event_id: String, memory_id: String, anchors: Array) -> bool:
	_errors.clear()
	var event: Dictionary = ledger.get_event(event_id)
	if event.is_empty(): _errors.append("encoder: unresolved canonical event "+event_id); return false
	var policy: Dictionary = _config.get_policy(event.event_type)
	if policy.is_empty() or policy.category not in ["historical","landmark"]: _errors.append("encoder: event is not historically significant"); return false
	var profile: Dictionary = _config.get_profile(policy.profile_id)
	var claims: Array = []
	var subject: String = event.actor_refs[0].entity_id if not event.actor_refs.is_empty() else event.location_ref.area_id
	for fact in event.facts: claims.append(_claim(memory_id,subject,fact.key,fact.value,event_id,profile,claims.size()))
	for actor in event.actor_refs: claims.append(_claim(memory_id,actor.entity_id,"participated_as",actor.role,event_id,profile,claims.size()))
	claims.append(_claim(memory_id,subject,"located_at",event.location_ref,event_id,profile,claims.size()))
	var residue := _claim(memory_id,event.location_ref.area_id,"occurred",event.event_type,event_id,profile,claims.size())
	residue.semantic_residue = true
	residue.fragment_state = "residue"
	claims.append(residue)
	var anchor_records: Array = []
	var anchor_ids: Array = []
	for anchor in anchors:
		if not anchor is Dictionary: _errors.append("encoder: invalid anchor"); return false
		var record: Dictionary = anchor.duplicate(true)
		record["memory_ids"] = [memory_id]
		anchor_records.append(record)
		anchor_ids.append(record.get("anchor_id",""))
	var claim_ids: Array = []
	for claim in claims: claim_ids.append(claim.claim_id)
	var memory := {
		"memory_id":memory_id,"memory_class":policy.memory_class,"memory_state":"active","profile_id":policy.profile_id,
		"claim_ids":claim_ids,"anchor_ids":anchor_ids,"source_event_ids":[event_id],
		"created_world_time":event.world_time_seconds,"last_updated_world_time":event.world_time_seconds,"last_reinforced_world_time":event.world_time_seconds,
		"reinforcement_score":0.0,"redundancy_score":0.0,"accessibility":1.0,"stability":profile.base_stability,"fragmentation":0.0,
		"provenance":{"operation":"encoding","source_event_ids":[event_id],"source_memory_ids":[]},"reinforcement_sources":{},
	}
	if not graph.apply_bundle({"claims":claims,"nodes":[memory],"anchors":anchor_records}):
		_errors = graph.get_errors()
		return false
	return true
func get_errors() -> Array[String]: return _errors.duplicate()

func _claim(memory_id: String, subject: String, predicate: String, value: Variant, event_id: String, profile: Dictionary, index: int) -> Dictionary:
	return {"claim_id":memory_id+"_claim_%d" % index,"subject_ref":subject,"predicate":predicate,"object_ref_or_value":value,"source_event_ids":[event_id],"clarity":profile.base_readability,"retention":1.0,"confidence":profile.base_readability,"accessibility":1.0,"fragment_state":"intact","semantic_residue":false}
