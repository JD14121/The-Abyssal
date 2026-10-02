extends SceneTree
## Medical static data, Item mapping and schema validation checks.

const REGISTRY_PATH := "res://autoload/data_registry.gd"
const VALIDATOR_PATH := "res://scripts/data/data_validator.gd"
const VALID_ROOT := "res://data"

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	var registry = load(REGISTRY_PATH).new()
	check(registry.load_all_data(VALID_ROOT), "production Medical data loads atomically")
	var has_api: bool = registry.has_method("get_medical") and registry.has_method("has_medical") \
		and registry.has_method("get_all_medical") and registry.has_method("get_medical_for_item")
	check(has_api, "DataRegistry exposes Medical profile lookup APIs")
	if has_api and registry.is_loaded():
		var bandage = registry.get_medical(&"medical_clean_bandage")
		check(bandage != null and bandage.item_id == &"clean_bandage", "MedicalDefinition resolves its exact Item ID")
		check(bandage != null and is_equal_approx(bandage.bleeding_reduction_per_game_hour, 0.75), "MedicalDefinition loads bleeding treatment strength")
		var antibiotic = registry.get_medical(&"medical_antibiotic_tablet")
		check(registry.has_medical(&"medical_clean_bandage") and registry.get_all_medical().size() == 2, "Medical ID lookup and listing work")
		check(antibiotic != null and antibiotic.item_id == &"antibiotic_tablet" \
			and is_equal_approx(antibiotic.infection_reduction_per_game_hour, 25.0), "infection-only Medical profile is loaded")
		check(registry.get_medical_for_item(&"clean_bandage") == bandage, "Item mapping finds the MedicalDefinition")
		check(registry.get_medical_for_item(&"hammer") == null and registry.get_medical(&"missing") == null, "unknown Medical and Item IDs return null")

	var validator = load(VALIDATOR_PATH).new()
	var items := {&"clean_bandage": true}
	var valid: Dictionary = {"type": "medical", "id": "medical_test", "item_id": "clean_bandage", "bleeding_reduction_per_game_hour": 0.5}
	check(_validate_medical(validator, valid, items, {}), "Medical schema accepts a positive finite treatment effect")
	check(_validate_medical(validator, {"type": "medical", "id": "antibiotic_test", "item_id": "clean_bandage", "infection_reduction_per_game_hour": 5.0}, items, {}), "Medical schema accepts infection-only treatment")
	var invalid_entries: Array[Dictionary] = [
		{"type": "medical", "id": "missing_effect", "item_id": "clean_bandage"},
		{"type": "medical", "id": "zero_effect", "item_id": "clean_bandage", "bleeding_reduction_per_game_hour": 0.0},
		{"type": "medical", "id": "negative_effect", "item_id": "clean_bandage", "bleeding_reduction_per_game_hour": -1.0},
		{"type": "medical", "id": "boolean_effect", "item_id": "clean_bandage", "bleeding_reduction_per_game_hour": true},
		{"type": "medical", "id": "nan_effect", "item_id": "clean_bandage", "bleeding_reduction_per_game_hour": NAN},
		{"type": "medical", "id": "infinite_effect", "item_id": "clean_bandage", "bleeding_reduction_per_game_hour": INF},
		{"type": "medical", "id": "unknown_item", "item_id": "not_an_item", "bleeding_reduction_per_game_hour": 1.0},
	]
	for entry in invalid_entries:
		check(not _validate_medical(validator, entry, items, {}), "Medical schema rejects invalid fields or unresolved Items")
	var duplicate_mapping := {&"clean_bandage": {"source_file": "medical/first.json"}}
	check(not validator.validate(valid, "medical", "medical fixture", {}, items, {}, {}, duplicate_mapping), "one Item cannot map to duplicate Medical profiles")
	registry.free()
	_finish()


func _validate_medical(validator: RefCounted, entry: Dictionary, items: Dictionary, mappings: Dictionary) -> bool:
	return validator.validate(entry, "medical", "medical fixture", {}, items)


func _finish() -> void:
	print("Medical registry: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
