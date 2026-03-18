extends CanvasLayer
class_name KZ_Hud

const CRAFT2_BASE: int = 100
const CRAFT2_RESULT: int = 104
const CRAFT3_BASE: int = 200
const CRAFT3_RESULT: int = 209
const CREATIVE_BASE: int = 300

var player: KZ_Player
var registry: KZ_BlockRegistry

var root: Control
var hotbar_box: HBoxContainer
var inv_panel: PanelContainer
var inv_grid: GridContainer
var settings_panel: PanelContainer
var controls_panel: PanelContainer
var controls_list: VBoxContainer
var controls_status_label: Label
var controls_button: Button
var auto_step_check: CheckBox
var back_to_game_button: Button
var save_return_button: Button
var render_distance_spin: SpinBox
var fov_spin: SpinBox
var max_fps_spin: SpinBox
var character_button: Button
var character_panel: PanelContainer
var character_preview_container: SubViewportContainer
var character_preview_viewport: SubViewport
var character_preview_root: Node3D
var character_preview_camera: Camera3D
var character_preview_model: Node3D
var character_sex_option: OptionButton
var character_build_option: OptionButton
var character_height_slider: HSlider
var character_width_slider: HSlider
var character_weight_slider: HSlider
var character_height_value_label: Label
var character_width_value_label: Label
var character_weight_value_label: Label
var walk_mode_label: Label
var camera_mode_label: Label
var time_label: Label
var fps_label: Label
var crosshair: Label
var break_progress_panel: PanelContainer
var break_progress_bar: ProgressBar
var break_progress_label: Label
var hint_label: Label
var health_bar: ProgressBar
var health_label: Label
var hunger_bar: ProgressBar
var hunger_label: Label
var thirst_bar: ProgressBar
var thirst_label: Label
var death_panel: PanelContainer
var crafting_table_panel: PanelContainer
var inventory_craft_row: HBoxContainer
var inventory_craft_hint: Label
var creative_panel: PanelContainer
var creative_grid: GridContainer
var creative_tabs: HBoxContainer
var creative_prev_button: Button
var creative_next_button: Button
var creative_page_label: Label
var creative_slots: Array[KZ_SlotButton] = []
var creative_entries: Array[Dictionary] = []
var creative_filtered_entries: Array[Dictionary] = []
var creative_category: String = "Blocks"
var creative_page: int = 0
var craft2_slots: Array[KZ_SlotButton] = []
var craft3_slots: Array[KZ_SlotButton] = []
var craft2_result_slot: KZ_SlotButton
var craft3_result_slot: KZ_SlotButton
var craft2_ids: Array[String] = []
var craft2_counts: Array[int] = []
var craft3_ids: Array[String] = []
var craft3_counts: Array[int] = []
var craft2_result_id: String = ""
var craft2_result_count: int = 0
var craft2_consume_slots: Array[int] = []
var craft3_result_id: String = ""
var craft3_result_count: int = 0
var craft3_consume_slots: Array[int] = []

var hotbar_slots: Array[KZ_SlotButton] = []
var inv_slots: Array[KZ_SlotButton] = []
var inv_grid_spacer: Control
var _texture_cache: Dictionary = {}

var cursor_panel: PanelContainer
var cursor_icon: ColorRect
var cursor_label: Label

var chat_panel: PanelContainer
var chat_log: RichTextLabel
var chat_input_panel: PanelContainer
var chat_input: LineEdit
var chat_hint_label: Label
var _chat_lines: Array[String] = []

var control_buttons: Dictionary = {}
var _capturing_action: String = ""

var _drag_button: int = 0
var _drag_visited: Dictionary = {}
var _drag_slots: Array[int] = []
var _drag_from_cursor: bool = false
var _chat_hide_after_sec: float = 25.0
var _last_chat_activity_ms: int = 0

func setup(p_player: KZ_Player, p_registry: KZ_BlockRegistry) -> void:
	player = p_player
	registry = p_registry
	_init_crafting_arrays()

	_build_ui()
	_connect_signals()
	_connect_chat_bus()
	_refresh_all()
	_refresh_controls_ui()
	_refresh_creative_catalog()
	_set_inventory_open(false)
	_set_settings_open(false)
	_set_controls_open(false)
	_set_chat_open(false)
	_refresh_health(player.health, player.max_health)
	_refresh_hunger(player.hunger, player.max_hunger)
	_refresh_thirst(player.thirst, player.max_thirst)
	_refresh_walk_mode(player.get_walk_mode_name())
	_refresh_camera_mode(player.get_camera_mode_name())
	_refresh_render_distance()
	_refresh_fov()
	_refresh_max_fps()
	_refresh_character_controls_from_player()
	_refresh_character_preview()
	_last_chat_activity_ms = Time.get_ticks_msec()

func _init_crafting_arrays() -> void:
	craft2_ids = ["", "", "", ""]
	craft2_counts = [0, 0, 0, 0]
	craft3_ids = ["", "", "", "", "", "", "", "", ""]
	craft3_counts = [0, 0, 0, 0, 0, 0, 0, 0, 0]
	craft2_result_id = ""
	craft2_result_count = 0
	craft2_consume_slots = []
	craft3_result_id = ""
	craft3_result_count = 0
	craft3_consume_slots = []

func _input(event: InputEvent) -> void:
	if _capturing_action != "":
		if event is InputEventKey:
			var key_event: InputEventKey = event as InputEventKey
			if not key_event.pressed or key_event.is_echo():
				return
			if key_event.keycode == KEY_ESCAPE:
				controls_status_label.text = "Rebind canceled."
				_capturing_action = ""
				return
			var game_node: Node = _get_game()
			if game_node != null and game_node.has_method("rebind_action"):
				var ok_v: Variant = game_node.call("rebind_action", _capturing_action, key_event)
				if ok_v is bool and bool(ok_v):
					controls_status_label.text = "Bound %s to %s" % [_capturing_action, key_event.as_text()]
					_capturing_action = ""
					_refresh_controls_ui()
					get_viewport().set_input_as_handled()
					return
		elif event is InputEventMouseButton:
			var mb_rebind: InputEventMouseButton = event as InputEventMouseButton
			if not mb_rebind.pressed or mb_rebind.is_echo():
				return
			if mb_rebind.button_index == MouseButton.MOUSE_BUTTON_WHEEL_UP or mb_rebind.button_index == MouseButton.MOUSE_BUTTON_WHEEL_DOWN:
				return
			var game_node2: Node = _get_game()
			if game_node2 != null and game_node2.has_method("rebind_action"):
				var ok_v2: Variant = game_node2.call("rebind_action", _capturing_action, mb_rebind)
				if ok_v2 is bool and bool(ok_v2):
					controls_status_label.text = "Bound %s to %s" % [_capturing_action, mb_rebind.as_text()]
					_capturing_action = ""
					_refresh_controls_ui()
					get_viewport().set_input_as_handled()
					return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if (mb.button_index == MouseButton.MOUSE_BUTTON_LEFT or mb.button_index == MouseButton.MOUSE_BUTTON_RIGHT) and not mb.pressed:
			_finalize_drag(mb.button_index)

func _unhandled_input(event: InputEvent) -> void:
	if player == null:
		return
	if _capturing_action != "":
		return
	if not (event is InputEventKey):
		return
	var ek: InputEventKey = event as InputEventKey
	if not ek.pressed or ek.is_echo():
		return

	if player.chat_is_open:
		if ek.keycode == KEY_ESCAPE:
			_set_chat_open(false)
			player.set_chat_open(false)
			get_viewport().set_input_as_handled()
		return

	if player.inventory_is_open or player.settings_is_open or player.crafting_table_is_open or player.is_dead:
		return

	if event.is_action_pressed("chat"):
		_open_chat("")
		get_viewport().set_input_as_handled()
		return

	if ek.keycode == KEY_SLASH:
		_open_chat("/")
		get_viewport().set_input_as_handled()
		return

func _process(_dt: float) -> void:
	var game_node: Node = _get_game()
	if game_node != null and game_node.has_method("get_time_display_text") and time_label != null:
		time_label.text = str(game_node.call("get_time_display_text"))
	if fps_label != null:
		fps_label.text = "FPS %d" % Engine.get_frames_per_second()

	if chat_panel != null:
		var idle_sec: float = float(Time.get_ticks_msec() - _last_chat_activity_ms) / 1000.0
		chat_panel.visible = player != null and (player.chat_is_open or idle_sec <= _chat_hide_after_sec)

	if player == null:
		if break_progress_panel != null:
			break_progress_panel.visible = false
		return

	if break_progress_panel != null:
		var show_break: bool = player.is_breaking_block() and not player.inventory_is_open and not player.crafting_table_is_open and not player.settings_is_open and not player.chat_is_open and not player.is_dead
		break_progress_panel.visible = show_break
		if show_break:
			var ratio: float = player.get_break_progress_ratio()
			break_progress_bar.max_value = 1.0
			break_progress_bar.value = ratio
			break_progress_label.text = player.get_break_progress_text()

	if not player.inventory_is_open and not player.crafting_table_is_open:
		cursor_panel.visible = false
	else:
		if player.cursor_item_id == "" or player.cursor_count <= 0:
			cursor_panel.visible = false
		else:
			cursor_panel.visible = true
			var mp: Vector2 = get_viewport().get_mouse_position()
			cursor_panel.position = mp + Vector2(12, 12)

