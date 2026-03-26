shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;

uniform sampler2D grass_side_tex : source_color, repeat_enable, filter_nearest;
uniform sampler2D grass_top_tex : source_color, repeat_enable, filter_nearest;
uniform sampler2D dirt_tex : source_color, repeat_enable, filter_nearest;
uniform sampler2D log_side_tex : source_color, repeat_enable, filter_nearest;
uniform sampler2D log_top_tex : source_color, repeat_enable, filter_nearest;
uniform sampler2D leaves_tex : source_color, repeat_enable, filter_nearest;
uniform sampler2D oak_planks_tex : source_color, repeat_enable, filter_nearest;
uniform sampler2D crafting_table_side_tex : source_color, repeat_enable, filter_nearest;
uniform sampler2D crafting_table_top_tex : source_color, repeat_enable, filter_nearest;
uniform sampler2D water_tex : source_color, repeat_enable, filter_nearest;
uniform sampler2D sand_tex : source_color, repeat_enable, filter_nearest;
uniform sampler2D stone_tex : source_color, repeat_enable, filter_nearest;
uniform vec3 day_night_tint = vec3(1.0, 1.0, 1.0);
uniform vec3 sun_dir = vec3(0.2, 1.0, -0.3);
uniform vec3 moon_dir = vec3(-0.2, -1.0, 0.3);
uniform float sun_strength = 1.0;
uniform float moon_strength = 0.0;
uniform vec3 ambient_tint = vec3(0.8, 0.85, 0.95);

vec4 sample_face_tex(int face_id, vec2 uv) {
	if (face_id == 5) { return texture(leaves_tex, uv); }
	return texture(leaves_tex, uv);
}

float cel_band(float v) {
	if (v > 0.82) { return 1.00; }
	if (v > 0.50) { return 0.82; }
	if (v > 0.20) { return 0.62; }
	return 0.46;
}

void fragment() {
	int face_id = int(round(COLOR.r * 255.0));
	vec4 texel = sample_face_tex(face_id, UV);
	if (texel.a < 0.45) {
		discard;
	}
	vec3 n = normalize(NORMAL);
	float sun_lambert = max(dot(n, normalize(-sun_dir)), 0.0);
	float moon_lambert = max(dot(n, normalize(-moon_dir)), 0.0);
	float sun_term = cel_band(sun_lambert) * sun_strength;
	float moon_term = cel_band(moon_lambert) * moon_strength;
	vec3 lighting = ambient_tint * 0.78;
	lighting += vec3(1.00, 0.98, 0.94) * sun_term * 0.66;
	lighting += vec3(0.64, 0.74, 0.94) * moon_term * 0.26;
	ALBEDO = texel.rgb * day_night_tint * lighting;
	ALPHA = 1.0;
	ROUGHNESS = 1.0;
}
