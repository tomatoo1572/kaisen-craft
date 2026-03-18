extends Node

signal chunk_mesh_updated(chunk_pos: Vector2i, mesh_arrays: Dictionary)
signal block_broken(world_block: Vector3i, runtime_id: int)
signal block_placed(world_block: Vector3i, runtime_id: int)

var world_root: String = ""
var world_seed: int = 1337

var dims: Vector3i = Vector3i(16, 256, 16)
var view_distance_chunks: int = 6

var max_worker_threads: int = 1
var cache_max_chunks: int = 256

var terrain_frequency: float = 0.008
var terrain_base_height: int = 64
var terrain_height_scale: int = 28
var sea_level: int = 62
var tree_spawn_chance_percent: int = 1
var tree_edge_margin: int = 3

var registry: KZ_BlockRegistry
var grass_runtime_id: int = 1
var dirt_runtime_id: int = 1
var oak_log_runtime_id: int = 1
var oak_leaves_runtime_id: int = 1
var oak_planks_runtime_id: int = 1
var crafting_table_runtime_id: int = 1
var water_runtime_id: int = 1
var stone_runtime_id: int = 1
var sand_runtime_id: int = 1

# Main-thread noise (performance)
var _main_noise: FastNoiseLite

# Cache: Vector2i -> Dictionary {chunk_pos, origin, dims, voxels, mesh_arrays, heightmap}
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

# If edits happen while a mesh job is running, mark dirty and rebuild again
var _mesh_dirty: Dictionary = {}    # Vector2i -> bool
var _mesh_revision: Dictionary = {} # Vector2i -> int

var _chunk_edits_dirty: bool = false
var _chunk_edits_save_timer: float = 0.0
var _chunk_edits_save_interval_sec: float = 1.0

func setup(p_world_root: String, worldgen_cfg: Dictionary, block_registry: KZ_BlockRegistry) -> void:
	world_root = p_world_root
	registry = block_registry

	_apply_worldgen(worldgen_cfg)
	_load_or_create_world_files()
	_load_chunk_edits()
	_rebuild_main_noise()

	grass_runtime_id = registry.get_runtime_id("kaizencraft:grass")
	dirt_runtime_id = registry.get_runtime_id("kaizencraft:dirt")
	oak_log_runtime_id = registry.get_runtime_id("kaizencraft:oak_log")
	oak_leaves_runtime_id = registry.get_runtime_id("kaizencraft:oak_leaves")
	oak_planks_runtime_id = registry.get_runtime_id("kaizencraft:oak_planks")
	crafting_table_runtime_id = registry.get_runtime_id("kaizencraft:crafting_table")
	water_runtime_id = registry.get_runtime_id("kaizencraft:water")
	stone_runtime_id = registry.get_runtime_id("kaizencraft:stone")
	sand_runtime_id = registry.get_runtime_id("kaizencraft:sand")

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

func _process(dt: float) -> void:
	# Prioritize mesh jobs (fast visual feedback on edits)
	_start_jobs()
	_collect_finished_gen()
	_collect_finished_mesh()
	if _chunk_edits_dirty:
		_chunk_edits_save_timer += dt
		if _chunk_edits_save_timer >= _chunk_edits_save_interval_sec:
			_save_chunk_edits()

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
# Public API
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

func break_block_world(wx: int, wy: int, wz: int) -> bool:
	var cpos: Vector2i = _world_to_chunk(wx, wz)
	if _cache.has(cpos):
		return _break_in_cached_chunk(cpos, wx, wy, wz)

	request_chunk(cpos, Callable(self, "_on_chunk_loaded_for_break").bind(wx, wy, wz))
	return false

func place_block_world(wx: int, wy: int, wz: int, runtime_id: int) -> bool:
	var cpos: Vector2i = _world_to_chunk(wx, wz)
	if _cache.has(cpos):
		return _place_in_cached_chunk(cpos, wx, wy, wz, runtime_id)

	request_chunk(cpos, Callable(self, "_on_chunk_loaded_for_place").bind(wx, wy, wz, runtime_id))
	return false

func get_spawn_position() -> Vector3:
	var surface_y: int = get_surface_y(0, 0)
	return Vector3(0.5, float(surface_y + 2), 0.5)

func get_height_at_world(wx: int, wz: int) -> int:
	if _main_noise == null:
		_rebuild_main_noise()
	var n: float = _main_noise.get_noise_2d(float(wx), float(wz))
	var h: int = int(round(float(terrain_base_height) + n * float(terrain_height_scale)))
	return clampi(h, 1, dims.y - 2)

