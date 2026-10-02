class_name WorldGrid
extends RefCounted
## Converts between world space, tile cells and stable chunk coordinates.

const MAX_COORDINATE := 1_000_000_000.0

var tile_size: float
var chunk_size: int


func _init(world_tile_size: Variant = 32.0, cells_per_chunk: Variant = 16) -> void:
	if typeof(world_tile_size) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(world_tile_size)):
		tile_size = 0.0
	else:
		tile_size = float(world_tile_size)
	chunk_size = int(cells_per_chunk) if typeof(cells_per_chunk) == TYPE_INT else 0


func is_valid() -> bool:
	return is_finite(tile_size) and tile_size > 0.0 and chunk_size > 0


func world_to_cell(position: Vector2) -> Vector2i:
	if not is_valid() or not _is_finite_vector(position):
		return Vector2i.ZERO
	return Vector2i(floori(position.x / tile_size), floori(position.y / tile_size))


func cell_to_world_center(cell: Vector2i) -> Vector2:
	if not is_valid():
		return Vector2.ZERO
	return (Vector2(cell) + Vector2.ONE * 0.5) * tile_size


func cell_to_chunk(cell: Vector2i) -> Vector2i:
	if not is_valid():
		return Vector2i.ZERO
	return Vector2i(floori(float(cell.x) / chunk_size), floori(float(cell.y) / chunk_size))


func chunk_to_world_origin(chunk: Vector2i) -> Vector2:
	if not is_valid():
		return Vector2.ZERO
	return Vector2(chunk * chunk_size) * tile_size


func _is_finite_vector(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y) \
		and absf(value.x) <= MAX_COORDINATE and absf(value.y) <= MAX_COORDINATE
