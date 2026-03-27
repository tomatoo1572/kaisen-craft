extends Node3D
class_name KZ_VoxelWorldManager

const GENERATOR_SCRIPT_PATH := "res://world/KZVoxelGenerator.gd"

var server: Node = null
var worldgen_cfg: Dictionary = {}
var registry: KZ_BlockRegistry = null

var dims: Vector3i = Vector3i(16, 256, 16)
var view_distance: int = 6

var player: Node3D = null
var terrain: Node3D = null
var viewer: Node = null
var generator: KZ_VoxelGenerator = null
var _voxel_tool: Object = null

var _materials: Array[StandardMaterial3D] = []
var _material_base_tints: Dictionary = {}
var _day_night_tint: Color = Color(1, 1, 1, 1)

func setup(p_server: Node, p_worldgen_cfg: Dictionary) -> void:
	server = p_server
	worldgen_cfg = p_worldgen_cfg
	registry = null
	if server != null and server.get("registry") is KZ_BlockRegistry:
		registry = server.get("registry") as KZ_BlockRegistry
	else:
		var game: Node = get_node_or_null("/root/Game")
		if game != null and game.get("block_registry") is KZ_BlockRegistry:
			registry = game.get("block_registry") as KZ_BlockRegistry

	var wg: Dictionary = {}
	if worldgen_cfg.get("worldgen", {}) is Dictionary:
		wg = worldgen_cfg.get("worldgen", {}) as Dictionary
	dims = Vector3i(
		int(wg.get("chunk_size_x", 16)),
		int(wg.get("chunk_size_y", 256)),
		int(wg.get("chunk_size_z", 16))
	)
	view_distance = clampi(int(wg.get("view_distance_chunks", 6)), 4, 16)

	_rebuild_terrain()
	_connect_server_signals()

func set_player(p: Node3D) -> void:
	player = p
	_attach_viewer_to_player()

func set_view_distance(chunks: int) -> void:
	view_distance = clampi(chunks, 4, 16)
	_set_prop_if_present(terrain, "view_distance", view_distance)

func set_day_night_tint(tint: Color) -> void:
	_day_night_tint = tint
	for mat in _materials:
		var base_tint: Color = _material_base_tints.get(mat, Color(1, 1, 1, 1))
		mat.albedo_color = Color(base_tint.r * tint.r, base_tint.g * tint.g, base_tint.b * tint.b, base_tint.a)

func set_celestial_lighting(_sun_dir: Vector3, _moon_dir: Vector3, _sun_strength: float, _moon_strength: float, _ambient: Color) -> void:
	pass

func _exit_tree() -> void:
	if viewer != null:
		viewer.queue_free()
		viewer = null

func _rebuild_terrain() -> void:
	if terrain != null:
		terrain.queue_free()
		terrain = null
		_voxel_tool = null

	if not ClassDB.can_instantiate("VoxelTerrain"):
		push_error("Voxel Tools plugin not loaded: VoxelTerrain class unavailable.")
		return

	terrain = ClassDB.instantiate("VoxelTerrain") as Node3D
	if terrain == null:
		push_error("Could not instantiate VoxelTerrain.")
		return
	terrain.name = "VoxelTerrain"
	add_child(terrain)

	_set_prop_if_present(terrain, "view_distance", view_distance)
	_set_prop_if_present(terrain, "view_distance_vertical_ratio", 0.6)
	_set_prop_if_present(terrain, "mesh_block_size", dims.x)
	_set_prop_if_present(terrain, "streaming_system", 1)
	if terrain.has_method("set_mesh_collision_enabled"):
		terrain.call("set_mesh_collision_enabled", false)

	var gen_script: Script = load(GENERATOR_SCRIPT_PATH) as Script
	if gen_script == null:
		push_error("Could not load voxel generator script: %s" % GENERATOR_SCRIPT_PATH)
		return
	generator = gen_script.new() as KZ_VoxelGenerator
	if generator == null:
		push_error("Could not instantiate voxel generator.")
		return
	generator.configure(worldgen_cfg, registry)
	if server != null:
		var edits_v: Variant = server.get("_chunk_edits")
		if edits_v is Dictionary:
			generator.set_chunk_edits_snapshot(edits_v as Dictionary)
	terrain.set("generator", generator)

	var mesher: Resource = ClassDB.instantiate("VoxelMesherBlocky") as Resource
	var library: Resource = _build_block_library()
	if mesher != null and library != null:
		mesher.set("library", library)
		terrain.set("mesher", mesher)

	if terrain.has_method("get_voxel_tool"):
		_voxel_tool = terrain.call("get_voxel_tool")
		if _voxel_tool != null:
			_voxel_tool.set("channel", VoxelBuffer.CHANNEL_TYPE)

	_attach_viewer_to_player()

