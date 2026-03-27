extends VBoxContainer
class_name KZ_HairEditorPanel

signal hair_data_changed(hair_data: Dictionary, preset_id: String)
signal hair_color_changed(color: Color)

var hair_color_button: ColorPickerButton
var preset_option: OptionButton
var side_buttons: Dictionary = {}
var slot_option: OptionButton
var enabled_check: CheckBox
var save_name_edit: LineEdit
var saved_option: OptionButton
var status_label: Label
var code_dialog: AcceptDialog
var code_text: TextEdit
var _code_mode: String = ""

var _current_preset_id: String = "soft_messy"
var _current_hair_data: Dictionary = {}
var _selected_side: String = "front"
var _selected_slot_index: int = 0
var _updating: bool = false
var _slider_controls: Dictionary = {}

func _ready() -> void:
	if get_child_count() == 0:
		_build_ui()
	if _current_hair_data.is_empty():
		_current_hair_data = KZ_HairStyleLibrary.build_preset(_current_preset_id)
	_refresh_ui()
	_refresh_saved_option_list()

func setup_from_profile(profile: Dictionary) -> void:
	_current_preset_id = KZ_HairStyleLibrary.preset_id_from_legacy(str(profile.get("hair_preset_id", profile.get("hair_style", "soft_messy"))))
	var hair_data_v: Variant = profile.get("hair_data", {})
	if hair_data_v is Dictionary and not (hair_data_v as Dictionary).is_empty():
		_current_hair_data = KZ_HairStyleLibrary.ensure_hair_data(hair_data_v)
	else:
		_current_hair_data = KZ_HairStyleLibrary.build_preset(_current_preset_id)
	if hair_color_button != null:
		hair_color_button.color = _dict_color(profile.get("hair_color", [0.08, 0.08, 0.10, 1.0]), Color(0.08, 0.08, 0.10, 1.0))
	_ensure_valid_selection()
	_refresh_ui()
	_refresh_saved_option_list()

func get_current_hair_data() -> Dictionary:
	return KZ_HairStyleLibrary.ensure_hair_data(_current_hair_data)

func get_current_preset_id() -> String:
	return _current_preset_id

func get_current_hair_color() -> Color:
	return hair_color_button.color if hair_color_button != null else Color(0.08, 0.08, 0.10, 1.0)

