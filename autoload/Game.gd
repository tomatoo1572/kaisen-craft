extends Node
class_name KZ_Game

const WORLD_MANAGER_SCRIPT_PATH := "res://world/WorldManager.gd"
const LOCAL_WORLD_SERVER_SCRIPT_PATH := "res://world/LocalWorldServer.gd"
const CHAT_BUS_SCRIPT_PATH := "res://chat/ChatBus.gd"
const CONTROLS_FILE_NAME := "controls.json"
const PLAYERDATA_FILE_NAME := "local_player.json"
const WORLDSTATE_FILE_NAME := "world_state.json"
const RECIPES_FILE_NAME := "recipes.json"
const DEFAULT_PROXIMITY_CHAT_RADIUS_BLOCKS: float = 30.0

const DEFAULT_CONTROLS := {
	"move_forward": {"type": "key", "code": KEY_W},
	"move_back": {"type": "key", "code": KEY_S},
	"move_left": {"type": "key", "code": KEY_A},
	"move_right": {"type": "key", "code": KEY_D},
	"jump": {"type": "key", "code": KEY_SPACE},
	"sneak": {"type": "key", "code": KEY_SHIFT},
	"inventory": {"type": "key", "code": KEY_E},
	"chat": {"type": "key", "code": KEY_T},
	"toggle_walk_mode": {"type": "key", "code": KEY_R},
	"toggle_camera": {"type": "key", "code": KEY_F5},
	"drop_selected": {"type": "key", "code": KEY_Q},
	"attack": {"type": "mouse", "button": MouseButton.MOUSE_BUTTON_LEFT},
	"use": {"type": "mouse", "button": MouseButton.MOUSE_BUTTON_RIGHT},
	"ui_cancel": {"type": "key", "code": KEY_ESCAPE}
}

var instance_name: String = "default"
var world_name: String = "world1"

var instance_root: String = ""
var world_root: String = ""

var config_manager: KZ_ConfigManager
var block_registry: KZ_BlockRegistry
var server: Node
var chat_bus: KZ_ChatBus

var world_manager: Node
var player: KZ_Player
var hud: KZ_Hud

var is_session_active: bool = false

var day_duration_sec: float = 14.0 * 60.0
var night_duration_sec: float = 10.0 * 60.0
var _time_of_day_sec: float = 0.0
var _day_count: int = 0
var time_speed_multiplier: float = 1.0
var max_time_speed_multiplier: float = 240.0
var animals_root: Node3D

var world_environment: WorldEnvironment
var environment_resource: Environment
var sky_material_resource: ProceduralSkyMaterial
var sun_light: DirectionalLight3D
var moon_light: DirectionalLight3D
var sky_anchor: Node3D
var sun_sprite: Sprite3D
var moon_sprite: Sprite3D
var moon_phase_textures: Array[Texture2D] = []
var cloud_root: Node3D
var cloud_sprites: Array = []
var cloud_base_positions: Array[Vector3] = []
var cloud_scroll_speed: float = 2.4
var _sky_color_current: Color = Color(0.58, 0.80, 1.0)
var _ambient_color_current: Color = Color(0.90, 0.92, 0.98)
var _terrain_tint_current: Color = Color(1.0, 1.0, 1.0)
var _sun_dir_current: Vector3 = Vector3(0.25, 1.0, -0.28).normalized()
var _moon_dir_current: Vector3 = Vector3(-0.25, 1.0, 0.24).normalized()
var _sun_strength_current: float = 1.0
var _moon_strength_current: float = 0.0
var keep_inventory_enabled: bool = false
var game_mode: String = "survival"
var _recipe_cache: Array[Dictionary] = []

func _enter_tree() -> void:
	_parse_cmdline_args()
	_bootstrap_instance_state(instance_name)
	_ensure_input_actions_exist()
	_load_controls()

func _ready() -> void:
	pass

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_session_active:
		_save_session_state()

func _process(dt: float) -> void:
	if not is_session_active or world_manager == null:
		return
	_update_day_night(dt * time_speed_multiplier)

func start_singleplayer(p_instance_name: String = "default", p_world_name: String = "world1") -> bool:
	if is_session_active:
		return false

	instance_name = p_instance_name.strip_edges()
	world_name = p_world_name.strip_edges()
	if instance_name == "":
		instance_name = "default"
	if world_name == "":
		world_name = "world1"

	_bootstrap_instance_state(instance_name)
	_load_controls()
	_recipe_cache.clear()
	world_root = KZ_InstanceManager.new().ensure_world(instance_name, world_name)

	block_registry = KZ_BlockRegistry.new()
	block_registry.load_from_folders([
		KZ_PathUtil.join(instance_root, "config/blocks"),
		KZ_PathUtil.join(instance_root, "config/items")
	])

	var local_server_script: Script = load(LOCAL_WORLD_SERVER_SCRIPT_PATH) as Script
	if local_server_script == null:
		push_error("Failed to load LocalWorldServer script: %s" % LOCAL_WORLD_SERVER_SCRIPT_PATH)
		return false
	server = local_server_script.new()
	if server == null:
		push_error("Failed to instantiate LocalWorldServer from: %s" % LOCAL_WORLD_SERVER_SCRIPT_PATH)
		return false
	add_child(server)
	server.setup(world_root, config_manager.worldgen, block_registry)

	var scene: Node = get_tree().current_scene
	if scene == null:
		scene = get_tree().root
	if scene == null:
		push_error("No scene to spawn into.")
		return false

	_setup_world_visuals(scene)
	_apply_cycle_settings()
	_load_world_state()

	var chat_script: Script = load(CHAT_BUS_SCRIPT_PATH) as Script
	if chat_script == null:
		push_error("Failed to load ChatBus script: %s" % CHAT_BUS_SCRIPT_PATH)
		return false
	chat_bus = chat_script.new()
	if chat_bus == null:
		push_error("Failed to instantiate ChatBus.")
		return false
	add_child(chat_bus)
	chat_bus.setup(world_name, DEFAULT_PROXIMITY_CHAT_RADIUS_BLOCKS)

	var world_manager_script: Script = load(WORLD_MANAGER_SCRIPT_PATH) as Script
	if world_manager_script == null:
		push_error("Failed to load WorldManager script: %s" % WORLD_MANAGER_SCRIPT_PATH)
		return false
	world_manager = world_manager_script.new()
	if world_manager == null:
		push_error("Failed to instantiate WorldManager from: %s" % WORLD_MANAGER_SCRIPT_PATH)
		return false
	scene.add_child(world_manager)
	world_manager.setup(server, config_manager.worldgen)

	player = KZ_Player.new()
	scene.add_child(player)
	player.apply_settings(config_manager.gameplay)
	world_manager.set_player(player)

	var spawn_pos: Vector3 = server.get_spawn_position()
	player.global_position = spawn_pos
	_load_player_state(spawn_pos)

	hud = KZ_Hud.new()
	scene.add_child(hud)
	hud.setup(player, block_registry)

	_setup_animals(scene)
	_spawn_initial_sheep(6)

	if not server.block_broken.is_connected(Callable(self, "_on_block_broken")):
		server.block_broken.connect(Callable(self, "_on_block_broken"))

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED as Input.MouseMode)
	is_session_active = true
	_update_day_night(0.0)
	if chat_bus != null:
		chat_bus.post_system("Entered world %s." % world_name)
	return true

