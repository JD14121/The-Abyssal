extends "res://scripts/inventory/inventory.gd"

var reject_add := false
var on_reject: Callable


func add_item(value: Variant) -> bool:
	if reject_add:
		if on_reject.is_valid():
			on_reject.call()
		return _fail("simulated Inventory add rejection")
	return super.add_item(value)


func reject_future_adds() -> void:
	reject_add = true
