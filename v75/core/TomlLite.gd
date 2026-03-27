extends RefCounted
class_name KZ_TomlLite

# Minimal TOML subset:
# [section]
# key = value
# value supports: int, float, bool, "string"

func parse(text: String) -> Dictionary:
	var data: Dictionary = {}
	var current_section: String = ""
	var lines: PackedStringArray = text.split("\n")

	for raw in lines:
		var line: String = raw.strip_edges()
		if line == "" or line.begins_with("#"):
			continue

		# Strip inline comment
		var comment_idx: int = line.find("#")
		if comment_idx != -1:
			line = line.substr(0, comment_idx).strip_edges()
			if line == "":
				continue

		if line.begins_with("[") and line.ends_with("]"):
			current_section = line.substr(1, line.length() - 2).strip_edges()
			if not data.has(current_section):
				data[current_section] = {}
			continue

		var eq: int = line.find("=")
		if eq == -1:
			continue

		var key: String = line.substr(0, eq).strip_edges()
		var val_str: String = line.substr(eq + 1, line.length() - (eq + 1)).strip_edges()
		var val: Variant = _parse_value(val_str)

		if current_section == "":
			data[key] = val
		else:
			var sec: Dictionary = data.get(current_section, {}) as Dictionary
			sec[key] = val
			data[current_section] = sec

	return data

func stringify(data: Dictionary) -> String:
	var out: String = ""

	for k in data.keys():
		var v: Variant = data[k]
		if typeof(v) != TYPE_DICTIONARY:
			out += "%s = %s\n" % [str(k), _stringify_value(v)]

	for k in data.keys():
		var v: Variant = data[k]
		if typeof(v) == TYPE_DICTIONARY:
			out += "\n[%s]\n" % str(k)
			var sec: Dictionary = v as Dictionary
			for sk in sec.keys():
				out += "%s = %s\n" % [str(sk), _stringify_value(sec[sk])]

	return out.strip_edges() + "\n"

func _parse_value(s: String) -> Variant:
	if s.begins_with("\"") and s.ends_with("\"") and s.length() >= 2:
		return s.substr(1, s.length() - 2)

	var low: String = s.to_lower()
	if low == "true":
		return true
	if low == "false":
		return false

	# int?
	var is_int: bool = true
	for i in range(s.length()):
		var c: String = s[i]
		if i == 0 and (c == "-" or c == "+"):
			continue
		if c < "0" or c > "9":
			is_int = false
			break
	if is_int:
		return int(s)

	# float?
	var got_dot: bool = false
	var is_float: bool = true
	for i in range(s.length()):
		var c: String = s[i]
		if i == 0 and (c == "-" or c == "+"):
			continue
		if c == ".":
			if got_dot:
				is_float = false
				break
			got_dot = true
			continue
		if c < "0" or c > "9":
			is_float = false
			break
	if is_float and got_dot:
		return float(s)

	return s

func _stringify_value(v: Variant) -> String:
	match typeof(v):
		TYPE_STRING:
			return "\"%s\"" % String(v)
		TYPE_BOOL:
			return "true" if bool(v) else "false"
		_:
			return str(v)
