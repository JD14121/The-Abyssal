extends CanvasLayer
## Playable-demo HUD and event-driven, step-by-step survival tutorial.

signal tutorial_safety_released

const TransferScript := preload("res://scripts/inventory/inventory_transfer.gd")
const ConsumableServiceScript := preload("res://scripts/consumables/consumable_use_service.gd")
const TreatmentServiceScript := preload("res://scripts/medical/treatment_service.gd")
const TUTORIAL_POINTER_SCRIPT := preload("res://scripts/ui/tutorial_pointer.gd")

const TUTORIAL_STEPS := [
	{"title": "1 / 10 - Move"},
	{"title": "2 / 10 - Buildings"},
	{"title": "3 / 10 - Search"},
	{"title": "4 / 10 - Transfer"},
	{"title": "5 / 10 - Supplies"},
	{"title": "6 / 10 - Equip"},
	{"title": "7 / 10 - Melee"},
	{"title": "8 / 10 - Ranged"},
	{"title": "9 / 10 - Treatment"},
	{"title": "10 / 10 - Exit"}
]

const TUTORIAL_ACTION_HINTS := [
	"MOVE: WASD",
	"DOOR: E  -  WINDOW: SPACE",
	"SEARCH: E",
	"TRANSFER: CLICK ITEM",
	"USE: C",
	"EQUIP: TAB - HANDS",
	"ATTACK: SPACE",
	"LOAD: Q - FIRE: R",
	"TREAT: T",
	"EXIT: E"
]

var player: CharacterBody2D
var world: Node2D
var status_label: Label
var prompt_label: Label
var help_label: Label
var panel: PanelContainer
var player_items: VBoxContainer
var container_items: VBoxContainer
var wounds_list: HBoxContainer
var selected_label: Label
var message_label: Label
var combat_feedback_label: Label
var action_hint_label: Label
var tutorial_pointer: Control
var tutorial_panel: PanelContainer
var tutorial_title: Label
var tutorial_reopen_button: Button
var tutorial_skip_guide_button: Button
var use_action_button: Button
var equip_action_button: Button
var treat_action_button: Button
var death_overlay: ColorRect
var death_retry_button: Button
var _player_item_buttons: Dictionary = {}
var _selected_instance_id := ""
var _selected_wound_id := ""
var _inventory_open := false
var _refresh_timer := 0.0
var _transfer := TransferScript.new()
var _consumable_service
var _treatment_service
var _tutorial_index := 0
var _tutorial_origin := Vector2.ZERO
var _tutorial_hidden := false
var _tutorial_finished := false
var _tutorial_safety_released := false
var _combat_feedback_remaining := 0.0
var _player_is_dead := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	world = get_parent()
	player = world.get_node_or_null("Player")
	if player == null:
		push_error("[DemoHUD] Player is required")
		return
	_consumable_service = ConsumableServiceScript.new(DataRegistry)
	_treatment_service = TreatmentServiceScript.new(DataRegistry)
	_tutorial_origin = player.global_position
	_build_ui()
	player.get_node("InteractionComponent").interaction_completed.connect(_on_interaction_completed)
	player.get_node("PlayerMeleeComponent").attack_landed.connect(_on_melee_attack_landed)
	player.get_node("PlayerInventoryComponent").item_picked_up.connect(_on_item_picked_up)
	player.get_node("PlayerDefeatComponent").defeated.connect(_on_player_defeated)
	_update_status()


func _process(delta: float) -> void:
	if player == null:
		return
	_combat_feedback_remaining = maxf(_combat_feedback_remaining - delta, 0.0)
	combat_feedback_label.visible = _combat_feedback_remaining > 0.0
	_update_status()
	if _tutorial_index == 0 and player.global_position.distance_to(_tutorial_origin) >= 72.0:
		_advance_tutorial()
	if _tutorial_index == 2:
		var access = player.get_node("ContainerAccessComponent")
		if access.get_active_container() != null:
			_advance_tutorial()
	if world.has_won() and _tutorial_index == 9:
		_finish_tutorial()
	var interaction = player.get_node_or_null("InteractionComponent")
	var prompt: String = interaction.get_current_prompt() if interaction != null else ""
	var melee_tutorial_active: bool = _tutorial_index == 6
	prompt_label.text = "[E / LEFT CLICK] %s" % prompt if not prompt.is_empty() and not melee_tutorial_active else ""
	var access = player.get_node_or_null("ContainerAccessComponent")
	var has_container: bool = access != null and access.get_active_container() != null
	panel.visible = _inventory_open or has_container
	_update_tutorial_pointer()
	if panel.visible:
		_refresh_timer -= delta
		if _refresh_timer <= 0.0:
			_refresh_timer = 0.5
			_fill_wounds()


