extends Button
class_name KZ_SlotButton

var slot_global: int = -1

var _icon: ColorRect
var _count_label: Label
var _border: Panel

func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	text = ""
	flat = true

	# ✅ Square slot
	custom_minimum_size = Vector2(52, 52)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER

	_border = Panel.new()
	_border.anchor_left = 0.0
	_border.anchor_top = 0.0
	_border.anchor_right = 1.0
	_border.anchor_bottom = 1.0
	add_child(_border)

	_icon = ColorRect.new()
	_icon.anchor_left = 0.14
	_icon.anchor_top = 0.14
	_icon.anchor_right = 0.86
	_icon.anchor_bottom = 0.86
	_icon.color = Color(0, 0, 0, 0)
	_border.add_child(_icon)

	_count_label = Label.new()
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

func set_slot_index(g: int) -> void:
	slot_global = g

func set_visual(item_id: String, count: int, tint: Color, is_selected: bool) -> void:
	if item_id == "" or count <= 0:
		_icon.color = Color(0, 0, 0, 0)
		_count_label.text = ""
	else:
		_icon.color = tint
		_count_label.text = str(count) if count > 1 else ""
	_update_border(is_selected)

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
