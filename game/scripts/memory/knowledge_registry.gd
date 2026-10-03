extends RefCounted
## Observer-local beliefs. No ledger reference and no privileged truth-accuracy field.
const V = preload("res://scripts/history/record_validation.gd")
const Claim = preload("res://scripts/memory/memory_claim.gd")
var _records: Dictionary = {}
func learn(observer_id: String, memory_id: String, claims: Array, now: float) -> bool:
	if not V.identity(observer_id) or not V.identity(memory_id) or not V.number(now): return false
	var pending := _records.duplicate(true)
	for claim in claims:
		if not Claim.validate(claim).is_empty(): return false
		var key := JSON.stringify([observer_id,memory_id,claim.claim_id])
		pending[key] = {"observer_id":observer_id,"source_memory_id":memory_id,"source_claim_id":claim.claim_id,"subject_ref":claim.subject_ref,"predicate":claim.predicate,"believed_value":claim.object_ref_or_value,"confidence":claim.confidence,"learned_world_time":now}
	_records = V.normalize(pending)
	V.freeze(_records)
	return true
func query(observer_id: String) -> Array:
	var result: Array = []
	var keys := _records.keys()
	keys.sort()
	for key in keys:
		if _records[key].observer_id == observer_id: result.append(_records[key].duplicate(true))
	return result
func serialize() -> Dictionary:
	var keys := _records.keys()
	keys.sort()
	var records: Array = []
	for key in keys: records.append(_records[key].duplicate(true))
	return {"schema_version":1,"records":records}
func deserialize(data: Variant, graph: RefCounted) -> bool:
	if not V.fields(data,["schema_version","records"]).is_empty() or data.schema_version != 1 or not V.integer(data.schema_version) or not data.records is Array: return false
	var pending := {}
	for record in data.records:
		if not V.fields(record,["observer_id","source_memory_id","source_claim_id","subject_ref","predicate","believed_value","confidence","learned_world_time"]).is_empty(): return false
		for field in ["observer_id","source_memory_id","source_claim_id","subject_ref"]:
			if not V.identity(record[field]): return false
		if not V.tag(record.predicate) or not V.number(record.confidence,0,1) or not V.number(record.learned_world_time): return false
		var memory: Dictionary = graph.get_memory(record.source_memory_id)
		if memory.is_empty() or record.source_claim_id not in memory.claim_ids or record.learned_world_time < memory.created_world_time: return false
		var key := JSON.stringify([record.observer_id,record.source_memory_id,record.source_claim_id])
		if pending.has(key): return false
		pending[key] = record.duplicate(true)
	_records = V.normalize(pending)
	V.freeze(_records)
	return true
