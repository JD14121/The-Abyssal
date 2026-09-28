extends RefCounted
## Runtime records are a separate contract from static gameplay JSON.

const FIELDS := ["instance_id", "definition_id", "condition"]
static var _definition_id_pattern := RegEx.create_from_string("^[a-z][a-z0-9_]*$")


static func valid_condition(value: Variant) -> bool:
	if not (value is int or value is float):
		return false
	return is_finite(float(value)) and value >= 0.0 and value <= 1.0


static func definition_errors(definition_id: StringName, registry: Node) -> Array[String]:
	var errors: Array[String] = []
	var text := String(definition_id)
	if _definition_id_pattern.search(text) == null or text.contains("\n"):
		errors.append("field definition_id: expected ASCII lowercase_snake_case, got '%s'" % text)
	if not is_instance_valid(registry) or not registry.is_loaded():
		errors.append("registry: unavailable or not ready for definition_id '%s'" % text)
	elif not registry.has_item(definition_id):
		errors.append("field definition_id: unknown item definition '%s'" % text)
	return errors


static func validate(data: Variant, registry: Node) -> Array[String]:
	var errors: Array[String] = []
	if not data is Dictionary:
		errors.append("root: expected an item runtime Dictionary")
		return errors
	for field in FIELDS:
		if not data.has(field):
			errors.append("field %s: missing required field" % field)
	for field in ["instance_id", "definition_id"]:
		if data.has(field) and (not data[field] is String or data[field].strip_edges().is_empty()):
			errors.append("field %s: expected non-empty String" % field)
	if data.get("definition_id") is String:
		errors.append_array(definition_errors(StringName(data.definition_id), registry))
	if data.get("instance_id") is String and data.get("definition_id") is String and data.instance_id == data.definition_id:
		errors.append("field instance_id: must differ from definition_id")
	if data.has("condition") and not valid_condition(data.condition):
		errors.append("field condition: expected finite number in [0.0, 1.0], not bool")
	# Unknown runtime fields could contain state from a newer format. Reject rather
	# than silently discard that state while reconstructing a seemingly valid item.
	for field in data:
		if not field is String or field not in FIELDS:
			errors.append("field %s: unsupported runtime field" % str(field))
	return errors
