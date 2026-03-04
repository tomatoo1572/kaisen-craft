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
	var scene: Node = get_tree().current_scene
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

	var spawn_pos: Vector3 = server.get_spawn_position()
	player.global_position = spawn_pos
	player.apply_settings(config_manager.gameplay)

	world_manager.set_player(player)

	if not server.block_broken.is_connected(Callable(self, "_on_block_broken")):
		server.block_broken.connect(Callable(self, "_on_block_broken"))

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED as Input.MouseMode)

func _on_block_broken(world_block: Vector3i, runtime_id: int) -> void:
	var def: KZ_BlockRegistry.BlockDef = block_registry.get_def_by_runtime(runtime_id)
	var drop := KZ_DroppedItem.new()

	var scene: Node = get_tree().current_scene
	if scene == null:
		scene = get_tree().root
	scene.add_child(drop)

	drop.global_position = Vector3(float(world_block.x) + 0.5, float(world_block.y) + 0.6, float(world_block.z) + 0.5)
	drop.setup(def.tint)

func _parse_cmdline_args() -> void:
	var args := OS.get_cmdline_args()
	for a in args:
		if a.begins_with("--instance="):
			instance_name = a.get_slice("=", 1).strip_edges()
		elif a.begins_with("--world="):
			world_name = a.get_slice("=", 1).strip_edges()

func _ensure_input_map() -> void:
	_add_key_action_if_missing("move_forward", [KEY_W])
	_add_key_action_if_missing("move_back", [KEY_S])
	_add_key_action_if_missing("move_left", [KEY_A])
	_add_key_action_if_missing("move_right", [KEY_D])
	_add_key_action_if_missing("jump", [KEY_SPACE])
	_add_key_action_if_missing("ui_cancel", [KEY_ESCAPE])

	# ✅ Use enum member name that exists on your build
	_add_mouse_action_if_missing("attack", MouseButton.MOUSE_BUTTON_LEFT)

func _add_key_action_if_missing(action: StringName, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.keycode = k
		InputMap.action_add_event(action, ev)

func _add_mouse_action_if_missing(action: StringName, button: MouseButton) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
