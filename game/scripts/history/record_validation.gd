extends RefCounted
## Shared serialization-boundary checks; never coerces Nodes into identities.

static func identity(value: Variant) -> bool:
	return value is String and not value.is_empty() and value == value.strip_edges() and not value.contains("\n") and not value.contains("\t")

static func tag(value: Variant) -> bool:
	if not identity(value):
		return false
	for character in value:
		if character not in "abcdefghijklmnopqrstuvwxyz0123456789_":
			return false
	return value[0] in "abcdefghijklmnopqrstuvwxyz"

static func number(value: Variant, minimum: float = 0.0, maximum: float = INF) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum

static func integer(value: Variant, minimum: int = 0) -> bool:
	return number(value,float(minimum)) and float(value) == floor(float(value))

static func json_value(value: Variant, depth: int = 0) -> bool:
	if depth > 32:
		return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_STRING:
			return true
		TYPE_INT:
			return value >= -9007199254740991 and value <= 9007199254740991
		TYPE_FLOAT:
			return is_finite(value)
		TYPE_ARRAY:
			for entry in value:
				if not json_value(entry,depth+1): return false
			return true
		TYPE_DICTIONARY:
			for key in value:
				if not key is String or not json_value(value[key],depth+1): return false
			return true
	return false

static func fields(value: Variant, required: Array, optional: Array = []) -> Array[String]:
	var errors: Array[String] = []
	if not value is Dictionary:
		return ["record: expected Dictionary"]
	for field in required:
		if not value.has(field): errors.append("field %s: missing" % field)
	for field in value:
		if field not in required and field not in optional: errors.append("field %s: unsupported" % str(field))
	if not json_value(value): errors.append("record: expected finite JSON values; live objects are forbidden")
	return errors

static func ids(value: Variant) -> bool:
	if not value is Array: return false
	var seen := {}
	for entry in value:
		if not identity(entry) or seen.has(entry): return false
		seen[entry] = true
	return true

static func location(value: Variant) -> bool:
	if not value is Dictionary or not fields(value,["region_id","area_id"],["position","ecological_region_id","world_epoch"]).is_empty(): return false
	if not identity(value.region_id) or not identity(value.area_id): return false
	if value.has("ecological_region_id") and not identity(value.ecological_region_id): return false
	if value.has("world_epoch") and not identity(value.world_epoch): return false
	if value.has("position"):
		if not value.position is Array or value.position.size() not in [2,3]: return false
		for coordinate in value.position:
			if not number(coordinate,-INF): return false
	return true

static func freeze(value: Variant) -> void:
	if value is Dictionary:
		for child in value.values(): freeze(child)
		value.make_read_only()
	elif value is Array:
		for child in value: freeze(child)
		value.make_read_only()

static func normalize(value: Variant) -> Variant:
	# JSON has one number type; normalize integral floats for deterministic restores.
	if value is float and is_finite(value) and absf(value) <= 9007199254740991.0 and value == floor(value):
		return int(value)
	if value is Array:
		var output: Array = []
		for child in value: output.append(normalize(child))
		return output
	if value is Dictionary:
		var output: Dictionary = {}
		for key in value: output[key] = normalize(value[key])
		return output
	return value