func _build_ui() -> void:
	add_theme_constant_override("separation", 8)

	var preset_row := HBoxContainer.new()
	preset_row.add_theme_constant_override("separation", 8)
	add_child(preset_row)
	var preset_label := Label.new()
	preset_label.text = "Hair Preset"
	preset_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preset_row.add_child(preset_label)
	preset_option = OptionButton.new()
	var display: Dictionary = KZ_HairStyleLibrary.preset_display_names()
	for preset_id in KZ_HairStyleLibrary.preset_ids():
		preset_option.add_item(str(display.get(preset_id, preset_id.capitalize())))
	preset_option.item_selected.connect(Callable(self, "_on_preset_selected"))
	preset_row.add_child(preset_option)

	var color_row := HBoxContainer.new()
	color_row.add_theme_constant_override("separation", 8)
	add_child(color_row)
	var color_label := Label.new()
	color_label.text = "Hair Color"
	color_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color_row.add_child(color_label)
	hair_color_button = ColorPickerButton.new()
	hair_color_button.custom_minimum_size = Vector2(92, 32)
	hair_color_button.color_changed.connect(Callable(self, "_on_hair_color_changed"))
	color_row.add_child(hair_color_button)

	var side_label := Label.new()
	side_label.text = "Edit Region"
	add_child(side_label)
	var side_row := HBoxContainer.new()
	side_row.add_theme_constant_override("separation", 6)
	add_child(side_row)
	for side in KZ_HairStyleLibrary.SIDE_NAMES:
		var button := Button.new()
		button.text = side.capitalize()
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(Callable(self, "_on_side_button_pressed").bind(side))
		side_row.add_child(button)
		side_buttons[side] = button

	var slot_row := HBoxContainer.new()
	slot_row.add_theme_constant_override("separation", 6)
	add_child(slot_row)
	var slot_label := Label.new()
	slot_label.text = "Strand Slot"
	slot_row.add_child(slot_label)
	slot_option = OptionButton.new()
	slot_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_option.item_selected.connect(Callable(self, "_on_slot_selected"))
	slot_row.add_child(slot_option)
	var add_btn := Button.new()
	add_btn.text = "+"
	add_btn.tooltip_text = "Add strand"
	add_btn.pressed.connect(Callable(self, "_on_add_slot_pressed"))
	slot_row.add_child(add_btn)
	var dup_btn := Button.new()
	dup_btn.text = "Dup"
	dup_btn.tooltip_text = "Duplicate selected strand"
	dup_btn.pressed.connect(Callable(self, "_on_duplicate_slot_pressed"))
	slot_row.add_child(dup_btn)
	var del_btn := Button.new()
	del_btn.text = "-"
	del_btn.tooltip_text = "Delete selected strand"
	del_btn.pressed.connect(Callable(self, "_on_delete_slot_pressed"))
	slot_row.add_child(del_btn)

	enabled_check = CheckBox.new()
	enabled_check.text = "Enabled"
	enabled_check.toggled.connect(Callable(self, "_on_enabled_toggled"))
	add_child(enabled_check)

	var props_grid := GridContainer.new()
	props_grid.columns = 2
	props_grid.add_theme_constant_override("h_separation", 8)
	props_grid.add_theme_constant_override("v_separation", 6)
	add_child(props_grid)

	_add_slider(props_grid, "Width", "width", 0.04, 0.55, 0.01)
	_add_slider(props_grid, "Length", "length", 0.06, 1.30, 0.01)
	_add_slider(props_grid, "Depth", "depth", 0.03, 0.50, 0.01)
	_add_slider(props_grid, "Bend", "bend", -1.0, 1.0, 0.01)
	_add_slider(props_grid, "Offset X", "offset_x", -0.40, 0.40, 0.01)
	_add_slider(props_grid, "Offset Y", "offset_y", -0.25, 0.40, 0.01)
	_add_slider(props_grid, "Offset Z", "offset_z", -0.40, 0.40, 0.01)
	_add_slider(props_grid, "Rot X", "rot_x", -90.0, 90.0, 1.0)
	_add_slider(props_grid, "Rot Y", "rot_y", -90.0, 90.0, 1.0)
	_add_slider(props_grid, "Rot Z", "rot_z", -90.0, 90.0, 1.0)
	_add_slider(props_grid, "Taper", "taper", 0.0, 1.0, 0.01)
	_add_slider(props_grid, "Sway", "sway", 0.0, 1.0, 0.01)

	var storage_title := Label.new()
	storage_title.text = "Save / Load"
	add_child(storage_title)

	var save_row := HBoxContainer.new()
	save_row.add_theme_constant_override("separation", 6)
	add_child(save_row)
	save_name_edit = LineEdit.new()
	save_name_edit.placeholder_text = "preset_name"
	save_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_row.add_child(save_name_edit)
	var save_btn := Button.new()
	save_btn.text = "Save Preset"
	save_btn.pressed.connect(Callable(self, "_on_save_preset_pressed"))
	save_row.add_child(save_btn)

	var load_row := HBoxContainer.new()
	load_row.add_theme_constant_override("separation", 6)
	add_child(load_row)
	saved_option = OptionButton.new()
	saved_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_row.add_child(saved_option)
	var load_btn := Button.new()
	load_btn.text = "Load Saved"
	load_btn.pressed.connect(Callable(self, "_on_load_saved_pressed"))
	load_row.add_child(load_btn)

	var code_row := HBoxContainer.new()
	code_row.add_theme_constant_override("separation", 6)
	add_child(code_row)
	var export_btn := Button.new()
	export_btn.text = "Export Hair Code"
	export_btn.pressed.connect(Callable(self, "_on_export_code_pressed"))
	code_row.add_child(export_btn)
	var import_btn := Button.new()
	import_btn.text = "Import Hair Code"
	import_btn.pressed.connect(Callable(self, "_on_import_code_pressed"))
	code_row.add_child(import_btn)
	var reset_btn := Button.new()
	reset_btn.text = "Reset Hair"
	reset_btn.pressed.connect(Callable(self, "_on_reset_pressed"))
	code_row.add_child(reset_btn)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.text = "Build hair from editable block strands. Each side has its own slots and live updates the character preview."
	add_child(status_label)

	code_dialog = AcceptDialog.new()
	code_dialog.title = "Hair Code"
	code_dialog.confirmed.connect(Callable(self, "_on_code_dialog_confirmed"))
	add_child(code_dialog)
	code_text = TextEdit.new()
	code_text.custom_minimum_size = Vector2(520, 220)
	code_dialog.add_child(code_text)

