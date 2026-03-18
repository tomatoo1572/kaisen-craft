extends RefCounted

const DEFAULTS := {
	"sex": "male",
	"build": "base",
	"face_preset": "default",
	"skin_tone": [1.0, 1.0, 1.0, 1.0],
	"height_scale": 1.0,
	"width_scale": 1.0,
	"body_weight": 0.0,
	"body_preset": "male_base_01",
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
var build: String = "base"
var face_preset: String = "default"
var skin_tone: Color = Color(1.0, 1.0, 1.0, 1.0)
var height_scale: float = 1.0
var width_scale: float = 1.0
var body_weight: float = 0.0
var body_preset: String = "male_base_01"
var clothing: Dictionary = {}

func _init() -> void:
	apply_dict(DEFAULTS)

func to_dict() -> Dictionary:
	return {
		"sex": sex,
		"build": build,
		"face_preset": face_preset,
		"skin_tone": [skin_tone.r, skin_tone.g, skin_tone.b, skin_tone.a],
		"height_scale": height_scale,
		"width_scale": width_scale,
		"body_weight": body_weight,
		"body_preset": body_preset,
		"clothing": clothing.duplicate(true)
	}

func apply_dict(data: Dictionary) -> void:
	var merged: Dictionary = DEFAULTS.duplicate(true)
	for key in data.keys():
		merged[key] = data[key]
	sex = str(merged.get("sex", "male")).to_lower()
	if sex != "female":
		sex = "male"
	build = str(merged.get("build", "base")).to_lower()
	if build != "slim" and build != "shredded" and build != "fat":
		build = "base"
	face_preset = str(merged.get("face_preset", "default"))
	var tone_v: Variant = merged.get("skin_tone", [1.0, 1.0, 1.0, 1.0])
	if tone_v is Array:
		var tone_arr: Array = tone_v as Array
		if tone_arr.size() >= 4:
			skin_tone = Color(float(tone_arr[0]), float(tone_arr[1]), float(tone_arr[2]), float(tone_arr[3]))
	height_scale = clampf(float(merged.get("height_scale", 1.0)), 0.82, 1.24)
	width_scale = clampf(float(merged.get("width_scale", 1.0)), 0.78, 1.28)
	body_weight = clampf(float(merged.get("body_weight", 0.0)), -1.0, 1.0)
	body_preset = str(merged.get("body_preset", "male_base_01"))
	var clothing_v: Variant = merged.get("clothing", {})
	if clothing_v is Dictionary:
		clothing = (clothing_v as Dictionary).duplicate(true)
	else:
		clothing = {}
