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
	"inventory": {"type": "key", "code": KEY_E},
	"chat": {"type": "key", "code": KEY_T},
	"toggle_walk_mode": {"type": "key", "code": KEY_R},
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

var day_duration_sec: float = 15.0 * 60.0
var night_duration_sec: float = 20.0 * 60.0
var _time_of_day_sec: float = 0.0

var world_environment: WorldEnvironment
var environment_resource: Environment
var sun_light: DirectionalLight3D
var moon_light: DirectionalLight3D
var sky_anchor: Node3D
var sun_sprite: Sprite3D
var moon_sprite: Sprite3D
var keep_inventory_enabled: bool = false
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
	_update_day_night(dt)

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
		{"action": "inventory", "label": "Inventory"},
		{"action": "chat", "label": "Chat"},
		{"action": "toggle_walk_mode", "label": "Cycle Walk Mode"},
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
		if parts.size() >= 3 and parts[1].to_lower() == "set":
			var label: String = parts[2].to_lower()
			if set_time_preset(label):
				_post_system("Set time to %s." % label)
			else:
				_post_system("Usage: /time set morning|day|noon|afternoon|evening|night|midnight")
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
		var remaining: int = player.inventory.add_item(sid, count, block_registry.get_stack_size(sid))
		player.emit_signal("inventory_changed")
		var def_give: KZ_BlockRegistry.BlockDef = block_registry.get_def_by_runtime(rid)
		_post_system("Gave %d x %s (#%d)." % [count - remaining, def_give.name if def_give != null else sid, rid])
		return

	_post_system("Unknown command: /%s" % cmd)

func get_time_display_text() -> String:
	var info: Dictionary = get_time_display_info()
	var elapsed_min: float = float(info.get("elapsed_minutes", 0.0))
	var total_min: float = float(info.get("total_minutes", 0.0))
	var label: String = str(info.get("label", "Day"))
	return "%.1f/%.1f %s" % [elapsed_min, total_min, label]

func get_time_display_info() -> Dictionary:
	var total_cycle: float = day_duration_sec + night_duration_sec
	var sunrise: float = night_duration_sec * 0.5
	var sunset: float = sunrise + day_duration_sec
	var time_sec: float = fmod(_time_of_day_sec, total_cycle)
	if time_sec < 0.0:
		time_sec += total_cycle
	if time_sec >= sunrise and time_sec < sunset:
		var day_sec: float = time_sec - sunrise
		var day_t: float = day_sec / maxf(day_duration_sec, 0.001)
		var label: String = "Day"
		if day_t < 0.18:
			label = "Morning"
		elif day_t < 0.42:
			label = "Day"
		elif day_t < 0.58:
			label = "Noon"
		elif day_t < 0.82:
			label = "Afternoon"
		else:
			label = "Evening"
		return {"label": label, "elapsed_minutes": day_sec / 60.0, "total_minutes": day_duration_sec / 60.0, "is_day": true}
	var night_elapsed: float = time_sec - sunset
	if night_elapsed < 0.0:
		night_elapsed += total_cycle
	var night_t: float = night_elapsed / maxf(night_duration_sec, 0.001)
	var night_label: String = "Night"
	if night_t >= 0.35 and night_t <= 0.65:
		night_label = "Midnight"
	return {"label": night_label, "elapsed_minutes": night_elapsed / 60.0, "total_minutes": night_duration_sec / 60.0, "is_day": false}

func _show_help() -> void:
	_post_system("Commands: /help, /damage <amount>, /give <id|numeric_id> [count], /time set morning|day|noon|afternoon|evening|night|midnight, /keepinventory true|false, /gamerule keepInventory true|false")

func _post_system(text: String) -> void:
	if chat_bus != null:
		chat_bus.post_system(text)

func set_time_to_daylight() -> void:
	var sunrise: float = night_duration_sec * 0.5
	_time_of_day_sec = sunrise + day_duration_sec * 0.30
	_update_day_night(0.0)

func set_time_preset(label: String) -> bool:
	var sunrise: float = night_duration_sec * 0.5
	var sunset: float = sunrise + day_duration_sec
	match label:
		"morning":
			_time_of_day_sec = sunrise + day_duration_sec * 0.12
		"day":
			_time_of_day_sec = sunrise + day_duration_sec * 0.30
		"noon":
			_time_of_day_sec = sunrise + day_duration_sec * 0.50
		"afternoon":
			_time_of_day_sec = sunrise + day_duration_sec * 0.70
		"evening":
			_time_of_day_sec = sunrise + day_duration_sec * 0.88
		"night":
			_time_of_day_sec = sunset + night_duration_sec * 0.20
		"midnight":
			_time_of_day_sec = sunset + night_duration_sec * 0.50
		_:
			return false
	_update_day_night(0.0)
	return true

