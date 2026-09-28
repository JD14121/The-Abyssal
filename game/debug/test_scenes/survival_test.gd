extends Node2D

const PLAYER_SCENE = preload("res://scenes/player/player.tscn")
const ONE_HOUR_SECONDS := 3600.0
const SIX_HOURS_SECONDS := 21600.0

@onready var _status: Label = $CanvasLayer/Status
var _player: CharacterBody2D


func _ready() -> void:
	_player = PLAYER_SCENE.instantiate()
	_player.position = Vector2(400.0, 300.0)
	add_child(_player)
	_refresh_status()


func _process(_delta: float) -> void:
	_refresh_status()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1:
			_advance_hours(ONE_HOUR_SECONDS)
		KEY_6:
			_advance_hours(SIX_HOURS_SECONDS)
		KEY_P:
			GameClock.set_paused(not GameClock.is_paused())
		KEY_R:
			GameClock.deserialize({"elapsed_game_seconds": 0.0, "time_scale": 1.0, "paused": false})
			var survival = _player.get_node("SurvivalComponent")
			survival.state.deserialize({"health": 100.0, "hunger": 0.0, "thirst": 0.0})
	_refresh_status()


func _advance_hours(real_seconds: float) -> void:
	var was_paused: bool = GameClock.is_paused()
	var old_scale: float = GameClock.get_time_scale()
	GameClock.set_paused(false)
	GameClock.set_time_scale(1.0)
	GameClock.advance(real_seconds)
	GameClock.set_time_scale(old_scale)
	GameClock.set_paused(was_paused)
	# Node processing catches up from the shared elapsed-time cursor on the next frame.


func _refresh_status() -> void:
	if _player == null:
		return
	var survival = _player.get_node("SurvivalComponent")
	var state = survival.state
	var pause_text := "paused" if GameClock.is_paused() else "running"
	_status.text = "Phase 7 — Survival Foundation\n" + \
		"1: +1 game hour   6: +6 game hours   P: pause   R: reset\n" + \
		"Clock: %.2f game hours (%s)\n" % [GameClock.get_elapsed_game_seconds() / ONE_HOUR_SECONDS, pause_text] + \
		"Health: %.1f / 100   Hunger: %.2f / 100   Thirst: %.2f / 100\n" % [state.get_health(), state.get_hunger(), state.get_thirst()] + \
		"Test rates: hunger +1/hour, thirst +2/hour"