func _unhandled_input(event: InputEvent) -> void:
	if _player_is_dead:
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_H:
			_set_tutorial_hidden(not _tutorial_hidden)
		KEY_TAB:
			_inventory_open = not _inventory_open
			get_tree().paused = _inventory_open
			GameClock.set_paused(_inventory_open)
			player.set_control_enabled(not _inventory_open)
			player.get_node("InteractionComponent").set_interaction_enabled(not _inventory_open)
			player.get_node("PlayerMeleeComponent").set_combat_enabled(not _inventory_open)
			if not _inventory_open:
				player.get_node("ContainerAccessComponent").clear_active_container()
			_refresh_lists()
			get_viewport().set_input_as_handled()
		KEY_C:
			_use_selected_item()
		KEY_T:
			_treat_selected_wound()
		KEY_G:
			_drop_selected_item()
		KEY_X:
			_unequip_hands()
		KEY_R:
			var ranged := player.get_node_or_null("RangedWeaponComponent")
			if ranged != null:
				var fired: bool = ranged.fire()
				_set_message("Shot fired" if fired else "No shot: equip a loaded ranged weapon")
				if fired and _tutorial_index == 7:
					_advance_tutorial()
					_release_tutorial_safety()
		KEY_Q:
			var reload = player.get_node_or_null("RangedWeaponComponent")
			if reload != null:
				var reloaded: bool = reload.reload()
				_set_message("Weapon reloaded" if reloaded else "No compatible ammunition")
				if reloaded:
					_refresh_lists()


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	status_label = Label.new()
	status_label.position = Vector2(16, 12)
	status_label.add_theme_font_size_override("font_size", 16)
	root.add_child(status_label)
	prompt_label = Label.new()
	prompt_label.anchor_left = 0.5
	prompt_label.anchor_right = 0.5
	prompt_label.position = Vector2(-160, 42)
	prompt_label.size = Vector2(320, 30)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 18)
	root.add_child(prompt_label)
	combat_feedback_label = Label.new()
	combat_feedback_label.anchor_left = 0.5
	combat_feedback_label.anchor_right = 0.5
	combat_feedback_label.position = Vector2(-220, 78)
	combat_feedback_label.size = Vector2(440, 34)
	combat_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combat_feedback_label.add_theme_font_size_override("font_size", 20)
	combat_feedback_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_feedback_label.visible = false
	root.add_child(combat_feedback_label)
	help_label = Label.new()
	help_label.anchor_top = 1.0
	help_label.anchor_bottom = 1.0
	help_label.position = Vector2(16, -56)
	help_label.size = Vector2(1150, 44)
	help_label.text = "WASD Move   E Interact   Space Attack   Tab Pack   H Guide"
	help_label.add_theme_font_size_override("font_size", 13)
	root.add_child(help_label)
	var hint_panel := PanelContainer.new()
	hint_panel.anchor_left = 0.5
	hint_panel.anchor_right = 0.5
	hint_panel.anchor_top = 1.0
	hint_panel.anchor_bottom = 1.0
	hint_panel.offset_left = -170
	hint_panel.offset_top = -102
	hint_panel.offset_right = 170
	hint_panel.offset_bottom = -68
	var hint_style := StyleBoxFlat.new()
	hint_style.bg_color = Color("202820")
	hint_style.border_color = Color("b89d54")
	hint_style.set_border_width_all(2)
	hint_style.set_corner_radius_all(3)
	hint_style.content_margin_left = 12.0
	hint_style.content_margin_right = 12.0
	hint_style.content_margin_top = 5.0
	hint_style.content_margin_bottom = 5.0
	hint_panel.add_theme_stylebox_override("panel", hint_style)
	root.add_child(hint_panel)
	action_hint_label = Label.new()
	action_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_hint_label.add_theme_font_size_override("font_size", 16)
	action_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_panel.add_child(action_hint_label)
	tutorial_panel = PanelContainer.new()
	tutorial_panel.offset_left = 16
	tutorial_panel.offset_top = 48
	tutorial_panel.offset_right = 278
	tutorial_panel.offset_bottom = 90
	var tutorial_style := StyleBoxFlat.new()
	tutorial_style.bg_color = Color("202820")
	tutorial_style.border_color = Color("b89d54")
	tutorial_style.set_border_width_all(2)
	tutorial_style.set_corner_radius_all(3)
	tutorial_style.content_margin_left = 8.0
	tutorial_style.content_margin_right = 8.0
	tutorial_style.content_margin_top = 3.0
	tutorial_style.content_margin_bottom = 3.0
	tutorial_panel.add_theme_stylebox_override("panel", tutorial_style)
	root.add_child(tutorial_panel)
	var tutorial_content := HBoxContainer.new()
	tutorial_panel.add_child(tutorial_content)
	tutorial_title = Label.new()
	tutorial_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tutorial_title.add_theme_font_size_override("font_size", 14)
	tutorial_content.add_child(tutorial_title)
	tutorial_skip_guide_button = Button.new()
	tutorial_skip_guide_button.text = "End"
	tutorial_skip_guide_button.focus_mode = Control.FOCUS_NONE
	tutorial_skip_guide_button.mouse_filter = Control.MOUSE_FILTER_STOP
	tutorial_skip_guide_button.custom_minimum_size = Vector2(48.0, 28.0)
	tutorial_skip_guide_button.pressed.connect(_finish_tutorial)
	tutorial_content.add_child(tutorial_skip_guide_button)
	tutorial_reopen_button = Button.new()
	tutorial_reopen_button.text = "Show Guide (H)"
	tutorial_reopen_button.focus_mode = Control.FOCUS_NONE
	tutorial_reopen_button.mouse_filter = Control.MOUSE_FILTER_STOP
	tutorial_reopen_button.offset_left = 16
	tutorial_reopen_button.offset_top = 72
	tutorial_reopen_button.offset_right = 164
	tutorial_reopen_button.offset_bottom = 108
	tutorial_reopen_button.pressed.connect(func() -> void: _set_tutorial_hidden(false))
	tutorial_reopen_button.visible = false
	root.add_child(tutorial_reopen_button)
	_update_tutorial_card()
	panel = PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -390
	panel.offset_top = -255
	panel.offset_right = 390
	panel.offset_bottom = 255
	panel.visible = false
	root.add_child(panel)
	var columns := VBoxContainer.new()
	panel.add_child(columns)
	var title := Label.new()
	title.text = "FIELD INVENTORY  ·  Click an item to select; E opens nearby furniture"
	title.add_theme_font_size_override("font_size", 18)
	columns.add_child(title)
	var split := HBoxContainer.new()
	columns.add_child(split)
	var player_box := VBoxContainer.new()
	player_box.custom_minimum_size.x = 350
	player_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(player_box)
	player_box.add_child(_section_label("PLAYER PACK"))
	var player_scroll := ScrollContainer.new()
	player_scroll.custom_minimum_size = Vector2(340, 250)
	player_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	player_box.add_child(player_scroll)
	player_items = VBoxContainer.new()
	player_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_scroll.add_child(player_items)
	var container_box := VBoxContainer.new()
	container_box.custom_minimum_size.x = 350
	container_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(container_box)
	container_box.add_child(_section_label("NEARBY CONTAINER"))
	var container_scroll := ScrollContainer.new()
	container_scroll.custom_minimum_size = Vector2(340, 250)
	container_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container_box.add_child(container_scroll)
	container_items = VBoxContainer.new()
	container_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container_scroll.add_child(container_items)
	columns.add_child(_section_label("WOUNDS · Select one, then press T with matching medical supplies"))
	wounds_list = HBoxContainer.new()
	columns.add_child(wounds_list)
	selected_label = Label.new()
	columns.add_child(selected_label)
	var actions := HBoxContainer.new()
	columns.add_child(actions)
	use_action_button = _add_action(actions, "Use (C)", _use_selected_item)
	equip_action_button = _add_action(actions, "Equip Hands", _equip_selected_item)
	_add_action(actions, "Store Selected", _store_selected_item)
	treat_action_button = _add_action(actions, "Treat (T)", _treat_selected_wound)
	_add_action(actions, "Drop (G)", _drop_selected_item)
	_add_action(actions, "Unequip (X)", _unequip_hands)
	message_label = Label.new()
	columns.add_child(message_label)
	_build_death_overlay(root)
	_build_tutorial_pointer(root)


