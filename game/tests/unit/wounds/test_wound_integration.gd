extends SceneTree
## Player damage creates independent Wounds and GameClock bleeding reaches Health.

const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"
const DAMAGE_EVENT_PATH := "res://scripts/combat/damage_event.gd"
const COMBAT_SERVICE_PATH := "res://scripts/combat/combat_service.gd"

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
	var game_clock: Node = root.get_node("GameClock")
	check(game_clock.deserialize({"elapsed_game_seconds": 0.0, "time_scale": 1.0, "paused": false}), "test starts with a known GameClock state")
	var player_scene: PackedScene = load(PLAYER_SCENE_PATH)
	var event_script: Script = load(DAMAGE_EVENT_PATH)
	var service_script: Script = load(COMBAT_SERVICE_PATH)
	check(player_scene != null and event_script != null and service_script != null, "Player combat integration resources load")
	if player_scene == null or event_script == null or service_script == null:
		_finish()
		return
	var player: CharacterBody2D = player_scene.instantiate()
	root.add_child(player)
	await process_frame
	var wounds = player.get_node_or_null("WoundComponent")
	check(wounds != null, "Player composes a WoundComponent")
	if wounds == null:
		player.queue_free()
		await process_frame
		_finish()
		return
	var attacker := Node2D.new()
	root.add_child(attacker)
	var service = service_script.new()
	var state = player.get_node("SurvivalComponent").get("state")
	check(service.apply_damage_event(event_script.new(attacker, player, 20.0)), "accepted combat damage applies to Player")
	check(wounds.get_wounds().size() == 1 and is_equal_approx(state.get_health(), 80.0), "one accepted hit creates one Wound and applies base damage")
	check(not service.apply_damage_event(event_script.new(attacker, player, -1.0)), "rejected damage does not enter the Wound system")
	check(wounds.get_wounds().size() == 1 and is_equal_approx(state.get_health(), 80.0), "invalid combat input creates no Wound or Health change")
	var first_wound = wounds.get_wounds()[0]
	check(is_equal_approx(first_wound.get_bleeding_rate_per_game_hour(), 2.0), "damage amount determines the initial bleeding rate")
	check(wounds.get_wound(first_wound.wound_id) == first_wound and wounds.get_wound("unknown_wound") == null, "WoundComponent resolves only an exact wound_id")
	check(service.apply_damage_event(event_script.new(attacker, player, 10.0)), "second combat hit applies")
	var wound_list: Array = wounds.get_wounds()
	check(wound_list.size() == 2 and wound_list[0].wound_id != wound_list[1].wound_id, "each accepted hit creates an independently identifiable Wound")
	check(game_clock.advance(1800.0), "GameClock advances logical time")
	wounds._process(0.0)
	check(is_equal_approx(state.get_health(), 68.5), "independent bleeding rates reduce Player Health over game time")
	check(not wounds.advance_game_time(-1.0) and not wounds.advance_game_time(INF), "WoundComponent rejects invalid elapsed time")
	check(is_equal_approx(state.get_health(), 68.5), "invalid elapsed time does not change Health")
	wound_list[0].reduce_bleeding(2.0)
	check(game_clock.advance(3600.0), "GameClock advances after one Wound stops bleeding")
	wounds._process(0.0)
	check(is_equal_approx(state.get_health(), 67.5), "stopped Wound contributes no further blood loss")
	state.set_health(0.5)
	check(game_clock.advance(3600.0), "GameClock advances the lethal bleeding interval")
	wounds._process(0.0)
	check(is_zero_approx(state.get_health()) and player.get_node("PlayerDefeatComponent").is_defeated(), "bleeding depletion follows the existing Player defeat signal path")
	attacker.queue_free()
	player.queue_free()
	await process_frame
	_finish()


func _finish() -> void:
	print("Wound integration: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
