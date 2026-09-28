extends RefCounted
## Central schema rules for the two supported static definition types.

const GROUP_TYPES := {"materials": "material", "items": "item"}
const COMMON_FIELDS := ["type", "id", "name"]
const MATERIAL_FIELDS := ["density", "flammable"]
const ITEM_FIELDS := ["category", "mass", "materials"]

var errors: Array[String] = []
var warnings: Array[String] = []
var _id_pattern := RegEx.create_from_string("^[a-z][a-z0-9_]*$")


func validate_load_order(value: Variant, source: String) -> bool:
	if not value is Dictionary or value.get("groups") != ["materials", "items"]:
		errors.append("%s | field groups: expected [materials, items] in dependency order" % source)
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
	for field in COMMON_FIELDS:
		_required_string(entry, field, context)
	if entry.get("type") != expected_type:
		errors.append("%s | field type: expected %s, unknown or misplaced type" % [context, expected_type])
	var identifier: Variant = entry.get("id")
	if identifier is String:
		if _id_pattern.search(identifier) == null or identifier.contains("\n"):
			errors.append("%s | field id: expected ASCII lowercase_snake_case" % context)
		if registered.has(StringName(identifier)):
			errors.append("%s | field id: duplicate ID; first defined in %s" % [context, registered[StringName(identifier)].source_file])
	var allowed: Array = COMMON_FIELDS.duplicate()
	if expected_type == "material":
		allowed.append_array(MATERIAL_FIELDS)
		_nonnegative_number(entry, "density", context)
		if entry.has("flammable") and not entry["flammable"] is bool:
			errors.append("%s | field flammable: expected bool" % context)
	else:
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