func _section_label(value: String) -> Label:
	var label := Label.new()
	label.text = value
	return label


func _add_action(parent: HBoxContainer, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _build_tutorial_pointer(root: Control) -> void:
	tutorial_pointer = Control.new()
	tutorial_pointer.set_script(TUTORIAL_POINTER_SCRIPT)
	tutorial_pointer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tutorial_pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tutorial_pointer.z_index = 100
	root.add_child(tutorial_pointer)
	_update_tutorial_pointer()


func _build_death_overlay(root: Control) -> void:
	death_overlay = ColorRect.new()
	death_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	death_overlay.color = Color(0.035, 0.045, 0.04, 0.90)
	death_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	death_overlay.z_index = 200
	death_overlay.visible = false
	root.add_child(death_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_STOP
	death_overlay.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(430, 235)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color("222923")
	card_style.border_color = Color("8e4944")
	card_style.set_border_width_all(3)
	card_style.set_corner_radius_all(3)
	card_style.content_margin_left = 34.0
	card_style.content_margin_right = 34.0
	card_style.content_margin_top = 26.0
	card_style.content_margin_bottom = 26.0
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)
	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 16)
	card.add_child(content)
	var title := Label.new()
	title.text = "YOU ARE DEAD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color("d87868"))
	content.add_child(title)
	var description := Label.new()
	description.text = "Your survival ends here."
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.add_theme_font_size_override("font_size", 17)
	content.add_child(description)
	death_retry_button = Button.new()
	death_retry_button.text = "Retry"
	death_retry_button.custom_minimum_size = Vector2(160, 42)
	death_retry_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	death_retry_button.pressed.connect(_retry_demo)
	content.add_child(death_retry_button)


