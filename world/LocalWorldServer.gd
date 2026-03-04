extends Node
class_name KZ_LocalWorldServer

signal chunk_mesh_updated(chunk_pos: Vector2i, mesh_arrays: Dictionary)
signal block_broken(world_block: Vector3i, runtime_id: int)

var world_root: String = ""
var world_seed: int = 1337

var dims: Vector3i = Vector3i(16, 256, 16)
var view_distance_chunks: int = 6

var max_worker_threads: int = 3
var cache_max_chunks: int = 256

var terrain_frequency: float = 0.008
var terrain_base_height: int = 64
var terrain_height_scale: int = 28

var registry: KZ_BlockRegistry
var grass_runtime_id: int = 1

# Cache: Vector2i -> Dictionary {chunk_pos, origin, dims, voxels, mesh_arrays}
var _cache: Dictionary = {}
var _cache_order: Array[Vector2i] = []

# Sparse edits per chunk: Vector2i -> Dictionary<int,int> (linear index -> runtime_id)
var _chunk_edits: Dictionary = {}

# Generation requests
var _pending_gen: Array[Vector2i] = []
var _gen_callbacks: Dictionary = {} # Vector2i -> Array[Callable]
var _gen_jobs: Dictionary = {}      # Vector2i -> Thread

# Mesh rebuild requests
var _pending_mesh: Array[Vector2i] = []
var _mesh_jobs: Dictionary = {}     # Vector2i -> Thread

func setup(p_world_root: String, worldgen_cfg: Dictionary, block_registry: KZ_BlockRegistry) -> void:
	world_root = p_world_root
	registry = block_registry

	_apply_worldgen(worldgen_cfg)
	_load_or_create_world_files()

	grass_runtime_id = registry.get_runtime_id("kaizencraft:grass")

func _exit_tree() -> void:
	_join_all_threads()

func _join_all_threads() -> void:
	var gen_keys: Array = _gen_jobs.keys()
	for i in range(gen_keys.size()):
		var pos_v: Variant = gen_keys[i]
		if typeof(pos_v) != TYPE_VECTOR2I:
			continue
		var pos: Vector2i = pos_v as Vector2i
		var t: Thread = _gen_jobs[pos] as Thread
		if t != null:
			var _ignored: Variant = t.wait_to_finish()
	_gen_jobs.clear()

	var mesh_keys: Array = _mesh_jobs.keys()
	for j in range(mesh_keys.size()):
		var pos2_v: Variant = mesh_keys[j]
		if typeof(pos2_v) != TYPE_VECTOR2I:
			continue
		var pos2: Vector2i = pos2_v as Vector2i
		var t2: Thread = _mesh_jobs[pos2] as Thread
		if t2 != null:
			var _ignored2: Variant = t2.wait_to_finish()
	_mesh_jobs.clear()

func _process(_dt: float) -> void:
	# Prioritize mesh jobs (fast visual feedback on breaking)
	_start_jobs()

	_collect_finished_gen()
	_collect_finished_mesh()

func _start_jobs() -> void:
	while (_gen_jobs.size() + _mesh_jobs.size()) < max_worker_threads:
		if _pending_mesh.size() > 0:
			var mpos: Vector2i = _pending_mesh.pop_front()
			if _mesh_jobs.has(mpos):
				continue
			if not _cache.has(mpos):
				continue

			var tmesh := Thread.new()
			_mesh_jobs[mpos] = tmesh

			var job_payload: Dictionary = _build_mesh_job_payload(mpos)
			var callable := Callable(self, "_thread_build_mesh").bind(mpos, job_payload)
			var err: int = tmesh.start(callable)
			if err != OK:
				_mesh_jobs.erase(mpos)
				push_error("Mesh thread start failed: %s" % str(err))
			continue

		if _pending_gen.size() > 0:
			var gpos: Vector2i = _pending_gen.pop_front()
			if _gen_jobs.has(gpos):
				continue

			var tgen := Thread.new()
			_gen_jobs[gpos] = tgen

			var cfg: Dictionary = _build_gen_job_cfg(gpos)
			var callable2 := Callable(self, "_thread_generate_chunk").bind(gpos, cfg)
			var err2: int = tgen.start(callable2)
			if err2 != OK:
				_gen_jobs.erase(gpos)
				_finish_with_error(gpos, "Thread start failed: %s" % str(err2))
			continue

		break