func list_singleplayer_worlds(p_instance_name: String = "default") -> Array[Dictionary]:
	var target: String = p_instance_name.strip_edges()
	if target == "":
		target = "default"
	var im := KZ_InstanceManager.new()
	im.bootstrap_instance(target)
	return im.list_worlds(target)

func create_singleplayer_world(p_instance_name: String, p_world_name: String, p_seed_text: String) -> Dictionary:
	var target_instance: String = p_instance_name.strip_edges()
	if target_instance == "":
		target_instance = "default"
	var target_world: String = p_world_name.strip_edges()
	if target_world == "":
		return {"ok": false, "error": "World name cannot be empty."}
	var seed_text: String = p_seed_text.strip_edges()
	var seed_value: int = 0
	if seed_text == "":
		seed_value = int(Time.get_unix_time_from_system()) ^ randi()
	elif seed_text.is_valid_int():
		seed_value = int(seed_text)
	else:
		seed_value = abs(seed_text.hash())

	var worlds: Array[Dictionary] = list_singleplayer_worlds(target_instance)
	for entry_v in worlds:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_v as Dictionary
		if str(entry.get("name", "")).to_lower() == target_world.to_lower():
			return {"ok": false, "error": "A world with that name already exists."}

	var im := KZ_InstanceManager.new()
	im.bootstrap_instance(target_instance)
	var created_path: String = im.create_world(target_instance, target_world, seed_value)
	return {"ok": true, "world_name": target_world, "seed": seed_value, "path": created_path}

func delete_singleplayer_world(p_instance_name: String, p_world_name: String) -> Dictionary:
	var target_instance: String = p_instance_name.strip_edges()
	if target_instance == "":
		target_instance = "default"
	var target_world: String = p_world_name.strip_edges()
	if target_world == "":
		return {"ok": false, "error": "World name cannot be empty."}
	var world_path: String = KZ_PathUtil.join(KZ_PathUtil.join(KZ_InstanceManager.new().get_instance_root(target_instance), "worlds"), target_world)
	if not DirAccess.dir_exists_absolute(world_path):
		return {"ok": false, "error": "World not found."}
	if not _delete_dir_recursive(world_path):
		return {"ok": false, "error": "Could not delete world."}
	return {"ok": true}

func _delete_dir_recursive(path: String) -> bool:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return false
	dir.list_dir_begin()
	while true:
		var entry_name: String = dir.get_next()
		if entry_name == "":
			break
		if entry_name == "." or entry_name == "..":
			continue
		var child: String = path.path_join(entry_name)
		if dir.current_is_dir():
			if not _delete_dir_recursive(child):
				dir.list_dir_end()
				return false
		else:
			if DirAccess.remove_absolute(child) != OK:
				dir.list_dir_end()
				return false
	dir.list_dir_end()
	return DirAccess.remove_absolute(path) == OK

func get_registry_entries() -> Array[Dictionary]:
	if block_registry == null:
		return []
	return block_registry.get_registered_entries()

func get_render_distance() -> int:
	if config_manager != null and config_manager.worldgen.has("worldgen") and config_manager.worldgen["worldgen"] is Dictionary:
		var wg: Dictionary = config_manager.worldgen["worldgen"] as Dictionary
		return int(wg.get("view_distance_chunks", 6))
	return 6

func set_render_distance(chunks: int) -> void:
	var clamped: int = clampi(chunks, 2, 16)
	if config_manager != null:
		var wg: Dictionary = {}
		if config_manager.worldgen.has("worldgen") and config_manager.worldgen["worldgen"] is Dictionary:
			wg = config_manager.worldgen["worldgen"] as Dictionary
		wg["view_distance_chunks"] = clamped
		config_manager.worldgen["worldgen"] = wg
		_save_worldgen_config()
	if world_manager != null and world_manager.has_method("set_view_distance"):
		world_manager.call("set_view_distance", clamped)
	if server != null:
		server.view_distance_chunks = clamped


func get_fov() -> float:
	if player != null and player.has_method("get_camera_fov"):
		return float(player.call("get_camera_fov"))
	if config_manager != null and config_manager.gameplay.has("gameplay") and config_manager.gameplay["gameplay"] is Dictionary:
		var gp: Dictionary = config_manager.gameplay["gameplay"] as Dictionary
		return float(gp.get("fov", 75.0))
	return 75.0

func get_max_fps() -> int:
	if Engine.max_fps > 0:
		return int(Engine.max_fps)
	if config_manager != null and config_manager.gameplay.has("gameplay") and config_manager.gameplay["gameplay"] is Dictionary:
		var gp_fps: Dictionary = config_manager.gameplay["gameplay"] as Dictionary
		return int(gp_fps.get("max_fps", 0))
	return 0

func set_max_fps(value: float) -> void:
	var fps_cap: int = clampi(int(round(value)), 0, 1000)
	Engine.max_fps = fps_cap
	if config_manager != null:
		var gp_fps2: Dictionary = {}
		if config_manager.gameplay.has("gameplay") and config_manager.gameplay["gameplay"] is Dictionary:
			gp_fps2 = config_manager.gameplay["gameplay"] as Dictionary
		gp_fps2["max_fps"] = fps_cap
		config_manager.gameplay["gameplay"] = gp_fps2
		_save_gameplay_config()

func set_fov(value: float) -> void:
	var clamped: float = clampf(value, 20.0, 120.0)
	if config_manager != null:
		var gp: Dictionary = {}
		if config_manager.gameplay.has("gameplay") and config_manager.gameplay["gameplay"] is Dictionary:
			gp = config_manager.gameplay["gameplay"] as Dictionary
		gp["fov"] = clamped
		config_manager.gameplay["gameplay"] = gp
		_save_gameplay_config()
	if player != null and player.has_method("set_camera_fov"):
		player.call("set_camera_fov", clamped)

func _save_gameplay_config() -> void:
	if config_manager == null:
		return
	var path: String = KZ_PathUtil.join(instance_root, "config/gameplay.toml")
	KZ_PathUtil.write_text(path, KZ_TomlLite.new().stringify(config_manager.gameplay))

func _recipes_path() -> String:
	return KZ_PathUtil.join(instance_root, "config/recipes/%s" % RECIPES_FILE_NAME)

