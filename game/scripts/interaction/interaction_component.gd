extends Area2D
## Detects nearby Interactable targets, selects the nearest and handles requests.

@export_range(1.0, 1000.0, 1.0, "or_greater") var interaction_range: float = 96.0:
	set(value):
		interaction_range = maxf(value, 1.0)
		_sync_range_shape()

var interactor: Node2D
var _candidates: Array[Interactable] = []
var _current_target: Interactable
var _interaction_enabled := true


func _ready() -> void:
	if interactor == null:
		interactor = get_parent() as Node2D
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	_sync_range_shape()
	refresh_target()


func _process(_delta: float) -> void:
	refresh_target()
	if Input.is_action_just_pressed(&"interact"):
		try_interact()


func get_current_target() -> Interactable:
	return _current_target if is_instance_valid(_current_target) else null


func get_current_prompt() -> String:
	var target := get_current_target()
	if target == null or not target.can_interact(interactor):
		return ""
	return target.get_interaction_prompt(interactor)


func get_candidates() -> Array[Interactable]:
	return _candidates.duplicate()


func try_interact() -> bool:
	if not _interaction_enabled:
		return false
	var target := get_current_target()
	if target == null or not target.is_inside_tree() or not target.can_interact(interactor):
		refresh_target()
		return false
	target.interact(interactor)
	return true


func set_interaction_enabled(enabled: bool) -> void:
	_interaction_enabled = enabled
	if not enabled:
		_current_target = null
	else:
		refresh_target()


func is_interaction_enabled() -> bool:
	return _interaction_enabled


func refresh_target() -> void:
	if not _interaction_enabled:
		_current_target = null
		return
	for index in range(_candidates.size() - 1, -1, -1):
		var candidate := _candidates[index]
		if not is_instance_valid(candidate) or not candidate.is_inside_tree():
			_candidates.remove_at(index)
	var selected: Interactable
	var nearest_distance_squared := INF
	if is_instance_valid(interactor) and interactor.is_inside_tree():
		for candidate in _candidates:
			if not candidate.can_interact(interactor):
				continue
			var distance_squared := global_position.distance_squared_to(candidate.global_position)
			if distance_squared < nearest_distance_squared:
				nearest_distance_squared = distance_squared
				selected = candidate
	_current_target = selected


func _register_candidate(candidate: Interactable) -> void:
	if is_instance_valid(candidate) and not _candidates.has(candidate):
		_candidates.append(candidate)
	refresh_target()


func _remove_candidate(candidate: Interactable) -> void:
	_candidates.erase(candidate)
	refresh_target()


func _on_area_entered(area: Area2D) -> void:
	var candidate := area as Interactable
	if candidate != null:
		_register_candidate(candidate)


func _on_area_exited(area: Area2D) -> void:
	var candidate := area as Interactable
	if candidate != null:
		_remove_candidate(candidate)


func _sync_range_shape() -> void:
	var collision_shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null:
		return
	var circle := collision_shape.shape as CircleShape2D
	if circle == null:
		circle = CircleShape2D.new()
		collision_shape.shape = circle
	circle.radius = interaction_range
