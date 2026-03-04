extends Node3D
class_name KZ_WorldManager

var server: KZ_LocalWorldServer
var worldgen_cfg: Dictionary = {}

var dims: Vector3i = Vector3i(16, 256, 16)
var view_distance: int = 6

var player: Node3D

var _chunks: Dictionary = {}    # Vector2i -> KZ_Chunk
var _requested: Dictionary = {} # Vector2i -> bool

# Retry cooldown for failed chunk requests
var _retry_after_ms: Dictionary = {} # Vector2i -> int

# Streaming tuning (Stage 1)
var request_budget_per_frame: int = 16
var initial_burst_target_loaded: int = 80
var initial_burst_budget_per_frame: int = 80

# Debug
var debug_wireframe: bool = false
var debug_double_sided: bool = true   # START TRUE so you can confirm the “holes” are culling

func setup(p_server: KZ_LocalWorldServer, p_worldgen_cfg: Dictionary) -> void:
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

	RenderingServer.set_debug_generate_wireframes(true)
	_apply_materials_to_loaded_chunks()

func set_player(p: Node3D) -> void:
	player = p

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_F3:
			debug_wireframe = not debug_wireframe
			get_viewport().debug_draw = Viewport.DEBUG_DRAW_WIREFRAME if debug_wireframe else Viewport.DEBUG_DRAW_DISABLED

func _process(_dt: float) -> void:
	if player == null or server == null:
		return

	var pc: Vector2i = _world_to_chunk(player.global_position)
	var needed: Dictionary = _compute_needed(pc, view_distance)

	# Request missing (near-first)
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

	to_request.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.distance_squared_to(pc) < b.distance_squared_to(pc)
	)

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

	# Unload far
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
		var ch: KZ_Chunk = _chunks[c3] as KZ_Chunk
		_chunks.erase(c3)
		if ch != null:
			ch.queue_free()

func _on_chunk_ready(result: Dictionary) -> void:
	# Always clear requested if we can
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

	var ch := KZ_Chunk.new()
	ch.set_chunk_pos(cpos)
	ch.position = origin
	add_child(ch)
	_chunks[cpos] = ch

	var mesh: ArrayMesh = _make_mesh(arrays)
	ch.set_mesh(mesh)

func _make_mesh(arrays: Dictionary) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var a := []
	a.resize(Mesh.ARRAY_MAX)

	a[Mesh.ARRAY_VERTEX] = arrays["vertices"]
	a[Mesh.ARRAY_NORMAL] = arrays["normals"]
	a[Mesh.ARRAY_TEX_UV] = arrays["uvs"]
	a[Mesh.ARRAY_COLOR] = arrays["colors"]
	a[Mesh.ARRAY_INDEX] = arrays["indices"]

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)

	var mat := _create_material()
	mesh.surface_set_material(0, mat)

	return mesh

func _create_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# This is the key: double-sided vs backface-culling
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED if debug_double_sided else BaseMaterial3D.CULL_BACK
	return mat

func _apply_materials_to_loaded_chunks() -> void:
	var mat := _create_material()
	var keys: Array = _chunks.keys()
	for i in range(keys.size()):
		var c_v: Variant = keys[i]
		if typeof(c_v) != TYPE_VECTOR2I:
			continue
		var c: Vector2i = c_v as Vector2i
		var ch: KZ_Chunk = _chunks[c] as KZ_Chunk
		if ch == null or ch.mesh_instance == null:
			continue
		var m: Mesh = ch.mesh_instance.mesh
		if m is ArrayMesh:
			var am: ArrayMesh = m as ArrayMesh
			if am.get_surface_count() > 0:
				am.surface_set_material(0, mat)

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
