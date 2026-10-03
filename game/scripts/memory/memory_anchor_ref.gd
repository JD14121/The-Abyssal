extends RefCounted
const V = preload("res://scripts/history/record_validation.gd")
const TYPES := ["world_item","corpse","location","structure","npc","archive","ecological_state","geological_state","spiritual_residue"]
static func validate(data: Variant) -> Array[String]:
	var errors := V.fields(data,["anchor_id","anchor_type","target_ref","profile_id","memory_ids","durability","readability","accessibility","environmental_exposure","available","last_known_location"])
	if not errors.is_empty(): return errors
	if not V.identity(data.anchor_id) or data.anchor_type not in TYPES or not V.tag(data.profile_id) or not V.ids(data.memory_ids): errors.append("anchor: invalid ID/type/profile/links")
	if not V.fields(data.target_ref,["kind","id"]).is_empty() or data.target_ref.get("kind") != data.anchor_type or not V.identity(data.target_ref.get("id")): errors.append("anchor: unresolved target identity")
	for field in ["durability","readability","accessibility","environmental_exposure"]:
		if not V.number(data[field],0,1): errors.append("anchor %s.%s: invalid quality" % [data.anchor_id,field])
	if not data.available is bool or not V.location(data.last_known_location): errors.append("anchor: invalid availability/location")
	return errors