func _build_ui() -> void:
	root = Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(root)

	crosshair = Label.new()
	crosshair.text = "+"
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair.anchor_left = 0.5
	crosshair.anchor_top = 0.5
	crosshair.anchor_right = 0.5
	crosshair.anchor_bottom = 0.5
	crosshair.offset_left = -8
	crosshair.offset_top = -8
	crosshair.offset_right = 8
	crosshair.offset_bottom = 8
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(crosshair)

	break_progress_panel = PanelContainer.new()
	break_progress_panel.anchor_left = 0.5
	break_progress_panel.anchor_right = 0.5
	break_progress_panel.anchor_top = 0.5
	break_progress_panel.anchor_bottom = 0.5
	break_progress_panel.offset_left = -90
	break_progress_panel.offset_right = 90
	break_progress_panel.offset_top = 20
	break_progress_panel.offset_bottom = 58
	break_progress_panel.visible = false
	break_progress_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(break_progress_panel)

	var break_vbox := VBoxContainer.new()
	break_vbox.add_theme_constant_override("separation", 2)
	break_progress_panel.add_child(break_vbox)

	break_progress_label = Label.new()
	break_progress_label.text = "Breaking 0%"
	break_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	break_vbox.add_child(break_progress_label)

	break_progress_bar = ProgressBar.new()
	break_progress_bar.custom_minimum_size = Vector2(168, 14)
	break_progress_bar.max_value = 1.0
	break_progress_bar.show_percentage = false
	break_vbox.add_child(break_progress_bar)

	var vitals_panel := PanelContainer.new()
	vitals_panel.offset_left = 16
	vitals_panel.offset_top = 16
	vitals_panel.offset_right = 260
	vitals_panel.offset_bottom = 134
	vitals_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vitals_panel)

	var vitals_vbox := VBoxContainer.new()
	vitals_vbox.add_theme_constant_override("separation", 4)
	vitals_panel.add_child(vitals_vbox)

	health_label = Label.new()
	health_label.text = "Health 20 / 20"
	vitals_vbox.add_child(health_label)
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(220, 18)
	health_bar.show_percentage = false
	vitals_vbox.add_child(health_bar)

	hunger_label = Label.new()
	hunger_label.text = "Hunger 20 / 20"
	vitals_vbox.add_child(hunger_label)
	hunger_bar = ProgressBar.new()
	hunger_bar.custom_minimum_size = Vector2(220, 18)
	hunger_bar.show_percentage = false
	vitals_vbox.add_child(hunger_bar)

	thirst_label = Label.new()
	thirst_label.text = "Thirst 20 / 20"
	vitals_vbox.add_child(thirst_label)
	thirst_bar = ProgressBar.new()
	thirst_bar.custom_minimum_size = Vector2(220, 18)
	thirst_bar.show_percentage = false
	vitals_vbox.add_child(thirst_bar)

	chat_panel = PanelContainer.new()
	chat_panel.offset_left = 16
	chat_panel.offset_right = 380
	chat_panel.anchor_top = 1.0
	chat_panel.anchor_bottom = 1.0
	chat_panel.offset_top = -300
	chat_panel.offset_bottom = -160
	chat_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(chat_panel)

	var chat_box := VBoxContainer.new()
	chat_box.add_theme_constant_override("separation", 4)
	chat_panel.add_child(chat_box)

	chat_hint_label = Label.new()
	chat_hint_label.text = "Press T to chat. Messages travel 30 blocks."
	chat_box.add_child(chat_hint_label)

	chat_log = RichTextLabel.new()
	chat_log.fit_content = true
	chat_log.scroll_active = false
	chat_log.bbcode_enabled = false
	chat_log.selection_enabled = false
	chat_log.custom_minimum_size = Vector2(340, 110)
	chat_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chat_box.add_child(chat_log)

	chat_input_panel = PanelContainer.new()
	chat_input_panel.visible = false
	chat_input_panel.offset_left = 16
	chat_input_panel.offset_right = 440
	chat_input_panel.anchor_top = 1.0
	chat_input_panel.anchor_bottom = 1.0
	chat_input_panel.offset_top = -152
	chat_input_panel.offset_bottom = -112
	chat_input_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(chat_input_panel)

	chat_input = LineEdit.new()
	chat_input.placeholder_text = "Type a message or /command"
	chat_input.text_submitted.connect(Callable(self, "_on_chat_text_submitted"))
	chat_input_panel.add_child(chat_input)

	time_label = Label.new()
	time_label.anchor_left = 1.0
	time_label.anchor_right = 1.0
	time_label.offset_left = -260
	time_label.offset_right = -18
	time_label.offset_top = 18
	time_label.offset_bottom = 40
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	time_label.text = "0.0/15.0 Morning"
	root.add_child(time_label)

	fps_label = Label.new()
	fps_label.anchor_left = 1.0
	fps_label.anchor_right = 1.0
	fps_label.offset_left = -260
	fps_label.offset_right = -18
	fps_label.offset_top = 42
	fps_label.offset_bottom = 64
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fps_label.text = "FPS 0"
	root.add_child(fps_label)

	camera_mode_label = Label.new()
	camera_mode_label.anchor_left = 1.0
	camera_mode_label.anchor_right = 1.0
	camera_mode_label.anchor_top = 1.0
	camera_mode_label.anchor_bottom = 1.0
	camera_mode_label.offset_left = -260
	camera_mode_label.offset_right = -18
	camera_mode_label.offset_top = -82
	camera_mode_label.offset_bottom = -58
	camera_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	camera_mode_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camera_mode_label.text = "First Person"
	root.add_child(camera_mode_label)

	walk_mode_label = Label.new()
	walk_mode_label.anchor_left = 1.0
	walk_mode_label.anchor_right = 1.0
	walk_mode_label.anchor_top = 1.0
	walk_mode_label.anchor_bottom = 1.0
	walk_mode_label.offset_left = -190
	walk_mode_label.offset_right = -18
	walk_mode_label.offset_top = -56
	walk_mode_label.offset_bottom = -30
	walk_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	walk_mode_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	walk_mode_label.text = "Jogging"
	root.add_child(walk_mode_label)

	hotbar_box = HBoxContainer.new()
	hotbar_box.anchor_left = 0.5
	hotbar_box.anchor_right = 0.5
	hotbar_box.anchor_top = 1.0
	hotbar_box.anchor_bottom = 1.0
	hotbar_box.offset_left = -258
	hotbar_box.offset_right = 258
	hotbar_box.offset_top = -70
	hotbar_box.offset_bottom = -12
	hotbar_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hotbar_box.add_theme_constant_override("separation", 6)
	root.add_child(hotbar_box)

	hotbar_slots.clear()
	for i in range(KZ_Inventory.HOTBAR_SIZE):
		var b := KZ_SlotButton.new()
		b.set_slot_index(i)
		b.gui_input.connect(Callable(self, "_on_slot_gui_input").bind(i))
		b.mouse_entered.connect(Callable(self, "_on_slot_mouse_entered").bind(i))
		hotbar_box.add_child(b)
		hotbar_slots.append(b)

	inv_panel = PanelContainer.new()
	inv_panel.anchor_left = 0.5
	inv_panel.anchor_right = 0.5
	inv_panel.anchor_top = 0.5
	inv_panel.anchor_bottom = 0.5
	inv_panel.offset_left = -280
	inv_panel.offset_right = 280
	inv_panel.offset_top = -210
	inv_panel.offset_bottom = 150
	inv_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(inv_panel)

	var inv_vbox := VBoxContainer.new()
	inv_vbox.add_theme_constant_override("separation", 8)
	inv_panel.add_child(inv_vbox)

	var title := Label.new()
	title.text = "Inventory"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.visible = false
	inv_vbox.add_child(title)

	inventory_craft_row = HBoxContainer.new()
	var craft_row: HBoxContainer = inventory_craft_row
	craft_row.alignment = BoxContainer.ALIGNMENT_CENTER
	craft_row.add_theme_constant_override("separation", 8)
	inv_vbox.add_child(craft_row)

	var craft_left := VBoxContainer.new()
	craft_left.add_theme_constant_override("separation", 4)
	craft_row.add_child(craft_left)
	var craft_title := Label.new()
	craft_title.text = "2x2 Crafting"
	craft_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	craft_title.visible = false
	craft_left.add_child(craft_title)
	var craft_grid := GridContainer.new()
	craft_grid.columns = 2
	craft_grid.add_theme_constant_override("h_separation", 6)
	craft_grid.add_theme_constant_override("v_separation", 6)
	craft_left.add_child(craft_grid)
	craft2_slots.clear()
	for craft_i in range(4):
		var craft_slot := KZ_SlotButton.new()
		craft_slot.set_slot_index(CRAFT2_BASE + craft_i)
		craft_slot.gui_input.connect(Callable(self, "_on_slot_gui_input").bind(CRAFT2_BASE + craft_i))
		craft_slot.mouse_entered.connect(Callable(self, "_on_slot_mouse_entered").bind(CRAFT2_BASE + craft_i))
		craft_grid.add_child(craft_slot)
		craft2_slots.append(craft_slot)

	var craft_arrow := Label.new()
	craft_arrow.text = "→"
	craft_arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	craft_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	craft_row.add_child(craft_arrow)

	var craft_result_box := VBoxContainer.new()
	craft_result_box.add_theme_constant_override("separation", 4)
	craft_row.add_child(craft_result_box)
	var craft_result_title := Label.new()
	craft_result_title.text = "Result"
	craft_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	craft_result_title.visible = false
	craft_result_box.add_child(craft_result_title)
	var craft_result_spacer := Control.new()
	craft_result_spacer.custom_minimum_size = Vector2(0, 18)
	craft_result_box.add_child(craft_result_spacer)
	craft2_result_slot = KZ_SlotButton.new()
	craft2_result_slot.set_slot_index(CRAFT2_RESULT)
	craft2_result_slot.gui_input.connect(Callable(self, "_on_slot_gui_input").bind(CRAFT2_RESULT))
	craft2_result_slot.mouse_entered.connect(Callable(self, "_on_slot_mouse_entered").bind(CRAFT2_RESULT))
	craft_result_box.add_child(craft2_result_slot)

	var inv_title2 := Label.new()
	inv_title2.text = "Backpack"
	inv_title2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inv_title2.visible = false
	inv_vbox.add_child(inv_title2)

	creative_panel = PanelContainer.new()
	creative_panel.visible = false
	inv_vbox.add_child(creative_panel)
	var creative_wrap := VBoxContainer.new()
	creative_wrap.add_theme_constant_override("separation", 6)
	creative_panel.add_child(creative_wrap)
	creative_tabs = HBoxContainer.new()
	creative_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	creative_tabs.add_theme_constant_override("separation", 6)
	creative_wrap.add_child(creative_tabs)
	for category_name in ["Blocks", "Tools", "Items", "All"]:
		var tab_btn := Button.new()
		tab_btn.text = category_name
		tab_btn.toggle_mode = true
		tab_btn.button_pressed = category_name == creative_category
		tab_btn.pressed.connect(Callable(self, "_on_creative_category_pressed").bind(category_name))
		creative_tabs.add_child(tab_btn)
	var creative_nav := HBoxContainer.new()
	creative_nav.alignment = BoxContainer.ALIGNMENT_CENTER
	creative_nav.add_theme_constant_override("separation", 8)
	creative_wrap.add_child(creative_nav)
	creative_prev_button = Button.new()
	creative_prev_button.text = "←"
	creative_prev_button.pressed.connect(Callable(self, "_on_creative_prev_pressed"))
	creative_nav.add_child(creative_prev_button)
	creative_page_label = Label.new()
	creative_page_label.text = "Blocks 1/1"
	creative_nav.add_child(creative_page_label)
	creative_next_button = Button.new()
	creative_next_button.text = "→"
	creative_next_button.pressed.connect(Callable(self, "_on_creative_next_pressed"))
	creative_nav.add_child(creative_next_button)
	var creative_center := CenterContainer.new()
	creative_wrap.add_child(creative_center)
	creative_grid = GridContainer.new()
	creative_grid.columns = KZ_Inventory.INV_COLS
	creative_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	creative_grid.add_theme_constant_override("h_separation", 6)
	creative_grid.add_theme_constant_override("v_separation", 6)
	creative_center.add_child(creative_grid)
	creative_slots.clear()
	for creative_i in range(18):
		var creative_slot := KZ_SlotButton.new()
		creative_slot.set_slot_index(CREATIVE_BASE + creative_i)
		creative_slot.gui_input.connect(Callable(self, "_on_slot_gui_input").bind(CREATIVE_BASE + creative_i))
		creative_slot.mouse_entered.connect(Callable(self, "_on_slot_mouse_entered").bind(CREATIVE_BASE + creative_i))
		creative_grid.add_child(creative_slot)
		creative_slots.append(creative_slot)

	inv_grid_spacer = Control.new()
	inv_grid_spacer.custom_minimum_size = Vector2(0, 12)
	inv_vbox.add_child(inv_grid_spacer)

	var inv_grid_center := CenterContainer.new()
	inv_vbox.add_child(inv_grid_center)
	inv_grid = GridContainer.new()
	inv_grid.columns = KZ_Inventory.INV_COLS
	inv_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inv_grid.add_theme_constant_override("h_separation", 6)
	inv_grid.add_theme_constant_override("v_separation", 6)
	inv_grid_center.add_child(inv_grid)

	inv_slots.clear()
	for j in range(KZ_Inventory.INV_SIZE):
		var g: int = KZ_Inventory.HOTBAR_SIZE + j
		var b2 := KZ_SlotButton.new()
		b2.set_slot_index(g)
		b2.gui_input.connect(Callable(self, "_on_slot_gui_input").bind(g))
		b2.mouse_entered.connect(Callable(self, "_on_slot_mouse_entered").bind(g))
		inv_grid.add_child(b2)
		inv_slots.append(b2)

	hint_label = Label.new()
	inventory_craft_hint = hint_label
	hint_label.text = ""
	hint_label.visible = false
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inv_vbox.add_child(hint_label)

	crafting_table_panel = PanelContainer.new()
	crafting_table_panel.anchor_left = 0.5
	crafting_table_panel.anchor_right = 0.5
	crafting_table_panel.anchor_top = 0.5
	crafting_table_panel.anchor_bottom = 0.5
	crafting_table_panel.offset_left = -300
	crafting_table_panel.offset_right = 300
	crafting_table_panel.offset_top = -250
	crafting_table_panel.offset_bottom = -10
	crafting_table_panel.visible = false
	crafting_table_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(crafting_table_panel)

	var ct_vbox := VBoxContainer.new()
	ct_vbox.add_theme_constant_override("separation", 8)
	crafting_table_panel.add_child(ct_vbox)
	var ct_title := Label.new()
	ct_title.text = "Crafting Table"
	ct_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ct_vbox.add_child(ct_title)
	var ct_row := HBoxContainer.new()
	ct_row.alignment = BoxContainer.ALIGNMENT_CENTER
	ct_row.add_theme_constant_override("separation", 10)
	ct_vbox.add_child(ct_row)
	var ct_grid := GridContainer.new()
	ct_grid.columns = 3
	ct_grid.add_theme_constant_override("h_separation", 6)
	ct_grid.add_theme_constant_override("v_separation", 6)
	ct_row.add_child(ct_grid)
	craft3_slots.clear()
	for ct_i in range(9):
		var ct_slot := KZ_SlotButton.new()
		ct_slot.set_slot_index(CRAFT3_BASE + ct_i)
		ct_slot.gui_input.connect(Callable(self, "_on_slot_gui_input").bind(CRAFT3_BASE + ct_i))
		ct_slot.mouse_entered.connect(Callable(self, "_on_slot_mouse_entered").bind(CRAFT3_BASE + ct_i))
		ct_grid.add_child(ct_slot)
		craft3_slots.append(ct_slot)
	var ct_arrow := Label.new()
	ct_arrow.text = "→"
	ct_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ct_arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ct_row.add_child(ct_arrow)
	var ct_result_center := CenterContainer.new()
	ct_result_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ct_row.add_child(ct_result_center)
	var ct_result_box := VBoxContainer.new()
	ct_result_box.alignment = BoxContainer.ALIGNMENT_CENTER
	ct_result_box.add_theme_constant_override("separation", 8)
	ct_result_center.add_child(ct_result_box)
	var ct_spacer := Control.new()
	ct_spacer.custom_minimum_size = Vector2(0, 84)
	ct_result_box.add_child(ct_spacer)
	var ct_res_label := Label.new()
	ct_res_label.text = "Result"
	ct_res_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ct_res_label.visible = false
	ct_result_box.add_child(ct_res_label)
	craft3_result_slot = KZ_SlotButton.new()
	craft3_result_slot.set_slot_index(CRAFT3_RESULT)
	craft3_result_slot.gui_input.connect(Callable(self, "_on_slot_gui_input").bind(CRAFT3_RESULT))
	craft3_result_slot.mouse_entered.connect(Callable(self, "_on_slot_mouse_entered").bind(CRAFT3_RESULT))
	ct_result_box.add_child(craft3_result_slot)
	var ct_hint := Label.new()
	ct_hint.text = ""
	ct_hint.visible = false
	ct_vbox.add_child(ct_hint)

	settings_panel = PanelContainer.new()
	settings_panel.anchor_left = 0.5
	settings_panel.anchor_right = 0.5
	settings_panel.anchor_top = 0.5
	settings_panel.anchor_bottom = 0.5
	settings_panel.offset_left = -240
	settings_panel.offset_right = 240
	settings_panel.offset_top = -180
	settings_panel.offset_bottom = 180
	settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(settings_panel)

	var settings_vbox := VBoxContainer.new()
	settings_vbox.add_theme_constant_override("separation", 10)
	settings_panel.add_child(settings_vbox)

	var settings_title := Label.new()
	settings_title.text = "Settings"
	settings_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_vbox.add_child(settings_title)

	auto_step_check = CheckBox.new()
	auto_step_check.text = "Auto Step"
	auto_step_check.toggled.connect(Callable(self, "_on_auto_step_toggled"))
	settings_vbox.add_child(auto_step_check)

	var render_row := HBoxContainer.new()
	render_row.add_theme_constant_override("separation", 8)
	settings_vbox.add_child(render_row)
	var render_label := Label.new()
	render_label.text = "Render Distance"
	render_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	render_row.add_child(render_label)
	render_distance_spin = SpinBox.new()
	render_distance_spin.min_value = 2
	render_distance_spin.max_value = 16
	render_distance_spin.step = 1
	render_distance_spin.value_changed.connect(Callable(self, "_on_render_distance_changed"))
	render_row.add_child(render_distance_spin)

	var fov_row := HBoxContainer.new()
	fov_row.add_theme_constant_override("separation", 8)
	settings_vbox.add_child(fov_row)
	var fov_label := Label.new()
	fov_label.text = "FOV"
	fov_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fov_row.add_child(fov_label)
	fov_spin = SpinBox.new()
	fov_spin.min_value = 20
	fov_spin.max_value = 120
	fov_spin.step = 1
	fov_spin.value_changed.connect(Callable(self, "_on_fov_changed"))
	fov_row.add_child(fov_spin)

	var fps_row := HBoxContainer.new()
	fps_row.add_theme_constant_override("separation", 8)
	settings_vbox.add_child(fps_row)
	var fps_cap_label := Label.new()
	fps_cap_label.text = "Max FPS (0 = uncapped)"
	fps_cap_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fps_row.add_child(fps_cap_label)
	max_fps_spin = SpinBox.new()
	max_fps_spin.min_value = 0
	max_fps_spin.max_value = 360
	max_fps_spin.step = 10
	max_fps_spin.value_changed.connect(Callable(self, "_on_max_fps_changed"))
	fps_row.add_child(max_fps_spin)

	character_button = Button.new()
	character_button.text = "Character Creation"
	character_button.pressed.connect(Callable(self, "_on_character_button_pressed"))
	settings_vbox.add_child(character_button)

	controls_button = Button.new()
	controls_button.text = "Controls"
	controls_button.pressed.connect(Callable(self, "_on_controls_button_pressed"))
	settings_vbox.add_child(controls_button)

	back_to_game_button = Button.new()
	back_to_game_button.text = "Back to Game"
	back_to_game_button.pressed.connect(Callable(self, "_on_back_to_game_pressed"))
	settings_vbox.add_child(back_to_game_button)

	save_return_button = Button.new()
	save_return_button.text = "Save and Return to Main Menu"
	save_return_button.pressed.connect(Callable(self, "_on_save_return_pressed"))
	settings_vbox.add_child(save_return_button)

	var settings_hint := Label.new()
	settings_hint.text = "Auto Step OFF = manual jump. Auto Step ON = step up one block while walking, like Minecraft."
	settings_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settings_vbox.add_child(settings_hint)

	character_panel = PanelContainer.new()
	character_panel.visible = false
	character_panel.anchor_left = 0.5
	character_panel.anchor_right = 0.5
	character_panel.anchor_top = 0.5
	character_panel.anchor_bottom = 0.5
	character_panel.offset_left = -390
	character_panel.offset_right = 390
	character_panel.offset_top = -255
	character_panel.offset_bottom = 255
	character_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(character_panel)

	var character_margin := MarginContainer.new()
	character_margin.add_theme_constant_override("margin_left", 14)
	character_margin.add_theme_constant_override("margin_top", 14)
	character_margin.add_theme_constant_override("margin_right", 14)
	character_margin.add_theme_constant_override("margin_bottom", 14)
	character_panel.add_child(character_margin)

	var character_hbox := HBoxContainer.new()
	character_hbox.add_theme_constant_override("separation", 16)
	character_margin.add_child(character_hbox)

	var preview_wrap := VBoxContainer.new()
	preview_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_wrap.add_theme_constant_override("separation", 8)
	character_hbox.add_child(preview_wrap)

	var preview_title := Label.new()
	preview_title.text = "Character Preview"
	preview_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_wrap.add_child(preview_title)

	character_preview_container = SubViewportContainer.new()
	character_preview_container.custom_minimum_size = Vector2(360, 420)
	character_preview_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character_preview_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_wrap.add_child(character_preview_container)

	character_preview_viewport = SubViewport.new()
	character_preview_viewport.size = Vector2i(380, 440)
	character_preview_viewport.transparent_bg = false
	character_preview_viewport.own_world_3d = true
	character_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	character_preview_container.add_child(character_preview_viewport)

	character_preview_root = Node3D.new()
	character_preview_root.name = "CharacterPreviewRoot"
	character_preview_viewport.add_child(character_preview_root)

	var preview_env := WorldEnvironment.new()
	var preview_env_res := Environment.new()
	preview_env_res.background_mode = Environment.BG_COLOR
	preview_env_res.background_color = Color(0.14, 0.15, 0.17, 1.0)
	preview_env.environment = preview_env_res
	character_preview_root.add_child(preview_env)

	character_preview_camera = Camera3D.new()
	character_preview_camera.position = Vector3(0.0, 1.14, -2.65)
	character_preview_camera.look_at(Vector3(0.0, 1.08, 0.0), Vector3.UP)
	character_preview_root.add_child(character_preview_camera)

	var preview_light := DirectionalLight3D.new()
	preview_light.light_energy = 2.2
	preview_light.rotation_degrees = Vector3(-28.0, -28.0, 0.0)
	character_preview_root.add_child(preview_light)

	var preview_fill := OmniLight3D.new()
	preview_fill.light_energy = 1.2
	preview_fill.position = Vector3(0.7, 1.6, 1.8)
	character_preview_root.add_child(preview_fill)

	var player_model_script: Script = load("res://player/PlayerModel.gd") as Script
	if player_model_script != null:
		character_preview_model = player_model_script.new()
		if character_preview_model != null:
			character_preview_root.add_child(character_preview_model)
			if character_preview_model.has_method("set_first_person_hidden"):
				character_preview_model.call("set_first_person_hidden", false)

	var character_controls := VBoxContainer.new()
	character_controls.custom_minimum_size = Vector2(280, 0)
	character_controls.add_theme_constant_override("separation", 10)
	character_hbox.add_child(character_controls)

	var character_title := Label.new()
	character_title.text = "Character Creation"
	character_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	character_controls.add_child(character_title)

	var sex_row := HBoxContainer.new()
	sex_row.add_theme_constant_override("separation", 8)
	character_controls.add_child(sex_row)
	var sex_label := Label.new()
	sex_label.text = "Body Sex"
	sex_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sex_row.add_child(sex_label)
	character_sex_option = OptionButton.new()
	character_sex_option.add_item("Male")
	character_sex_option.add_item("Female")
	character_sex_option.item_selected.connect(Callable(self, "_on_character_sex_selected"))
	sex_row.add_child(character_sex_option)

	var build_row := HBoxContainer.new()
	build_row.add_theme_constant_override("separation", 8)
	character_controls.add_child(build_row)
	var build_label := Label.new()
	build_label.text = "Body Type"
	build_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build_row.add_child(build_label)
	character_build_option = OptionButton.new()
	character_build_option.add_item("Base")
	character_build_option.add_item("Slim")
	character_build_option.add_item("Shredded")
	character_build_option.add_item("Fat")
	character_build_option.item_selected.connect(Callable(self, "_on_character_build_selected"))
	build_row.add_child(character_build_option)

	var height_box := VBoxContainer.new()
	height_box.add_theme_constant_override("separation", 4)
	character_controls.add_child(height_box)
	var height_head := HBoxContainer.new()
	height_box.add_child(height_head)
	var height_label := Label.new()
	height_label.text = "Height"
	height_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	height_head.add_child(height_label)
	character_height_value_label = Label.new()
	character_height_value_label.text = "1.00"
	height_head.add_child(character_height_value_label)
	character_height_slider = HSlider.new()
	character_height_slider.min_value = 0.82
	character_height_slider.max_value = 1.24
	character_height_slider.step = 0.01
	character_height_slider.value_changed.connect(Callable(self, "_on_character_height_changed"))
	height_box.add_child(character_height_slider)

	var width_box := VBoxContainer.new()
	width_box.add_theme_constant_override("separation", 4)
	character_controls.add_child(width_box)
	var width_head := HBoxContainer.new()
	width_box.add_child(width_head)
	var width_label := Label.new()
	width_label.text = "Width"
	width_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	width_head.add_child(width_label)
	character_width_value_label = Label.new()
	character_width_value_label.text = "1.00"
	width_head.add_child(character_width_value_label)
	character_width_slider = HSlider.new()
	character_width_slider.min_value = 0.78
	character_width_slider.max_value = 1.28
	character_width_slider.step = 0.01
	character_width_slider.value_changed.connect(Callable(self, "_on_character_width_changed"))
	width_box.add_child(character_width_slider)

	var weight_box := VBoxContainer.new()
	weight_box.add_theme_constant_override("separation", 4)
	character_controls.add_child(weight_box)
	var weight_head := HBoxContainer.new()
	weight_box.add_child(weight_head)
	var weight_label := Label.new()
	weight_label.text = "Body Weight"
	weight_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weight_head.add_child(weight_label)
	character_weight_value_label = Label.new()
	character_weight_value_label.text = "0.00"
	weight_head.add_child(character_weight_value_label)
	character_weight_slider = HSlider.new()
	character_weight_slider.min_value = -1.0
	character_weight_slider.max_value = 1.0
	character_weight_slider.step = 0.05
	character_weight_slider.value_changed.connect(Callable(self, "_on_character_weight_changed"))
	weight_box.add_child(character_weight_slider)

	var character_hint := Label.new()
	character_hint.text = "Live preview updates while you edit. Current female option uses the male base until the female model is added."
	character_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	character_controls.add_child(character_hint)

	var character_back_button := Button.new()
	character_back_button.text = "Back to Settings"
	character_back_button.pressed.connect(Callable(self, "_on_character_back_pressed"))
	character_controls.add_child(character_back_button)

	controls_panel = PanelContainer.new()
	controls_panel.anchor_left = 0.5
	controls_panel.anchor_right = 0.5
	controls_panel.anchor_top = 0.5
	controls_panel.anchor_bottom = 0.5
	controls_panel.offset_left = -260
	controls_panel.offset_right = 260
	controls_panel.offset_top = -190
	controls_panel.offset_bottom = 190
	controls_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(controls_panel)

	var controls_outer := VBoxContainer.new()
	controls_outer.add_theme_constant_override("separation", 8)
	controls_panel.add_child(controls_outer)

	var controls_title := Label.new()
	controls_title.text = "Controls"
	controls_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_outer.add_child(controls_title)

	controls_status_label = Label.new()
	controls_status_label.text = "Select an action, then press a key or mouse button."
	controls_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls_outer.add_child(controls_status_label)

	var controls_scroll := ScrollContainer.new()
	controls_scroll.custom_minimum_size = Vector2(460, 220)
	controls_outer.add_child(controls_scroll)

	controls_list = VBoxContainer.new()
	controls_list.add_theme_constant_override("separation", 6)
	controls_scroll.add_child(controls_list)

	var controls_back_button := Button.new()
	controls_back_button.text = "Back"
	controls_back_button.pressed.connect(Callable(self, "_on_controls_back_pressed"))
	controls_outer.add_child(controls_back_button)

	cursor_panel = PanelContainer.new()
	cursor_panel.visible = false
	cursor_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cursor_panel)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	cursor_panel.add_child(hb)

	cursor_icon = ColorRect.new()
	cursor_icon.custom_minimum_size = Vector2(18, 18)
	hb.add_child(cursor_icon)

	cursor_label = Label.new()
	hb.add_child(cursor_label)

	death_panel = PanelContainer.new()
	death_panel.visible = false
	death_panel.anchor_left = 0.5
	death_panel.anchor_right = 0.5
	death_panel.anchor_top = 0.5
	death_panel.anchor_bottom = 0.5
	death_panel.offset_left = -170
	death_panel.offset_right = 170
	death_panel.offset_top = -100
	death_panel.offset_bottom = 100
	death_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(death_panel)

	var death_vbox := VBoxContainer.new()
	death_vbox.add_theme_constant_override("separation", 10)
	death_panel.add_child(death_vbox)

	var death_title := Label.new()
	death_title.text = "You Died"
	death_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_vbox.add_child(death_title)

	var respawn_button := Button.new()
	respawn_button.text = "Respawn"
	respawn_button.pressed.connect(Callable(self, "_on_respawn_pressed"))
	death_vbox.add_child(respawn_button)

	var return_button := Button.new()
	return_button.text = "Return to Main Menu"
	return_button.pressed.connect(Callable(self, "_on_return_to_menu_pressed"))
	death_vbox.add_child(return_button)

