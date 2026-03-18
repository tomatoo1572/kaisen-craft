extends CharacterBody3D
class_name KZ_Player

signal inventory_changed
signal inventory_opened(open: bool)
signal hotbar_selected_changed(index: int)
signal settings_opened(open: bool)
signal chat_opened(open: bool)
signal health_changed(current: float, max_value: float)
signal hunger_changed(current: float, max_value: float)
signal thirst_changed(current: float, max_value: float)
signal auto_step_changed(enabled: bool)
signal walk_mode_changed(mode_name: String)
signal died
signal crafting_table_opened(open: bool)

var walk_speed: float = 4.8
var jog_speed: float = 7.8
var run_speed: float = 12.4
var walk_mode_index: int = 1
var jump_velocity: float = 6.85
var gravity: float = 42.0
var mouse_sensitivity: float = 0.12
var camera_fov: float = 75.0

var cam: Camera3D
var pitch: float = 0.0

# Voxel collision sampling
var body_radius: float = 0.27
var floor_probe_radius: float = 0.20
var step_height: float = 1.02
var auto_step_enabled: bool = false

# Ground snapping
var ground_epsilon: float = 0.06
var snap_down_max: float = 0.64
var jump_climb_height: float = 1.24
var _jump_assist_timer: float = 0.0
var _coyote_timer: float = 0.0

# Block interaction
var reach_distance: float = 6.0
var mining_block: Vector3i = Vector3i(2147483647, 2147483647, 2147483647)
var mining_runtime_id: int = 0
var mining_progress_sec: float = 0.0

# Inventory / UI state
var inventory: KZ_Inventory = KZ_Inventory.new()
var inventory_is_open: bool = false
var settings_is_open: bool = false
var chat_is_open: bool = false
var crafting_table_is_open: bool = false

# Cursor stack (inventory UI)
var cursor_item_id: String = ""
var cursor_count: int = 0

# Survival stats
var max_health: float = 20.0
var health: float = 20.0
var max_hunger: float = 20.0
var hunger: float = 20.0
var max_thirst: float = 20.0
var thirst: float = 20.0
var hunger_drain_interval_sec: float = 35.0
var thirst_drain_interval_sec: float = 28.0
var starvation_damage_interval_sec: float = 8.0
var _hunger_timer: float = 0.0
var _thirst_timer: float = 0.0
var _starve_timer: float = 0.0
var is_dead: bool = false

var _vel_y: float = 0.0
var _is_grounded: bool = false

func _init() -> void:
	var col: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = body_radius
	capsule.height = 1.26
	col.shape = capsule
	col.position = Vector3(0, 0.90, 0)
	add_child(col)

	cam = Camera3D.new()
	cam.position = Vector3(0, 1.62, 0)
	cam.fov = camera_fov
	add_child(cam)

func _ready() -> void:
	if not _is_ui_open():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED as Input.MouseMode)
	_emit_survival_signals()
	emit_signal("auto_step_changed", auto_step_enabled)
	emit_signal("walk_mode_changed", get_walk_mode_name())

