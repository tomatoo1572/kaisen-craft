extends Node
class_name KZ_MainMenu

var canvas: CanvasLayer
var root_control: Control
var main_panel: PanelContainer
var singleplayer_panel: PanelContainer
var create_world_panel: PanelContainer
var multiplayer_panel: PanelContainer

var status_label: Label
var worlds_list: ItemList
var world_info_label: Label
var create_world_name_edit: LineEdit
var create_seed_edit: LineEdit
var delete_world_button: Button
var _busy_overlay: ColorRect
var _busy_label: Label
var _busy: bool = false

func _ready() -> void:
	_build_ui()
	show_menu()

func _build_ui() -> void:
	canvas = CanvasLayer.new()
	add_child(canvas)

	root_control = Control.new()
	root_control.anchor_right = 1.0
	root_control.anchor_bottom = 1.0
	canvas.add_child(root_control)

	var bg := ColorRect.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color(0.05, 0.055, 0.08, 1.0)
	root_control.add_child(bg)

	var left_glow := ColorRect.new()
	left_glow.anchor_top = 0.0
	left_glow.anchor_bottom = 1.0
	left_glow.offset_left = 0
	left_glow.offset_right = 240
	left_glow.color = Color(0.13, 0.06, 0.08, 0.22)
	root_control.add_child(left_glow)

	var right_glow := ColorRect.new()
	right_glow.anchor_left = 1.0
	right_glow.anchor_right = 1.0
	right_glow.anchor_top = 0.0
	right_glow.anchor_bottom = 1.0
	right_glow.offset_left = -240
	right_glow.offset_right = 0
	right_glow.color = Color(0.08, 0.06, 0.13, 0.18)
	root_control.add_child(right_glow)

	var top_bar := ColorRect.new()
	top_bar.anchor_right = 1.0
	top_bar.offset_bottom = 84
	top_bar.color = Color(0.08, 0.085, 0.12, 0.95)
	root_control.add_child(top_bar)

	var accent_line := ColorRect.new()
	accent_line.anchor_right = 1.0
	accent_line.offset_top = 84
	accent_line.offset_bottom = 88
	accent_line.color = Color(0.64, 0.18, 0.24, 0.95)
	root_control.add_child(accent_line)

	var version_label := Label.new()
	version_label.text = "KAISENCRAFT 0.0.1"
	version_label.anchor_left = 0.5
	version_label.anchor_right = 0.5
	version_label.offset_left = -180
	version_label.offset_right = 180
	version_label.offset_top = 18
	version_label.offset_bottom = 44
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	version_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.96, 0.94))
	version_label.add_theme_font_size_override("font_size", 22)
	root_control.add_child(version_label)

	var subtitle := Label.new()
	subtitle.text = "JJK-inspired voxel sandbox prototype"
	subtitle.anchor_left = 0.5
	subtitle.anchor_right = 0.5
	subtitle.offset_left = -240
	subtitle.offset_right = 240
	subtitle.offset_top = 44
	subtitle.offset_bottom = 68
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.72, 0.74, 0.82, 0.88))
	root_control.add_child(subtitle)

	main_panel = _make_center_panel(Vector2(460, 300))
	root_control.add_child(main_panel)
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	main_panel.add_child(main_vbox)

	var main_title := Label.new()
	main_title.text = "Main Menu"
	main_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_title.add_theme_font_size_override("font_size", 18)
	main_vbox.add_child(main_title)

	var single_btn := _make_button("Singleplayer", Callable(self, "_on_singleplayer_pressed"))
	main_vbox.add_child(single_btn)

	var multi_btn := _make_button("Multiplayer", Callable(self, "_on_multiplayer_pressed"))
	main_vbox.add_child(multi_btn)

	var quit_btn := _make_button("Quit", Callable(self, "_on_quit_pressed"))
	main_vbox.add_child(quit_btn)

	status_label = Label.new()
	status_label.text = "Singleplayer worlds are ready now. Multiplayer is scaffolded for the future server/client path."
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color(0.76, 0.78, 0.84, 0.92))
	main_vbox.add_child(status_label)

	singleplayer_panel = _make_center_panel(Vector2(760, 500))
	singleplayer_panel.visible = false
	root_control.add_child(singleplayer_panel)
	var sp_vbox := VBoxContainer.new()
	sp_vbox.add_theme_constant_override("separation", 10)
	singleplayer_panel.add_child(sp_vbox)

	var sp_title := Label.new()
	sp_title.text = "Singleplayer Worlds"
	sp_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sp_title.add_theme_font_size_override("font_size", 18)
	sp_vbox.add_child(sp_title)

	worlds_list = ItemList.new()
	worlds_list.custom_minimum_size = Vector2(660, 240)
	worlds_list.select_mode = ItemList.SELECT_SINGLE
	worlds_list.item_selected.connect(Callable(self, "_on_world_selected"))
	worlds_list.item_activated.connect(Callable(self, "_on_world_activated"))
	_style_item_list(worlds_list)
	sp_vbox.add_child(worlds_list)

	world_info_label = Label.new()
	world_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	world_info_label.text = "Select a saved world or create a new one."
	world_info_label.add_theme_color_override("font_color", Color(0.78, 0.8, 0.86, 0.92))
	sp_vbox.add_child(world_info_label)

	var sp_buttons := HBoxContainer.new()
	sp_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	sp_buttons.add_theme_constant_override("separation", 8)
	sp_vbox.add_child(sp_buttons)

	sp_buttons.add_child(_make_button("Play Selected World", Callable(self, "_on_play_selected_pressed")))
	sp_buttons.add_child(_make_button("Create New World", Callable(self, "_on_create_world_pressed")))
	delete_world_button = _make_button("Delete Selected World", Callable(self, "_on_delete_selected_pressed"))
	sp_buttons.add_child(delete_world_button)
	sp_buttons.add_child(_make_button("Back", Callable(self, "_on_singleplayer_back_pressed")))

	create_world_panel = _make_center_panel(Vector2(520, 340))
	create_world_panel.visible = false
	root_control.add_child(create_world_panel)
	var cw_vbox := VBoxContainer.new()
	cw_vbox.add_theme_constant_override("separation", 12)
	create_world_panel.add_child(cw_vbox)

	var cw_title := Label.new()
	cw_title.text = "Create New World"
	cw_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cw_title.add_theme_font_size_override("font_size", 18)
	cw_vbox.add_child(cw_title)

	var name_label := Label.new()
	name_label.text = "World Name"
	cw_vbox.add_child(name_label)
	create_world_name_edit = LineEdit.new()
	create_world_name_edit.text = "world1"
	_style_line_edit(create_world_name_edit)
	cw_vbox.add_child(create_world_name_edit)

	var seed_label := Label.new()
	seed_label.text = "Seed"
	cw_vbox.add_child(seed_label)
	create_seed_edit = LineEdit.new()
	create_seed_edit.placeholder_text = "Leave blank for default, or type text/number"
	_style_line_edit(create_seed_edit)
	cw_vbox.add_child(create_seed_edit)

	var create_tip := Label.new()
	create_tip.text = "The world will generate using your current visual revamp pack."
	create_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	create_tip.add_theme_color_override("font_color", Color(0.72, 0.74, 0.82, 0.86))
	cw_vbox.add_child(create_tip)

	var cw_buttons := HBoxContainer.new()
	cw_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	cw_buttons.add_theme_constant_override("separation", 8)
	cw_vbox.add_child(cw_buttons)

	cw_buttons.add_child(_make_button("Create and Play", Callable(self, "_on_create_world_confirm_pressed")))
	cw_buttons.add_child(_make_button("Back", Callable(self, "_on_create_world_back_pressed")))

	multiplayer_panel = _make_center_panel(Vector2(500, 240))
	multiplayer_panel.visible = false
	root_control.add_child(multiplayer_panel)
	var mp_box := VBoxContainer.new()
	mp_box.add_theme_constant_override("separation", 10)
	multiplayer_panel.add_child(mp_box)

	var mp_title := Label.new()
	mp_title.text = "Multiplayer"
	mp_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mp_title.add_theme_font_size_override("font_size", 18)
	mp_box.add_child(mp_title)

	var mp_text := Label.new()
	mp_text.text = "Server browser / direct connect will hook into the same gameplay, chat, controls, and future proximity voice systems later."
	mp_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mp_text.add_theme_color_override("font_color", Color(0.78, 0.8, 0.86, 0.92))
	mp_box.add_child(mp_text)

	mp_box.add_child(_make_button("Back", Callable(self, "_on_multiplayer_back_pressed")))

	_busy_overlay = ColorRect.new()
	_busy_overlay.anchor_right = 1.0
	_busy_overlay.anchor_bottom = 1.0
	_busy_overlay.color = Color(0.02, 0.02, 0.03, 0.45)
	_busy_overlay.visible = false
	_busy_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root_control.add_child(_busy_overlay)

	_busy_label = Label.new()
	_busy_label.anchor_left = 0.5
	_busy_label.anchor_right = 0.5
	_busy_label.anchor_top = 0.88
	_busy_label.anchor_bottom = 0.88
	_busy_label.offset_left = -220
	_busy_label.offset_right = 220
	_busy_label.offset_top = -18
	_busy_label.offset_bottom = 18
	_busy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_busy_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_busy_label.visible = false
	_busy_label.add_theme_color_override("font_color", Color(0.96, 0.96, 0.99, 0.96))
	root_control.add_child(_busy_label)

