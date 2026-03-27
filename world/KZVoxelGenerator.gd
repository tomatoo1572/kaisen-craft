extends VoxelGeneratorScript
class_name KZ_VoxelGenerator

const CHANNEL: int = VoxelBuffer.CHANNEL_TYPE

var dims: Vector3i = Vector3i(16, 256, 16)
var terrain_frequency: float = 0.008
var terrain_base_height: int = 64
var terrain_height_scale: int = 28
var sea_level: int = 62
var tree_spawn_chance_percent: int = 1
var tree_edge_margin: int = 3
var world_seed: int = 1337

var grass_runtime_id: int = 1
var dirt_runtime_id: int = 2
var oak_log_runtime_id: int = 3
var oak_leaves_runtime_id: int = 4
var oak_planks_runtime_id: int = 5
var crafting_table_runtime_id: int = 7
var water_runtime_id: int = 9
var stone_runtime_id: int = 10
var sand_runtime_id: int = 11

var _chunk_edits: Dictionary = {}
var _edit_mutex: Mutex = Mutex.new()

func configure(worldgen_cfg: Dictionary, registry: KZ_BlockRegistry) -> void:
	var wg: Dictionary = {}
	var terrain_cfg: Dictionary = {}
	if worldgen_cfg.get("worldgen", {}) is Dictionary:
		wg = worldgen_cfg.get("worldgen", {}) as Dictionary
	if worldgen_cfg.get("terrain", {}) is Dictionary:
		terrain_cfg = worldgen_cfg.get("terrain", {}) as Dictionary

	dims = Vector3i(
		int(wg.get("chunk_size_x", 16)),
		int(wg.get("chunk_size_y", 256)),
		int(wg.get("chunk_size_z", 16))
	)
	world_seed = int(terrain_cfg.get("seed", 1337))
	terrain_frequency = float(terrain_cfg.get("frequency", 0.008))
	terrain_base_height = int(terrain_cfg.get("base_height", 64))
	terrain_height_scale = int(terrain_cfg.get("height_scale", 28))
	sea_level = int(terrain_cfg.get("sea_level", terrain_base_height - 2))
	tree_spawn_chance_percent = clampi(int(terrain_cfg.get("tree_spawn_chance_percent", 1)), 0, 100)
	tree_edge_margin = clampi(int(terrain_cfg.get("tree_edge_margin", 3)), 2, 6)

	if registry != null:
		grass_runtime_id = registry.get_runtime_id("kaizencraft:grass")
		dirt_runtime_id = registry.get_runtime_id("kaizencraft:dirt")
		oak_log_runtime_id = registry.get_runtime_id("kaizencraft:oak_log")
		oak_leaves_runtime_id = registry.get_runtime_id("kaizencraft:oak_leaves")
		oak_planks_runtime_id = registry.get_runtime_id("kaizencraft:oak_planks")
		crafting_table_runtime_id = registry.get_runtime_id("kaizencraft:crafting_table")
		water_runtime_id = registry.get_runtime_id("kaizencraft:water")
		stone_runtime_id = registry.get_runtime_id("kaizencraft:stone")
		sand_runtime_id = registry.get_runtime_id("kaizencraft:sand")

func set_chunk_edits_snapshot(snapshot: Dictionary) -> void:
	_edit_mutex.lock()
	_chunk_edits = snapshot.duplicate(true)
	_edit_mutex.unlock()

func set_block_edit_world(wx: int, wy: int, wz: int, runtime_id: int) -> void:
	if wy < 0 or wy >= dims.y:
		return
	var cpos: Vector2i = _world_to_chunk(wx, wz)
	var origin_x: int = cpos.x * dims.x
	var origin_z: int = cpos.y * dims.z
	var lx: int = wx - origin_x
	var lz: int = wz - origin_z
	if lx < 0 or lx >= dims.x or lz < 0 or lz >= dims.z:
		return
	var li: int = _idx_local(lx, wy, lz)

	_edit_mutex.lock()
	var edits: Dictionary = {}
	if _chunk_edits.has(cpos):
		edits = (_chunk_edits[cpos] as Dictionary).duplicate()
	var base_noise: FastNoiseLite = _make_noise()
	if runtime_id == _get_generated_block_at_world_with_noise(base_noise, wx, wy, wz):
		edits.erase(li)
	else:
		edits[li] = runtime_id
	if edits.is_empty():
		_chunk_edits.erase(cpos)
	else:
		_chunk_edits[cpos] = edits
	_edit_mutex.unlock()

func _get_used_channels_mask() -> int:
	return 1 << CHANNEL

