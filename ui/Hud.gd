extends CanvasLayer
class_name KZ_Hud

var player: KZ_Player
var registry: KZ_BlockRegistry

var root: Control
var hotbar_box: HBoxContainer
var inv_panel: PanelContainer
var inv_grid: GridContainer
var crosshair: Label

var hotbar_slots: Array[KZ_SlotButton] = []
var inv_slots: Array[KZ_SlotButton] = []

var cursor_panel: PanelContainer
var cursor_icon: ColorRect
var cursor_label: Label

func setup(p_player: KZ_Player, p_registry: KZ_BlockRegistry) -> void:
	player = p_player
	registry = p_registry

	_build_ui()
	_connect_signals()
	_refresh_all()
	_set_inventory_open(false)

func _process(_dt: float) -> void:
	if player == null:
		return

	if not player.inventory_is_open:
		cursor_panel.visible = false
		return

	if player.cursor_item_id == "" or player.cursor_count <= 0:
		cursor_panel.visible = false
		return

	cursor_panel.visible = true
	var mp: Vector2 = get_viewport().get_mouse_position()
	cursor_panel.position = mp + Vector2(12, 12)

func _build_ui() -> void:
	root = Control.new()
	root.anchor_left = 0.0
	root.anchor_top = 0.0
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	# ✅ IMPORTANT: do NOT block mouse motion for the game
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(root)

	# Crosshair (ignore mouse entirely)
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

	# Hotbar container (pass so it doesn't swallow motion; buttons will stop clicks themselves)
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
	hotbar_box.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(hotbar_box)

	hotbar_slots.clear()
	for i in range(KZ_Inventory.HOTBAR_SIZE):
		var b := KZ_SlotButton.new()
		b.set_slot_index(i)
		b.pressed.connect(Callable(self, "_on_hotbar_pressed").bind(i))
		hotbar_box.add_child(b)
		hotbar_slots.append(b)

	# Inventory panel (when visible, it should capture clicks)
	inv_panel = PanelContainer.new()
	inv_panel.anchor_left = 0.5
	inv_panel.anchor_right = 0.5
	inv_panel.anchor_top = 0.5
	inv_panel.anchor_bottom = 0.5
	inv_panel.offset_left = -280
	inv_panel.offset_right = 280
	inv_panel.offset_top = -190
	inv_panel.offset_bottom = 190
	inv_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(inv_panel)

	var inv_vbox := VBoxContainer.new()
	inv_vbox.add_theme_constant_override("separation", 8)
	inv_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	inv_panel.add_child(inv_vbox)

	var title := Label.new()
	title.text = "Inventory"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inv_vbox.add_child(title)

	inv_grid = GridContainer.new()
	inv_grid.columns = KZ_Inventory.INV_COLS
	inv_grid.add_theme_constant_override("h_separation", 6)
	inv_grid.add_theme_constant_override("v_separation", 6)
	inv_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	inv_vbox.add_child(inv_grid)

	inv_slots.clear()
	for j in range(KZ_Inventory.INV_SIZE):
		var g: int = KZ_Inventory.HOTBAR_SIZE + j
		var b2 := KZ_SlotButton.new()
		b2.set_slot_index(g)
		b2.pressed.connect(Callable(self, "_on_inventory_slot_pressed").bind(g))
		inv_grid.add_child(b2)
		inv_slots.append(b2)

	var hint := Label.new()
	hint.text = "Click slots to move stacks. Press E to close."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inv_vbox.add_child(hint)

	# Cursor panel (ignore mouse)
	cursor_panel = PanelContainer.new()
	cursor_panel.visible = false
	cursor_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cursor_panel)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor_panel.add_child(hb)

	cursor_icon = ColorRect.new()
	cursor_icon.custom_minimum_size = Vector2(18, 18)
	cursor_icon.color = Color(0, 0, 0, 0)
	cursor_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(cursor_icon)

	cursor_label = Label.new()
	cursor_label.text = ""
	cursor_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(cursor_label)