func _update_tutorial_pointer() -> void:
	if tutorial_pointer == null or not is_instance_valid(tutorial_pointer):
		return
	if _tutorial_finished:
		tutorial_pointer.call("set_target", null)
		return
	if _tutorial_hidden:
		tutorial_panel.visible = false
		tutorial_pointer.call("set_target", null)
		return
	# Keep prose out of the modal inventory surface; the pointer still marks the
	# visible item row or action button the player needs next.
	var container_access = player.get_node_or_null("ContainerAccessComponent")
	var container_open: bool = container_access != null and container_access.get_active_container() != null
	tutorial_panel.visible = not _tutorial_hidden and not _inventory_open and not container_open
	var target: Control = action_hint_label
	match _tutorial_index:
		1:
			var prompt_is_building: bool = prompt_label.text.contains("Door") or prompt_label.text.contains("Window")
			target = prompt_label if prompt_is_building else action_hint_label
		2:
			var prompt_is_container: bool = prompt_label.text.contains("Container") or prompt_label.text.contains("Cupboard") or prompt_label.text.contains("Shelf")
			target = prompt_label if prompt_is_container else action_hint_label
		9:
			var prompt_is_exit: bool = prompt_label.text.contains("Exit") or prompt_label.text.contains("Extraction")
			target = prompt_label if prompt_is_exit else action_hint_label
		3:
			target = container_items
		4:
			target = use_action_button if _selected_item_is_consumable() else player_items
		5:
			target = equip_action_button if not _selected_instance_id.is_empty() else player_items
		7:
			target = _get_ranged_lesson_target()
		8:
			if _selected_wound_id.is_empty():
				target = wounds_list
			elif _selected_instance_id.is_empty():
				target = player_items
			else:
				target = treat_action_button
	if not target.is_visible_in_tree():
		target = action_hint_label
	tutorial_pointer.call("set_target", target)


func _selected_item_is_consumable() -> bool:
	var inventory = player.get_node("PlayerInventoryComponent").get_inventory()
	if not inventory.has_item(_selected_instance_id):
		return false
	var item = inventory.get_item(_selected_instance_id)
	return DataRegistry.get_consumable_for_item(item.definition_id) != null