func _connect_signals() -> void:
	if player == null:
		return
	if not player.inventory_changed.is_connected(Callable(self, "_on_inventory_changed")):
		player.inventory_changed.connect(Callable(self, "_on_inventory_changed"))
	if not player.hotbar_selected_changed.is_connected(Callable(self, "_on_hotbar_selected")):
		player.hotbar_selected_changed.connect(Callable(self, "_on_hotbar_selected"))
	if not player.inventory_opened.is_connected(Callable(self, "_on_inventory_opened")):
		player.inventory_opened.connect(Callable(self, "_on_inventory_opened"))
	if not player.settings_opened.is_connected(Callable(self, "_on_settings_opened")):
		player.settings_opened.connect(Callable(self, "_on_settings_opened"))
	if not player.chat_opened.is_connected(Callable(self, "_on_chat_opened")):
		player.chat_opened.connect(Callable(self, "_on_chat_opened"))
	if not player.health_changed.is_connected(Callable(self, "_on_health_changed")):
		player.health_changed.connect(Callable(self, "_on_health_changed"))
	if not player.hunger_changed.is_connected(Callable(self, "_on_hunger_changed")):
		player.hunger_changed.connect(Callable(self, "_on_hunger_changed"))
	if not player.thirst_changed.is_connected(Callable(self, "_on_thirst_changed")):
		player.thirst_changed.connect(Callable(self, "_on_thirst_changed"))
	if not player.auto_step_changed.is_connected(Callable(self, "_on_auto_step_changed")):
		player.auto_step_changed.connect(Callable(self, "_on_auto_step_changed"))
	if not player.walk_mode_changed.is_connected(Callable(self, "_on_walk_mode_changed")):
		player.walk_mode_changed.connect(Callable(self, "_on_walk_mode_changed"))
	if not player.camera_mode_changed.is_connected(Callable(self, "_on_camera_mode_changed")):
		player.camera_mode_changed.connect(Callable(self, "_on_camera_mode_changed"))
	if not player.appearance_changed.is_connected(Callable(self, "_on_appearance_changed")):
		player.appearance_changed.connect(Callable(self, "_on_appearance_changed"))
	if not player.died.is_connected(Callable(self, "_on_player_died")):
		player.died.connect(Callable(self, "_on_player_died"))
	if not player.crafting_table_opened.is_connected(Callable(self, "_on_crafting_table_opened")):
		player.crafting_table_opened.connect(Callable(self, "_on_crafting_table_opened"))