func _collect_finished_gen() -> void:
	var keys: Array = _gen_jobs.keys()
	for i in range(keys.size()):
		var pos_v: Variant = keys[i]
		if typeof(pos_v) != TYPE_VECTOR2I:
			continue
		var pos: Vector2i = pos_v as Vector2i
		var t: Thread = _gen_jobs[pos] as Thread
		if t == null:
			continue
		if not t.is_alive():
			var result_v: Variant = t.wait_to_finish()
			_gen_jobs.erase(pos)
			_on_chunk_generated(pos, result_v)

func _collect_finished_mesh() -> void:
	var keys: Array = _mesh_jobs.keys()
	for i in range(keys.size()):
		var pos_v: Variant = keys[i]
		if typeof(pos_v) != TYPE_VECTOR2I:
			continue
		var pos: Vector2i = pos_v as Vector2i
		var t: Thread = _mesh_jobs[pos] as Thread
		if t == null:
			continue
		if not t.is_alive():
			var result_v: Variant = t.wait_to_finish()
			_mesh_jobs.erase(pos)
			_on_mesh_built(pos, result_v)

# ----------------------------
# Public API (Stage 2)
# ----------------------------

func request_chunk(chunk_pos: Vector2i, cb: Callable) -> void:
	if _cache.has(chunk_pos):
		cb.call(_cache[chunk_pos])
		return

	if not _gen_callbacks.has(chunk_pos):
		_gen_callbacks[chunk_pos] = []
		_pending_gen.append(chunk_pos)

	var arr: Array = _gen_callbacks[chunk_pos] as Array
	arr.append(cb)
	_gen_callbacks[chunk_pos] = arr

func break_block_world(wx: int, wy: int, wz: int) -> void:
	# If chunk isn't loaded yet, load it first then apply break.
	var cpos: Vector2i = _world_to_chunk(wx, wz)
	if _cache.has(cpos):
		_break_in_cached_chunk(cpos, wx, wy, wz)
		return

	request_chunk(cpos, Callable(self, "_on_chunk_loaded_for_break").bind(wx, wy, wz))

func get_spawn_position() -> Vector3:
	var h: int = get_height_at_world(0, 0)
	return Vector3(0.5, float(h + 3), 0.5)

func get_height_at_world(wx: int, wz: int) -> int:
	var n: float = _noise2(wx, wz)
	var h: int = int(round(float(terrain_base_height) + n * float(terrain_height_scale)))
	return clampi(h, 1, dims.y - 2)

# Used by raycast + player grounding. Includes edits.
func get_block_at_world(wx: int, wy: int, wz: int) -> int:
	if wy < 0 or wy >= dims.y:
		return 0

	var cpos: Vector2i = _world_to_chunk(wx, wz)
	var origin_x: int = cpos.x * dims.x
	var origin_z: int = cpos.y * dims.z
	var lx: int = wx - origin_x
	var lz: int = wz - origin_z

	var li: int = _idx_local(lx, wy, lz)

	if _cache.has(cpos):
		var ch_v: Variant = _cache[cpos]
		var ch: Dictionary = ch_v as Dictionary
		var vox_v: Variant = ch.get("voxels")
		if typeof(vox_v) == TYPE_PACKED_BYTE_ARRAY:
			var vox: PackedByteArray = vox_v as PackedByteArray
			if li >= 0 and li < vox.size():
				return int(vox[li])

	var edits_v: Variant = _chunk_edits.get(cpos, {})
	var edits: Dictionary = edits_v as Dictionary
	if edits.has(li):
		return int(edits[li])

	var hgt: int = get_height_at_world(wx, wz)
	return grass_runtime_id if wy <= hgt else 0

func get_surface_y(wx: int, wz: int) -> int:
	# Returns the top face Y (block_y + 1) of the highest solid block at (wx,wz),
	# considering edits. Stage 2 only breaks, so we start from base height and scan down.
	var hgt: int = get_height_at_world(wx, wz)
	var start_y: int = clampi(hgt + 1, 0, dims.y - 1)

	for y in range(start_y, -1, -1):
		var rid: int = get_block_at_world(wx, y, wz)
		if rid != 0:
			return y + 1
	return 0

# ----------------------------
# Internal: break + edits + remesh
# ----------------------------

func _on_chunk_loaded_for_break(result: Dictionary, wx: int, wy: int, wz: int) -> void:
	if result.has("error"):
		return
	var cpos: Vector2i = _world_to_chunk(wx, wz)
	if _cache.has(cpos):
		_break_in_cached_chunk(cpos, wx, wy, wz)

