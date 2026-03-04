extends CharacterBody3D
class_name KZ_Player

signal inventory_changed
signal inventory_opened(open: bool)
signal hotbar_selected_changed(index: int)

var walk_speed: float = 6.0
var jump_velocity: float = 5.5
var gravity: float = 18.0
var mouse_sensitivity: float = 0.12

var cam: Camera3D
var pitch: float = 0.0

# Voxel collision sampling
var body_radius: float = 0.35
var step_height: float = 1.0

# Ground snapping (no teleport)
var ground_epsilon: float = 0.06
var snap_up_max: float = 0.65
var snap_down_max: float = 1.25

# Block interaction
var reach_distance: float = 6.0

# Inventory (Stage 3)
var inventory: KZ_Inventory = KZ_Inventory.new()
var inventory_is_open: bool = false

# Cursor stack (inventory UI)
var cursor_item_id: String = ""
var cursor_count: int = 0

var _vel_y: float = 0.0

func _init() -> void:
	var col: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = body_radius
	capsule.height = 1.2
	col.shape = capsule
	col.position = Vector3(0, 0.95, 0)
	add_child(col)

	cam = Camera3D.new()
	cam.position = Vector3(0, 1.6, 0)
	add_child(cam)

func _ready() -> void:
	# Always start captured for mouse look
	if not inventory_is_open:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED as Input.MouseMode)

func apply_settings(gameplay_cfg: Dictionary) -> void:
	var p: Dictionary = gameplay_cfg.get("player", {}) as Dictionary
	walk_speed = float(p.get("walk_speed", walk_speed))
	jump_velocity = float(p.get("jump_velocity", jump_velocity))
	gravity = float(p.get("gravity", gravity))
	mouse_sensitivity = float(p.get("mouse_sensitivity", mouse_sensitivity))

func pickup_item(item_id: String, count: int) -> bool:
	var remaining: int = inventory.add_item(item_id, count)
	if remaining == 0:
		print("Picked up: ", item_id, " x", count)
		print(inventory.debug_string())
		emit_signal("inventory_changed")
		return true
	print("Inventory full, could not pick up all.")
	print(inventory.debug_string())
	return false

func _set_inventory_open(open: bool) -> void:
	inventory_is_open = open
	if inventory_is_open:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE as Input.MouseMode)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED as Input.MouseMode)
	emit_signal("inventory_opened", inventory_is_open)

func _cycle_hotbar(delta: int) -> void:
	var idx: int = inventory.selected_index + delta
	while idx < 0:
		idx += KZ_Inventory.HOTBAR_SIZE
	idx = idx % KZ_Inventory.HOTBAR_SIZE
	inventory.set_selected(idx)
	emit_signal("hotbar_selected_changed", idx)
	print("Selected hotbar slot ", idx + 1)
	print(inventory.debug_string())

func _unhandled_input(event: InputEvent) -> void:
	# Key input
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var ek: InputEventKey = event as InputEventKey

		# E toggles inventory
		if ek.keycode == KEY_E:
			_set_inventory_open(not inventory_is_open)
			return

		# ESC: close inventory if open; otherwise release mouse
		if ek.keycode == KEY_ESCAPE:
			if inventory_is_open:
				_set_inventory_open(false)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE as Input.MouseMode)
			return

		# Hotbar 1-9
		if ek.keycode >= KEY_1 and ek.keycode <= KEY_9:
			var idx: int = int(ek.keycode - KEY_1)
			inventory.set_selected(idx)
			emit_signal("hotbar_selected_changed", idx)
			print("Selected hotbar slot ", idx + 1)
			print(inventory.debug_string())
			return

	# Mouse motion: only look when captured AND inventory closed
	if event is InputEventMouseMotion:
		if (not inventory_is_open) and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			var mm: InputEventMouseMotion = event as InputEventMouseMotion
			rotate_y(-mm.relative.x * mouse_sensitivity * 0.01)
			pitch = clamp(pitch - mm.relative.y * mouse_sensitivity * 0.01, deg_to_rad(-89), deg_to_rad(89))
			cam.rotation.x = pitch
		return

	# Mouse buttons
	if event is InputEventMouseButton and event.pressed and not event.is_echo():
		var mb: InputEventMouseButton = event as InputEventMouseButton

		# If inventory is closed but mouse isn't captured, capture on first click and DO NOTHING ELSE
		if (not inventory_is_open) and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED as Input.MouseMode)
			return

		# Scroll wheel cycles hotbar (only when inventory closed)
		if not inventory_is_open:
			if mb.button_index == MouseButton.MOUSE_BUTTON_WHEEL_UP:
				_cycle_hotbar(-1)
				return
			if mb.button_index == MouseButton.MOUSE_BUTTON_WHEEL_DOWN:
				_cycle_hotbar(+1)
				return

		# If inventory open, don't break/place
		if inventory_is_open:
			return

		if mb.button_index == MouseButton.MOUSE_BUTTON_LEFT:
			_try_break_block()
			return
		if mb.button_index == MouseButton.MOUSE_BUTTON_RIGHT:
			_try_place_block()
			return