func _connect_chat_bus() -> void:
	var game_node: Node = _get_game()
	if game_node == null:
		return
	var chat_bus_v: Variant = game_node.get("chat_bus")
	if chat_bus_v is KZ_ChatBus:
		var bus: KZ_ChatBus = chat_bus_v as KZ_ChatBus
		if not bus.message_posted.is_connected(Callable(self, "_on_chat_message_posted")):
			bus.message_posted.connect(Callable(self, "_on_chat_message_posted"))

func _get_game() -> Node:
	return get_node_or_null("/root/Game")

func _on_inventory_changed() -> void:
	_refresh_all()

func _on_hotbar_selected(_idx: int) -> void:
	_refresh_hotbar()

func _on_inventory_opened(open: bool) -> void:
	_set_inventory_open(open)
	if not open:
		_end_drag()
	_refresh_all()

func _on_settings_opened(open: bool) -> void:
	_set_settings_open(open)
	if open:
		_end_drag()
		_refresh_render_distance()
		_refresh_fov()
		_refresh_max_fps()
		_refresh_character_controls_from_player()
		_refresh_character_preview()
	else:
		_set_controls_open(false)
		_set_character_open(false)

func _on_chat_opened(open: bool) -> void:
	_set_chat_open(open)

func _on_health_changed(current: float, max_value: float) -> void:
	_refresh_health(current, max_value)

func _on_hunger_changed(current: float, max_value: float) -> void:
	_refresh_hunger(current, max_value)

func _on_thirst_changed(current: float, max_value: float) -> void:
	_refresh_thirst(current, max_value)