# Used by raycast + collision. Includes edits.
func get_block_at_world(wx: int, wy: int, wz: int) -> int:
	if wy < 0 or wy >= dims.y:
		return 0

	var cpos: Vector2i = _world_to_chunk(wx, wz)
	var origin_x: int = cpos.x * dims.x
	var origin_z: int = cpos.y * dims.z
	var lx: int = wx - origin_x
	var lz: int = wz - origin_z
	if lx < 0 or lx >= dims.x or lz < 0 or lz >= dims.z:
		# Shouldn't happen, but safe fallback.
		var hh0: int = get_height_at_world(wx, wz)
		if wy > hh0:
			return 0
		if wy == hh0:
			return grass_runtime_id
		return dirt_runtime_id

	var li: int = _idx_local(lx, wy, lz)

	if _cache.has(cpos):
		var ch: Dictionary = _cache[cpos] as Dictionary
		var vox_v: Variant = ch.get("voxels")
		if typeof(vox_v) == TYPE_PACKED_BYTE_ARRAY:
			var vox: PackedByteArray = vox_v as PackedByteArray
			if li >= 0 and li < vox.size():
				return int(vox[li])

	var edits_v: Variant = _chunk_edits.get(cpos, {})
	var edits: Dictionary = edits_v as Dictionary
	if edits.has(li):
		return int(edits[li])

	return _get_generated_block_at_world(wx, wy, wz)

func is_block_collidable_at_world(wx: int, wy: int, wz: int) -> bool:
	var rid: int = get_block_at_world(wx, wy, wz)
	if rid == 0:
		return false
	if registry != null:
		return registry.is_collidable(rid)
	return true

func _mark_chunk_edits_dirty() -> void:
	_chunk_edits_dirty = true
	_chunk_edits_save_timer = 0.0

func _get_generated_block_at_world(wx: int, wy: int, wz: int) -> int:
	var hgt: int = get_height_at_world(wx, wz)
	var top_id: int = grass_runtime_id if hgt > sea_level + 1 else sand_runtime_id
	if wy <= hgt:
		if wy == hgt:
			return top_id
		if wy >= hgt - 3:
			return dirt_runtime_id if top_id == grass_runtime_id else sand_runtime_id
		return stone_runtime_id
	if wy <= sea_level:
		return water_runtime_id
	return _get_generated_tree_block_at_world(wx, wy, wz)

func _get_generated_tree_block_at_world(wx: int, wy: int, wz: int) -> int:
	var height_at_callable: Callable = Callable(self, "get_height_at_world")
	for tz in range(wz - 3, wz + 4):
		for tx in range(wx - 3, wx + 4):
			var tcpos: Vector2i = _world_to_chunk(tx, tz)
			var origin_x: int = tcpos.x * dims.x
			var origin_z: int = tcpos.y * dims.z
			var lx: int = tx - origin_x
			var lz: int = tz - origin_z
			if lx < tree_edge_margin or lx >= dims.x - tree_edge_margin:
				continue
			if lz < tree_edge_margin or lz >= dims.z - tree_edge_margin:
				continue
			var ground_y: int = get_height_at_world(tx, tz)
			if ground_y <= sea_level + 1:
				continue
			if not _should_place_tree_at_world(tx, tz, ground_y, height_at_callable, world_seed):
				continue
			var variant: int = _tree_variant_for_world(tx, tz, world_seed)
			var trunk_height: int = _tree_trunk_height_for_variant(variant)
			var base_y: int = ground_y + 1
			if wx == tx and wz == tz and wy >= base_y and wy < base_y + trunk_height:
				return oak_log_runtime_id
			if _tree_has_block_at_variant(variant, tx, base_y, tz, wx, wy, wz):
				return oak_leaves_runtime_id
	return 0

func get_surface_y(wx: int, wz: int) -> int:
	# Fast path: use cached heightmap if available.
	var cpos: Vector2i = _world_to_chunk(wx, wz)
	if _cache.has(cpos):
		var ch: Dictionary = _cache[cpos] as Dictionary
		var hm_v: Variant = ch.get("heightmap")
		if typeof(hm_v) == TYPE_PACKED_INT32_ARRAY:
			var hm: PackedInt32Array = hm_v as PackedInt32Array
			var origin_x: int = cpos.x * dims.x
			var origin_z: int = cpos.y * dims.z
			var lx: int = wx - origin_x
			var lz: int = wz - origin_z
			if lx >= 0 and lx < dims.x and lz >= 0 and lz < dims.z:
				var hi: int = lx + lz * dims.x
				if hi >= 0 and hi < hm.size():
					return int(hm[hi]) + 1

	# Fallback: deterministic surface including sea level
	return maxi(get_height_at_world(wx, wz) + 1, sea_level + 1)

# ----------------------------
# Break / Place (cached)
# ----------------------------

func _on_chunk_loaded_for_break(result: Dictionary, wx: int, wy: int, wz: int) -> void:
	if result.has("error"):
		return
	var cpos: Vector2i = _world_to_chunk(wx, wz)
	if _cache.has(cpos):
		_break_in_cached_chunk(cpos, wx, wy, wz)

func _on_chunk_loaded_for_place(result: Dictionary, wx: int, wy: int, wz: int, runtime_id: int) -> void:
	if result.has("error"):
		return
	var cpos: Vector2i = _world_to_chunk(wx, wz)
	if _cache.has(cpos):
		_place_in_cached_chunk(cpos, wx, wy, wz, runtime_id)