func _break_in_cached_chunk(chunk_pos: Vector2i, wx: int, wy: int, wz: int) -> void:
	if wy < 0 or wy >= dims.y:
		return

	var ch_v: Variant = _cache[chunk_pos]
	var ch: Dictionary = ch_v as Dictionary

	var vox_v: Variant = ch.get("voxels")
	if typeof(vox_v) != TYPE_PACKED_BYTE_ARRAY:
		return
	var vox: PackedByteArray = vox_v as PackedByteArray

	var origin_x: int = chunk_pos.x * dims.x
	var origin_z: int = chunk_pos.y * dims.z
	var lx: int = wx - origin_x
	var lz: int = wz - origin_z

	if lx < 0 or lx >= dims.x or lz < 0 or lz >= dims.z:
		return

	var li: int = _idx_local(lx, wy, lz)
	if li < 0 or li >= vox.size():
		return

	var old_id: int = int(vox[li])
	if old_id == 0:
		return

	# Apply break
	vox[li] = 0
	ch["voxels"] = vox
	_cache[chunk_pos] = ch

	# Record sparse edit
	var edits_v: Variant = _chunk_edits.get(chunk_pos, {})
	var edits: Dictionary = edits_v as Dictionary
	edits[li] = 0
	_chunk_edits[chunk_pos] = edits

	# Emit a hardcoded “drop”
	emit_signal("block_broken", Vector3i(wx, wy, wz), old_id)

	# Remesh this chunk (+ neighbors if edge)
	_schedule_remesh(chunk_pos)

	if lx == 0:
		_schedule_remesh(Vector2i(chunk_pos.x - 1, chunk_pos.y))
	elif lx == dims.x - 1:
		_schedule_remesh(Vector2i(chunk_pos.x + 1, chunk_pos.y))

	if lz == 0:
		_schedule_remesh(Vector2i(chunk_pos.x, chunk_pos.y - 1))
	elif lz == dims.z - 1:
		_schedule_remesh(Vector2i(chunk_pos.x, chunk_pos.y + 1))

func _schedule_remesh(chunk_pos: Vector2i) -> void:
	if not _cache.has(chunk_pos):
		return
	if _mesh_jobs.has(chunk_pos):
		return
	if _pending_mesh.has(chunk_pos):
		return
	_pending_mesh.append(chunk_pos)

func _on_mesh_built(chunk_pos: Vector2i, result_v: Variant) -> void:
	if typeof(result_v) != TYPE_DICTIONARY:
		return
	var result: Dictionary = result_v as Dictionary

	var arrays_v: Variant = result.get("mesh_arrays")
	if typeof(arrays_v) != TYPE_DICTIONARY:
		return
	var mesh_arrays: Dictionary = arrays_v as Dictionary

	if _cache.has(chunk_pos):
		var ch: Dictionary = (_cache[chunk_pos] as Dictionary)
		ch["mesh_arrays"] = mesh_arrays
		_cache[chunk_pos] = ch

	emit_signal("chunk_mesh_updated", chunk_pos, mesh_arrays)

# ----------------------------
# Jobs: cfg builders
# ----------------------------

func _build_gen_job_cfg(chunk_pos: Vector2i) -> Dictionary:
	var edits_v: Variant = _chunk_edits.get(chunk_pos, {})
	var edits: Dictionary = edits_v as Dictionary

	var neighbors: Dictionary = _get_neighbor_voxels(chunk_pos)

	return {
		"seed": world_seed,
		"dims": dims,
		"freq": terrain_frequency,
		"base_h": terrain_base_height,
		"scale_h": terrain_height_scale,
		"grass_id": grass_runtime_id,
		"edits": edits,
		"neighbors": neighbors
	}

func _build_mesh_job_payload(chunk_pos: Vector2i) -> Dictionary:
	var ch: Dictionary = _cache[chunk_pos] as Dictionary
	var vox_v: Variant = ch.get("voxels")
	var vox: PackedByteArray = vox_v as PackedByteArray

	var neighbors: Dictionary = _get_neighbor_voxels(chunk_pos)

	return {
		"seed": world_seed,
		"dims": dims,
		"freq": terrain_frequency,
		"base_h": terrain_base_height,
		"scale_h": terrain_height_scale,
		"grass_id": grass_runtime_id,
		"voxels": vox,
		"neighbors": neighbors
	}