func _generate_block(buffer: VoxelBuffer, origin: Vector3i, lod: int) -> void:
	buffer.fill(0, CHANNEL)
	if lod != 0:
		return

	var size: Vector3i = buffer.get_size()
	if origin.y >= dims.y or origin.y + size.y <= 0:
		return

	var cpos: Vector2i = _world_to_chunk(origin.x, origin.z)
	var chunk_edits: Dictionary = {}
	_edit_mutex.lock()
	if _chunk_edits.has(cpos):
		chunk_edits = (_chunk_edits[cpos] as Dictionary).duplicate()
	_edit_mutex.unlock()

	var noise: FastNoiseLite = _make_noise()
	for z in range(size.z):
		var wz: int = origin.z + z
		for x in range(size.x):
			var wx: int = origin.x + x
			var hgt: int = _get_height_at_world_with_noise(noise, wx, wz)
			var top_id: int = grass_runtime_id if hgt > sea_level + 1 else sand_runtime_id
			for y in range(size.y):
				var wy: int = origin.y + y
				if wy < 0 or wy >= dims.y:
					continue
				var rid: int = 0
				if wy <= hgt:
					if wy == hgt:
						rid = top_id
					elif wy >= hgt - 3:
						rid = dirt_runtime_id if top_id == grass_runtime_id else sand_runtime_id
					else:
						rid = stone_runtime_id
				elif wy <= sea_level:
					rid = water_runtime_id
				else:
					rid = _get_generated_tree_block_at_world_with_noise(noise, wx, wy, wz)

				var li: int = _idx_local(_posmod(wx, dims.x), wy, _posmod(wz, dims.z))
				if chunk_edits.has(li):
					rid = int(chunk_edits[li])

				buffer.set_voxel(rid, x, y, z, CHANNEL)

func get_height_at_world(wx: int, wz: int) -> int:
	return _get_height_at_world_with_noise(_make_noise(), wx, wz)

func _make_noise() -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = world_seed
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = terrain_frequency
	return noise

func _get_height_at_world_with_noise(noise: FastNoiseLite, wx: int, wz: int) -> int:
	var n: float = noise.get_noise_2d(float(wx), float(wz))
	var h: int = int(round(float(terrain_base_height) + n * float(terrain_height_scale)))
	return clampi(h, 1, dims.y - 2)

func _get_generated_block_at_world_with_noise(noise: FastNoiseLite, wx: int, wy: int, wz: int) -> int:
	if wy < 0 or wy >= dims.y:
		return 0
	var hgt: int = _get_height_at_world_with_noise(noise, wx, wz)
	var top_id: int = grass_runtime_id if hgt > sea_level + 1 else sand_runtime_id
	if wy <= hgt:
		if wy == hgt:
			return top_id
		if wy >= hgt - 3:
			return dirt_runtime_id if top_id == grass_runtime_id else sand_runtime_id
		return stone_runtime_id
	if wy <= sea_level:
		return water_runtime_id
	return _get_generated_tree_block_at_world_with_noise(noise, wx, wy, wz)

func _get_generated_tree_block_at_world_with_noise(noise: FastNoiseLite, wx: int, wy: int, wz: int) -> int:
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
			var ground_y: int = _get_height_at_world_with_noise(noise, tx, tz)
			if ground_y <= sea_level + 1:
				continue
			if not _should_place_tree_at_world_with_noise(noise, tx, tz, ground_y):
				continue
			var variant: int = _tree_variant_for_world(tx, tz)
			var trunk_height: int = _tree_trunk_height_for_variant(variant)
			var base_y: int = ground_y + 1
			if wx == tx and wz == tz and wy >= base_y and wy < base_y + trunk_height:
				return oak_log_runtime_id
			if _tree_has_block_at_variant(variant, tx, base_y, tz, wx, wy, wz):
				return oak_leaves_runtime_id
	return 0

func _should_place_tree_at_world(wx: int, wz: int, ground_y: int) -> bool:
	return _should_place_tree_at_world_with_noise(_make_noise(), wx, wz, ground_y)

func _should_place_tree_at_world_with_noise(noise: FastNoiseLite, wx: int, wz: int, ground_y: int) -> bool:
	var n: int = wx * 73428767 + wz * 912931 + world_seed * 31
	n = abs(n)
	if int(n % 100) >= tree_spawn_chance_percent:
		return false
	if abs(_get_height_at_world_with_noise(noise, wx - 1, wz) - ground_y) > 1:
		return false
	if abs(_get_height_at_world_with_noise(noise, wx + 1, wz) - ground_y) > 1:
		return false
	if abs(_get_height_at_world_with_noise(noise, wx, wz - 1) - ground_y) > 1:
		return false
	if abs(_get_height_at_world_with_noise(noise, wx, wz + 1) - ground_y) > 1:
		return false
	return true

func _tree_variant_for_world(wx: int, wz: int) -> int:
	var n: int = abs(wx * 19349663 + wz * 83492791 + world_seed * 97)
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

func _world_to_chunk(wx: int, wz: int) -> Vector2i:
	return Vector2i(_floor_div(wx, dims.x), _floor_div(wz, dims.z))

func _floor_div(a: int, b: int) -> int:
	return int(floor(float(a) / float(b)))

func _posmod(a: int, b: int) -> int:
	var m: int = a % b
	if m < 0:
		m += abs(b)
	return m

func _idx_local(x: int, y: int, z: int) -> int:
	return x + z * dims.x + y * dims.x * dims.z
