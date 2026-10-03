extends RefCounted
## Transactional mutable evidence graph. No gameplay decisions or frame callbacks.
const V = preload("res://scripts/history/record_validation.gd")
const Claim = preload("res://scripts/memory/memory_claim.gd")
const Memory = preload("res://scripts/memory/memory_node.gd")
const Edge = preload("res://scripts/memory/memory_edge.gd")
const Anchor = preload("res://scripts/memory/memory_anchor_ref.gd")
const GROUPS := ["claims","nodes","edges","anchors"]
var _records := {"claims":{},"nodes":{},"edges":{},"anchors":{}}
var _ledger: RefCounted
var _config: RefCounted
var _events: Dictionary = {}
var _targets: Dictionary = {}
var _errors: Array[String] = []

func _init(ledger: RefCounted, config: RefCounted) -> void:
	_ledger = ledger
	_config = config

func apply_bundle(bundle: Dictionary) -> bool:
	_errors.clear()
	var pending: Dictionary = _records.duplicate(true)
	for group in bundle:
		if group not in GROUPS or not bundle[group] is Array:
			_errors.append("bundle: invalid collection %s" % group)
			return false
		for record in bundle[group]:
			var identity: Variant = record.get(_id_field(group)) if record is Dictionary else null
			if not V.identity(identity) or pending[group].has(identity):
				_errors.append("%s: missing or duplicate ID %s" % [group,str(identity)])
				return false
			pending[group][identity] = record.duplicate(true)
	return _commit(pending)

func update_records(patch: Dictionary) -> bool:
	_errors.clear()
	var pending: Dictionary = _records.duplicate(true)
	for group in patch:
		if group not in GROUPS or not patch[group] is Array: return _fail("update: invalid collection "+str(group))
		for record in patch[group]:
			var identity: Variant = record.get(_id_field(group)) if record is Dictionary else null
			if not V.identity(identity) or not pending[group].has(identity): return _fail("update %s: unresolved ID %s" % [group,str(identity)])
			pending[group][identity] = record.duplicate(true)
	return _commit(pending)

func serialize() -> Dictionary:
	var data := {"schema_version":1}
	for group in GROUPS:
		data[group] = []
		var identities: Array = _records[group].keys()
		identities.sort()
		for identity in identities: data[group].append(_records[group][identity].duplicate(true))
	return data

func deserialize(data: Variant) -> bool:
	_errors = V.fields(data,["schema_version","claims","nodes","edges","anchors"])
	if not _errors.is_empty(): return false
	if data.schema_version != 1 or not V.integer(data.schema_version): return _fail("graph: unsupported schema version")
	var pending := {"claims":{},"nodes":{},"edges":{},"anchors":{}}
	for group in GROUPS:
		if not data[group] is Array: return _fail("graph %s: expected array" % group)
		for record in data[group]:
			var identity: Variant = record.get(_id_field(group)) if record is Dictionary else null
			if not V.identity(identity) or pending[group].has(identity): return _fail("graph %s: invalid/duplicate ID %s" % [group,str(identity)])
			pending[group][identity] = record.duplicate(true)
	return _commit(pending)

func get_memory(memory_id: String) -> Dictionary:
	return _records.nodes.get(memory_id,{}).duplicate(true)
func get_anchor(anchor_id: String) -> Dictionary:
	return _records.anchors.get(anchor_id,{}).duplicate(true)
func get_claims(memory_id: String, accessible_only: bool = false) -> Array:
	var result: Array = []
	var memory := get_memory(memory_id)
	for identity in memory.get("claim_ids",[]):
		var claim: Dictionary = _records.claims[identity]
		if not accessible_only or (memory.accessibility > 0 and claim.accessibility > 0 and claim.fragment_state != "missing" and claim.retention > 0): result.append(claim.duplicate(true))
	return result
func query_by_event(event_id: String) -> Array:
	return _events.get(event_id,[]).duplicate()
func query_by_target(kind: String, target_id: String) -> Array:
	return _targets.get(JSON.stringify([kind,target_id]),[]).duplicate()