func _get_neighbor_voxels(chunk_pos: Vector2i) -> Dictionary:
	# Returns {"W": PackedByteArray, "E":..., "N":..., "S":...} only for cached neighbors.
	var out: Dictionary = {}

	var west := Vector2i(chunk_pos.x - 1, chunk_pos.y)
	var east := Vector2i(chunk_pos.x + 1, chunk_pos.y)
	var north := Vector2i(chunk_pos.x, chunk_pos.y - 1)
	var south := Vector2i(chunk_pos.x, chunk_pos.y + 1)

	_try_put_neighbor_voxels(out, "W", west)
	_try_put_neighbor_voxels(out, "E", east)
	_try_put_neighbor_voxels(out, "N", north)
	_try_put_neighbor_voxels(out, "S", south)

	return out

func _try_put_neighbor_voxels(out: Dictionary, key: String, pos: Vector2i) -> void:
	if not _cache.has(pos):
		return
	var ch: Dictionary = _cache[pos] as Dictionary
	var vox_v: Variant = ch.get("voxels")
	if typeof(vox_v) == TYPE_PACKED_BYTE_ARRAY:
		out[key] = vox_v

# ----------------------------
# Generation + mesh threads
# ----------------------------

func _on_chunk_generated(chunk_pos: Vector2i, result_v: Variant) -> void:
	if typeof(result_v) != TYPE_DICTIONARY:
		_finish_with_error(chunk_pos, "Chunk gen returned non-dict.")
		return

	var result: Dictionary = result_v as Dictionary
	_cache[chunk_pos] = result
	_cache_order.append(chunk_pos)

	while _cache_order.size() > cache_max_chunks:
		var old: Vector2i = _cache_order.pop_front()
		_cache.erase(old)

	if _gen_callbacks.has(chunk_pos):
		var arr: Array = _gen_callbacks[chunk_pos] as Array
		_gen_callbacks.erase(chunk_pos)
		for i in range(arr.size()):
			var cb: Callable = arr[i] as Callable
			cb.call(result)

func _finish_with_error(chunk_pos: Vector2i, msg: String) -> void:
	push_error("Chunk %s error: %s" % [str(chunk_pos), msg])
	if _gen_callbacks.has(chunk_pos):
		var arr: Array = _gen_callbacks[chunk_pos] as Array
		_gen_callbacks.erase(chunk_pos)
		for i in range(arr.size()):
			var cb: Callable = arr[i] as Callable
			cb.call({
				"chunk_pos": chunk_pos,
				"error": msg
			})