func _apply_cycle_settings() -> void:
	var p: Dictionary = {}
	if config_manager != null and config_manager.gameplay.has("gameplay") and config_manager.gameplay["gameplay"] is Dictionary:
		p = config_manager.gameplay.get("gameplay", {}) as Dictionary
	day_duration_sec = maxf(10.0, float(p.get("day_duration_sec", day_duration_sec)))
	night_duration_sec = maxf(10.0, float(p.get("night_duration_sec", night_duration_sec)))
	keep_inventory_enabled = bool(p.get("keep_inventory", keep_inventory_enabled))
	Engine.max_fps = clampi(int(p.get("max_fps", 0)), 0, 1000)

func _setup_world_visuals(scene: Node) -> void:
	world_environment = WorldEnvironment.new()
	environment_resource = Environment.new()
	environment_resource.background_mode = Environment.BG_COLOR
	environment_resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment_resource.ambient_light_sky_contribution = 0.0
	environment_resource.ambient_light_color = Color(0.90, 0.92, 0.98)
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
	sun_sprite.pixel_size = 0.32
	sun_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sun_sprite.shaded = false
	sky_anchor.add_child(sun_sprite)

	moon_sprite = Sprite3D.new()
	moon_sprite.texture = load("res://assets/textures/sky/moon.png") as Texture2D
	moon_sprite.pixel_size = 0.26
	moon_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	moon_sprite.shaded = false
	sky_anchor.add_child(moon_sprite)

func _smooth01(t: float) -> float:
	var c: float = clampf(t, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)

func _update_celestial_sprite(sprite: Sprite3D, dir: Vector3, dist: float, color_mod: Color) -> void:
	if sprite == null or player == null:
		return
	# dir points from the world toward the celestial body/light source, so the sprite should be placed along +dir.
	sprite.global_position = player.global_position + dir.normalized() * dist
	sprite.modulate = color_mod

