extends RefCounted
## Canonical structured facts. Ledger owns a frozen detached copy.

const V = preload("res://scripts/history/record_validation.gd")
const FIELDS := ["schema_version","event_id","event_type","world_time_seconds","location_ref","absolute_depth_m","actor_refs","object_refs","cause_event_ids","effect_tags","facts","significance_tags","source_system"]
var _data: Dictionary

func _init(record: Dictionary) -> void:
	_data = V.normalize(record)
	V.freeze(_data)

func to_data() -> Dictionary:
	return _data.duplicate(true)

static func validate(record: Variant) -> Array[String]:
	var errors := V.fields(record,FIELDS)
	if not errors.is_empty(): return errors
	if record.schema_version != 1 or not V.integer(record.schema_version): errors.append("schema_version: unsupported")
	for field in ["event_id","event_type","source_system"]:
		if not V.tag(record[field]): errors.append("field %s: expected stable lowercase identifier" % field)
	if not V.number(record.world_time_seconds): errors.append("world_time_seconds: expected finite nonnegative time")
	if not V.number(record.absolute_depth_m): errors.append("absolute_depth_m: expected finite nonnegative physical depth")
	if not V.location(record.location_ref): errors.append("location_ref: invalid stable location")
	for field in ["cause_event_ids","effect_tags","significance_tags"]:
		if not V.ids(record[field]): errors.append("field %s: expected unique stable IDs" % field)
	for field in ["actor_refs","object_refs"]:
		if not record[field] is Array:
			errors.append("field %s: expected Array" % field)
			continue
		var identity_key := "entity_id" if field == "actor_refs" else "instance_id"
		for reference in record[field]:
			if not V.fields(reference,[identity_key,"role"]).is_empty() or not V.identity(reference.get(identity_key)) or not V.tag(reference.get("role")):
				errors.append("field %s: invalid reference or role" % field)
	if not record.facts is Array:
		errors.append("facts: expected semantic fragments")
	else:
		var keys := {}
		for fact in record.facts:
			if not V.fields(fact,["key","value"]).is_empty() or not V.tag(fact.get("key")):
				errors.append("facts: invalid semantic fragment")
			elif keys.has(fact.key):
				errors.append("facts: duplicate key %s" % fact.key)
			else: keys[fact.key] = true
	return errors
