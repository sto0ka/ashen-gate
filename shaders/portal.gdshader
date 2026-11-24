shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform vec4 inner_color : source_color = vec4(0.48, 0.13, 0.75, 1.0);
uniform vec4 outer_color : source_color = vec4(0.10, 0.56, 0.65, 1.0);

void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(1.6, 1.1);
	float r = length(p);
	float a = atan(p.y, p.x);
	float spiral = sin(a * 5.0 - TIME * 2.0 + r * 17.0);
	float haze = sin(p.y * 19.0 + TIME * 1.5) * 0.12;
	float edge = 1.0 - smoothstep(0.56, 0.72, r);
	vec3 color = mix(inner_color.rgb, outer_color.rgb, clamp(r * 1.4 + spiral * 0.17 + haze, 0.0, 1.0));
	ALBEDO = color;
	EMISSION = color * (1.5 + spiral * 0.25);
	ALPHA = edge * (0.74 + spiral * 0.1);
}
