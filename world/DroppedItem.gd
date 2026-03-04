extends Node3D
class_name KZ_DroppedItem

var lifetime_sec: float = 20.0
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

func setup(color: Color) -> void:
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
	if _age >= lifetime_sec:
		queue_free()