func _get_ranged_lesson_target() -> Control:
	var equipment = player.get_node("EquipmentComponent")
	var inventory = player.get_node("PlayerInventoryComponent").get_inventory()
	var equipped_id: String = equipment.get_equipped_instance_id(&"hands")
	if inventory.has_item(equipped_id) and inventory.get_item(equipped_id).definition_id == &"pipe_pistol":
		return action_hint_label
	if inventory.has_item(_selected_instance_id) and inventory.get_item(_selected_instance_id).definition_id == &"pipe_pistol":
		return equip_action_button
	for instance_id: String in _player_item_buttons:
		var item = inventory.get_item(instance_id)
		if item != null and item.definition_id == &"pipe_pistol":
			return _player_item_buttons[instance_id]
	return player_items


func _refresh_lists() -> void:
	if player == null:
		return
	var inventory = player.get_node("PlayerInventoryComponent").get_inventory()
	_fill_item_list(player_items, inventory, true)
	var access = player.get_node("ContainerAccessComponent")
	var active = access.get_active_container()
	_fill_item_list(container_items, active.get_inventory() if active != null else null, false)
	_fill_wounds()
	var selected = inventory.get_item(_selected_instance_id) if inventory.has_item(_selected_instance_id) else null
	selected_label.text = "Selected: %s" % (selected.get_definition().name if selected != null else "none")
	_update_tutorial_pointer()


func _fill_item_list(list: VBoxContainer, inventory, is_player: bool) -> void:
	for child in list.get_children():
		child.queue_free()
	if is_player:
		_player_item_buttons.clear()
	if inventory == null:
		list.add_child(_section_label("—"))
		return
	for item in inventory.get_all_items():
		var definition = item.get_definition()
		var button := Button.new()
		var selected_item: bool = is_player and item.instance_id == _selected_instance_id
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.tooltip_text = "Click to select this item" if is_player else "Click to transfer this item into your pack"
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = "%s  ·  %.2f kg" % [definition.name if definition != null else item.definition_id, definition.mass if definition != null else 0.0]
		button.set_meta("base_text", button.text)
		if selected_item:
			button.text = "▶ " + button.text
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_select_player_item.bind(item.instance_id) if is_player else _transfer_from_container.bind(item.instance_id))
		list.add_child(button)
		if is_player:
			_player_item_buttons[item.instance_id] = button
	if is_player:
		var weight := Label.new()
		weight.text = "Carried mass: %.2f kg" % inventory.get_total_weight()
		list.add_child(weight)


func _fill_wounds() -> void:
	for child in wounds_list.get_children():
		child.queue_free()
	var wounds = player.get_node("WoundComponent").get_wounds()
	var infections = player.get_node("InfectionComponent")
	if wounds.is_empty():
		wounds_list.add_child(_section_label("No wounds"))
		_selected_wound_id = ""
		return
	for wound in wounds:
		var infection = infections.get_infection(wound.wound_id)
		var infection_level: float = infection.get_level() if infection != null else 0.0
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var injury = player.get_node("InjuryComponent").get_injury(wound.wound_id)
		var injury_label := " · pain %.0f%s" % [injury.get_pain(), " · fracture" if injury.is_fracture() else ""] if injury != null else ""
		button.text = "%s · bleed %.2f · inf %.1f%s" % [wound.wound_id.substr(0, 8), wound.get_bleeding_rate_per_game_hour(), infection_level, injury_label]
		button.pressed.connect(_select_wound.bind(wound.wound_id))
		wounds_list.add_child(button)
		if _selected_wound_id.is_empty():
			_selected_wound_id = wound.wound_id


func _select_player_item(instance_id: String) -> void:
	if not _player_item_buttons.has(instance_id):
		return
	var previous_id := _selected_instance_id
	_selected_instance_id = instance_id
	if _player_item_buttons.has(previous_id):
		var previous_button: Button = _player_item_buttons[previous_id]
		previous_button.text = str(previous_button.get_meta("base_text", previous_button.text))
	var selected_button: Button = _player_item_buttons[instance_id]
	selected_button.text = "▶ " + str(selected_button.get_meta("base_text", selected_button.text))
	var inventory = player.get_node("PlayerInventoryComponent").get_inventory()
	var selected = inventory.get_item(instance_id)
	selected_label.text = "Selected: %s" % (selected.get_definition().name if selected != null else "none")
	_update_tutorial_pointer()


