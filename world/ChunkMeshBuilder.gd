extends RefCounted
class_name KZ_ChunkMeshBuilder

# Greedy rectangle merging per face direction.
# IMPORTANT: Vertices are emitted in CHUNK-LOCAL coordinates.
# The chunk node itself is positioned at chunk_origin_world.

static func build_mesh_arrays(
	chunk_origin_world: Vector3,
	dims: Vector3i,
	get_block_world: Callable,
	get_face_material_id: Callable,
	is_renderable_runtime: Callable,
	face_occludes_neighbor: Callable,
	max_mesh_y: int = -1
) -> Dictionary:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	var index_base: int = 0

	if max_mesh_y < 0:
		max_mesh_y = dims.y - 1
	max_mesh_y = clampi(max_mesh_y, 0, dims.y - 1)

	index_base = _mesh_dir(0, +1, chunk_origin_world, dims, get_block_world, get_face_material_id, is_renderable_runtime, face_occludes_neighbor, max_mesh_y,
		vertices, normals, uvs, colors, indices, index_base)
	index_base = _mesh_dir(0, -1, chunk_origin_world, dims, get_block_world, get_face_material_id, is_renderable_runtime, face_occludes_neighbor, max_mesh_y,
		vertices, normals, uvs, colors, indices, index_base)

	index_base = _mesh_dir(1, +1, chunk_origin_world, dims, get_block_world, get_face_material_id, is_renderable_runtime, face_occludes_neighbor, max_mesh_y,
		vertices, normals, uvs, colors, indices, index_base)
	index_base = _mesh_dir(1, -1, chunk_origin_world, dims, get_block_world, get_face_material_id, is_renderable_runtime, face_occludes_neighbor, max_mesh_y,
		vertices, normals, uvs, colors, indices, index_base)

	index_base = _mesh_dir(2, +1, chunk_origin_world, dims, get_block_world, get_face_material_id, is_renderable_runtime, face_occludes_neighbor, max_mesh_y,
		vertices, normals, uvs, colors, indices, index_base)
	index_base = _mesh_dir(2, -1, chunk_origin_world, dims, get_block_world, get_face_material_id, is_renderable_runtime, face_occludes_neighbor, max_mesh_y,
		vertices, normals, uvs, colors, indices, index_base)

	return {
		"vertices": vertices,
		"normals": normals,
		"uvs": uvs,
		"colors": colors,
		"indices": indices
	}

static func _mesh_dir(
	axis: int,
	dir: int,
	chunk_origin_world: Vector3,
	dims: Vector3i,
	get_block_world: Callable,
	get_face_material_id: Callable,
	is_renderable_runtime: Callable,
	face_occludes_neighbor: Callable,
	max_mesh_y: int,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	index_base: int
) -> int:
	var sx: int = dims.x
	var sz: int = dims.z

	var u_size: int
	var v_size: int

	# axis X: u=Z, v=Y, slices over X
	# axis Y: u=X, v=Z, slices over Y
	# axis Z: u=X, v=Y, slices over Z
	if axis == 0:
		u_size = sz
		v_size = max_mesh_y + 1
	elif axis == 1:
		u_size = sx
		v_size = sz
	else:
		u_size = sx
		v_size = max_mesh_y + 1

	var mask := PackedInt32Array()
	mask.resize(u_size * v_size)

	var slice_count: int = sx if axis == 0 else ((max_mesh_y + 1) if axis == 1 else sz)

	for s in range(slice_count):
		for v in range(v_size):
			for u in range(u_size):
				var bx: int
				var by: int
				var bz: int

				if axis == 0:
					bx = s
					by = v
					bz = u
				elif axis == 1:
					by = s
					bx = u
					bz = v
				else:
					bz = s
					by = v
					bx = u

				var wx: int = int(chunk_origin_world.x) + bx
				var wy: int = int(chunk_origin_world.y) + by
				var wz: int = int(chunk_origin_world.z) + bz

				var a: int = int(get_block_world.call(wx, wy, wz))
				if not bool(is_renderable_runtime.call(a)):
					mask[u + v * u_size] = 0
					continue

				var nx: int = wx
				var ny: int = wy
				var nz: int = wz
				if axis == 0:
					nx = wx + dir
				elif axis == 1:
					ny = wy + dir
				else:
					nz = wz + dir

				var b: int = int(get_block_world.call(nx, ny, nz))
				var visible: bool = not bool(face_occludes_neighbor.call(a, b, axis, dir))
				mask[u + v * u_size] = a if visible else 0

		var v0: int = 0
		while v0 < v_size:
			var u0: int = 0
			while u0 < u_size:
				var rid: int = mask[u0 + v0 * u_size]
				if rid == 0:
					u0 += 1
					continue

				var no_merge: bool = int(get_face_material_id.call(rid, axis, dir)) == 5

				var w: int = 1
				if not no_merge:
					while (u0 + w) < u_size and mask[(u0 + w) + v0 * u_size] == rid:
						w += 1

				var h: int = 1
				if not no_merge:
					while (v0 + h) < v_size:
						var ok: bool = true
						for k in range(w):
							if mask[(u0 + k) + (v0 + h) * u_size] != rid:
								ok = false
								break
						if not ok:
							break
						h += 1

				index_base = _emit_quad(axis, dir, s, u0, v0, w, h, dims, rid,
					get_face_material_id, vertices, normals, uvs, colors, indices, index_base)

				for vv in range(h):
					for uu in range(w):
						mask[(u0 + uu) + (v0 + vv) * u_size] = 0

				u0 += w
			v0 += 1

	return index_base