func apply_settings(gameplay_cfg: Dictionary) -> void:
	var p: Dictionary = {}
	if gameplay_cfg.has("player") and gameplay_cfg["player"] is Dictionary:
		p = gameplay_cfg.get("player", {}) as Dictionary
	elif gameplay_cfg.has("gameplay") and gameplay_cfg["gameplay"] is Dictionary:
		p = gameplay_cfg.get("gameplay", {}) as Dictionary
	else:
		p = gameplay_cfg

	walk_speed = float(p.get("walk_speed", p.get("player_walk_speed", walk_speed)))
	jog_speed = float(p.get("jog_speed", p.get("player_jog_speed", jog_speed)))
	run_speed = float(p.get("run_speed", p.get("player_run_speed", run_speed)))
	if jog_speed < walk_speed + 2.2:
		jog_speed = walk_speed + 1.8
	if run_speed < jog_speed + 3.0:
		run_speed = jog_speed + 2.6
	jump_velocity = clampf(float(p.get("jump_velocity", p.get("player_jump_velocity", jump_velocity))), 6.5, 7.2)
	gravity = maxf(40.0, float(p.get("gravity", gravity)))
	camera_fov = clampf(float(p.get("fov", p.get("camera_fov", p.get("player_fov", camera_fov)))), 20.0, 120.0)
	if cam != null:
		cam.fov = camera_fov
	mouse_sensitivity = float(p.get("mouse_sensitivity", mouse_sensitivity))
	if mouse_sensitivity < 0.01:
		mouse_sensitivity *= 100.0
	reach_distance = float(p.get("reach_distance", p.get("break_range", reach_distance)))
	auto_step_enabled = bool(p.get("auto_step_enabled", auto_step_enabled))
	step_height = clampf(float(p.get("step_height", step_height)), 0.60, 1.08)
	max_health = float(p.get("max_health", max_health))
	health = clampf(float(p.get("starting_health", max_health)), 0.0, max_health)
	max_hunger = float(p.get("max_hunger", max_hunger))
	hunger = clampf(float(p.get("starting_hunger", max_hunger)), 0.0, max_hunger)
	max_thirst = float(p.get("max_thirst", max_thirst))
	thirst = clampf(float(p.get("starting_thirst", max_thirst)), 0.0, max_thirst)
	hunger_drain_interval_sec = maxf(5.0, float(p.get("hunger_drain_interval_sec", hunger_drain_interval_sec)))
	thirst_drain_interval_sec = maxf(5.0, float(p.get("thirst_drain_interval_sec", thirst_drain_interval_sec)))
	_emit_survival_signals()
	emit_signal("auto_step_changed", auto_step_enabled)
	emit_signal("walk_mode_changed", get_walk_mode_name())

func _emit_survival_signals() -> void:
	emit_signal("health_changed", health, max_health)
	emit_signal("hunger_changed", hunger, max_hunger)
	emit_signal("thirst_changed", thirst, max_thirst)

func set_auto_step_enabled(enabled: bool) -> void:
	auto_step_enabled = enabled
	emit_signal("auto_step_changed", auto_step_enabled)


func set_camera_fov(value: float) -> void:
	camera_fov = clampf(value, 20.0, 120.0)
	if cam != null:
		cam.fov = camera_fov

func get_camera_fov() -> float:
	return camera_fov

func get_walk_mode_name() -> String:
	match walk_mode_index:
		0:
			return "Walking"
		1:
			return "Jogging"
		2:
			return "Running"
		_:
			return "Jogging"

func get_current_move_speed() -> float:
	match walk_mode_index:
		0:
			return walk_speed
		1:
			return jog_speed
		2:
			return run_speed
		_:
			return jog_speed

func cycle_walk_mode() -> void:
	walk_mode_index = (walk_mode_index + 1) % 3
	emit_signal("walk_mode_changed", get_walk_mode_name())

func set_walk_mode_index(idx: int) -> void:
	walk_mode_index = clampi(idx, 0, 2)
	emit_signal("walk_mode_changed", get_walk_mode_name())

func set_health(value: float) -> void:
	var old_dead: bool = is_dead
	health = clampf(value, 0.0, max_health)
	is_dead = health <= 0.0
	emit_signal("health_changed", health, max_health)
	if is_dead and not old_dead:
		emit_signal("died")

func set_hunger(value: float) -> void:
	hunger = clampf(value, 0.0, max_hunger)
	emit_signal("hunger_changed", hunger, max_hunger)

func set_thirst(value: float) -> void:
	thirst = clampf(value, 0.0, max_thirst)
	emit_signal("thirst_changed", thirst, max_thirst)

func damage(amount: float) -> void:
	if amount <= 0.0 or is_dead:
		return
	set_health(health - amount)

func heal(amount: float) -> void:
	if amount <= 0.0:
		return
	set_health(health + amount)

func restore_to_spawn(spawn_pos: Vector3) -> void:
	global_position = spawn_pos
	_vel_y = 0.0
	_is_grounded = false
	is_dead = false
	set_health(max_health)
	set_hunger(max_hunger)
	set_thirst(max_thirst)
	_hunger_timer = 0.0
	_thirst_timer = 0.0
	_starve_timer = 0.0
	if inventory_is_open:
		_set_inventory_open(false)
	if settings_is_open:
		_set_settings_open(false)
	if chat_is_open:
		set_chat_open(false)
	if crafting_table_is_open:
		set_crafting_table_open(false)