func _make_center_panel(size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -size.x * 0.5
	panel.offset_right = size.x * 0.5
	panel.offset_top = -size.y * 0.5
	panel.offset_bottom = size.y * 0.5
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.075, 0.11, 0.9)
	sb.border_color = Color(0.66, 0.18, 0.24, 0.9)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 16
	sb.corner_radius_bottom_right = 16
	sb.content_margin_left = 18
	sb.content_margin_top = 16
	sb.content_margin_right = 18
	sb.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", sb)
	return panel

func _make_button(text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0, 42)
	button.pressed.connect(callback)
	_style_button(button)
	return button

func _style_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.11, 0.12, 0.17, 0.96)
	normal.border_color = Color(0.62, 0.2, 0.27, 0.85)
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.corner_radius_top_left = 10
	normal.corner_radius_top_right = 10
	normal.corner_radius_bottom_left = 10
	normal.corner_radius_bottom_right = 10
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.16, 0.17, 0.24, 0.98)
	hover.border_color = Color(0.86, 0.3, 0.36, 0.96)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.08, 0.09, 0.13, 1.0)
	pressed.border_color = Color(0.94, 0.42, 0.47, 1.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", Color(0.94, 0.94, 0.98, 1.0))
	button.add_theme_color_override("font_focus_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_font_size_override("font_size", 15)

func _style_line_edit(edit: LineEdit) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.085, 0.12, 0.96)
	normal.border_color = Color(0.46, 0.5, 0.62, 0.8)
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.corner_radius_top_left = 10
	normal.corner_radius_top_right = 10
	normal.corner_radius_bottom_left = 10
	normal.corner_radius_bottom_right = 10
	var focus := normal.duplicate() as StyleBoxFlat
	focus.border_color = Color(0.86, 0.3, 0.36, 0.96)
	edit.add_theme_stylebox_override("normal", normal)
	edit.add_theme_stylebox_override("focus", focus)
	edit.add_theme_color_override("font_color", Color(0.94, 0.94, 0.98, 1.0))
	edit.add_theme_color_override("placeholder_color", Color(0.65, 0.68, 0.76, 0.72))
	edit.custom_minimum_size = Vector2(0, 40)

func _style_item_list(list: ItemList) -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.08, 0.085, 0.12, 0.96)
	panel.border_color = Color(0.42, 0.46, 0.58, 0.85)
	panel.border_width_left = 2
	panel.border_width_top = 2
	panel.border_width_right = 2
	panel.border_width_bottom = 2
	panel.corner_radius_top_left = 10
	panel.corner_radius_top_right = 10
	panel.corner_radius_bottom_left = 10
	panel.corner_radius_bottom_right = 10
	list.add_theme_stylebox_override("panel", panel)
	list.add_theme_color_override("font_color", Color(0.94, 0.94, 0.98, 1.0))
	list.add_theme_color_override("font_selected_color", Color(1.0, 1.0, 1.0, 1.0))
	list.add_theme_color_override("guide_color", Color(0.62, 0.2, 0.27, 0.24))
	list.add_theme_color_override("selection_fill", Color(0.5, 0.18, 0.24, 0.38))
	list.add_theme_color_override("selection_stroke", Color(0.9, 0.34, 0.4, 0.92))

