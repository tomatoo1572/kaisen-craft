extends Button
class_name KZ_SlotButton

var slot_global: int = -1

var _border: Panel
var _icon_root: Control
var _fallback: ColorRect
var _flat_sprite: Sprite2D
var _cube_root: Node2D
var _cube_top: Polygon2D
var _cube_left: Polygon2D
var _cube_right: Polygon2D
var _count_label: Label

func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	text = ""
	flat = true
	custom_minimum_size = Vector2(52, 52)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER

	_border = Panel.new()
	_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_border.anchor_left = 0.0
	_border.anchor_top = 0.0
	_border.anchor_right = 1.0
	_border.anchor_bottom = 1.0
	add_child(_border)

	_icon_root = Control.new()
	_icon_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_root.anchor_left = 0.0
	_icon_root.anchor_top = 0.0
	_icon_root.anchor_right = 1.0
	_icon_root.anchor_bottom = 1.0
	_border.add_child(_icon_root)

	_fallback = ColorRect.new()
	_fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fallback.anchor_left = 0.20
	_fallback.anchor_top = 0.20
	_fallback.anchor_right = 0.80
	_fallback.anchor_bottom = 0.80
	_fallback.color = Color(0, 0, 0, 0)
	_icon_root.add_child(_fallback)

	_flat_sprite = Sprite2D.new()
	_flat_sprite.centered = true
	_flat_sprite.position = Vector2(26, 30)
	_flat_sprite.rotation_degrees = -28.0
	_flat_sprite.scale = Vector2(1.05, 1.05)
	_flat_sprite.visible = false
	_icon_root.add_child(_flat_sprite)

	_cube_root = Node2D.new()
	_cube_root.position = Vector2(26, 31)
	_cube_root.visible = false
	_icon_root.add_child(_cube_root)

	_cube_top = Polygon2D.new()
	_cube_top.polygon = PackedVector2Array([
		Vector2(0, -16), Vector2(15, -8), Vector2(0, 0), Vector2(-15, -8)
	])
	_cube_top.uv = PackedVector2Array([
		Vector2(0.5, 0.0), Vector2(1.0, 0.5), Vector2(0.5, 1.0), Vector2(0.0, 0.5)
	])
	_cube_root.add_child(_cube_top)

	_cube_left = Polygon2D.new()
	_cube_left.polygon = PackedVector2Array([
		Vector2(-15, -8), Vector2(0, 0), Vector2(0, 16), Vector2(-15, 8)
	])
	_cube_left.uv = PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)
	])
	_cube_root.add_child(_cube_left)

	_cube_right = Polygon2D.new()
	_cube_right.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(15, -8), Vector2(15, 8), Vector2(0, 16)
	])
	_cube_right.uv = PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)
	])
	_cube_root.add_child(_cube_right)

	_count_label = Label.new()
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count_label.anchor_left = 0.0
	_count_label.anchor_top = 0.0
	_count_label.anchor_right = 1.0
	_count_label.anchor_bottom = 1.0
	_count_label.offset_left = 4
	_count_label.offset_top = 4
	_count_label.offset_right = -4
	_count_label.offset_bottom = -4
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_count_label.text = ""
	_border.add_child(_count_label)

	_update_border(false)
	_clear_preview()

func set_slot_index(g: int) -> void:
	slot_global = g

func set_visual(item_id: String, count: int, tint: Color, is_selected: bool, preview: Dictionary = {}) -> void:
	if item_id == "" or count <= 0:
		_clear_preview()
		_count_label.text = ""
	else:
		_apply_preview(preview, tint)
		_count_label.text = str(count) if count > 1 else ""
	_update_border(is_selected)

func _clear_preview() -> void:
	_fallback.visible = false
	_fallback.color = Color(0, 0, 0, 0)
	_flat_sprite.visible = false
	_flat_sprite.texture = null
	_cube_root.visible = false
	_cube_top.texture = null
	_cube_left.texture = null
	_cube_right.texture = null

func _apply_preview(preview: Dictionary, tint: Color) -> void:
	_clear_preview()
	var mode: String = str(preview.get("mode", "flat"))
	var top_tex: Texture2D = preview.get("top_tex") as Texture2D
	var side_tex: Texture2D = preview.get("side_tex") as Texture2D
	var front_tex: Texture2D = preview.get("front_tex") as Texture2D
	if mode == "block" and (side_tex != null or top_tex != null):
		if top_tex == null:
			top_tex = side_tex
		if side_tex == null:
			side_tex = top_tex
		_cube_root.visible = true
		_cube_top.texture = top_tex
		_cube_left.texture = side_tex
		_cube_right.texture = side_tex
		_cube_top.color = tint.lightened(0.18)
		_cube_left.color = tint.darkened(0.22)
		_cube_right.color = tint.darkened(0.08)
		return
	var tex: Texture2D = front_tex
	if tex == null:
		tex = side_tex if side_tex != null else top_tex
	if tex != null:
		_flat_sprite.visible = true
		_flat_sprite.texture = tex
		_flat_sprite.modulate = tint
		if tex.get_width() > 0 and tex.get_height() > 0:
			var biggest: float = float(maxi(tex.get_width(), tex.get_height()))
			var base_scale: float = 18.0 / biggest
			_flat_sprite.scale = Vector2(base_scale, base_scale)
		return
	_fallback.visible = true
	_fallback.color = tint

func _update_border(is_selected: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.35)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(1, 1, 1, 0.95) if is_selected else Color(1, 1, 1, 0.25)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	_border.add_theme_stylebox_override("panel", sb)
