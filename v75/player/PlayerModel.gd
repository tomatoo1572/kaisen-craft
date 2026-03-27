extends Node3D

const MALE_DEFAULT_MODEL_PATH := "res://assets/models/player/male/default/kaizencraftplayer.glb"
const FEMALE_DEFAULT_MODEL_PATH := "res://assets/models/player/female/default/kaizencraftplayer.glb"
const TARGET_PLAYER_HEIGHT_BLOCKS := 1.8
const DEFAULT_HEIGHT_METERS := 1.8288
const DEFAULT_EYE_HEIGHT_RATIO := 0.915

const BODY_PART_ALIASES := {
	"hip": ["hip"],
	"waist": ["waist", "hips"],
	"head": ["head"],
	"torso_upper": ["upper"],
	"torso_lower": ["lower", "bodylower"],
	"arm_upper_r": ["upper2"],
	"arm_lower_r": ["lower2"],
	"hand_r": ["hand"],
	"arm_upper_l": ["upper5"],
	"arm_lower_l": ["lower5"],
	"hand_l": ["hand2"],
	"leg_upper_r": ["upper4"],
	"leg_lower_r": ["lower4"],
	"foot_r": ["feet"],
	"leg_upper_l": ["upper3"],
	"leg_lower_l": ["lower3"],
	"foot_l": ["feet2"]
}

const CLOTHING_SLOTS := {
	"head_accessory": "head",
	"torso_under": "torso_upper",
	"torso_outer": "torso_upper",
	"waist": "waist",
	"arm_left": "arm_upper_l",
	"arm_right": "arm_upper_r",
	"hand_left": "hand_l",
	"hand_right": "hand_r",
	"leg_left": "leg_upper_l",
	"leg_right": "leg_upper_r",
	"foot_left": "foot_l",
	"foot_right": "foot_r",
	"back": "torso_upper"
}

const BODY_TEXTURES := {
	"skin": "res://assets/textures/player/body/maleskin.png",
	"boxers": "res://assets/textures/player/body/maleboxers.png",
	"male1": "res://assets/textures/player/body/male1.png",
	"male2": "res://assets/textures/player/body/male2.png",
	"male3": "res://assets/textures/player/body/male3.png",
	"male4": "res://assets/textures/player/body/male4.png"
}

var appearance_profile: RefCounted
var model_scene_root: Node3D
var model_asset_root: Node3D
var body_parts: Dictionary = {}
var clothing_anchors: Dictionary = {}
var first_person_hidden: bool = true
var current_model_path: String = ""
var _body_part_base_scales: Dictionary = {}
var _base_fit_scale: float = 1.0
var _first_person_body_visible: bool = false
var _cached_local_aabb: AABB = AABB(Vector3.ZERO, Vector3.ZERO)
var _cached_eye_height: float = 1.62
var _cached_focus_height: float = 1.42
var _image_cache: Dictionary = {}
var _mesh_nodes: Array[MeshInstance3D] = []
var _body_texture_key: String = ""
var _hair_root: Node3D
var _hair_strands: Array = []
var _hair_time: float = 0.0
var _wind_dir: Vector3 = Vector3(0.65, 0.0, 0.25)
var _wind_strength: float = 0.0

func _ready() -> void:
	set_process(true)
	if appearance_profile == null:
		var app_script: Script = load("res://player/CharacterAppearance.gd") as Script
		if app_script != null:
			appearance_profile = app_script.new()
	ensure_model_loaded()

func _process(delta: float) -> void:
	_hair_time += delta
	_update_hair_motion(delta)

func ensure_model_loaded() -> void:
	if appearance_profile == null:
		return
	var target_path: String = _resolve_model_path()
	if model_scene_root != null and current_model_path == target_path:
		return
	_reload_model(target_path)

func set_appearance_profile(profile: RefCounted) -> void:
	appearance_profile = profile
	ensure_model_loaded()
	apply_profile()