func _connect_signals() -> void:
	if player == null:
		return
	if not player.inventory_changed.is_connected(Callable(self, "_on_inventory_changed")):
		player.inventory_changed.connect(Callable(self, "_on_inventory_changed"))
	if not player.hotbar_selected_changed.is_connected(Callable(self, "_on_hotbar_selected")):
		player.hotbar_selected_changed.connect(Callable(self, "_on_hotbar_selected"))
	if not player.inventory_opened.is_connected(Callable(self, "_on_inventory_opened")):
		player.inventory_opened.connect(Callable(self, "_on_inventory_opened"))

func _on_inventory_changed() -> void:
	_refresh_all()

func _on_hotbar_selected(_idx: int) -> void:
	_refresh_hotbar()

func _on_inventory_opened(open: bool) -> void:
	_set_inventory_open(open)
	_refresh_all()

func _set_inventory_open(open: bool) -> void:
	inv_panel.visible = open
	crosshair.visible = not open

func _refresh_all() -> void:
	_refresh_hotbar()
	_refresh_inventory()
	_refresh_cursor()

func _refresh_hotbar() -> void:
	if player == null:
		return
	var inv: KZ_Inventory = player.inventory
	for i in range(KZ_Inventory.HOTBAR_SIZE):
		var id: String = inv.hotbar_ids[i]
		var c: int = inv.hotbar_counts[i]
		var tint: Color = _tint_for_id(id)
		var sel: bool = (i == inv.selected_index)
		hotbar_slots[i].set_visual(id, c, tint, sel)

func _refresh_inventory() -> void:
	if player == null:
		return
	var inv: KZ_Inventory = player.inventory
	for j in range(KZ_Inventory.INV_SIZE):
		var id: String = inv.inv_ids[j]
		var c: int = inv.inv_counts[j]
		var tint: Color = _tint_for_id(id)
		inv_slots[j].set_visual(id, c, tint, false)

func _refresh_cursor() -> void:
	if player == null:
		return
	if player.cursor_item_id == "" or player.cursor_count <= 0:
		cursor_icon.color = Color(0, 0, 0, 0)
		cursor_label.text = ""
		return
	cursor_icon.color = _tint_for_id(player.cursor_item_id)
	cursor_label.text = "%s x%d" % [player.cursor_item_id, player.cursor_count]

func _tint_for_id(item_id: String) -> Color:
	if item_id == "":
		return Color(0, 0, 0, 0)
	if registry == null:
		return Color(1, 1, 1, 1)
	var rid: int = registry.get_runtime_id(item_id)
	var def: KZ_BlockRegistry.BlockDef = registry.get_def_by_runtime(rid)
	return def.tint if def != null else Color(1, 1, 1, 1)

func _on_hotbar_pressed(slot: int) -> void:
	if player == null:
		return
	player.inventory.set_selected(slot)
	player.emit_signal("hotbar_selected_changed", slot)
	_refresh_hotbar()

func _on_inventory_slot_pressed(g: int) -> void:
	if player == null:
		return
	if not player.inventory_is_open:
		return

	var inv: KZ_Inventory = player.inventory
	var slot_id: String = inv.get_slot_id_global(g)
	var slot_count: int = inv.get_slot_count_global(g)
	var max_stack: int = inv.max_stack_for(slot_id)

	if player.cursor_item_id == "" or player.cursor_count <= 0:
		if slot_id != "" and slot_count > 0:
			player.cursor_item_id = slot_id
			player.cursor_count = slot_count
			inv.clear_slot_global(g)
			player.emit_signal("inventory_changed")
		return

	var cur_id: String = player.cursor_item_id
	var cur_count: int = player.cursor_count

	if slot_id == "" or slot_count <= 0:
		inv.set_slot_global(g, cur_id, cur_count)
		player.cursor_item_id = ""
		player.cursor_count = 0
		player.emit_signal("inventory_changed")
		return

	if slot_id == cur_id:
		var can_add: int = max_stack - slot_count
		if can_add > 0:
			var take: int = min(can_add, cur_count)
			inv.set_slot_global(g, slot_id, slot_count + take)
			cur_count -= take
			player.cursor_count = cur_count
			if player.cursor_count <= 0:
				player.cursor_count = 0
				player.cursor_item_id = ""
			player.emit_signal("inventory_changed")
		return

	inv.set_slot_global(g, cur_id, cur_count)
	player.cursor_item_id = slot_id
	player.cursor_count = slot_count
	player.emit_signal("inventory_changed")
