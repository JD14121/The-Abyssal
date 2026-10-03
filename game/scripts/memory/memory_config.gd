extends RefCounted
## Domain configuration with strict validation, independent of static item APIs.
const V = preload("res://scripts/history/record_validation.gd")
const Loader = preload("res://scripts/data/data_loader.gd")
const KINDS := ["exposure","inspection","recording","corroboration","archival","institutionalization"]
var _data: Dictionary = {}
var _profiles: Dictionary = {}
var _policies: Dictionary = {}
var _errors: Array[String] = []

func load_files(directory: String = "res://data/world_memory") -> bool:
	var loader = Loader.new()
	var profiles: Dictionary = loader.read_json(directory.path_join("memory_retention_profiles.json"))
	var policies: Dictionary = loader.read_json(directory.path_join("memory_event_policies.json"))
	_errors = loader.errors.duplicate()
	if not profiles.ok or not policies.ok: return false
	if not V.fields(policies.value,["schema_version","policies","reinforcement_weights","significant_item_ids","severe_bleeding_rate_per_game_hour"]).is_empty():
		_errors.append(directory+"/memory_event_policies.json: invalid policy root")
		return false
	var data: Dictionary = policies.value.duplicate(true)
	if not V.fields(profiles.value,["schema_version","profiles"]).is_empty() or profiles.value.schema_version != 1:
		_errors.append(directory+": invalid retention profile root")
		return false
	data["profiles"] = profiles.value.profiles
	var accepted := deserialize(data)
	if not accepted:
		for index in range(_errors.size()): _errors[index] = directory+": "+_errors[index]
	return accepted

func deserialize(data: Variant) -> bool:
	_errors = V.fields(data,["schema_version","profiles","policies","reinforcement_weights","significant_item_ids","severe_bleeding_rate_per_game_hour"])
	if not _errors.is_empty(): return false
	if data.schema_version != 1 or not V.integer(data.schema_version) or not data.profiles is Array or not data.policies is Array or not data.reinforcement_weights is Dictionary:
		_errors.append("world_memory: invalid version or configuration collections")
		return false
	var profiles := {}
	var policies := {}
	for entry in data.profiles:
		var errors := V.fields(entry,["id","base_stability","base_readability","base_decay_rate","fragmentation_bias","environment_sensitivity"])
		if not errors.is_empty(): _errors.append_array(errors); continue
		if not V.tag(entry.id) or profiles.has(entry.id): _errors.append("retention profile %s: invalid/duplicate ID" % str(entry.id)); continue
		for field in ["base_stability","base_readability","fragmentation_bias","environment_sensitivity"]:
			if not V.number(entry[field],0,1): _errors.append("retention profile %s.%s: expected [0,1]" % [entry.id,field])
		if not V.number(entry.base_decay_rate): _errors.append("retention profile %s: invalid decay rate" % entry.id)
		profiles[entry.id] = entry
	for entry in data.policies:
		if not V.fields(entry,["id","category","memory_class","profile_id"]).is_empty(): _errors.append("event policy: invalid fields"); continue
		if not V.tag(entry.id) or policies.has(entry.id): _errors.append("event policy %s: invalid/duplicate ID" % str(entry.id)); continue
		if not V.tag(entry.profile_id): _errors.append("event policy %s: invalid profile ID" % entry.id); continue
		if entry.category not in ["trivial","local_trace","historical","landmark"] or entry.memory_class not in ["trace","episodic","persistent"]: _errors.append("event policy %s: invalid category/class" % entry.id)
		if not profiles.has(entry.profile_id): _errors.append("event policy %s: unresolved profile %s" % [entry.id,entry.profile_id])
		policies[entry.id] = entry
	if not V.fields(data.reinforcement_weights,KINDS).is_empty(): _errors.append("reinforcement_weights: invalid kinds")
	else:
		for kind in KINDS:
			if not V.number(data.reinforcement_weights[kind],0,1): _errors.append("reinforcement weight %s: invalid" % kind)
	if not V.ids(data.significant_item_ids): _errors.append("significant_item_ids: invalid IDs")
	else:
		for item_id in data.significant_item_ids:
			if not V.tag(item_id): _errors.append("significant_item_ids: invalid static item ID "+item_id)
	if not V.number(data.severe_bleeding_rate_per_game_hour): _errors.append("severe bleeding threshold: invalid")
	if not _errors.is_empty(): return false
	_data = V.normalize(data)
	V.freeze(_data)
	_profiles = {}
	_policies = {}
	for entry in _data.profiles: _profiles[entry.id] = entry
	for entry in _data.policies: _policies[entry.id] = entry
	return true

func get_profile(profile_id: String) -> Dictionary:
	return _profiles.get(profile_id,{}).duplicate(true)
func get_policy(event_type: String) -> Dictionary:
	return _policies.get(event_type,{}).duplicate(true)
func serialize() -> Dictionary:
	return _data.duplicate(true)
func get_errors() -> Array[String]:
	return _errors.duplicate()