static func _emit_quad(
	axis: int,
	dir: int,
	slice_index: int,
	u0: int,
	v0: int,
	w: int,
	h: int,
	_dims: Vector3i,
	runtime_id: int,
	get_face_material_id: Callable,
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	uvs: PackedVector2Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	index_base: int
) -> int:
	var face_material_id: int = int(get_face_material_id.call(runtime_id, axis, dir))
	var encoded: float = clampf(float(face_material_id) / 255.0, 0.0, 1.0)
	var face_color: Color = Color(encoded, 0.0, 0.0, 1.0)

	var x0: int = 0
	var x1: int = 0
	var y0: int = 0
	var y1: int = 0
	var z0: int = 0
	var z1: int = 0

	if axis == 0:
		y0 = v0
		y1 = v0 + h
		z0 = u0
		z1 = u0 + w
		x0 = slice_index + 1 if dir == +1 else slice_index
		x1 = x0
	elif axis == 1:
		x0 = u0
		x1 = u0 + w
		z0 = v0
		z1 = v0 + h
		y0 = slice_index + 1 if dir == +1 else slice_index
		y1 = y0
	else:
		x0 = u0
		x1 = u0 + w
		y0 = v0
		y1 = v0 + h
		z0 = slice_index + 1 if dir == +1 else slice_index
		z1 = z0

	var p0: Vector3
	var p1: Vector3
	var p2: Vector3
	var p3: Vector3
	var n: Vector3

	if axis == 0 and dir == +1:
		p0 = Vector3(x0, y0, z0); p1 = Vector3(x0, y1, z0); p2 = Vector3(x0, y1, z1); p3 = Vector3(x0, y0, z1)
		n = Vector3(1, 0, 0)
	elif axis == 0 and dir == -1:
		p0 = Vector3(x0, y0, z0); p1 = Vector3(x0, y0, z1); p2 = Vector3(x0, y1, z1); p3 = Vector3(x0, y1, z0)
		n = Vector3(-1, 0, 0)
	elif axis == 1 and dir == +1:
		p0 = Vector3(x0, y0, z0); p1 = Vector3(x0, y0, z1); p2 = Vector3(x1, y0, z1); p3 = Vector3(x1, y0, z0)
		n = Vector3(0, 1, 0)
	elif axis == 1 and dir == -1:
		p0 = Vector3(x0, y0, z0); p1 = Vector3(x1, y0, z0); p2 = Vector3(x1, y0, z1); p3 = Vector3(x0, y0, z1)
		n = Vector3(0, -1, 0)
	elif axis == 2 and dir == +1:
		p0 = Vector3(x0, y0, z0); p1 = Vector3(x1, y0, z0); p2 = Vector3(x1, y1, z0); p3 = Vector3(x0, y1, z0)
		n = Vector3(0, 0, 1)
	else:
		p0 = Vector3(x0, y0, z0); p1 = Vector3(x0, y1, z0); p2 = Vector3(x1, y1, z0); p3 = Vector3(x1, y0, z0)
		n = Vector3(0, 0, -1)

	var tri_n: Vector3 = (p1 - p0).cross(p2 - p0)
	if tri_n.dot(n) < 0.0:
		var tmp: Vector3 = p1
		p1 = p3
		p3 = tmp

	var i0: int = index_base
	var i1: int = index_base + 1
	var i2: int = index_base + 2
	var i3: int = index_base + 3

	vertices.append(p0); vertices.append(p1); vertices.append(p2); vertices.append(p3)
	normals.append(n); normals.append(n); normals.append(n); normals.append(n)

	var quad_points: Array[Vector3] = [p0, p1, p2, p3]
	for p in quad_points:
		uvs.append(_face_uv_for_point(axis, dir, p, x0, x1, y0, y1, z0, z1))

	colors.append(face_color); colors.append(face_color); colors.append(face_color); colors.append(face_color)

	indices.append(i0); indices.append(i1); indices.append(i2)
	indices.append(i0); indices.append(i2); indices.append(i3)

	return index_base + 4

static func _face_uv_for_point(
	axis: int,
	dir: int,
	p: Vector3,
	x0: int,
	x1: int,
	_y0: int,
	y1: int,
	z0: int,
	z1: int
) -> Vector2:
	if axis == 0:
		if dir == +1:
			return Vector2(p.z - float(z0), float(y1) - p.y)
		return Vector2(float(z1) - p.z, float(y1) - p.y)
	if axis == 1:
		if dir == +1:
			return Vector2(p.x - float(x0), p.z - float(z0))
		return Vector2(p.x - float(x0), float(z1) - p.z)
	if dir == +1:
		return Vector2(float(x1) - p.x, float(y1) - p.y)
	return Vector2(p.x - float(x0), float(y1) - p.y)