func _on_auto_step_changed(enabled: bool) -> void:
	auto_step_check.set_pressed_no_signal(enabled)

func _on_walk_mode_changed(mode_name: String) -> void:
	_refresh_walk_mode(mode_name)

func _on_camera_mode_changed(mode_name: String) -> void:
	_refresh_camera_mode(mode_name)

func _on_appearance_changed(_profile: Dictionary) -> void:
	_refresh_character_controls_from_player()
	_refresh_character_preview()

func _on_player_died() -> void:
	death_panel.visible = true
	crosshair.visible = false
	chat_input_panel.visible = false
	inv_panel.visible = false
	settings_panel.visible = false
	controls_panel.visible = false
	if character_panel != null:
		character_panel.visible = false
	cursor_panel.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE as Input.MouseMode)

func _on_crafting_table_opened(open: bool) -> void:
	crafting_table_panel.visible = open
	if open:
		# Keep only the backpack/hotbar visible while the table is open.
		inv_panel.visible = true
		inv_panel.offset_top = 56
		inv_panel.offset_bottom = 300
		if inv_grid_spacer != null:
			inv_grid_spacer.custom_minimum_size = Vector2(0, 28)
		if inventory_craft_row != null:
			inventory_craft_row.visible = false
		if inventory_craft_hint != null:
			inventory_craft_hint.visible = false
		if creative_panel != null:
			creative_panel.visible = false
		settings_panel.visible = false
		controls_panel.visible = false
		if character_panel != null:
			character_panel.visible = false
		chat_input_panel.visible = false
		crosshair.visible = false
		hotbar_box.offset_top = -74
		hotbar_box.offset_bottom = -16
		_refresh_all()
	else:
		_return_crafting_items_to_inventory(true)
		inv_panel.offset_top = -210
		inv_panel.offset_bottom = 160
		if inv_grid_spacer != null:
			inv_grid_spacer.custom_minimum_size = Vector2(0, 12)
		if inventory_craft_row != null:
			inventory_craft_row.visible = true
		if inventory_craft_hint != null:
			inventory_craft_hint.visible = true
		hotbar_box.offset_top = -70
		hotbar_box.offset_bottom = -12
		crosshair.visible = not player.inventory_is_open and not player.chat_is_open and not player.settings_is_open and not player.is_dead

func _set_inventory_open(open: bool) -> void:
	inv_panel.visible = open
	if open:
		settings_panel.visible = false
		controls_panel.visible = false
		if character_panel != null:
			character_panel.visible = false
		chat_input_panel.visible = false
		crafting_table_panel.visible = false
		var creative_mode: bool = _is_creative_mode()
		if inventory_craft_row != null:
			inventory_craft_row.visible = not creative_mode
		if inventory_craft_hint != null:
			inventory_craft_hint.visible = false
		if creative_panel != null:
			creative_panel.visible = creative_mode
			if creative_mode:
				_refresh_creative_catalog()
		inv_panel.offset_top = -210
		inv_panel.offset_bottom = 160
		if inv_grid_spacer != null:
			inv_grid_spacer.custom_minimum_size = Vector2(0, 12)
		crosshair.visible = false
		hotbar_box.offset_top = -74
		hotbar_box.offset_bottom = -16
	else:
		_return_crafting_items_to_inventory(false)
		if creative_panel != null:
			creative_panel.visible = false
		crosshair.visible = not player.settings_is_open and not player.chat_is_open and not player.is_dead
		hotbar_box.offset_top = -70
		hotbar_box.offset_bottom = -12

func _set_settings_open(open: bool) -> void:
	settings_panel.visible = open
	if character_panel != null:
		character_panel.visible = false
	if open:
		inv_panel.visible = false
		controls_panel.visible = false
		crafting_table_panel.visible = false
		if creative_panel != null:
			creative_panel.visible = false
		crosshair.visible = false
	else:
		crosshair.visible = not player.inventory_is_open and not player.chat_is_open and not player.is_dead

func _set_controls_open(open: bool) -> void:
	controls_panel.visible = open
	if open:
		settings_panel.visible = false
		if character_panel != null:
			character_panel.visible = false
		inv_panel.visible = false
		crafting_table_panel.visible = false
		if creative_panel != null:
			creative_panel.visible = false
		crosshair.visible = false
	else:
		crosshair.visible = not player.inventory_is_open and not player.chat_is_open and not player.settings_is_open and not player.is_dead

func _set_chat_open(open: bool) -> void:
	chat_input_panel.visible = open
	if open:
		_last_chat_activity_ms = Time.get_ticks_msec()
		if chat_panel != null:
			chat_panel.visible = true
		crafting_table_panel.visible = false
		if character_panel != null:
			character_panel.visible = false
		if creative_panel != null:
			creative_panel.visible = false
		crosshair.visible = false
		call_deferred("_focus_chat_input")
	else:
		chat_input.release_focus()
		chat_input.text = ""
		crosshair.visible = not player.inventory_is_open and not player.settings_is_open and not player.is_dead

func _focus_chat_input() -> void:
	chat_input.grab_focus()
	chat_input.caret_column = chat_input.text.length()

func _refresh_health(current: float, max_value: float) -> void:
	health_bar.max_value = max_value
	health_bar.value = current
	health_label.text = "Health %d / %d" % [int(round(current)), int(round(max_value))]

func _refresh_hunger(current: float, max_value: float) -> void:
	hunger_bar.max_value = max_value
	hunger_bar.value = current
	hunger_label.text = "Hunger %d / %d" % [int(round(current)), int(round(max_value))]

func _refresh_thirst(current: float, max_value: float) -> void:
	thirst_bar.max_value = max_value
	thirst_bar.value = current
	thirst_label.text = "Thirst %d / %d" % [int(round(current)), int(round(max_value))]

func _refresh_walk_mode(mode_name: String) -> void:
	if walk_mode_label != null:
		walk_mode_label.text = mode_name

func _refresh_camera_mode(mode_name: String) -> void:
	if camera_mode_label != null:
		camera_mode_label.text = mode_name

func _refresh_render_distance() -> void:
	var game_node: Node = _get_game()
	if game_node != null and game_node.has_method("get_render_distance") and render_distance_spin != null:
		var current_v: Variant = game_node.call("get_render_distance")
		render_distance_spin.set_value_no_signal(float(int(current_v)))

func _refresh_fov() -> void:
	var game_node: Node = _get_game()
	if game_node != null and game_node.has_method("get_fov") and fov_spin != null:
		var current_v: Variant = game_node.call("get_fov")
		fov_spin.set_value_no_signal(float(current_v))

func _refresh_max_fps() -> void:
	var game_node: Node = _get_game()
	if game_node != null and game_node.has_method("get_max_fps") and max_fps_spin != null:
		var current_v: Variant = game_node.call("get_max_fps")
		max_fps_spin.set_value_no_signal(float(int(current_v)))

func _refresh_character_controls_from_player() -> void:
	if player == null:
		return
	var profile: Dictionary = player.get_character_appearance()
	var sex: String = str(profile.get("sex", "male")).to_lower()
	var build: String = str(profile.get("build", "base")).to_lower()
	var height_scale: float = float(profile.get("height_scale", 1.0))
	var width_scale: float = float(profile.get("width_scale", 1.0))
	var body_weight: float = float(profile.get("body_weight", 0.0))
	if character_sex_option != null:
		character_sex_option.select(1 if sex == "female" else 0)
	if character_build_option != null:
		var build_idx: int = 0
		match build:
			"slim":
				build_idx = 1
			"shredded":
				build_idx = 2
			"fat":
				build_idx = 3
			_:
				build_idx = 0
		character_build_option.select(build_idx)
	if character_height_slider != null:
		character_height_slider.set_value_no_signal(height_scale)
	if character_width_slider != null:
		character_width_slider.set_value_no_signal(width_scale)
	if character_weight_slider != null:
		character_weight_slider.set_value_no_signal(body_weight)
	_update_character_value_labels()

func _update_character_value_labels() -> void:
	if character_height_value_label != null and character_height_slider != null:
		character_height_value_label.text = "%.2f" % character_height_slider.value
	if character_width_value_label != null and character_width_slider != null:
		character_width_value_label.text = "%.2f" % character_width_slider.value
	if character_weight_value_label != null and character_weight_slider != null:
		character_weight_value_label.text = "%.2f" % character_weight_slider.value

func _refresh_character_preview() -> void:
	if character_preview_model == null or player == null:
		return
	var app_script: Script = load("res://player/CharacterAppearance.gd") as Script
	if app_script == null:
		return
	var preview_profile: RefCounted = app_script.new()
	if preview_profile != null and preview_profile.has_method("apply_dict"):
		preview_profile.call("apply_dict", player.get_character_appearance())
		if character_preview_model.has_method("set_appearance_profile"):
			character_preview_model.call("set_appearance_profile", preview_profile)
		elif character_preview_model.has_method("apply_profile"):
			character_preview_model.call("apply_profile")
	if character_preview_model.has_method("set_first_person_hidden"):
		character_preview_model.call("set_first_person_hidden", false)

func _apply_character_ui_changes() -> void:
	if player == null:
		return
	var profile: Dictionary = player.get_character_appearance()
	if character_sex_option != null:
		profile["sex"] = "female" if character_sex_option.selected == 1 else "male"
	if character_build_option != null:
		match character_build_option.selected:
			1:
				profile["build"] = "slim"
			2:
				profile["build"] = "shredded"
			3:
				profile["build"] = "fat"
			_:
				profile["build"] = "base"
	if character_height_slider != null:
		profile["height_scale"] = character_height_slider.value
	if character_width_slider != null:
		profile["width_scale"] = character_width_slider.value
	if character_weight_slider != null:
		profile["body_weight"] = character_weight_slider.value
	_update_character_value_labels()
	player.apply_character_appearance(profile)

func _set_character_open(open: bool) -> void:
	if character_panel == null:
		return
	character_panel.visible = open
	if open:
		settings_panel.visible = false
		controls_panel.visible = false
		inv_panel.visible = false
		crafting_table_panel.visible = false
		if creative_panel != null:
			creative_panel.visible = false
		crosshair.visible = false
		_refresh_character_controls_from_player()
		_refresh_character_preview()
	else:
		if player != null and player.settings_is_open:
			settings_panel.visible = true
		if player != null:
			crosshair.visible = not player.inventory_is_open and not player.chat_is_open and not player.settings_is_open and not player.is_dead
		else:
			crosshair.visible = true

func _refresh_all() -> void:
	_refresh_hotbar()
	_refresh_inventory()
	_refresh_crafting_views()
	_refresh_creative_view()
	_refresh_cursor()

func _refresh_hotbar() -> void:
	var inv: KZ_Inventory = player.inventory
	for i in range(KZ_Inventory.HOTBAR_SIZE):
		var id: String = inv.hotbar_ids[i]
		var c: int = inv.hotbar_counts[i]
		var tint: Color = _tint_for_id(id)
		var sel: bool = (i == inv.selected_index)
		hotbar_slots[i].set_visual(id, c, tint, sel, _preview_for_item(id))
		hotbar_slots[i].tooltip_text = _tooltip_for_item(id)