func _physics_process(dt: float) -> void:
	var srv: KZ_LocalWorldServer = _get_server()

	var pos: Vector3 = global_position
	var prev_pos: Vector3 = pos

	# Disable movement while inventory open
	var input_dir: Vector3 = Vector3.ZERO
	if not inventory_is_open:
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
	var move_h: Vector3 = input_dir * walk_speed * dt

	# Gravity
	_vel_y -= gravity * dt

	# Snap to ground ONLY if close
	if srv != null:
		var wx: int = int(floor(pos.x))
		var wz: int = int(floor(pos.z))
		var surface_y: float = float(srv.get_surface_y(wx, wz))
		var dy: float = surface_y - pos.y
		var close_enough: bool = (dy >= -snap_down_max and dy <= snap_up_max)

		if close_enough and _vel_y <= 0.0 and pos.y <= surface_y + ground_epsilon:
			pos.y = surface_y
			_vel_y = 0.0
			if (not inventory_is_open) and Input.is_action_just_pressed("jump"):
				_vel_y = jump_velocity

	# Apply vertical
	pos.y += _vel_y * dt

	# Voxel collision
	if srv != null:
		pos = _move_with_voxel_collision(srv, pos, move_h)
		pos = _resolve_penetration_safe(srv, prev_pos, pos)

	global_position = pos

func _move_with_voxel_collision(srv: KZ_LocalWorldServer, pos: Vector3, move_h: Vector3) -> Vector3:
	# X axis
	if move_h.x != 0.0:
		var try_pos: Vector3 = Vector3(pos.x + move_h.x, pos.y, pos.z)
		if not _collides_at(srv, try_pos):
			pos = try_pos
		else:
			var step_pos: Vector3 = Vector3(try_pos.x, pos.y + step_height, try_pos.z)
			if not _collides_at(srv, step_pos):
				pos = step_pos

	# Z axis
	if move_h.z != 0.0:
		var try_pos2: Vector3 = Vector3(pos.x, pos.y, pos.z + move_h.z)
		if not _collides_at(srv, try_pos2):
			pos = try_pos2
		else:
			var step_pos2: Vector3 = Vector3(try_pos2.x, pos.y + step_height, try_pos2.z)
			if not _collides_at(srv, step_pos2):
				pos = step_pos2

	# Gentle stick-down if close
	var wx: int = int(floor(pos.x))
	var wz: int = int(floor(pos.z))
	var surface_y: float = float(srv.get_surface_y(wx, wz))
	var dy: float = surface_y - pos.y
	if dy >= -snap_down_max and dy <= snap_up_max and _vel_y <= 0.0:
		if pos.y <= surface_y + ground_epsilon:
			pos.y = surface_y
			_vel_y = 0.0

	return pos

func _resolve_penetration_safe(srv: KZ_LocalWorldServer, prev_pos: Vector3, pos: Vector3) -> Vector3:
	if not _collides_at(srv, pos):
		return pos

	var undo_h: Vector3 = Vector3(prev_pos.x, pos.y, prev_pos.z)
	if not _collides_at(srv, undo_h):
		return undo_h

	if not _collides_at(srv, prev_pos):
		_vel_y = minf(_vel_y, 0.0)
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
			if _vel_y < 0.0:
				_vel_y = 0.0
			return p2
	return prev_pos

func _collides_at(srv: KZ_LocalWorldServer, pos: Vector3) -> bool:
	var offsets: Array[Vector2] = [
		Vector2(+body_radius, +body_radius),
		Vector2(+body_radius, -body_radius),
		Vector2(-body_radius, +body_radius),
		Vector2(-body_radius, -body_radius),
		Vector2(0.0, 0.0)
	]
	var y_samples: Array[float] = [0.1, 0.9, 1.7]

	for oy: float in y_samples:
		var wy: int = int(floor(pos.y + oy))
		for o: Vector2 in offsets:
			var wx: int = int(floor(pos.x + o.x))
			var wz: int = int(floor(pos.z + o.y))
			if srv.get_block_at_world(wx, wy, wz) != 0:
				return true
	return false

func _get_server() -> KZ_LocalWorldServer:
	var game_node: Node = get_node_or_null("/root/Game")
	if game_node == null:
		return null
	var srv_v: Variant = game_node.get("server")
	if srv_v is KZ_LocalWorldServer:
		return srv_v as KZ_LocalWorldServer
	return null

func _try_break_block() -> void:
	var srv: KZ_LocalWorldServer = _get_server()
	if srv == null:
		return
	var hit: Dictionary = _voxel_raycast(reach_distance)
	if not bool(hit.get("hit", false)):
		return
	var b: Vector3i = hit["block"] as Vector3i
	srv.break_block_world(b.x, b.y, b.z)

func _try_place_block() -> void:
	if not inventory.has_selected():
		return
	var srv: KZ_LocalWorldServer = _get_server()
	if srv == null:
		return
	var hit: Dictionary = _voxel_raycast(reach_distance)
	if not bool(hit.get("hit", false)):
		return

	var b: Vector3i = hit["block"] as Vector3i
	var n: Vector3i = hit["normal"] as Vector3i
	var t: Vector3i = b + n

	if srv.get_block_at_world(t.x, t.y, t.z) != 0:
		return

	var item_id: String = inventory.get_selected_id()
	var rid: int = 0
	if srv.registry != null:
		rid = srv.registry.get_runtime_id(item_id)
	if rid == 0:
		return

	var ok: bool = srv.place_block_world(t.x, t.y, t.z, rid)
	if ok:
		inventory.consume_selected(1)
		emit_signal("inventory_changed")

func _voxel_raycast(max_dist: float) -> Dictionary:
	var srv: KZ_LocalWorldServer = _get_server()
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
