extends RefCounted
class_name KZ_HairCodec

const PRESET_DIR := "user://hair_presets"

static func encode_hair_data(hair_data: Dictionary) -> String:
	var normalized: Dictionary = KZ_HairStyleLibrary.ensure_hair_data(hair_data)
	var json: String = JSON.stringify(normalized)
	return Marshalls.raw_to_base64(json.to_utf8_buffer())

static func decode_hair_code(code: String) -> Dictionary:
	var trimmed: String = code.strip_edges()
	if trimmed == "":
		return KZ_HairStyleLibrary.blank_hair_data()
	var raw: PackedByteArray = Marshalls.base64_to_raw(trimmed)
	if raw.is_empty():
		return KZ_HairStyleLibrary.blank_hair_data()
	var json: String = raw.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(json)
	if parsed is Dictionary:
		return KZ_HairStyleLibrary.ensure_hair_data(parsed)
	return KZ_HairStyleLibrary.blank_hair_data()

static func save_named_preset(preset_name: String, hair_data: Dictionary) -> bool:
	var clean_name: String = _sanitize_name(preset_name)
	if clean_name == "":
		return false
	_ensure_preset_dir()
	var path: String = "%s/%s.json" % [PRESET_DIR, clean_name]
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	var payload: Dictionary = {
		"name": clean_name,
		"hair": KZ_HairStyleLibrary.ensure_hair_data(hair_data)
	}
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true

static func load_named_preset(preset_name: String) -> Dictionary:
	var clean_name: String = _sanitize_name(preset_name)
	if clean_name == "":
		return KZ_HairStyleLibrary.blank_hair_data()
	var path: String = "%s/%s.json" % [PRESET_DIR, clean_name]
	if not FileAccess.file_exists(path):
		return KZ_HairStyleLibrary.blank_hair_data()
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return KZ_HairStyleLibrary.blank_hair_data()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		var payload: Dictionary = parsed as Dictionary
		var hair: Variant = payload.get("hair", {})
		if hair is Dictionary:
			return KZ_HairStyleLibrary.ensure_hair_data(hair)
	return KZ_HairStyleLibrary.blank_hair_data()

static func list_saved_presets() -> Array[String]:
	_ensure_preset_dir()
	var names: Array[String] = []
	var dir: DirAccess = DirAccess.open(PRESET_DIR)
	if dir == null:
		return names
	dir.list_dir_begin()
	while true:
		var entry: String = dir.get_next()
		if entry == "":
			break
		if dir.current_is_dir():
			continue
		if entry.get_extension().to_lower() == "json":
			names.append(entry.get_basename())
	dir.list_dir_end()
	names.sort()
	return names

static func reset_to_preset(preset_id: String) -> Dictionary:
	return KZ_HairStyleLibrary.build_preset(preset_id)

static func _ensure_preset_dir() -> void:
	var dir: DirAccess = DirAccess.open("user://")
	if dir != null and not dir.dir_exists("hair_presets"):
		dir.make_dir_recursive("hair_presets")

static func _sanitize_name(name_value: String) -> String:
	var cleaned: String = name_value.strip_edges().to_lower()
	cleaned = cleaned.replace(" ", "_")
	cleaned = cleaned.replace("/", "_")
	cleaned = cleaned.replace("\\", "_")
	cleaned = cleaned.replace(":", "_")
	cleaned = cleaned.replace("*", "_")
	cleaned = cleaned.replace("?", "_")
	cleaned = cleaned.replace("\"", "_")
	cleaned = cleaned.replace("<", "_")
	cleaned = cleaned.replace(">", "_")
	cleaned = cleaned.replace("|", "_")
	return cleaned
