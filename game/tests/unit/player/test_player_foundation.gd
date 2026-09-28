extends SceneTree
## Exercise the actual Input Map, Player scene, physics world and active camera.

const ACTIONS := [&"move_left", &"move_right", &"move_up", &"move_down"]
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	if not FileAccess.file_exists("res://scenes/world/test_world.tscn"):
		check(false, "Player test world must support input, collision and camera follow")
		_finish()
		return
	var controller = load("res://scripts/player/player_controller.gd")
	if controller == null or not controller.can_instantiate():
		check(false, "player controller compiles")
		_finish()
		return
	check(controller.calculate_velocity(Vector2.ZERO, 220.0) == Vector2.ZERO, "zero input")
	check(controller.calculate_velocity(Vector2.RIGHT, 220.0) == Vector2(220.0, 0.0), "right velocity")
	check(controller.calculate_velocity(Vector2.UP, 220.0) == Vector2(0.0, -220.0), "up velocity")
	check(is_equal_approx(controller.calculate_velocity(Vector2(1, 1), 220.0).length(), 220.0), "diagonal speed normalized")
	check(controller.calculate_velocity(Vector2.LEFT, 100.0) == Vector2(-100.0, 0.0), "configurable speed calculation")
	check(controller.calculate_velocity(Vector2(0.5, 0), 220.0) == Vector2(110.0, 0), "analog magnitude retained")
	for action in ACTIONS:
		check(InputMap.has_action(action), "Input Map includes " + String(action))
	var mappings := {KEY_W: &"move_up", KEY_S: &"move_down", KEY_A: &"move_left", KEY_D: &"move_right", KEY_UP: &"move_up", KEY_DOWN: &"move_down", KEY_LEFT: &"move_left", KEY_RIGHT: &"move_right"}
	for key in mappings:
		_key(key, true)
		check(Input.is_action_pressed(mappings[key]), "key event activates " + String(mappings[key]))
		_key(key, false)
		check(not Input.is_action_pressed(mappings[key]), "released key releases action")
	var world_scene = load("res://scenes/world/test_world.tscn")
	var world = world_scene.instantiate()
	root.add_child(world)
	var player = world.get_node_or_null("Player")
	check(player is CharacterBody2D, "test world instantiates CharacterBody2D Player")
	if not player is CharacterBody2D:
		world.free()
		_finish()
		return
	check(player.get_node_or_null("Visual") is Polygon2D and player.get_node("Visual").visible, "visible placeholder")
	var collider = player.get_node_or_null("CollisionShape2D")
	check(collider is CollisionShape2D and collider.shape != null and not collider.disabled, "active player collision shape")
	var camera = player.get_node_or_null("Camera2D")
	check(camera is Camera2D and camera.enabled and not camera.position_smoothing_enabled, "enabled unsmoothed camera")
	await _frames(3)
	check(root.get_camera_2d() == camera, "player camera is active")
	check(world.find_children("*", "Camera2D", true, false).size() == 1, "one camera in test world")
	var start: Vector2 = player.position
	await _frames(8)
	check(player.position.is_equal_approx(start) and player.velocity == Vector2.ZERO, "no-input startup does not drift")
	for action in ACTIONS:
		await _place(player, Vector2(400, 220))
		Input.action_press(action)
		await _frames(15)
		var displacement: Vector2 = player.position - Vector2(400, 220)
		var expected: Vector2 = {&"move_left": Vector2.LEFT, &"move_right": Vector2.RIGHT, &"move_up": Vector2.UP, &"move_down": Vector2.DOWN}[action]
		check(displacement.dot(expected) > 40.0 and absf(displacement.cross(expected)) < 0.1, "actual movement " + String(action))
		check(is_equal_approx(player.velocity.length(), player.move_speed), "configured physical velocity")
		_release_actions()
	await _place(player, Vector2(400, 220))
	Input.action_press(&"move_right")
	Input.action_press(&"move_up")
	await _frames(15)
	check(is_equal_approx(player.velocity.length(), player.move_speed), "actual diagonal is not faster")
	_release_actions()
	await _frames(2)
	start = player.position
	await _frames(8)
	check(player.position.is_equal_approx(start) and player.velocity == Vector2.ZERO, "release stops immediately")
	for pair in [[&"move_left", &"move_right"], [&"move_up", &"move_down"], ACTIONS]:
		for action in pair:
			Input.action_press(action)
		await _frames(5)
		check(player.velocity == Vector2.ZERO and player.position.is_equal_approx(start), "opposite inputs cancel")
		_release_actions()
	var original_speed: float = player.move_speed
	player.move_speed = 100.0
	await _place(player, Vector2(400, 220))
	Input.action_press(&"move_right")
	await _frames(30)
	check(is_equal_approx(player.velocity.x, 100.0) and absf(player.position.x - 450.0) < 4.0, "configured speed affects actual distance")
	_release_actions()
	player.move_speed = original_speed
	var original_ticks: int = Engine.physics_ticks_per_second
	for ticks in [60, 120]:
		Engine.physics_ticks_per_second = ticks
		await _place(player, Vector2(400, 220))
		Input.action_press(&"move_right")
		await _frames(int(ticks / 2.0))
		check(absf(player.position.x - 510.0) < 6.0, "half-second distance at %d physics ticks" % ticks)
		_release_actions()
	Engine.physics_ticks_per_second = original_ticks
	# Collide with the left face of the tall internal obstacle (x = 820).
	await _place(player, Vector2(700, 480))
	Input.action_press(&"move_right")
	await _frames(60)
	check(absf(player.position.x - 804.0) < 1.0 and player.get_slide_collision_count() > 0, "cannot pass through internal obstacle")
	start = player.position
	Input.action_press(&"move_down")
	await _frames(15)
	check(absf(player.position.x - 804.0) < 1.0 and player.position.y > start.y + 20.0, "diagonal input slides along wall")
	await _frames(60)
	check(player.position.x > 830.0 and player.position.y > 616.0, "can move around obstacle corner")
	_release_actions()
	# Check every map edge in clear corridors, independently of the obstacles.
	var edges := [
		[Vector2(100, 140), &"move_left", 0, 48.0],
		[Vector2(1500, 140), &"move_right", 0, 1552.0],
		[Vector2(1450, 100), &"move_up", 1, 48.0],
		[Vector2(1450, 900), &"move_down", 1, 952.0],
	]
	for edge in edges:
		await _place(player, edge[0])
		Input.action_press(edge[1])
		await _frames(60)
		check(absf(player.position[edge[2]] - edge[3]) < 1.0, "boundary collision " + String(edge[1]))
		_release_actions()
	await _place(player, Vector2(400, 650))
	Input.action_press(&"move_down")
	await _frames(60)
	check(absf(player.position.y - 712.0) < 1.0, "wide obstacle collision")
	_release_actions()
	await _place(player, Vector2(1100, 720))
	Input.action_press(&"move_right")
	await _frames(60)
	check(absf(player.position.x - 1186.0) < 1.0, "square obstacle collision")
	_release_actions()
	await _place(player, Vector2(400, 220))
	var camera_before: Vector2 = camera.get_screen_center_position()
	Input.action_press(&"move_right")
	await _frames(30)
	check(camera.get_screen_center_position().distance_to(player.global_position) < 1.0, "camera center follows moving player")
	check(camera.get_screen_center_position().x > camera_before.x + 90.0, "camera actually scrolls through world")
	_release_actions()
	await _place(player, Vector2(480, 360))
	if OS.get_cmdline_user_args().has("--capture"):
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var path := "user://player_foundation.png"
		check(image.save_png(path) == OK, "save visual verification image")
		print("Screenshot: " + ProjectSettings.globalize_path(path))
	world.free()
	_finish()


func _key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _release_actions() -> void:
	for action in ACTIONS:
		if InputMap.has_action(action):
			Input.action_release(action)


func _place(player: CharacterBody2D, position: Vector2) -> void:
	_release_actions()
	player.position = position
	player.velocity = Vector2.ZERO
	await _frames(3)


func _frames(count: int) -> void:
	for index in range(count):
		await physics_frame
	await process_frame


func _finish() -> void:
	_release_actions()
	print("Player foundation: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