func _break_in_cached_chunk(chunk_pos: Vector2i, wx: int, wy: int, wz: int) -> bool:
	if wy < 0 or wy >= dims.y:
		return false

	var ch: Dictionary = _cache[chunk_pos] as Dictionary
	var vox_v: Variant = ch.get("voxels")
	if typeof(vox_v) != TYPE_PACKED_BYTE_ARRAY:
		return false
	var vox: PackedByteArray = vox_v as PackedByteArray

	var origin_x: int = chunk_pos.x * dims.x
	var origin_z: int = chunk_pos.y * dims.z
	var lx: int = wx - origin_x
	var lz: int = wz - origin_z
	if lx < 0 or lx >= dims.x or lz < 0 or lz >= dims.z:
		return false

	var li: int = _idx_local(lx, wy, lz)
	if li < 0 or li >= vox.size():
		return false

	var old_id: int = int(vox[li])
	if old_id == 0:
		return false

	vox[li] = 0
	ch["voxels"] = vox

	# Update heightmap for this column (fast surface queries)
	_update_heightmap_for_column(ch, lx, lz, vox)

	_cache[chunk_pos] = ch

	var edits_v: Variant = _chunk_edits.get(chunk_pos, {})
	var edits: Dictionary = edits_v as Dictionary
	edits[li] = 0
	_chunk_edits[chunk_pos] = edits
	_mark_chunk_edits_dirty()

	emit_signal("block_broken", Vector3i(wx, wy, wz), old_id)

	_schedule_remesh_front(chunk_pos)
	_rebuild_neighbor_mesh_if_edge(chunk_pos, lx, lz)
	return true

func _place_in_cached_chunk(chunk_pos: Vector2i, wx: int, wy: int, wz: int, runtime_id: int) -> bool:
	if wy < 0 or wy >= dims.y:
		return false
	if runtime_id == 0:
		return false

	var ch: Dictionary = _cache[chunk_pos] as Dictionary
	var vox_v: Variant = ch.get("voxels")
	if typeof(vox_v) != TYPE_PACKED_BYTE_ARRAY:
		return false
	var vox: PackedByteArray = vox_v as PackedByteArray

	var origin_x: int = chunk_pos.x * dims.x
	var origin_z: int = chunk_pos.y * dims.z
	var lx: int = wx - origin_x
	var lz: int = wz - origin_z
	if lx < 0 or lx >= dims.x or lz < 0 or lz >= dims.z:
		return false

	var li: int = _idx_local(lx, wy, lz)
	if li < 0 or li >= vox.size():
		return false

	if int(vox[li]) != 0:
		return false

	vox[li] = runtime_id
	ch["voxels"] = vox

	_update_heightmap_for_column(ch, lx, lz, vox)

	_cache[chunk_pos] = ch

	var edits_v: Variant = _chunk_edits.get(chunk_pos, {})
	var edits: Dictionary = edits_v as Dictionary
	edits[li] = runtime_id
	_chunk_edits[chunk_pos] = edits
	_mark_chunk_edits_dirty()

	emit_signal("block_placed", Vector3i(wx, wy, wz), runtime_id)

	_schedule_remesh_front(chunk_pos)
	_rebuild_neighbor_mesh_if_edge(chunk_pos, lx, lz)
	return true

func _schedule_neighbor_remesh_if_edge(chunk_pos: Vector2i, lx: int, lz: int) -> void:
	if lx == 0:
		_schedule_remesh(Vector2i(chunk_pos.x - 1, chunk_pos.y))
	elif lx == dims.x - 1:
		_schedule_remesh(Vector2i(chunk_pos.x + 1, chunk_pos.y))

	if lz == 0:
		_schedule_remesh(Vector2i(chunk_pos.x, chunk_pos.y - 1))
	elif lz == dims.z - 1:
		_schedule_remesh(Vector2i(chunk_pos.x, chunk_pos.y + 1))

func _rebuild_neighbor_mesh_if_edge(chunk_pos: Vector2i, lx: int, lz: int) -> void:
	# Keep the edited chunk instant, but rebuild neighbor chunks asynchronously.
	# This preserves edge correctness without hitching the frame every time a border block changes.
	if lx == 0:
		_schedule_remesh(Vector2i(chunk_pos.x - 1, chunk_pos.y))
	elif lx == dims.x - 1:
		_schedule_remesh(Vector2i(chunk_pos.x + 1, chunk_pos.y))

	if lz == 0:
		_schedule_remesh(Vector2i(chunk_pos.x, chunk_pos.y - 1))
	elif lz == dims.z - 1:
		_schedule_remesh(Vector2i(chunk_pos.x, chunk_pos.y + 1))

func _bump_mesh_revision(chunk_pos: Vector2i) -> int:
	var rev: int = int(_mesh_revision.get(chunk_pos, 0)) + 1
	_mesh_revision[chunk_pos] = rev
	return rev

func _schedule_remesh(chunk_pos: Vector2i) -> void:
	if not _cache.has(chunk_pos):
		return
	_bump_mesh_revision(chunk_pos)
	# If a mesh build is already running, mark dirty so we rebuild again afterwards.
	if _mesh_jobs.has(chunk_pos):
		_mesh_dirty[chunk_pos] = true
		return
	if _pending_mesh.has(chunk_pos):
		return
	_pending_mesh.append(chunk_pos)

func _rebuild_chunk_mesh_now(chunk_pos: Vector2i) -> void:
	if not _cache.has(chunk_pos):
		return
	var rev: int = _bump_mesh_revision(chunk_pos)
	var payload: Dictionary = _build_mesh_job_payload(chunk_pos)
	payload["revision"] = rev
	var result: Dictionary = _build_mesh_result(chunk_pos, payload)
	_apply_mesh_build_result(chunk_pos, result)

