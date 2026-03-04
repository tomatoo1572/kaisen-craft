extends RefCounted
class_name KZ_ConfigManager

var gameplay: Dictionary = {}
var worldgen: Dictionary = {}
var spawns: Dictionary = {}
var loot: Dictionary = {}

func ensure_defaults(instance_root: String) -> void:
	var cfg_dir := KZ_PathUtil.join(instance_root, "config")
	KZ_PathUtil.ensure_dir(cfg_dir)

	# gameplay.toml
	var gameplay_path := KZ_PathUtil.join(cfg_dir, "gameplay.toml")
	if not KZ_PathUtil.file_exists(gameplay_path):
		var d := {
			"player": {
				"walk_speed": 6.0,
				"jump_velocity": 5.5,
				"gravity": 18.0,
				"mouse_sensitivity": 0.12
			}
		}
		var toml := KZ_TomlLite.new().stringify(d)
		KZ_PathUtil.write_text(gameplay_path, toml)

	# worldgen.toml
	var worldgen_path := KZ_PathUtil.join(cfg_dir, "worldgen.toml")
	if not KZ_PathUtil.file_exists(worldgen_path):
		var d2 := {
			"worldgen": {
				"chunk_size_x": 16,
				"chunk_size_y": 256,
				"chunk_size_z": 16,
				"view_distance_chunks": 6,
				"max_worker_threads": 3,
				"cache_max_chunks": 256
			},
			"terrain": {
				"seed": 1337,
				"frequency": 0.008,
				"base_height": 64,
				"height_scale": 28
			}
		}
		var toml2 := KZ_TomlLite.new().stringify(d2)
		KZ_PathUtil.write_text(worldgen_path, toml2)

	# spawns.toml (not used yet, but created)
	var spawns_path := KZ_PathUtil.join(cfg_dir, "spawns.toml")
	if not KZ_PathUtil.file_exists(spawns_path):
		var d3 := {"spawns": {"enabled": true}}
		KZ_PathUtil.write_text(spawns_path, KZ_TomlLite.new().stringify(d3))

	# loot.toml (not used yet, but created)
	var loot_path := KZ_PathUtil.join(cfg_dir, "loot.toml")
	if not KZ_PathUtil.file_exists(loot_path):
		var d4 := {"loot": {"enabled": true}}
		KZ_PathUtil.write_text(loot_path, KZ_TomlLite.new().stringify(d4))

	# default block json(s)
	var blocks_dir := KZ_PathUtil.join(cfg_dir, "blocks")
	KZ_PathUtil.ensure_dir(blocks_dir)

	var grass_json_path := KZ_PathUtil.join(blocks_dir, "grass.json")
	if not KZ_PathUtil.file_exists(grass_json_path):
		var grass := {
			"id": "kaizencraft:grass",
			"name": "Grass",
			"textures": {
				"all": ""
			},
			"tint": "#68c248",
			"hardness": 0.6,
			"required_tool": "none",
			"drops": [{"item": "kaizencraft:grass", "count": 1}],
			"transparency": false,
			"light_level": 0
		}
		KZ_PathUtil.write_text(grass_json_path, JSON.stringify(grass, "\t"))

func load_all(instance_root: String) -> void:
	var cfg_dir := KZ_PathUtil.join(instance_root, "config")

	gameplay = _load_toml(KZ_PathUtil.join(cfg_dir, "gameplay.toml"))
	worldgen = _load_toml(KZ_PathUtil.join(cfg_dir, "worldgen.toml"))
	spawns = _load_toml(KZ_PathUtil.join(cfg_dir, "spawns.toml"))
	loot = _load_toml(KZ_PathUtil.join(cfg_dir, "loot.toml"))

func _load_toml(path: String) -> Dictionary:
	var text := KZ_PathUtil.read_text(path)
	if text == "":
		return {}
	return KZ_TomlLite.new().parse(text)