func _select_wound(wound_id: String) -> void:
	_selected_wound_id = wound_id
	_fill_wounds()
	_update_tutorial_pointer()


func _on_interaction_completed(target: Interactable) -> void:
	if _tutorial_index == 1 and (target is DemoDoor or target is DemoWindow):
		_advance_tutorial()
	if target is WorldItem:
		_set_message("World item picked up. Open Tab to see it in your pack.")
	if target is WorldContainer:
		_refresh_lists()


func _on_item_picked_up(instance_id: String) -> void:
	var inventory = player.get_node("PlayerInventoryComponent").get_inventory()
	var item = inventory.get_item(instance_id)
	if item != null:
		_set_message("Picked up %s" % item.get_definition().name)
		_refresh_lists()


func _on_melee_attack_landed(target: Node2D) -> void:
	var receiver = target.get_damage_receiver() if target.has_method("get_damage_receiver") else null
	if receiver != null:
		if target is DemoWindow and receiver.is_depleted():
			_show_combat_feedback("WINDOW BROKEN")
		elif receiver.is_depleted():
			_show_combat_feedback("ZOMBIE KILLED")
		else:
			var target_name := "WINDOW" if target is DemoWindow else "ZOMBIE"
			_show_combat_feedback("%s HIT  ·  %d DAMAGE  ·  %d / %d HP" % [target_name,
				roundi(player.get_melee_damage()), roundi(receiver.get_current_health()), roundi(receiver.get_max_health())])
	if _tutorial_index == 6 and not target is DemoWindow and receiver != null and receiver.is_depleted():
		_advance_tutorial()
		_release_tutorial_safety()
	elif target is DemoWindow and _tutorial_index == 1:
		_advance_tutorial()


func _transfer_from_container(instance_id: String) -> void:
	var access = player.get_node("ContainerAccessComponent")
	var container = access.get_active_container()
	if container == null:
		return
	var inventory = player.get_node("PlayerInventoryComponent").get_inventory()
	if _transfer.transfer_item(container.get_inventory(), inventory, instance_id):
		_set_message("Item moved into pack")
		if _tutorial_index == 3:
			_advance_tutorial()
	else:
		_set_message("Transfer failed: %s" % "; ".join(_transfer.get_errors()))
	_refresh_lists()


func _transfer_to_container(instance_id: String) -> void:
	var access = player.get_node("ContainerAccessComponent")
	var container = access.get_active_container()
	if container == null:
		return
	var inventory = player.get_node("PlayerInventoryComponent").get_inventory()
	if _transfer.transfer_item(inventory, container.get_inventory(), instance_id):
		_set_message("Item stored")
	else:
		_set_message("Transfer failed: %s" % "; ".join(_transfer.get_errors()))
	_refresh_lists()


func _store_selected_item() -> void:
	if _selected_instance_id.is_empty():
		_set_message("Select an inventory item first")
		return
	_transfer_to_container(_selected_instance_id)


func _use_selected_item() -> void:
	var inventory = player.get_node("PlayerInventoryComponent").get_inventory()
	var state = player.get_node("SurvivalComponent").state
	if _consumable_service.use_item(inventory, state, _selected_instance_id):
		_set_message("Consumable used")
		_selected_instance_id = ""
		if _tutorial_index == 4:
			_advance_tutorial()
	else:
		_set_message("Cannot use item: %s" % "; ".join(_consumable_service.get_errors()))
	_refresh_lists()


func _equip_selected_item() -> void:
	if player.get_node("EquipmentComponent").equip_item(&"hands", _selected_instance_id):
		_set_message("Item equipped in Hands")
		if _tutorial_index == 5:
			_advance_tutorial()
	else:
		_set_message("Selected item cannot be equipped in Hands")


func _unequip_hands() -> void:
	var equipment = player.get_node("EquipmentComponent")
	var hands_id: String = equipment.get_equipped_instance_id(&"hands")
	if hands_id.is_empty():
		_set_message("Hands are already empty; Fists are ready")
		return
	if equipment.unequip(&"hands"):
		_set_message("Unequipped. Fists are ready")
		_refresh_lists()


