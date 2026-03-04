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