func pickup_item(item_id: String, count: int) -> bool:
	var remaining: int = inventory.add_item(item_id, count)
	var added: int = count - remaining
	if added > 0:
		emit_signal("inventory_changed")
	return remaining == 0

func serialize_state() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y, global_position.z],
		"pitch": pitch,
		"yaw": rotation.y,
		"health": health,
		"hunger": hunger,
		"thirst": thirst,
		"walk_mode_index": walk_mode_index,
		"selected_index": inventory.selected_index,
		"hotbar_ids": inventory.hotbar_ids.duplicate(),
		"hotbar_counts": inventory.hotbar_counts.duplicate(),
		"inv_ids": inventory.inv_ids.duplicate(),
		"inv_counts": inventory.inv_counts.duplicate()
	}

func load_state(data: Dictionary) -> void:
	if data.has("position") and data["position"] is Array:
		var arr: Array = data["position"] as Array
		if arr.size() >= 3:
			global_position = Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
	pitch = float(data.get("pitch", pitch))
	rotation.y = float(data.get("yaw", rotation.y))
	cam.rotation.x = pitch
	if data.has("hotbar_ids") and data["hotbar_ids"] is Array:
		var src_ids: Array = data["hotbar_ids"] as Array
		for i in range(min(src_ids.size(), inventory.hotbar_ids.size())):
			inventory.hotbar_ids[i] = str(src_ids[i])
	if data.has("hotbar_counts") and data["hotbar_counts"] is Array:
		var src_counts: Array = data["hotbar_counts"] as Array
		for j in range(min(src_counts.size(), inventory.hotbar_counts.size())):
			inventory.hotbar_counts[j] = int(src_counts[j])
	if data.has("inv_ids") and data["inv_ids"] is Array:
		var src_inv_ids: Array = data["inv_ids"] as Array
		for k in range(min(src_inv_ids.size(), inventory.inv_ids.size())):
			inventory.inv_ids[k] = str(src_inv_ids[k])
	if data.has("inv_counts") and data["inv_counts"] is Array:
		var src_inv_counts: Array = data["inv_counts"] as Array
		for m in range(min(src_inv_counts.size(), inventory.inv_counts.size())):
			inventory.inv_counts[m] = int(src_inv_counts[m])
	inventory.set_selected(int(data.get("selected_index", inventory.selected_index)))
	set_health(float(data.get("health", health)))
	if health <= 0.0:
		is_dead = false
		set_health(max_health)
	set_hunger(float(data.get("hunger", hunger)))
	set_thirst(float(data.get("thirst", thirst)))
	walk_mode_index = clampi(int(data.get("walk_mode_index", walk_mode_index)), 0, 2)
	emit_signal("inventory_changed")
	emit_signal("walk_mode_changed", get_walk_mode_name())
	emit_signal("hotbar_selected_changed", inventory.selected_index)

func _is_ui_open() -> bool:
	return inventory_is_open or settings_is_open or chat_is_open or crafting_table_is_open or is_dead

func _refresh_mouse_mode() -> void:
	if _is_ui_open():
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE as Input.MouseMode)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED as Input.MouseMode)

func _set_inventory_open(open: bool) -> void:
	if is_dead:
		return
	var final_open: bool = open

	if open and settings_is_open:
		settings_is_open = false
		emit_signal("settings_opened", false)
	if open and chat_is_open:
		chat_is_open = false
		emit_signal("chat_opened", false)
	if open and crafting_table_is_open:
		crafting_table_is_open = false
		emit_signal("crafting_table_opened", false)

	if not open and cursor_item_id != "" and cursor_count > 0:
		var remaining: int = inventory.add_item(cursor_item_id, cursor_count)
		cursor_count = remaining
		if cursor_count <= 0:
			cursor_count = 0
			cursor_item_id = ""
			emit_signal("inventory_changed")
		else:
			final_open = true

	inventory_is_open = final_open
	_refresh_mouse_mode()
	emit_signal("inventory_opened", inventory_is_open)