func _treat_selected_wound() -> void:
	var inventory = player.get_node("PlayerInventoryComponent").get_inventory()
	var wounds = player.get_node("WoundComponent")
	var infections = player.get_node("InfectionComponent")
	if _treatment_service.treat_wound(inventory, wounds, _selected_instance_id, _selected_wound_id, infections):
		_set_message("Wound treated")
		_selected_instance_id = ""
		if _tutorial_index == 8:
			_advance_tutorial()
	else:
		_set_message("Treatment failed: %s" % "; ".join(_treatment_service.get_errors()))
	_refresh_lists()


func _drop_selected_item() -> void:
	var component = player.get_node("PlayerInventoryComponent")
	if component.drop_item(_selected_instance_id, world, player.global_position + player.get_facing_direction() * 40.0):
		_set_message("Item dropped")
		_selected_instance_id = ""
	else:
		_set_message("Drop failed")
	_refresh_lists()


func _update_status() -> void:
	if player == null:
		return
	var state = player.get_node("SurvivalComponent").state
	var injuries = player.get_node("InjuryComponent")
	var ranged := player.get_node("RangedWeaponComponent")
	var hands_id: String = player.get_node("EquipmentComponent").get_equipped_instance_id(&"hands")
	var hands_text := "FISTS"
	if not hands_id.is_empty():
		var item = player.get_node("PlayerInventoryComponent").get_inventory().get_item(hands_id)
		if item != null and item.get_definition() != null:
			hands_text = item.get_definition().name.to_upper()
	var ranged_status := "   HANDS %s" % hands_text
	if hands_id == ranged.equipped_instance_id and not hands_id.is_empty():
		ranged_status += "   AMMO %d/%d" % [ranged.get_loaded_ammo(), ranged.get_magazine_capacity()]
	status_label.text = "HEALTH %5.1f   HUNGER %5.1f   THIRST %5.1f   MOBILITY %3d%%%s   SEED %d" % [
		state.get_health(), state.get_hunger(), state.get_thirst(), roundi(injuries.get_movement_multiplier() * 100.0), ranged_status, world.world_seed]
	if world.has_won():
		prompt_label.text = "EXTRACTION COMPLETE · Safe zone reached"


func _set_message(value: String) -> void:
	message_label.text = value
	message_label.visible = true


func _show_combat_feedback(value: String) -> void:
	combat_feedback_label.text = value
	combat_feedback_label.visible = true
	_combat_feedback_remaining = 1.5


func _on_player_defeated() -> void:
	if _player_is_dead:
		return
	_player_is_dead = true
	get_tree().paused = true
	GameClock.set_paused(true)
	panel.visible = false
	tutorial_panel.visible = false
	tutorial_reopen_button.visible = false
	death_overlay.visible = true
	get_tree().paused = true
	death_retry_button.grab_focus()


func _retry_demo() -> void:
	get_tree().paused = false
	GameClock.set_paused(false)
	get_tree().reload_current_scene()


func _advance_tutorial() -> void:
	if _tutorial_finished:
		return
	_tutorial_index += 1
	if _tutorial_index >= TUTORIAL_STEPS.size():
		_finish_tutorial()
		return
	_update_tutorial_card()


func _finish_tutorial() -> void:
	if _tutorial_finished:
		return
	_tutorial_finished = true
	_release_tutorial_safety()
	tutorial_title.text = "Guide Complete"
	tutorial_skip_guide_button.visible = false
	tutorial_panel.visible = not _tutorial_hidden
	_update_tutorial_pointer()


func _release_tutorial_safety() -> void:
	if _tutorial_safety_released:
		return
	_tutorial_safety_released = true
	tutorial_safety_released.emit()


func _set_tutorial_hidden(hidden: bool) -> void:
	_tutorial_hidden = hidden
	if tutorial_panel != null:
		tutorial_panel.visible = not hidden
	if tutorial_reopen_button != null:
		tutorial_reopen_button.visible = hidden


func _update_tutorial_card() -> void:
	if _tutorial_finished or _tutorial_index >= TUTORIAL_STEPS.size():
		return
	var step: Dictionary = TUTORIAL_STEPS[_tutorial_index]
	tutorial_title.text = str(step["title"])
	action_hint_label.text = TUTORIAL_ACTION_HINTS[_tutorial_index]
	_set_tutorial_hidden(_tutorial_hidden)
	_update_tutorial_pointer()