func _get_recipe_defs() -> Array[Dictionary]:
	if not _recipe_cache.is_empty():
		return _recipe_cache
	var path: String = _recipes_path()
	if KZ_PathUtil.file_exists(path):
		var txt: String = KZ_PathUtil.read_text(path)
		var parsed_v: Variant = JSON.parse_string(txt)
		if typeof(parsed_v) == TYPE_ARRAY:
			var parsed: Array = parsed_v as Array
			for entry_v in parsed:
				if typeof(entry_v) == TYPE_DICTIONARY:
					_recipe_cache.append(entry_v as Dictionary)
	return _recipe_cache

func _save_worldgen_config() -> void:
	if config_manager == null:
		return
	var path: String = KZ_PathUtil.join(instance_root, "config/worldgen.toml")
	KZ_PathUtil.write_text(path, KZ_TomlLite.new().stringify(config_manager.worldgen))

func _bootstrap_instance_state(target_instance_name: String) -> void:
	var im := KZ_InstanceManager.new()
	im.bootstrap_instance(target_instance_name)
	instance_root = im.get_instance_root(target_instance_name)
	config_manager = KZ_ConfigManager.new()
	config_manager.ensure_defaults(instance_root)
	config_manager.load_all(instance_root)

func _controls_path() -> String:
	return KZ_PathUtil.join(instance_root, "config/%s" % CONTROLS_FILE_NAME)

func _playerdata_path() -> String:
	return KZ_PathUtil.join(world_root, "playerdata/%s" % PLAYERDATA_FILE_NAME)

func _worldstate_path() -> String:
	return KZ_PathUtil.join(world_root, WORLDSTATE_FILE_NAME)

func _ensure_input_actions_exist() -> void:
	for action_v in DEFAULT_CONTROLS.keys():
		var action: StringName = StringName(str(action_v))
		if not InputMap.has_action(action):
			InputMap.add_action(action)

func _load_controls() -> void:
	var path: String = _controls_path()
	var data: Dictionary = {}
	if KZ_PathUtil.file_exists(path):
		var txt: String = KZ_PathUtil.read_text(path)
		var parsed_v: Variant = JSON.parse_string(txt)
		if typeof(parsed_v) == TYPE_DICTIONARY:
			data = parsed_v as Dictionary
	if data.is_empty():
		data = DEFAULT_CONTROLS.duplicate(true) as Dictionary
		_save_controls(data)
	_apply_controls(data)

func _save_controls(data: Dictionary) -> void:
	KZ_PathUtil.write_text(_controls_path(), JSON.stringify(data, "\t"))

func _apply_controls(data: Dictionary) -> void:
	_ensure_input_actions_exist()
	for action_v in DEFAULT_CONTROLS.keys():
		var action: String = str(action_v)
		InputMap.action_erase_events(StringName(action))
		var bind_v: Variant = data.get(action, DEFAULT_CONTROLS[action])
		if typeof(bind_v) != TYPE_DICTIONARY:
			bind_v = DEFAULT_CONTROLS[action]
		var bind: Dictionary = bind_v as Dictionary
		var ev: InputEvent = _event_from_dict(bind)
		if ev != null:
			InputMap.action_add_event(StringName(action), ev)

func get_bindable_actions() -> Array[Dictionary]:
	return [
		{"action": "move_forward", "label": "Move Forward"},
		{"action": "move_back", "label": "Move Back"},
		{"action": "move_left", "label": "Move Left"},
		{"action": "move_right", "label": "Move Right"},
		{"action": "jump", "label": "Jump"},
		{"action": "sneak", "label": "Sneak / Descend"},
		{"action": "inventory", "label": "Inventory"},
		{"action": "chat", "label": "Chat"},
		{"action": "toggle_walk_mode", "label": "Cycle Walk Mode"},
		{"action": "toggle_camera", "label": "Toggle Camera"},
		{"action": "drop_selected", "label": "Drop Selected Item"},
		{"action": "attack", "label": "Attack / Break"},
		{"action": "use", "label": "Use / Place"}
	]

func get_action_binding_text(action: String) -> String:
	if not InputMap.has_action(StringName(action)):
		return "Unbound"
	var events: Array[InputEvent] = InputMap.action_get_events(StringName(action))
	if events.is_empty():
		return "Unbound"
	var ev: InputEvent = events[0]
	if ev == null:
		return "Unbound"
	return ev.as_text()

func rebind_action(action: String, event: InputEvent) -> bool:
	if action == "" or event == null:
		return false
	var serialized: Dictionary = _event_to_dict(event)
	if serialized.is_empty():
		return false
	var path: String = _controls_path()
	var data: Dictionary = {}
	if KZ_PathUtil.file_exists(path):
		var txt: String = KZ_PathUtil.read_text(path)
		var parsed_v: Variant = JSON.parse_string(txt)
		if typeof(parsed_v) == TYPE_DICTIONARY:
			data = parsed_v as Dictionary
	data[action] = serialized
	_save_controls(data)
	_apply_controls(data)
	return true

