extends RefCounted
const V = preload("res://scripts/history/record_validation.gd")
const RELATIONS := ["derived_from","associated_with","contradicts","supports","same_subject","same_location","caused_by","interpreted_as","copied_from"]
static func validate(data: Variant) -> Array[String]:
	var errors := V.fields(data,["edge_id","from_memory_id","to_memory_id","relation_type","strength","provenance"])
	if not errors.is_empty(): return errors
	for field in ["edge_id","from_memory_id","to_memory_id"]:
		if not V.identity(data[field]): errors.append("edge: invalid identity")
	if data.from_memory_id == data.to_memory_id or data.relation_type not in RELATIONS or not V.number(data.strength,0,1) or not data.provenance is Dictionary: errors.append("edge: invalid relationship")
	if data.provenance is Dictionary:
		for field in ["source_memory_ids","source_event_ids"]:
			if data.provenance.has(field) and not V.ids(data.provenance[field]): errors.append("edge provenance: invalid "+field)
	return errors
