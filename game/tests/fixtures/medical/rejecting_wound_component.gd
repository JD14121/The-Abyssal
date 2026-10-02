extends Node

const RejectingWoundState = preload("res://tests/fixtures/medical/rejecting_wound_state.gd")

var wound: WoundState = RejectingWoundState.new(1.0)


func _ready() -> void:
	pass


func get_wound(wound_id: String) -> WoundState:
	return wound if wound_id == wound.wound_id else null
