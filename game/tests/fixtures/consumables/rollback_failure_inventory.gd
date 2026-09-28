extends "res://scripts/inventory/inventory.gd"

var reject_readd := false


func add_item(value: Variant) -> bool:
	if reject_readd:
		return _fail("test double rejected rollback re-add")
	return super.add_item(value)
