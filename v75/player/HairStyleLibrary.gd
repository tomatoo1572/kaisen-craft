extends RefCounted
class_name KZ_HairStyleLibrary

const SIDE_NAMES: Array[String] = ["front", "top", "back", "left", "right"]
const CURRENT_VERSION: int = 1

static func blank_hair_data() -> Dictionary:
	var sides: Dictionary = {}
	for side in SIDE_NAMES:
		sides[side] = []
	return {
		"version": CURRENT_VERSION,
		"preset_id": "custom",
		"sides": sides
	}

static func make_strand(
	enabled: bool = true,
	width: float = 0.18,
	length: float = 0.42,
	depth: float = 0.14,
	bend: float = 0.18,
	offset: Vector3 = Vector3.ZERO,
	rotation_deg: Vector3 = Vector3.ZERO,
	taper: float = 0.22,
	sway: float = 0.08
) -> Dictionary:
	return {
		"enabled": enabled,
		"width": clampf(width, 0.04, 0.55),
		"length": clampf(length, 0.06, 1.30),
		"depth": clampf(depth, 0.03, 0.50),
		"bend": clampf(bend, -1.0, 1.0),
		"offset": [offset.x, offset.y, offset.z],
		"rotation": [rotation_deg.x, rotation_deg.y, rotation_deg.z],
		"taper": clampf(taper, 0.0, 1.0),
		"sway": clampf(sway, 0.0, 1.0)
	}

static func preset_ids() -> Array[String]:
	return ["none", "short_clean", "soft_messy", "spike_crown", "side_swept", "layered_wolf", "long_flow"]

static func preset_display_names() -> Dictionary:
	return {
		"none": "None",
		"short_clean": "Short Clean",
		"soft_messy": "Soft Messy",
		"spike_crown": "Spike Crown",
		"side_swept": "Side Swept",
		"layered_wolf": "Layered Wolf",
		"long_flow": "Long Flow"
	}

static func preset_id_from_legacy(style: String) -> String:
	var normalized: String = style.to_lower().strip_edges()
	match normalized:
		"", "none":
			return "none"
		"jjk_buzz", "buzz_01":
			return "short_clean"
		"jjk_yuji", "spiky_01":
			return "spike_crown"
		"jjk_megumi", "short_01", "messy_01":
			return "soft_messy"
		"jjk_gojo":
			return "layered_wolf"
		"jjk_yuta":
			return "side_swept"
		"jjk_long", "long_01":
			return "long_flow"
		"short_clean", "soft_messy", "spike_crown", "side_swept", "layered_wolf", "long_flow":
			return normalized
		_:
			return "soft_messy"