func _add_slider(parent: GridContainer, label_text: String, key: String, min_value: float, max_value: float, step_value: float) -> void:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 2)
	parent.add_child(wrap)
	var head := HBoxContainer.new()
	wrap.add_child(head)
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(label)
	var value_label := Label.new()
	value_label.text = "0"
	head.add_child(value_label)
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step_value
	slider.value_changed.connect(Callable(self, "_on_slider_changed").bind(key))
	wrap.add_child(slider)
	_slider_controls[key] = {"slider": slider, "value_label": value_label}

func _refresh_ui() -> void:
	_updating = true
	_refresh_preset_selection()
	_refresh_side_buttons()
	_refresh_slot_option()
	_refresh_strand_controls()
	_updating = false

func _refresh_preset_selection() -> void:
	if preset_option == null:
		return
	var ids: Array[String] = KZ_HairStyleLibrary.preset_ids()
	var idx: int = max(ids.find(_current_preset_id), 0)
	preset_option.select(idx)

func _refresh_side_buttons() -> void:
	for side in side_buttons.keys():
		var button: Button = side_buttons[side] as Button
		if button != null:
			button.button_pressed = side == _selected_side

func _refresh_slot_option() -> void:
	if slot_option == null:
		return
	slot_option.clear()
	var strands: Array = _side_slots(_selected_side)
	for i in range(strands.size()):
		slot_option.add_item("%s %d" % [_selected_side.capitalize(), i + 1])
	if strands.is_empty():
		slot_option.add_item("No strands")
		slot_option.disabled = true
		_selected_slot_index = 0
	else:
		slot_option.disabled = false
		_selected_slot_index = clampi(_selected_slot_index, 0, strands.size() - 1)
		slot_option.select(_selected_slot_index)

func _refresh_strand_controls() -> void:
	var strand: Dictionary = _selected_strand_data()
	var has_strand: bool = not strand.is_empty()
	enabled_check.disabled = not has_strand
	enabled_check.button_pressed = bool(strand.get("enabled", true)) if has_strand else false
	_set_slider_value("width", float(strand.get("width", 0.18)), has_strand)
	_set_slider_value("length", float(strand.get("length", 0.42)), has_strand)
	_set_slider_value("depth", float(strand.get("depth", 0.14)), has_strand)
	_set_slider_value("bend", float(strand.get("bend", 0.18)), has_strand)
	var offset: Vector3 = _strand_offset_vec(strand)
	_set_slider_value("offset_x", offset.x, has_strand)
	_set_slider_value("offset_y", offset.y, has_strand)
	_set_slider_value("offset_z", offset.z, has_strand)
	var rot: Vector3 = _strand_rot_vec(strand)
	_set_slider_value("rot_x", rot.x, has_strand)
	_set_slider_value("rot_y", rot.y, has_strand)
	_set_slider_value("rot_z", rot.z, has_strand)
	_set_slider_value("taper", float(strand.get("taper", 0.22)), has_strand)
	_set_slider_value("sway", float(strand.get("sway", 0.08)), has_strand)