func apply_profile() -> void:
	ensure_model_loaded()
	if appearance_profile == null or model_asset_root == null:
		return
	_restore_base_scales()
	var height_scale: float = _get_height_scale()
	var width_scale: float = clampf(_get_profile_float("width_scale", 1.0), 0.82, 1.18)
	model_asset_root.scale = Vector3(_base_fit_scale * width_scale, _base_fit_scale * height_scale, _base_fit_scale * width_scale)
	_recenter_model_to_origin()
	_update_cached_camera_metrics()
	_apply_body_materials()
	_rebuild_hair()
	set_first_person_hidden(first_person_hidden)

func set_look_pitch(pitch_radians: float) -> void:
	var head_node: Node3D = body_parts.get("head", null) as Node3D
	if head_node != null:
		head_node.rotation.x = clampf(-pitch_radians * 0.50, deg_to_rad(-48.0), deg_to_rad(38.0))
	var torso_upper_node: Node3D = body_parts.get("torso_upper", null) as Node3D
	if torso_upper_node != null:
		torso_upper_node.rotation.x = 0.0
	var torso_lower_node: Node3D = body_parts.get("torso_lower", null) as Node3D
	if torso_lower_node != null:
		torso_lower_node.rotation.x = 0.0
	var waist_node: Node3D = body_parts.get("waist", null) as Node3D
	if waist_node != null:
		waist_node.rotation.x = 0.0

func set_first_person_hidden(hidden: bool) -> void:
	first_person_hidden = hidden
	if model_scene_root == null:
		return
	if hidden and _first_person_body_visible:
		model_scene_root.visible = true
		_set_head_visibility(false)
		if _hair_root != null:
			_hair_root.visible = false
	else:
		model_scene_root.visible = not hidden
		_set_head_visibility(true)
		if _hair_root != null:
			_hair_root.visible = true
	for part_name in ["torso_upper", "torso_lower", "waist", "arm_upper_l", "arm_upper_r", "arm_lower_l", "arm_lower_r", "hand_l", "hand_r", "leg_upper_l", "leg_upper_r", "leg_lower_l", "leg_lower_r", "foot_l", "foot_r"]:
		_set_part_visibility(part_name, true)

func set_first_person_body_visible(enabled: bool) -> void:
	_first_person_body_visible = enabled
	set_first_person_hidden(first_person_hidden)

func set_world_wind_direction(wind_direction: Vector3) -> void:
	var strength: float = wind_direction.length()
	if strength <= 0.0001:
		_wind_dir = Vector3.ZERO
		_wind_strength = 0.0
	else:
		_wind_dir = wind_direction / strength
		_wind_strength = clampf(strength, 0.0, 1.5)

func get_first_person_camera_height() -> float:
	return _cached_eye_height

func get_third_person_focus_height() -> float:
	return _cached_focus_height

func get_visual_height_blocks() -> float:
	return TARGET_PLAYER_HEIGHT_BLOCKS * _get_height_scale()

func get_visual_height_meters() -> float:
	return _get_profile_float("height_meters", DEFAULT_HEIGHT_METERS)

func get_current_local_aabb() -> AABB:
	if model_scene_root == null:
		return AABB(Vector3.ZERO, Vector3.ZERO)
	return _compute_combined_local_aabb(model_scene_root)

func get_current_body_height() -> float:
	var aabb: AABB = get_current_local_aabb()
	return aabb.size.y

func get_current_body_width() -> float:
	var aabb: AABB = get_current_local_aabb()
	return maxf(aabb.size.x, aabb.size.z)

func get_first_person_eye_height() -> float:
	return get_first_person_camera_local_pos().y

func get_first_person_forward_offset() -> float:
	return get_first_person_camera_local_pos().z

func get_first_person_visual_offset() -> Vector3:
	# Keep the body rooted at the feet so the camera feels like real eyes rather than the torso or legs.
	return Vector3(0.0, 0.0, 0.0)