static func build_preset(preset_id: String) -> Dictionary:
	var hair_data: Dictionary = blank_hair_data()
	var pid: String = preset_id_from_legacy(preset_id)
	hair_data["preset_id"] = pid
	var sides: Dictionary = hair_data.get("sides", {}) as Dictionary
	match pid:
		"none":
			pass
		"short_clean":
			sides["top"] = [
				make_strand(true, 0.52, 0.16, 0.44, 0.0, Vector3(0.0, 0.04, 0.0), Vector3.ZERO, 0.0, 0.02),
				make_strand(true, 0.40, 0.14, 0.34, 0.0, Vector3(0.0, -0.02, -0.02), Vector3.ZERO, 0.0, 0.02)
			]
			sides["front"] = [
				make_strand(true, 0.18, 0.18, 0.12, 0.10, Vector3(-0.10, 0.00, -0.02), Vector3(18.0, 0.0, 8.0), 0.08, 0.03),
				make_strand(true, 0.18, 0.20, 0.12, 0.08, Vector3(0.10, 0.00, -0.02), Vector3(18.0, 0.0, -8.0), 0.08, 0.03)
			]
		"soft_messy":
			sides["top"] = [
				make_strand(true, 0.42, 0.20, 0.28, 0.10, Vector3(0.0, 0.05, 0.0), Vector3(0.0, 0.0, 0.0), 0.10, 0.04),
				make_strand(true, 0.16, 0.34, 0.12, 0.28, Vector3(-0.18, 0.05, -0.04), Vector3(-20.0, -8.0, 18.0), 0.18, 0.08),
				make_strand(true, 0.16, 0.36, 0.12, 0.24, Vector3(0.18, 0.05, -0.04), Vector3(-18.0, 8.0, -18.0), 0.18, 0.08),
				make_strand(true, 0.14, 0.30, 0.10, 0.20, Vector3(-0.06, 0.09, 0.10), Vector3(-16.0, 0.0, 12.0), 0.18, 0.07),
				make_strand(true, 0.14, 0.30, 0.10, 0.20, Vector3(0.08, 0.08, 0.12), Vector3(-16.0, 0.0, -12.0), 0.18, 0.07)
			]
			sides["front"] = [
				make_strand(true, 0.12, 0.44, 0.10, 0.38, Vector3(-0.16, 0.00, -0.02), Vector3(28.0, 0.0, 18.0), 0.30, 0.10),
				make_strand(true, 0.11, 0.36, 0.09, 0.24, Vector3(-0.04, 0.02, -0.01), Vector3(22.0, 0.0, 10.0), 0.26, 0.08),
				make_strand(true, 0.10, 0.34, 0.09, 0.18, Vector3(0.06, 0.03, -0.01), Vector3(20.0, 0.0, -6.0), 0.24, 0.07),
				make_strand(true, 0.11, 0.38, 0.09, 0.22, Vector3(0.18, 0.00, -0.02), Vector3(24.0, 0.0, -18.0), 0.28, 0.09)
			]
			sides["left"] = [make_strand(true, 0.10, 0.28, 0.08, 0.08, Vector3(0.00, 0.02, 0.04), Vector3(8.0, 0.0, 20.0), 0.18, 0.06)]
			sides["right"] = [make_strand(true, 0.10, 0.28, 0.08, 0.08, Vector3(0.00, 0.02, 0.04), Vector3(8.0, 0.0, -20.0), 0.18, 0.06)]
			sides["back"] = [
				make_strand(true, 0.12, 0.26, 0.10, -0.08, Vector3(-0.12, 0.04, 0.00), Vector3(-6.0, 0.0, 8.0), 0.14, 0.05),
				make_strand(true, 0.12, 0.30, 0.10, -0.10, Vector3(0.12, 0.04, 0.00), Vector3(-6.0, 0.0, -8.0), 0.14, 0.05)
			]
		"spike_crown":
			sides["top"] = [
				make_strand(true, 0.15, 0.56, 0.12, -0.24, Vector3(-0.22, 0.08, -0.10), Vector3(-42.0, 0.0, 28.0), 0.22, 0.10),
				make_strand(true, 0.16, 0.64, 0.12, -0.28, Vector3(-0.10, 0.12, -0.02), Vector3(-46.0, 0.0, 14.0), 0.22, 0.11),
				make_strand(true, 0.18, 0.72, 0.14, -0.34, Vector3(0.00, 0.16, 0.02), Vector3(-54.0, 0.0, 0.0), 0.24, 0.12),
				make_strand(true, 0.16, 0.64, 0.12, -0.28, Vector3(0.10, 0.12, -0.02), Vector3(-46.0, 0.0, -14.0), 0.22, 0.11),
				make_strand(true, 0.15, 0.56, 0.12, -0.24, Vector3(0.22, 0.08, -0.10), Vector3(-42.0, 0.0, -28.0), 0.22, 0.10),
				make_strand(true, 0.14, 0.46, 0.10, -0.18, Vector3(-0.18, 0.06, 0.12), Vector3(-34.0, 0.0, 22.0), 0.18, 0.08),
				make_strand(true, 0.14, 0.46, 0.10, -0.18, Vector3(0.18, 0.06, 0.12), Vector3(-34.0, 0.0, -22.0), 0.18, 0.08)
			]
			sides["front"] = [
				make_strand(true, 0.10, 0.26, 0.08, 0.18, Vector3(-0.12, -0.02, -0.02), Vector3(18.0, 0.0, 12.0), 0.18, 0.06),
				make_strand(true, 0.10, 0.24, 0.08, 0.16, Vector3(0.12, -0.02, -0.02), Vector3(18.0, 0.0, -12.0), 0.18, 0.06)
			]
		"side_swept":
			sides["top"] = [
				make_strand(true, 0.44, 0.18, 0.30, 0.06, Vector3(0.0, 0.05, 0.02), Vector3(0.0, 0.0, 0.0), 0.10, 0.04),
				make_strand(true, 0.22, 0.52, 0.14, 0.22, Vector3(-0.12, 0.10, -0.04), Vector3(-18.0, 0.0, 26.0), 0.24, 0.09),
				make_strand(true, 0.24, 0.72, 0.16, 0.28, Vector3(0.02, 0.12, -0.02), Vector3(-22.0, 0.0, 8.0), 0.28, 0.11)
			]
			sides["front"] = [
				make_strand(true, 0.13, 0.60, 0.10, 0.30, Vector3(-0.18, 0.00, -0.03), Vector3(24.0, 0.0, 20.0), 0.28, 0.10),
				make_strand(true, 0.13, 0.72, 0.10, 0.26, Vector3(-0.04, 0.00, -0.01), Vector3(20.0, 0.0, 8.0), 0.32, 0.10),
				make_strand(true, 0.12, 0.82, 0.09, 0.24, Vector3(0.10, -0.02, -0.01), Vector3(18.0, 0.0, -6.0), 0.36, 0.10)
			]
			sides["left"] = [make_strand(true, 0.10, 0.58, 0.08, 0.10, Vector3(0.00, 0.00, 0.00), Vector3(8.0, 0.0, 10.0), 0.24, 0.07)]
			sides["right"] = [make_strand(true, 0.09, 0.26, 0.08, 0.08, Vector3(0.0, 0.00, 0.02), Vector3(6.0, 0.0, -18.0), 0.18, 0.05)]
		"layered_wolf":
			sides["top"] = [
				make_strand(true, 0.22, 0.58, 0.14, -0.12, Vector3(-0.18, 0.08, -0.06), Vector3(-28.0, 0.0, 22.0), 0.22, 0.10),
				make_strand(true, 0.22, 0.66, 0.14, -0.16, Vector3(0.00, 0.10, -0.02), Vector3(-34.0, 0.0, 0.0), 0.22, 0.11),
				make_strand(true, 0.22, 0.58, 0.14, -0.12, Vector3(0.18, 0.08, -0.06), Vector3(-28.0, 0.0, -22.0), 0.22, 0.10)
			]
			sides["front"] = [
				make_strand(true, 0.10, 0.42, 0.08, 0.18, Vector3(-0.16, 0.00, -0.02), Vector3(18.0, 0.0, 16.0), 0.24, 0.08),
				make_strand(true, 0.10, 0.36, 0.08, 0.14, Vector3(0.00, 0.02, -0.01), Vector3(14.0, 0.0, 0.0), 0.20, 0.07),
				make_strand(true, 0.10, 0.42, 0.08, 0.18, Vector3(0.16, 0.00, -0.02), Vector3(18.0, 0.0, -16.0), 0.24, 0.08)
			]
			sides["back"] = [
				make_strand(true, 0.14, 0.68, 0.12, 0.04, Vector3(-0.16, 0.02, 0.00), Vector3(8.0, 0.0, 10.0), 0.28, 0.08),
				make_strand(true, 0.14, 0.76, 0.12, 0.06, Vector3(0.00, 0.00, 0.00), Vector3(8.0, 0.0, 0.0), 0.32, 0.09),
				make_strand(true, 0.14, 0.68, 0.12, 0.04, Vector3(0.16, 0.02, 0.00), Vector3(8.0, 0.0, -10.0), 0.28, 0.08)
			]
			sides["left"] = [make_strand(true, 0.10, 0.52, 0.08, 0.08, Vector3(0.0, 0.00, 0.04), Vector3(10.0, 0.0, 18.0), 0.26, 0.07)]
			sides["right"] = [make_strand(true, 0.10, 0.52, 0.08, 0.08, Vector3(0.0, 0.00, 0.04), Vector3(10.0, 0.0, -18.0), 0.26, 0.07)]
		"long_flow":
			sides["top"] = [
				make_strand(true, 0.48, 0.20, 0.32, 0.04, Vector3(0.0, 0.04, 0.0), Vector3(0.0, 0.0, 0.0), 0.10, 0.04)
			]
			sides["front"] = [
				make_strand(true, 0.10, 0.38, 0.08, 0.16, Vector3(-0.14, 0.00, -0.02), Vector3(18.0, 0.0, 14.0), 0.22, 0.07),
				make_strand(true, 0.10, 0.38, 0.08, 0.16, Vector3(0.14, 0.00, -0.02), Vector3(18.0, 0.0, -14.0), 0.22, 0.07)
			]
			sides["back"] = [
				make_strand(true, 0.12, 1.00, 0.10, 0.06, Vector3(-0.18, 0.00, 0.00), Vector3(6.0, 0.0, 10.0), 0.30, 0.09),
				make_strand(true, 0.14, 1.08, 0.10, 0.08, Vector3(0.00, -0.02, 0.00), Vector3(6.0, 0.0, 0.0), 0.34, 0.10),
				make_strand(true, 0.12, 1.00, 0.10, 0.06, Vector3(0.18, 0.00, 0.00), Vector3(6.0, 0.0, -10.0), 0.30, 0.09)
			]
			sides["left"] = [make_strand(true, 0.10, 0.94, 0.08, 0.06, Vector3(0.0, 0.00, 0.02), Vector3(8.0, 0.0, 12.0), 0.28, 0.08)]
			sides["right"] = [make_strand(true, 0.10, 0.94, 0.08, 0.06, Vector3(0.0, 0.00, 0.02), Vector3(8.0, 0.0, -12.0), 0.28, 0.08)]
		_:
			return build_preset("soft_messy")
	hair_data["sides"] = sides
	return ensure_hair_data(hair_data)