func _schedule_remesh_front(chunk_pos: Vector2i) -> void:
	if not _cache.has(chunk_pos):
		return
	_bump_mesh_revision(chunk_pos)
	if _mesh_jobs.has(chunk_pos):
		_mesh_dirty[chunk_pos] = true
		return
	if _pending_mesh.has(chunk_pos):
		_pending_mesh.erase(chunk_pos)
	_pending_mesh.push_front(chunk_pos)

func _apply_mesh_build_result(chunk_pos: Vector2i, result: Dictionary) -> void:
	var result_revision: int = int(result.get("revision", 0))
	var current_revision: int = int(_mesh_revision.get(chunk_pos, 0))
	if result_revision != 0 and result_revision != current_revision:
		return
	var arrays_v: Variant = result.get("mesh_arrays")
	if typeof(arrays_v) != TYPE_DICTIONARY:
		return
	var mesh_arrays: Dictionary = arrays_v as Dictionary

	if _cache.has(chunk_pos):
		var ch: Dictionary = _cache[chunk_pos] as Dictionary
		ch["mesh_arrays"] = mesh_arrays
		_cache[chunk_pos] = ch

	emit_signal("chunk_mesh_updated", chunk_pos, mesh_arrays)

func _on_mesh_built(chunk_pos: Vector2i, result_v: Variant) -> void:
	if typeof(result_v) != TYPE_DICTIONARY:
		return
	var result: Dictionary = result_v as Dictionary
	_apply_mesh_build_result(chunk_pos, result)

	if _mesh_dirty.has(chunk_pos):
		_mesh_dirty.erase(chunk_pos)
		_schedule_remesh_front(chunk_pos)

# ----------------------------
# Heightmap
# ----------------------------

func _update_heightmap_for_column(ch: Dictionary, lx: int, lz: int, vox: PackedByteArray) -> void:
	var hm_v: Variant = ch.get("heightmap")
	var hm: PackedInt32Array
	if typeof(hm_v) == TYPE_PACKED_INT32_ARRAY:
		hm = hm_v as PackedInt32Array
	else:
		hm = PackedInt32Array()
		hm.resize(dims.x * dims.z)

	var hi: int = lx + lz * dims.x
	var top: int = -1
	# Scan down from top for this column only.
	for y in range(dims.y - 1, -1, -1):
		var li: int = _idx_local(lx, y, lz)
		if li >= 0 and li < vox.size() and int(vox[li]) != 0:
			top = y
			break

	hm[hi] = top
	ch["heightmap"] = hm
	var mesh_top: int = max(sea_level, 0)
	for hm_entry in hm:
		mesh_top = maxi(mesh_top, int(hm_entry))
	ch["mesh_y_max"] = clampi(mesh_top + 2, 0, dims.y - 1)

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
		"dirt_id": dirt_runtime_id,
		"log_id": oak_log_runtime_id,
		"leaves_id": oak_leaves_runtime_id,
		"planks_id": oak_planks_runtime_id,
		"crafting_table_id": crafting_table_runtime_id,
		"water_id": water_runtime_id,
		"stone_id": stone_runtime_id,
		"sand_id": sand_runtime_id,
		"sea_level": sea_level,
		"edits": edits,
		"neighbors": neighbors
	}

func _build_mesh_job_payload(chunk_pos: Vector2i) -> Dictionary:
	var ch: Dictionary = _cache[chunk_pos] as Dictionary
	var vox_v: Variant = ch.get("voxels")
	var vox: PackedByteArray = vox_v as PackedByteArray
	var neighbors: Dictionary = _get_neighbor_voxels(chunk_pos)
	var mesh_y_max: int = int(ch.get("mesh_y_max", _estimate_mesh_y_max(vox)))

	return {
		"seed": world_seed,
		"dims": dims,
		"freq": terrain_frequency,
		"base_h": terrain_base_height,
		"scale_h": terrain_height_scale,
		"grass_id": grass_runtime_id,
		"dirt_id": dirt_runtime_id,
		"log_id": oak_log_runtime_id,
		"leaves_id": oak_leaves_runtime_id,
		"planks_id": oak_planks_runtime_id,
		"crafting_table_id": crafting_table_runtime_id,
		"water_id": water_runtime_id,
		"stone_id": stone_runtime_id,
		"sand_id": sand_runtime_id,
		"sea_level": sea_level,
		"voxels": vox,
		"neighbors": neighbors,
		"mesh_y_max": mesh_y_max,
		"revision": int(_mesh_revision.get(chunk_pos, 0))
	}

func _get_neighbor_voxels(chunk_pos: Vector2i) -> Dictionary:
	var out: Dictionary = {}
	_try_put_neighbor_voxels(out, "W", Vector2i(chunk_pos.x - 1, chunk_pos.y))
	_try_put_neighbor_voxels(out, "E", Vector2i(chunk_pos.x + 1, chunk_pos.y))
	_try_put_neighbor_voxels(out, "N", Vector2i(chunk_pos.x, chunk_pos.y - 1))
	_try_put_neighbor_voxels(out, "S", Vector2i(chunk_pos.x, chunk_pos.y + 1))
	return out