func get_first_person_camera_local_pos() -> Vector3:
	var aabb: AABB = get_current_local_aabb()
	if aabb.size == Vector3.ZERO:
		return Vector3(0.0, 1.64, 0.0)
	var eye_y: float = aabb.position.y + aabb.size.y * 0.915
	var head_node: Node3D = body_parts.get("head", null) as Node3D
	if head_node != null:
		var head_aabb: AABB = _compute_combined_local_aabb(head_node)
		if head_aabb.size != Vector3.ZERO:
			var alt_eye_y: float = head_aabb.position.y + head_aabb.size.y * 0.58
			eye_y = maxf(eye_y, alt_eye_y)
	return Vector3(0.0, clampf(eye_y, 1.58, 2.08), 0.0)

func get_third_person_pivot_height() -> float:
	var aabb: AABB = get_current_local_aabb()
	if aabb.size == Vector3.ZERO:
		return 1.42
	return aabb.position.y + aabb.size.y * 0.78

func _set_head_visibility(visible_value: bool) -> void:
	_set_part_visibility("head", visible_value)

func _set_part_visibility(part_name: String, visible_value: bool) -> void:
	var node: Node3D = body_parts.get(part_name, null) as Node3D
	if node == null:
		return
	node.visible = visible_value
	for child in node.get_children():
		if child is Node3D:
			(child as Node3D).visible = visible_value

func get_body_part(part_name: String) -> Node3D:
	return body_parts.get(part_name, null) as Node3D

func get_clothing_anchor(slot_name: String) -> Node3D:
	return clothing_anchors.get(slot_name, null) as Node3D

func equip_layer_scene(slot_name: String, layer_scene: PackedScene, clear_existing: bool = true) -> Node3D:
	var anchor: Node3D = get_clothing_anchor(slot_name)
	if anchor == null or layer_scene == null:
		return null
	if clear_existing:
		for child in anchor.get_children():
			child.queue_free()
	var inst: Node = layer_scene.instantiate()
	anchor.add_child(inst)
	return inst as Node3D

func clear_layer_slot(slot_name: String) -> void:
	var anchor: Node3D = get_clothing_anchor(slot_name)
	if anchor == null:
		return
	for child in anchor.get_children():
		child.queue_free()

func get_character_framework_info() -> Dictionary:
	return {
		"sexes": ["male", "female"],
		"body_presets": ["male1", "male2", "male3", "male4"],
		"hair_presets": KZ_HairStyleLibrary.preset_ids(),
		"body_parts": body_parts.keys(),
		"clothing_slots": clothing_anchors.keys()
	}

func _resolve_model_path() -> String:
	var sex: String = _get_profile_string("sex", "male")
	if sex == "female" and ResourceLoader.exists(FEMALE_DEFAULT_MODEL_PATH):
		return FEMALE_DEFAULT_MODEL_PATH
	return MALE_DEFAULT_MODEL_PATH

func _reload_model(model_path: String) -> void:
	current_model_path = model_path
	if model_scene_root != null:
		model_scene_root.queue_free()
	model_scene_root = Node3D.new()
	model_scene_root.name = "CharacterModelRoot"
	add_child(model_scene_root)
	var packed: PackedScene = load(model_path) as PackedScene
	if packed == null:
		push_error("Could not load player model scene: %s" % model_path)
		return
	var inst: Node = packed.instantiate()
	model_asset_root = inst as Node3D
	if model_asset_root == null:
		var wrapper := Node3D.new()
		wrapper.add_child(inst)
		model_asset_root = wrapper
	model_scene_root.add_child(model_asset_root)
	_register_body_parts()
	_collect_mesh_nodes()
	_create_clothing_anchors()
	_store_base_scales()
	_refresh_base_fit_scale()
	model_asset_root.scale = Vector3.ONE * _base_fit_scale
	_recenter_model_to_origin()
	_update_cached_camera_metrics()
	_body_texture_key = ""
	apply_profile()

func _register_body_parts() -> void:
	body_parts.clear()
	if model_asset_root == null:
		return
	var all_nodes: Array = []
	_collect_nodes(model_asset_root, all_nodes)
	for part_name in BODY_PART_ALIASES.keys():
		var aliases: Array = BODY_PART_ALIASES[part_name]
		var match_node: Node3D = _find_best_node_match(all_nodes, aliases)
		if match_node != null:
			body_parts[part_name] = match_node
	if not body_parts.has("waist") and body_parts.has("hip"):
		body_parts["waist"] = body_parts["hip"]

