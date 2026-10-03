extends RefCounted
const V = preload("res://scripts/history/record_validation.gd")
static func validate(data: Variant) -> Array[String]:
	var errors := V.fields(data,["claim_id","subject_ref","predicate","object_ref_or_value","source_event_ids","clarity","retention","confidence","accessibility","fragment_state","semantic_residue"])
	if not errors.is_empty(): return errors
	if not V.identity(data.claim_id) or not V.identity(data.subject_ref) or not V.tag(data.predicate) or not V.ids(data.source_event_ids): errors.append("claim: invalid identity or source")
	for field in ["clarity","retention","confidence","accessibility"]:
		if not V.number(data[field],0,1): errors.append("claim %s.%s: invalid quality" % [data.claim_id,field])
	if data.fragment_state not in ["intact","weakened","missing","residue"] or not data.semantic_residue is bool: errors.append("claim: invalid fragment state")
	return errors