func _try_put_neighbor_voxels(out: Dictionary, key: String, pos: Vector2i) -> void:
	if not _cache.has(pos):
		return
	var ch: Dictionary = _cache[pos] as Dictionary
	var vox_v: Variant = ch.get("voxels")
	if typeof(vox_v) == TYPE_PACKED_BYTE_ARRAY:
		out[key] = vox_v

func _estimate_mesh_y_max(vox: PackedByteArray) -> int:
	for y in range(dims.y - 1, -1, -1):
		var row_base: int = y * dims.x * dims.z
		var row_end: int = row_base + dims.x * dims.z
		for i in range(row_base, row_end):
			if i >= 0 and i < vox.size() and int(vox[i]) != 0:
				return y
	return 0

func _queue_adjacent_chunk_refreshes(chunk_pos: Vector2i) -> void:
	var neighbors: Array[Vector2i] = [
		Vector2i(chunk_pos.x - 1, chunk_pos.y),
		Vector2i(chunk_pos.x + 1, chunk_pos.y),
		Vector2i(chunk_pos.x, chunk_pos.y - 1),
		Vector2i(chunk_pos.x, chunk_pos.y + 1)
	]
	for npos in neighbors:
		if _cache.has(npos):
			_schedule_remesh_front(npos)

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

	_queue_adjacent_chunk_refreshes(chunk_pos)

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
			cb.call({"chunk_pos": chunk_pos, "error": msg})

func _thread_generate_chunk(chunk_pos: Vector2i, cfg: Dictionary) -> Dictionary:
	var local_seed: int = int(cfg["seed"])
	var local_dims: Vector3i = cfg["dims"] as Vector3i
	var freq: float = float(cfg["freq"])
	var base_h: int = int(cfg["base_h"])
	var scale_h: int = int(cfg["scale_h"])
	var grass_id: int = int(cfg["grass_id"])
	var dirt_id: int = int(cfg.get("dirt_id", grass_id))
	var log_id: int = int(cfg.get("log_id", grass_id))
	var leaves_id: int = int(cfg.get("leaves_id", grass_id))
	var planks_id: int = int(cfg.get("planks_id", dirt_id))
	var crafting_table_id: int = int(cfg.get("crafting_table_id", planks_id))
	var water_id: int = int(cfg.get("water_id", 0))
	var stone_id: int = int(cfg.get("stone_id", dirt_id))
	var sand_id: int = int(cfg.get("sand_id", dirt_id))
	var local_sea_level: int = int(cfg.get("sea_level", base_h - 2))

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
		return clampi(h, 1, local_dims.y - 2)

	var vox := PackedByteArray()
	vox.resize(sx * sy * sz)

	for z in range(sz):
		for x in range(sx):
			var wx: int = origin_x + x
			var wz: int = origin_z + z
			var hh: int = int(height_at.call(wx, wz))
			var top_id: int = grass_id if hh > local_sea_level + 1 else sand_id
			for y in range(sy):
				if y > hh:
					vox[idx.call(x, y, z)] = water_id if y <= local_sea_level else 0
				elif y == hh:
					vox[idx.call(x, y, z)] = top_id
				elif y >= hh - 3:
					vox[idx.call(x, y, z)] = dirt_id if top_id == grass_id else sand_id
				else:
					vox[idx.call(x, y, z)] = stone_id

	for z in range(tree_edge_margin, sz - tree_edge_margin):
		for x in range(tree_edge_margin, sx - tree_edge_margin):
			var wx_tree: int = origin_x + x
			var wz_tree: int = origin_z + z
			var ground_y: int = int(height_at.call(wx_tree, wz_tree))
			if ground_y > local_sea_level + 1 and _should_place_tree_at_world(wx_tree, wz_tree, ground_y, height_at, local_seed):
				_place_tree_into_voxels(vox, sx, sy, sz, x, ground_y + 1, z, log_id, leaves_id, _tree_variant_for_world(wx_tree, wz_tree, local_seed))

	# Apply sparse edits
	var edit_keys: Array = edits.keys()
	for i in range(edit_keys.size()):
		var k: Variant = edit_keys[i]
		var li: int = int(k)
		if li >= 0 and li < vox.size():
			vox[li] = int(edits[li])

	# Build heightmap (top solid y per column)
	var hm := PackedInt32Array()
	hm.resize(sx * sz)
	for z in range(sz):
		for x in range(sx):
			var top: int = -1
			for y in range(sy - 1, -1, -1):
				if int(vox[idx.call(x, y, z)]) != 0:
					top = y
					break
			hm[x + z * sx] = top

	# World sampler with neighbor support and deterministic fallback for uncached neighbors.
	var generated_block_at := func(wx: int, wy: int, wz: int) -> int:
		var hh2: int = int(height_at.call(wx, wz))
		var top_id2: int = grass_id if hh2 > local_sea_level + 1 else sand_id
		if wy <= hh2:
			if wy == hh2:
				return top_id2
			if wy >= hh2 - 3:
				return dirt_id if top_id2 == grass_id else sand_id
			return stone_id
		if wy <= local_sea_level:
			return water_id
		for tz in range(wz - 3, wz + 4):
			for tx in range(wx - 3, wx + 4):
				var ground_y2: int = int(height_at.call(tx, tz))
				if ground_y2 <= local_sea_level + 1:
					continue
				if not _should_place_tree_at_world(tx, tz, ground_y2, height_at, local_seed):
					continue
				var variant2: int = _tree_variant_for_world(tx, tz, local_seed)
				var trunk_height2: int = _tree_trunk_height_for_variant(variant2)
				var base_y2: int = ground_y2 + 1
				if wx == tx and wz == tz and wy >= base_y2 and wy < base_y2 + trunk_height2:
					return log_id
				if _tree_has_block_at_variant(variant2, tx, base_y2, tz, wx, wy, wz):
					return leaves_id
		return 0
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

		return int(generated_block_at.call(wx, wy, wz))

	var chunk_origin_world := Vector3(origin_x, 0, origin_z)
	var mesh_y_max: int = 0
	for hm_v in hm:
		mesh_y_max = maxi(mesh_y_max, int(hm_v))
	mesh_y_max = clampi(mesh_y_max + 2, 0, sy - 1)

	var face_material_for_runtime := func(rid: int, axis: int, dir: int) -> int:
		return _face_material_id_for_runtime(rid, axis, dir, grass_id, dirt_id, log_id, leaves_id, planks_id, crafting_table_id)
	var is_runtime_renderable := func(rid: int) -> bool:
		return rid != 0
	var face_occludes_neighbor := func(a_rid: int, b_rid: int, _axis: int, _dir: int) -> bool:
		if a_rid == 0:
			return false
		if a_rid == water_id:
			return b_rid != 0 and b_rid != leaves_id
		if a_rid == leaves_id:
			return b_rid != 0 and b_rid != water_id and b_rid != leaves_id
		return b_rid != 0 and b_rid != water_id

	var mesh_arrays: Dictionary = KZ_ChunkMeshBuilder.build_mesh_arrays(
		chunk_origin_world,
		local_dims,
		get_block_world,
		face_material_for_runtime,
		is_runtime_renderable,
		face_occludes_neighbor,
		mesh_y_max
	)

	return {
		"chunk_pos": chunk_pos,
		"origin": chunk_origin_world,
		"dims": local_dims,
		"voxels": vox,
		"mesh_arrays": mesh_arrays,
		"heightmap": hm,
		"mesh_y_max": mesh_y_max
	}