func get_errors() -> Array[String]: return _errors.duplicate()
func _fail(message: String) -> bool:
	_errors.append(message)
	return false

func bind_anchor(memory_id: String, anchor_id: String) -> bool:
	var memory := get_memory(memory_id)
	var anchor := get_anchor(anchor_id)
	if memory.is_empty() or anchor.is_empty() or anchor_id in memory.anchor_ids: return false
	memory.anchor_ids.append(anchor_id)
	anchor.memory_ids.append(memory_id)
	return update_records({"nodes":[memory],"anchors":[anchor]})

func destroy_anchor(anchor_id: String) -> bool:
	var anchor := get_anchor(anchor_id)
	if anchor.is_empty() or not anchor.available: return false
	anchor.available = false
	anchor.durability = 0.0
	anchor.accessibility = 0.0
	return update_records({"anchors":[anchor]})

func set_anchor_accessibility(anchor_id: String, accessibility: float) -> bool:
	var anchor := get_anchor(anchor_id)
	if anchor.is_empty() or not anchor.available or not V.number(accessibility,0,1): return false
	anchor.accessibility = accessibility
	return update_records({"anchors":[anchor]})

func discover(memory_id: String, anchor_id: String, observer_id: String) -> Array:
	var memory := get_memory(memory_id)
	var anchor := get_anchor(anchor_id)
	if not V.identity(observer_id) or memory.is_empty() or anchor.is_empty() or anchor_id not in memory.anchor_ids or not anchor.available or anchor.durability <= 0 or anchor.readability <= 0: return []
	if not set_anchor_accessibility(anchor_id,1.0): return []
	return get_claims(memory_id,true)

func _commit(pending: Dictionary) -> bool:
	_errors.clear()
	var validators := {"claims":Claim,"nodes":Memory,"edges":Edge,"anchors":Anchor}
	for group in GROUPS:
		for identity in pending[group]:
			var errors: Array[String] = validators[group].validate(pending[group][identity])
			for error in errors: _errors.append("%s/%s: %s" % [group,identity,error])
	if not _errors.is_empty(): return false
	var owned_claims := {}
	for memory in pending.nodes.values():
		if _config.get_profile(memory.profile_id).is_empty(): _errors.append("memory %s: unresolved profile" % memory.memory_id)
		for event_id in memory.source_event_ids:
			if not _ledger.has_event(event_id): _errors.append("memory %s: unresolved source event" % memory.memory_id)
		for claim_id in memory.claim_ids:
			if not pending.claims.has(claim_id) or owned_claims.has(claim_id): _errors.append("memory %s: unresolved/shared claim %s" % [memory.memory_id,claim_id])
			owned_claims[claim_id] = true
		for anchor_id in memory.anchor_ids:
			if not pending.anchors.has(anchor_id) or memory.memory_id not in pending.anchors[anchor_id].memory_ids: _errors.append("memory %s: asymmetric/unresolved anchor %s" % [memory.memory_id,anchor_id])
		for source_id in memory.provenance.get("source_memory_ids",[]):
			if not pending.nodes.has(source_id) or source_id == memory.memory_id: _errors.append("memory %s: invalid provenance" % memory.memory_id)
			elif pending.nodes[source_id].created_world_time > memory.created_world_time: _errors.append("memory %s: source created after derived memory" % memory.memory_id)
		for source_event in memory.provenance.get("source_event_ids",[]):
			if not _ledger.has_event(source_event) or source_event not in memory.source_event_ids: _errors.append("memory %s: unresolved provenance event %s" % [memory.memory_id,source_event])
	for claim in pending.claims.values():
		if not owned_claims.has(claim.claim_id): _errors.append("claim %s: missing owner" % claim.claim_id)
		for event_id in claim.source_event_ids:
			if not _ledger.has_event(event_id): _errors.append("claim %s: unresolved source event" % claim.claim_id)
	for anchor in pending.anchors.values():
		if _config.get_profile(anchor.profile_id).is_empty(): _errors.append("anchor %s: unresolved profile" % anchor.anchor_id)
		for memory_id in anchor.memory_ids:
			if not pending.nodes.has(memory_id) or anchor.anchor_id not in pending.nodes[memory_id].anchor_ids: _errors.append("anchor %s: asymmetric memory link" % anchor.anchor_id)
	for edge in pending.edges.values():
		if not pending.nodes.has(edge.from_memory_id) or not pending.nodes.has(edge.to_memory_id): _errors.append("edge %s: unresolved endpoint" % edge.edge_id)
		for source_id in edge.provenance.get("source_memory_ids",[]):
			if not pending.nodes.has(source_id): _errors.append("edge %s: unresolved provenance memory" % edge.edge_id)
		for event_id in edge.provenance.get("source_event_ids",[]):
			if not _ledger.has_event(event_id): _errors.append("edge %s: unresolved provenance event" % edge.edge_id)
	if not _errors.is_empty(): return false
	if _has_provenance_cycle(pending.nodes): return _fail("provenance: cyclic source memory references")
	for memory in pending.nodes.values(): _refresh(memory,pending)
	_records = V.normalize(pending)
	V.freeze(_records)
	_reindex()
	return true

