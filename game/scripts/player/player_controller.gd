extends CharacterBody2D
## Local input and direct top-down physics movement; independent of world/items.

@export_range(0.0, 2000.0, 1.0, "or_greater") var move_speed: float = 220.0
var _control_enabled := true


func _physics_process(_delta: float) -> void:
	if not _control_enabled:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var direction := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	velocity = calculate_velocity(direction, move_speed)
	# CharacterBody2D applies the physics timestep itself; velocity is pixels/sec.
	move_and_slide()


static func calculate_velocity(direction: Vector2, speed: float) -> Vector2:
	return direction.limit_length(1.0) * maxf(speed, 0.0)


func try_pickup_world_item(world_item: Variant) -> bool:
	var inventory_component := get_node_or_null("PlayerInventoryComponent")
	if inventory_component == null:
		return false
	return inventory_component.try_pickup_world_item(world_item)


func set_active_container(container: Variant) -> bool:
	var access_component := get_node_or_null("ContainerAccessComponent")
	if access_component == null:
		return false
	return access_component.set_active_container(container)


func set_control_enabled(enabled: bool) -> void:
	_control_enabled = enabled
	if not enabled:
		velocity = Vector2.ZERO
	set_physics_process(true)


func is_control_enabled() -> bool:
	return _control_enabled


func get_damage_receiver() -> DamageReceiver:
	return get_node_or_null("PlayerDamageReceiver") as DamageReceiver


func get_melee_damage() -> float:
	var melee := get_node_or_null("PlayerMeleeComponent")
	return melee.get_current_melee_damage() if melee != null else 0.0