func _thread_build_mesh(chunk_pos: Vector2i, payload: Dictionary) -> Dictionary:
	return _build_mesh_result(chunk_pos, payload)

func _build_mesh_result(chunk_pos: Vector2i, payload: Dictionary) -> Dictionary:
	var local_seed: int = int(payload["seed"])
	var local_dims: Vector3i = payload["dims"] as Vector3i
	var freq: float = float(payload["freq"])
	var base_h: int = int(payload["base_h"])
	var scale_h: int = int(payload["scale_h"])
	var grass_id: int = int(payload["grass_id"])
	var dirt_id: int = int(payload.get("dirt_id", grass_id))
	var log_id: int = int(payload.get("log_id", grass_id))
	var leaves_id: int = int(payload.get("leaves_id", grass_id))
	var planks_id: int = int(payload.get("planks_id", dirt_id))
	var crafting_table_id: int = int(payload.get("crafting_table_id", planks_id))
	var water_id: int = int(payload.get("water_id", 0))
	var stone_id: int = int(payload.get("stone_id", dirt_id))
	var sand_id: int = int(payload.get("sand_id", dirt_id))
	var local_sea_level: int = int(payload.get("sea_level", base_h - 2))

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
		return clampi(h, 1, local_dims.y - 2)

	var generated_block_at := func(wx: int, wy: int, wz: int) -> int:
		var hh: int = int(height_at.call(wx, wz))
		var top_id: int = grass_id if hh > local_sea_level + 1 else sand_id
		if wy <= hh:
			if wy == hh:
				return top_id
			if wy >= hh - 3:
				return dirt_id if top_id == grass_id else sand_id
			return stone_id
		if wy <= local_sea_level:
			return water_id
		for tz in range(wz - 3, wz + 4):
			for tx in range(wx - 3, wx + 4):
				var ground_y2: int = int(height_at.call(tx, tz))
				if ground_y2 <= local_sea_level + 1:
					continue
				if not _should_place_tree_at_world(tx, tz, ground_y2, height_at, local_seed):
					continue
				var variant2: int = _tree_variant_for_world(tx, tz, local_seed)
				var trunk_height2: int = _tree_trunk_height_for_variant(variant2)
				var base_y2: int = ground_y2 + 1
				if wx == tx and wz == tz and wy >= base_y2 and wy < base_y2 + trunk_height2:
					return log_id
				if _tree_has_block_at_variant(variant2, tx, base_y2, tz, wx, wy, wz):
					return leaves_id
		return 0
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

		return int(generated_block_at.call(wx, wy, wz))

	var chunk_origin_world := Vector3(origin_x, 0, origin_z)
	var mesh_y_max: int = clampi(int(payload.get("mesh_y_max", sy - 1)), 0, sy - 1)
	var face_material_for_runtime := func(rid: int, axis: int, dir: int) -> int:
		return _face_material_id_for_runtime(rid, axis, dir, grass_id, dirt_id, log_id, leaves_id, planks_id, crafting_table_id)
	var is_runtime_renderable := func(rid: int) -> bool:
		return rid != 0
	var face_occludes_neighbor := func(a_rid: int, b_rid: int, _axis: int, _dir: int) -> bool:
		if a_rid == 0:
			return false
		if a_rid == water_id:
			return b_rid != 0 and b_rid != leaves_id
		if a_rid == leaves_id:
			return b_rid != 0 and b_rid != water_id and b_rid != leaves_id
		return b_rid != 0 and b_rid != water_id

	var mesh_arrays: Dictionary = KZ_ChunkMeshBuilder.build_mesh_arrays(
		chunk_origin_world,
		local_dims,
		get_block_world,
		face_material_for_runtime,
		is_runtime_renderable,
		face_occludes_neighbor,
		mesh_y_max
	)

	return {"chunk_pos": chunk_pos, "mesh_arrays": mesh_arrays, "revision": int(payload.get("revision", 0))}

