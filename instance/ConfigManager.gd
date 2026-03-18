extends RefCounted
class_name KZ_ConfigManager

var gameplay: Dictionary = {}
var worldgen: Dictionary = {}
var spawns: Dictionary = {}
var loot: Dictionary = {}

func ensure_defaults(instance_root: String) -> void:
	var cfg_dir := KZ_PathUtil.join(instance_root, "config")
	KZ_PathUtil.ensure_dir(cfg_dir)

	var gameplay_path := KZ_PathUtil.join(cfg_dir, "gameplay.toml")
	if not KZ_PathUtil.file_exists(gameplay_path):
		var d1 := {
			"gameplay": {
				"player_walk_speed": 4.8,
				"player_jog_speed": 7.2,
				"player_run_speed": 10.6,
				"player_jump_velocity": 6.2,
				"mouse_sensitivity": 0.12,
				"gravity": 28.0,
				"break_range": 6.0,
				"place_range": 6.0,
				"break_cooldown_sec": 0.18,
				"place_cooldown_sec": 0.12,
				"auto_step_enabled": false,
				"step_height": 0.75,
				"max_health": 20.0,
				"starting_health": 20.0,
				"max_hunger": 20.0,
				"starting_hunger": 20.0,
				"max_thirst": 20.0,
				"starting_thirst": 20.0,
				"hunger_drain_interval_sec": 35.0,
				"thirst_drain_interval_sec": 28.0,
				"day_duration_sec": 900.0,
				"night_duration_sec": 1200.0,
				"fov": 75.0,
				"max_fps": 0
			}
		}
		var toml1 := KZ_TomlLite.new().stringify(d1)
		KZ_PathUtil.write_text(gameplay_path, toml1)

	var worldgen_path := KZ_PathUtil.join(cfg_dir, "worldgen.toml")
	if not KZ_PathUtil.file_exists(worldgen_path):
		var d2 := {
			"worldgen": {
				"chunk_size_x": 16,
				"chunk_size_y": 256,
				"chunk_size_z": 16,
				"view_distance_chunks": 6,
				"seed": 1337,
				"frequency": 0.008,
				"base_height": 64,
				"height_scale": 28,
				"tree_spawn_chance_percent": 1,
				"tree_edge_margin": 3
			}
		}
		var toml2 := KZ_TomlLite.new().stringify(d2)
		KZ_PathUtil.write_text(worldgen_path, toml2)

	var spawns_path := KZ_PathUtil.join(cfg_dir, "spawns.toml")
	if not KZ_PathUtil.file_exists(spawns_path):
		var d3 := {"spawns": {"enabled": true}}
		KZ_PathUtil.write_text(spawns_path, KZ_TomlLite.new().stringify(d3))

	var loot_path := KZ_PathUtil.join(cfg_dir, "loot.toml")
	if not KZ_PathUtil.file_exists(loot_path):
		var d4 := {"loot": {"enabled": true}}
		KZ_PathUtil.write_text(loot_path, KZ_TomlLite.new().stringify(d4))

	var blocks_dir := KZ_PathUtil.join(cfg_dir, "blocks")
	KZ_PathUtil.ensure_dir(blocks_dir)
	_ensure_default_block_files(blocks_dir)

	var items_dir := KZ_PathUtil.join(cfg_dir, "items")
	KZ_PathUtil.ensure_dir(items_dir)
	_ensure_default_item_files(items_dir)

	var recipes_dir := KZ_PathUtil.join(cfg_dir, "recipes")
	KZ_PathUtil.ensure_dir(recipes_dir)
	_ensure_default_recipe_file(KZ_PathUtil.join(recipes_dir, "recipes.json"))

