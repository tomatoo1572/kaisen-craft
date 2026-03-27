extends Control
class_name KZ_BodyShapeTriangle

signal shape_changed(lean: float, athletic: float, bulky: float, width_scale: float)

var lean_weight: float = 0.33
var athletic_weight: float = 0.34
var bulky_weight: float = 0.33
var _dragging: bool = false

func _ready() -> void:
	custom_minimum_size = Vector2(250, 230)
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()

func set_weights(lean: float, athletic: float, bulky: float, emit_signal_now: bool = false) -> void:
	var total: float = maxf(0.0001, lean + athletic + bulky)
	lean_weight = clampf(lean / total, 0.0, 1.0)
	athletic_weight = clampf(athletic / total, 0.0, 1.0)
	bulky_weight = clampf(bulky / total, 0.0, 1.0)
	queue_redraw()
	if emit_signal_now:
		_emit_shape_changed()

func set_width_scale(width_scale: float) -> void:
	var t: float = clampf((width_scale - 0.82) / 0.36, 0.0, 1.0)
	var athletic: float = 0.34
	var bulky: float = clampf(t * 0.76, 0.06, 0.78)
	var lean: float = maxf(0.06, 1.0 - athletic - bulky)
	set_weights(lean, athletic, bulky, false)

func get_width_scale() -> float:
	return 0.82 + bulky_weight * 0.30 + athletic_weight * 0.06 - lean_weight * 0.06

func get_weights_array() -> Array:
	return [lean_weight, athletic_weight, bulky_weight]

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MouseButton.MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			if mb.pressed:
				_update_from_local_pos(mb.position)
	elif event is InputEventMouseMotion and _dragging:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		_update_from_local_pos(mm.position)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var tri: Array[Vector2] = _triangle_points()
	var fill_color: Color = Color(0.06, 0.10, 0.16, 0.65)
	draw_colored_polygon(PackedVector2Array(tri), fill_color)
	for i in range(1, 4):
		var inset: Array[Vector2] = _triangle_points(0.15 * float(i))
		_draw_loop(inset, Color(0.54, 0.60, 0.72, 0.33), 1.5)
	_draw_loop(tri, Color(0.95, 0.96, 0.98, 0.95), 3.0)
	var marker: Vector2 = _marker_pos()
	draw_circle(marker, 8.0, Color(0.24, 1.0, 0.24, 1.0))
	draw_circle(marker, 12.0, Color(0.24, 1.0, 0.24, 0.22))
	var font: Font = get_theme_default_font()
	var font_size: int = get_theme_default_font_size() + 2
	if font != null:
		draw_string(font, Vector2(tri[1].x - 32.0, tri[1].y - 14.0), "Athletic", HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color.WHITE)
		draw_string(font, Vector2(tri[0].x - 16.0, tri[0].y + 22.0), "Lean", HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color.WHITE)
		draw_string(font, Vector2(tri[2].x - 18.0, tri[2].y + 22.0), "Bulky", HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color.WHITE)

func _draw_loop(points: Array[Vector2], color: Color, width: float) -> void:
	for i in range(points.size()):
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % points.size()]
		draw_line(a, b, color, width, true)

func _triangle_points(inset_ratio: float = 0.0) -> Array[Vector2]:
	var pad_x: float = 24.0 + inset_ratio * 38.0
	var pad_top: float = 18.0 + inset_ratio * 30.0
	var pad_bottom: float = 28.0 + inset_ratio * 30.0
	var p0 := Vector2(pad_x, size.y - pad_bottom)
	var p1 := Vector2(size.x * 0.5, pad_top)
	var p2 := Vector2(size.x - pad_x, size.y - pad_bottom)
	return [p0, p1, p2]

func _marker_pos() -> Vector2:
	var tri: Array[Vector2] = _triangle_points()
	return tri[0] * lean_weight + tri[1] * athletic_weight + tri[2] * bulky_weight

func _update_from_local_pos(pos: Vector2) -> void:
	var tri: Array[Vector2] = _triangle_points()
	var bary: Vector3 = _clamped_barycentric(pos, tri[0], tri[1], tri[2])
	lean_weight = bary.x
	athletic_weight = bary.y
	bulky_weight = bary.z
	queue_redraw()
	_emit_shape_changed()

func _emit_shape_changed() -> void:
	emit_signal("shape_changed", lean_weight, athletic_weight, bulky_weight, get_width_scale())

func _barycentric(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> Vector3:
	var v0: Vector2 = b - a
	var v1: Vector2 = c - a
	var v2: Vector2 = p - a
	var d00: float = v0.dot(v0)
	var d01: float = v0.dot(v1)
	var d11: float = v1.dot(v1)
	var d20: float = v2.dot(v0)
	var d21: float = v2.dot(v1)
	var denom: float = d00 * d11 - d01 * d01
	if absf(denom) <= 0.00001:
		return Vector3(1.0, 0.0, 0.0)
	var v: float = (d11 * d20 - d01 * d21) / denom
	var w: float = (d00 * d21 - d01 * d20) / denom
	var u: float = 1.0 - v - w
	return Vector3(u, v, w)

func _point_in_triangle(bary: Vector3) -> bool:
	return bary.x >= 0.0 and bary.y >= 0.0 and bary.z >= 0.0 and bary.x <= 1.0 and bary.y <= 1.0 and bary.z <= 1.0

func _clamped_barycentric(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> Vector3:
	var bary: Vector3 = _barycentric(p, a, b, c)
	if _point_in_triangle(bary):
		return bary
	var ca: Vector2 = _closest_point_segment(a, b, p)
	var cb: Vector2 = _closest_point_segment(b, c, p)
	var cc: Vector2 = _closest_point_segment(c, a, p)
	var da: float = p.distance_squared_to(ca)
	var db: float = p.distance_squared_to(cb)
	var dc: float = p.distance_squared_to(cc)
	var closest: Vector2 = ca
	if db < da and db <= dc:
		closest = cb
	elif dc < da and dc < db:
		closest = cc
	var out: Vector3 = _barycentric(closest, a, b, c)
	out.x = clampf(out.x, 0.0, 1.0)
	out.y = clampf(out.y, 0.0, 1.0)
	out.z = clampf(out.z, 0.0, 1.0)
	var total: float = maxf(0.0001, out.x + out.y + out.z)
	return out / total

func _closest_point_segment(a: Vector2, b: Vector2, p: Vector2) -> Vector2:
	var ab: Vector2 = b - a
	var denom: float = maxf(0.00001, ab.dot(ab))
	var t: float = clampf((p - a).dot(ab) / denom, 0.0, 1.0)
	return a + ab * t
