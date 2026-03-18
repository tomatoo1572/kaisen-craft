extends Node3D

const MALE_DEFAULT_MODEL_PATH := "res://assets/models/player/male/default/kaizencraftplayer.glb"
const FEMALE_DEFAULT_MODEL_PATH := "res://assets/models/player/female/default/kaizencraftplayer.glb"
const TARGET_PLAYER_HEIGHT_BLOCKS := 1.8

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


func _ready() -> void:
	if appearance_profile == null:
		var app_script: Script = load("res://player/CharacterAppearance.gd") as Script
		if app_script != null:
			appearance_profile = app_script.new()
	ensure_model_loaded()

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
	var sex: String = _get_profile_string("sex", "male")
	var build: String = _get_profile_string("build", "base")
	var height_scale: float = _get_profile_float("height_scale", 1.0)
	var width_scale: float = _get_profile_float("width_scale", 1.0)
	var body_weight: float = _get_profile_float("body_weight", 0.0)

	var torso_scale: Vector3 = Vector3.ONE
	var waist_scale: Vector3 = Vector3.ONE
	var arm_scale: Vector3 = Vector3.ONE
	var forearm_scale: Vector3 = Vector3.ONE
	var leg_scale: Vector3 = Vector3.ONE
	var calf_scale: Vector3 = Vector3.ONE
	var head_scale: Vector3 = Vector3.ONE

	match build:
		"slim":
			torso_scale = Vector3(0.93, 1.0, 0.93)
			waist_scale = Vector3(0.90, 1.0, 0.88)
			arm_scale = Vector3(0.92, 1.0, 0.92)
			forearm_scale = Vector3(0.92, 1.0, 0.92)
			leg_scale = Vector3(0.94, 1.0, 0.94)
			calf_scale = Vector3(0.94, 1.0, 0.94)
		"shredded":
			torso_scale = Vector3(1.10, 1.04, 1.08)
			waist_scale = Vector3(1.03, 1.0, 1.00)
			arm_scale = Vector3(1.12, 1.02, 1.10)
			forearm_scale = Vector3(1.08, 1.0, 1.06)
			leg_scale = Vector3(1.08, 1.02, 1.06)
			calf_scale = Vector3(1.04, 1.0, 1.04)
			head_scale = Vector3(1.01, 1.0, 1.01)
		"fat":
			torso_scale = Vector3(1.16, 1.03, 1.18)
			waist_scale = Vector3(1.20, 1.0, 1.24)
			arm_scale = Vector3(1.12, 1.0, 1.12)
			forearm_scale = Vector3(1.10, 1.0, 1.10)
			leg_scale = Vector3(1.14, 1.0, 1.14)
			calf_scale = Vector3(1.10, 1.0, 1.10)
			head_scale = Vector3(1.02, 1.0, 1.02)
		_:
			pass

	if sex == "female":
		torso_scale *= Vector3(0.96, 1.0, 0.96)
		waist_scale *= Vector3(0.94, 1.0, 0.96)
		leg_scale *= Vector3(0.98, 1.0, 0.98)
		arm_scale *= Vector3(0.95, 1.0, 0.95)

	var weight_push: float = body_weight * 0.08
	torso_scale.x += weight_push
	torso_scale.z += weight_push
	waist_scale.x += weight_push * 1.4
	waist_scale.z += weight_push * 1.6
	arm_scale.x += weight_push * 0.65
	arm_scale.z += weight_push * 0.65
	forearm_scale.x += weight_push * 0.55
	forearm_scale.z += weight_push * 0.55
	leg_scale.x += weight_push * 0.75
	leg_scale.z += weight_push * 0.75
	calf_scale.x += weight_push * 0.60
	calf_scale.z += weight_push * 0.60

	_apply_part_scale("head", head_scale)
	_apply_part_scale("torso_upper", torso_scale)
	_apply_part_scale("torso_lower", torso_scale)
	_apply_part_scale("waist", waist_scale)
	_apply_part_scale("arm_upper_l", arm_scale)
	_apply_part_scale("arm_upper_r", arm_scale)
	_apply_part_scale("arm_lower_l", forearm_scale)
	_apply_part_scale("arm_lower_r", forearm_scale)
	_apply_part_scale("hand_l", Vector3(1.0 + weight_push * 0.2, 1.0, 1.0 + weight_push * 0.2))
	_apply_part_scale("hand_r", Vector3(1.0 + weight_push * 0.2, 1.0, 1.0 + weight_push * 0.2))
	_apply_part_scale("leg_upper_l", leg_scale)
	_apply_part_scale("leg_upper_r", leg_scale)
	_apply_part_scale("leg_lower_l", calf_scale)
	_apply_part_scale("leg_lower_r", calf_scale)
	_apply_part_scale("foot_l", Vector3(1.0 + weight_push * 0.1, 1.0, 1.0 + weight_push * 0.1))
	_apply_part_scale("foot_r", Vector3(1.0 + weight_push * 0.1, 1.0, 1.0 + weight_push * 0.1))

	var root_scale: Vector3 = Vector3(_base_fit_scale * width_scale, _base_fit_scale * height_scale, _base_fit_scale * width_scale)
	model_asset_root.scale = root_scale
	_recenter_model_to_origin()
	set_first_person_hidden(first_person_hidden)

