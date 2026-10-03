extends Node
## Scene boundary only. Canonical records contain stable IDs, never live Objects.
const Runtime = preload("res://scripts/history/world_history_runtime.gd")
const V = preload("res://scripts/history/record_validation.gd")
var runtime: RefCounted
var _world: WeakRef
var _clock: WeakRef
var _observer: WeakRef
var _carried: Dictionary = {}
var _bound: Dictionary = {}

func configure(world: Node, clock: Node, world_id: String) -> bool:
	if runtime != null or not is_instance_valid(world) or not world.is_inside_tree() or not is_instance_valid(clock) or not clock.has_method("get_elapsed_game_seconds"): return false
	var pending := Runtime.new()
	if not pending.initialize(world_id): push_error("[WorldHistory] "+str(pending.get_errors())); return false
	var registry := get_tree().root.get_node_or_null("DataRegistry")
	for item_id in pending.config.serialize().significant_item_ids:
		if registry == null or registry.get_item(StringName(item_id)) == null:
			push_error("[WorldHistory] Unresolved significant item: "+item_id)
			return false
	runtime = pending
	_world = weakref(world)
	_clock = weakref(clock)
	get_tree().node_added.connect(_on_node_added)
	_scan(world)
	return true

func identity_for(node: Node) -> String:
	if runtime == null or not is_instance_valid(node): return ""
	if not node.has_meta("history_entity_id"):
		node.set_meta("history_entity_id",runtime.next_id("entity"))
	return str(node.get_meta("history_entity_id"))

func bind_restored_identity(node: Node, stable_id: String) -> bool:
	if runtime == null or not is_instance_valid(node) or not V.identity(stable_id) or not node.is_inside_tree() or not _world.get_ref().is_ancestor_of(node): return false
	if node.has_meta("history_entity_id") and node.get_meta("history_entity_id") != stable_id: return false
	if runtime.ledger.query_by_actor(stable_id).is_empty() and runtime.graph.query_by_target("corpse",stable_id).is_empty(): return false
	var pending: Array = [_world.get_ref()]
	while not pending.is_empty():
		var candidate: Node = pending.pop_back()
		if candidate != node and candidate.get_meta("history_entity_id","") == stable_id: return false
		pending.append_array(candidate.get_children())
	node.set_meta("history_entity_id",stable_id)
	if node is Corpse:
		_set_target_access("corpse",stable_id,1.0)
		_bind_corpse(node)
	return true

func _bind_corpse(corpse: Node2D) -> void:
	var exiting := _set_target_access.bind("corpse",identity_for(corpse),0.0)
	if not corpse.tree_exiting.is_connected(exiting): corpse.tree_exiting.connect(exiting)
	if not corpse.inspected.is_connected(_on_corpse_inspected): corpse.inspected.connect(_on_corpse_inspected)

func _scan(node: Node) -> void:
	_on_node_added(node)
	for child in node.get_children(): _scan(child)

func _on_node_added(node: Node) -> void:
	if runtime == null or _world == null: return
	var world = _world.get_ref()
	if world == null or (node != world and not world.is_ancestor_of(node)): return
	var key := node.get_instance_id() # Ephemeral connection deduplication only; never serialized.
	if _bound.has(key): return
	_bound[key] = true
	node.tree_exiting.connect(_forget_binding.bind(key),CONNECT_ONE_SHOT)
	var actor := node.get_parent()
	if node.has_signal("corpse_spawned"):
		_connect_once(node,"corpse_spawned",_on_corpse_spawned.bind(weakref(actor)))
	if node.has_signal("defeated"):
		_observer = weakref(actor)
		_connect_once(node,"defeated",_on_defeated.bind(weakref(actor)))
	if node.has_signal("wound_created"):
		_connect_once(node,"wound_created",_on_wound_created.bind(weakref(actor)))
	if node.has_signal("item_dropped"):
		_connect_once(node,"item_dropped",_on_item_dropped)
		_connect_once(node,"item_picked_up",_on_item_picked_up.bind(weakref(actor)))
		_connect_once(actor,"tree_exiting",_on_carrier_exit.bind(weakref(actor)))
	if node is WorldItem: call_deferred("_bind_world_item",weakref(node))

