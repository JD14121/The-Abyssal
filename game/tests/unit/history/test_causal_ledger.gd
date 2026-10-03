extends SceneTree

const Fixture = preload("res://tests/unit/history/history_fixture.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: "+message)

func run() -> void:
	var path := "res://scripts/history/causal_ledger.gd"
	check(ResourceLoader.exists(path), "causal history layer exists")
	if failures:
		quit(1)
		return
	var ledger = load(path).new()
	var source := Fixture.event("evt_wound")
	source.event_type = "major_wound"
	source.world_time_seconds = 10.0
	check(ledger.append_event(source), "valid event is accepted")
	source.facts[0].value = "tampered"
	check(ledger.get_event("evt_wound").facts[0].value == "blood_loss", "caller mutation cannot rewrite canonical facts")
	var snapshot: Dictionary = ledger.get_event("evt_wound")
	snapshot.actor_refs.clear()
	check(ledger.get_event("evt_wound").actor_refs.size() == 1, "returned nested collections are detached")
	check(not ledger.append_event(Fixture.event("evt_wound")), "duplicate IDs are rejected")
	check(ledger.append_event(Fixture.event("evt_death", ["evt_wound"])), "existing causal reference is accepted")
	check(ledger.get_causes("evt_death") == ["evt_wound"], "cause query follows explicit IDs")
	check(ledger.get_effects("evt_wound") == ["evt_death"], "reverse causal query is indexed")
	check(ledger.query_by_actor("character_mara") == ["evt_wound", "evt_death"], "actor query returns deterministic acceptance order")
	check(ledger.query_by_object("knife_x") == ["evt_wound", "evt_death"], "item history uses stable instance identity")
	check(ledger.query_by_location("region_mine", "mine_7") == ["evt_wound", "evt_death"], "location query includes region and area")
	var before: Dictionary = ledger.serialize()
	check(not ledger.append_event(Fixture.event("evt_invalid", ["evt_unknown"])), "unknown explicit cause fails closed")
	check(ledger.serialize() == before, "failed append does not change records or indexes")
	var invalid := Fixture.event("evt_nan")
	invalid.world_time_seconds = NAN
	check(not ledger.append_event(invalid), "nonfinite time is rejected")
	invalid = Fixture.event("evt_node")
	invalid.facts[0].value = root
	check(not ledger.append_event(invalid), "live Node cannot become historical data")
	invalid = Fixture.event("evt_negative")
	invalid.world_time_seconds = -1.0
	check(not ledger.append_event(invalid), "negative world time is rejected")
	invalid = Fixture.event("evt_future_cause", ["evt_death"])
	invalid.world_time_seconds = 1.0
	check(not ledger.append_event(invalid), "cause cannot occur after its effect")
	invalid = Fixture.event("evt_self", ["evt_self"])
	check(not ledger.append_event(invalid), "self causality is rejected")
	var restored = load(path).new()
	check(restored.deserialize(JSON.parse_string(JSON.stringify(before))), "JSON round trip restores canonical events")
	check(restored.serialize() == before, "round trip preserves complete structured history")
	var broken := before.duplicate(true)
	broken.events[1].cause_event_ids = ["missing"]
	check(not restored.deserialize(broken), "invalid causal references reject load")
	check(restored.serialize() == before, "failed load retains previous valid ledger")
	check(not restored.deserialize({"schema_version": 2, "events": []}), "unknown schema version is rejected")
	print("CausalLedger: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