func _thread_generate_chunk(chunk_pos: Vector2i, cfg: Dictionary) -> Dictionary:
	var local_seed: int = int(cfg["seed"])
	var local_dims: Vector3i = cfg["dims"] as Vector3i
	var freq: float = float(cfg["freq"])
	var base_h: int = int(cfg["base_h"])
	var scale_h: int = int(cfg["scale_h"])
	var grass_id: int = int(cfg["grass_id"])

	var edits_v: Variant = cfg.get("edits", {})
	var edits: Dictionary = edits_v as Dictionary

	var neighbors_v: Variant = cfg.get("neighbors", {})
	var neighbors: Dictionary = neighbors_v as Dictionary

	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = local_seed
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = freq

	var sx: int = local_dims.x
	var sy: int = local_dims.y
	var sz: int = local_dims.z

	var origin_x: int = chunk_pos.x * sx
	var origin_z: int = chunk_pos.y * sz

	var idx := func(x: int, y: int, z: int) -> int:
		return x + z * sx + y * sx * sz

	var height_at := func(wx: int, wz: int) -> int:
		var n: float = noise.get_noise_2d(float(wx), float(wz))
		var h: int = int(round(float(base_h) + n * float(scale_h)))
		return clampi(h, 1, sy - 2)

	var vox := PackedByteArray()
	vox.resize(sx * sy * sz)

	for z in range(sz):
		for x in range(sx):
			var wx: int = origin_x + x
			var wz: int = origin_z + z
			var hh: int = int(height_at.call(wx, wz))
			for y in range(sy):
				vox[idx.call(x, y, z)] = grass_id if y <= hh else 0

	# Apply sparse edits
	var edit_keys: Array = edits.keys()
	for i in range(edit_keys.size()):
		var k: Variant = edit_keys[i]
		var li: int = int(k)
		if li >= 0 and li < vox.size():
			vox[li] = int(edits[li])

	# World sampler with neighbor support
	var get_block_world := func(wx: int, wy: int, wz: int) -> int:
		if wy < 0 or wy >= sy:
			return 0

		var lx: int = wx - origin_x
		var lz: int = wz - origin_z
		if lx >= 0 and lx < sx and lz >= 0 and lz < sz:
			return int(vox[idx.call(lx, wy, lz)])

		# Neighbor sampling for boundaries
		if lx < 0 and neighbors.has("W"):
			var nvox: PackedByteArray = neighbors["W"] as PackedByteArray
			var nx: int = lx + sx
			if nx >= 0 and nx < sx and lz >= 0 and lz < sz:
				return int(nvox[idx.call(nx, wy, lz)])
		if lx >= sx and neighbors.has("E"):
			var evox: PackedByteArray = neighbors["E"] as PackedByteArray
			var ex: int = lx - sx
			if ex >= 0 and ex < sx and lz >= 0 and lz < sz:
				return int(evox[idx.call(ex, wy, lz)])
		if lz < 0 and neighbors.has("N"):
			var nvox2: PackedByteArray = neighbors["N"] as PackedByteArray
			var nz: int = lz + sz
			if lx >= 0 and lx < sx and nz >= 0 and nz < sz:
				return int(nvox2[idx.call(lx, wy, nz)])
		if lz >= sz and neighbors.has("S"):
			var svox: PackedByteArray = neighbors["S"] as PackedByteArray
			var sz2: int = lz - sz
			if lx >= 0 and lx < sx and sz2 >= 0 and sz2 < sz:
				return int(svox[idx.call(lx, wy, sz2)])

		var hh2: int = int(height_at.call(wx, wz))
		return grass_id if wy <= hh2 else 0

	var chunk_origin_world := Vector3(origin_x, 0, origin_z)
	var mesh_arrays: Dictionary = KZ_ChunkMeshBuilder.build_mesh_arrays(
		chunk_origin_world,
		local_dims,
		get_block_world,
		func(rid: int) -> Color:
			return Color(0.4078, 0.7607, 0.2823, 1.0) if rid == grass_id else Color(1, 1, 1, 1),
		func(rid: int) -> bool:
			return rid != 0
	)

	return {
		"chunk_pos": chunk_pos,
		"origin": chunk_origin_world,
		"dims": local_dims,
		"voxels": vox,
		"mesh_arrays": mesh_arrays
	}

func _thread_build_mesh(chunk_pos: Vector2i, payload: Dictionary) -> Dictionary:
	var local_seed: int = int(payload["seed"])
	var local_dims: Vector3i = payload["dims"] as Vector3i
	var freq: float = float(payload["freq"])
	var base_h: int = int(payload["base_h"])
	var scale_h: int = int(payload["scale_h"])
	var grass_id: int = int(payload["grass_id"])

	var vox_v: Variant = payload.get("voxels")
	var vox: PackedByteArray = vox_v as PackedByteArray

	var neighbors_v: Variant = payload.get("neighbors", {})
	var neighbors: Dictionary = neighbors_v as Dictionary

	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = local_seed
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = freq

	var sx: int = local_dims.x
	var sy: int = local_dims.y
	var sz: int = local_dims.z

	var origin_x: int = chunk_pos.x * sx
	var origin_z: int = chunk_pos.y * sz

	var idx := func(x: int, y: int, z: int) -> int:
		return x + z * sx + y * sx * sz

	var height_at := func(wx: int, wz: int) -> int:
		var n: float = noise.get_noise_2d(float(wx), float(wz))
		var h: int = int(round(float(base_h) + n * float(scale_h)))
		return clampi(h, 1, sy - 2)

	var get_block_world := func(wx: int, wy: int, wz: int) -> int:
		if wy < 0 or wy >= sy:
			return 0

		var lx: int = wx - origin_x
		var lz: int = wz - origin_z
		if lx >= 0 and lx < sx and lz >= 0 and lz < sz:
			return int(vox[idx.call(lx, wy, lz)])

		if lx < 0 and neighbors.has("W"):
			var wvox: PackedByteArray = neighbors["W"] as PackedByteArray
			var nx: int = lx + sx
			if nx >= 0 and nx < sx and lz >= 0 and lz < sz:
				return int(wvox[idx.call(nx, wy, lz)])
		if lx >= sx and neighbors.has("E"):
			var evox: PackedByteArray = neighbors["E"] as PackedByteArray
			var ex: int = lx - sx
			if ex >= 0 and ex < sx and lz >= 0 and lz < sz:
				return int(evox[idx.call(ex, wy, lz)])
		if lz < 0 and neighbors.has("N"):
			var nvox: PackedByteArray = neighbors["N"] as PackedByteArray
			var nz: int = lz + sz
			if lx >= 0 and lx < sx and nz >= 0 and nz < sz:
				return int(nvox[idx.call(lx, wy, nz)])
		if lz >= sz and neighbors.has("S"):
			var svox: PackedByteArray = neighbors["S"] as PackedByteArray
			var zz: int = lz - sz
			if lx >= 0 and lx < sx and zz >= 0 and zz < sz:
				return int(svox[idx.call(lx, wy, zz)])

		var hh: int = int(height_at.call(wx, wz))
		return grass_id if wy <= hh else 0

	var chunk_origin_world := Vector3(origin_x, 0, origin_z)
	var mesh_arrays: Dictionary = KZ_ChunkMeshBuilder.build_mesh_arrays(
		chunk_origin_world,
		local_dims,
		get_block_world,
		func(rid: int) -> Color:
			return Color(0.4078, 0.7607, 0.2823, 1.0) if rid == grass_id else Color(1, 1, 1, 1),
		func(rid: int) -> bool:
			return rid != 0
	)

	return {
		"chunk_pos": chunk_pos,
		"mesh_arrays": mesh_arrays
	}

