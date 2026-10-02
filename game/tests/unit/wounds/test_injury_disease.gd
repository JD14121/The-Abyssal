extends SceneTree
## Infection and injury consequences advance independently from Combat.

const INFECTION_PATH := "res://scripts/wounds/infection_state.gd"
const INJURY_PATH := "res://scripts/wounds/injury_state.gd"
const WOUND_ID := "7f9f8818-940b-4e38-9c02-137d9963103a"

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
	var infection_script: Script = load(INFECTION_PATH)
	var injury_script: Script = load(INJURY_PATH)
	check(infection_script != null and injury_script != null, "InfectionState and InjuryState APIs exist")
	if infection_script == null or injury_script == null:
		_finish()
		return
	var infection = infection_script.new(WOUND_ID, 0.5, 20.0)
	check(infection.is_valid() and not infection.is_infected(), "new contamination is valid but not yet an infection")
	check(infection.advance_game_time(3600.0) and is_equal_approx(infection.get_level(), 10.0), "infection progresses by game time and wound risk")
	check(infection.is_infected(), "infection crosses its symptom threshold")
	check(infection.advance_game_time(3600.0), "infection continues progressing while untreated")
	check(infection.get_health_loss_per_game_hour() > 0.0, "severe infection can create health consequences")
	check(infection.reduce(16.0) and is_equal_approx(infection.get_level(), 4.0), "antibiotic effect reduces infection severity")
	check(not infection.is_infected(), "treatment clears infection below its threshold")
	check(not infection.advance_game_time(INF) and not infection.reduce(-1.0), "infection rejects invalid progression and treatment")
	var injury = injury_script.new(WOUND_ID, 5.0, 80.0, true)
	check(injury.is_valid() and injury.is_fracture(), "severe InjuryState retains fracture state")
	check(injury.get_movement_multiplier() < 0.8, "fractures apply a movement penalty")
	check(injury.reduce_pain(20.0) and is_equal_approx(injury.get_pain(), 60.0), "pain treatment reduces pain")
	check(injury.advance_game_time(3600.0) and injury.get_healing_progress() > 0.0, "injury healing advances with game time")
	check(not injury.advance_game_time(-1.0) and not injury.reduce_pain(INF), "injury rejects invalid updates")
	_finish()


func _finish() -> void:
	print("Injury and disease: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