func _build_block_library() -> Resource:
	if registry == null or not ClassDB.can_instantiate("VoxelBlockyLibrary"):
		return null

	var entries: Array[Dictionary] = registry.get_registered_entries()
	var texture_paths: Array[String] = _collect_texture_paths(entries)
	var atlas_info: Dictionary = _build_runtime_atlas(texture_paths)
	var atlas_texture: Texture2D = atlas_info.get("texture") as Texture2D
	var tile_map: Dictionary = atlas_info.get("tiles", {}) as Dictionary
	var atlas_tiles_per_side: int = int(atlas_info.get("tiles_per_side", 1))

	var opaque_mat: StandardMaterial3D = _make_block_material(atlas_texture, BaseMaterial3D.TRANSPARENCY_DISABLED, 1.0)
	var alpha_clip_mat: StandardMaterial3D = _make_block_material(atlas_texture, BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR, 0.5)
	var water_mat: StandardMaterial3D = _make_block_material(atlas_texture, BaseMaterial3D.TRANSPARENCY_ALPHA, 0.25)
	water_mat.albedo_color = Color(1, 1, 1, 0.78)

	_materials = [opaque_mat, alpha_clip_mat, water_mat]
	_material_base_tints = {
		opaque_mat: Color(1, 1, 1, 1),
		alpha_clip_mat: Color(1, 1, 1, 1),
		water_mat: Color(1, 1, 1, 0.78)
	}
	set_day_night_tint(_day_night_tint)

	var library: Resource = ClassDB.instantiate("VoxelBlockyLibrary") as Resource
	if library == null:
		return null

	var empty_model: Resource = ClassDB.instantiate("VoxelBlockyModelEmpty") as Resource
	var models: Array[Resource] = []
	models.resize(entries.size())
	for i in range(models.size()):
		models[i] = empty_model

	for entry_v in entries:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_v as Dictionary
		var rid: int = int(entry.get("runtime_id", 0))
		var sid: String = str(entry.get("string_id", ""))
		if rid == 0:
			models[rid] = empty_model
			continue
		var def: KZ_BlockRegistry.BlockDef = registry.get_def_by_runtime(rid)
		if def == null or not def.placeable:
			models[rid] = empty_model
			continue

		var cube: Resource = ClassDB.instantiate("VoxelBlockyModelCube") as Resource
		if cube == null:
			continue
		cube.set("atlas_size_in_tiles", atlas_tiles_per_side)
		cube.set("tile_top", tile_map.get(def.texture_top_path, Vector2i.ZERO))
		cube.set("tile_bottom", tile_map.get(def.texture_bottom_path, Vector2i.ZERO))
		cube.set("tile_front", tile_map.get(def.texture_side_path, Vector2i.ZERO))
		cube.set("tile_back", tile_map.get(def.texture_side_path, Vector2i.ZERO))
		cube.set("tile_left", tile_map.get(def.texture_side_path, Vector2i.ZERO))
		cube.set("tile_right", tile_map.get(def.texture_side_path, Vector2i.ZERO))
		cube.set("culls_neighbors", sid != "kaizencraft:oak_leaves" and sid != "kaizencraft:water")
		if sid == "kaizencraft:oak_leaves":
			cube.set("material_override", alpha_clip_mat)
			cube.set("transparency_index", 1)
		elif sid == "kaizencraft:water":
			cube.set("material_override", water_mat)
			cube.set("transparency_index", 2)
		else:
			cube.set("material_override", opaque_mat)
			cube.set("transparency_index", 0)
		models[rid] = cube

	library.set("models", models)
	if library.has_method("bake"):
		library.call("bake")
	return library

