extends SceneTree
## World coordinates map deterministically to cells and chunks, including negatives.

const WORLD_GRID_PATH := "res://scripts/world/world_grid.gd"

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
	var script: Script = load(WORLD_GRID_PATH)
	check(script != null, "WorldGrid API exists")
	if script != null:
		var grid = script.new(32, 16)
		check(grid.is_valid(), "positive tile and chunk sizes are accepted")
		check(grid.world_to_cell(Vector2(0.0, 0.0)) == Vector2i.ZERO, "origin maps to cell zero")
		check(grid.world_to_cell(Vector2(31.9, 32.0)) == Vector2i(0, 1), "world positions map to floor-based cells")
		check(grid.world_to_cell(Vector2(-0.1, -32.1)) == Vector2i(-1, -2), "negative positions map consistently")
		check(grid.cell_to_world_center(Vector2i(2, 3)).is_equal_approx(Vector2(80.0, 112.0)), "cells map back to world-space centers")
		check(grid.cell_to_chunk(Vector2i(17, 31)) == Vector2i(1, 1), "positive cells map to chunks")
		check(grid.cell_to_chunk(Vector2i(-1, -16)) == Vector2i(-1, -1), "negative cells map to floor-based chunks")
		check(not script.new(0, 16).is_valid(), "invalid tile size is rejected")
	print("WorldGrid: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