func _event_to_dict(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		return {"type": "key", "code": int(key_event.keycode)}
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		return {"type": "mouse", "button": int(mouse_event.button_index)}
	return {}

func _event_from_dict(data: Dictionary) -> InputEvent:
	var t: String = str(data.get("type", ""))
	if t == "key":
		var ev := InputEventKey.new()
		ev.keycode = int(data.get("code", KEY_NONE)) as Key
		return ev
	if t == "mouse":
		var mb := InputEventMouseButton.new()
		mb.button_index = int(data.get("button", MouseButton.MOUSE_BUTTON_LEFT)) as MouseButton
		return mb
	return null

func send_chat_text(text: String) -> void:
	if not is_session_active or player == null or chat_bus == null:
		return
	var trimmed: String = text.strip_edges()
	if trimmed == "":
		return
	if trimmed.begins_with("/"):
		_run_command(trimmed)
		return
	chat_bus.post_text("local", "You", player.global_position, trimmed, DEFAULT_PROXIMITY_CHAT_RADIUS_BLOCKS)

func _run_command(raw: String) -> void:
	var body: String = raw.substr(1).strip_edges()
	if body == "":
		return
	var parts: PackedStringArray = body.split(" ", false)
	if parts.is_empty():
		return
	var cmd: String = parts[0].to_lower()

	if cmd == "help":
		_show_help()
		return
	if cmd == "damage":
		if player == null:
			return
		if parts.size() < 2:
			_post_system("Usage: /damage <amount>")
			return
		var amt_str: String = parts[1].strip_edges()
		if not amt_str.is_valid_float() and not amt_str.is_valid_int():
			_post_system("Damage amount must be a number.")
			return
		var amount: float = float(amt_str)
		player.damage(amount)
		_post_system("Took %.1f damage. Health: %d / %d" % [amount, int(round(player.health)), int(round(player.max_health))])
		return
	if cmd == "time":
		if parts.size() >= 3 and parts[1].to_lower() == "speed":
			var speed_text: String = parts[2].strip_edges()
			if not speed_text.is_valid_float() and not speed_text.is_valid_int():
				_post_system("Usage: /time speed <multiplier>")
				return
			set_time_speed_multiplier(float(speed_text))
			_post_system("Time speed set to %.2fx." % time_speed_multiplier)
			return
		if parts.size() >= 3 and parts[1].to_lower() == "set":
			var label: String = parts[2].to_lower()
			if set_time_preset(label):
				_post_system("Set time to %s." % label)
			else:
				_post_system("Usage: /time set morning|day|noon|afternoon|evening|night|midnight OR /time speed <multiplier>")
			return
		_post_system("Usage: /time set morning|day|noon|afternoon|evening|night|midnight")
		return
	if cmd == "keepinventory":
		if parts.size() < 2:
			_post_system("Usage: /keepinventory true|false")
			return
		var val: String = parts[1].to_lower()
		if val != "true" and val != "false":
			_post_system("Usage: /keepinventory true|false")
			return
		keep_inventory_enabled = (val == "true")
		_post_system("keepInventory set to %s." % ("true" if keep_inventory_enabled else "false"))
		return
	if cmd == "gamerule":
		if parts.size() >= 3 and parts[1].to_lower() == "keepinventory":
			var value: String = parts[2].to_lower()
			if value != "true" and value != "false":
				_post_system("Usage: /gamerule keepInventory true|false")
				return
			keep_inventory_enabled = (value == "true")
			_post_system("keepInventory set to %s." % ("true" if keep_inventory_enabled else "false"))
			return
		_post_system("Usage: /gamerule keepInventory true|false")
		return
	if cmd == "give":
		if player == null or block_registry == null:
			return
		if parts.size() < 2:
			_post_system("Usage: /give <id|numeric_id> [count]")
			return
		var token: String = parts[1].strip_edges()
		var sid: String = block_registry.resolve_string_id(token)
		var rid: int = block_registry.get_runtime_id(sid)
		if rid == 0:
			_post_system("Unknown item: %s" % token)
			return
		var count: int = 1
		if parts.size() >= 3:
			var count_str: String = parts[2].strip_edges()
			if not count_str.is_valid_int():
				_post_system("Count must be a whole number.")
				return
			count = maxi(1, int(count_str))
		give_item_to_player(sid, count)
		var def_give: KZ_BlockRegistry.BlockDef = block_registry.get_def_by_runtime(rid)
		_post_system("Gave %d x %s (#%d)." % [count, def_give.name if def_give != null else sid, rid])
		return
	if cmd == "clear":
		if player == null:
			return
		player.inventory.clear_all()
		player.cursor_item_id = ""
		player.cursor_count = 0
		player.emit_signal("inventory_changed")
		_post_system("Inventory cleared.")
		return
	if cmd == "body":
		if player == null:
			return
		if parts.size() < 2:
			_post_system("Usage: /body sex male|female, /body build base|slim|shredded|fat, /body size <height> <width> <weight>")
			return
		var body_sub: String = parts[1].to_lower()
		if body_sub == "sex":
			if parts.size() < 3:
				_post_system("Usage: /body sex male|female")
				return
			var sex_value: String = parts[2].to_lower()
			if sex_value != "male" and sex_value != "female":
				_post_system("Usage: /body sex male|female")
				return
			player.set_body_sex(sex_value)
			_post_system("Body sex set to %s." % sex_value)
			return
		if body_sub == "build":
			if parts.size() < 3:
				_post_system("Usage: /body build base|slim|shredded|fat")
				return
			var build_value: String = parts[2].to_lower()
			if build_value != "base" and build_value != "slim" and build_value != "shredded" and build_value != "fat":
				_post_system("Usage: /body build base|slim|shredded|fat")
				return
			player.set_body_build(build_value)
			_post_system("Body build set to %s." % build_value)
			return
		if body_sub == "size":
			if parts.size() < 5:
				_post_system("Usage: /body size <height_scale> <width_scale> <weight>")
				return
			var h_text: String = parts[2]
			var w_text: String = parts[3]
			var wt_text: String = parts[4]
			if (not h_text.is_valid_float() and not h_text.is_valid_int()) or (not w_text.is_valid_float() and not w_text.is_valid_int()) or (not wt_text.is_valid_float() and not wt_text.is_valid_int()):
				_post_system("Usage: /body size <height_scale> <width_scale> <weight>")
				return
			player.set_body_size(float(h_text), float(w_text), float(wt_text))
			_post_system("Body size updated.")
			return
		_post_system("Usage: /body sex male|female, /body build base|slim|shredded|fat, /body size <height> <width> <weight>")
		return
	if cmd == "gamemode" or cmd == "gm":
		if parts.size() < 2:
			_post_system("Usage: /gamemode survival|creative")
			return
		var mode_token: String = parts[1].to_lower()
		if mode_token == "s" or mode_token == "0":
			mode_token = "survival"
		elif mode_token == "c" or mode_token == "1":
			mode_token = "creative"
		if mode_token != "survival" and mode_token != "creative":
			_post_system("Usage: /gamemode survival|creative")
			return
		set_game_mode(mode_token)
		_post_system("Game mode set to %s." % mode_token)
		return

	_post_system("Unknown command: /%s" % cmd)

func get_time_display_text() -> String:
	var info: Dictionary = get_time_display_info()
	return "%s %s" % [str(info.get("clock_text", "00:00")), str(info.get("label", "Day"))]

func _cycle_to_clock_hour(time_sec: float) -> float:
	var total_cycle: float = day_duration_sec + night_duration_sec
	if total_cycle <= 0.0:
		return 0.0
	return fmod((time_sec / total_cycle) * 24.0, 24.0)

func _clock_hour_to_cycle_seconds(hour_value: float) -> float:
	var total_cycle: float = day_duration_sec + night_duration_sec
	if total_cycle <= 0.0:
		return 0.0
	var hour_norm: float = fmod(hour_value, 24.0)
	if hour_norm < 0.0:
		hour_norm += 24.0
	return (hour_norm / 24.0) * total_cycle

func get_time_display_info() -> Dictionary:
	var total_cycle: float = day_duration_sec + night_duration_sec
	if total_cycle <= 0.0:
		return {"clock_text": "00:00", "label": "Day", "hour": 0, "minute": 0}
	var time_sec: float = fmod(_time_of_day_sec, total_cycle)
	if time_sec < 0.0:
		time_sec += total_cycle
	var clock_hour_f: float = _cycle_to_clock_hour(time_sec)
	var hour_int: int = int(floor(clock_hour_f))
	var minute_int: int = int(floor((clock_hour_f - float(hour_int)) * 60.0))
	if minute_int >= 60:
		minute_int = 0
		hour_int = (hour_int + 1) % 24
	var label: String = "Night"
	if clock_hour_f >= 5.0 and clock_hour_f < 8.0:
		label = "Morning"
	elif clock_hour_f >= 8.0 and clock_hour_f < 12.0:
		label = "Day"
	elif clock_hour_f >= 12.0 and clock_hour_f < 17.0:
		label = "Afternoon"
	elif clock_hour_f >= 17.0 and clock_hour_f < 19.0:
		label = "Evening"
	elif clock_hour_f >= 19.0 or clock_hour_f < 5.0:
		label = "Night"
	if hour_int == 0:
		label = "Midnight"
	elif hour_int == 12:
		label = "Noon"
	return {
		"clock_text": "%02d:%02d" % [hour_int, minute_int],
		"label": label,
		"hour": hour_int,
		"minute": minute_int,
		"hour_f": clock_hour_f,
		"is_day": clock_hour_f >= 7.0 and clock_hour_f < 19.0
	}

func set_time_speed_multiplier(multiplier: float) -> void:
	time_speed_multiplier = clampf(multiplier, 0.0, max_time_speed_multiplier)

func get_player_attack_damage() -> float:

	if player == null or block_registry == null:
		return 0.5
	var selected_id: String = player.inventory.get_selected_id()
	if selected_id == "":
		return 0.5
	return block_registry.get_attack_damage_for_item(selected_id, 0.5)

func try_attack_entity_from_player(attacker: Node3D) -> bool:
	if attacker == null:
		return false
	var scene: Node = get_tree().current_scene
	if scene == null:
		scene = get_tree().root
	if scene == null:
		return false
	var cam: Camera3D = null
	if attacker.has_method("get"):
		var cam_v: Variant = attacker.get("cam")
		if cam_v is Camera3D:
			cam = cam_v as Camera3D
	var origin: Vector3 = cam.global_position if cam != null else attacker.global_position + Vector3(0.0, 1.6, 0.0)
	var dir: Vector3 = -attacker.global_transform.basis.z
	if cam != null:
		dir = -cam.global_transform.basis.z
	var best: Node = null
	var best_dist: float = 99999.0
	for node in scene.get_tree().get_nodes_in_group("kz_damageable"):
		if not (node is Node3D):
			continue
		var n3: Node3D = node as Node3D
		var to_target: Vector3 = n3.global_position - origin
		var along: float = to_target.dot(dir)
		if along < 0.0 or along > 4.5:
			continue
		var closest: Vector3 = origin + dir * along
		var radius: float = 0.85
		if n3.has_method("get_target_radius"):
			radius = float(n3.call("get_target_radius"))
		if n3.global_position.distance_to(closest) <= radius and along < best_dist:
			best = n3
			best_dist = along
	if best != null and best.has_method("take_damage"):
		best.call("take_damage", get_player_attack_damage(), attacker)
		return true
	return false

func _setup_animals(scene: Node) -> void:
	if animals_root != null:
		animals_root.queue_free()
	animals_root = Node3D.new()
	animals_root.name = "Animals"
	scene.add_child(animals_root)

func _spawn_initial_sheep(count: int) -> void:
	if animals_root == null or server == null:
		return
	var sheep_script: Script = load("res://world/Sheep.gd") as Script
	if sheep_script == null:
		return
	var base: Vector3 = server.get_spawn_position()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(Time.get_ticks_usec())
	var spawned: int = 0
	var attempts: int = 0
	while spawned < count and attempts < count * 12:
		attempts += 1
		var wx: int = int(round(base.x)) + rng.randi_range(-24, 24)
		var wz: int = int(round(base.z)) + rng.randi_range(-24, 24)
		var surface_y: int = server.get_surface_y(wx, wz)
		var ground_id: int = server.get_block_at_world(wx, surface_y - 1, wz)
		var ground_sid: String = block_registry.get_string_id(ground_id)
		if ground_sid != "kaizencraft:grass":
			continue
		var sheep: Node = sheep_script.new()
		animals_root.add_child(sheep)
		if sheep.has_method("setup_from_game"):
			sheep.call("setup_from_game")
		(sheep as Node3D).global_position = Vector3(float(wx) + 0.5, float(surface_y) + 0.05, float(wz) + 0.5)
		spawned += 1

func _show_help() -> void:
	_post_system("Commands: /help, /damage <amount>, /give <id|numeric_id> [count], /clear, /time set morning|day|noon|afternoon|evening|night|midnight, /time speed <multiplier>, /keepinventory true|false, /gamerule keepInventory true|false, /gamemode survival|creative, /body sex male|female, /body build base|slim|shredded|fat, /body size <height> <width> <weight>")

func _post_system(text: String) -> void:
	if chat_bus != null:
		chat_bus.post_system(text)

func set_time_to_daylight() -> void:
	_time_of_day_sec = _clock_hour_to_cycle_seconds(9.0)
	_update_day_night(0.0)

func set_time_preset(label: String) -> bool:
	match label:
		"morning":
			_time_of_day_sec = _clock_hour_to_cycle_seconds(5.0)
		"day":
			_time_of_day_sec = _clock_hour_to_cycle_seconds(9.0)
		"noon":
			_time_of_day_sec = _clock_hour_to_cycle_seconds(12.0)
		"afternoon":
			_time_of_day_sec = _clock_hour_to_cycle_seconds(15.0)
		"evening":
			_time_of_day_sec = _clock_hour_to_cycle_seconds(17.0)
		"night":
			_time_of_day_sec = _clock_hour_to_cycle_seconds(21.0)
		"midnight":
			_time_of_day_sec = _clock_hour_to_cycle_seconds(0.0)
		_:
			return false
	_update_day_night(0.0)
	return true

func _apply_cycle_settings() -> void:
	var p: Dictionary = {}
	if config_manager != null and config_manager.gameplay.has("gameplay") and config_manager.gameplay["gameplay"] is Dictionary:
		p = config_manager.gameplay.get("gameplay", {}) as Dictionary
	var use_real_clock: bool = bool(p.get("use_real_time_24h_clock", true))
	if use_real_clock:
		day_duration_sec = 14.0 * 60.0
		night_duration_sec = 10.0 * 60.0
	else:
		day_duration_sec = maxf(60.0, float(p.get("day_duration_sec", day_duration_sec)))
		night_duration_sec = maxf(60.0, float(p.get("night_duration_sec", night_duration_sec)))
	max_time_speed_multiplier = maxf(20.0, float(p.get("max_time_speed_multiplier", max_time_speed_multiplier)))
	time_speed_multiplier = clampf(float(p.get("time_speed_multiplier", time_speed_multiplier)), 0.0, max_time_speed_multiplier)
	keep_inventory_enabled = bool(p.get("keep_inventory", keep_inventory_enabled))
	Engine.max_fps = clampi(int(p.get("max_fps", 0)), 0, 1000)

func _setup_world_visuals(scene: Node) -> void:
	world_environment = WorldEnvironment.new()
	environment_resource = Environment.new()
	environment_resource.background_mode = Environment.BG_SKY
	environment_resource.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment_resource.ambient_light_sky_contribution = 1.0
	environment_resource.ambient_light_color = Color(0.90, 0.92, 0.98)
	var sky := Sky.new()
	sky_material_resource = ProceduralSkyMaterial.new()
	sky_material_resource.sky_top_color = Color(0.24, 0.42, 0.74)
	sky_material_resource.sky_horizon_color = Color(0.68, 0.82, 1.0)
	sky_material_resource.ground_horizon_color = Color(0.45, 0.38, 0.32)
	sky_material_resource.ground_bottom_color = Color(0.20, 0.17, 0.14)
	sky.sky_material = sky_material_resource
	environment_resource.sky = sky
	environment_resource.ambient_light_energy = 1.18
	world_environment.environment = environment_resource
	scene.add_child(world_environment)

	if sky_anchor != null:
		sky_anchor.queue_free()
	sky_anchor = Node3D.new()
	scene.add_child(sky_anchor)

	sun_light = DirectionalLight3D.new()
	sun_light.shadow_enabled = true
	sun_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun_light.light_energy = 1.35
	sun_light.light_color = Color(1.0, 0.96, 0.90)
	scene.add_child(sun_light)

	moon_light = DirectionalLight3D.new()
	moon_light.shadow_enabled = false
	moon_light.light_energy = 0.0
	moon_light.light_color = Color(0.62, 0.70, 0.96)
	scene.add_child(moon_light)

	sun_sprite = Sprite3D.new()
	sun_sprite.texture = load("res://assets/textures/sky/sun.png") as Texture2D
	sun_sprite.pixel_size = 1.10
	sun_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sun_sprite.shaded = false
	sky_anchor.add_child(sun_sprite)

	moon_phase_textures.clear()
	for phase_i in range(8):
		var phase_path: String = "res://assets/textures/sky/moon_phase_%d.png" % phase_i
		var phase_tex: Texture2D = load(phase_path) as Texture2D
		if phase_tex != null:
			moon_phase_textures.append(phase_tex)
	moon_sprite = Sprite3D.new()
	moon_sprite.texture = moon_phase_textures[0] if moon_phase_textures.size() > 0 else (load("res://assets/textures/sky/moon.png") as Texture2D)
	moon_sprite.pixel_size = 0.72
	moon_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	moon_sprite.shaded = false
	sky_anchor.add_child(moon_sprite)

	_setup_clouds()

func _smooth01(t: float) -> float:
	var c: float = clampf(t, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)

func _update_celestial_sprite(sprite: Sprite3D, dir: Vector3, dist: float, color_mod: Color) -> void:
	if sprite == null or player == null:
		return
	# dir points from the world toward the celestial body/light source, so the sprite should be placed along +dir.
	sprite.global_position = player.global_position + dir.normalized() * dist
	sprite.modulate = color_mod

func _setup_clouds() -> void:
	if sky_anchor == null:
		return
	if cloud_root != null:
		cloud_root.queue_free()
	cloud_root = Node3D.new()
	cloud_root.name = "CloudRoot"
	sky_anchor.add_child(cloud_root)
	cloud_sprites.clear()
	cloud_base_positions.clear()
	var cloud_tex: Texture2D = load("res://assets/textures/sky/clouds.png") as Texture2D
	var rng := RandomNumberGenerator.new()
	rng.seed = 13371337
	for i in range(18):
		var sprite := Sprite3D.new()
		sprite.texture = cloud_tex
		sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		sprite.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		sprite.pixel_size = rng.randf_range(0.90, 1.35)
		var local_pos: Vector3 = Vector3(rng.randf_range(-240.0, 240.0), rng.randf_range(0.0, 18.0), rng.randf_range(-240.0, 240.0))
		sprite.position = local_pos
		sprite.modulate = Color(1.0, 1.0, 1.0, 0.0)
		cloud_root.add_child(sprite)
		cloud_sprites.append(sprite)
		cloud_base_positions.append(local_pos)

func _update_clouds(day_amount: float, dt: float) -> void:
	if cloud_root == null or player == null:
		return
	var tile_size: float = 512.0
	var time_s: float = Time.get_ticks_msec() / 1000.0
	var drift_x: float = time_s * cloud_scroll_speed
	var snapped_x: float = floor((player.global_position.x - drift_x) / tile_size) * tile_size
	var snapped_z: float = floor(player.global_position.z / tile_size) * tile_size
	cloud_root.global_position = Vector3(snapped_x + drift_x, 108.0, snapped_z)
	var target_alpha: float = 0.12 + day_amount * 0.42
	var blend: float = 1.0 if dt <= 0.0 else clampf(dt * 1.4, 0.0, 1.0)
	for i in range(cloud_sprites.size()):
		var sprite: Sprite3D = cloud_sprites[i] as Sprite3D
		if sprite == null:
			continue
		var base_pos: Vector3 = cloud_base_positions[i] if i < cloud_base_positions.size() else sprite.position
		sprite.position = Vector3(base_pos.x, base_pos.y + sin(time_s * 0.08 + float(i) * 0.61) * 0.3, base_pos.z)
		var target_color: Color = Color(1.0, 1.0, 1.0, target_alpha)
		sprite.modulate = sprite.modulate.lerp(target_color, blend)

func _update_day_night(dt: float) -> void:
	var total_cycle: float = day_duration_sec + night_duration_sec
	if total_cycle <= 0.0:
		return
	var prev_time: float = _time_of_day_sec
	_time_of_day_sec = fmod(_time_of_day_sec + dt, total_cycle)
	if _time_of_day_sec < 0.0:
		_time_of_day_sec += total_cycle
	if dt > 0.0 and _time_of_day_sec < prev_time:
		_day_count += 1

	var hour: float = _cycle_to_clock_hour(_time_of_day_sec)
	var daylight: float = 0.0
	if hour >= 7.0 and hour < 17.0:
		daylight = 1.0
	elif hour >= 5.0 and hour < 7.0:
		daylight = _smooth01((hour - 5.0) / 2.0)
	elif hour >= 17.0 and hour < 19.0:
		daylight = 1.0 - _smooth01((hour - 17.0) / 2.0)
	else:
		daylight = 0.0
	var twilight: float = 0.0
	if hour >= 5.0 and hour < 7.0:
		twilight = 1.0 - absf(((hour - 5.0) / 2.0) - 0.5) * 2.0
	elif hour >= 17.0 and hour < 19.0:
		twilight = 1.0 - absf(((hour - 17.0) / 2.0) - 0.5) * 2.0

	var sun_progress: float = clampf((hour - 6.0) / 12.0, 0.0, 1.0)
	var sun_height: float = sin(sun_progress * PI)
	var sun_horiz: float = lerpf(0.95, -0.95, sun_progress)
	var target_sun_dir: Vector3 = Vector3(sun_horiz, maxf(-0.26, sun_height), -0.28).normalized()
	var moon_hour: float = fmod(hour + 12.0, 24.0)
	var moon_progress: float = clampf((moon_hour - 6.0) / 12.0, 0.0, 1.0)
	var moon_height: float = sin(moon_progress * PI)
	var moon_horiz: float = lerpf(-0.95, 0.95, moon_progress)
	var target_moon_dir: Vector3 = Vector3(moon_horiz, maxf(-0.26, moon_height), 0.24).normalized()
	var target_sun_strength: float = daylight
	var target_moon_strength: float = maxf(0.0, 1.0 - daylight * 0.96) * maxf(0.18, sin(moon_progress * PI))

	var day_tint: Color = Color(1.00, 0.995, 0.99)
	var dusk_tint: Color = Color(1.00, 0.72, 0.50)
	var night_tint: Color = Color(0.18, 0.22, 0.34)
	var target_ambient: Color = night_tint.lerp(dusk_tint, twilight * 0.75).lerp(day_tint, daylight)
	var target_sky: Color = Color(0.08, 0.11, 0.20).lerp(Color(0.97, 0.69, 0.48), twilight * 0.62).lerp(Color(0.53, 0.77, 1.0), daylight)
	var target_terrain_tint: Color = Color(0.78, 0.84, 0.94).lerp(Color(1.0, 1.0, 1.0), clampf(daylight * 0.9 + twilight * 0.1, 0.0, 1.0))

	var blend: float = 1.0 if dt <= 0.0 else clampf(dt * 0.20, 0.0, 1.0)
	_sky_color_current = _sky_color_current.lerp(target_sky, blend)
	_ambient_color_current = _ambient_color_current.lerp(target_ambient, blend)
	_terrain_tint_current = _terrain_tint_current.lerp(target_terrain_tint, blend)
	_sun_dir_current = _sun_dir_current.lerp(target_sun_dir, blend).normalized()
	_moon_dir_current = _moon_dir_current.lerp(target_moon_dir, blend).normalized()
	_sun_strength_current = lerpf(_sun_strength_current, target_sun_strength, blend)
	_moon_strength_current = lerpf(_moon_strength_current, target_moon_strength, blend)

	if environment_resource != null:
		environment_resource.background_color = _sky_color_current
		environment_resource.ambient_light_color = _ambient_color_current
		environment_resource.ambient_light_energy = 0.82 + _sun_strength_current * 1.18 + _moon_strength_current * 0.24
	if sky_material_resource != null:
		sky_material_resource.sky_top_color = _sky_color_current.darkened(0.18)
		sky_material_resource.sky_horizon_color = _sky_color_current
		sky_material_resource.ground_horizon_color = Color(0.32, 0.28, 0.24).lerp(Color(0.58, 0.42, 0.24), twilight * 0.4)
		sky_material_resource.ground_bottom_color = Color(0.12, 0.10, 0.09)

	if sun_light != null:
		sun_light.light_color = Color(1.0, 0.96, 0.90).lerp(Color(1.0, 0.80, 0.56), twilight)
		sun_light.light_energy = _sun_strength_current * 1.35
		sun_light.visible = _sun_strength_current > 0.01
		sun_light.look_at(-_sun_dir_current, Vector3.UP)
	if moon_light != null:
		moon_light.light_color = Color(0.76, 0.84, 1.0)
		moon_light.light_energy = _moon_strength_current * 0.34
		moon_light.visible = _moon_strength_current > 0.01
		moon_light.look_at(-_moon_dir_current, Vector3.UP)

	if world_manager != null:
		world_manager.call("set_day_night_tint", _terrain_tint_current)
		if world_manager.has_method("set_celestial_lighting"):
			world_manager.call("set_celestial_lighting", _sun_dir_current, _moon_dir_current, _sun_strength_current, _moon_strength_current, _ambient_color_current)

	_update_celestial_sprite(sun_sprite, _sun_dir_current, 180.0, Color(1, 1, 1, clampf(_sun_strength_current * 1.10, 0.0, 1.0)))
	_update_celestial_sprite(moon_sprite, _moon_dir_current, 180.0, Color(1, 1, 1, clampf(_moon_strength_current * 1.18, 0.0, 1.0)))
	if moon_sprite != null and moon_phase_textures.size() > 0:
		var phase_index: int = _day_count % moon_phase_textures.size()
		moon_sprite.texture = moon_phase_textures[phase_index]
	if sun_sprite != null:
		sun_sprite.visible = _sun_strength_current > 0.01
	if moon_sprite != null:
		moon_sprite.visible = _moon_strength_current > 0.01
	_update_clouds(daylight, dt)

func _load_player_state(default_spawn_pos: Vector3) -> void:
	if player == null:
		return
	var path: String = _playerdata_path()
	if not KZ_PathUtil.file_exists(path):
		player.global_position = default_spawn_pos
		return
	var txt: String = KZ_PathUtil.read_text(path)
	var parsed_v: Variant = JSON.parse_string(txt)
	if typeof(parsed_v) != TYPE_DICTIONARY:
		player.global_position = default_spawn_pos
		return
	var parsed: Dictionary = parsed_v as Dictionary
	player.load_state(parsed)

func _save_player_state() -> void:
	if player == null:
		return
	KZ_PathUtil.write_text(_playerdata_path(), JSON.stringify(player.serialize_state(), "\t"))

func _load_world_state() -> void:
	_time_of_day_sec = _clock_hour_to_cycle_seconds(8.0)
	_day_count = 0
	keep_inventory_enabled = false
	time_speed_multiplier = 1.0
	max_time_speed_multiplier = 240.0
	game_mode = "survival"
	var path: String = _worldstate_path()
	if not KZ_PathUtil.file_exists(path):
		return
	var txt: String = KZ_PathUtil.read_text(path)
	var parsed_v: Variant = JSON.parse_string(txt)
	if typeof(parsed_v) != TYPE_DICTIONARY:
		return
	var parsed: Dictionary = parsed_v as Dictionary
	_time_of_day_sec = float(parsed.get("time_of_day_sec", _time_of_day_sec))
	_day_count = int(parsed.get("day_count", _day_count))
	keep_inventory_enabled = bool(parsed.get("keep_inventory", keep_inventory_enabled))
	max_time_speed_multiplier = maxf(20.0, float(parsed.get("max_time_speed_multiplier", max_time_speed_multiplier)))
	time_speed_multiplier = clampf(float(parsed.get("time_speed_multiplier", time_speed_multiplier)), 0.0, max_time_speed_multiplier)
	game_mode = str(parsed.get("game_mode", game_mode)).to_lower()
	if game_mode != "creative":
		game_mode = "survival"

func _save_world_state() -> void:
	var data: Dictionary = {
		"time_of_day_sec": _time_of_day_sec,
		"day_count": _day_count,
		"keep_inventory": keep_inventory_enabled,
		"time_speed_multiplier": time_speed_multiplier,
		"max_time_speed_multiplier": max_time_speed_multiplier,
		"game_mode": game_mode
	}
	KZ_PathUtil.write_text(_worldstate_path(), JSON.stringify(data, "\t"))
	if server != null:
		server.save_world_state()

func respawn_player() -> void:
	if player == null or server == null:
		return
	if not keep_inventory_enabled:
		player.inventory.clear_all()
		player.cursor_item_id = ""
		player.cursor_count = 0
		player.emit_signal("inventory_changed")
	var spawn_pos: Vector3 = server.get_spawn_position()
	player.restore_to_spawn(spawn_pos)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED as Input.MouseMode)
	_post_system("Respawned.")

