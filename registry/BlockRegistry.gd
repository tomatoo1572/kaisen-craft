extends RefCounted
class_name KZ_BlockRegistry

class BlockDef extends RefCounted:
	var string_id: String = ""
	var name: String = ""
	var tint: Color = Color(1, 1, 1, 1)
	var transparent: bool = false
	var light_level: int = 0
	var texture_all_path: String = ""  # NEW

var _by_string: Dictionary = {}
var _runtime_by_string: Dictionary = {}
var _string_by_runtime: Array[String] = []

func _init() -> void:
	_add_builtin_air()

func _add_builtin_air() -> void:
	var air := BlockDef.new()
	air.string_id = "kaizencraft:air"
	air.name = "Air"
	air.transparent = true
	air.tint = Color(1, 1, 1, 0)
	_register_runtime(air)

func load_from_folder(folder_user_path: String) -> void:
	var files: Array[String] = KZ_PathUtil.list_files(folder_user_path, ".json")
	files.sort()

	for fpath in files:
		var txt: String = KZ_PathUtil.read_text(fpath)
		if txt == "":
			continue

		var parsed_v: Variant = JSON.parse_string(txt)
		if typeof(parsed_v) != TYPE_DICTIONARY:
			continue
		var parsed: Dictionary = parsed_v as Dictionary

		var sid: String = String(parsed.get("id", "")).strip_edges()
		if sid == "" or sid == "kaizencraft:air":
			continue

		var bd := BlockDef.new()
		bd.string_id = sid
		bd.name = String(parsed.get("name", sid))
		bd.transparent = bool(parsed.get("transparency", false))
		bd.light_level = int(parsed.get("light_level", 0))

		var tint_str: String = String(parsed.get("tint", "#ffffff"))
		bd.tint = _parse_hex_color(tint_str)

		# NEW: textures
		var textures_v: Variant = parsed.get("textures", {})
		if typeof(textures_v) == TYPE_DICTIONARY:
			var textures: Dictionary = textures_v as Dictionary
			bd.texture_all_path = String(textures.get("all", "")).strip_edges()

		_register_runtime(bd)

func _register_runtime(bd: BlockDef) -> void:
	if _runtime_by_string.has(bd.string_id):
		return
	var runtime_id: int = _string_by_runtime.size()
	_string_by_runtime.append(bd.string_id)
	_runtime_by_string[bd.string_id] = runtime_id
	_by_string[bd.string_id] = bd

func get_runtime_id(string_id: String) -> int:
	return int(_runtime_by_string.get(string_id, 0))

func get_string_id(runtime_id: int) -> String:
	if runtime_id < 0 or runtime_id >= _string_by_runtime.size():
		return "kaizencraft:air"
	return _string_by_runtime[runtime_id]

func get_def_by_runtime(runtime_id: int) -> BlockDef:
	var sid: String = get_string_id(runtime_id)
	var d: BlockDef = _by_string.get(sid) as BlockDef
	if d == null:
		d = _by_string.get("kaizencraft:air") as BlockDef
	return d

func is_air(runtime_id: int) -> bool:
	return runtime_id == 0

func is_solid(runtime_id: int) -> bool:
	if runtime_id == 0:
		return false
	return not get_def_by_runtime(runtime_id).transparent

func _parse_hex_color(s: String) -> Color:
	var t: String = s.strip_edges()
	if not t.begins_with("#"):
		t = "#" + t
	return Color.html(t)
