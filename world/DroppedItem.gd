extends Node3D
class_name KZ_DroppedItem

# Minimal pickup item (Stage 3)
# No physics dependency: checks distance to player each frame.

var item_id: String = ""
var count: int = 1

var lifetime_sec: float = 30.0
var pickup_radius: float = 1.2

var _age: float = 0.0
var _spin_speed: float = 2.2
var _bob_amp: float = 0.12
var _base_y: float = 0.0

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
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh.material_override = mat

	_base_y = global_position.y

func _process(dt: float) -> void:
	_age += dt
	rotate_y(_spin_speed * dt)
	global_position.y = _base_y + sin(_age * 2.0) * _bob_amp

	# Pickup check
	var game: Node = get_node_or_null("/root/Game")
	if game != null:
		var p: Variant = game.get("player")
		if p is Node3D:
			var player: Node3D = p as Node3D
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