# ----------------------------
# Helpers
# ----------------------------

func _apply_worldgen(worldgen_cfg: Dictionary) -> void:
	var wg_v: Variant = worldgen_cfg.get("worldgen", {})
	var terrain_v: Variant = worldgen_cfg.get("terrain", {})

	var wg: Dictionary = wg_v as Dictionary
	var terrain_cfg: Dictionary = terrain_v as Dictionary

	dims = Vector3i(
		int(wg.get("chunk_size_x", 16)),
		int(wg.get("chunk_size_y", 256)),
		int(wg.get("chunk_size_z", 16))
	)
	view_distance_chunks = int(wg.get("view_distance_chunks", 6))
	max_worker_threads = int(wg.get("max_worker_threads", 3))
	cache_max_chunks = int(wg.get("cache_max_chunks", 256))

	world_seed = int(terrain_cfg.get("seed", 1337))
	terrain_frequency = float(terrain_cfg.get("frequency", 0.008))
	terrain_base_height = int(terrain_cfg.get("base_height", 64))
	terrain_height_scale = int(terrain_cfg.get("height_scale", 28))

func _load_or_create_world_files() -> void:
	var seed_path: String = KZ_PathUtil.join(world_root, "seed.dat")
	if KZ_PathUtil.file_exists(seed_path):
		var s: String = KZ_PathUtil.read_text(seed_path).strip_edges()
		if s != "" and s.is_valid_int():
			world_seed = int(s)
	else:
		KZ_PathUtil.write_text(seed_path, str(world_seed) + "\n")

	var level_path: String = KZ_PathUtil.join(world_root, "level.dat")
	if not KZ_PathUtil.file_exists(level_path):
		var meta: Dictionary = {
			"name": world_root.get_file(),
			"created_utc": Time.get_datetime_string_from_system(true),
			"last_played_utc": Time.get_datetime_string_from_system(true),
			"seed": world_seed,
			"format": "kaizencraft_level_v1_json"
		}
		KZ_PathUtil.write_text(level_path, JSON.stringify(meta, "\t"))
	else:
		var txt: String = KZ_PathUtil.read_text(level_path)
		var parsed_v: Variant = JSON.parse_string(txt)
		if typeof(parsed_v) == TYPE_DICTIONARY:
			var parsed: Dictionary = parsed_v as Dictionary
			parsed["last_played_utc"] = Time.get_datetime_string_from_system(true)
			KZ_PathUtil.write_text(level_path, JSON.stringify(parsed, "\t"))

func _noise2(wx: int, wz: int) -> float:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = world_seed
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = terrain_frequency
	return noise.get_noise_2d(float(wx), float(wz))

func _world_to_chunk(wx: int, wz: int) -> Vector2i:
	var cx: int = int(floor(float(wx) / float(dims.x)))
	var cz: int = int(floor(float(wz) / float(dims.z)))
	return Vector2i(cx, cz)

func _idx_local(x: int, y: int, z: int) -> int:
	return x + z * dims.x + y * dims.x * dims.z
