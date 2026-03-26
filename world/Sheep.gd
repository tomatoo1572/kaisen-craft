extends Node3D
class_name KZ_Sheep

const CUSTOM_MODEL_PATH := "res://assets/models/entities/sheep/sheep.glb"

var max_health: float = 10.0
var health: float = 10.0
var move_speed: float = 1.2
var wander_radius: float = 8.0
var target_radius: float = 0.78
var wool_drop_min: int = 1
var wool_drop_max: int = 3
var mutton_drop_min: int = 1
var mutton_drop_max: int = 3

var _body_root: Node3D
var _hitbox_body: AnimatableBody3D
var _wander_dir: Vector3 = Vector3.ZERO
var _wander_timer: float = 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	add_to_group("kz_damageable")
	_rng.seed = int(Time.get_ticks_usec()) ^ int(global_position.x * 92821.0) ^ int(global_position.z * 68917.0)
	_build_hitbox()
	_build_visual()
	_pick_new_wander()


func _build_hitbox() -> void:
	if _hitbox_body != null:
		_hitbox_body.queue_free()
	_hitbox_body = AnimatableBody3D.new()
	_hitbox_body.name = "Hitbox"
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.9, 1.2, 1.3)
	col.shape = shape
	col.position = Vector3(0.0, 0.6, 0.0)
	_hitbox_body.add_child(col)
	add_child(_hitbox_body)

func setup_from_game() -> void:
	# Hook point for future external configs.
	max_health = 10.0
	health = max_health
	wool_drop_min = 1
	wool_drop_max = 3
	mutton_drop_min = 1
	mutton_drop_max = 3

func get_target_radius() -> float:
	return target_radius

func take_damage(amount: float, _attacker: Node = null) -> void:
	if amount <= 0.0:
		return
	health -= amount
	if health <= 0.0:
		_die()

func _physics_process(dt: float) -> void:
	var srv: Node = _get_server()
	if srv == null:
		return
	_wander_timer -= dt
	if _wander_timer <= 0.0:
		_pick_new_wander()
	var move: Vector3 = _wander_dir * move_speed * dt
	global_position += move
	if move.length_squared() > 0.0001:
		rotation.y = atan2(move.x, move.z)
	var surface_y: int = srv.get_surface_y(int(floor(global_position.x)), int(floor(global_position.z)))
	global_position.y = float(surface_y) + 0.02

func _pick_new_wander() -> void:
	_wander_timer = _rng.randf_range(1.5, 3.4)
	var angle: float = _rng.randf_range(-PI, PI)
	_wander_dir = Vector3(sin(angle), 0.0, cos(angle))
	if _rng.randf() < 0.28:
		_wander_dir = Vector3.ZERO

func _die() -> void:
	var game: Node = get_node_or_null("/root/Game")
	if game != null and game.has_method("spawn_dropped_item"):
		var wool_count: int = _rng.randi_range(wool_drop_min, wool_drop_max)
		var mutton_count: int = _rng.randi_range(mutton_drop_min, mutton_drop_max)
		game.call("spawn_dropped_item", "kaizencraft:wool", wool_count, global_position + Vector3(0.0, 0.25, 0.0))
		game.call("spawn_dropped_item", "kaizencraft:mutton", mutton_count, global_position + Vector3(0.18, 0.25, 0.0))
	queue_free()

func _build_visual() -> void:
	if _body_root != null:
		_body_root.queue_free()
	_body_root = Node3D.new()
	_body_root.name = "SheepVisual"
	add_child(_body_root)
	if ResourceLoader.exists(CUSTOM_MODEL_PATH):
		var packed: PackedScene = load(CUSTOM_MODEL_PATH) as PackedScene
		if packed != null:
			var inst: Node = packed.instantiate()
			_body_root.add_child(inst)
			return
	_build_fallback_sheep()

func _build_fallback_sheep() -> void:
	_add_box(Vector3(0.0, 0.72, 0.0), Vector3(0.95, 0.72, 1.25), Color(0.92, 0.92, 0.90), "Body")
	_add_box(Vector3(0.0, 1.14, 0.64), Vector3(0.54, 0.46, 0.44), Color(0.90, 0.90, 0.88), "Head")
	for lx in [-0.28, 0.28]:
		for lz in [-0.36, 0.36]:
			_add_box(Vector3(lx, 0.28, lz), Vector3(0.18, 0.56, 0.18), Color(0.25, 0.22, 0.20), "Leg")

func _add_box(local_pos: Vector3, size: Vector3, color: Color, node_name: String) -> void:
	var n := MeshInstance3D.new()
	n.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	n.material_override = mat
	n.position = local_pos
	_body_root.add_child(n)

func _get_server() -> Node:
	var game: Node = get_node_or_null("/root/Game")
	if game == null:
		return null
	var srv_v: Variant = game.get("server")
	if srv_v is Node:
		return srv_v as Node
	return null
