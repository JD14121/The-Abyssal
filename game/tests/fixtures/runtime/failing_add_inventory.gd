extends "res://scripts/inventory/inventory.gd"

var reject_add := false
var reject_after_successful_adds := -1
var successful_adds := 0
var on_reject: Callable


func add_item(value: Variant) -> bool:
	if reject_add or (reject_after_successful_adds >= 0 and successful_adds >= reject_after_successful_adds):
		if on_reject.is_valid():
			on_reject.call()
		return _fail("simulated Inventory add rejection")
	var added: bool = super.add_item(value)
	if added:
		successful_adds += 1
	return added


func reject_future_adds() -> void:
	reject_add = true
