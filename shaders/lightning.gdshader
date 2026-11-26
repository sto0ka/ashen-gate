shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 arc_color : source_color = vec4(0.42, 0.94, 1.0, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 1.0;
uniform bool plasma_orb = false;

float hash(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}

void fragment() {
	float tick = floor(TIME * 48.0);
	float flicker = 0.68 + 0.32 * hash(tick);
	float core;
	float halo;
	if (plasma_orb) {
		float facing = abs(dot(normalize(NORMAL), VIEW));
		float angle = UV.x * 6.2831853;
		float warp = sin(UV.y * 39.0 + sin(angle * 7.0 + tick * 2.4) * 1.8);
		float filament = pow(1.0 - abs(warp), 6.0);
		core = pow(facing, 4.0) * 0.88 + filament * 0.36;
		halo = smoothstep(0.0, 0.45, facing) * (0.32 + filament * 0.55);
	} else {
		float jitter = (hash(floor(UV.y * 51.0) + tick * 13.0) - 0.5) * 0.20;
		jitter += sin(UV.y * 137.0 - TIME * 87.0) * 0.055;
		float distance_to_core = abs(UV.x * 2.0 - 1.0 + jitter);
		core = 1.0 - smoothstep(0.035, 0.23, distance_to_core);
		halo = (1.0 - smoothstep(0.12, 0.82, distance_to_core)) * 0.48;
	}
	ALBEDO = mix(arc_color.rgb, vec3(0.90, 0.98, 1.0), clamp(core, 0.0, 1.0));
	ALBEDO *= 1.65 + core * 2.1;
	ALPHA = clamp((core * 0.8 + halo) * flicker * intensity * arc_color.a, 0.0, 1.0);
}