func _set_slider_value(key: String, value: float, enabled: bool) -> void:
	if not _slider_controls.has(key):
		return
	var data: Dictionary = _slider_controls[key] as Dictionary
	var slider: HSlider = data.get("slider") as HSlider
	var label: Label = data.get("value_label") as Label
	if slider != null:
		slider.editable = enabled
		slider.set_value_no_signal(value)
	if label != null:
		label.text = "%.2f" % value

func _ensure_valid_selection() -> void:
	if _selected_side not in KZ_HairStyleLibrary.SIDE_NAMES:
		_selected_side = "front"
	var strands: Array = _side_slots(_selected_side)
	if strands.is_empty():
		_selected_slot_index = 0
	else:
		_selected_slot_index = clampi(_selected_slot_index, 0, strands.size() - 1)

func _side_slots(side: String) -> Array:
	var normalized: Dictionary = KZ_HairStyleLibrary.ensure_hair_data(_current_hair_data)
	_current_hair_data = normalized
	var sides: Dictionary = normalized.get("sides", {}) as Dictionary
	var slots_v: Variant = sides.get(side, [])
	return slots_v as Array

func _selected_strand_data() -> Dictionary:
	var strands: Array = _side_slots(_selected_side)
	if strands.is_empty() or _selected_slot_index < 0 or _selected_slot_index >= strands.size():
		return {}
	var strand_v: Variant = strands[_selected_slot_index]
	if strand_v is Dictionary:
		return strand_v as Dictionary
	return {}

func _write_selected_strand(strand: Dictionary) -> void:
	var normalized: Dictionary = KZ_HairStyleLibrary.ensure_hair_data(_current_hair_data)
	var sides: Dictionary = normalized.get("sides", {}) as Dictionary
	var strands: Array = sides.get(_selected_side, []) as Array
	if strands.is_empty() or _selected_slot_index < 0 or _selected_slot_index >= strands.size():
		return
	var clean_wrapper: Dictionary = KZ_HairStyleLibrary.ensure_hair_data({"sides": {_selected_side: [strand]}})
	var clean_sides: Dictionary = clean_wrapper.get("sides", {}) as Dictionary
	var clean_list: Array = clean_sides.get(_selected_side, []) as Array
	var clean_strand: Dictionary = strand
	if not clean_list.is_empty() and clean_list[0] is Dictionary:
		clean_strand = clean_list[0] as Dictionary
	strands[_selected_slot_index] = clean_strand
	sides[_selected_side] = strands
	normalized["sides"] = sides
	_current_hair_data = normalized

func _emit_data_changed() -> void:
	emit_signal("hair_data_changed", get_current_hair_data(), _current_preset_id)

func _on_preset_selected(idx: int) -> void:
	if _updating:
		return
	var ids: Array[String] = KZ_HairStyleLibrary.preset_ids()
	if idx < 0 or idx >= ids.size():
		return
	_current_preset_id = ids[idx]
	_current_hair_data = KZ_HairStyleLibrary.build_preset(_current_preset_id)
	_selected_side = "front"
	_selected_slot_index = 0
	_refresh_ui()
	_emit_data_changed()
	status_label.text = "Preset applied: %s" % str(KZ_HairStyleLibrary.preset_display_names().get(_current_preset_id, _current_preset_id))

func _on_hair_color_changed(color: Color) -> void:
	if _updating:
		return
	emit_signal("hair_color_changed", color)

func _on_side_button_pressed(side: String) -> void:
	if _updating:
		return
	_selected_side = side
	_selected_slot_index = 0
	_refresh_ui()

func _on_slot_selected(idx: int) -> void:
	if _updating:
		return
	_selected_slot_index = idx
	_refresh_strand_controls()

