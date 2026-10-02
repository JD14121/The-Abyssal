extends Node
## Converts Player Health depletion into a one-time gameplay shutdown.

signal defeated

var _defeated := false


func _ready() -> void:
	var player := get_parent()
	if player == null:
		push_error("[PlayerDefeatComponent] Missing Player parent")
		return
	var receiver = player.get_node_or_null("PlayerDamageReceiver")
	if receiver == null or not receiver.has_signal("health_depleted"):
		push_error("[PlayerDefeatComponent] PlayerDamageReceiver health_depleted signal is unavailable")
		return
	if not receiver.health_depleted.is_connected(handle_health_depleted):
		receiver.health_depleted.connect(handle_health_depleted)
	if receiver.is_depleted():
		handle_health_depleted()


func handle_health_depleted() -> void:
	if _defeated:
		return
	_defeated = true
	var player := get_parent()
	if player == null:
		push_error("[PlayerDefeatComponent] Cannot defeat Player without its parent")
		return
	var controller = player
	if controller.has_method("set_control_enabled"):
		controller.set_control_enabled(false)
	var melee = player.get_node_or_null("PlayerMeleeComponent")
	if melee != null and melee.has_method("set_combat_enabled"):
		melee.set_combat_enabled(false)
	var interaction = player.get_node_or_null("InteractionComponent")
	if interaction != null and interaction.has_method("set_interaction_enabled"):
		interaction.set_interaction_enabled(false)
	var container_access = player.get_node_or_null("ContainerAccessComponent")
	if container_access != null and container_access.has_method("clear_active_container"):
		container_access.clear_active_container()
	defeated.emit()


func is_defeated() -> bool:
	return _defeated
