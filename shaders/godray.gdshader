shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 shaft_color : source_color = vec4(0.65, 0.78, 1.0, 0.22);

float hash(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	// CylinderMesh packs the side wall into the upper half of the UV atlas.
	float depth = UV.y * 2.0;
	float edge = smoothstep(0.04, 0.76, abs(dot(normalize(NORMAL), VIEW)));
	float falloff = (1.0 - smoothstep(0.06, 1.0, depth)) * smoothstep(0.0, 0.07, depth);
	vec2 dust_uv = vec2(UV.x, depth) * vec2(40.0, 54.0) + TIME * vec2(0.24, -1.35);
	vec2 cell = floor(dust_uv);
	cell.x = mod(cell.x, 40.0);
	vec2 offset = vec2(hash(cell), hash(cell + 7.0)) * 0.58 + 0.21;
	float mote = (1.0 - smoothstep(0.05, 0.19, length(fract(dust_uv) - offset)));
	mote *= step(0.87, hash(cell + 13.0));
	ALBEDO = shaft_color.rgb * (0.82 + mote * 1.15);
	ALPHA = shaft_color.a * edge * falloff * (0.56 + mote * 0.22);
}