func _forget_binding(key: int) -> void: _bound.erase(key)
func _connect_once(node: Node, signal_name: String, callback: Callable) -> void:
	for connection in node.get_signal_connection_list(signal_name):
		var existing: Callable = connection.callable
		if existing.get_object() == self and existing.get_method() == callback.get_method(): return
	node.connect(signal_name,callback)
func _now() -> float:
	var clock = _clock.get_ref()
	return clock.get_elapsed_game_seconds() if clock != null else 0.0
func _location(position: Vector2) -> Dictionary:
	return {"region_id":runtime.world_id,"area_id":"surface","position":[position.x,position.y]}
func _anchor(kind: String, target_id: String, profile_id: String, location: Dictionary) -> Dictionary:
	return {"anchor_id":runtime.next_id("anchor"),"anchor_type":kind,"target_ref":{"kind":kind,"id":target_id},"profile_id":profile_id,"memory_ids":[],"durability":1.0,"readability":1.0,"accessibility":1.0,"environmental_exposure":0.0,"available":true,"last_known_location":location}
func _event(actor: Node2D, event_type: String, facts: Array, objects: Array = [], causes: Array = []) -> Dictionary:
	return {"schema_version":1,"event_id":runtime.next_id("event"),"event_type":event_type,"world_time_seconds":_now(),"location_ref":_location(actor.global_position),"absolute_depth_m":0.0,"actor_refs":[{"entity_id":identity_for(actor),"role":"subject"}],"object_refs":objects,"cause_event_ids":causes,"effect_tags":[event_type],"facts":facts,"significance_tags":["historical"],"source_system":"lifecycle_adapter"}
func _record(event: Dictionary, anchors: Array) -> void:
	if not runtime.record(event,anchors): push_error("[WorldHistory] %s: %s" % [event.event_id,str(runtime.get_errors())])
func _location_anchor(location: Dictionary) -> Dictionary:
	# Current demo has only a surface. Future world service supplies depth/region IDs.
	return _anchor("location",runtime.world_id+"_surface","location_trace",location)
func _important_items(actor: Node2D, location: Dictionary, anchors: Array) -> Array:
	var objects: Array = []
	var component := actor.get_node_or_null("PlayerInventoryComponent")
	if component == null or component.get_inventory() == null: return objects
	for item in component.get_inventory().get_all_items():
		if str(item.definition_id) not in runtime.config.serialize().significant_item_ids: continue
		objects.append({"instance_id":item.instance_id,"role":"carried_evidence"})
		anchors.append(_anchor("world_item",item.instance_id,"relic",location))
		_carried[item.instance_id] = weakref(actor)
	return objects
func _on_corpse_spawned(corpse: Node2D, actor_ref: WeakRef) -> void:
	var actor = actor_ref.get_ref()
	if actor == null: return
	var location := _location(corpse.global_position)
	var anchors := [_anchor("corpse",identity_for(corpse),"corpse",location),_location_anchor(location)]
	var objects := _important_items(actor,location,anchors)
	_record(_event(actor,"character_death",[{"key":"death_cause","value":"unknown"}],objects),anchors)
	_bind_corpse(corpse)
func _on_defeated(actor_ref: WeakRef) -> void:
	var actor = actor_ref.get_ref()
	if actor == null: return
	var location := _location(actor.global_position)
	var anchors := [_location_anchor(location)]
	var objects := _important_items(actor,location,anchors)
	_record(_event(actor,"character_defeat",[{"key":"defeat_cause","value":"unknown"}],objects),anchors)
