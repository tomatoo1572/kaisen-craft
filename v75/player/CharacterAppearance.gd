extends RefCounted
class_name KZ_CharacterAppearance

const DEFAULT_HEIGHT_METERS: float = 1.8288
const MAX_HEIGHT_METERS: float = 2.240
const MIN_HEIGHT_METERS: float = 1.60

const DEFAULTS := {
	"sex": "male",
	"face_preset": "default",
	"skin_tone": [0.93, 0.81, 0.69, 1.0],
	"height_meters": DEFAULT_HEIGHT_METERS,
	"height_scale": 1.0,
	"width_scale": 1.0,
	"shape_weights": [0.33, 0.34, 0.33],
	"body_preset": "male1",
	"hair_preset_id": "soft_messy",
	"hair_style": "soft_messy",
	"hair_color": [0.08, 0.08, 0.10, 1.0],
	"hair_data": {},
	"clothing": {
		"under_layer": "",
		"top_layer": "",
		"waist_layer": "",
		"leg_layer": "",
		"foot_layer": "",
		"hand_layer": "",
		"accessory_layer": ""
	}
}

var sex: String = "male"
var face_preset: String = "default"
var skin_tone: Color = Color(0.93, 0.81, 0.69, 1.0)
var height_meters: float = DEFAULT_HEIGHT_METERS
var height_scale: float = 1.0
var width_scale: float = 1.0
var shape_weights: Array = [0.33, 0.34, 0.33]
var body_preset: String = "male1"
var hair_preset_id: String = "soft_messy"
var hair_style: String = "soft_messy"
var hair_color: Color = Color(0.08, 0.08, 0.10, 1.0)
var hair_data: Dictionary = {}
var clothing: Dictionary = {}

func _init() -> void:
	apply_dict(DEFAULTS)

func to_dict() -> Dictionary:
	return {
		"sex": sex,
		"face_preset": face_preset,
		"skin_tone": [skin_tone.r, skin_tone.g, skin_tone.b, skin_tone.a],
		"height_meters": height_meters,
		"height_scale": height_scale,
		"width_scale": width_scale,
		"shape_weights": shape_weights.duplicate(),
		"body_preset": body_preset,
		"hair_preset_id": hair_preset_id,
		"hair_style": hair_style,
		"hair_color": [hair_color.r, hair_color.g, hair_color.b, hair_color.a],
		"hair_data": KZ_HairStyleLibrary.ensure_hair_data(hair_data),
		"clothing": clothing.duplicate(true)
	}

func apply_dict(data: Dictionary) -> void:
	var merged: Dictionary = DEFAULTS.duplicate(true)
	for key in data.keys():
		merged[key] = data[key]

	sex = str(merged.get("sex", "male")).to_lower()
	if sex != "female":
		sex = "male"

	face_preset = str(merged.get("face_preset", "default"))
	skin_tone = _color_from_variant(merged.get("skin_tone", [0.93, 0.81, 0.69, 1.0]), Color(0.93, 0.81, 0.69, 1.0))
	hair_color = _color_from_variant(merged.get("hair_color", [0.08, 0.08, 0.10, 1.0]), Color(0.08, 0.08, 0.10, 1.0))

	var height_variant: Variant = merged.get("height_meters", null)
	if typeof(height_variant) == TYPE_NIL:
		height_scale = clampf(float(merged.get("height_scale", 1.0)), MIN_HEIGHT_METERS / DEFAULT_HEIGHT_METERS, MAX_HEIGHT_METERS / DEFAULT_HEIGHT_METERS)
		height_meters = DEFAULT_HEIGHT_METERS * height_scale
	else:
		height_meters = clampf(float(height_variant), MIN_HEIGHT_METERS, MAX_HEIGHT_METERS)
		height_scale = height_meters / DEFAULT_HEIGHT_METERS

	width_scale = clampf(float(merged.get("width_scale", 1.0)), 0.82, 1.18)
	var shape_v: Variant = merged.get("shape_weights", [0.33, 0.34, 0.33])
	if shape_v is Array and (shape_v as Array).size() >= 3:
		var raw_shape: Array = shape_v as Array
		var lean: float = float(raw_shape[0])
		var athletic: float = float(raw_shape[1])
		var bulky: float = float(raw_shape[2])
		var total: float = maxf(0.0001, lean + athletic + bulky)
		shape_weights = [lean / total, athletic / total, bulky / total]
	else:
		shape_weights = [0.33, 0.34, 0.33]

	body_preset = str(merged.get("body_preset", "male1")).to_lower()
	if body_preset not in ["male1", "male2", "male3", "male4"]:
		body_preset = "male1"

	hair_preset_id = KZ_HairStyleLibrary.preset_id_from_legacy(str(merged.get("hair_preset_id", merged.get("hair_style", "soft_messy"))))
	hair_style = hair_preset_id
	var incoming_hair_data: Variant = merged.get("hair_data", {})
	if incoming_hair_data is Dictionary and not (incoming_hair_data as Dictionary).is_empty():
		hair_data = KZ_HairStyleLibrary.ensure_hair_data(incoming_hair_data)
	else:
		hair_data = KZ_HairStyleLibrary.build_preset(hair_preset_id)

	var clothing_v: Variant = merged.get("clothing", {})
	if clothing_v is Dictionary:
		clothing = (clothing_v as Dictionary).duplicate(true)
	else:
		clothing = {}

func set_hair_from_preset(preset_id: String) -> void:
	hair_preset_id = KZ_HairStyleLibrary.preset_id_from_legacy(preset_id)
	hair_style = hair_preset_id
	hair_data = KZ_HairStyleLibrary.build_preset(hair_preset_id)

func set_hair_data(new_hair_data: Dictionary, preset_id: String = "custom") -> void:
	hair_preset_id = preset_id
	hair_style = preset_id
	hair_data = KZ_HairStyleLibrary.ensure_hair_data(new_hair_data)

func _color_from_variant(v: Variant, fallback: Color) -> Color:
	if v is Color:
		return v
	if v is Array:
		var a: Array = v as Array
		if a.size() >= 4:
			return Color(float(a[0]), float(a[1]), float(a[2]), float(a[3]))
		elif a.size() >= 3:
			return Color(float(a[0]), float(a[1]), float(a[2]), 1.0)
	return fallback
