extends Node
class_name KZ_LocalWorldServer

var world_root: String = ""

# Renamed from "seed" to avoid shadowing built-in seed()
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

var _cache: Dictionary = {}                 # Vector2i -> Dictionary result
var _cache_order: Array[Vector2i] = []

var _pending: Array[Vector2i] = []
var _callbacks: Dictionary = {}             # Vector2i -> Array[Callable]
var _jobs: Dictionary = {}                  # Vector2i -> Thread

func setup(p_world_root: String, worldgen_cfg: Dictionary, block_registry: KZ_BlockRegistry) -> void:
	world_root = p_world_root
	registry = block_registry

	_apply_worldgen(worldgen_cfg)
	_load_or_create_world_files()

	grass_runtime_id = registry.get_runtime_id("kaizencraft:grass")

func _exit_tree() -> void:
	_join_all_threads()

func _join_all_threads() -> void:
	var keys: Array = _jobs.keys()
	for i in range(keys.size()):
		var pos_v: Variant = keys[i]
		if typeof(pos_v) != TYPE_VECTOR2I:
			continue
		var pos: Vector2i = pos_v as Vector2i
		var t: Thread = _jobs[pos] as Thread
		if t != null:
			# wait_to_finish is safe to call; it will join if running
			var _ignored: Variant = t.wait_to_finish()
	_jobs.clear()

func _process(_dt: float) -> void:
	# Start jobs up to max
	while _jobs.size() < max_worker_threads and _pending.size() > 0:
		var pos: Vector2i = _pending.pop_front()
		if _jobs.has(pos):
			continue

		var t: Thread = Thread.new()
		_jobs[pos] = t

		var cfg: Dictionary = {
			"seed": world_seed,
			"dims": dims,
			"freq": terrain_frequency,
			"base_h": terrain_base_height,
			"scale_h": terrain_height_scale,
			"grass_id": grass_runtime_id
		}

		var callable: Callable = Callable(self, "_thread_generate_chunk").bind(pos, cfg)
		var err: int = t.start(callable)
		if err != OK:
			_jobs.erase(pos)
			_finish_with_error(pos, "Thread start failed: %s" % str(err))

	# Collect finished
	var keys: Array = _jobs.keys()
	for i in range(keys.size()):
		var pos_v: Variant = keys[i]
		if typeof(pos_v) != TYPE_VECTOR2I:
			continue
		var pos2: Vector2i = pos_v as Vector2i

		var t2: Thread = _jobs[pos2] as Thread
		if t2 == null:
			continue

		if not t2.is_alive():
			var result_v: Variant = t2.wait_to_finish()
			_jobs.erase(pos2)
			_on_chunk_generated(pos2, result_v)

func request_chunk(chunk_pos: Vector2i, cb: Callable) -> void:
	if _cache.has(chunk_pos):
		cb.call(_cache[chunk_pos])
		return

	if not _callbacks.has(chunk_pos):
		_callbacks[chunk_pos] = []
		_pending.append(chunk_pos)

	var arr: Array = _callbacks[chunk_pos] as Array
	arr.append(cb)
	_callbacks[chunk_pos] = arr

func get_spawn_position() -> Vector3:
	var h: int = get_height_at_world(0, 0)
	return Vector3(0.5, float(h + 3), 0.5)

func get_height_at_world(wx: int, wz: int) -> int:
	var n: float = _noise2(wx, wz)
	var h: int = int(round(float(terrain_base_height) + n * float(terrain_height_scale)))
	return clampi(h, 1, dims.y - 2)

func get_block_at_world(wx: int, wy: int, wz: int) -> int:
	var h: int = get_height_at_world(wx, wz)
	return grass_runtime_id if wy <= h else 0

func _apply_worldgen(worldgen_cfg: Dictionary) -> void:
	var wg_v: Variant = worldgen_cfg.get("worldgen", {})
	var terrain_v: Variant = worldgen_cfg.get("terrain", {}) # renamed (no "tr")

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

func _on_chunk_generated(chunk_pos: Vector2i, result: Variant) -> void:
	if typeof(result) != TYPE_DICTIONARY:
		_finish_with_error(chunk_pos, "Chunk gen returned non-dict.")
		return

	var res: Dictionary = result as Dictionary
	_cache[chunk_pos] = res
	_cache_order.append(chunk_pos)

	while _cache_order.size() > cache_max_chunks:
		var old: Vector2i = _cache_order.pop_front()
		_cache.erase(old)

	if _callbacks.has(chunk_pos):
		var arr: Array = _callbacks[chunk_pos] as Array
		_callbacks.erase(chunk_pos)
		for j in range(arr.size()):
			var cb: Callable = arr[j] as Callable
			cb.call(res)

func _finish_with_error(chunk_pos: Vector2i, msg: String) -> void:
	push_error("Chunk %s error: %s" % [str(chunk_pos), msg])
	if _callbacks.has(chunk_pos):
		var arr: Array = _callbacks[chunk_pos] as Array
		_callbacks.erase(chunk_pos)
		for j in range(arr.size()):
			var cb: Callable = arr[j] as Callable
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

	var get_block_world := func(wx: int, wy: int, wz: int) -> int:
		var lx: int = wx - origin_x
		var lz: int = wz - origin_z
		if lx >= 0 and lx < sx and lz >= 0 and lz < sz and wy >= 0 and wy < sy:
			return int(vox[idx.call(lx, wy, lz)])
		var hh2: int = int(height_at.call(wx, wz))
		return grass_id if wy <= hh2 else 0

	var chunk_origin: Vector3 = Vector3(origin_x, 0, origin_z)
	var mesh_arrays: Dictionary = KZ_ChunkMeshBuilder.build_mesh_arrays(
		chunk_origin,
		local_dims,
		get_block_world,
		func(rid: int) -> Color:
			return Color(0.4078, 0.7607, 0.2823, 1.0) if rid == grass_id else Color(1, 1, 1, 1),
		func(rid: int) -> bool:
			return rid != 0
	)

	return {
		"chunk_pos": chunk_pos,
		"origin": chunk_origin,
		"dims": local_dims,
		"voxels": vox,
		"mesh_arrays": mesh_arrays
	}

func _noise2(wx: int, wz: int) -> float:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = world_seed
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = terrain_frequency
	return noise.get_noise_2d(float(wx), float(wz))