func save_and_leave_game() -> void:
	_save_session_state()
	_cleanup_session_nodes()

func save_and_return_to_main_menu() -> void:
	_save_session_state()
	_cleanup_session_nodes()
	_show_main_menu()

func return_to_main_menu() -> void:
	save_and_return_to_main_menu()

func _save_session_state() -> void:
	if not is_session_active:
		return
	_save_player_state()
	_save_world_state()

func _cleanup_session_nodes() -> void:
	if not is_session_active:
		return
	is_session_active = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE as Input.MouseMode)
	if hud != null:
		hud.queue_free()
		hud = null
	if player != null:
		player.queue_free()
		player = null
	if world_manager != null:
		world_manager.queue_free()
		world_manager = null
	if world_environment != null:
		world_environment.queue_free()
		world_environment = null
		environment_resource = null
	if sun_light != null:
		sun_light.queue_free()
		sun_light = null
	if moon_light != null:
		moon_light.queue_free()
		moon_light = null
	if sky_anchor != null:
		sky_anchor.queue_free()
		sky_anchor = null
		sun_sprite = null
		moon_sprite = null
		sky_material_resource = null
		cloud_root = null
		cloud_sprites.clear()
	if server != null:
		server.queue_free()
		server = null
	if animals_root != null:
		animals_root.queue_free()
		animals_root = null
	if chat_bus != null:
		chat_bus.queue_free()
		chat_bus = null