func _set_settings_open(open: bool) -> void:
	if is_dead:
		return
	if open and inventory_is_open:
		_set_inventory_open(false)
	if open and chat_is_open:
		chat_is_open = false
		emit_signal("chat_opened", false)
	if open and crafting_table_is_open:
		crafting_table_is_open = false
		emit_signal("crafting_table_opened", false)
	settings_is_open = open
	_refresh_mouse_mode()
	emit_signal("settings_opened", settings_is_open)

func set_chat_open(open: bool) -> void:
	if is_dead:
		return
	if open and inventory_is_open:
		_set_inventory_open(false)
	if open and settings_is_open:
		_set_settings_open(false)
	if open and crafting_table_is_open:
		set_crafting_table_open(false)
	chat_is_open = open
	_refresh_mouse_mode()
	emit_signal("chat_opened", chat_is_open)

func set_crafting_table_open(open: bool) -> void:
	if is_dead:
		return
	if open and inventory_is_open:
		_set_inventory_open(false)
	if open and settings_is_open:
		_set_settings_open(false)
	if open and chat_is_open:
		set_chat_open(false)
	crafting_table_is_open = open
	_refresh_mouse_mode()
	emit_signal("crafting_table_opened", crafting_table_is_open)

func _cycle_hotbar(delta: int) -> void:
	var idx: int = inventory.selected_index + delta
	while idx < 0:
		idx += KZ_Inventory.HOTBAR_SIZE
	idx = idx % KZ_Inventory.HOTBAR_SIZE
	inventory.set_selected(idx)
	emit_signal("hotbar_selected_changed", idx)

func _unhandled_input(event: InputEvent) -> void:
	if is_dead:
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var ek: InputEventKey = event as InputEventKey

		if event.is_action_pressed("inventory"):
			if settings_is_open:
				_set_settings_open(false)
			_set_inventory_open(not inventory_is_open)
			return

		if event.is_action_pressed("toggle_walk_mode"):
			if not _is_ui_open():
				cycle_walk_mode()
			return

		if event.is_action_pressed("ui_cancel"):
			if inventory_is_open:
				_set_inventory_open(false)
			elif settings_is_open:
				_set_settings_open(false)
			elif chat_is_open:
				set_chat_open(false)
			elif crafting_table_is_open:
				set_crafting_table_open(false)
			else:
				_set_settings_open(true)
			return

		if chat_is_open or settings_is_open or crafting_table_is_open:
			return

		if ek.keycode >= KEY_1 and ek.keycode <= KEY_9:
			var idx: int = int(ek.keycode - KEY_1)
			inventory.set_selected(idx)
			emit_signal("hotbar_selected_changed", idx)
			return

	if event is InputEventMouseMotion:
		if (not _is_ui_open()) and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			var mm: InputEventMouseMotion = event as InputEventMouseMotion
			rotate_y(-mm.relative.x * mouse_sensitivity * 0.01)
			pitch = clamp(pitch - mm.relative.y * mouse_sensitivity * 0.01, deg_to_rad(-89), deg_to_rad(89))
			cam.rotation.x = pitch
		return

	if event is InputEventMouseButton and not event.pressed and not event.is_echo():
		if event.is_action_released("attack"):
			_reset_mining_state()
		return

	if event is InputEventMouseButton and event.pressed and not event.is_echo():
		var mb: InputEventMouseButton = event as InputEventMouseButton

		if (not _is_ui_open()) and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED as Input.MouseMode)
			return

		if settings_is_open or chat_is_open or crafting_table_is_open:
			return

		if not inventory_is_open:
			if mb.button_index == MouseButton.MOUSE_BUTTON_WHEEL_UP:
				_cycle_hotbar(-1)
				return
			if mb.button_index == MouseButton.MOUSE_BUTTON_WHEEL_DOWN:
				_cycle_hotbar(+1)
				return

		if inventory_is_open:
			return

		if event.is_action_pressed("attack"):
			_try_break_block()
			return
		if event.is_action_pressed("use"):
			_try_place_block()
			return

