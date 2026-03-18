extends RefCounted
class_name KZ_BlockRegistry

class BlockDef extends RefCounted:
	var string_id: String = ""
	var name: String = ""
	var tint: Color = Color(1, 1, 1, 1)
	var transparent: bool = false
	var collidable: bool = true
	var placeable: bool = true
	var stack_size: int = 64
	var light_level: int = 0
	var hardness: float = 0.6
	var preferred_tool: String = ""
	var order_hint: int = 999999
	var texture_all_path: String = ""
	var texture_top_path: String = ""
	var texture_bottom_path: String = ""
	var texture_side_path: String = ""

	func get_face_texture_path(axis: int, dir: int) -> String:
		if axis == 1 and dir == +1 and texture_top_path != "":
			return texture_top_path
		if axis == 1 and dir == -1 and texture_bottom_path != "":
			return texture_bottom_path
		if texture_side_path != "":
			return texture_side_path
		return texture_all_path

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
	air.placeable = false
	air.stack_size = 0
	air.tint = Color(1, 1, 1, 0)
	air.order_hint = 0
	_register_runtime(air)

func load_from_folder(folder_user_path: String) -> void:
	var defs: Array[BlockDef] = _read_defs_from_folder(folder_user_path)
	for bd in defs:
		_register_runtime(bd)

func load_from_folders(folders: Array[String]) -> void:
	var defs: Array[BlockDef] = []
	for folder in folders:
		defs.append_array(_read_defs_from_folder(folder))
	defs.sort_custom(_sort_defs)
	for bd in defs:
		_register_runtime(bd)

func _read_defs_from_folder(folder_user_path: String) -> Array[BlockDef]:
	var files: Array[String] = KZ_PathUtil.list_files(folder_user_path, ".json")
	files.sort()
	var defs: Array[BlockDef] = []
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
		bd.collidable = bool(parsed.get("collidable", true))
		bd.placeable = bool(parsed.get("placeable", true))
		bd.stack_size = max(1, int(parsed.get("stack_size", 64)))
		bd.light_level = int(parsed.get("light_level", 0))
		bd.hardness = maxf(0.05, float(parsed.get("hardness", _default_hardness_for_id(sid))))
		bd.preferred_tool = String(parsed.get("preferred_tool", _default_tool_for_id(sid))).strip_edges().to_lower()
		bd.order_hint = _order_hint_for_id(sid, int(parsed.get("order", 999999)))
		var tint_str: String = String(parsed.get("tint", "#ffffff"))
		bd.tint = _parse_hex_color(tint_str)
		var textures_v: Variant = parsed.get("textures", {})
		if typeof(textures_v) == TYPE_DICTIONARY:
			var textures: Dictionary = textures_v as Dictionary
			bd.texture_all_path = String(textures.get("all", "")).strip_edges()
			bd.texture_top_path = String(textures.get("top", "")).strip_edges()
			bd.texture_bottom_path = String(textures.get("bottom", "")).strip_edges()
			bd.texture_side_path = String(textures.get("side", "")).strip_edges()
		if bd.texture_side_path == "":
			bd.texture_side_path = bd.texture_all_path
		if bd.texture_top_path == "":
			bd.texture_top_path = bd.texture_all_path
		if bd.texture_bottom_path == "":
			bd.texture_bottom_path = bd.texture_all_path
		if bd.string_id == "kaizencraft:oak_leaves":
			# Leaves should behave like full block foliage for collision in this phase.
			# Keep them solid for meshing and collidable so the player can stand on / bump into them.
			bd.collidable = bool(parsed.get("collidable", true))
		if bd.string_id == "kaizencraft:grass":
			if bd.texture_side_path == "res://assets/textures/blocks/grass.png":
				bd.texture_side_path = "res://assets/textures/blocks/grass_side.png"
			if bd.texture_side_path == "" or not ResourceLoader.exists(bd.texture_side_path):
				bd.texture_side_path = "res://assets/textures/blocks/grass_side.png"
			if bd.texture_top_path == "" or not ResourceLoader.exists(bd.texture_top_path) or bd.texture_top_path == bd.texture_side_path:
				bd.texture_top_path = "res://assets/textures/blocks/grass_top.png"
			if bd.texture_bottom_path == "" or not ResourceLoader.exists(bd.texture_bottom_path) or bd.texture_bottom_path == bd.texture_side_path:
				bd.texture_bottom_path = "res://assets/textures/blocks/dirt.png"
			bd.texture_all_path = bd.texture_side_path
		defs.append(bd)
	defs.sort_custom(_sort_defs)
	return defs

func _sort_defs(a: BlockDef, b: BlockDef) -> bool:
	if a.order_hint == b.order_hint:
		return a.string_id < b.string_id
	return a.order_hint < b.order_hint