func _collect_mesh_nodes() -> void:
	_mesh_nodes.clear()
	if model_asset_root == null:
		return
	var nodes: Array = []
	_collect_nodes(model_asset_root, nodes)
	for node_v in nodes:
		if node_v is MeshInstance3D:
			_mesh_nodes.append(node_v as MeshInstance3D)

func _apply_body_materials() -> void:
	var body_preset: String = _get_profile_string("body_preset", "male1").to_lower()
	var skin_tone: Color = _get_profile_color("skin_tone", Color(0.93, 0.81, 0.69, 1.0))
	var key: String = "%s_%0.3f_%0.3f_%0.3f" % [body_preset, skin_tone.r, skin_tone.g, skin_tone.b]
	if key == _body_texture_key and _mesh_nodes.size() > 0:
		return
	_body_texture_key = key

	var composed: Image = _compose_body_image(body_preset, skin_tone)
	if composed == null:
		return
	var tex := ImageTexture.create_from_image(composed)
	for mesh in _mesh_nodes:
		if mesh == null or mesh.mesh == null:
			continue
		for surface_idx in range(mesh.mesh.get_surface_count()):
			var mat := StandardMaterial3D.new()
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.cull_mode = BaseMaterial3D.CULL_BACK
			mat.albedo_texture = tex
			mat.albedo_color = Color.WHITE
			mat.metallic = 0.0
			mat.roughness = 1.0
			mesh.set_surface_override_material(surface_idx, mat)

func _compose_body_image(body_preset: String, skin_tone: Color) -> Image:
	var skin_img: Image = _get_image(BODY_TEXTURES.get("skin", ""))
	if skin_img == null:
		return null
	var composed := Image.create(skin_img.get_width(), skin_img.get_height(), false, Image.FORMAT_RGBA8)
	composed.fill(Color(skin_tone.r, skin_tone.g, skin_tone.b, 1.0))
	var layers: Array[String] = [
		BODY_TEXTURES.get("boxers", ""),
		BODY_TEXTURES.get(body_preset, BODY_TEXTURES.get("male1", ""))
	]
	for path in layers:
		var layer: Image = _get_image(path)
		if layer == null:
			continue
		composed.blend_rect(layer, Rect2i(Vector2i.ZERO, layer.get_size()), Vector2i.ZERO)
	return composed

func _get_image(path: String) -> Image:
	if path == "":
		return null
	if _image_cache.has(path):
		return _image_cache[path] as Image
	if not ResourceLoader.exists(path):
		return null
	var img: Image = Image.load_from_file(path)
	if img == null:
		return null
	_image_cache[path] = img
	return img

func _rebuild_hair() -> void:
	var head_node: Node3D = body_parts.get("head", null) as Node3D
	if head_node == null:
		return
	if _hair_root != null:
		_hair_root.queue_free()
	_hair_root = Node3D.new()
	_hair_root.name = "HairRoot"
	head_node.add_child(_hair_root)
	_hair_strands.clear()

	var hair_color: Color = _get_profile_color("hair_color", Color(0.08, 0.08, 0.10, 1.0))
	var head_aabb: AABB = _compute_combined_local_aabb(head_node)
	if head_aabb.size == Vector3.ZERO:
		head_aabb = AABB(Vector3(-0.22, -0.22, -0.22), Vector3(0.44, 0.44, 0.44))
	var hair_data: Dictionary = _get_profile_hair_data()
	var sides: Dictionary = hair_data.get("sides", {}) as Dictionary
	for side in KZ_HairStyleLibrary.SIDE_NAMES:
		var strand_defs: Array = sides.get(side, []) as Array
		for idx in range(strand_defs.size()):
			var strand_def_v: Variant = strand_defs[idx]
			if not (strand_def_v is Dictionary):
				continue
			var strand_def: Dictionary = strand_def_v as Dictionary
			if not bool(strand_def.get("enabled", true)):
				continue
			_build_hair_strand(side, idx, strand_def, head_aabb, hair_color)
	if _hair_root != null:
		_hair_root.visible = not (first_person_hidden and _first_person_body_visible)