func _physics_process(dt: float) -> void:
	if is_dead:
		return
	var srv: Node = _get_server()
	if srv == null:
		return

	_update_survival(dt)
	_update_block_breaking(dt)
	_jump_assist_timer = maxf(0.0, _jump_assist_timer - dt)

	var pos: Vector3 = global_position
	var prev_pos: Vector3 = pos

	var input_dir: Vector3 = Vector3.ZERO
	if not _is_ui_open():
		var forward: Vector3 = -global_transform.basis.z
		var right: Vector3 = global_transform.basis.x

		if Input.is_action_pressed("move_forward"):
			input_dir += forward
		if Input.is_action_pressed("move_back"):
			input_dir -= forward
		if Input.is_action_pressed("move_right"):
			input_dir += right
		if Input.is_action_pressed("move_left"):
			input_dir -= right

	input_dir.y = 0.0
	input_dir = input_dir.normalized()
	var move_speed: float = get_current_move_speed()
	var move_h: Vector3 = input_dir * move_speed * dt

	var floor_y_before: float = _find_local_floor_y(srv, pos)
	_is_grounded = false
	if floor_y_before > -999999.0:
		var dy_before: float = floor_y_before - pos.y
		var can_snap_down: bool = dy_before <= 0.0 and dy_before >= -snap_down_max
		if _vel_y <= 0.0 and pos.y <= floor_y_before + ground_epsilon and (can_snap_down or absf(dy_before) <= ground_epsilon):
			pos.y = floor_y_before
			_vel_y = 0.0
			_is_grounded = true

	if _is_grounded:
		_coyote_timer = 0.10
	else:
		_coyote_timer = maxf(0.0, _coyote_timer - dt)

	if (not _is_ui_open()) and Input.is_action_just_pressed("jump"):
		_jump_assist_timer = 0.28
		if _is_grounded or _coyote_timer > 0.0:
			_vel_y = jump_velocity
			_is_grounded = false
			_coyote_timer = 0.0
	else:
		_vel_y -= gravity * dt

	pos.y += _vel_y * dt
	pos = _move_with_voxel_collision(srv, pos, move_h)
	pos = _resolve_penetration_safe(srv, prev_pos, pos)

	var floor_y_after: float = _find_local_floor_y(srv, pos)
	if floor_y_after > -999999.0 and _vel_y <= 0.0:
		var dy_after: float = floor_y_after - pos.y
		var can_snap_down_after: bool = dy_after <= 0.0 and dy_after >= -snap_down_max
		if pos.y <= floor_y_after + ground_epsilon and (can_snap_down_after or absf(dy_after) <= ground_epsilon):
			pos.y = floor_y_after
			_vel_y = 0.0
			_is_grounded = true
		else:
			_is_grounded = false
	else:
		_is_grounded = false

	global_position = pos

func _update_survival(dt: float) -> void:
	_hunger_timer += dt
	_thirst_timer += dt
	if _hunger_timer >= hunger_drain_interval_sec:
		_hunger_timer = 0.0
		set_hunger(hunger - 1.0)
	if _thirst_timer >= thirst_drain_interval_sec:
		_thirst_timer = 0.0
		set_thirst(thirst - 1.0)
	if hunger <= 0.0 or thirst <= 0.0:
		_starve_timer += dt
		if _starve_timer >= starvation_damage_interval_sec:
			_starve_timer = 0.0
			damage(1.0)
	else:
		_starve_timer = 0.0

func _move_with_voxel_collision(srv: Node, pos: Vector3, move_h: Vector3) -> Vector3:
	if move_h.x != 0.0:
		pos = _attempt_axis_move(srv, pos, Vector3(move_h.x, 0.0, 0.0), true)
	if move_h.z != 0.0:
		pos = _attempt_axis_move(srv, pos, Vector3(0.0, 0.0, move_h.z), false)
	return pos

