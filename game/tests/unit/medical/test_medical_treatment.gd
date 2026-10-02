extends SceneTree
## Medical treatment targets one wound and consumes only the requested bandage.

const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"
const FACTORY_PATH := "res://scripts/items/item_factory.gd"
const DAMAGE_EVENT_PATH := "res://scripts/combat/damage_event.gd"
const COMBAT_SERVICE_PATH := "res://scripts/combat/combat_service.gd"
const TREATMENT_SERVICE_PATH := "res://scripts/medical/treatment_service.gd"
const REJECTING_WOUNDS := preload("res://tests/fixtures/medical/rejecting_wound_component.gd")

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
	var treatment_script: Script = load(TREATMENT_SERVICE_PATH)
	check(treatment_script != null, "TreatmentService exists")
	if treatment_script == null:
		_finish()
		return
	var registry = root.get_node("DataRegistry")
	var service = treatment_script.new(registry)
	var player_scene: PackedScene = load(PLAYER_SCENE_PATH)
	var player: CharacterBody2D = player_scene.instantiate()
	root.add_child(player)
	await process_frame
	var player_inventory = player.get_node("PlayerInventoryComponent").get_inventory()
	var wounds = player.get_node("WoundComponent")
	var infections = player.get_node("InfectionComponent")
	var injuries = player.get_node("InjuryComponent")
	var factory = load(FACTORY_PATH).new(registry)
	var bandages: Array[ItemInstance] = []
	for index in range(4):
		var bandage: ItemInstance = factory.create(&"clean_bandage")
		bandages.append(bandage)
		check(player_inventory.add_item(bandage), "Inventory accepts bandage instance %d" % index)
	var hammer: ItemInstance = factory.create(&"hammer")
	check(player_inventory.add_item(hammer), "Inventory accepts unrelated Item")
	var attacker := Node2D.new()
	root.add_child(attacker)
	var combat = load(COMBAT_SERVICE_PATH).new()
	var event_script = load(DAMAGE_EVENT_PATH)
	check(combat.apply_damage_event(event_script.new(attacker, player, 20.0)), "first hit creates a treatable Wound")
	check(combat.apply_damage_event(event_script.new(attacker, player, 10.0)), "second hit creates another Wound")
	var wound_list: Array = wounds.get_wounds()
	var wound_a = wound_list[0]
	var wound_b = wound_list[1]
	check(infections.get_infection(wound_a.wound_id) != null, "new wounds receive independent infection state")
	check(injuries.get_injury(wound_a.wound_id) != null and injuries.get_movement_multiplier() < 1.0, "severe wounds create movement-affecting injury state")
	check(not service.treat_wound(player_inventory, wounds, bandages[0].instance_id, "unknown_wound"), "unknown wound_id is rejected")
	check(not service.treat_wound(player_inventory, wounds, "unknown_item", wound_a.wound_id), "unknown Inventory instance is rejected")
	check(not service.treat_wound(player_inventory, wounds, hammer.instance_id, wound_a.wound_id), "non-medical Item is rejected")
	check(player_inventory.get_item_count() == 5 and wound_a.is_bleeding(), "invalid treatment attempts preserve Inventory and Wounds")
	check(service.treat_wound(player_inventory, wounds, bandages[0].instance_id, wound_a.wound_id), "bandage treats the selected wound")
	check(is_equal_approx(wound_a.get_bleeding_rate_per_game_hour(), 1.25), "bandage partially reduces target bleeding")
	check(is_equal_approx(wound_b.get_bleeding_rate_per_game_hour(), 1.0), "treatment leaves other wounds unchanged")
	check(not player_inventory.has_item(bandages[0].instance_id) and player_inventory.get_item(bandages[1].instance_id) == bandages[1], "treatment consumes the exact bandage instance")
	check(service.treat_wound(player_inventory, wounds, bandages[1].instance_id, wound_a.wound_id), "a second bandage further treats the same wound")
	check(is_equal_approx(wound_a.get_bleeding_rate_per_game_hour(), 0.5), "repeated treatment continues reducing bleeding")
	check(service.treat_wound(player_inventory, wounds, bandages[2].instance_id, wound_a.wound_id), "bandage can stop the remaining bleeding")
	check(not wound_a.is_bleeding() and is_equal_approx(wound_b.get_bleeding_rate_per_game_hour(), 1.0), "treated wound stops independently")
	check(not service.treat_wound(player_inventory, wounds, bandages[3].instance_id, wound_a.wound_id), "already-stopped Wound rejects treatment")
	check(player_inventory.get_item(bandages[3].instance_id) == bandages[3], "ineffective repeat treatment does not consume its bandage")
	var rejecting_wounds = REJECTING_WOUNDS.new()
	root.add_child(rejecting_wounds)
	var rejected_wound_id: String = rejecting_wounds.wound.wound_id
	check(not service.treat_wound(player_inventory, rejecting_wounds, bandages[3].instance_id, rejected_wound_id), "Wound mutation failure rejects the treatment transaction")
	check(player_inventory.get_item(bandages[3].instance_id) == bandages[3], "failed treatment restores the same bandage instance")
	check(is_equal_approx(rejecting_wounds.wound.get_bleeding_rate_per_game_hour(), 1.0), "failed treatment leaves the Wound unchanged")
	var antibiotic: ItemInstance = factory.create(&"antibiotic_tablet")
	check(player_inventory.add_item(antibiotic), "Inventory accepts antibiotic ItemInstance")
	check(not service.treat_wound(player_inventory, wounds, antibiotic.instance_id, wound_b.wound_id, infections), "antibiotics reject an untreated Wound")
	check(player_inventory.get_item(antibiotic.instance_id) == antibiotic, "ineffective antibiotic treatment preserves its ItemInstance")
	check(infections.advance_game_time(3.0 * 3600.0), "infection progresses from the target Wound over game time")
	var infection = infections.get_infection(wound_b.wound_id)
	check(infection != null and infection.is_infected(), "progressed infection is linked to wound_id")
	check(service.treat_wound(player_inventory, wounds, antibiotic.instance_id, wound_b.wound_id, infections), "antibiotic treats the matching infected wound")
	check(not infection.is_infected() and not player_inventory.has_item(antibiotic.instance_id), "antibiotic reduces infection and consumes its exact instance")
	rejecting_wounds.free()
	attacker.queue_free()
	player.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	print("Medical treatment: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