func _on_wound_created(wound: WoundState, actor_ref: WeakRef) -> void:
	var actor = actor_ref.get_ref()
	if actor == null or wound.get_bleeding_rate_per_game_hour() < runtime.config.serialize().severe_bleeding_rate_per_game_hour: return
	var event := _event(actor,"major_wound",[{"key":"wound_id","value":wound.wound_id}])
	_record(event,[_location_anchor(event.location_ref)])
	var bleeding := _event(actor,"severe_bleeding",[{"key":"wound_id","value":wound.wound_id},{"key":"bleeding_rate","value":wound.get_bleeding_rate_per_game_hour()}],[],[event.event_id])
	_record(bleeding,[_location_anchor(bleeding.location_ref)])
func _on_corpse_inspected(corpse: Node2D) -> void:
	var observer = _observer.get_ref() if _observer != null else null
	if observer == null: return
	for memory_id in runtime.graph.query_by_target("corpse",identity_for(corpse)):
		for anchor_id in runtime.graph.get_memory(memory_id).anchor_ids:
			var anchor: Dictionary = runtime.graph.get_anchor(anchor_id)
			if anchor.target_ref.kind == "corpse": runtime.observe(identity_for(observer),memory_id,anchor_id,_now())

func _on_item_dropped(instance_id: String, world_item: Node2D) -> void:
	_carried.erase(instance_id)
	_move_target("world_item",instance_id,_location(world_item.global_position))
	_bind_world_item(weakref(world_item))
func _on_item_picked_up(instance_id: String, actor_ref: WeakRef) -> void:
	if runtime.graph.query_by_target("world_item",instance_id).is_empty(): return
	var actor = actor_ref.get_ref()
	if actor == null: return
	_carried[instance_id] = actor_ref
	_move_target("world_item",instance_id,_location(actor.global_position))
func _on_carrier_exit(actor_ref: WeakRef) -> void:
	for instance_id in _carried.keys():
		if _carried[instance_id].get_ref() == actor_ref.get_ref():
			_carried.erase(instance_id)
			_set_target_access("world_item",instance_id,0.0)
func _bind_world_item(node_ref: WeakRef) -> void:
	var node = node_ref.get_ref()
	if node == null or not node.has_item(): return
	var item_id: String = node.get_item().instance_id
	_move_target("world_item",item_id,_location(node.global_position))
	var exiting := _on_world_item_exit.bind(item_id)
	if not node.tree_exiting.is_connected(exiting): node.tree_exiting.connect(exiting)
func _on_world_item_exit(item_id: String) -> void:
	if not _carried.has(item_id): _set_target_access("world_item",item_id,0.0)
func _move_target(kind: String, identity: String, location: Dictionary) -> void:
	var anchors: Array = []
	for anchor in _target_anchors(kind,identity):
		if anchor.available:
			anchor.last_known_location = location.duplicate(true)
			anchor.accessibility = 1.0
			anchors.append(anchor)
	if not anchors.is_empty(): runtime.graph.update_records({"anchors":anchors})
func _set_target_access(kind: String, identity: String, accessibility: float) -> void:
	var anchors: Array = []
	for anchor in _target_anchors(kind,identity):
		if anchor.available:
			anchor.accessibility = accessibility
			anchors.append(anchor)
	if not anchors.is_empty(): runtime.graph.update_records({"anchors":anchors})
func notify_anchor_destroyed(kind: String, identity: String) -> bool:
	if runtime == null: return false
	var anchors: Array = []
	for anchor in _target_anchors(kind,identity):
		if anchor.available:
			anchor.available = false
			anchor.durability = 0.0
			anchor.accessibility = 0.0
			anchors.append(anchor)
	return not anchors.is_empty() and runtime.graph.update_records({"anchors":anchors})

func _target_anchors(kind: String, identity: String) -> Array:
	var result: Array = []
	var seen := {}
	for memory_id in runtime.graph.query_by_target(kind,identity):
		for anchor_id in runtime.graph.get_memory(memory_id).anchor_ids:
			if seen.has(anchor_id): continue
			seen[anchor_id] = true
			var anchor: Dictionary = runtime.graph.get_anchor(anchor_id)
			if anchor.target_ref.kind == kind and anchor.target_ref.id == identity: result.append(anchor)
	return result