func _refresh(memory: Dictionary, pending: Dictionary) -> void:
	var accessible := 0.0
	var surviving := false
	var evidence := {}
	for anchor_id in memory.anchor_ids:
		var anchor: Dictionary = pending.anchors[anchor_id]
		if anchor.available and anchor.durability > 0:
			surviving = true
			accessible = maxf(accessible,anchor.accessibility*anchor.readability*anchor.durability)
			evidence[JSON.stringify(anchor.target_ref)] = true
	memory.redundancy_score = maxf(0,evidence.size()-1)
	memory.accessibility = accessible
	var missing := 0
	var retention := 0.0
	var recoverable := false
	for claim_id in memory.claim_ids:
		var claim: Dictionary = pending.claims[claim_id]
		if claim.fragment_state == "missing": missing += 1
		retention += claim.retention
		if claim.fragment_state != "missing" and claim.retention > 0: recoverable = true
	memory.fragmentation = float(missing)/memory.claim_ids.size()
	if not surviving or not recoverable:
		memory.memory_state = "lost"
		memory.accessibility = 0.0
	elif accessible == 0: memory.memory_state = "dormant"
	elif missing > 0: memory.memory_state = "fragmented"
	elif retention/memory.claim_ids.size() < 0.8: memory.memory_state = "fading"
	else: memory.memory_state = "active"

func _reindex() -> void:
	_events = {}
	_targets = {}
	var identities: Array = _records.nodes.keys()
	identities.sort()
	for identity in identities:
		var memory: Dictionary = _records.nodes[identity]
		for event_id in memory.source_event_ids: _index(_events,event_id,identity)
		for anchor_id in memory.anchor_ids:
			var target: Dictionary = _records.anchors[anchor_id].target_ref
			_index(_targets,JSON.stringify([target.kind,target.id]),identity)
func _index(index: Dictionary, key: String, identity: String) -> void:
	if not index.has(key): index[key] = []
	if identity not in index[key]: index[key].append(identity)
func _id_field(group: String) -> String:
	return {"claims":"claim_id","nodes":"memory_id","edges":"edge_id","anchors":"anchor_id"}[group]

func _has_provenance_cycle(nodes: Dictionary) -> bool:
	var counts := {}
	var dependents := {}
	var ready: Array = []
	for identity in nodes:
		var sources: Array = nodes[identity].provenance.source_memory_ids
		counts[identity] = sources.size()
		if sources.is_empty(): ready.append(identity)
		for source in sources:
			if not dependents.has(source): dependents[source] = []
			dependents[source].append(identity)
	var cursor := 0
	while cursor < ready.size():
		for dependent in dependents.get(ready[cursor],[]):
			counts[dependent] -= 1
			if counts[dependent] == 0: ready.append(dependent)
		cursor += 1
	return cursor != nodes.size()