func _ensure_default_block_files(blocks_dir: String) -> void:
	_ensure_block_file(
		KZ_PathUtil.join(blocks_dir, "grass.json"),
		{
			"id": "kaizencraft:grass",
			"name": "Grass",
			"textures": {
				"side": "res://assets/textures/blocks/grass.png",
				"top": "res://assets/textures/blocks/grass_top.png",
				"bottom": "res://assets/textures/blocks/dirt.png"
			},
			"tint": "#68c248",
			"hardness": 0.6,
			"required_tool": "none",
			"drops": [{"item": "kaizencraft:grass", "count": 1}],
			"transparency": false,
			"light_level": 0
		}
	)

	_ensure_block_file(
		KZ_PathUtil.join(blocks_dir, "dirt.json"),
		{
			"id": "kaizencraft:dirt",
			"name": "Dirt",
			"textures": {"all": "res://assets/textures/blocks/dirt.png"},
			"tint": "#9b6b3f",
			"hardness": 0.5,
			"required_tool": "none",
			"drops": [{"item": "kaizencraft:dirt", "count": 1}],
			"transparency": false,
			"light_level": 0
		}
	)

	_ensure_block_file(
		KZ_PathUtil.join(blocks_dir, "oak_log.json"),
		{
			"id": "kaizencraft:oak_log",
			"name": "Oak Log",
			"textures": {
				"side": "res://assets/textures/blocks/oak_log.png",
				"top": "res://assets/textures/blocks/oak_log_top.png",
				"bottom": "res://assets/textures/blocks/oak_log_top.png"
			},
			"tint": "#8a5b33",
			"hardness": 1.2,
			"required_tool": "none",
			"drops": [{"item": "kaizencraft:oak_log", "count": 1}],
			"transparency": false,
			"light_level": 0
		}
	)

	_ensure_block_file(
		KZ_PathUtil.join(blocks_dir, "oak_leaves.json"),
		{
			"id": "kaizencraft:oak_leaves",
			"name": "Oak Leaves",
			"textures": {"all": "res://assets/textures/blocks/oak_leaves.png"},
			"tint": "#5fa03a",
			"hardness": 0.2,
			"required_tool": "none",
			"drops": [{"item": "kaizencraft:oak_leaves", "count": 1}],
			"transparency": false,
			"collidable": true,
			"light_level": 0
		}
	)

func _ensure_default_item_files(items_dir: String) -> void:
	_ensure_block_file(
		KZ_PathUtil.join(items_dir, "oak_planks.json"),
		{
			"id": "kaizencraft:oak_planks",
			"name": "Oak Planks",
			"textures": {"all": "res://assets/textures/blocks/oak_planks.png"},
			"tint": "#c79b62",
			"placeable": true,
			"stack_size": 64,
			"transparency": false,
			"light_level": 0
		}
	)

	_ensure_block_file(
		KZ_PathUtil.join(items_dir, "stick.json"),
		{
			"id": "kaizencraft:stick",
			"name": "Stick",
			"textures": {"all": "res://assets/textures/blocks/stick.png"},
			"tint": "#a87d4d",
			"placeable": false,
			"stack_size": 64,
			"transparency": true,
			"light_level": 0
		}
	)

	_ensure_block_file(
		KZ_PathUtil.join(items_dir, "crafting_table.json"),
		{
			"id": "kaizencraft:crafting_table",
			"name": "Crafting Table",
			"textures": {
				"side": "res://assets/textures/blocks/crafting_table_side.png",
				"top": "res://assets/textures/blocks/crafting_table_top.png",
				"bottom": "res://assets/textures/blocks/oak_planks.png"
			},
			"tint": "#b58a55",
			"placeable": true,
			"stack_size": 64,
			"transparency": false,
			"light_level": 0
		}
	)

	_ensure_block_file(
		KZ_PathUtil.join(items_dir, "wooden_axe.json"),
		{
			"id": "kaizencraft:wooden_axe",
			"name": "Wooden Axe",
			"textures": {"all": "res://assets/textures/blocks/wooden_axe.png"},
			"tint": "#b98c55",
			"placeable": false,
			"stack_size": 1,
			"transparency": true,
			"light_level": 0
		}
	)


func _ensure_default_recipe_file(path: String) -> void:
	if KZ_PathUtil.file_exists(path):
		return
	var recipes: Array = [
		{
			"output": "kaizencraft:oak_planks",
			"count": 4,
			"pattern": ["kaizencraft:oak_log"]
		},
		{
			"output": "kaizencraft:stick",
			"count": 4,
			"pattern": ["kaizencraft:oak_planks", "kaizencraft:oak_planks"]
		},
		{
			"output": "kaizencraft:crafting_table",
			"count": 1,
			"pattern": [
				"kaizencraft:oak_planks,kaizencraft:oak_planks",
				"kaizencraft:oak_planks,kaizencraft:oak_planks"
			]
		},
		{
			"output": "kaizencraft:wooden_axe",
			"count": 1,
			"pattern": [
				"kaizencraft:oak_planks,kaizencraft:oak_planks,",
				"kaizencraft:oak_planks,kaizencraft:stick,",
				",,kaizencraft:stick"
			]
		},
		{
			"output": "kaizencraft:wooden_axe",
			"count": 1,
			"pattern": [
				",kaizencraft:oak_planks,kaizencraft:oak_planks",
				",kaizencraft:stick,kaizencraft:oak_planks",
				"kaizencraft:stick,,"
			]
		}
	]
	KZ_PathUtil.write_text(path, JSON.stringify(recipes, "	"))

func _ensure_block_file(path: String, data: Dictionary) -> void:
	if KZ_PathUtil.file_exists(path):
		return
	KZ_PathUtil.write_text(path, JSON.stringify(data, "\t"))

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
