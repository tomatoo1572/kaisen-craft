extends CanvasLayer
class_name KZ_Hud

const CRAFT2_BASE: int = 100
const CRAFT2_RESULT: int = 104
const CRAFT3_BASE: int = 200
const CRAFT3_RESULT: int = 209

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
var walk_mode_label: Label
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
	_set_inventory_open(false)
	_set_settings_open(false)
	_set_controls_open(false)
	_set_chat_open(false)
	_refresh_health(player.health, player.max_health)
	_refresh_hunger(player.hunger, player.max_hunger)
	_refresh_thirst(player.thirst, player.max_thirst)
	_refresh_walk_mode(player.get_walk_mode_name())
	_refresh_render_distance()
	_refresh_fov()
	_refresh_max_fps()
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
	inv_panel.offset_top = -255
	inv_panel.offset_bottom = 105
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

	inv_grid = GridContainer.new()
	inv_grid.columns = KZ_Inventory.INV_COLS
	inv_grid.add_theme_constant_override("h_separation", 6)
	inv_grid.add_theme_constant_override("v_separation", 6)
	inv_vbox.add_child(inv_grid)

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
	ct_result_box.add_theme_constant_override("separation", 4)
	ct_result_center.add_child(ct_result_box)
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
	else:
		_set_controls_open(false)

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

func _on_player_died() -> void:
	death_panel.visible = true
	crosshair.visible = false
	chat_input_panel.visible = false
	inv_panel.visible = false
	settings_panel.visible = false
	controls_panel.visible = false
	cursor_panel.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE as Input.MouseMode)

func _on_crafting_table_opened(open: bool) -> void:
	crafting_table_panel.visible = open
	if open:
		# Keep only the backpack/hotbar visible while the table is open.
		inv_panel.visible = true
		inv_panel.offset_top = -110
		inv_panel.offset_bottom = 250
		if inventory_craft_row != null:
			inventory_craft_row.visible = false
		if inventory_craft_hint != null:
			inventory_craft_hint.visible = false
		settings_panel.visible = false
		controls_panel.visible = false
		chat_input_panel.visible = false
		crosshair.visible = false
		hotbar_box.offset_top = -82
		hotbar_box.offset_bottom = -24
		_refresh_all()
	else:
		_return_crafting_items_to_inventory(true)
		inv_panel.offset_top = -255
		inv_panel.offset_bottom = 105
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
		chat_input_panel.visible = false
		crafting_table_panel.visible = false
		if inventory_craft_row != null:
			inventory_craft_row.visible = true
		if inventory_craft_hint != null:
			inventory_craft_hint.visible = true
		crosshair.visible = false
		hotbar_box.offset_top = -82
		hotbar_box.offset_bottom = -24
	else:
		_return_crafting_items_to_inventory(false)
		crosshair.visible = not player.settings_is_open and not player.chat_is_open and not player.is_dead
		hotbar_box.offset_top = -70
		hotbar_box.offset_bottom = -12

func _set_settings_open(open: bool) -> void:
	settings_panel.visible = open
	if open:
		inv_panel.visible = false
		controls_panel.visible = false
		crafting_table_panel.visible = false
		crosshair.visible = false
	else:
		crosshair.visible = not player.inventory_is_open and not player.chat_is_open and not player.is_dead

func _set_controls_open(open: bool) -> void:
	controls_panel.visible = open
	if open:
		settings_panel.visible = false
		inv_panel.visible = false
		crafting_table_panel.visible = false
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

func _refresh_all() -> void:
	_refresh_hotbar()
	_refresh_inventory()
	_refresh_crafting_views()
	_refresh_cursor()

func _refresh_hotbar() -> void:
	var inv: KZ_Inventory = player.inventory
	for i in range(KZ_Inventory.HOTBAR_SIZE):
		var id: String = inv.hotbar_ids[i]
		var c: int = inv.hotbar_counts[i]
		var tint: Color = _tint_for_id(id)
		var sel: bool = (i == inv.selected_index)
		hotbar_slots[i].set_visual(id, c, tint, sel)
		hotbar_slots[i].tooltip_text = _tooltip_for_item(id)

func _refresh_inventory() -> void:
	var inv: KZ_Inventory = player.inventory
	for j in range(KZ_Inventory.INV_SIZE):
		var id: String = inv.inv_ids[j]
		var c: int = inv.inv_counts[j]
		var tint: Color = _tint_for_id(id)
		inv_slots[j].set_visual(id, c, tint, false)
		inv_slots[j].tooltip_text = _tooltip_for_item(id)

func _refresh_crafting_views() -> void:
	_refresh_craft_result(2)
	_refresh_craft_result(3)
	for i in range(craft2_slots.size()):
		var id: String = craft2_ids[i]
		var count: int = craft2_counts[i]
		craft2_slots[i].set_visual(id, count, _tint_for_id(id), false)
		craft2_slots[i].tooltip_text = _tooltip_for_item(id)
	if craft2_result_slot != null:
		craft2_result_slot.set_visual(craft2_result_id, craft2_result_count, _tint_for_id(craft2_result_id), false)
		craft2_result_slot.tooltip_text = _tooltip_for_item(craft2_result_id)
	for j in range(craft3_slots.size()):
		var id3: String = craft3_ids[j]
		var count3: int = craft3_counts[j]
		craft3_slots[j].set_visual(id3, count3, _tint_for_id(id3), false)
		craft3_slots[j].tooltip_text = _tooltip_for_item(id3)
	if craft3_result_slot != null:
		craft3_result_slot.set_visual(craft3_result_id, craft3_result_count, _tint_for_id(craft3_result_id), false)
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
	if _is_craft_slot(g):
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
	var share: int = int(player.cursor_count / valid_slots.size())
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