func set_look_pitch(pitch_radians: float) -> void:
	var head_node: Node3D = body_parts.get("head", null) as Node3D
	if head_node != null:
		head_node.rotation.x = clampf(-pitch_radians * 0.55, deg_to_rad(-50.0), deg_to_rad(40.0))
	var torso_node: Node3D = body_parts.get("torso_upper", null) as Node3D
	if torso_node != null:
		torso_node.rotation.x = clampf(-pitch_radians * 0.14, deg_to_rad(-12.0), deg_to_rad(12.0))

func set_first_person_hidden(hidden: bool) -> void:
	first_person_hidden = hidden
	if model_scene_root == null:
		return
	if hidden and _first_person_body_visible:
		model_scene_root.visible = true
		_set_head_visibility(false)
	else:
		model_scene_root.visible = not hidden
		_set_head_visibility(true)

func set_first_person_body_visible(enabled: bool) -> void:
	_first_person_body_visible = enabled
	set_first_person_hidden(first_person_hidden)

func _set_head_visibility(visible_value: bool) -> void:
	var head_node: Node3D = body_parts.get("head", null) as Node3D
	if head_node == null:
		return
	head_node.visible = visible_value
	for child in head_node.get_children():
		if child is Node3D:
			(child as Node3D).visible = visible_value

func get_body_part(name: String) -> Node3D:
	return body_parts.get(name, null) as Node3D

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
		"builds": ["base", "slim", "shredded", "fat"],
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
	_create_clothing_anchors()
	_store_base_scales()
	_refresh_base_fit_scale()
	model_asset_root.scale = Vector3.ONE * _base_fit_scale
	_recenter_model_to_origin()
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
		var norm_name: String = _normalize_name(node.name)
		var score: int = -1000
		for alias_v in aliases:
			var alias: String = _normalize_name(str(alias_v))
			if norm_name == alias:
				score = max(score, 100)
			elif norm_name.begins_with(alias):
				score = max(score, 60)
			elif alias in norm_name:
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
		return
	var aabb: AABB = _compute_combined_local_aabb(model_asset_root)
	if aabb.size.y <= 0.0001:
		_base_fit_scale = 1.0
		return
	_base_fit_scale = TARGET_PLAYER_HEIGHT_BLOCKS / aabb.size.y

func _normalize_name(name: String) -> String:
	return name.to_lower().replace(" ", "").replace("_", "")

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

func _apply_part_scale(part_name: String, scale_multiplier: Vector3) -> void:
	var node: Node3D = body_parts.get(part_name, null) as Node3D
	if node == null:
		return
	var base_scale_v: Variant = _body_part_base_scales.get(part_name, Vector3.ONE)
	var base_scale: Vector3 = base_scale_v
	node.scale = Vector3(base_scale.x * scale_multiplier.x, base_scale.y * scale_multiplier.y, base_scale.z * scale_multiplier.z)

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
	var has_any: bool = false
	var combined: AABB = AABB(Vector3.ZERO, Vector3.ZERO)
	var root_inverse: Transform3D = root_node.global_transform.affine_inverse()
	var meshes: Array = []
	_collect_meshes(root_node, meshes)
	for mesh_v in meshes:
		var mesh_instance: MeshInstance3D = mesh_v as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var local_box: AABB = mesh_instance.get_aabb()
		var transformed_box: AABB = _transform_aabb(root_inverse * mesh_instance.global_transform, local_box)
		if not has_any:
			combined = transformed_box
			has_any = true
		else:
			combined = combined.merge(transformed_box)
	return combined if has_any else AABB(Vector3.ZERO, Vector3.ZERO)

func _collect_meshes(node: Node, out_meshes: Array) -> void:
	if node is MeshInstance3D:
		out_meshes.append(node)
	for child in node.get_children():
		_collect_meshes(child, out_meshes)

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
	for corner in corners:
		var p: Vector3 = xform * corner
		if first:
			first = false
			min_v = p
			max_v = p
		else:
			min_v = min_v.min(p)
			max_v = max_v.max(p)
	return AABB(min_v, max_v - min_v)