func show_menu() -> void:
	if canvas != null:
		canvas.visible = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE as Input.MouseMode)
	_set_busy(false, "")
	_show_only(main_panel)

func hide_menu() -> void:
	if canvas != null:
		canvas.visible = false

func _show_only(panel: Control) -> void:
	main_panel.visible = (panel == main_panel)
	singleplayer_panel.visible = (panel == singleplayer_panel)
	create_world_panel.visible = (panel == create_world_panel)
	multiplayer_panel.visible = (panel == multiplayer_panel)

func _get_game() -> Node:
	return get_node_or_null("/root/Game")

func _refresh_worlds_list() -> void:
	worlds_list.clear()
	var game_node: Node = _get_game()
	if game_node == null or not game_node.has_method("list_singleplayer_worlds"):
		world_info_label.text = "Game autoload was not found."
		return
	var worlds_v: Variant = game_node.call("list_singleplayer_worlds", "default")
	if typeof(worlds_v) != TYPE_ARRAY:
		world_info_label.text = "Could not read saved worlds."
		return
	var worlds: Array = worlds_v as Array
	for entry_v in worlds:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_v as Dictionary
		var display_name: String = str(entry.get("name", "world"))
		var seed_value: int = int(entry.get("seed", 1337))
		var last_played: String = str(entry.get("last_played_utc", ""))
		var line: String = "%s  |  Seed %d" % [display_name, seed_value]
		if last_played != "":
			line += "  |  Last Played %s" % last_played
		worlds_list.add_item(line)
	if worlds_list.get_item_count() > 0:
		worlds_list.select(0)
		_on_world_selected(0)
	else:
		world_info_label.text = "No saved worlds yet. Create a new world to start playing."

