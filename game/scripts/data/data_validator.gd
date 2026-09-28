extends RefCounted
## Central schema rules for supported static definition types.

const GROUP_TYPES := {"materials": "material", "items": "item", "loot": "loot"}
const COMMON_FIELDS := ["type", "id", "name"]
const MATERIAL_FIELDS := ["density", "flammable"]
const ITEM_FIELDS := ["category", "mass", "materials"]
const LOOT_FIELDS := ["rolls", "entries"]
const LOOT_ENTRY_FIELDS := ["item_id", "weight", "chance", "min_quantity", "max_quantity"]

var errors: Array[String] = []
var warnings: Array[String] = []
var _id_pattern := RegEx.create_from_string("^[a-z][a-z0-9_]*$")


func validate_load_order(value: Variant, source: String) -> bool:
	if not value is Dictionary or value.get("groups") != ["materials", "items", "loot"]:
		errors.append("%s | field groups: expected [materials, items, loot] in dependency order" % source)
		return false
	for field in value:
		if field != "groups":
			warnings.append("%s | field %s: unknown optional field" % [source, field])
	return true


func entries(value: Variant, source: String) -> Array:
	if value is Dictionary:
		return [value]
	if value is Array:
		return value
	errors.append("%s | root: expected an object or array of objects" % source)
	return []


func validate(entry: Variant, expected_type: String, source: String,
		registered: Dictionary, known_materials: Dictionary) -> bool:
	var previous_errors := errors.size()
	if not entry is Dictionary:
		errors.append("%s | definition: expected an object" % source)
		return false
	var context := "%s | %s:%s" % [source, str(entry.get("type", expected_type)), str(entry.get("id", "<missing>"))]
	var allowed: Array = []
	if expected_type == "loot":
		_required_string(entry, "type", context)
		_required_string(entry, "id", context)
		allowed = ["type", "id"] + LOOT_FIELDS
		_validate_loot(entry, context, known_materials)
	else:
		for field in COMMON_FIELDS:
			_required_string(entry, field, context)
			allowed = COMMON_FIELDS.duplicate()
	if entry.get("type") != expected_type:
		errors.append("%s | field type: expected %s, unknown or misplaced type" % [context, expected_type])
	var identifier: Variant = entry.get("id")
	if identifier is String:
		if _id_pattern.search(identifier) == null or identifier.contains("\n"):
			errors.append("%s | field id: expected ASCII lowercase_snake_case" % context)
		if registered.has(StringName(identifier)):
			errors.append("%s | field id: duplicate ID; first defined in %s" % [context, registered[StringName(identifier)].source_file])
	if expected_type == "material":
		allowed.append_array(MATERIAL_FIELDS)
		_nonnegative_number(entry, "density", context)
		if entry.has("flammable") and not entry["flammable"] is bool:
			errors.append("%s | field flammable: expected bool" % context)
	elif expected_type == "item":
		allowed.append_array(ITEM_FIELDS)
		_required_string(entry, "category", context)
		_nonnegative_number(entry, "mass", context)
		if entry.has("materials"):
			if not entry["materials"] is Array:
				errors.append("%s | field materials: expected array of material IDs" % context)
			else:
				for material_id in entry["materials"]:
					if not material_id is String:
						errors.append("%s | field materials: expected string material ID" % context)
					elif not known_materials.has(StringName(material_id)):
						errors.append("%s | field materials: unknown material ID %s" % [context, material_id])
	for field in entry:
		if field not in allowed:
			warnings.append("%s | field %s: unknown optional field" % [context, field])
	return errors.size() == previous_errors


func _validate_loot(entry: Dictionary, context: String, known_items: Dictionary) -> void:
	if not entry.has("rolls"):
		errors.append("%s | field rolls: missing required field" % context)
	elif not _is_nonnegative_integer(entry["rolls"]):
		errors.append("%s | field rolls: expected integer >= 0" % context)
	if not entry.has("entries"):
		errors.append("%s | field entries: missing required field" % context)
		return
	if not entry["entries"] is Array:
		errors.append("%s | field entries: expected array" % context)
		return
	if int(entry.get("rolls", 0)) > 0 and entry.entries.is_empty():
		warnings.append("%s | field entries: loot group has rolls but no entries" % context)
	for index in range(entry.entries.size()):
		var raw: Variant = entry.entries[index]
		var entry_context := "%s | entries[%d]" % [context, index]
		if not raw is Dictionary:
			errors.append("%s | entry: expected an object" % entry_context)
			continue
		if not raw.has("item_id") or not raw.item_id is String or raw.item_id.strip_edges().is_empty():
			errors.append("%s | field item_id: expected non-empty string" % entry_context)
		elif not known_items.has(StringName(raw.item_id)):
			errors.append("%s | field item_id: unknown item ID %s" % [entry_context, raw.item_id])
		if not raw.has("weight"):
			errors.append("%s | field weight: missing required field" % entry_context)
		elif not _is_finite_number(raw.weight) or float(raw.weight) <= 0.0:
			errors.append("%s | field weight: expected finite number > 0" % entry_context)
		if raw.has("chance"):
			if not _is_finite_number(raw.chance) or float(raw.chance) < 0.0 or float(raw.chance) > 1.0:
				errors.append("%s | field chance: expected finite number in [0.0, 1.0]" % entry_context)
		var minimum: Variant = raw.get("min_quantity", 1)
		var maximum: Variant = raw.get("max_quantity", minimum)
		if not _is_nonnegative_integer(minimum):
			errors.append("%s | field min_quantity: expected integer >= 0" % entry_context)
		if not _is_nonnegative_integer(maximum) or (_is_nonnegative_integer(minimum) and maximum < minimum):
			errors.append("%s | field max_quantity: expected integer >= min_quantity" % entry_context)
		for field in raw:
			if field not in LOOT_ENTRY_FIELDS:
				warnings.append("%s | field %s: unknown optional field" % [entry_context, field])


func _is_finite_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value))


func _is_nonnegative_integer(value: Variant) -> bool:
	return _is_finite_number(value) and float(value) >= 0.0 and floor(float(value)) == float(value)


func _required_string(entry: Dictionary, field: String, context: String) -> void:
	if not entry.has(field):
		errors.append("%s | field %s: missing required field" % [context, field])
	elif not entry[field] is String or entry[field].strip_edges().is_empty():
		errors.append("%s | field %s: expected non-empty string" % [context, field])


func _nonnegative_number(entry: Dictionary, field: String, context: String) -> void:
	if not entry.has(field):
		return
	var value: Variant = entry[field]
	if not (value is int or value is float):
		errors.append("%s | field %s: expected number (not bool)" % [context, field])
	elif not is_finite(float(value)) or value < 0:
		errors.append("%s | field %s: expected finite number >= 0" % [context, field])