func _build_hair_strand(side: String, slot_index: int, strand_def: Dictionary, head_aabb: AABB, hair_color: Color) -> void:
	var anchor := Node3D.new()
	anchor.name = "%s_%d" % [side, slot_index]
	anchor.position = _hair_anchor_pos(side, head_aabb) + _strand_offset_vec(strand_def)
	anchor.rotation_degrees = _hair_anchor_rot_deg(side) + _strand_rotation_vec(strand_def)
	_hair_root.add_child(anchor)

	var length: float = clampf(float(strand_def.get("length", 0.42)), 0.06, 1.30)
	var width: float = clampf(float(strand_def.get("width", 0.18)), 0.04, 0.55)
	var depth: float = clampf(float(strand_def.get("depth", width * 0.75)), 0.03, 0.50)
	var bend: float = clampf(float(strand_def.get("bend", 0.18)), -1.0, 1.0)
	var taper: float = clampf(float(strand_def.get("taper", 0.22)), 0.0, 1.0)
	var sway: float = clampf(float(strand_def.get("sway", 0.08)), 0.0, 1.0)

	var upper_len: float = length * 0.56
	var lower_len: float = maxf(0.03, length - upper_len)
	var lower_width: float = lerpf(width, width * 0.36, taper)
	var lower_depth: float = lerpf(depth, depth * 0.42, taper)

	var segment_root := Node3D.new()
	anchor.add_child(segment_root)

	var upper_mesh := MeshInstance3D.new()
	var upper_box := BoxMesh.new()
	upper_box.size = Vector3(width, upper_len, depth)
	upper_mesh.mesh = upper_box
	upper_mesh.position = Vector3(0.0, -upper_len * 0.5, 0.0)
	upper_mesh.material_override = _make_hair_material(hair_color)
	segment_root.add_child(upper_mesh)

	var lower_pivot := Node3D.new()
	lower_pivot.position = Vector3(0.0, -upper_len, 0.0)
	lower_pivot.rotation_degrees.x = bend * 26.0
	segment_root.add_child(lower_pivot)

	var lower_mesh := MeshInstance3D.new()
	var lower_box := BoxMesh.new()
	lower_box.size = Vector3(lower_width, lower_len, lower_depth)
	lower_mesh.mesh = lower_box
	lower_mesh.position = Vector3(0.0, -lower_len * 0.5, 0.0)
	lower_mesh.material_override = _make_hair_material(hair_color)
	lower_pivot.add_child(lower_mesh)

	_hair_strands.append({
		"anchor": anchor,
		"lower_pivot": lower_pivot,
		"base_rot": anchor.rotation,
		"base_lower_rot": lower_pivot.rotation,
		"bend": bend,
		"sway": sway,
		"phase": randf() * TAU,
		"side": side
	})