func _update_day_night(dt: float) -> void:
	var total_cycle: float = day_duration_sec + night_duration_sec
	if total_cycle <= 0.0:
		return
	_time_of_day_sec = fmod(_time_of_day_sec + dt, total_cycle)
	if _time_of_day_sec < 0.0:
		_time_of_day_sec += total_cycle

	var sunrise: float = night_duration_sec * 0.5
	var sunset: float = sunrise + day_duration_sec
	var time_sec: float = _time_of_day_sec
	var overlap_sec: float = minf(day_duration_sec, night_duration_sec) * 0.18

	var sun_dir: Vector3 = Vector3(0.25, 1.0, -0.28).normalized()
	var moon_dir: Vector3 = Vector3(-0.25, 1.0, 0.24).normalized()
	var sun_strength: float = 0.0
	var moon_strength: float = 0.0
	var twilight: float = 0.0

	var day_t: float = clampf((time_sec - sunrise) / maxf(day_duration_sec, 0.001), 0.0, 1.0)
	var night_elapsed: float = time_sec - sunset
	if night_elapsed < 0.0:
		night_elapsed += total_cycle
	var night_t: float = clampf(night_elapsed / maxf(night_duration_sec, 0.001), 0.0, 1.0)

	var sun_height: float = sin(day_t * PI)
	var sun_horiz: float = lerpf(0.95, -0.95, day_t)
	sun_dir = Vector3(sun_horiz, maxf(-0.22, sun_height), -0.28).normalized()
	var moon_height: float = sin(night_t * PI)
	var moon_horiz: float = lerpf(-0.95, 0.95, night_t)
	moon_dir = Vector3(moon_horiz, maxf(-0.22, moon_height), 0.24).normalized()

	sun_strength = _smooth01(maxf(0.0, sun_height))
	moon_strength = _smooth01(maxf(0.0, moon_height))

	if time_sec >= sunset - overlap_sec and time_sec <= sunset + overlap_sec:
		var dusk_t: float = 1.0 - absf(time_sec - sunset) / maxf(overlap_sec, 0.001)
		moon_strength = maxf(moon_strength, dusk_t * 0.42)
		moon_dir = Vector3(0.85, maxf(0.06, dusk_t * 0.36), 0.22).normalized()
		twilight = maxf(twilight, dusk_t)
	if time_sec <= sunrise + overlap_sec or time_sec >= total_cycle - overlap_sec:
		var dawn_dist: float = minf(absf(time_sec - sunrise), absf((time_sec - total_cycle) - sunrise))
		var dawn_t: float = 1.0 - dawn_dist / maxf(overlap_sec, 0.001)
		sun_strength = maxf(sun_strength, dawn_t * 0.42)
		sun_dir = Vector3(-0.85, maxf(0.06, dawn_t * 0.34), -0.28).normalized()
		twilight = maxf(twilight, dawn_t)
	if twilight <= 0.0:
		twilight = maxf(1.0 - clampf(sun_height * 2.6, 0.0, 1.0), 1.0 - clampf(moon_height * 2.4, 0.0, 1.0))

	var day_tint: Color = Color(1.00, 0.99, 0.98)
	var dusk_tint: Color = Color(1.00, 0.82, 0.60)
	var night_tint: Color = Color(0.72, 0.78, 0.96)
	var ambient: Color = night_tint.lerp(dusk_tint, twilight * 0.65).lerp(day_tint, clampf(sun_strength, 0.0, 1.0))
	var sky: Color = Color(0.16, 0.19, 0.30).lerp(Color(0.96, 0.74, 0.52), twilight * 0.58).lerp(Color(0.58, 0.80, 1.0), clampf(sun_strength, 0.0, 1.0))

	if environment_resource != null:
		environment_resource.background_color = sky
		environment_resource.ambient_light_color = ambient
		environment_resource.ambient_light_energy = 1.04 + sun_strength * 1.02 + moon_strength * 0.34

	if sun_light != null:
		sun_light.light_color = Color(1.0, 0.96, 0.90).lerp(Color(1.0, 0.82, 0.60), twilight)
		sun_light.light_energy = sun_strength * 1.72
		sun_light.visible = sun_strength > 0.01
		sun_light.look_at(-sun_dir, Vector3.UP)
	if moon_light != null:
		moon_light.light_color = Color(0.76, 0.84, 1.0)
		moon_light.light_energy = moon_strength * 0.62
		moon_light.visible = moon_strength > 0.01
		moon_light.look_at(-moon_dir, Vector3.UP)

	var terrain_tint: Color = Color(0.93, 0.95, 1.0).lerp(Color(1.00, 1.00, 1.00), clampf(sun_strength * 0.85 + twilight * 0.10, 0.0, 1.0))
	if world_manager != null:
		world_manager.call("set_day_night_tint", terrain_tint)
		if world_manager.has_method("set_celestial_lighting"):
			world_manager.call("set_celestial_lighting", sun_dir, moon_dir, sun_strength, moon_strength, ambient)

	_update_celestial_sprite(sun_sprite, sun_dir, 180.0, Color(1, 1, 1, clampf(sun_strength * 1.10, 0.0, 1.0)))
	_update_celestial_sprite(moon_sprite, moon_dir, 180.0, Color(1, 1, 1, clampf(moon_strength * 1.18, 0.0, 1.0)))
	if sun_sprite != null:
		sun_sprite.visible = sun_strength > 0.01
	if moon_sprite != null:
		moon_sprite.visible = moon_strength > 0.01

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
	_time_of_day_sec = night_duration_sec * 0.5 + day_duration_sec * 0.12
	keep_inventory_enabled = false
	var path: String = _worldstate_path()
	if not KZ_PathUtil.file_exists(path):
		return
	var txt: String = KZ_PathUtil.read_text(path)
	var parsed_v: Variant = JSON.parse_string(txt)
	if typeof(parsed_v) != TYPE_DICTIONARY:
		return
	var parsed: Dictionary = parsed_v as Dictionary
	_time_of_day_sec = float(parsed.get("time_of_day_sec", _time_of_day_sec))
	keep_inventory_enabled = bool(parsed.get("keep_inventory", keep_inventory_enabled))

func _save_world_state() -> void:
	var data: Dictionary = {
		"time_of_day_sec": _time_of_day_sec,
		"keep_inventory": keep_inventory_enabled
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
	if server != null:
		server.queue_free()
		server = null
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