func _refresh_inventory() -> void:
	var inv: KZ_Inventory = player.inventory
	for j in range(KZ_Inventory.INV_SIZE):
		var id: String = inv.inv_ids[j]
		var c: int = inv.inv_counts[j]
		var tint: Color = _tint_for_id(id)
		inv_slots[j].set_visual(id, c, tint, false, _preview_for_item(id))
		inv_slots[j].tooltip_text = _tooltip_for_item(id)

func _refresh_crafting_views() -> void:
	_refresh_craft_result(2)
	_refresh_craft_result(3)
	for i in range(craft2_slots.size()):
		var id: String = craft2_ids[i]
		var count: int = craft2_counts[i]
		craft2_slots[i].set_visual(id, count, _tint_for_id(id), false, _preview_for_item(id))
		craft2_slots[i].tooltip_text = _tooltip_for_item(id)
	if craft2_result_slot != null:
		craft2_result_slot.set_visual(craft2_result_id, craft2_result_count, _tint_for_id(craft2_result_id), false, _preview_for_item(craft2_result_id))
		craft2_result_slot.tooltip_text = _tooltip_for_item(craft2_result_id)
	for j in range(craft3_slots.size()):
		var id3: String = craft3_ids[j]
		var count3: int = craft3_counts[j]
		craft3_slots[j].set_visual(id3, count3, _tint_for_id(id3), false, _preview_for_item(id3))
		craft3_slots[j].tooltip_text = _tooltip_for_item(id3)
	if craft3_result_slot != null:
		craft3_result_slot.set_visual(craft3_result_id, craft3_result_count, _tint_for_id(craft3_result_id), false, _preview_for_item(craft3_result_id))
		craft3_result_slot.tooltip_text = _tooltip_for_item(craft3_result_id)

func _refresh_craft_result(grid_size: int) -> void:
	var game_node: Node = _get_game()
	if game_node == null or not game_node.has_method("try_craft_items"):
		return
	if grid_size == 2:
		var result_v: Variant = game_node.call("try_craft_items", craft2_ids, craft2_counts, 2, 2)
		if typeof(result_v) == TYPE_DICTIONARY:
			var result: Dictionary = result_v as Dictionary
			craft2_result_id = str(result.get("item_id", ""))
			craft2_result_count = int(result.get("count", 0))
			craft2_consume_slots.clear()
			for consume_v in result.get("consume", []):
				craft2_consume_slots.append(int(consume_v))
	else:
		var result_v3: Variant = game_node.call("try_craft_items", craft3_ids, craft3_counts, 3, 3)
		if typeof(result_v3) == TYPE_DICTIONARY:
			var result3: Dictionary = result_v3 as Dictionary
			craft3_result_id = str(result3.get("item_id", ""))
			craft3_result_count = int(result3.get("count", 0))
			craft3_consume_slots.clear()
			for consume_v3 in result3.get("consume", []):
				craft3_consume_slots.append(int(consume_v3))

func _return_crafting_items_to_inventory(include_table: bool) -> void:
	var game_node: Node = _get_game()
	for i in range(craft2_ids.size()):
		if craft2_ids[i] != "" and craft2_counts[i] > 0:
			var item_id: String = craft2_ids[i]
			var count: int = craft2_counts[i]
			var remaining: int = player.inventory.add_item(item_id, count)
			if remaining > 0 and game_node != null and game_node.has_method("spawn_dropped_item"):
				game_node.call("spawn_dropped_item", item_id, remaining, player.global_position + Vector3(0.0, 0.8, 0.0))
			craft2_ids[i] = ""
			craft2_counts[i] = 0
	if include_table:
		for j in range(craft3_ids.size()):
			if craft3_ids[j] != "" and craft3_counts[j] > 0:
				var item_id3: String = craft3_ids[j]
				var count3: int = craft3_counts[j]
				var remaining3: int = player.inventory.add_item(item_id3, count3)
				if remaining3 > 0 and game_node != null and game_node.has_method("spawn_dropped_item"):
					game_node.call("spawn_dropped_item", item_id3, remaining3, player.global_position + Vector3(0.0, 0.8, 0.0))
				craft3_ids[j] = ""
				craft3_counts[j] = 0
	_refresh_crafting_views()
	player.emit_signal("inventory_changed")

func _is_craft_slot(g: int) -> bool:
	return (g >= CRAFT2_BASE and g < CRAFT2_BASE + 4) or g == CRAFT2_RESULT or (g >= CRAFT3_BASE and g < CRAFT3_BASE + 9) or g == CRAFT3_RESULT

func _get_custom_slot_id(g: int) -> String:
	if g >= CRAFT2_BASE and g < CRAFT2_BASE + 4:
		return craft2_ids[g - CRAFT2_BASE]
	if g >= CRAFT3_BASE and g < CRAFT3_BASE + 9:
		return craft3_ids[g - CRAFT3_BASE]
	if g == CRAFT2_RESULT:
		return craft2_result_id
	if g == CRAFT3_RESULT:
		return craft3_result_id
	return ""

func _get_custom_slot_count(g: int) -> int:
	if g >= CRAFT2_BASE and g < CRAFT2_BASE + 4:
		return craft2_counts[g - CRAFT2_BASE]
	if g >= CRAFT3_BASE and g < CRAFT3_BASE + 9:
		return craft3_counts[g - CRAFT3_BASE]
	if g == CRAFT2_RESULT:
		return craft2_result_count
	if g == CRAFT3_RESULT:
		return craft3_result_count
	return 0

func _set_custom_slot(g: int, item_id: String, count: int) -> void:
	if g >= CRAFT2_BASE and g < CRAFT2_BASE + 4:
		craft2_ids[g - CRAFT2_BASE] = item_id if count > 0 else ""
		craft2_counts[g - CRAFT2_BASE] = max(0, count)
	elif g >= CRAFT3_BASE and g < CRAFT3_BASE + 9:
		craft3_ids[g - CRAFT3_BASE] = item_id if count > 0 else ""
		craft3_counts[g - CRAFT3_BASE] = max(0, count)
	_refresh_crafting_views()

func _consume_recipe_inputs(grid_size: int) -> void:
	var consume: Array = craft2_consume_slots if grid_size == 2 else craft3_consume_slots
	for idx_v in consume:
		var idx: int = int(idx_v)
		if grid_size == 2:
			if idx >= 0 and idx < craft2_ids.size() and craft2_counts[idx] > 0:
				craft2_counts[idx] -= 1
				if craft2_counts[idx] <= 0:
					craft2_counts[idx] = 0
					craft2_ids[idx] = ""
		else:
			if idx >= 0 and idx < craft3_ids.size() and craft3_counts[idx] > 0:
				craft3_counts[idx] -= 1
				if craft3_counts[idx] <= 0:
					craft3_counts[idx] = 0
					craft3_ids[idx] = ""
	_refresh_crafting_views()

func _take_crafting_result(grid_size: int) -> void:
	var result_id: String = craft2_result_id if grid_size == 2 else craft3_result_id
	var result_count: int = craft2_result_count if grid_size == 2 else craft3_result_count
	if result_id == "" or result_count <= 0:
		return
	var max_stack: int = player.inventory.max_stack_for(result_id)
	if player.cursor_item_id != "" and player.cursor_item_id != result_id:
		return
	if player.cursor_item_id == result_id and player.cursor_count + result_count > max_stack:
		return
	if player.cursor_item_id == "":
		player.cursor_item_id = result_id
		player.cursor_count = result_count
	else:
		player.cursor_count += result_count
	_consume_recipe_inputs(grid_size)
	player.emit_signal("inventory_changed")

func _refresh_cursor() -> void:
	if player.cursor_item_id == "" or player.cursor_count <= 0:
		cursor_icon.color = Color(0, 0, 0, 0)
		cursor_label.text = ""
		return
	cursor_icon.color = _tint_for_id(player.cursor_item_id)
	cursor_label.text = "%s x%d" % [_display_item_name(player.cursor_item_id), player.cursor_count]

func _is_creative_mode() -> bool:
	var game_node: Node = _get_game()
	return game_node != null and game_node.has_method("is_creative_mode") and bool(game_node.call("is_creative_mode"))

func _refresh_creative_catalog() -> void:
	creative_entries.clear()
	creative_filtered_entries.clear()
	var game_node: Node = _get_game()
	if game_node == null or not game_node.has_method("get_registry_entries"):
		return
	var entries_v: Variant = game_node.call("get_registry_entries")
	if typeof(entries_v) != TYPE_ARRAY:
		return
	var entries: Array = entries_v as Array
	for entry_v in entries:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_v as Dictionary
		var sid: String = str(entry.get("string_id", ""))
		if sid == "" or sid == "kaizencraft:air":
			continue
		creative_entries.append(entry)
	creative_entries.sort_custom(Callable(self, "_compare_creative_entries"))
	for entry in creative_entries:
		var category_name: String = str((entry as Dictionary).get("category", "Blocks"))
		if creative_category != "All" and category_name != creative_category:
			continue
		creative_filtered_entries.append(entry)
	var page_count: int = maxi(1, int(ceil(float(creative_filtered_entries.size()) / float(maxi(1, creative_slots.size())))))
	creative_page = clampi(creative_page, 0, page_count - 1)
	_refresh_creative_view()

func _refresh_creative_view() -> void:
	var page_size: int = maxi(1, creative_slots.size())
	var page_count: int = maxi(1, int(ceil(float(creative_filtered_entries.size()) / float(page_size))))
	creative_page = clampi(creative_page, 0, page_count - 1)
	if creative_page_label != null:
		creative_page_label.text = "%s %d/%d" % [creative_category, creative_page + 1, page_count]
	if creative_prev_button != null:
		creative_prev_button.disabled = creative_page <= 0
	if creative_next_button != null:
		creative_next_button.disabled = creative_page >= page_count - 1
	if creative_tabs != null:
		for child in creative_tabs.get_children():
			if child is Button:
				var child_btn: Button = child as Button
				child_btn.set_pressed_no_signal(child_btn.text == creative_category)
	var start_index: int = creative_page * page_size
	for i in range(creative_slots.size()):
		var btn: KZ_SlotButton = creative_slots[i]
		var entry_index: int = start_index + i
		if entry_index < creative_filtered_entries.size():
			var entry: Dictionary = creative_filtered_entries[entry_index] as Dictionary
			var sid: String = str(entry.get("string_id", ""))
			btn.visible = true
			btn.set_visual(sid, 1, _tint_for_id(sid), false, _preview_for_item(sid))
			btn.tooltip_text = _tooltip_for_item(sid)
		else:
			btn.visible = false
			btn.tooltip_text = ""

func _is_creative_slot(g: int) -> bool:
	return g >= CREATIVE_BASE and g < CREATIVE_BASE + creative_slots.size()

