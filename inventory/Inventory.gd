extends RefCounted
class_name KZ_Inventory

const HOTBAR_SIZE: int = 9
const INV_COLS: int = 9
const INV_ROWS: int = 3
const INV_SIZE: int = INV_COLS * INV_ROWS
const DEFAULT_MAX_STACK: int = 64

var hotbar_ids: Array[String] = []
var hotbar_counts: Array[int] = []
var inv_ids: Array[String] = []
var inv_counts: Array[int] = []
var selected_index: int = 0

func _init() -> void:
	hotbar_ids.resize(HOTBAR_SIZE)
	hotbar_counts.resize(HOTBAR_SIZE)
	for i in range(HOTBAR_SIZE):
		hotbar_ids[i] = ""
		hotbar_counts[i] = 0

	inv_ids.resize(INV_SIZE)
	inv_counts.resize(INV_SIZE)
	for j in range(INV_SIZE):
		inv_ids[j] = ""
		inv_counts[j] = 0

	selected_index = 0

func set_selected(idx: int) -> void:
	selected_index = clampi(idx, 0, HOTBAR_SIZE - 1)

func get_selected_id() -> String:
	return hotbar_ids[selected_index]

func get_selected_count() -> int:
	return hotbar_counts[selected_index]

func has_selected() -> bool:
	return hotbar_ids[selected_index] != "" and hotbar_counts[selected_index] > 0

func total_slots() -> int:
	return HOTBAR_SIZE + INV_SIZE

func is_hotbar_global(g: int) -> bool:
	return g >= 0 and g < HOTBAR_SIZE

func _inv_index_from_global(g: int) -> int:
	return g - HOTBAR_SIZE

func get_slot_id_global(g: int) -> String:
	if g < 0:
		return ""
	if g < HOTBAR_SIZE:
		return hotbar_ids[g]
	var i: int = _inv_index_from_global(g)
	if i < 0 or i >= INV_SIZE:
		return ""
	return inv_ids[i]

func get_slot_count_global(g: int) -> int:
	if g < 0:
		return 0
	if g < HOTBAR_SIZE:
		return hotbar_counts[g]
	var i: int = _inv_index_from_global(g)
	if i < 0 or i >= INV_SIZE:
		return 0
	return inv_counts[i]

func set_slot_global(g: int, item_id: String, count: int) -> void:
	var c: int = max(0, count)
	var id: String = item_id if c > 0 else ""
	if g < 0:
		return
	if g < HOTBAR_SIZE:
		hotbar_ids[g] = id
		hotbar_counts[g] = c
		return
	var i: int = _inv_index_from_global(g)
	if i < 0 or i >= INV_SIZE:
		return
	inv_ids[i] = id
	inv_counts[i] = c

func clear_slot_global(g: int) -> void:
	set_slot_global(g, "", 0)

func max_stack_for(_item_id: String) -> int:
	return DEFAULT_MAX_STACK

func add_item(item_id: String, count: int, max_stack: int = DEFAULT_MAX_STACK) -> int:
	# Returns remainder that could not be added.
	var remaining: int = count
	if remaining <= 0:
		return 0

	# Fill existing stacks (hotbar then inventory).
	remaining = _fill_existing(hotbar_ids, hotbar_counts, item_id, remaining, max_stack)
	remaining = _fill_existing(inv_ids, inv_counts, item_id, remaining, max_stack)

	# Use empty slots (hotbar then inventory).
	remaining = _fill_empty(hotbar_ids, hotbar_counts, item_id, remaining, max_stack)
	remaining = _fill_empty(inv_ids, inv_counts, item_id, remaining, max_stack)

	return remaining

func consume_selected(amount: int) -> bool:
	if amount <= 0:
		return true
	if not has_selected():
		return false
	if hotbar_counts[selected_index] < amount:
		return false
	hotbar_counts[selected_index] -= amount
	if hotbar_counts[selected_index] <= 0:
		hotbar_counts[selected_index] = 0
		hotbar_ids[selected_index] = ""
	return true

func _fill_existing(ids: Array[String], counts: Array[int], item_id: String, remaining: int, max_stack: int) -> int:
	var r: int = remaining
	for i in range(ids.size()):
		if r <= 0:
			break
		if ids[i] == item_id and counts[i] > 0 and counts[i] < max_stack:
			var can_add: int = max_stack - counts[i]
			var take: int = min(can_add, r)
			counts[i] += take
			r -= take
	return r

func _fill_empty(ids: Array[String], counts: Array[int], item_id: String, remaining: int, max_stack: int) -> int:
	var r: int = remaining
	for i in range(ids.size()):
		if r <= 0:
			break
		if counts[i] == 0:
			ids[i] = item_id
			var take: int = min(max_stack, r)
			counts[i] = take
			r -= take
	return r

func debug_string() -> String:
	var s: String = "["
	for i in range(HOTBAR_SIZE):
		var mark: String = "*" if i == selected_index else " "
		var id: String = hotbar_ids[i]
		var c: int = hotbar_counts[i]
		if id == "":
			s += "%s(%d: empty)" % [mark, i]
		else:
			s += "%s(%d: %s x%d)" % [mark, i, id, c]
		if i != HOTBAR_SIZE - 1:
			s += ", "
	s += "]"

	s += "\nInv: ["
	for j in range(INV_SIZE):
		var id2: String = inv_ids[j]
		var c2: int = inv_counts[j]
		if id2 == "":
			s += "(%d: empty)" % j
		else:
			s += "(%d: %s x%d)" % [j, id2, c2]
		if j != INV_SIZE - 1:
			s += ", "
	s += "]"
	return s
