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
	bg.color = Color(0.12, 0.14, 0.18, 1.0)
	root_control.add_child(bg)

	var title := Label.new()
	title.text = "KaisenCraft"
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.anchor_top = 0.18
	title.anchor_bottom = 0.18
	title.offset_left = -240
	title.offset_right = 240
	title.offset_top = -26
	title.offset_bottom = 26
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	root_control.add_child(title)

	main_panel = _make_center_panel(Vector2(420, 240))
	root_control.add_child(main_panel)
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	main_panel.add_child(main_vbox)

	var single_btn := Button.new()
	single_btn.text = "Singleplayer"
	single_btn.pressed.connect(Callable(self, "_on_singleplayer_pressed"))
	main_vbox.add_child(single_btn)

	var multi_btn := Button.new()
	multi_btn.text = "Multiplayer"
	multi_btn.pressed.connect(Callable(self, "_on_multiplayer_pressed"))
	main_vbox.add_child(multi_btn)

	var quit_btn := Button.new()
	quit_btn.text = "Quit"
	quit_btn.pressed.connect(Callable(self, "_on_quit_pressed"))
	main_vbox.add_child(quit_btn)

	status_label = Label.new()
	status_label.text = "Singleplayer worlds are listed separately. Multiplayer stays scaffolded for the future server/client path."
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(status_label)

	singleplayer_panel = _make_center_panel(Vector2(640, 420))
	singleplayer_panel.visible = false
	root_control.add_child(singleplayer_panel)
	var sp_vbox := VBoxContainer.new()
	sp_vbox.add_theme_constant_override("separation", 8)
	singleplayer_panel.add_child(sp_vbox)

	var sp_title := Label.new()
	sp_title.text = "Singleplayer Worlds"
	sp_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sp_vbox.add_child(sp_title)

	worlds_list = ItemList.new()
	worlds_list.custom_minimum_size = Vector2(560, 220)
	worlds_list.select_mode = ItemList.SELECT_SINGLE
	worlds_list.item_selected.connect(Callable(self, "_on_world_selected"))
	worlds_list.item_activated.connect(Callable(self, "_on_world_activated"))
	sp_vbox.add_child(worlds_list)

	world_info_label = Label.new()
	world_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	world_info_label.text = "Select a saved world or create a new one."
	sp_vbox.add_child(world_info_label)

	var sp_buttons := HBoxContainer.new()
	sp_buttons.add_theme_constant_override("separation", 8)
	sp_vbox.add_child(sp_buttons)

	var play_btn := Button.new()
	play_btn.text = "Play Selected World"
	play_btn.pressed.connect(Callable(self, "_on_play_selected_pressed"))
	sp_buttons.add_child(play_btn)

	var create_btn := Button.new()
	create_btn.text = "Create New World"
	create_btn.pressed.connect(Callable(self, "_on_create_world_pressed"))
	sp_buttons.add_child(create_btn)

	delete_world_button = Button.new()
	delete_world_button.text = "Delete Selected World"
	delete_world_button.pressed.connect(Callable(self, "_on_delete_selected_pressed"))
	sp_buttons.add_child(delete_world_button)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.pressed.connect(Callable(self, "_on_singleplayer_back_pressed"))
	sp_buttons.add_child(back_btn)

	create_world_panel = _make_center_panel(Vector2(460, 270))
	create_world_panel.visible = false
	root_control.add_child(create_world_panel)
	var cw_vbox := VBoxContainer.new()
	cw_vbox.add_theme_constant_override("separation", 10)
	create_world_panel.add_child(cw_vbox)

	var cw_title := Label.new()
	cw_title.text = "Create New World"
	cw_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cw_vbox.add_child(cw_title)

	var name_label := Label.new()
	name_label.text = "World Name"
	cw_vbox.add_child(name_label)
	create_world_name_edit = LineEdit.new()
	create_world_name_edit.text = "world1"
	cw_vbox.add_child(create_world_name_edit)

	var seed_label := Label.new()
	seed_label.text = "Seed"
	cw_vbox.add_child(seed_label)
	create_seed_edit = LineEdit.new()
	create_seed_edit.placeholder_text = "Leave blank for default, or type text/number"
	cw_vbox.add_child(create_seed_edit)

	var cw_buttons := HBoxContainer.new()
	cw_buttons.add_theme_constant_override("separation", 8)
	cw_vbox.add_child(cw_buttons)

	var create_confirm_btn := Button.new()
	create_confirm_btn.text = "Create and Play"
	create_confirm_btn.pressed.connect(Callable(self, "_on_create_world_confirm_pressed"))
	cw_buttons.add_child(create_confirm_btn)

	var create_back_btn := Button.new()
	create_back_btn.text = "Back"
	create_back_btn.pressed.connect(Callable(self, "_on_create_world_back_pressed"))
	cw_buttons.add_child(create_back_btn)

	multiplayer_panel = _make_center_panel(Vector2(440, 200))
	multiplayer_panel.visible = false
	root_control.add_child(multiplayer_panel)
	var mp_box := VBoxContainer.new()
	mp_box.add_theme_constant_override("separation", 8)
	multiplayer_panel.add_child(mp_box)

	var mp_title := Label.new()
	mp_title.text = "Multiplayer"
	mp_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mp_box.add_child(mp_title)

	var mp_text := Label.new()
	mp_text.text = "Server browser / direct connect will plug into the same gameplay, chat, commands, saved controls, and future proximity voice channels later."
	mp_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mp_box.add_child(mp_text)

	var mp_back := Button.new()
	mp_back.text = "Back"
	mp_back.pressed.connect(Callable(self, "_on_multiplayer_back_pressed"))
	mp_box.add_child(mp_back)

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
	return panel

func show_menu() -> void:
	if canvas != null:
		canvas.visible = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE as Input.MouseMode)
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
	var game_node: Node = _get_game()
	if game_node == null:
		status_label.text = "Game autoload was not found."
		_show_only(main_panel)
		return
	if game_node.has_method("start_singleplayer"):
		var ok_v: Variant = game_node.call("start_singleplayer", "default", world_name)
		if ok_v is bool and bool(ok_v):
			hide_menu()
			return
	status_label.text = "Failed to start singleplayer session."
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
	var world_name: String = create_world_name_edit.text.strip_edges()
	var seed_text: String = create_seed_edit.text.strip_edges()
	var game_node: Node = _get_game()
	if game_node == null or not game_node.has_method("create_singleplayer_world"):
		status_label.text = "Game autoload was not found."
		_show_only(main_panel)
		return
	var result_v: Variant = game_node.call("create_singleplayer_world", "default", world_name, seed_text)
	if typeof(result_v) != TYPE_DICTIONARY:
		world_info_label.text = "World creation failed."
		return
	var result: Dictionary = result_v as Dictionary
	if not bool(result.get("ok", false)):
		world_info_label.text = str(result.get("error", "World creation failed."))
		return
	_refresh_worlds_list()
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