func _on_add_slot_pressed() -> void:
	var normalized: Dictionary = KZ_HairStyleLibrary.ensure_hair_data(_current_hair_data)
	var sides: Dictionary = normalized.get("sides", {}) as Dictionary
	var strands: Array = sides.get(_selected_side, []) as Array
	strands.append(KZ_HairStyleLibrary.make_strand())
	sides[_selected_side] = strands
	normalized["sides"] = sides
	_current_hair_data = normalized
	_current_preset_id = "custom"
	_selected_slot_index = strands.size() - 1
	_refresh_ui()
	_emit_data_changed()

func _on_duplicate_slot_pressed() -> void:
	var strand: Dictionary = _selected_strand_data()
	if strand.is_empty():
		return
	var normalized: Dictionary = KZ_HairStyleLibrary.ensure_hair_data(_current_hair_data)
	var sides: Dictionary = normalized.get("sides", {}) as Dictionary
	var strands: Array = sides.get(_selected_side, []) as Array
	var clean_wrapper: Dictionary = KZ_HairStyleLibrary.ensure_hair_data({"sides": {_selected_side: [strand]}})
	var clean_sides: Dictionary = clean_wrapper.get("sides", {}) as Dictionary
	var clean_list: Array = clean_sides.get(_selected_side, []) as Array
	var copy_strand: Dictionary = strand
	if not clean_list.is_empty() and clean_list[0] is Dictionary:
		copy_strand = clean_list[0] as Dictionary
	strands.insert(_selected_slot_index + 1, copy_strand)
	sides[_selected_side] = strands
	normalized["sides"] = sides
	_current_hair_data = normalized
	_current_preset_id = "custom"
	_selected_slot_index += 1
	_refresh_ui()
	_emit_data_changed()

func _on_delete_slot_pressed() -> void:
	var normalized: Dictionary = KZ_HairStyleLibrary.ensure_hair_data(_current_hair_data)
	var sides: Dictionary = normalized.get("sides", {}) as Dictionary
	var strands: Array = sides.get(_selected_side, []) as Array
	if strands.is_empty():
		return
	strands.remove_at(_selected_slot_index)
	sides[_selected_side] = strands
	normalized["sides"] = sides
	_current_hair_data = normalized
	_current_preset_id = "custom"
	_selected_slot_index = clampi(_selected_slot_index, 0, max(0, strands.size() - 1))
	_refresh_ui()
	_emit_data_changed()

func _on_enabled_toggled(pressed: bool) -> void:
	if _updating:
		return
	var strand: Dictionary = _selected_strand_data()
	if strand.is_empty():
		return
	strand["enabled"] = pressed
	_current_preset_id = "custom"
	_write_selected_strand(strand)
	_emit_data_changed()

func _on_slider_changed(value: float, key: String) -> void:
	if _updating:
		return
	if _slider_controls.has(key):
		var data: Dictionary = _slider_controls[key] as Dictionary
		var label: Label = data.get("value_label") as Label
		if label != null:
			label.text = "%.2f" % value
	var strand: Dictionary = _selected_strand_data()
	if strand.is_empty():
		return
	var offset: Vector3 = _strand_offset_vec(strand)
	var rot: Vector3 = _strand_rot_vec(strand)
	match key:
		"width", "length", "depth", "bend", "taper", "sway":
			strand[key] = value
		"offset_x":
			offset.x = value
			strand["offset"] = [offset.x, offset.y, offset.z]
		"offset_y":
			offset.y = value
			strand["offset"] = [offset.x, offset.y, offset.z]
		"offset_z":
			offset.z = value
			strand["offset"] = [offset.x, offset.y, offset.z]
		"rot_x":
			rot.x = value
			strand["rotation"] = [rot.x, rot.y, rot.z]
		"rot_y":
			rot.y = value
			strand["rotation"] = [rot.x, rot.y, rot.z]
		"rot_z":
			rot.z = value
			strand["rotation"] = [rot.x, rot.y, rot.z]
	_current_preset_id = "custom"
	_write_selected_strand(strand)
	_emit_data_changed()