# ----------------------------
# Material + tree helpers
# ----------------------------

func _face_material_id_for_runtime(rid: int, axis: int, dir: int, grass_id: int, dirt_id: int, log_id: int, leaves_id: int, planks_id: int, crafting_table_id: int) -> int:
	if rid == grass_id:
		if axis == 1 and dir == +1:
			return 1
		if axis == 1 and dir == -1:
			return 2
		return 0
	if rid == dirt_id:
		return 2
	if rid == log_id:
		if axis == 1:
			return 4
		return 3
	if rid == leaves_id:
		return 5
	if rid == planks_id:
		return 6
	if rid == crafting_table_id:
		if axis == 1 and dir == +1:
			return 8
		if axis == 1 and dir == -1:
			return 6
		return 7
	if rid == water_runtime_id:
		return 9
	if rid == sand_runtime_id:
		return 10
	if rid == stone_runtime_id:
		return 11
	return 2

func _should_place_tree_at_world(wx: int, wz: int, ground_y: int, height_at: Callable, local_seed: int) -> bool:
	var n: int = wx * 73428767 + wz * 912931 + local_seed * 31
	n = abs(n)
	if int(n % 100) >= tree_spawn_chance_percent:
		return false
	if abs(int(height_at.call(wx - 1, wz)) - ground_y) > 1:
		return false
	if abs(int(height_at.call(wx + 1, wz)) - ground_y) > 1:
		return false
	if abs(int(height_at.call(wx, wz - 1)) - ground_y) > 1:
		return false
	if abs(int(height_at.call(wx, wz + 1)) - ground_y) > 1:
		return false
	return true

func _tree_variant_for_world(wx: int, wz: int, local_seed: int) -> int:
	var n: int = abs(wx * 19349663 + wz * 83492791 + local_seed * 97)
	return int(n % 3)

func _tree_trunk_height_for_variant(variant: int) -> int:
	match variant:
		0:
			return 4
		1:
			return 5
		_:
			return 7

func _tree_has_leaf_offset_variant(variant: int, ox: int, oy: int, oz: int) -> bool:
	var ax: int = abs(ox)
	var az: int = abs(oz)
	match variant:
		0:
			match oy:
				-1:
					return maxi(ax, az) <= 1
				0, 1:
					return maxi(ax, az) <= 2 and not (ax == 2 and az == 2)
				2:
					return ax + az <= 1
				_:
					return false
		1:
			match oy:
				-1:
					return maxi(ax, az) <= 1
				0, 1:
					return maxi(ax, az) <= 2 and not (ax == 2 and az == 2)
				2:
					return ax + az <= 1
				3:
					return ax == 0 and az == 0
				_:
					return false
		_:
			match oy:
				-2, -1:
					return maxi(ax, az) <= 1
				0, 1:
					return maxi(ax, az) <= 2
				2:
					return maxi(ax, az) <= 2 and not (ax == 2 and az == 2)
				3:
					return ax + az <= 1
				4:
					return ax == 0 and az == 0
				_:
					return false

func _tree_has_block_at_variant(variant: int, trunk_x: int, base_y: int, trunk_z: int, wx: int, wy: int, wz: int) -> bool:
	var trunk_height: int = _tree_trunk_height_for_variant(variant)
	var canopy_base_y: int = base_y + trunk_height - 2
	var ox: int = wx - trunk_x
	var oy: int = wy - canopy_base_y
	var oz: int = wz - trunk_z
	return _tree_has_leaf_offset_variant(variant, ox, oy, oz)

