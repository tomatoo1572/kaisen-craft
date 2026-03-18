extends Node3D

const CHUNK_SCRIPT_PATH := "res://world/Chunk.gd"

var server
var worldgen_cfg: Dictionary = {}

var dims: Vector3i = Vector3i(16, 256, 16)
var view_distance: int = 6

var player: Node3D

var _chunks: Dictionary = {}
var _requested: Dictionary = {}
var _retry_after_ms: Dictionary = {}

var request_budget_per_frame: int = 2
var initial_burst_target_loaded: int = 8
var initial_burst_budget_per_frame: int = 3

var debug_wireframe: bool = false
var _terrain_mat: Material
var _flora_mat: Material
var _water_mat: Material
var _day_night_tint: Color = Color(1, 1, 1, 1)
var _sun_dir: Vector3 = Vector3(0.2, 1.0, -0.3).normalized()
var _moon_dir: Vector3 = Vector3(-0.2, -1.0, 0.3).normalized()
var _sun_strength: float = 1.0
var _moon_strength: float = 0.0
var _ambient_tint: Color = Color(0.7, 0.75, 0.85, 1.0)

func setup(p_server, p_worldgen_cfg: Dictionary) -> void:
	server = p_server
	worldgen_cfg = p_worldgen_cfg

	var wg_v: Variant = worldgen_cfg.get("worldgen", {})
	var wg: Dictionary = wg_v as Dictionary

	dims = Vector3i(
		int(wg.get("chunk_size_x", 16)),
		int(wg.get("chunk_size_y", 256)),
		int(wg.get("chunk_size_z", 16))
	)
	view_distance = int(wg.get("view_distance_chunks", 6))

	_build_chunk_materials()

	RenderingServer.set_debug_generate_wireframes(false)
	if is_inside_tree() and get_viewport() != null:
		get_viewport().debug_draw = Viewport.DEBUG_DRAW_DISABLED as Viewport.DebugDraw

	if server != null and not server.chunk_mesh_updated.is_connected(Callable(self, "_on_server_chunk_mesh_updated")):
		server.chunk_mesh_updated.connect(Callable(self, "_on_server_chunk_mesh_updated"))

func _build_chunk_materials() -> void:
	_terrain_mat = _build_shader_material("res://assets/shaders/terrain_grass.gdshader")
	_flora_mat = _build_shader_material("res://assets/shaders/terrain_flora.gdshader")
	_water_mat = _build_shader_material("res://assets/shaders/terrain_water.gdshader")

	if _terrain_mat == null:
		var terrain_fallback := StandardMaterial3D.new()
		terrain_fallback.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		terrain_fallback.cull_mode = BaseMaterial3D.CULL_DISABLED
		terrain_fallback.albedo_color = Color(1, 1, 1, 1)
		terrain_fallback.vertex_color_use_as_albedo = true
		terrain_fallback.texture_repeat = true
		terrain_fallback.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST as BaseMaterial3D.TextureFilter
		_terrain_mat = terrain_fallback

	if _flora_mat == null:
		var flora_fallback := StandardMaterial3D.new()
		flora_fallback.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flora_fallback.cull_mode = BaseMaterial3D.CULL_DISABLED
		flora_fallback.albedo_color = Color(1, 1, 1, 1)
		flora_fallback.vertex_color_use_as_albedo = true
		flora_fallback.texture_repeat = true
		flora_fallback.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST as BaseMaterial3D.TextureFilter
		_flora_mat = flora_fallback

	if _water_mat == null:
		var water_fallback := StandardMaterial3D.new()
		water_fallback.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		water_fallback.cull_mode = BaseMaterial3D.CULL_DISABLED
		water_fallback.albedo_color = Color(0.36, 0.62, 0.95, 0.72)
		water_fallback.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		water_fallback.texture_repeat = true
		water_fallback.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST as BaseMaterial3D.TextureFilter
		_water_mat = water_fallback

