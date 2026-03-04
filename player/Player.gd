extends CharacterBody3D
class_name KZ_Player

var walk_speed: float = 6.0
var jump_velocity: float = 5.5
var gravity: float = 18.0
var mouse_sensitivity: float = 0.12

var cam: Camera3D
var pitch: float = 0.0

# Stage 1 ground clamp (heightmap-only). Later replaced by voxel collision.
var ground_epsilon: float = 0.05
var on_ground: bool = false

func _init() -> void:
	# Collision shape (not used for terrain yet, but we keep it for later stages)
	var col := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.2
	col.shape = capsule

	# Move capsule up so the CharacterBody origin is at the feet
	# Total capsule height ~= height + 2*radius = 1.9 -> half is ~0.95
	col.position = Vector3(0, 0.95, 0)
	add_child(col)

	# Camera
	cam = Camera3D.new()
	cam.position = Vector3(0, 1.6, 0)
	add_child(cam)

func apply_settings(gameplay_cfg: Dictionary) -> void:
	var p: Dictionary = gameplay_cfg.get("player", {}) as Dictionary
	walk_speed = float(p.get("walk_speed", walk_speed))
	jump_velocity = float(p.get("jump_velocity", jump_velocity))
	gravity = float(p.get("gravity", gravity))
	mouse_sensitivity = float(p.get("mouse_sensitivity", mouse_sensitivity))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed():
		if event.keycode == KEY_ESCAPE:
			if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity * 0.01)
		pitch = clamp(pitch - event.relative.y * mouse_sensitivity * 0.01, deg_to_rad(-89), deg_to_rad(89))
		cam.rotation.x = pitch

func _physics_process(dt: float) -> void:
	# Horizontal input
	var input_dir := Vector3.ZERO
	var forward := -global_transform.basis.z
	var right := global_transform.basis.x

	if Input.is_action_pressed("move_forward"):
		input_dir += forward
	if Input.is_action_pressed("move_back"):
		input_dir -= forward
	if Input.is_action_pressed("move_right"):
		input_dir += right
	if Input.is_action_pressed("move_left"):
		input_dir -= right

	input_dir.y = 0
	input_dir = input_dir.normalized()

	velocity.x = input_dir.x * walk_speed
	velocity.z = input_dir.z * walk_speed

	# Stage 1: heightmap ground
	var ground_y: float = _get_ground_y()

	# If we don't have a server yet, just apply gravity normally
	if ground_y > -1e19:
		# Determine grounded state before applying gravity
		on_ground = (global_position.y <= ground_y + ground_epsilon) and (velocity.y <= 0.0)

		if on_ground:
			# Stick to ground
			global_position.y = ground_y
			velocity.y = 0.0
			if Input.is_action_just_pressed("jump"):
				velocity.y = jump_velocity
				on_ground = false
		else:
			velocity.y -= gravity * dt
	else:
		velocity.y -= gravity * dt

	move_and_slide()

	# Clamp after movement too (prevents sinking/falling through)
	if ground_y > -1e19:
		if global_position.y < ground_y:
			global_position.y = ground_y
			if velocity.y < 0.0:
				velocity.y = 0.0
			on_ground = true

func _get_ground_y() -> float:
	# Pull server from autoload /root/Game without referencing "Game" symbol (safe even if not autoloaded)
	var game_node := get_node_or_null("/root/Game")
	if game_node == null:
		return -1e20

	var srv_v: Variant = game_node.get("server")
	if srv_v == null:
		return -1e20
	if not (srv_v is KZ_LocalWorldServer):
		return -1e20

	var srv: KZ_LocalWorldServer = srv_v as KZ_LocalWorldServer

	var wx: int = int(floor(global_position.x))
	var wz: int = int(floor(global_position.z))
	var h: int = srv.get_height_at_world(wx, wz)

	# Highest solid block is y=h, its top face is y=h+1
	return float(h + 1)
