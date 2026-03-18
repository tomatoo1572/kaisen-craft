shader_type spatial;
render_mode blend_mix, cull_disabled, depth_prepass_alpha;

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
uniform sampler2D water_tex : source_color, repeat_enable, filter_nearest;
uniform vec3 day_night_tint = vec3(1.0, 1.0, 1.0);
uniform vec3 sun_dir = vec3(0.2, 1.0, -0.3);
uniform vec3 moon_dir = vec3(-0.2, -1.0, 0.3);
uniform float sun_strength = 1.0;
uniform float moon_strength = 0.0;
uniform vec3 ambient_tint = vec3(0.8, 0.85, 0.95);

float cel_band(float v) {
	if (v > 0.75) { return 1.00; }
	if (v > 0.35) { return 0.78; }
	return 0.56;
}

void fragment() {
	vec4 texel = texture(water_tex, UV);
	vec3 n = normalize(NORMAL);
	float sun_lambert = max(dot(n, normalize(-sun_dir)), 0.0);
	float moon_lambert = max(dot(n, normalize(-moon_dir)), 0.0);
	float sun_term = cel_band(sun_lambert) * sun_strength;
	float moon_term = cel_band(moon_lambert) * moon_strength;
	vec3 lighting = ambient_tint * 0.90;
	lighting += vec3(0.52, 0.74, 1.16) * sun_term * 0.48;
	lighting += vec3(0.40, 0.62, 1.12) * moon_term * 0.30;
	ALBEDO = texel.rgb * day_night_tint * lighting;
	ALPHA = 0.72;
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
}