func _selected_world_name() -> String:
	var selected: PackedInt32Array = worlds_list.get_selected_items()
	var idx: int = -1
	if selected.size() > 0:
		idx = int(selected[0])
	if idx < 0:
		return ""
	var game_node: Node = _get_game()
	if game_node == null or not game_node.has_method("list_singleplayer_worlds"):
		return ""
	var worlds_v: Variant = game_node.call("list_singleplayer_worlds", "default")
	if typeof(worlds_v) != TYPE_ARRAY:
		return ""
	var worlds: Array = worlds_v as Array
	if idx >= worlds.size():
		return ""
	var entry_v: Variant = worlds[idx]
	if typeof(entry_v) != TYPE_DICTIONARY:
		return ""
	var entry: Dictionary = entry_v as Dictionary
	return str(entry.get("name", ""))

func _on_singleplayer_pressed() -> void:
	_refresh_worlds_list()
	_show_only(singleplayer_panel)

func _on_multiplayer_pressed() -> void:
	_show_only(multiplayer_panel)

func _on_multiplayer_back_pressed() -> void:
	_show_only(main_panel)

func _on_singleplayer_back_pressed() -> void:
	_show_only(main_panel)

func _on_create_world_pressed() -> void:
	var next_index: int = int(max(1, worlds_list.get_item_count() + 1))
	create_world_name_edit.text = "world%d" % next_index
	create_seed_edit.text = ""
	_show_only(create_world_panel)
	create_world_name_edit.grab_focus()

func _on_create_world_back_pressed() -> void:
	_show_only(singleplayer_panel)