func _on_save_preset_pressed() -> void:
	var name_value: String = save_name_edit.text.strip_edges()
	if name_value == "":
		status_label.text = "Type a preset name before saving."
		return
	if KZ_HairCodec.save_named_preset(name_value, get_current_hair_data()):
		status_label.text = "Saved preset: %s" % name_value
		_refresh_saved_option_list(name_value)
	else:
		status_label.text = "Could not save preset."

func _on_load_saved_pressed() -> void:
	if saved_option == null or saved_option.item_count == 0:
		status_label.text = "No saved presets found yet."
		return
	var preset_name: String = saved_option.get_item_text(saved_option.selected)
	var loaded: Dictionary = KZ_HairCodec.load_named_preset(preset_name)
	_current_hair_data = loaded
	_current_preset_id = preset_name
	_selected_side = "front"
	_selected_slot_index = 0
	_refresh_ui()
	_emit_data_changed()
	status_label.text = "Loaded saved preset: %s" % preset_name

func _on_export_code_pressed() -> void:
	_code_mode = "export"
	code_dialog.title = "Export Hair Code"
	code_text.editable = false
	code_text.text = KZ_HairCodec.encode_hair_data(get_current_hair_data())
	code_dialog.popup_centered_ratio(0.62)

func _on_import_code_pressed() -> void:
	_code_mode = "import"
	code_dialog.title = "Import Hair Code"
	code_text.editable = true
	code_text.text = ""
	code_dialog.popup_centered_ratio(0.62)

func _on_reset_pressed() -> void:
	_current_hair_data = KZ_HairStyleLibrary.build_preset(_current_preset_id)
	_selected_side = "front"
	_selected_slot_index = 0
	_refresh_ui()
	_emit_data_changed()
	status_label.text = "Hair reset to current preset foundation."

func _on_code_dialog_confirmed() -> void:
	if _code_mode != "import":
		return
	var decoded: Dictionary = KZ_HairCodec.decode_hair_code(code_text.text)
	_current_hair_data = decoded
	_current_preset_id = "custom"
	_selected_side = "front"
	_selected_slot_index = 0
	_refresh_ui()
	_emit_data_changed()
	status_label.text = "Hair code imported."

func _refresh_saved_option_list(select_name: String = "") -> void:
	if saved_option == null:
		return
	saved_option.clear()
	var names: Array[String] = KZ_HairCodec.list_saved_presets()
	for entry in names:
		saved_option.add_item(entry)
	if names.is_empty():
		saved_option.add_item("No saved presets")
		saved_option.disabled = true
	else:
		saved_option.disabled = false
		var idx: int = 0
		if select_name != "":
			var found: int = names.find(select_name.to_lower())
			if found >= 0:
				idx = found
		saved_option.select(idx)

func _strand_offset_vec(strand: Dictionary) -> Vector3:
	var arr: Array = strand.get("offset", [0.0, 0.0, 0.0]) as Array
	return Vector3(
		float(arr[0]) if arr.size() > 0 else 0.0,
		float(arr[1]) if arr.size() > 1 else 0.0,
		float(arr[2]) if arr.size() > 2 else 0.0
	)

func _strand_rot_vec(strand: Dictionary) -> Vector3:
	var arr: Array = strand.get("rotation", [0.0, 0.0, 0.0]) as Array
	return Vector3(
		float(arr[0]) if arr.size() > 0 else 0.0,
		float(arr[1]) if arr.size() > 1 else 0.0,
		float(arr[2]) if arr.size() > 2 else 0.0
	)

func _dict_color(v: Variant, fallback: Color) -> Color:
	if v is Color:
		return v
	if v is Array:
		var arr: Array = v as Array
		if arr.size() >= 4:
			return Color(float(arr[0]), float(arr[1]), float(arr[2]), float(arr[3]))
		if arr.size() >= 3:
			return Color(float(arr[0]), float(arr[1]), float(arr[2]), 1.0)
	return fallback
