shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D grass_side_tex : source_color, repeat_enable, filter_nearest;
uniform sampler2D grass_top_tex : source_color, repeat_enable, filter_nearest;
uniform sampler2D dirt_tex : source_color, repeat_enable, filter_nearest;
uniform sampler2D log_side_tex : source_color, repeat_enable, filter_nearest;
uniform sampler2D log_top_tex : source_color, repeat_enable, filter_nearest;
uniform sampler2D leaves_tex : source_color, repeat_enable, filter_nearest;
uniform sampler2D oak_planks_tex : source_color, repeat_enable, filter_nearest;
uniform sampler2D crafting_table_side_tex : source_color, repeat_enable, filter_nearest;
uniform sampler2D crafting_table_top_tex : source_color, repeat_enable, filter_nearest;
uniform sampler2D sand_tex : source_color, repeat_enable, filter_nearest;
uniform sampler2D stone_tex : source_color, repeat_enable, filter_nearest;
uniform vec3 day_night_tint = vec3(1.0, 1.0, 1.0);
uniform vec3 sun_dir = vec3(0.2, 1.0, -0.3);
uniform vec3 moon_dir = vec3(-0.2, -1.0, 0.3);
uniform float sun_strength = 1.0;
uniform float moon_strength = 0.0;
uniform vec3 ambient_tint = vec3(0.8, 0.85, 0.95);

vec4 sample_face_tex(int face_id, vec2 uv) {
	if (face_id == 1) { return texture(grass_top_tex, uv); }
	if (face_id == 2) { return texture(dirt_tex, uv); }
	if (face_id == 3) { return texture(log_side_tex, uv); }
	if (face_id == 4) { return texture(log_top_tex, uv); }
	if (face_id == 5) { return texture(leaves_tex, uv); }
	if (face_id == 6) { return texture(oak_planks_tex, uv); }
	if (face_id == 7) { return texture(crafting_table_side_tex, uv); }
	if (face_id == 8) { return texture(crafting_table_top_tex, uv); }
	if (face_id == 10) { return texture(sand_tex, uv); }
	if (face_id == 11) { return texture(stone_tex, uv); }
	return texture(grass_side_tex, uv);
}

float cel_band(float v) {
	if (v > 0.90) { return 1.00; }
	if (v > 0.65) { return 0.86; }
	if (v > 0.35) { return 0.68; }
	if (v > 0.12) { return 0.52; }
	return 0.40;
}

void fragment() {
	int face_id = int(round(COLOR.r * 255.0));
	vec4 texel = sample_face_tex(face_id, UV);
	vec3 n = normalize(NORMAL);
	float sun_lambert = max(dot(n, normalize(-sun_dir)), 0.0);
	float moon_lambert = max(dot(n, normalize(-moon_dir)), 0.0);
	float sun_term = cel_band(sun_lambert) * sun_strength;
	float moon_term = cel_band(moon_lambert) * moon_strength;
	float top_bias = 0.86 + max(n.y, 0.0) * 0.20;
	vec3 lighting = ambient_tint * 0.88;
	lighting += vec3(1.12, 1.04, 0.96) * sun_term * 0.94;
	lighting += vec3(0.72, 0.80, 1.02) * moon_term * 0.40;
	ALBEDO = texel.rgb * day_night_tint * lighting * top_bias;
	ALPHA = 1.0;
	ROUGHNESS = 1.0;
}