func _on_world_selected(index: int) -> void:
	var game_node: Node = _get_game()
	if game_node == null or not game_node.has_method("list_singleplayer_worlds"):
		return
	var worlds_v: Variant = game_node.call("list_singleplayer_worlds", "default")
	if typeof(worlds_v) != TYPE_ARRAY:
		return
	var worlds: Array = worlds_v as Array
	if index < 0 or index >= worlds.size():
		return
	var entry_v: Variant = worlds[index]
	if typeof(entry_v) != TYPE_DICTIONARY:
		return
	var entry: Dictionary = entry_v as Dictionary
	world_info_label.text = "World: %s\nSeed: %s\nCreated: %s\nLast Played: %s" % [
		str(entry.get("name", "world")),
		str(entry.get("seed", 1337)),
		str(entry.get("created_utc", "")),
		str(entry.get("last_played_utc", ""))
	]

func _start_world(world_name: String) -> void:
	if _busy:
		return
	_set_busy(true, "Loading world...")
	call_deferred("_start_world_deferred", world_name)

func _start_world_deferred(world_name: String) -> void:
	var game_node: Node = _get_game()
	if game_node == null:
		status_label.text = "Game autoload was not found."
		_set_busy(false, "")
		_show_only(main_panel)
		return
	if game_node.has_method("start_singleplayer"):
		var ok_v: Variant = game_node.call("start_singleplayer", "default", world_name)
		if ok_v is bool and bool(ok_v):
			hide_menu()
			_set_busy(false, "")
			return
	status_label.text = "Failed to start singleplayer session."
	_set_busy(false, "")
	_show_only(main_panel)

func _on_play_selected_pressed() -> void:
	var world_name: String = _selected_world_name()
	if world_name == "":
		world_info_label.text = "Select a world first."
		return
	_start_world(world_name)

func _on_world_activated(index: int) -> void:
	_on_world_selected(index)
	_on_play_selected_pressed()

func _on_create_world_confirm_pressed() -> void:
	if _busy:
		return
	var world_name: String = create_world_name_edit.text.strip_edges()
	var seed_text: String = create_seed_edit.text.strip_edges()
	_set_busy(true, "Creating world...")
	call_deferred("_create_world_confirm_deferred", world_name, seed_text)

func _create_world_confirm_deferred(world_name: String, seed_text: String) -> void:
	var game_node: Node = _get_game()
	if game_node == null or not game_node.has_method("create_singleplayer_world"):
		status_label.text = "Game autoload was not found."
		_set_busy(false, "")
		_show_only(main_panel)
		return
	var result_v: Variant = game_node.call("create_singleplayer_world", "default", world_name, seed_text)
	if typeof(result_v) != TYPE_DICTIONARY:
		world_info_label.text = "World creation failed."
		_set_busy(false, "")
		return
	var result: Dictionary = result_v as Dictionary
	if not bool(result.get("ok", false)):
		world_info_label.text = str(result.get("error", "World creation failed."))
		_set_busy(false, "")
		return
	_refresh_worlds_list()
	_set_busy(false, "")
	_start_world(str(result.get("world_name", world_name)))

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_delete_selected_pressed() -> void:
	var world_name: String = _selected_world_name()
	if world_name == "":
		world_info_label.text = "Select a world first."
		return
	var game_node: Node = _get_game()
	if game_node == null or not game_node.has_method("delete_singleplayer_world"):
		world_info_label.text = "Delete is unavailable right now."
		return
	var result_v: Variant = game_node.call("delete_singleplayer_world", "default", world_name)
	if typeof(result_v) != TYPE_DICTIONARY:
		world_info_label.text = "Delete failed."
		return
	var result: Dictionary = result_v as Dictionary
	if not bool(result.get("ok", false)):
		world_info_label.text = str(result.get("error", "Delete failed."))
		return
	_refresh_worlds_list()
	world_info_label.text = "Deleted world %s." % world_name

func _set_busy(enabled: bool, message: String) -> void:
	_busy = enabled
	if _busy_overlay != null:
		_busy_overlay.visible = enabled
	if _busy_label != null:
		_busy_label.text = message
		_busy_label.visible = enabled and message != ""
