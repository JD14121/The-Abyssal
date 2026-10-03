extends RefCounted
## Composition root for one world's history. Persistence boundary only: no disk I/O.
const V = preload("res://scripts/history/record_validation.gd")
const Config = preload("res://scripts/memory/memory_config.gd")
const Ledger = preload("res://scripts/history/causal_ledger.gd")
const Graph = preload("res://scripts/memory/world_memory_graph.gd")
const Encoder = preload("res://scripts/memory/memory_encoder.gd")
const Lifecycle = preload("res://scripts/memory/memory_lifecycle.gd")
const Knowledge = preload("res://scripts/memory/knowledge_registry.gd")
var config: RefCounted
var ledger: RefCounted
var graph: RefCounted
var lifecycle: RefCounted
var knowledge: RefCounted
var world_id := ""
var _counter := 0
var _errors: Array[String] = []
func initialize(identity: String) -> bool:
	if not V.tag(identity): return false
	var definitions := Config.new()
	if not definitions.load_files(): _errors = definitions.get_errors(); return false
	_compose(identity,definitions,Ledger.new())
	return true
func _compose(identity: String, definitions: RefCounted, truth: RefCounted) -> void:
	world_id = identity
	config = definitions
	ledger = truth
	graph = Graph.new(ledger,config)
	lifecycle = Lifecycle.new(config)
	knowledge = Knowledge.new()
func next_id(kind: String) -> String:
	if not V.tag(kind) or world_id.is_empty(): return ""
	_counter += 1
	return "%s_%s_%d" % [world_id,kind,_counter]
func record(event: Dictionary, anchors: Array) -> bool:
	_errors.clear()
	var event_type: Variant = event.get("event_type")
	if not V.tag(event_type): _errors.append("outcome: invalid event_type"); return false
	var policy: Dictionary = config.get_policy(event_type)
	if policy.is_empty() or policy.category not in ["historical","landmark"]: return false
	if not ledger.append_event(event): _errors = ledger.get_errors(); return false
	var encoder := Encoder.new(config)
	if not encoder.encode(ledger,graph,event.event_id,event.event_id+"_memory",anchors):
		_errors = encoder.get_errors()
		return false
	return true
func observe(observer_id: String, memory_id: String, anchor_id: String, now: float) -> bool:
	if not V.identity(observer_id) or not V.number(now): return false
	if not lifecycle.advance(graph,now): return false
	var claims: Array = graph.discover(memory_id,anchor_id,observer_id)
	if claims.is_empty(): return false
	return knowledge.learn(observer_id,memory_id,claims,now)
func serialize() -> Dictionary:
	return {"schema_version":1,"world_id":world_id,"identity_counter":_counter,"config":config.serialize(),"ledger":ledger.serialize(),"graph":graph.serialize(),"knowledge":knowledge.serialize()}
func deserialize(data: Variant) -> bool:
	_errors = V.fields(data,["schema_version","world_id","identity_counter","config","ledger","graph","knowledge"])
	if not _errors.is_empty(): return false
	if data.schema_version != 1 or not V.integer(data.schema_version) or not V.tag(data.world_id) or not V.integer(data.identity_counter): _errors.append("history snapshot: invalid metadata"); return false
	var generated := RegEx.new()
	generated.compile("^"+data.world_id+"_[a-z_]+_([0-9]+)$")
	if data.identity_counter < _maximum_allocated_id(data,generated): _errors.append("identity_counter: precedes retained identities"); return false
	var definitions := Config.new()
	var truth := Ledger.new()
	if not definitions.deserialize(data.config): _errors = definitions.get_errors(); return false
	if not truth.deserialize(data.ledger): _errors = truth.get_errors(); return false
	var pending = get_script().new()
	pending._compose(data.world_id,definitions,truth)
	if not pending.graph.deserialize(data.graph): _errors = pending.graph.get_errors(); return false
	if not pending.knowledge.deserialize(data.knowledge,pending.graph): _errors.append("knowledge: invalid record/source"); return false
	world_id = pending.world_id
	config = pending.config
	ledger = pending.ledger
	graph = pending.graph
	lifecycle = pending.lifecycle
	knowledge = pending.knowledge
	_counter = int(data.identity_counter)
	return true
func get_errors() -> Array[String]: return _errors.duplicate()
func _maximum_allocated_id(value: Variant, pattern: RegEx) -> int:
	var largest := 0
	if value is String:
		var matched := pattern.search(value)
		if matched != null: largest = matched.get_string(1).to_int()
	elif value is Array:
		for child in value: largest = maxi(largest,_maximum_allocated_id(child,pattern))
	elif value is Dictionary:
		for key in value:
			var child: Variant = value[key]
			if child is Dictionary or child is Array or key in ["event_id","entity_id","anchor_id","memory_id","observer_id","subject_ref","instance_id","id"]:
				largest = maxi(largest,_maximum_allocated_id(child,pattern))
	return largest