func _order_hint_for_id(sid: String, fallback: int) -> int:
	match sid:
		"kaizencraft:grass":
			return 1
		"kaizencraft:dirt":
			return 2
		"kaizencraft:oak_log":
			return 3
		"kaizencraft:oak_leaves":
			return 4
		"kaizencraft:oak_planks":
			return 5
		"kaizencraft:stick":
			return 6
		"kaizencraft:crafting_table":
			return 7
		"kaizencraft:wooden_axe":
			return 8
		"kaizencraft:water":
			return 9
		"kaizencraft:stone":
			return 10
		"kaizencraft:sand":
			return 11
		_:
			return fallback

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

func get_numeric_id(item_id: String) -> int:
	return get_runtime_id(item_id)

func resolve_runtime_id(token: String) -> int:
	var t: String = token.strip_edges()
	if t == "":
		return 0
		
	if t.is_valid_int():
		return clampi(int(t), 0, _string_by_runtime.size() - 1)
	return get_runtime_id(t)

func resolve_string_id(token: String) -> String:
	var rid: int = resolve_runtime_id(token)
	return get_string_id(rid)

func get_def_by_runtime(runtime_id: int) -> BlockDef:
	var sid: String = get_string_id(runtime_id)
	var d: BlockDef = _by_string.get(sid) as BlockDef
	if d == null:
		d = _by_string.get("kaizencraft:air") as BlockDef
	return d

func get_def_by_string(item_id: String) -> BlockDef:
	return _by_string.get(item_id) as BlockDef

func get_registered_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for rid in range(_string_by_runtime.size()):
		var sid: String = _string_by_runtime[rid]
		var def: BlockDef = get_def_by_runtime(rid)
		out.append({
			"runtime_id": rid,
			"string_id": sid,
			"name": def.name if def != null else sid,
			"placeable": def.placeable if def != null else false,
			"stack_size": def.stack_size if def != null else 64,
			"category": _creative_category_for_def(def),
			"order": def.order_hint if def != null else rid
		})
	return out

func is_air(runtime_id: int) -> bool:
	return runtime_id == 0

func is_solid(runtime_id: int) -> bool:
	if runtime_id == 0:
		return false
	return not get_def_by_runtime(runtime_id).transparent

func is_collidable(runtime_id: int) -> bool:
	if runtime_id == 0:
		return false
	var def: BlockDef = get_def_by_runtime(runtime_id)
	return def != null and def.collidable

func is_placeable(runtime_id: int) -> bool:
	if runtime_id == 0:
		return false
	var def: BlockDef = get_def_by_runtime(runtime_id)
	return def != null and def.placeable

func get_stack_size(item_id: String) -> int:
	var def: BlockDef = get_def_by_string(item_id)
	if def == null:
		return 64
	return max(1, def.stack_size)

func get_hardness_by_runtime(runtime_id: int) -> float:
	var def: BlockDef = get_def_by_runtime(runtime_id)
	if def == null:
		return 0.6
	return maxf(0.05, def.hardness)

func get_preferred_tool_by_runtime(runtime_id: int) -> String:
	var def: BlockDef = get_def_by_runtime(runtime_id)
	if def == null:
		return ""
	return def.preferred_tool

func _default_hardness_for_id(sid: String) -> float:
	match sid:
		"kaizencraft:grass":
			return 0.6
		"kaizencraft:dirt":
			return 0.5
		"kaizencraft:oak_log":
			return 2.0
		"kaizencraft:oak_leaves":
			return 0.2
		"kaizencraft:oak_planks":
			return 2.0
		"kaizencraft:stick":
			return 0.2
		"kaizencraft:crafting_table":
			return 2.5
		"kaizencraft:wooden_axe":
			return 1.0
		"kaizencraft:water":
			return 100.0
		"kaizencraft:stone":
			return 2.2
		"kaizencraft:sand":
			return 0.6
		_:
			return 0.6

func _default_tool_for_id(sid: String) -> String:
	match sid:
		"kaizencraft:oak_log", "kaizencraft:oak_planks", "kaizencraft:crafting_table":
			return "axe"
		_:
			return ""

func _parse_hex_color(s: String) -> Color:
	var t: String = s.strip_edges()
	if not t.begins_with("#"):
		t = "#" + t
	return Color.html(t)

func get_preview_paths(item_id: String) -> Dictionary:
	var def: BlockDef = get_def_by_string(item_id)
	if def == null:
		return {}
	return {
		"top": def.texture_top_path,
		"side": def.texture_side_path,
		"bottom": def.texture_bottom_path,
		"all": def.texture_all_path,
		"mode": "block" if _looks_block_like(def) else "item"
	}

func _looks_block_like(def: BlockDef) -> bool:
	if def == null:
		return false
	if def.preferred_tool != "":
		return false
	if def.string_id.ends_with(":stick"):
		return false
	return def.placeable

func _creative_category_for_def(def: BlockDef) -> String:
	if def == null:
		return "Items"
	if def.preferred_tool != "" or def.string_id.contains("axe"):
		return "Tools"
	if _looks_block_like(def):
		return "Blocks"
	return "Items"