func _collect_texture_paths(entries: Array[Dictionary]) -> Array[String]:
	var found: Dictionary = {}
	for entry_v in entries:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_v as Dictionary
		var rid: int = int(entry.get("runtime_id", 0))
		if rid == 0:
			continue
		var def: KZ_BlockRegistry.BlockDef = registry.get_def_by_runtime(rid)
		if def == null or not def.placeable:
			continue
		for path in [def.texture_top_path, def.texture_bottom_path, def.texture_side_path]:
			var p: String = str(path)
			if p != "" and ResourceLoader.exists(p):
				found[p] = true
	var out: Array[String] = []
	for k in found.keys():
		out.append(str(k))
	out.sort()
	return out

func _build_runtime_atlas(texture_paths: Array[String]) -> Dictionary:
	var tile_size: int = 32
	var tiles_per_side: int = maxi(1, int(ceil(sqrt(float(maxi(1, texture_paths.size()))))))
	var atlas_image: Image = Image.create(tile_size * tiles_per_side, tile_size * tiles_per_side, false, Image.FORMAT_RGBA8)
	atlas_image.fill(Color(0, 0, 0, 0))
	var tile_map: Dictionary = {}
	for i in range(texture_paths.size()):
		var tex_path: String = texture_paths[i]
		var tex: Texture2D = load(tex_path) as Texture2D
		if tex == null:
			continue
		var image: Image = tex.get_image()
		if image == null:
			continue
		if image.get_width() != tile_size or image.get_height() != tile_size:
			image.resize(tile_size, tile_size, Image.INTERPOLATE_NEAREST)
		var tx: int = i % tiles_per_side
		var ty: int = int(i / tiles_per_side)
		atlas_image.blit_rect(image, Rect2i(0, 0, tile_size, tile_size), Vector2i(tx * tile_size, ty * tile_size))
		tile_map[tex_path] = Vector2i(tx, ty)
	var atlas_texture: ImageTexture = ImageTexture.create_from_image(atlas_image)
	return {
		"texture": atlas_texture,
		"tiles": tile_map,
		"tiles_per_side": tiles_per_side
	}

func _make_block_material(atlas_texture: Texture2D, transparency: BaseMaterial3D.Transparency, alpha_scissor_threshold: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = atlas_texture
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.texture_repeat = true
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.metallic = 0.0
	mat.transparency = transparency
	mat.alpha_scissor_threshold = alpha_scissor_threshold
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	return mat

func _attach_viewer_to_player() -> void:
	if player == null or not ClassDB.can_instantiate("VoxelViewer"):
		return
	var target_parent: Node = player
	if player.has_method("get"):
		var cam_v: Variant = player.get("cam")
		if cam_v is Node:
			target_parent = cam_v as Node
	if viewer != null and viewer.get_parent() != target_parent:
		viewer.queue_free()
		viewer = null
	if viewer == null:
		viewer = ClassDB.instantiate("VoxelViewer") as Node
		if viewer == null:
			return
		viewer.name = "VoxelViewer"
		target_parent.add_child(viewer)

func _connect_server_signals() -> void:
	if server == null:
		return
	if server.has_signal("block_broken") and not server.is_connected("block_broken", Callable(self, "_on_server_block_broken")):
		server.connect("block_broken", Callable(self, "_on_server_block_broken"))
	if server.has_signal("block_placed") and not server.is_connected("block_placed", Callable(self, "_on_server_block_placed")):
		server.connect("block_placed", Callable(self, "_on_server_block_placed"))

func _on_server_block_broken(world_block: Vector3i, _runtime_id: int) -> void:
	_apply_voxel_edit(world_block, 0)

func _on_server_block_placed(world_block: Vector3i, runtime_id: int) -> void:
	_apply_voxel_edit(world_block, runtime_id)

func _apply_voxel_edit(world_block: Vector3i, runtime_id: int) -> void:
	if generator != null:
		generator.set_block_edit_world(world_block.x, world_block.y, world_block.z, runtime_id)
	if _voxel_tool != null:
		_voxel_tool.call("set_voxel", runtime_id, world_block.x, world_block.y, world_block.z)


func _set_prop_if_present(obj: Object, prop: StringName, value: Variant) -> void:
	if obj == null:
		return
	for prop_info_v in obj.get_property_list():
		if typeof(prop_info_v) != TYPE_DICTIONARY:
			continue
		var prop_info: Dictionary = prop_info_v as Dictionary
		if StringName(prop_info.get("name", "")) == prop:
			obj.set(prop, value)
			return