func _make_hair_material(hair_color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	mat.albedo_color = hair_color
	mat.roughness = 1.0
	mat.metallic = 0.0
	return mat

func _strand_offset_vec(strand_def: Dictionary) -> Vector3:
	var offset_arr: Array = strand_def.get("offset", [0.0, 0.0, 0.0]) as Array
	return Vector3(
		float(offset_arr[0]) if offset_arr.size() > 0 else 0.0,
		float(offset_arr[1]) if offset_arr.size() > 1 else 0.0,
		float(offset_arr[2]) if offset_arr.size() > 2 else 0.0
	)

func _strand_rotation_vec(strand_def: Dictionary) -> Vector3:
	var rot_arr: Array = strand_def.get("rotation", [0.0, 0.0, 0.0]) as Array
	return Vector3(
		float(rot_arr[0]) if rot_arr.size() > 0 else 0.0,
		float(rot_arr[1]) if rot_arr.size() > 1 else 0.0,
		float(rot_arr[2]) if rot_arr.size() > 2 else 0.0
	)

func _hair_anchor_pos(side: String, aabb: AABB) -> Vector3:
	var center_x: float = aabb.position.x + aabb.size.x * 0.5
	var center_z: float = aabb.position.z + aabb.size.z * 0.5
	var top_y: float = aabb.position.y + aabb.size.y * 0.98
	var front_z: float = aabb.position.z + aabb.size.z * 0.04
	var back_z: float = aabb.position.z + aabb.size.z * 0.96
	var left_x: float = aabb.position.x + aabb.size.x * 0.08
	var right_x: float = aabb.position.x + aabb.size.x * 0.92
	match side:
		"front":
			return Vector3(center_x, top_y, front_z)
		"top":
			return Vector3(center_x, top_y, center_z)
		"back":
			return Vector3(center_x, top_y, back_z)
		"left":
			return Vector3(left_x, top_y * 0.98 + aabb.position.y * 0.02, center_z)
		"right":
			return Vector3(right_x, top_y * 0.98 + aabb.position.y * 0.02, center_z)
		_:
			return Vector3(center_x, top_y, center_z)

func _hair_anchor_rot_deg(side: String) -> Vector3:
	match side:
		"front":
			return Vector3.ZERO
		"top":
			return Vector3.ZERO
		"back":
			return Vector3(0.0, 180.0, 0.0)
		"left":
			return Vector3(0.0, 90.0, 0.0)
		"right":
			return Vector3(0.0, -90.0, 0.0)
		_:
			return Vector3.ZERO

func _update_hair_motion(_delta: float) -> void:
	if _hair_root == null or _hair_strands.is_empty():
		return
	var wind_amount: float = clampf(_wind_strength, 0.0, 1.0)
	for strand_data_v in _hair_strands:
		if not (strand_data_v is Dictionary):
			continue
		var strand_data: Dictionary = strand_data_v as Dictionary
		var anchor: Node3D = strand_data.get("anchor", null) as Node3D
		var lower_pivot: Node3D = strand_data.get("lower_pivot", null) as Node3D
		if anchor == null or lower_pivot == null:
			continue
		var base_rot: Vector3 = strand_data.get("base_rot", Vector3.ZERO)
		var base_lower_rot: Vector3 = strand_data.get("base_lower_rot", Vector3.ZERO)
		var sway: float = float(strand_data.get("sway", 0.08))
		var phase: float = float(strand_data.get("phase", 0.0))
		var bend: float = float(strand_data.get("bend", 0.18))
		var side: String = str(strand_data.get("side", "top"))

		var oscillation: float = sin(_hair_time * 2.1 + phase) * 0.65
		oscillation += sin(_hair_time * 3.7 + phase * 1.91) * 0.35
		var gust: float = 0.35 + wind_amount * 0.95
		var side_bias: float = 1.0
		if side == "back":
			side_bias = 0.75
		elif side == "front":
			side_bias = 1.10
		var pitch_offset: float = (_wind_dir.z * 0.18 + oscillation * 0.12 * gust) * sway * side_bias
		var yaw_offset: float = (-_wind_dir.x * 0.14 + cos(_hair_time * 1.45 + phase) * 0.04 * gust) * sway
		var roll_offset: float = (_wind_dir.x * 0.12 + sin(_hair_time * 1.7 + phase * 0.7) * 0.03 * gust) * sway

		if wind_amount <= 0.001:
			pitch_offset *= 0.30
			yaw_offset *= 0.30
			roll_offset *= 0.30

		anchor.rotation = Vector3(
			base_rot.x + pitch_offset,
			base_rot.y + yaw_offset,
			base_rot.z + roll_offset
		)
		lower_pivot.rotation = Vector3(
			base_lower_rot.x + bend * 0.18 + pitch_offset * 1.45,
			base_lower_rot.y + yaw_offset * 0.35,
			base_lower_rot.z + roll_offset * 0.55
		)

func _get_profile_hair_data() -> Dictionary:
	if appearance_profile == null:
		return KZ_HairStyleLibrary.build_preset("soft_messy")
	var data_v: Variant = appearance_profile.get("hair_data")
	if data_v is Dictionary and not (data_v as Dictionary).is_empty():
		return KZ_HairStyleLibrary.ensure_hair_data(data_v)
	var preset: String = _get_profile_string("hair_preset_id", _get_profile_string("hair_style", "soft_messy"))
	return KZ_HairStyleLibrary.build_preset(preset)

func _collect_nodes(node: Node, out_nodes: Array) -> void:
	if node is Node3D:
		out_nodes.append(node)
	for child in node.get_children():
		_collect_nodes(child, out_nodes)

func _find_best_node_match(nodes: Array, aliases: Array) -> Node3D:
	var best: Node3D = null
	var best_score: int = -100000
	for node_v in nodes:
		var node: Node3D = node_v as Node3D
		if node == null:
			continue
		var norm_node_name: String = _normalize_name(node.name)
		var score: int = -1000
		for alias_v in aliases:
			var alias: String = _normalize_name(str(alias_v))
			if norm_node_name == alias:
				score = max(score, 100)
			elif norm_node_name.begins_with(alias):
				score = max(score, 60)
			elif alias in norm_node_name:
				score = max(score, 40)
		if score < 0:
			continue
		if node.get_child_count() > 0:
			score += 8
		if not (node is MeshInstance3D):
			score += 4
		if node.get_parent() == model_asset_root:
			score += 2
		if score > best_score:
			best_score = score
			best = node
	return best

func _refresh_base_fit_scale() -> void:
	if model_asset_root == null:
		_base_fit_scale = 1.0
		_cached_local_aabb = AABB(Vector3.ZERO, Vector3.ZERO)
		return
	_cached_local_aabb = _compute_combined_local_aabb(model_asset_root)
	if _cached_local_aabb.size.y <= 0.0001:
		_base_fit_scale = 1.0
		return
	_base_fit_scale = TARGET_PLAYER_HEIGHT_BLOCKS / _cached_local_aabb.size.y

func _update_cached_camera_metrics() -> void:
	_cached_local_aabb = get_current_local_aabb()
	if _cached_local_aabb.size.y <= 0.0001:
		_cached_eye_height = 1.62
		_cached_focus_height = 1.42
		return
	var current_height: float = _cached_local_aabb.size.y
	var base_eye_height: float = _cached_local_aabb.position.y + current_height * DEFAULT_EYE_HEIGHT_RATIO
	var base_focus_height: float = _cached_local_aabb.position.y + current_height * 0.79
	_cached_eye_height = clampf(base_eye_height, 1.58, 2.08)
	_cached_focus_height = clampf(base_focus_height, 1.28, 1.92)

func _normalize_name(node_name: String) -> String:
	return node_name.to_lower().replace(" ", "").replace("_", "")

func _create_clothing_anchors() -> void:
	for slot_name in clothing_anchors.keys():
		var old_anchor: Node = clothing_anchors[slot_name] as Node
		if old_anchor != null:
			old_anchor.queue_free()
	clothing_anchors.clear()
	for slot_name in CLOTHING_SLOTS.keys():
		var body_name: String = str(CLOTHING_SLOTS[slot_name])
		var body_node: Node3D = body_parts.get(body_name, null) as Node3D
		if body_node == null:
			continue
		var anchor := Node3D.new()
		anchor.name = "%s_Anchor" % slot_name
		body_node.add_child(anchor)
		clothing_anchors[slot_name] = anchor

func _store_base_scales() -> void:
	_body_part_base_scales.clear()
	for key in body_parts.keys():
		var node: Node3D = body_parts[key] as Node3D
		if node != null:
			_body_part_base_scales[key] = node.scale

func _restore_base_scales() -> void:
	for key in _body_part_base_scales.keys():
		var node: Node3D = body_parts.get(key, null) as Node3D
		if node != null:
			node.scale = _body_part_base_scales[key]

func _get_profile_string(key: String, fallback: String) -> String:
	if appearance_profile == null:
		return fallback
	var value: Variant = appearance_profile.get(key)
	if typeof(value) == TYPE_NIL:
		return fallback
	return str(value)

func _get_profile_float(key: String, fallback: float) -> float:
	if appearance_profile == null:
		return fallback
	var value: Variant = appearance_profile.get(key)
	if typeof(value) == TYPE_NIL:
		return fallback
	return float(value)

func _get_profile_color(key: String, fallback: Color) -> Color:
	if appearance_profile == null:
		return fallback
	var value: Variant = appearance_profile.get(key)
	if value is Color:
		return value
	if value is Array:
		var arr: Array = value as Array
		if arr.size() >= 4:
			return Color(float(arr[0]), float(arr[1]), float(arr[2]), float(arr[3]))
		if arr.size() >= 3:
			return Color(float(arr[0]), float(arr[1]), float(arr[2]), 1.0)
	return fallback

func _get_height_scale() -> float:
	var meters: float = _get_profile_float("height_meters", DEFAULT_HEIGHT_METERS)
	return meters / DEFAULT_HEIGHT_METERS

func _recenter_model_to_origin() -> void:
	if model_asset_root == null:
		return
	var aabb: AABB = _compute_combined_local_aabb(model_asset_root)
	if aabb.size == Vector3.ZERO:
		return
	var center_x: float = aabb.position.x + aabb.size.x * 0.5
	var center_z: float = aabb.position.z + aabb.size.z * 0.5
	model_asset_root.position = Vector3(-center_x, -aabb.position.y, -center_z)

func _compute_combined_local_aabb(root_node: Node3D) -> AABB:
	var result: Dictionary = _compute_local_aabb_recursive(root_node, Transform3D.IDENTITY)
	if bool(result.get("has_any", false)):
		var result_aabb_v: Variant = result.get("aabb", AABB(Vector3.ZERO, Vector3.ZERO))
		if typeof(result_aabb_v) == TYPE_AABB:
			return result_aabb_v
	return AABB(Vector3.ZERO, Vector3.ZERO)

func _compute_local_aabb_recursive(node: Node3D, parent_xform: Transform3D) -> Dictionary:
	var combined: AABB = AABB(Vector3.ZERO, Vector3.ZERO)
	var has_any: bool = false
	var local_xform: Transform3D = parent_xform * node.transform
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance != null and mesh_instance.mesh != null:
			combined = _transform_aabb(local_xform, mesh_instance.get_aabb())
			has_any = true
	for child in node.get_children():
		if child is Node3D:
			var child_result: Dictionary = _compute_local_aabb_recursive(child as Node3D, local_xform)
			if bool(child_result.get("has_any", false)):
				var child_aabb_v: Variant = child_result.get("aabb", AABB(Vector3.ZERO, Vector3.ZERO))
				if typeof(child_aabb_v) != TYPE_AABB:
					continue
				var child_aabb: AABB = child_aabb_v
				if not has_any:
					combined = child_aabb
					has_any = true
				else:
					combined = combined.merge(child_aabb)
	return {"has_any": has_any, "aabb": combined}

func _transform_aabb(xform: Transform3D, source: AABB) -> AABB:
	var corners: Array = [
		source.position,
		source.position + Vector3(source.size.x, 0.0, 0.0),
		source.position + Vector3(0.0, source.size.y, 0.0),
		source.position + Vector3(0.0, 0.0, source.size.z),
		source.position + Vector3(source.size.x, source.size.y, 0.0),
		source.position + Vector3(source.size.x, 0.0, source.size.z),
		source.position + Vector3(0.0, source.size.y, source.size.z),
		source.position + source.size
	]
	var first: bool = true
	var min_v: Vector3 = Vector3.ZERO
	var max_v: Vector3 = Vector3.ZERO
	for corner_v in corners:
		var p: Vector3 = xform * corner_v
		if first:
			first = false
			min_v = p
			max_v = p
		else:
			min_v = min_v.min(p)
			max_v = max_v.max(p)
	return AABB(min_v, max_v - min_v)
