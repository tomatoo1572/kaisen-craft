shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D atlas_tex;
uniform vec2 tile_size_uv = vec2(0.0625, 0.0625);

varying vec2 v_tile_origin;

void vertex() {
	v_tile_origin = UV2;
}

void fragment() {
	vec2 tiled = v_tile_origin + fract(UV) * tile_size_uv;
	vec4 tex = texture(atlas_tex, tiled);
	ALBEDO = tex.rgb * COLOR.rgb;
	ALPHA = tex.a * COLOR.a;
}
