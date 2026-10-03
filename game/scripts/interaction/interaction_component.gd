extends Area2D
## Detects nearby Interactable targets, selects the nearest and handles requests.

signal interaction_completed(target: Interactable)

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


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	if _interaction_enabled:
		var clicked_target := _get_clicked_candidate(get_global_mouse_position())
		if clicked_target != null:
			_interact_with_target(clicked_target)
	# Consume world clicks so an embedded F5 run cannot select editor objects/scripts.
	get_viewport().set_input_as_handled()


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
	if target == null:
		refresh_target()
		return false
	return _interact_with_target(target)


func _interact_with_target(target: Interactable) -> bool:
	if not _interaction_enabled or not is_instance_valid(target) or not target.is_inside_tree() \
		or not _candidates.has(target) or not target.can_interact(interactor):
		refresh_target()
		return false
	target.interact(interactor)
	interaction_completed.emit(target)
	return true


func _get_clicked_candidate(world_position: Vector2) -> Interactable:
	if not is_finite(world_position.x) or not is_finite(world_position.y):
		return null
	var query := PhysicsPointQueryParameters2D.new()
	query.position = world_position
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hits := get_world_2d().direct_space_state.intersect_point(query, 16)
	for hit in hits:
		var candidate := hit.get("collider") as Interactable
		if candidate != null and _candidates.has(candidate) and candidate.can_interact(interactor):
			return candidate
	return null


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
	var selected_priority := -2147483648
	if is_instance_valid(interactor) and interactor.is_inside_tree():
		for candidate in _candidates:
			if not candidate.can_interact(interactor):
				continue
			var distance_squared := global_position.distance_squared_to(candidate.global_position)
			if candidate.interaction_priority > selected_priority or \
				(candidate.interaction_priority == selected_priority and distance_squared < nearest_distance_squared):
				nearest_distance_squared = distance_squared
				selected_priority = candidate.interaction_priority
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
