extends SceneTree
## Exercises generic atomic Inventory-to-Inventory ItemInstance transfer.

const FactoryScript = preload("res://scripts/items/item_factory.gd")
const InventoryScript = preload("res://scripts/inventory/inventory.gd")
const TransferScript = preload("res://scripts/inventory/inventory_transfer.gd")
const FailingInventoryScript = preload("res://tests/fixtures/runtime/failing_add_inventory.gd")

var checks := 0
var failures := 0
var groups: Dictionary[String, int] = {}
var registry: Node
var factory: RefCounted
var transfer: RefCounted


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String, group: String = "Transfer core") -> void:
	checks += 1
	groups[group] = groups.get(group, 0) + 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)


func _run() -> void:
	registry = root.get_node_or_null("DataRegistry")
	check(registry != null and registry.is_loaded(), "DataRegistry is ready")
	if registry == null or not registry.is_loaded():
		_finish()
		return
	factory = FactoryScript.new(registry)
	transfer = TransferScript.new()
	_successful_transfer_cases()
	_rejection_cases()
	_capacity_cases()
	_rollback_cases()
	_finish()


func _successful_transfer_cases() -> void:
	var source = InventoryScript.new(registry)
	var destination = InventoryScript.new(registry)
	var item = factory.create_with_condition(&"kitchen_knife", 0.37)
	check(source.add_item(item), "source accepts item before transfer")
	var source_weight_before: float = source.get_total_weight()
	var destination_weight_before: float = destination.get_total_weight()
	var combined_count_before: int = source.get_item_count() + destination.get_item_count()
	var combined_weight_before: float = source_weight_before + destination_weight_before
	check(transfer.transfer_item(source, destination, item.instance_id), "valid transfer succeeds")
	check(not source.has_item(item.instance_id), "successful transfer removes source identity")
	check(destination.get_item(item.instance_id) == item, "successful transfer moves same reference")
	check(item.instance_id == destination.get_item(item.instance_id).instance_id, "instance_id is unchanged")
	check(destination.get_item(item.instance_id).definition_id == &"kitchen_knife", "definition_id is unchanged")
	check(is_equal_approx(destination.get_item(item.instance_id).condition, 0.37), "non-default condition is unchanged")
	check(is_equal_approx(source.get_total_weight(), 0.0) and is_equal_approx(destination.get_total_weight(), source_weight_before), "source and destination weights update")
	check(source.get_item_count() + destination.get_item_count() == combined_count_before, "combined item count is preserved", "Invariants")
	check(is_equal_approx(source.get_total_weight() + destination.get_total_weight(), combined_weight_before), "combined weight is preserved", "Invariants")
	check(not transfer.transfer_item(source, destination, item.instance_id), "second transfer from empty source fails")
	check(source.get_item_count() == 0 and destination.get_item(item.instance_id) == item, "second transfer cannot duplicate identity")
	check(transfer.transfer_item(destination, source, item.instance_id), "reverse transfer succeeds")
	check(source.get_item(item.instance_id) == item and not destination.has_item(item.instance_id), "reverse transfer returns same instance to source")
	check(is_equal_approx(item.condition, 0.37), "reverse transfer preserves condition")
	check(source.get_item_count() + destination.get_item_count() == combined_count_before, "reverse transfer preserves combined item count", "Invariants")
	check(is_equal_approx(source.get_total_weight() + destination.get_total_weight(), combined_weight_before), "reverse transfer preserves combined weight", "Invariants")


func _rejection_cases() -> void:
	var inventory = InventoryScript.new(registry)
	var item = factory.create(&"hammer")
	inventory.add_item(item)
	check(not transfer.transfer_item(inventory, inventory, item.instance_id), "same Inventory cannot transfer to itself")
	check(inventory.get_item(item.instance_id) == item, "same-Inventory rejection leaves contents unchanged")
	check(not transfer.transfer_item(inventory, InventoryScript.new(registry), "missing"), "unknown instance ID fails")
	check(inventory.get_item(item.instance_id) == item, "unknown ID rejection preserves source")
	check(not transfer.transfer_item(null, inventory, item.instance_id), "null source fails safely")
	check(not transfer.transfer_item(inventory, null, item.instance_id), "null destination fails safely")
	var invalid_source := Node.new()
	check(not transfer.transfer_item(invalid_source, inventory, item.instance_id), "non-Inventory source fails safely")
	invalid_source.free()

	var duplicate_source = InventoryScript.new(registry)
	var duplicate_destination = InventoryScript.new(registry)
	var original = factory.create_with_condition(&"canned_beans", 0.37)
	var duplicate = factory.deserialize(original.serialize())
	duplicate_source.add_item(original)
	duplicate_destination.add_item(duplicate)
	check(not transfer.transfer_item(duplicate_source, duplicate_destination, original.instance_id), "destination duplicate is rejected")
	check(duplicate_source.get_item(original.instance_id) == original and duplicate_destination.get_item(original.instance_id) == duplicate, "duplicate rejection leaves both references unchanged")


func _capacity_cases() -> void:
	var source = InventoryScript.new(registry)
	var too_heavy_destination = InventoryScript.new(registry, 0.1)
	var heavy = factory.create(&"water_bottle")
	source.add_item(heavy)
	check(not too_heavy_destination.can_add_item(heavy), "can_add_item rejects capacity overflow")
	check(not transfer.transfer_item(source, too_heavy_destination, heavy.instance_id), "capacity overflow transfer fails")
	check(source.get_item(heavy.instance_id) == heavy and too_heavy_destination.get_item_count() == 0, "capacity failure leaves both inventories unchanged")

	var exact_source = InventoryScript.new(registry)
	var exact_destination = InventoryScript.new(registry, 0.03)
	var exact_item = factory.create(&"clean_bandage")
	exact_source.add_item(exact_item)
	check(exact_destination.can_add_item(exact_item), "can_add_item accepts exact capacity")
	check(transfer.transfer_item(exact_source, exact_destination, exact_item.instance_id), "exact-capacity transfer succeeds")
	check(exact_destination.get_item(exact_item.instance_id) == exact_item, "exact-capacity item reaches destination")


func _rollback_cases() -> void:
	var source = InventoryScript.new(registry)
	var rejecting_destination = FailingInventoryScript.new(registry)
	var item = factory.create_with_condition(&"kitchen_knife", 0.37)
	source.add_item(item)
	rejecting_destination.reject_add = true
	check(not transfer.transfer_item(source, rejecting_destination, item.instance_id), "unexpected destination rejection fails transfer")
	check(source.get_item(item.instance_id) == item and rejecting_destination.get_item_count() == 0, "rollback restores same item and destination remains unchanged", "Rollback")

	var rejecting_source = FailingInventoryScript.new(registry)
	var rejecting_destination_and_source = FailingInventoryScript.new(registry)
	var lost_item = factory.create(&"hammer")
	rejecting_source.add_item(lost_item)
	rejecting_destination_and_source.on_reject = Callable(rejecting_source, "reject_future_adds")
	rejecting_destination_and_source.reject_add = true
	check(not transfer.transfer_item(rejecting_source, rejecting_destination_and_source, lost_item.instance_id), "failed rollback reports transfer failure", "Rollback")
	check(transfer.get_errors().any(func(message: String) -> bool: return message.contains(lost_item.instance_id) and message.to_lower().contains("rollback")), "rollback diagnostic identifies instance and failure", "Rollback")


func _finish() -> void:
	for group in groups:
		print("%s: %d checks" % [group, groups[group]])
	print("Inventory transfer: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
