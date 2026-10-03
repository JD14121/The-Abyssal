extends RefCounted
## Explicit, batched logical-time operations; never owns a timer or scene node.
const V = preload("res://scripts/history/record_validation.gd")
var _config: RefCounted
func _init(config: RefCounted) -> void: _config = config

func advance(graph: RefCounted, now: float) -> bool:
	if not V.number(now): return false
	var snapshot: Dictionary = graph.serialize()
	var changed_claims: Array = []
	var changed_nodes: Array = []
	for memory in snapshot.nodes:
		if now < memory.last_updated_world_time: return false
		var elapsed: float = now-memory.last_updated_world_time
		if elapsed == 0: continue
		var profile: Dictionary = _config.get_profile(memory.profile_id)
		# Best surviving medium protects shared claims; inaccessible media still preserve them.
		var rate: float = INF
		for anchor_id in memory.anchor_ids:
			var anchor: Dictionary = graph.get_anchor(anchor_id)
			if not anchor.available or anchor.durability <= 0: continue
			var medium: Dictionary = _config.get_profile(anchor.profile_id)
			rate = minf(rate,medium.base_decay_rate*(1.0+anchor.environmental_exposure*medium.environment_sensitivity))
		if rate == INF: rate = profile.base_decay_rate
		var factor := exp(-rate*elapsed/(1.0+memory.reinforcement_score))
		for claim in graph.get_claims(memory.memory_id):
			claim.retention *= factor
			claim.clarity *= factor
			if claim.retention < 0.05 and not claim.semantic_residue: claim.fragment_state = "missing"
			elif claim.retention < 0.8 and not claim.semantic_residue: claim.fragment_state = "weakened"
			changed_claims.append(claim)
		memory.last_updated_world_time = now
		changed_nodes.append(memory)
	return graph.update_records({"claims":changed_claims,"nodes":changed_nodes})

func reinforce(graph: RefCounted, memory_id: String, anchor_id: String, observer_id: String, kind: String, now: float) -> bool:
	var memory: Dictionary = graph.get_memory(memory_id)
	var anchor: Dictionary = graph.get_anchor(anchor_id)
	var weights: Dictionary = _config.serialize().reinforcement_weights
	if memory.is_empty() or anchor.is_empty() or not V.identity(observer_id) or not weights.has(kind) or not V.number(now) or now < memory.last_updated_world_time: return false
	if anchor_id not in memory.anchor_ids or not anchor.available or anchor.accessibility <= 0 or anchor.readability <= 0 or anchor.durability <= 0: return false
	if not advance(graph,now): return false
	memory = graph.get_memory(memory_id)
	# Physical source + observer deduplicates cross-kind repetitions too.
	var source := JSON.stringify([observer_id,anchor.target_ref])
	if memory.reinforcement_sources.has(source) or weights[kind] == 0: return true
	memory.reinforcement_sources[source] = 1
	memory.reinforcement_score += weights[kind]
	memory.last_reinforced_world_time = now
	var claims: Array = graph.get_claims(memory_id)
	for claim in claims:
		if claim.fragment_state == "missing": continue
		claim.retention = minf(1.0,claim.retention+weights[kind])
		claim.confidence = minf(1.0,claim.confidence+weights[kind])
	return graph.update_records({"nodes":[memory],"claims":claims})

func fragment(graph: RefCounted, memory_id: String, severity: float, now: float, seed_value: int) -> bool:
	var memory: Dictionary = graph.get_memory(memory_id)
	if memory.is_empty() or not V.number(severity,0,1) or not V.number(now) or now < memory.last_updated_world_time: return false
	if not advance(graph,now): return false
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var claims: Array = graph.get_claims(memory_id)
	for claim in claims:
		if claim.semantic_residue: continue
		if rng.randf() < severity:
			claim.fragment_state = "missing"
			claim.accessibility = 0.0
	return graph.update_records({"claims":claims})

func derive(graph: RefCounted, source_id: String, new_id: String, new_anchor: Dictionary, now: float, alternatives: Dictionary = {}, seed_value: int = 0) -> bool:
	var memory: Dictionary = graph.get_memory(source_id)
	if memory.is_empty() or not V.identity(new_id) or not graph.get_memory(new_id).is_empty() or not V.number(now) or now < memory.last_updated_world_time or not V.json_value(alternatives): return false
	for values in alternatives.values():
		if not values is Array or values.is_empty(): return false
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var claims: Array = graph.get_claims(source_id,true)
	if claims.is_empty(): return false
	var claim_ids: Array = []
	for index in range(claims.size()):
		var claim: Dictionary = claims[index]
		claim.claim_id = new_id+"_claim_%d" % index
		claim_ids.append(claim.claim_id)
		if alternatives.has(claim.predicate):
			var values: Array = alternatives[claim.predicate]
			claim.object_ref_or_value = values[rng.randi_range(0,values.size()-1)]
	memory.memory_id = new_id
	memory.claim_ids = claim_ids
	memory.anchor_ids = [new_anchor.get("anchor_id","")]
	memory.created_world_time = now
	memory.last_updated_world_time = now
	memory.last_reinforced_world_time = now
	memory.reinforcement_score = 0.0
	memory.reinforcement_sources = {}
	memory.profile_id = new_anchor.get("profile_id","")
	memory.provenance = {"operation":"reconsolidation" if alternatives.is_empty() else "distortion","source_memory_ids":[source_id],"seed":seed_value,"changed_predicates":alternatives.keys()}
	var anchor := new_anchor.duplicate(true)
	anchor.memory_ids = [new_id]
	var edge := {"edge_id":new_id+"_source","from_memory_id":new_id,"to_memory_id":source_id,"relation_type":"derived_from","strength":1.0,"provenance":memory.provenance.duplicate(true)}
	return graph.apply_bundle({"nodes":[memory],"claims":claims,"anchors":[anchor],"edges":[edge]})
