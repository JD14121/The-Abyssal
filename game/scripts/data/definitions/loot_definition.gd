class_name LootDefinition
extends RefCounted
## Static loot group. Entries are immutable after construction.

const Entry = preload("res://scripts/data/definitions/loot_entry.gd")

var id: StringName
var rolls: int
var entries: Array[Entry] = []
var source_file: String


func _init(data: Dictionary, source: String) -> void:
	id = StringName(data["id"])
	rolls = int(data["rolls"])
	for raw_entry in data["entries"]:
		entries.append(Entry.new(raw_entry))
	entries.make_read_only()
	source_file = source
