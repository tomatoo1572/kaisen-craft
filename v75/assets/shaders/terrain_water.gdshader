shader_type spatial;
render_mode cull_back, depth_draw_opaque;

uniform sampler2D water_tex : source_color, repeat_enable, filter_nearest;
uniform vec3 day_night_tint = vec3(1.0, 1.0, 1.0);
uniform vec3 sun_dir = vec3(0.2, 1.0, -0.3);
uniform vec3 moon_dir = vec3(-0.2, -1.0, 0.3);
uniform float sun_strength = 1.0;
uniform float moon_strength = 0.0;
uniform vec3 ambient_tint = vec3(0.8, 0.85, 0.95);

varying vec2 world_uv;

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_uv = world_pos.xz * 0.0625;
}

float cel_band(float v) {
	if (v > 0.82) { return 1.00; }
	if (v > 0.48) { return 0.82; }
	if (v > 0.18) { return 0.64; }
	return 0.46;
}

void fragment() {
	vec2 uv = world_uv + vec2(TIME * 0.008, TIME * 0.005);
	vec4 texel = texture(water_tex, uv);
	vec3 n = normalize(NORMAL);
	float sun_lambert = max(dot(n, normalize(-sun_dir)), 0.0);
	float moon_lambert = max(dot(n, normalize(-moon_dir)), 0.0);
	float sun_term = cel_band(sun_lambert) * sun_strength;
	float moon_term = cel_band(moon_lambert) * moon_strength;
	vec3 lighting = ambient_tint * 0.72;
	lighting += vec3(0.34, 0.50, 0.88) * sun_term * 0.52;
	lighting += vec3(0.26, 0.36, 0.70) * moon_term * 0.32;
	ALBEDO = texel.rgb * day_night_tint * lighting;
	ALPHA = 1.0;
	ROUGHNESS = 0.18;
	METALLIC = 0.0;
}