func _attempt_axis_move(srv: Node, pos: Vector3, delta: Vector3, is_x_axis: bool) -> Vector3:
	var try_pos: Vector3 = pos + delta
	if not _collides_at(srv, try_pos):
		return try_pos

	if auto_step_enabled and (_is_grounded or _vel_y <= 0.1):
		var stepped: Vector3 = _try_auto_step(srv, pos, delta)
		if stepped != pos:
			return stepped
	elif _vel_y > 0.0 or _jump_assist_timer > 0.0:
		var jump_climb: Vector3 = _try_jump_climb(srv, pos, delta)
		if jump_climb != pos:
			return jump_climb

	var nudges: Array[float] = [0.0, -0.10, 0.10, -0.20, 0.20]
	for n: float in nudges:
		var adjusted: Vector3 = pos
		if is_x_axis:
			adjusted.z += n
		else:
			adjusted.x += n
		if _collides_at(srv, adjusted):
			continue
		var moved: Vector3 = adjusted + delta
		if not _collides_at(srv, moved):
			return moved
		if auto_step_enabled:
			var moved_step: Vector3 = _try_auto_step(srv, adjusted, delta)
			if moved_step != adjusted:
				return moved_step
		elif _vel_y > 0.0 or _jump_assist_timer > 0.0:
			var moved_jump: Vector3 = _try_jump_climb(srv, adjusted, delta)
			if moved_jump != adjusted:
				return moved_jump

	return pos

func _try_auto_step(srv: Node, pos: Vector3, delta: Vector3) -> Vector3:
	var raised: Vector3 = pos + Vector3(0.0, step_height + 0.08, 0.0)
	if _collides_at(srv, raised):
		return pos
	var moved: Vector3 = raised + delta
	if _collides_at(srv, moved):
		return pos
	var floor_y: float = _find_local_floor_y(srv, moved)
	if floor_y <= -999999.0:
		return pos
	var dy: float = floor_y - pos.y
	if dy < -0.15 or dy > step_height + 0.18:
		return pos
	var landed: Vector3 = Vector3(moved.x, floor_y, moved.z)
	if _collides_at(srv, landed):
		return pos
	return landed

func _try_jump_climb(srv: Node, pos: Vector3, delta: Vector3) -> Vector3:
	var ahead: Vector3 = pos + delta
	var ahead_floor: float = _find_local_floor_y(srv, ahead)
	if ahead_floor > -999999.0:
		var ledge_dy: float = ahead_floor - pos.y
		if ledge_dy > 0.05 and ledge_dy <= jump_climb_height:
			var landed_direct: Vector3 = Vector3(ahead.x, ahead_floor, ahead.z)
			if not _collides_at(srv, landed_direct):
				return landed_direct

	var rises: Array[float] = [0.18, 0.36, 0.54, 0.72, 0.90, jump_climb_height]
	for rise: float in rises:
		var candidate: Vector3 = pos + Vector3(0.0, rise, 0.0) + delta
		if _collides_at(srv, candidate):
			continue
		var floor_y: float = _find_local_floor_y(srv, candidate)
		if floor_y <= -999999.0:
			continue
		var dy: float = floor_y - candidate.y
		if dy < -0.25 or dy > 0.65:
			continue
		var landed: Vector3 = Vector3(candidate.x, floor_y, candidate.z)
		if _collides_at(srv, landed):
			continue
		return landed
	return pos

func _resolve_penetration_safe(srv: Node, prev_pos: Vector3, pos: Vector3) -> Vector3:
	if not _collides_at(srv, pos):
		return pos

	var undo_h: Vector3 = Vector3(prev_pos.x, pos.y, prev_pos.z)
	if not _collides_at(srv, undo_h):
		return undo_h

	if not _collides_at(srv, prev_pos):
		if pos.y < prev_pos.y:
			_vel_y = 0.0
		return prev_pos

	var candidates: Array[Vector3] = [
		Vector3( 0.10,  0.00,  0.00),
		Vector3(-0.10,  0.00,  0.00),
		Vector3( 0.00,  0.00,  0.10),
		Vector3( 0.00,  0.00, -0.10),
		Vector3( 0.00, -0.10,  0.00),
		Vector3( 0.00, -0.20,  0.00),
		Vector3( 0.00,  0.10,  0.00)
	]
	for c: Vector3 in candidates:
		var p2: Vector3 = pos + c
		if not _collides_at(srv, p2):
			if c.y <= 0.0 and _vel_y < 0.0:
				_vel_y = 0.0
			return p2
	return prev_pos

