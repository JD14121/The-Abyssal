extends SceneTree
const Fixture = preload("res://tests/unit/history/history_fixture.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: "+message)
func run() -> void:
	for path in ["memory_config","world_memory_graph","memory_encoder"]:
		check(ResourceLoader.exists("res://scripts/memory/"+path+".gd"),path+" exists")
	if failures: quit(1); return
	var config = load("res://scripts/memory/memory_config.gd").new()
	check(config.load_files(), "memory profiles and policies load")
	var original_config: Dictionary = config.serialize()
	var malformed := original_config.duplicate(true)
	malformed.profiles.append(malformed.profiles[0].duplicate())
	check(not config.deserialize(malformed), "duplicate media ID is rejected")
	check(config.serialize() == original_config, "config failure retains validated definitions")
	malformed = original_config.duplicate(true)
	malformed.policies[0].profile_id = "unknown"
	check(not config.deserialize(malformed), "event policy must resolve its retention profile")
	var ledger = load("res://scripts/history/causal_ledger.gd").new()
	ledger.append_event(Fixture.event())
	var graph = load("res://scripts/memory/world_memory_graph.gd").new(ledger,config)
	var encoder = load("res://scripts/memory/memory_encoder.gd").new(config)
	check(encoder.encode(ledger,graph,"evt_death","memory_death",[Fixture.anchor("corpse_a"),Fixture.anchor("knife_a","world_item","relic")]), "canonical event encodes semantic memory with two media")
	var memory: Dictionary = graph.get_memory("memory_death")
	check(memory.anchor_ids == ["corpse_a","knife_a"], "one memory links multiple physical anchors")
	check(graph.get_claims("memory_death").size() == 5, "claims preserve facts, actor, place and semantic residue separately")
	check(graph.query_by_event("evt_death") == ["memory_death"], "memory source is indexed")
	check(graph.query_by_target("world_item","knife_a_target") == ["memory_death"], "stable item target finds its evidence")
	memory.anchor_ids.clear()
	check(graph.get_memory("memory_death").anchor_ids.size() == 2, "returned graph collections cannot mutate stored links")
	var truth: Dictionary = ledger.serialize()
	var before: Dictionary = graph.serialize()
	check(not encoder.encode(ledger,graph,"evt_death","memory_invalid",[Fixture.anchor("corpse_a")]), "duplicate anchor ID rejects encoding")
	check(graph.serialize() == before and ledger.serialize() == truth, "encode failure changes neither graph nor canonical event")
	check(encoder.encode(ledger,graph,"evt_death","memory_second",[Fixture.anchor("location_a","location","location_trace")]), "one event supports multiple independently anchored memories")
	check(graph.query_by_event("evt_death") == ["memory_death","memory_second"], "multiple memories coexist")
	check(graph.destroy_anchor("corpse_a"), "physical destruction removes a corpse access path")
	check(graph.get_memory("memory_death").accessibility > 0.0, "remaining knife anchor preserves access")
	check(graph.set_anchor_accessibility("knife_a",0.0), "buried relic loses current accessibility")
	check(graph.get_memory("memory_death").memory_state == "dormant", "durable inaccessible evidence becomes dormant")
	check(graph.discover("memory_death","knife_a","observer_later").size() > 0, "rediscovery restores access to surviving relic")
	check(graph.get_memory("memory_death").memory_state == "active", "dormant memory reactivates")
	check(not graph.discover("memory_death","corpse_a","observer_later").size(), "destroyed corpse cannot be rediscovered")
	check(graph.destroy_anchor("knife_a"), "last anchor can be destroyed")
	check(graph.get_memory("memory_death").memory_state == "lost", "no surviving medium makes world memory lost")
	check(ledger.serialize() == truth, "lost memory never deletes death truth")
	var restored = load("res://scripts/memory/world_memory_graph.gd").new(ledger,config)
	check(restored.deserialize(JSON.parse_string(JSON.stringify(graph.serialize()))), "graph JSON restores all structured links")
	check(restored.serialize() == graph.serialize(), "graph round trip is deterministic")
	var invalid: Dictionary = graph.serialize()
	invalid.nodes[0].claim_ids.append("missing_claim")
	var restored_before: Dictionary = restored.serialize()
	check(not restored.deserialize(invalid) and restored.serialize() == restored_before, "unresolved graph references fail atomically")
	invalid = graph.serialize()
	invalid.nodes[0].provenance.source_memory_ids = ""
	check(not restored.deserialize(invalid) and restored.serialize() == restored_before,"malformed provenance cannot bypass source validation")
	check(not restored.update_records({"unknown":[]}) and not restored.get_errors().is_empty(),"invalid update reports actionable errors")
	check(graph.bind_anchor("memory_second","corpse_a"),"one anchor may support multiple memories even after destruction")
	invalid = graph.serialize()
	invalid.nodes[0].last_updated_world_time = "invalid"
	check(not restored.deserialize(invalid),"malformed timestamp is rejected without arithmetic on invalid data")
	invalid = graph.serialize()
	invalid.nodes[0].provenance.source_memory_ids = [invalid.nodes[1].memory_id]
	invalid.nodes[1].provenance.source_memory_ids = [invalid.nodes[0].memory_id]
	check(not restored.deserialize(invalid),"derived provenance cannot form a cycle")
	invalid = graph.serialize()
	invalid.nodes[0].provenance.source_event_ids = ["missing_event"]
	check(not restored.deserialize(invalid),"provenance cannot contain an unresolved event reference")
	print("MemoryGraph: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