static func clone_hair_data(data: Dictionary) -> Dictionary:
	return ensure_hair_data(data)

static func ensure_hair_data(data_variant: Variant) -> Dictionary:
	var result: Dictionary = blank_hair_data()
	var clean_sides: Dictionary = result.get("sides", {}) as Dictionary
	if data_variant is Dictionary:
		var data: Dictionary = data_variant as Dictionary
		result["version"] = int(data.get("version", CURRENT_VERSION))
		result["preset_id"] = str(data.get("preset_id", "custom"))
		var incoming_sides: Variant = data.get("sides", {})
		if incoming_sides is Dictionary:
			for side in SIDE_NAMES:
				var raw_list: Variant = (incoming_sides as Dictionary).get(side, [])
				var clean_list: Array = []
				if raw_list is Array:
					for strand_v in raw_list:
						if strand_v is Dictionary:
							clean_list.append(_sanitize_strand(strand_v as Dictionary))
				clean_sides[side] = clean_list
	result["sides"] = clean_sides
	return result

static func _sanitize_strand(strand: Dictionary) -> Dictionary:
	var offset_arr: Array = strand.get("offset", [0.0, 0.0, 0.0]) as Array
	var rotation_arr: Array = strand.get("rotation", [0.0, 0.0, 0.0]) as Array
	var offset := Vector3(
		float(offset_arr[0]) if offset_arr.size() > 0 else 0.0,
		float(offset_arr[1]) if offset_arr.size() > 1 else 0.0,
		float(offset_arr[2]) if offset_arr.size() > 2 else 0.0
	)
	var rotation_deg := Vector3(
		float(rotation_arr[0]) if rotation_arr.size() > 0 else 0.0,
		float(rotation_arr[1]) if rotation_arr.size() > 1 else 0.0,
		float(rotation_arr[2]) if rotation_arr.size() > 2 else 0.0
	)
	return make_strand(
		bool(strand.get("enabled", true)),
		float(strand.get("width", 0.18)),
		float(strand.get("length", 0.42)),
		float(strand.get("depth", strand.get("width", 0.14))),
		float(strand.get("bend", 0.18)),
		offset,
		rotation_deg,
		float(strand.get("taper", 0.22)),
		float(strand.get("sway", 0.08))
	)
