extends RefCounted
class_name KZ_InstanceManager

func get_instances_root() -> String:
	return "user://instances"

func get_instance_root(instance_name: String) -> String:
	return KZ_PathUtil.join(get_instances_root(), instance_name)

func bootstrap_instance(instance_name: String) -> void:
	var root := get_instance_root(instance_name)

	var dirs := [
		"versions",
		"worlds",
		"logs",
		"mods",
		"config",
		"config/blocks",
		"config/items",
		"config/recipes",
		"config/loot_tables",
		"config/models",
		"resourcepacks",
		"screenshots",
		"cache",
	]
	for d in dirs:
		KZ_PathUtil.ensure_dir(KZ_PathUtil.join(root, d))

func ensure_world(instance_name: String, world_name: String) -> String:
	var instance_root := get_instance_root(instance_name)
	var worlds_root := KZ_PathUtil.join(instance_root, "worlds")
	var world_root := KZ_PathUtil.join(worlds_root, world_name)

	KZ_PathUtil.ensure_dir(world_root)
	KZ_PathUtil.ensure_dir(KZ_PathUtil.join(world_root, "playerdata"))
	KZ_PathUtil.ensure_dir(KZ_PathUtil.join(world_root, "chunks"))

	# level.dat created by server/setup if missing
	return world_root


func create_world(instance_name: String, world_name: String, seed_value: int = 1337) -> String:
	var world_root := ensure_world(instance_name, world_name)
	KZ_PathUtil.write_text(KZ_PathUtil.join(world_root, "seed.dat"), str(seed_value) + "\n")
	var level_path := KZ_PathUtil.join(world_root, "level.dat")
	var now_utc: String = Time.get_datetime_string_from_system(true)
	var meta: Dictionary = {
		"name": world_name,
		"created_utc": now_utc,
		"last_played_utc": now_utc,
		"seed": seed_value,
		"format": "kaizencraft_level_v1_json"
	}
	KZ_PathUtil.write_text(level_path, JSON.stringify(meta, "\t"))
	return world_root

func list_worlds(instance_name: String) -> Array[Dictionary]:
	var worlds_root := KZ_PathUtil.join(get_instance_root(instance_name), "worlds")
	var dirs: Array[String] = KZ_PathUtil.list_dirs(worlds_root)
	dirs.sort()
	var out: Array[Dictionary] = []
	for dir_path in dirs:
		var world_root: String = str(dir_path)
		var world_name: String = world_root.get_file()
		var info: Dictionary = {
			"name": world_name,
			"path": world_root,
			"seed": 1337,
			"created_utc": "",
			"last_played_utc": ""
		}
		var level_path: String = KZ_PathUtil.join(world_root, "level.dat")
		if KZ_PathUtil.file_exists(level_path):
			var txt: String = KZ_PathUtil.read_text(level_path)
			var parsed_v: Variant = JSON.parse_string(txt)
			if typeof(parsed_v) == TYPE_DICTIONARY:
				var parsed: Dictionary = parsed_v as Dictionary
				info["name"] = str(parsed.get("name", world_name))
				info["seed"] = int(parsed.get("seed", 1337))
				info["created_utc"] = str(parsed.get("created_utc", ""))
				info["last_played_utc"] = str(parsed.get("last_played_utc", ""))
		out.append(info)
	return out