func _handle_creative_slot_click(g: int, button_index: int) -> void:
	var idx: int = g - CREATIVE_BASE + creative_page * maxi(1, creative_slots.size())
	if idx < 0 or idx >= creative_filtered_entries.size():
		return
	var entry: Dictionary = creative_filtered_entries[idx] as Dictionary
	var sid: String = str(entry.get("string_id", ""))
	if sid == "":
		return
	var count: int = 1 if button_index == MouseButton.MOUSE_BUTTON_RIGHT else player.inventory.max_stack_for(sid)
	player.cursor_item_id = sid
	player.cursor_count = max(1, count)
	player.emit_signal("inventory_changed")

func _refresh_controls_ui() -> void:
	for child in controls_list.get_children():
		child.queue_free()
	control_buttons.clear()
	var game_node: Node = _get_game()
	if game_node == null or not game_node.has_method("get_bindable_actions"):
		return
	var actions_v: Variant = game_node.call("get_bindable_actions")
	if typeof(actions_v) != TYPE_ARRAY:
		return
	var actions: Array = actions_v as Array
	for entry_v in actions:
		if typeof(entry_v) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_v as Dictionary
		var action: String = str(entry.get("action", ""))
		var label_txt: String = str(entry.get("label", action))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		controls_list.add_child(row)

		var lbl := Label.new()
		lbl.text = label_txt
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)

		var btn := Button.new()
		btn.text = game_node.call("get_action_binding_text", action)
		btn.custom_minimum_size = Vector2(180, 0)
		btn.pressed.connect(Callable(self, "_on_control_bind_button_pressed").bind(action))
		row.add_child(btn)
		control_buttons[action] = btn

func _compare_creative_entries(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("order", 999999)) < int(b.get("order", 999999))

func _on_creative_category_pressed(category_name: String) -> void:
	creative_category = category_name
	creative_page = 0
	_refresh_creative_catalog()

func _on_creative_prev_pressed() -> void:
	creative_page = maxi(0, creative_page - 1)
	_refresh_creative_view()

func _on_creative_next_pressed() -> void:
	creative_page += 1
	_refresh_creative_view()

func _load_preview_texture(path: String) -> Texture2D:
	if path == "":
		return null
	if _texture_cache.has(path):
		return _texture_cache[path] as Texture2D
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path) as Texture2D
	_texture_cache[path] = tex
	return tex

func _preview_for_item(item_id: String) -> Dictionary:
	if item_id == "" or registry == null:
		return {}
	var paths: Dictionary = registry.get_preview_paths(item_id)
	if paths.is_empty():
		return {}
	var top_path: String = str(paths.get("top", ""))
	var side_path: String = str(paths.get("side", ""))
	var all_path: String = str(paths.get("all", ""))
	var front_path: String = side_path if side_path != "" else all_path
	if front_path == "":
		front_path = top_path
	return {
		"mode": str(paths.get("mode", "item")),
		"top_tex": _load_preview_texture(top_path),
		"side_tex": _load_preview_texture(side_path if side_path != "" else all_path),
		"front_tex": _load_preview_texture(front_path)
	}

func _tooltip_for_item(item_id: String) -> String:
	if item_id == "":
		return ""
	var rid: int = registry.get_numeric_id(item_id) if registry != null else 0
	return "%s\n%s\n#%d" % [_display_item_name(item_id), item_id, rid]

func _tint_for_id(item_id: String) -> Color:
	if item_id == "":
		return Color(0, 0, 0, 0)
	if registry == null:
		return Color(1, 1, 1, 1)
	var rid: int = registry.get_runtime_id(item_id)
	var def: KZ_BlockRegistry.BlockDef = registry.get_def_by_runtime(rid)
	return def.tint if def != null else Color(1, 1, 1, 1)

func _display_item_name(item_id: String) -> String:
	if item_id == "":
		return ""
	if registry != null:
		var rid: int = registry.get_runtime_id(item_id)
		var def: KZ_BlockRegistry.BlockDef = registry.get_def_by_runtime(rid)
		if def != null and def.name != "":
			return def.name
	var short_id: String = item_id.get_slice(":", 1)
	return short_id.capitalize() if short_id != "" else item_id

func _on_auto_step_toggled(enabled: bool) -> void:
	player.set_auto_step_enabled(enabled)

func _on_render_distance_changed(value: float) -> void:
	var game_node: Node = _get_game()
	if game_node != null and game_node.has_method("set_render_distance"):
		game_node.call("set_render_distance", int(round(value)))

func _on_fov_changed(value: float) -> void:
	var game_node: Node = _get_game()
	if game_node != null and game_node.has_method("set_fov"):
		game_node.call("set_fov", value)

func _on_max_fps_changed(value: float) -> void:
	var game_node: Node = _get_game()
	if game_node != null and game_node.has_method("set_max_fps"):
		game_node.call("set_max_fps", value)

func _on_character_button_pressed() -> void:
	_set_character_open(true)

func _on_character_back_pressed() -> void:
	_set_character_open(false)
	if player != null and player.settings_is_open:
		settings_panel.visible = true

func _on_character_sex_selected(_idx: int) -> void:
	_apply_character_ui_changes()

func _on_character_build_selected(_idx: int) -> void:
	_apply_character_ui_changes()

func _on_character_height_changed(_value: float) -> void:
	_apply_character_ui_changes()

func _on_character_width_changed(_value: float) -> void:
	_apply_character_ui_changes()

func _on_character_weight_changed(_value: float) -> void:
	_apply_character_ui_changes()

func _on_controls_button_pressed() -> void:
	controls_status_label.text = "Select an action, then press a key or mouse button."
	_set_controls_open(true)
	_refresh_controls_ui()

func _on_controls_back_pressed() -> void:
	_capturing_action = ""
	controls_status_label.text = "Select an action, then press a key or mouse button."
	_set_controls_open(false)
	_set_settings_open(true)

func _on_control_bind_button_pressed(action: String) -> void:
	_capturing_action = action
	controls_status_label.text = "Press a key or mouse button for %s. ESC cancels." % action

func _on_back_to_game_pressed() -> void:
	player._set_settings_open(false)

func _on_save_return_pressed() -> void:
	var game_node: Node = _get_game()
	if game_node != null and game_node.has_method("save_and_return_to_main_menu"):
		game_node.call("save_and_return_to_main_menu")

func _on_respawn_pressed() -> void:
	var game_node: Node = _get_game()
	if game_node != null and game_node.has_method("respawn_player"):
		game_node.call("respawn_player")
	death_panel.visible = false
	crosshair.visible = true

func _on_return_to_menu_pressed() -> void:
	var game_node: Node = _get_game()
	if game_node != null and game_node.has_method("save_and_return_to_main_menu"):
		game_node.call("save_and_return_to_main_menu")

func _open_chat(prefill: String) -> void:
	player.set_chat_open(true)
	chat_input.text = prefill
	_set_chat_open(true)

func _on_chat_text_submitted(text: String) -> void:
	var game_node: Node = _get_game()
	if game_node != null and game_node.has_method("send_chat_text"):
		game_node.call("send_chat_text", text)
	_set_chat_open(false)
	player.set_chat_open(false)

func _on_chat_message_posted(packet: Dictionary) -> void:
	_last_chat_activity_ms = Time.get_ticks_msec()
	if chat_panel != null:
		chat_panel.visible = true
	var game_node: Node = _get_game()
	if game_node == null:
		return
	var chat_bus_v: Variant = game_node.get("chat_bus")
	if not (chat_bus_v is KZ_ChatBus):
		return
	var bus: KZ_ChatBus = chat_bus_v as KZ_ChatBus
	if not bus.should_deliver(packet, str(game_node.get("world_name")), player.global_position):
		return
	var kind: String = str(packet.get("kind", "text"))
	var line: String = ""
	if kind == "system":
		line = "[System] %s" % str(packet.get("text", ""))
	else:
		line = "<%s> %s" % [str(packet.get("sender_name", "Player")), str(packet.get("text", ""))]
	_chat_lines.append(line)
	while _chat_lines.size() > 8:
		_chat_lines.pop_front()
	chat_log.clear()
	chat_log.append_text("\n".join(_chat_lines))