func _place_tree_into_voxels(vox: PackedByteArray, sx: int, sy: int, sz: int, base_x: int, base_y: int, base_z: int, log_id: int, leaves_id: int, variant: int = 1) -> void:
	var idx := func(x: int, y: int, z: int) -> int:
		return x + z * sx + y * sx * sz

	var trunk_height: int = _tree_trunk_height_for_variant(variant)
	for dy in range(trunk_height):
		var y: int = base_y + dy
		if y >= 0 and y < sy:
			var li: int = idx.call(base_x, y, base_z)
			if li >= 0 and li < vox.size():
				vox[li] = log_id

	if variant == 2:
		for branch in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var bx: int = base_x + branch.x
			var bz: int = base_z + branch.y
			var by: int = base_y + trunk_height - 2
			if bx >= 0 and bx < sx and bz >= 0 and bz < sz and by >= 0 and by < sy:
				var bli: int = idx.call(bx, by, bz)
				if bli >= 0 and bli < vox.size() and vox[bli] == 0:
					vox[bli] = log_id

	var canopy_base_y: int = base_y + trunk_height - 2
	var y_min: int = -2 if variant == 2 else -1
	var y_max: int = 5 if variant == 2 else 4
	for oy in range(y_min, y_max):
		for ox in range(-2, 3):
			for oz in range(-2, 3):
				if not _tree_has_leaf_offset_variant(variant, ox, oy, oz):
					continue
				var x: int = base_x + ox
				var y: int = canopy_base_y + oy
				var z: int = base_z + oz
				if x < 0 or x >= sx or y < 0 or y >= sy or z < 0 or z >= sz:
					continue
				var li2: int = idx.call(x, y, z)
				if li2 < 0 or li2 >= vox.size():
					continue
				if vox[li2] == 0:
					vox[li2] = leaves_id

# ----------------------------
# Config / helpers
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
	max_worker_threads = clampi(int(wg.get("max_worker_threads", 2)), 1, maxi(1, OS.get_processor_count() - 1))
	cache_max_chunks = int(wg.get("cache_max_chunks", 256))

	world_seed = int(terrain_cfg.get("seed", 1337))
	terrain_frequency = float(terrain_cfg.get("frequency", 0.008))
	terrain_base_height = int(terrain_cfg.get("base_height", 64))
	terrain_height_scale = int(terrain_cfg.get("height_scale", 28))
	sea_level = int(terrain_cfg.get("sea_level", terrain_base_height - 2))
	tree_spawn_chance_percent = int(terrain_cfg.get("tree_spawn_chance_percent", tree_spawn_chance_percent))
	tree_edge_margin = int(terrain_cfg.get("tree_edge_margin", tree_edge_margin))
	tree_spawn_chance_percent = clampi(tree_spawn_chance_percent, 0, 100)
	tree_edge_margin = clampi(tree_edge_margin, 2, 6)
	sea_level = clampi(sea_level, 1, dims.y - 8)


func save_world_state() -> void:
	if _chunk_edits_dirty:
		_save_chunk_edits()
	var level_path: String = KZ_PathUtil.join(world_root, "level.dat")
	var txt: String = KZ_PathUtil.read_text(level_path)
	var parsed_v: Variant = JSON.parse_string(txt)
	if typeof(parsed_v) == TYPE_DICTIONARY:
		var parsed: Dictionary = parsed_v as Dictionary
		parsed["last_played_utc"] = Time.get_datetime_string_from_system(true)
		KZ_PathUtil.write_text(level_path, JSON.stringify(parsed, "	"))

func _edits_path() -> String:
	return KZ_PathUtil.join(world_root, "chunks/edits.json")

func _load_chunk_edits() -> void:
	_chunk_edits.clear()
	var path: String = _edits_path()
	if not KZ_PathUtil.file_exists(path):
		return
	var txt: String = KZ_PathUtil.read_text(path)
	var parsed_v: Variant = JSON.parse_string(txt)
	if typeof(parsed_v) != TYPE_DICTIONARY:
		return
	var parsed: Dictionary = parsed_v as Dictionary
	for key_v in parsed.keys():
		var key: String = str(key_v)
		var packed: PackedStringArray = key.split(",", false)
		if packed.size() != 2:
			continue
		if not packed[0].is_valid_int() or not packed[1].is_valid_int():
			continue
		var cpos := Vector2i(int(packed[0]), int(packed[1]))
		var entry_v: Variant = parsed[key]
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_v as Dictionary
		var edits: Dictionary = {}
		for li_v in entry.keys():
			var li_str: String = str(li_v)
			if not li_str.is_valid_int():
				continue
			edits[int(li_str)] = int(entry[li_v])
		_chunk_edits[cpos] = edits

func _save_chunk_edits() -> void:
	var out: Dictionary = {}
	for cpos_v in _chunk_edits.keys():
		if typeof(cpos_v) != TYPE_VECTOR2I:
			continue
		var cpos: Vector2i = cpos_v as Vector2i
		var edits_v: Variant = _chunk_edits[cpos]
		if typeof(edits_v) != TYPE_DICTIONARY:
			continue
		var edits: Dictionary = edits_v as Dictionary
		var packed: Dictionary = {}
		for li_v in edits.keys():
			packed[str(li_v)] = int(edits[li_v])
		out["%d,%d" % [cpos.x, cpos.y]] = packed
	KZ_PathUtil.write_text(_edits_path(), JSON.stringify(out, "	"))
	_chunk_edits_dirty = false
	_chunk_edits_save_timer = 0.0

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

func _rebuild_main_noise() -> void:
	_main_noise = FastNoiseLite.new()
	_main_noise.seed = world_seed
	_main_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_main_noise.frequency = terrain_frequency

func _world_to_chunk(wx: int, wz: int) -> Vector2i:
	var cx: int = int(floor(float(wx) / float(dims.x)))
	var cz: int = int(floor(float(wz) / float(dims.z)))
	return Vector2i(cx, cz)

func _idx_local(x: int, y: int, z: int) -> int:
	return x + z * dims.x + y * dims.x * dims.z