func _find_local_floor_y(srv: Node, pos: Vector3) -> float:
	var r: float = floor_probe_radius
	var offsets: Array[Vector2] = [
		Vector2(+r, +r),
		Vector2(+r, -r),
		Vector2(-r, +r),
		Vector2(-r, -r),
		Vector2(0.0, 0.0)
	]

	var best: float = -1000000.0
	var y_min: int = int(floor(pos.y - snap_down_max - 1.0))
	var y_max: int = int(floor(pos.y + step_height + 1.5))

	for o: Vector2 in offsets:
		var wx: int = int(floor(pos.x + o.x))
		var wz: int = int(floor(pos.z + o.y))
		for wy in range(y_max, y_min - 1, -1):
			if srv.is_block_collidable_at_world(wx, wy, wz):
				best = maxf(best, float(wy + 1))
				break

	return best

func _collides_at(srv: Node, pos: Vector3) -> bool:
	var offsets: Array[Vector2] = [
		Vector2(+body_radius, +body_radius),
		Vector2(+body_radius, -body_radius),
		Vector2(-body_radius, +body_radius),
		Vector2(-body_radius, -body_radius),
		Vector2(0.0, 0.0)
	]
	var y_samples: Array[float] = [0.08, 0.92, 1.78]

	for oy: float in y_samples:
		var wy: int = int(floor(pos.y + oy))
		for o: Vector2 in offsets:
			var wx: int = int(floor(pos.x + o.x))
			var wz: int = int(floor(pos.z + o.y))
			if srv.is_block_collidable_at_world(wx, wy, wz):
				return true
	return false

func _get_server() -> Node:
	var game_node: Node = get_node_or_null("/root/Game")
	if game_node == null:
		return null
	var srv_v: Variant = game_node.get("server")
	if srv_v is Node:
		return srv_v as Node
	return null

func _reset_mining_state() -> void:
	mining_block = Vector3i(2147483647, 2147483647, 2147483647)
	mining_runtime_id = 0
	mining_progress_sec = 0.0

func is_breaking_block() -> bool:
	return mining_runtime_id != 0 and mining_progress_sec > 0.0

func get_break_progress_ratio() -> float:
	if mining_runtime_id == 0:
		return 0.0
	var break_time: float = _get_break_time_seconds(mining_runtime_id)
	if break_time <= 0.0:
		return 0.0
	return clampf(mining_progress_sec / break_time, 0.0, 1.0)

func get_break_progress_text() -> String:
	if mining_runtime_id == 0:
		return ""
	var pct: int = int(round(get_break_progress_ratio() * 100.0))
	return "Breaking %d%%" % pct

func _update_block_breaking(dt: float) -> void:
	if _is_ui_open() or not Input.is_action_pressed("attack"):
		_reset_mining_state()
		return
	var srv: Node = _get_server()
	if srv == null:
		_reset_mining_state()
		return
	var hit: Dictionary = _voxel_raycast(reach_distance)
	if not bool(hit.get("hit", false)):
		_reset_mining_state()
		return
	var b: Vector3i = hit["block"] as Vector3i
	var rid: int = srv.get_block_at_world(b.x, b.y, b.z)
	if rid == 0:
		_reset_mining_state()
		return
	if mining_block != b or mining_runtime_id != rid:
		mining_block = b
		mining_runtime_id = rid
		mining_progress_sec = 0.0
	var break_time: float = _get_break_time_seconds(rid)
	mining_progress_sec += dt
	if mining_progress_sec >= break_time:
		if srv.break_block_world(b.x, b.y, b.z):
			_reset_mining_state()
		else:
			mining_progress_sec = minf(mining_progress_sec, break_time * 0.75)

func _get_break_time_seconds(runtime_id: int) -> float:
	var srv: Node = _get_server()
	if srv == null or srv.registry == null:
		return 0.35
	var hardness: float = srv.registry.get_hardness_by_runtime(runtime_id)
	var preferred_tool: String = srv.registry.get_preferred_tool_by_runtime(runtime_id)
	var selected_item_id: String = inventory.get_selected_id()
	var speed_multiplier: float = 1.0
	if preferred_tool == "axe" and selected_item_id == "kaizencraft:wooden_axe":
		speed_multiplier = 2.4
	var base_time: float = maxf(0.12, hardness * 0.45)
	return maxf(0.08, base_time / speed_multiplier)