func _build_shader_material(shader_path: String) -> Material:
	var shader_res: Shader = load(shader_path) as Shader
	if shader_res == null:
		return null

	var mat := ShaderMaterial.new()
	mat.shader = shader_res
	mat.set_shader_parameter("grass_side_tex", _load_tex("res://assets/textures/blocks/grass_side.png"))
	mat.set_shader_parameter("grass_top_tex", _load_tex("res://assets/textures/blocks/grass_top.png"))
	mat.set_shader_parameter("dirt_tex", _load_tex("res://assets/textures/blocks/dirt.png"))
	mat.set_shader_parameter("log_side_tex", _load_tex("res://assets/textures/blocks/oak_log.png"))
	mat.set_shader_parameter("log_top_tex", _load_tex("res://assets/textures/blocks/oak_log_top.png"))
	mat.set_shader_parameter("leaves_tex", _load_tex("res://assets/textures/blocks/oak_leaves.png"))
	mat.set_shader_parameter("oak_planks_tex", _load_tex("res://assets/textures/blocks/oak_planks.png"))
	mat.set_shader_parameter("crafting_table_side_tex", _load_tex("res://assets/textures/blocks/crafting_table_side.png"))
	mat.set_shader_parameter("crafting_table_top_tex", _load_tex("res://assets/textures/blocks/crafting_table_top.png"))
	mat.set_shader_parameter("water_tex", _load_tex("res://assets/textures/blocks/water.png"))
	mat.set_shader_parameter("sand_tex", _load_tex("res://assets/textures/blocks/sand.png"))
	mat.set_shader_parameter("stone_tex", _load_tex("res://assets/textures/blocks/stone.png"))
	mat.set_shader_parameter("day_night_tint", Vector3(_day_night_tint.r, _day_night_tint.g, _day_night_tint.b))
	mat.set_shader_parameter("sun_dir", _sun_dir)
	mat.set_shader_parameter("moon_dir", _moon_dir)
	mat.set_shader_parameter("sun_strength", _sun_strength)
	mat.set_shader_parameter("moon_strength", _moon_strength)
	mat.set_shader_parameter("ambient_tint", Vector3(_ambient_tint.r, _ambient_tint.g, _ambient_tint.b))
	return mat

