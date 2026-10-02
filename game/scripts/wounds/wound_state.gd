class_name WoundState
extends RefCounted
## Runtime state for one wound and its ongoing blood loss.

const RECORD_KEYS := [&"wound_id", &"bleeding_rate_per_game_hour"]
const MAX_BLEEDING_RATE_PER_GAME_HOUR := 10.0

var _wound_id := ""
var _bleeding_rate_per_game_hour := 0.0
var _crypto := Crypto.new()

var wound_id: String:
	get:
		return _wound_id
	set(_value):
		push_error("[WoundState] wound_id is read-only; restore through deserialize().")


func _init(initial_bleeding_rate_per_game_hour: float = 0.0) -> void:
	if not _is_valid_rate(initial_bleeding_rate_per_game_hour):
		push_error("[WoundState] Cannot initialize: bleeding rate must be finite and non-negative")
		return
	_wound_id = _new_wound_id()
	if _wound_id.is_empty():
		push_error("[WoundState] Cannot initialize: UUID generation failed")
		return
	_bleeding_rate_per_game_hour = initial_bleeding_rate_per_game_hour


func get_bleeding_rate_per_game_hour() -> float:
	return _bleeding_rate_per_game_hour


func is_bleeding() -> bool:
	return _bleeding_rate_per_game_hour > 0.0


func reduce_bleeding(amount_per_game_hour: float) -> bool:
	if not _is_valid_rate(amount_per_game_hour) or amount_per_game_hour == 0.0 \
		or not is_valid() or not is_bleeding():
		return false
	_bleeding_rate_per_game_hour = maxf(0.0, _bleeding_rate_per_game_hour - amount_per_game_hour)
	return true


func is_valid() -> bool:
	return _is_valid_wound_id(_wound_id) and _is_valid_rate(_bleeding_rate_per_game_hour)


func serialize() -> Dictionary:
	if not is_valid():
		push_error("[WoundState] Cannot serialize invalid Wound")
		return {}
	return {
		"wound_id": _wound_id,
		"bleeding_rate_per_game_hour": _bleeding_rate_per_game_hour,
	}


func deserialize(data: Variant) -> bool:
	if not data is Dictionary or data.size() != RECORD_KEYS.size():
		return false
	for key: StringName in RECORD_KEYS:
		if not data.has(key):
			return false
	var identity: Variant = data[&"wound_id"]
	var rate: Variant = data[&"bleeding_rate_per_game_hour"]
	if not _is_valid_wound_id(identity) or not _is_valid_rate(rate):
		return false
	_wound_id = identity
	_bleeding_rate_per_game_hour = float(rate)
	return true


func _is_valid_wound_id(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING:
		return false
	var identity: String = value
	if identity.length() != 36:
		return false
	for index in range(identity.length()):
		var code := identity.unicode_at(index)
		if index == 8 or index == 13 or index == 18 or index == 23:
			if code != 45:
				return false
		elif index == 14:
			if code != 52:
				return false
		elif index == 19:
			if code not in [56, 57, 97, 98]:
				return false
		elif not (code >= 48 and code <= 57 or code >= 97 and code <= 102):
			return false
	return true


func _is_valid_rate(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) \
		and float(value) >= 0.0 and float(value) <= MAX_BLEEDING_RATE_PER_GAME_HOUR


func _new_wound_id() -> String:
	var bytes := _crypto.generate_random_bytes(16)
	if bytes.size() != 16:
		return ""
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]