func _try_break_block() -> void:
	var srv: Node = _get_server()
	if srv == null:
		_reset_mining_state()
		return
	var hit: Dictionary = _voxel_raycast(reach_distance)
	if not bool(hit.get("hit", false)):
		_reset_mining_state()
		return
	var b: Vector3i = hit["block"] as Vector3i
	var rid: int = srv.get_block_at_world(b.x, b.y, b.z)
	if rid == 0:
		_reset_mining_state()
		return
	if mining_block != b or mining_runtime_id != rid:
		mining_block = b
		mining_runtime_id = rid
		mining_progress_sec = 0.0

func _try_place_block() -> void:
	var srv: Node = _get_server()
	if srv == null:
		return
	var hit: Dictionary = _voxel_raycast(reach_distance)
	if not bool(hit.get("hit", false)):
		return

	var b: Vector3i = hit["block"] as Vector3i
	var hit_rid: int = srv.get_block_at_world(b.x, b.y, b.z)
	if srv.registry != null and hit_rid == srv.registry.get_runtime_id("kaizencraft:crafting_table"):
		set_crafting_table_open(true)
		return

	if not inventory.has_selected():
		return
	var n: Vector3i = hit["normal"] as Vector3i
	var t: Vector3i = b + n

	if srv.get_block_at_world(t.x, t.y, t.z) != 0:
		return

	var item_id: String = inventory.get_selected_id()
	var rid: int = 0
	if srv.registry != null:
		rid = srv.registry.get_runtime_id(item_id)
		if not srv.registry.is_placeable(rid):
			return
	if rid == 0:
		return

	var ok: bool = srv.place_block_world(t.x, t.y, t.z, rid)
	if ok:
		inventory.consume_selected(1)
		emit_signal("inventory_changed")

func _voxel_raycast(max_dist: float) -> Dictionary:
	var srv: Node = _get_server()
	if srv == null:
		return {"hit": false}

	var origin: Vector3 = cam.global_position
	var dir: Vector3 = (-cam.global_transform.basis.z).normalized()

	var x: int = int(floor(origin.x))
	var y: int = int(floor(origin.y))
	var z: int = int(floor(origin.z))

	var step_x: int = 1 if dir.x > 0.0 else (-1 if dir.x < 0.0 else 0)
	var step_y: int = 1 if dir.y > 0.0 else (-1 if dir.y < 0.0 else 0)
	var step_z: int = 1 if dir.z > 0.0 else (-1 if dir.z < 0.0 else 0)

	var t_max_x: float = INF
	var t_max_y: float = INF
	var t_max_z: float = INF
	var t_delta_x: float = INF
	var t_delta_y: float = INF
	var t_delta_z: float = INF

	if step_x != 0:
		var next_x: float = float(x + (1 if step_x > 0 else 0))
		t_max_x = (next_x - origin.x) / dir.x
		t_delta_x = 1.0 / abs(dir.x)
	if step_y != 0:
		var next_y: float = float(y + (1 if step_y > 0 else 0))
		t_max_y = (next_y - origin.y) / dir.y
		t_delta_y = 1.0 / abs(dir.y)
	if step_z != 0:
		var next_z: float = float(z + (1 if step_z > 0 else 0))
		t_max_z = (next_z - origin.z) / dir.z
		t_delta_z = 1.0 / abs(dir.z)

	var traveled: float = 0.0
	var last_step_normal: Vector3i = Vector3i.ZERO

	if srv.get_block_at_world(x, y, z) != 0:
		return {"hit": true, "block": Vector3i(x, y, z), "normal": Vector3i.ZERO}

	while traveled <= max_dist:
		if t_max_x < t_max_y and t_max_x < t_max_z:
			x += step_x
			traveled = t_max_x
			t_max_x += t_delta_x
			last_step_normal = Vector3i(-step_x, 0, 0)
		elif t_max_y < t_max_z:
			y += step_y
			traveled = t_max_y
			t_max_y += t_delta_y
			last_step_normal = Vector3i(0, -step_y, 0)
		else:
			z += step_z
			traveled = t_max_z
			t_max_z += t_delta_z
			last_step_normal = Vector3i(0, 0, -step_z)

		if srv.get_block_at_world(x, y, z) != 0:
			return {"hit": true, "block": Vector3i(x, y, z), "normal": last_step_normal}

	return {"hit": false}