func _on_slot_gui_input(event: InputEvent, g: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb.is_echo():
		return

	if _is_creative_slot(g):
		if Input.is_mouse_button_pressed(MouseButton.MOUSE_BUTTON_LEFT):
			_handle_creative_slot_click(g, MouseButton.MOUSE_BUTTON_LEFT)
			get_viewport().set_input_as_handled()
		elif Input.is_mouse_button_pressed(MouseButton.MOUSE_BUTTON_RIGHT):
			_handle_creative_slot_click(g, MouseButton.MOUSE_BUTTON_RIGHT)
			get_viewport().set_input_as_handled()
		return

	if _is_craft_slot(g):
		if not mb.pressed:
			return
		if mb.button_index == MouseButton.MOUSE_BUTTON_LEFT:
			if g == CRAFT2_RESULT:
				_take_crafting_result(2)
			elif g == CRAFT3_RESULT:
				_take_crafting_result(3)
			else:
				_handle_left_click_custom_slot(g)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MouseButton.MOUSE_BUTTON_RIGHT:
			if g != CRAFT2_RESULT and g != CRAFT3_RESULT:
				_handle_right_click_custom_slot(g)
				get_viewport().set_input_as_handled()
		return

	if player.inventory_is_open or player.crafting_table_is_open:
		if mb.button_index == MouseButton.MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if mb.double_click:
					_handle_double_left_click_on_slot(g)
					_end_drag()
					get_viewport().set_input_as_handled()
					return
				_drag_button = MouseButton.MOUSE_BUTTON_LEFT
				_drag_from_cursor = player.cursor_item_id != "" and player.cursor_count > 0
				_drag_visited.clear()
				_drag_slots.clear()
				_mark_drag_slot(g)
				if not _drag_from_cursor:
					_handle_left_click_on_slot(g)
				get_viewport().set_input_as_handled()
			else:
				_finalize_drag(MouseButton.MOUSE_BUTTON_LEFT)
		elif mb.button_index == MouseButton.MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_drag_button = MouseButton.MOUSE_BUTTON_RIGHT
				_drag_from_cursor = false
				_drag_visited.clear()
				_drag_slots.clear()
				_handle_right_click_on_slot(g)
				_mark_drag_slot(g)
				get_viewport().set_input_as_handled()
			else:
				_finalize_drag(MouseButton.MOUSE_BUTTON_RIGHT)
		return

	if g < 0 or g >= KZ_Inventory.HOTBAR_SIZE:
		return
	if not mb.pressed or mb.button_index != MouseButton.MOUSE_BUTTON_LEFT:
		return

	player.inventory.set_selected(g)
	player.emit_signal("hotbar_selected_changed", g)
	_refresh_hotbar()
	get_viewport().set_input_as_handled()

func _on_slot_mouse_entered(g: int) -> void:
	if player == null:
		return
	if _is_creative_slot(g):
		if Input.is_mouse_button_pressed(MouseButton.MOUSE_BUTTON_LEFT):
			_handle_creative_slot_click(g, MouseButton.MOUSE_BUTTON_LEFT)
			get_viewport().set_input_as_handled()
		elif Input.is_mouse_button_pressed(MouseButton.MOUSE_BUTTON_RIGHT):
			_handle_creative_slot_click(g, MouseButton.MOUSE_BUTTON_RIGHT)
			get_viewport().set_input_as_handled()
		return

	if _is_creative_slot(g) or _is_craft_slot(g):
		return
	if not player.inventory_is_open and not player.crafting_table_is_open:
		return
	if _drag_button == MouseButton.MOUSE_BUTTON_LEFT and _drag_from_cursor:
		_mark_drag_slot(g)
		return
	if _drag_button == MouseButton.MOUSE_BUTTON_RIGHT:
		if _drag_visited.has(g):
			return
		if not Input.is_mouse_button_pressed(MouseButton.MOUSE_BUTTON_RIGHT):
			return
		if _drag_place_one(g):
			_mark_drag_slot(g)

func _mark_drag_slot(g: int) -> void:
	if _drag_visited.has(g):
		return
	_drag_visited[g] = true
	_drag_slots.append(g)

func _finalize_drag(button_index: int) -> void:
	if button_index == MouseButton.MOUSE_BUTTON_LEFT and _drag_button == MouseButton.MOUSE_BUTTON_LEFT and _drag_from_cursor:
		if _drag_slots.size() <= 1:
			if _drag_slots.size() == 1:
				_handle_left_click_on_slot(_drag_slots[0])
		else:
			_apply_left_drag_distribution()
	_end_drag()

func _end_drag() -> void:
	_drag_button = 0
	_drag_from_cursor = false
	_drag_visited.clear()
	_drag_slots.clear()

func _handle_left_click_custom_slot(g: int) -> void:
	var slot_id: String = _get_custom_slot_id(g)
	var slot_count: int = _get_custom_slot_count(g)
	if player.cursor_item_id == "" or player.cursor_count <= 0:
		if slot_id == "" or slot_count <= 0:
			return
		player.cursor_item_id = slot_id
		player.cursor_count = slot_count
		_set_custom_slot(g, "", 0)
		player.emit_signal("inventory_changed")
		return
	var cur_id: String = player.cursor_item_id
	var cur_count: int = player.cursor_count
	var max_stack: int = player.inventory.max_stack_for(cur_id)
	if slot_id == "" or slot_count <= 0:
		_set_custom_slot(g, cur_id, cur_count)
		player.cursor_item_id = ""
		player.cursor_count = 0
		player.emit_signal("inventory_changed")
		return
	if slot_id == cur_id:
		var can_add: int = max_stack - slot_count
		if can_add <= 0:
			return
		var take: int = min(can_add, cur_count)
		_set_custom_slot(g, slot_id, slot_count + take)
		player.cursor_count -= take
		if player.cursor_count <= 0:
			player.cursor_item_id = ""
			player.cursor_count = 0
		player.emit_signal("inventory_changed")
		return
	_set_custom_slot(g, cur_id, cur_count)
	player.cursor_item_id = slot_id
	player.cursor_count = slot_count
	player.emit_signal("inventory_changed")

func _handle_right_click_custom_slot(g: int) -> void:
	var slot_id: String = _get_custom_slot_id(g)
	var slot_count: int = _get_custom_slot_count(g)
	if player.cursor_item_id == "" or player.cursor_count <= 0:
		if slot_id == "" or slot_count <= 0:
			return
		var take_half: int = int(ceil(float(slot_count) / 2.0))
		var remain: int = slot_count - take_half
		player.cursor_item_id = slot_id
		player.cursor_count = take_half
		_set_custom_slot(g, slot_id, remain)
		player.emit_signal("inventory_changed")
		return
	var cur_id: String = player.cursor_item_id
	var max_stack: int = player.inventory.max_stack_for(cur_id)
	if slot_id == "" or slot_count <= 0:
		_set_custom_slot(g, cur_id, 1)
		player.cursor_count -= 1
		if player.cursor_count <= 0:
			player.cursor_item_id = ""
			player.cursor_count = 0
		player.emit_signal("inventory_changed")
		return
	if slot_id != cur_id or slot_count >= max_stack:
		return
	_set_custom_slot(g, slot_id, slot_count + 1)
	player.cursor_count -= 1
	if player.cursor_count <= 0:
		player.cursor_item_id = ""
		player.cursor_count = 0
	player.emit_signal("inventory_changed")

func _handle_left_click_on_slot(g: int) -> void:
	var inv: KZ_Inventory = player.inventory
	var slot_id: String = inv.get_slot_id_global(g)
	var slot_count: int = inv.get_slot_count_global(g)

	if player.cursor_item_id == "" or player.cursor_count <= 0:
		if slot_id == "" or slot_count <= 0:
			return
		player.cursor_item_id = slot_id
		player.cursor_count = slot_count
		inv.clear_slot_global(g)
		player.emit_signal("inventory_changed")
		return

	var cur_id: String = player.cursor_item_id
	var cur_count: int = player.cursor_count
	var max_stack: int = inv.max_stack_for(cur_id)

	if slot_id == "" or slot_count <= 0:
		inv.set_slot_global(g, cur_id, cur_count)
		player.cursor_item_id = ""
		player.cursor_count = 0
		player.emit_signal("inventory_changed")
		return

	if slot_id == cur_id:
		var can_add: int = max_stack - slot_count
		if can_add <= 0:
			return
		var take: int = min(can_add, cur_count)
		inv.set_slot_global(g, slot_id, slot_count + take)
		player.cursor_count -= take
		if player.cursor_count <= 0:
			player.cursor_count = 0
			player.cursor_item_id = ""
		player.emit_signal("inventory_changed")
		return

	inv.set_slot_global(g, cur_id, cur_count)
	player.cursor_item_id = slot_id
	player.cursor_count = slot_count
	player.emit_signal("inventory_changed")

func _apply_left_drag_distribution() -> void:
	if player.cursor_item_id == "" or player.cursor_count <= 0:
		return
	var inv: KZ_Inventory = player.inventory
	var valid_slots: Array[int] = []
	var item_id: String = player.cursor_item_id
	var max_stack: int = inv.max_stack_for(item_id)
	for slot_g in _drag_slots:
		var slot_id: String = inv.get_slot_id_global(slot_g)
		var slot_count: int = inv.get_slot_count_global(slot_g)
		if slot_id == "" or (slot_id == item_id and slot_count < max_stack):
			valid_slots.append(slot_g)
	if valid_slots.is_empty():
		return
	var share: int = int(float(player.cursor_count) / float(valid_slots.size()))
	var remainder: int = player.cursor_count % valid_slots.size()
	if share <= 0:
		share = 1
		remainder = 0
	for i in range(valid_slots.size()):
		if player.cursor_count <= 0:
			break
		var give: int = share
		if remainder > 0:
			give += 1
			remainder -= 1
		var slot_g2: int = valid_slots[i]
		var slot_id2: String = inv.get_slot_id_global(slot_g2)
		var slot_count2: int = inv.get_slot_count_global(slot_g2)
		var room: int = max_stack - slot_count2 if slot_id2 == item_id else max_stack
		give = min(give, room, player.cursor_count)
		if give <= 0:
			continue
		if slot_id2 == "":
			inv.set_slot_global(slot_g2, item_id, give)
		else:
			inv.set_slot_global(slot_g2, item_id, slot_count2 + give)
		player.cursor_count -= give
	if player.cursor_count <= 0:
		player.cursor_count = 0
		player.cursor_item_id = ""
	player.emit_signal("inventory_changed")

func _handle_double_left_click_on_slot(g: int) -> void:
	var inv: KZ_Inventory = player.inventory
	var slot_id: String = inv.get_slot_id_global(g)
	var slot_count: int = inv.get_slot_count_global(g)

	var target_id: String = player.cursor_item_id
	if target_id == "":
		target_id = slot_id
	if target_id == "":
		return
	if player.cursor_item_id != "" and player.cursor_item_id != target_id:
		return

	var max_stack: int = inv.max_stack_for(target_id)
	if player.cursor_item_id == "":
		var take_first: int = min(slot_count, max_stack)
		player.cursor_item_id = target_id
		player.cursor_count = take_first
		if slot_count > take_first:
			inv.set_slot_global(g, slot_id, slot_count - take_first)
		else:
			inv.clear_slot_global(g)

	var room: int = max_stack - player.cursor_count
	for slot_g in range(inv.total_slots()):
		if room <= 0:
			break
		var other_id: String = inv.get_slot_id_global(slot_g)
		var other_count: int = inv.get_slot_count_global(slot_g)
		if other_id != target_id or other_count <= 0:
			continue
		var take: int = min(room, other_count)
		room -= take
		player.cursor_count += take
		if other_count > take:
			inv.set_slot_global(slot_g, other_id, other_count - take)
		else:
			inv.clear_slot_global(slot_g)
	player.emit_signal("inventory_changed")

func _handle_right_click_on_slot(g: int) -> void:
	var inv: KZ_Inventory = player.inventory
	var slot_id: String = inv.get_slot_id_global(g)
	var slot_count: int = inv.get_slot_count_global(g)

	if player.cursor_item_id == "" or player.cursor_count <= 0:
		if slot_id == "" or slot_count <= 0:
			return
		var take_half: int = int(ceil(float(slot_count) / 2.0))
		var remain: int = slot_count - take_half
		player.cursor_item_id = slot_id
		player.cursor_count = take_half
		if remain > 0:
			inv.set_slot_global(g, slot_id, remain)
		else:
			inv.clear_slot_global(g)
		player.emit_signal("inventory_changed")
		return

	var cur_id: String = player.cursor_item_id
	var max_stack: int = inv.max_stack_for(cur_id)

	if slot_id == "" or slot_count <= 0:
		inv.set_slot_global(g, cur_id, 1)
		player.cursor_count -= 1
		if player.cursor_count <= 0:
			player.cursor_count = 0
			player.cursor_item_id = ""
		player.emit_signal("inventory_changed")
		return

	if slot_id != cur_id or slot_count >= max_stack:
		return

	inv.set_slot_global(g, slot_id, slot_count + 1)
	player.cursor_count -= 1
	if player.cursor_count <= 0:
		player.cursor_count = 0
		player.cursor_item_id = ""
	player.emit_signal("inventory_changed")

func _drag_place_one(g: int) -> bool:
	if player.cursor_item_id == "" or player.cursor_count <= 0:
		return false
	var inv: KZ_Inventory = player.inventory
	var slot_id: String = inv.get_slot_id_global(g)
	var slot_count: int = inv.get_slot_count_global(g)
	var cur_id: String = player.cursor_item_id
	var max_stack: int = inv.max_stack_for(cur_id)

	if slot_id == "" or slot_count <= 0:
		inv.set_slot_global(g, cur_id, 1)
		player.cursor_count -= 1
		if player.cursor_count <= 0:
			player.cursor_count = 0
			player.cursor_item_id = ""
		player.emit_signal("inventory_changed")
		return true

	if slot_id != cur_id or slot_count >= max_stack:
		return false

	inv.set_slot_global(g, slot_id, slot_count + 1)
	player.cursor_count -= 1
	if player.cursor_count <= 0:
		player.cursor_count = 0
		player.cursor_item_id = ""
	player.emit_signal("inventory_changed")
	return true