func _show_main_menu() -> void:
	var scene: Node = get_tree().current_scene
	if scene != null and scene.has_method("show_menu"):
		scene.call("show_menu")

func _on_block_broken(world_block: Vector3i, runtime_id: int) -> void:
	var sid: String = block_registry.get_string_id(runtime_id)
	spawn_dropped_item(sid, 1, Vector3(float(world_block.x) + 0.5, float(world_block.y) + 0.6, float(world_block.z) + 0.5))

func spawn_dropped_item(item_id: String, count: int, world_pos: Vector3) -> void:
	if item_id == "" or count <= 0 or block_registry == null:
		return
	var rid: int = block_registry.get_runtime_id(item_id)
	if rid == 0:
		return
	var def: KZ_BlockRegistry.BlockDef = block_registry.get_def_by_runtime(rid)
	var drop := KZ_DroppedItem.new()
	var scene: Node = get_tree().current_scene
	if scene == null:
		scene = get_tree().root
	scene.add_child(drop)
	drop.global_position = world_pos
	drop.setup(item_id, count, def.tint if def != null else Color(1, 1, 1, 1))


func give_item_to_player(item_id: String, count: int) -> int:
	if player == null or block_registry == null or item_id == "" or count <= 0:
		return 0
	var remaining: int = player.inventory.add_item(item_id, count, block_registry.get_stack_size(item_id))
	player.emit_signal("inventory_changed")
	return count - remaining

