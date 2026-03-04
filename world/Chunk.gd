extends Node3D
class_name KZ_Chunk

var chunk_pos: Vector2i
var mesh_instance: MeshInstance3D

func _init() -> void:
	mesh_instance = MeshInstance3D.new()
	add_child(mesh_instance)

func set_chunk_pos(p: Vector2i) -> void:
	chunk_pos = p

func set_mesh(m: Mesh) -> void:
	mesh_instance.mesh = m
