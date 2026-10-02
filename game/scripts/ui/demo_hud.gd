extends CanvasLayer
## Compact playable-demo HUD for status, inventory/container transfers and treatment.

const TransferScript := preload("res://scripts/inventory/inventory_transfer.gd")
const ConsumableServiceScript := preload("res://scripts/consumables/consumable_use_service.gd")
const TreatmentServiceScript := preload("res://scripts/medical/treatment_service.gd")

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
var _selected_instance_id := ""
var _selected_wound_id := ""
var _inventory_open := false
var _refresh_timer := 0.0
var _transfer := TransferScript.new()
var _consumable_service
var _treatment_service


func _ready() -> void:
	world = get_parent()
	player = world.get_node_or_null("Player")
	if player == null:
		push_error("[DemoHUD] Player is required")
		return
	_consumable_service = ConsumableServiceScript.new(DataRegistry)
	_treatment_service = TreatmentServiceScript.new(DataRegistry)
	_build_ui()
	_update_status()


func _process(delta: float) -> void:
	if player == null:
		return
	_update_status()
	var interaction = player.get_node_or_null("InteractionComponent")
	var prompt: String = interaction.get_current_prompt() if interaction != null else ""
	if prompt.is_empty():
		prompt = ""
	prompt_label.text = prompt
	var access = player.get_node_or_null("ContainerAccessComponent")
	var has_container: bool = access != null and access.get_active_container() != null
	panel.visible = _inventory_open or has_container
	if panel.visible:
		_refresh_timer -= delta
		if _refresh_timer <= 0.0:
			_refresh_timer = 0.35
			_refresh_lists()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_TAB:
			_inventory_open = not _inventory_open
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
		KEY_R:
			var ranged := player.get_node_or_null("RangedWeaponComponent")
			if ranged != null:
				_set_message("Shot fired" if ranged.fire() else "No shot: equip a loaded ranged weapon")
		KEY_Q:
			var reload = player.get_node_or_null("RangedWeaponComponent")
			if reload != null:
				_set_message("Weapon reloaded" if reload.reload() else "No compatible ammunition")


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
	help_label = Label.new()
	help_label.anchor_top = 1.0
	help_label.anchor_bottom = 1.0
	help_label.position = Vector2(16, -56)
	help_label.size = Vector2(860, 44)
	help_label.text = "WASD Move   E Interact   Space Melee   R Fire   Q Reload   Tab Inventory   C Use   T Treat   G Drop"
	help_label.add_theme_font_size_override("font_size", 14)
	root.add_child(help_label)
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
	_add_action(actions, "Use (C)", _use_selected_item)
	_add_action(actions, "Equip Hands", _equip_selected_item)
	_add_action(actions, "Store Selected", _store_selected_item)
	_add_action(actions, "Treat (T)", _treat_selected_wound)
	_add_action(actions, "Drop (G)", _drop_selected_item)
	message_label = Label.new()
	columns.add_child(message_label)


func _section_label(value: String) -> Label:
	var label := Label.new()
	label.text = value
	return label


func _add_action(parent: HBoxContainer, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)


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


func _fill_item_list(list: VBoxContainer, inventory, is_player: bool) -> void:
	for child in list.get_children():
		child.free()
	if inventory == null:
		list.add_child(_section_label("—"))
		return
	for item in inventory.get_all_items():
		var definition = item.get_definition()
		var button := Button.new()
		button.text = "%s  ·  %.2f kg" % [definition.name if definition != null else item.definition_id, definition.mass if definition != null else 0.0]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_select_player_item.bind(item.instance_id) if is_player else _transfer_from_container.bind(item.instance_id))
		list.add_child(button)
	if is_player:
		var weight := Label.new()
		weight.text = "Carried mass: %.2f kg" % inventory.get_total_weight()
		list.add_child(weight)


func _fill_wounds() -> void:
	for child in wounds_list.get_children():
		child.free()
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
		var injury = player.get_node("InjuryComponent").get_injury(wound.wound_id)
		var injury_label := " · pain %.0f%s" % [injury.get_pain(), " · fracture" if injury.is_fracture() else ""] if injury != null else ""
		button.text = "%s · bleed %.2f · inf %.1f%s" % [wound.wound_id.substr(0, 8), wound.get_bleeding_rate_per_game_hour(), infection_level, injury_label]
		button.pressed.connect(func() -> void: _selected_wound_id = wound.wound_id; _refresh_lists())
		wounds_list.add_child(button)
		if _selected_wound_id.is_empty():
			_selected_wound_id = wound.wound_id


func _select_player_item(instance_id: String) -> void:
	_selected_instance_id = instance_id
	_refresh_lists()


func _transfer_from_container(instance_id: String) -> void:
	var access = player.get_node("ContainerAccessComponent")
	var container = access.get_active_container()
	if container == null:
		return
	var inventory = player.get_node("PlayerInventoryComponent").get_inventory()
	if _transfer.transfer_item(container.get_inventory(), inventory, instance_id):
		_set_message("Item moved into pack")
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
	else:
		_set_message("Cannot use item: %s" % "; ".join(_consumable_service.get_errors()))
	_refresh_lists()


func _equip_selected_item() -> void:
	if player.get_node("EquipmentComponent").equip_item(&"hands", _selected_instance_id):
		_set_message("Item equipped in Hands")
	else:
		_set_message("Selected item cannot be equipped in Hands")


func _treat_selected_wound() -> void:
	var inventory = player.get_node("PlayerInventoryComponent").get_inventory()
	var wounds = player.get_node("WoundComponent")
	var infections = player.get_node("InfectionComponent")
	if _treatment_service.treat_wound(inventory, wounds, _selected_instance_id, _selected_wound_id, infections):
		_set_message("Wound treated")
		_selected_instance_id = ""
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
	var ranged_status := ""
	if hands_id == ranged.equipped_instance_id and not hands_id.is_empty():
		ranged_status = "   AMMO %d/%d" % [ranged.get_loaded_ammo(), ranged.get_magazine_capacity()]
	status_label.text = "HEALTH %5.1f   HUNGER %5.1f   THIRST %5.1f   MOBILITY %3d%%%s   SEED %d" % [
		state.get_health(), state.get_hunger(), state.get_thirst(), roundi(injuries.get_movement_multiplier() * 100.0), ranged_status, world.world_seed]
	if world.has_won():
		prompt_label.text = "EXTRACTION COMPLETE · Safe zone reached"


func _set_message(value: String) -> void:
	message_label.text = value
	message_label.visible = true
