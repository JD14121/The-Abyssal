extends "res://scripts/items/item_factory.gd"
## Test-only factory that fails after a requested number of successful creates.

var fail_after_successes := -1
var successful_creations := 0


func create(definition_id: StringName) -> ItemInstance:
	if fail_after_successes >= 0 and successful_creations >= fail_after_successes:
		return null
	var item: ItemInstance = super.create(definition_id)
	if item != null:
		successful_creations += 1
	return item