func _load_tex(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func set_day_night_tint(tint: Color) -> void:
	_day_night_tint = tint
	_apply_material_tint(_terrain_mat, tint)
	_apply_material_tint(_flora_mat, tint)
	_apply_material_tint(_water_mat, tint)

func _apply_material_tint(mat: Material, tint: Color) -> void:
	if mat == null:
		return
	if mat is ShaderMaterial:
		var sm: ShaderMaterial = mat as ShaderMaterial
		sm.set_shader_parameter("day_night_tint", Vector3(tint.r, tint.g, tint.b))
		sm.set_shader_parameter("sun_dir", _sun_dir)
		sm.set_shader_parameter("moon_dir", _moon_dir)
		sm.set_shader_parameter("sun_strength", _sun_strength)
		sm.set_shader_parameter("moon_strength", _moon_strength)
		sm.set_shader_parameter("ambient_tint", Vector3(_ambient_tint.r, _ambient_tint.g, _ambient_tint.b))
	elif mat is BaseMaterial3D:
		(mat as BaseMaterial3D).albedo_color = tint

func set_celestial_lighting(sun_dir: Vector3, moon_dir: Vector3, sun_strength: float, moon_strength: float, ambient: Color) -> void:
	_sun_dir = sun_dir
	_moon_dir = moon_dir
	_sun_strength = sun_strength
	_moon_strength = moon_strength
	_ambient_tint = ambient
	_apply_material_tint(_terrain_mat, _day_night_tint)
	_apply_material_tint(_flora_mat, _day_night_tint)
	_apply_material_tint(_water_mat, _day_night_tint)

func set_view_distance(chunks: int) -> void:
	view_distance = clampi(chunks, 2, 16)

func set_player(p: Node3D) -> void:
	player = p

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_F3:
			debug_wireframe = not debug_wireframe
			RenderingServer.set_debug_generate_wireframes(debug_wireframe)
			if debug_wireframe:
				get_viewport().debug_draw = Viewport.DEBUG_DRAW_WIREFRAME as Viewport.DebugDraw
			else:
				get_viewport().debug_draw = Viewport.DEBUG_DRAW_DISABLED as Viewport.DebugDraw

func _process(_dt: float) -> void:
	if player == null or server == null:
		return

	var pc: Vector2i = _world_to_chunk(player.global_position)
	var needed: Dictionary = _compute_needed(pc, view_distance)

	var to_request: Array[Vector2i] = []
	var now_ms: int = Time.get_ticks_msec()

	var needed_keys: Array = needed.keys()
	for i in range(needed_keys.size()):
		var c_v: Variant = needed_keys[i]
		if typeof(c_v) != TYPE_VECTOR2I:
			continue
		var c: Vector2i = c_v as Vector2i

		if _chunks.has(c) or _requested.has(c):
			continue

		if _retry_after_ms.has(c):
			var until_ms: int = int(_retry_after_ms[c])
			if now_ms < until_ms:
				continue
			_retry_after_ms.erase(c)

		to_request.append(c)

	_sort_chunk_positions_by_distance(to_request, pc)

	var budget: int = request_budget_per_frame
	if _chunks.size() < initial_burst_target_loaded:
		budget = initial_burst_budget_per_frame

	var count: int = 0
	for c in to_request:
		if count >= budget:
			break
		_requested[c] = true
		server.request_chunk(c, Callable(self, "_on_chunk_ready"))
		count += 1

	var to_unload: Array[Vector2i] = []
	var chunk_keys: Array = _chunks.keys()
	for i in range(chunk_keys.size()):
		var c_v2: Variant = chunk_keys[i]
		if typeof(c_v2) != TYPE_VECTOR2I:
			continue
		var c2: Vector2i = c_v2 as Vector2i
		if not needed.has(c2):
			to_unload.append(c2)

	for c3 in to_unload:
		var ch: Node = _chunks[c3] as Node
		_chunks.erase(c3)
		if ch != null:
			ch.queue_free()

func _on_chunk_ready(result: Dictionary) -> void:
	var cpos: Vector2i = Vector2i.ZERO
	var has_pos: bool = false

	var cpos_v: Variant = result.get("chunk_pos")
	if typeof(cpos_v) == TYPE_VECTOR2I:
		cpos = cpos_v as Vector2i
		has_pos = true
		_requested.erase(cpos)

	if result.has("error"):
		if has_pos:
			_retry_after_ms[cpos] = Time.get_ticks_msec() + 500
		return

	if not has_pos:
		return
	if _chunks.has(cpos):
		return

	var origin_v: Variant = result.get("origin")
	if typeof(origin_v) != TYPE_VECTOR3:
		return
	var origin: Vector3 = origin_v as Vector3

	var arrays_v: Variant = result.get("mesh_arrays")
	if typeof(arrays_v) != TYPE_DICTIONARY:
		return
	var arrays: Dictionary = arrays_v as Dictionary

	var chunk_script: Script = load(CHUNK_SCRIPT_PATH) as Script
	if chunk_script == null:
		push_error("Failed to load Chunk script: %s" % CHUNK_SCRIPT_PATH)
		return

	var ch: Variant = chunk_script.new()
	if ch == null:
		push_error("Failed to instantiate Chunk from: %s" % CHUNK_SCRIPT_PATH)
		return

	ch.set_chunk_pos(cpos)
	ch.position = origin
	add_child(ch)
	_chunks[cpos] = ch

	ch.set_mesh(_make_mesh(arrays))

func _on_server_chunk_mesh_updated(chunk_pos: Vector2i, mesh_arrays: Dictionary) -> void:
	if not _chunks.has(chunk_pos):
		return
	var ch: Node = _chunks[chunk_pos] as Node
	if ch == null:
		return
	ch.set_mesh(_make_mesh(mesh_arrays))

func _make_mesh(arrays: Dictionary) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var verts_v: Variant = arrays.get("vertices")
	if typeof(verts_v) != TYPE_PACKED_VECTOR3_ARRAY:
		return mesh

	var verts: PackedVector3Array = verts_v as PackedVector3Array
	if verts.is_empty():
		return mesh

	var normals: PackedVector3Array = arrays.get("normals", PackedVector3Array()) as PackedVector3Array
	var uvs: PackedVector2Array = arrays.get("uvs", PackedVector2Array()) as PackedVector2Array
	var colors: PackedColorArray = arrays.get("colors", PackedColorArray()) as PackedColorArray
	var src_indices: PackedInt32Array = arrays.get("indices", PackedInt32Array()) as PackedInt32Array

	var terrain := _split_surface_arrays(verts, normals, uvs, colors, src_indices, 0)
	var flora := _split_surface_arrays(verts, normals, uvs, colors, src_indices, 1)
	var water := _split_surface_arrays(verts, normals, uvs, colors, src_indices, 2)

	if not (terrain[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, terrain)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _terrain_mat)

	if not (flora[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, flora)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _flora_mat)

	if not (water[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, water)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _water_mat)

	return mesh

func _surface_kind_for_face_id(face_id: int) -> int:
	if face_id == 5:
		return 1
	if face_id == 9:
		return 2
	return 0

func _split_surface_arrays(
	verts: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	colors: PackedColorArray,
	src_indices: PackedInt32Array,
	surface_kind: int
) -> Array:
	var out_verts := PackedVector3Array()
	var out_normals := PackedVector3Array()
	var out_uvs := PackedVector2Array()
	var out_colors := PackedColorArray()
	var out_indices := PackedInt32Array()

	var quad_count: int = int(float(verts.size()) / 4.0)
	for q in range(quad_count):
		var src_i: int = q * 4
		if src_i >= colors.size():
			break
		var face_id: int = int(round(colors[src_i].r * 255.0))
		if _surface_kind_for_face_id(face_id) != surface_kind:
			continue

		var base: int = out_verts.size()
		for k in range(4):
			var si: int = src_i + k
			out_verts.append(verts[si])
			if si < normals.size():
				out_normals.append(normals[si])
			if si < uvs.size():
				out_uvs.append(uvs[si])
			if si < colors.size():
				out_colors.append(colors[si])

		var src_index_base: int = q * 6
		if src_index_base + 5 < src_indices.size():
			for ik in range(6):
				out_indices.append(base + (src_indices[src_index_base + ik] - src_i))
		else:
			out_indices.append(base)
			out_indices.append(base + 1)
			out_indices.append(base + 2)
			out_indices.append(base)
			out_indices.append(base + 2)
			out_indices.append(base + 3)

	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = out_verts
	a[Mesh.ARRAY_NORMAL] = out_normals
	a[Mesh.ARRAY_TEX_UV] = out_uvs
	a[Mesh.ARRAY_COLOR] = out_colors
	a[Mesh.ARRAY_INDEX] = out_indices
	return a

func _sort_chunk_positions_by_distance(list_in: Array[Vector2i], center: Vector2i) -> void:
	list_in.sort_custom(_compare_chunk_distance.bind(center))

func _compare_chunk_distance(a: Vector2i, b: Vector2i, center: Vector2i) -> bool:
	return a.distance_squared_to(center) < b.distance_squared_to(center)

func _world_to_chunk(pos: Vector3) -> Vector2i:
	var cx: int = int(floor(pos.x / float(dims.x)))
	var cz: int = int(floor(pos.z / float(dims.z)))
	return Vector2i(cx, cz)

func _compute_needed(center: Vector2i, radius: int) -> Dictionary:
	var needed_map: Dictionary = {}
	var r2: int = radius * radius
	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dz * dz <= r2:
				var p := Vector2i(center.x + dx, center.y + dz)
				needed_map[p] = true
	return needed_map