func get_game_mode() -> String:
	return game_mode

func is_creative_mode() -> bool:
	return game_mode == "creative"

func is_survival_mode() -> bool:
	return game_mode != "creative"

func set_game_mode(mode: String) -> void:
	game_mode = mode.to_lower()
	if game_mode != "creative":
		game_mode = "survival"
	if is_session_active:
		_save_world_state()
	if player != null:
		player.emit_signal("inventory_changed")

func resolve_item_token(token: String) -> Dictionary:
	if block_registry == null:
		return {"ok": false}
	var sid: String = block_registry.resolve_string_id(token)
	var rid: int = block_registry.get_runtime_id(sid)
	if rid == 0:
		return {"ok": false}
	var def: KZ_BlockRegistry.BlockDef = block_registry.get_def_by_runtime(rid)
	return {
		"ok": true,
		"string_id": sid,
		"runtime_id": rid,
		"name": def.name if def != null else sid,
		"placeable": def.placeable if def != null else false
	}

func get_stack_size_for_item(item_id: String) -> int:
	if block_registry == null:
		return 64
	return block_registry.get_stack_size(item_id)

func try_craft_items(grid_ids: Array[String], grid_counts: Array[int], grid_w: int, grid_h: int) -> Dictionary:
	var min_x: int = grid_w
	var min_y: int = grid_h
	var max_x: int = -1
	var max_y: int = -1
	for y in range(grid_h):
		for x in range(grid_w):
			var idx: int = x + y * grid_w
			if idx < grid_ids.size() and idx < grid_counts.size() and grid_ids[idx] != "" and grid_counts[idx] > 0:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return {"item_id": "", "count": 0, "consume": []}

	var pattern: Array[String] = []
	var used: Array[int] = []
	for y2 in range(min_y, max_y + 1):
		var row: Array[String] = []
		for x2 in range(min_x, max_x + 1):
			var idx2: int = x2 + y2 * grid_w
			var item_id: String = grid_ids[idx2]
			row.append(item_id)
			if item_id != "":
				used.append(idx2)
		pattern.append(",".join(row))
	var key: String = ";".join(pattern)
	for recipe in _get_recipe_defs():
		var recipe_pattern_v: Variant = recipe.get("pattern", [])
		if typeof(recipe_pattern_v) != TYPE_ARRAY:
			continue
		var recipe_pattern: Array = recipe_pattern_v as Array
		var rows: Array[String] = []
		for row_v in recipe_pattern:
			rows.append(str(row_v))
		if ";".join(rows) == key:
			return {
				"item_id": str(recipe.get("output", "")),
				"count": int(recipe.get("count", 1)),
				"consume": used
			}
	return {"item_id": "", "count": 0, "consume": []}

func _parse_cmdline_args() -> void:
	var args := OS.get_cmdline_args()
	for a in args:
		if a.begins_with("--instance="):
			instance_name = a.get_slice("=", 1).strip_edges()
		elif a.begins_with("--world="):
			world_name = a.get_slice("=", 1).strip_edges()
