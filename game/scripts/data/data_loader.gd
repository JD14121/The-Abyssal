extends RefCounted
## File discovery and parsing only; schemas belong to DataValidator.

var errors: Array[String] = []
var file_count: int = 0
var _json_token := RegEx.create_from_string(
	r'"(?:[^"\\\x00-\x1f]|\\["\\/bfnrt]|\\u[0-9a-fA-F]{4})*"|-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?|true|false|null|[{}\[\],:]|[ \t\r\n]+'
)


func read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		errors.append("%s | file: cannot read (%s)" % [path, error_string(FileAccess.get_open_error())])
		return {"ok": false}
	var content := file.get_as_text()
	file.close()
	file_count += 1
	if not _check_json_tokens(content, path):
		return {"ok": false}
	var parser := JSON.new()
	if parser.parse(content) != OK:
		errors.append("%s | JSON line %d: %s" % [path, parser.get_error_line(), parser.get_error_message()])
		return {"ok": false}
	return {"ok": true, "value": parser.data}


func _check_json_tokens(content: String, path: String) -> bool:
	# Godot accepts trailing commas, raw newlines in strings and leading zeroes.
	# Reject those extensions so authored files also pass Python's JSON parser.
	# Structural grammar and value conversion still belong to Godot's parser.
	var offset: int = 0
	var previous: String = ""
	while offset < content.length():
		var token_match := _json_token.search(content, offset)
		if token_match == null or token_match.get_start() != offset:
			return _invalid_token(content, path, offset)
		var token := token_match.get_string()
		var end := token_match.get_end()
		if not token.strip_edges().is_empty():
			if previous == "," and token in ["]", "}"]:
				return _invalid_token(content, path, offset)
			if token[0] not in ['"', "{", "}", "[", "]", ",", ":"]:
				if end < content.length() and content[end] not in [" ", "\t", "\r", "\n", ",", "]", "}"]:
					return _invalid_token(content, path, offset)
			previous = token
		offset = end
	return true


func _invalid_token(content: String, path: String, offset: int) -> bool:
	var line := content.substr(0, offset).count("\n") + 1
	errors.append("%s | JSON line %d: invalid token or trailing comma" % [path, line])
	return false


func scan_json(directory: String) -> Array[String]:
	var files: Array[String] = []
	_scan(directory, files)
	files.sort()
	return files


func _scan(path: String, files: Array[String]) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		errors.append("%s | directory: cannot open (%s)" % [path, error_string(DirAccess.get_open_error())])
		return
	for filename in directory.get_files():
		if filename.ends_with(".json"):
			files.append(path.path_join(filename))
	for subdirectory in directory.get_directories():
		# Do not follow directory links outside the content tree or into cycles.
		if directory.is_link(subdirectory):
			errors.append("%s | directory: symbolic links are not supported" % path.path_join(subdirectory))
			continue
		_scan(path.path_join(subdirectory), files)
