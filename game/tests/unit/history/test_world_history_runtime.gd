extends SceneTree
const F = preload("res://tests/unit/history/history_fixture.gd")
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; printerr("FAIL: "+message)
func run() -> void:
	check(ResourceLoader.exists("res://scripts/history/world_history_runtime.gd"),"runtime exists")
	if failures: quit(1); return
	var script = load("res://scripts/history/world_history_runtime.gd")
	var runtime = script.new()
	check(runtime.initialize("test_world"),"world-local runtime initializes validated configuration")
	check(runtime.record(F.event(),[F.anchor("corpse")]),"completed outcome creates ledger and memory")
	check(runtime.knowledge.query("observer_a").is_empty(),"world truth does not automatically grant observer knowledge")
	check(runtime.observe("observer_a","evt_death_memory","corpse",100.0),"explicit discovery creates knowledge")
	var beliefs: Array = runtime.knowledge.query("observer_a")
	check(beliefs.size() == 5 and not beliefs[0].has("truth_accuracy"),"belief stores confidence and provenance without truth access")
	check(runtime.knowledge.query("observer_b").is_empty(),"knowledge is isolated per observer")
	var serialized: Dictionary = runtime.serialize()
	var restored = script.new()
	check(restored.deserialize(JSON.parse_string(JSON.stringify(serialized))),"full boundary round-trips through JSON")
	check(restored.serialize() == serialized,"restored ledger graph and knowledge agree")
	var invalid: Dictionary = serialized.duplicate(true)
	invalid.graph.nodes[0].source_event_ids = ["missing_event"]
	check(not restored.deserialize(invalid) and restored.serialize() == serialized,"cross-layer restore failure is atomic")
	invalid = serialized.duplicate(true)
	invalid.knowledge.records[0].source_claim_id = "missing_claim"
	check(not restored.deserialize(invalid) and restored.serialize() == serialized,"unresolved knowledge source is rejected")
	var minor := F.event("evt_minor")
	minor.event_type = "ordinary_damage"
	check(not runtime.record(minor,[F.anchor("minor")]) and not runtime.ledger.has_event("evt_minor"),"ordinary damage never floods history")
	var good := F.event("evt_without_medium")
	check(not runtime.record(good,[]) and runtime.ledger.has_event("evt_without_medium"),"failed encoding retains completed canonical truth")
	var next: String = restored.next_id("actor")
	var again = script.new()
	again.deserialize(restored.serialize())
	check(again.next_id("actor") != next,"identity allocator survives restore without reusing IDs")
	var allocated := F.event(restored.next_id("event"))
	check(restored.record(allocated,[F.anchor(restored.next_id("anchor"))]),"allocated identities are retained in history")
	invalid = restored.serialize()
	invalid.identity_counter = 0
	check(not again.deserialize(invalid),"restore cannot rewind identity allocator below recorded IDs")
	var malformed_event := F.event("evt_bad_type")
	malformed_event.event_type = []
	check(not runtime.record(malformed_event,[]),"malformed outcome type fails without a script exception")
	var slice = script.new()
	slice.initialize("mine_history")
	var wound := F.event("slice_wound")
	wound.event_type = "major_wound"
	wound.world_time_seconds = 10
	wound.facts = [{"key":"wound_id","value":"severe_wound_a"}]
	var bleeding := F.event("slice_bleeding",["slice_wound"])
	bleeding.event_type = "severe_bleeding"
	bleeding.world_time_seconds = 20
	bleeding.facts = [{"key":"wound_id","value":"severe_wound_a"}]
	check(slice.record(wound,[F.anchor("wound_trace","location","location_trace")]) and slice.record(bleeding,[F.anchor("blood_trace","location","location_trace")]),"explicit severe wound and bleeding causes are recorded")
	check(slice.record(F.event("slice_death",["slice_bleeding"]),[F.anchor("slice_corpse"),F.anchor("slice_knife","world_item","relic")]),"confirmed blood-loss death binds corpse and carried knife")
	var slice_truth: Dictionary = slice.ledger.serialize()
	slice.graph.destroy_anchor("slice_corpse")
	slice.graph.set_anchor_accessibility("slice_knife",0.0)
	check(slice.graph.get_memory("slice_death_memory").memory_state == "dormant","buried knife preserves dormant character history")
	check(slice.observe("later_explorer","slice_death_memory","slice_knife",10000.0),"later explorer rediscovers surviving relic without a biography")
	check(slice.ledger.serialize() == slice_truth and slice.ledger.get_causes("slice_death") == ["slice_bleeding"],"rediscovery preserves the complete explicit causal chain")
	print("WorldHistoryRuntime: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
