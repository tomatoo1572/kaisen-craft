extends Node
class_name KZ_Game

var instance_name: String = "default"
var world_name: String = "world1"

var instance_root: String
var world_root: String

var config_manager: KZ_ConfigManager
var block_registry: KZ_BlockRegistry
var server: KZ_LocalWorldServer

var world_manager: KZ_WorldManager
var player: KZ_Player

func _enter_tree() -> void:
	_parse_cmdline_args()

	var im := KZ_InstanceManager.new()
	im.bootstrap_instance(instance_name)

	instance_root = im.get_instance_root(instance_name)
	world_root = im.ensure_world(instance_name, world_name)

	config_manager = KZ_ConfigManager.new()
	config_manager.ensure_defaults(instance_root)
	config_manager.load_all(instance_root)

	block_registry = KZ_BlockRegistry.new()
	block_registry.load_from_folder(KZ_PathUtil.join(instance_root, "config/blocks"))

	server = KZ_LocalWorldServer.new()
	add_child(server)
	server.setup(world_root, config_manager.worldgen, block_registry)

func _ready() -> void:
	_ensure_input_map()
	call_deferred("_spawn_client")

func _spawn_client() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		scene = get_tree().root
	if scene == null:
		push_error("No scene to spawn into.")
		return

	world_manager = KZ_WorldManager.new()
	scene.add_child(world_manager)
	world_manager.setup(server, config_manager.worldgen)

	player = KZ_Player.new()
	scene.add_child(player)

	var spawn_pos := server.get_spawn_position()
	player.global_position = spawn_pos
	player.apply_settings(config_manager.gameplay)

	world_manager.set_player(player)

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _parse_cmdline_args() -> void:
	var args := OS.get_cmdline_args()
	for a in args:
		if a.begins_with("--instance="):
			instance_name = a.get_slice("=", 1).strip_edges()
		elif a.begins_with("--world="):
			world_name = a.get_slice("=", 1).strip_edges()

func _ensure_input_map() -> void:
	_add_action_if_missing("move_forward", [KEY_W])
	_add_action_if_missing("move_back", [KEY_S])
	_add_action_if_missing("move_left", [KEY_A])
	_add_action_if_missing("move_right", [KEY_D])
	_add_action_if_missing("jump", [KEY_SPACE])
	_add_action_if_missing("ui_cancel", [KEY_ESCAPE])

func _add_action_if_missing(action: StringName, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.keycode = k
		InputMap.action_add_event(action, ev)
