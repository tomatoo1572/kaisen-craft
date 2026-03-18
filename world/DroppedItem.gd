extends Node3D
class_name KZ_DroppedItem

# Pickup item with simple voxel gravity.
# Still lightweight: no RigidBody3D dependency.

var item_id: String = ""
var count: int = 1

var lifetime_sec: float = 30.0
var pickup_radius: float = 1.2

var gravity: float = 18.0
var item_half_height: float = 0.15
var settle_offset: float = 0.02
var bob_amp: float = 0.08
var bob_speed: float = 2.0

var _age: float = 0.0
var _spin_speed: float = 2.2
var _vel_y: float = 0.0
var _grounded: bool = false

var _mesh: MeshInstance3D

func _init() -> void:
	_mesh = MeshInstance3D.new()
	add_child(_mesh)
	var box := BoxMesh.new()
	box.size = Vector3(0.30, 0.30, 0.30)
	_mesh.mesh = box

func setup(p_item_id: String, p_count: int, color: Color) -> void:
	item_id = p_item_id
	count = max(1, p_count)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	_mesh.material_override = mat

func _physics_process(dt: float) -> void:
	_age += dt
	rotate_y(_spin_speed * dt)

	var srv: Node = _get_server()
	if srv != null:
		_vel_y -= gravity * dt
		var pos: Vector3 = global_position
		pos.y += _vel_y * dt

		var floor_y: float = _find_floor_y(srv, pos)
		if floor_y > -999999.0:
			var rest_y: float = floor_y + item_half_height + settle_offset
			if pos.y <= rest_y:
				pos.y = rest_y
				_vel_y = 0.0
				_grounded = true
			else:
				_grounded = false
		else:
			_grounded = false

		global_position = pos

	if _grounded:
		_mesh.position.y = sin(_age * bob_speed) * bob_amp
	else:
		_mesh.position.y = 0.0

	var player: Node3D = _get_player()
	if player != null:
		var d: float = player.global_position.distance_to(global_position)
		if d <= pickup_radius:
			var picked: bool = false
			if player.has_method("pickup_item"):
				picked = bool(player.call("pickup_item", item_id, count))
			if picked:
				queue_free()
				return

	if _age >= lifetime_sec:
		queue_free()

func _find_floor_y(srv: Node, pos: Vector3) -> float:
	var wx: int = int(floor(pos.x))
	var wz: int = int(floor(pos.z))
	var start_y: int = int(floor(pos.y))
	for wy in range(start_y, start_y - 8, -1):
		if srv.get_block_at_world(wx, wy, wz) != 0:
			return float(wy + 1)
	return -1000000.0

func _get_server() -> Node:
	var game: Node = get_node_or_null("/root/Game")
	if game == null:
		return null
	var srv_v: Variant = game.get("server")
	if srv_v is Node:
		return srv_v as Node
	return null

func _get_player() -> Node3D:
	var game: Node = get_node_or_null("/root/Game")
	if game == null:
		return null
	var p: Variant = game.get("player")
	if p is Node3D:
		return p as Node3D
	return null
