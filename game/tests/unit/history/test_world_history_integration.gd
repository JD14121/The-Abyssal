extends SceneTree
const Damage = preload("res://scripts/combat/damage_event.gd")
const Combat = preload("res://scripts/combat/combat_service.gd")
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; printerr("FAIL: "+message)
func run() -> void:
	check(ResourceLoader.exists("res://scripts/history/world_history_adapter.gd"),"world adapter exists")
	if failures: quit(1); return
	var world := Node2D.new()
	root.add_child(world)
	var adapter = load("res://scripts/history/world_history_adapter.gd").new()
	world.add_child(adapter)
	check(adapter.configure(world,root.get_node("GameClock"),"integration_world"),"adapter initializes")
	var player: Node2D = load("res://scenes/player/player.tscn").instantiate()
	world.add_child(player)
	await process_frame
	var knife = load("res://scripts/items/item_factory.gd").new(root.get_node("DataRegistry")).create(&"kitchen_knife")
	var inventory = player.get_node("PlayerInventoryComponent")
	inventory.get_inventory().add_item(knife)
	world.remove_child(player)
	world.add_child(player)
	await process_frame
	Combat.new().apply_damage_event(Damage.new(world,player,50.0))
	var events: Array = adapter.runtime.ledger.serialize().events
	check(events.size() == 2,"major wound and severe bleeding record once after wound creation, including scene re-entry")
	check(events[1].cause_event_ids == [events[0].event_id],"bleeding references its known wound cause")
	Combat.new().apply_damage_event(Damage.new(world,player,1000.0))
	var defeats: Array = []
	for event in adapter.runtime.ledger.serialize().events:
		if event.event_type == "character_defeat": defeats.append(event)
	check(defeats.size() == 1 and defeats[0].facts[0].value == "unknown","player defeat is not fabricated blood-loss death")
	check(adapter.runtime.graph.query_by_target("world_item",knife.instance_id).size() == 1,"important carried item becomes an evidence anchor")
	var memory_id: String = defeats[0].event_id+"_memory"
	var item_anchor: String = ""
	for anchor in adapter.runtime.graph.serialize().anchors:
		if anchor.target_ref.id == knife.instance_id: item_anchor = anchor.anchor_id
	check(inventory.drop_item(knife.instance_id,world,Vector2(120,90)),"existing drop completes")
	check(adapter.runtime.graph.get_anchor(item_anchor).last_known_location.position == [120,90],"drop notification updates evidence position after commit")
	var dropped: Node2D
	for child in world.get_children():
		if child is WorldItem: dropped = child
	check(inventory.try_pickup_world_item(dropped),"existing pickup completes")
	await process_frame
	check(adapter.runtime.graph.get_anchor(item_anchor).accessibility > 0,"picked-up relic remains accessible after world node is freed")
	var zombie: Node2D = load("res://scenes/creatures/zombie/zombie.tscn").instantiate()
	var death = load("res://scripts/lifecycle/creature_death_component.gd").new()
	death.name = "CreatureDeathComponent"
	death.corpse_scene = load("res://scenes/lifecycle/corpse.tscn")
	zombie.add_child(death)
	world.add_child(zombie)
	Combat.new().apply_damage_event(Damage.new(world,zombie,1000.0))
	var corpse: Node2D
	for child in world.get_children():
		if child is Corpse: corpse = child
	check(corpse != null,"existing lifecycle still creates corpse")
	var corpse_id: String = adapter.identity_for(corpse)
	check(adapter.runtime.graph.query_by_target("corpse",corpse_id).size() == 1,"completed death automatically binds stable corpse evidence")
	corpse.interact(player)
	check(not adapter.runtime.knowledge.query(adapter.identity_for(player)).is_empty(),"corpse inspection explicitly grants player knowledge")
	var truth: Dictionary = adapter.runtime.ledger.serialize()
	corpse.queue_free()
	await process_frame
	var corpse_anchor: Dictionary
	for anchor in adapter.runtime.graph.serialize().anchors:
		if anchor.target_ref.id == corpse_id: corpse_anchor = anchor
	check(corpse_anchor.available and corpse_anchor.accessibility == 0,"scene removal unloads evidence without claiming physical destruction")
	check(adapter.runtime.ledger.serialize() == truth,"unload does not erase history")
	var rematerialized: Node2D = load("res://scenes/lifecycle/corpse.tscn").instantiate()
	rematerialized.initialize(&"zombie_basic")
	world.add_child(rematerialized)
	check(adapter.bind_restored_identity(rematerialized,corpse_id),"restored scene can bind its existing persistent identity")
	check(adapter.runtime.graph.get_anchor(corpse_anchor.anchor_id).accessibility > 0 and adapter.runtime.ledger.serialize() == truth,"rematerialization restores access without inventing a second death")
	var duplicate: Node2D = load("res://scenes/lifecycle/corpse.tscn").instantiate()
	duplicate.initialize(&"zombie_basic")
	world.add_child(duplicate)
	check(not adapter.bind_restored_identity(duplicate,corpse_id),"two live nodes cannot bind the same persistent identity")
	duplicate.queue_free()
	check(adapter.notify_anchor_destroyed("corpse",corpse_id),"physical destruction has an explicit separate boundary")
	check(not adapter.runtime.graph.get_anchor(corpse_anchor.anchor_id).available,"explicit destruction invalidates medium")
	check(adapter.runtime.graph.get_memory(memory_id).memory_state != "lost","independent carried-item evidence survives other destruction")
	world.queue_free()
	await process_frame
	print("WorldHistoryIntegration: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
