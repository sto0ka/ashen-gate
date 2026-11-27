shader_type canvas_item;
render_mode unshaded, blend_mix;

// Fullscreen resonance pulse: a crisp radial RGB split plus a tinted edge vignette.
// Lives on a canvas below HUD text and above the 3D view. Hide the rect at rest so
// the screen copy costs nothing.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform vec3 pulse_color : source_color = vec3(0.72, 0.48, 1.0);
// Channel offset in output pixels at the screen corners. Kept to 1.5 px for a sharp look.
uniform float max_shift_px : hint_range(0.0, 2.0) = 1.5;
uniform float vignette_amount : hint_range(0.0, 1.0) = 0.62;

void fragment() {
	float s = clamp(strength, 0.0, 1.0);
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	// Aspect-correct radial frame: 0 at the centre, 1 at the corners.
	vec2 centered = (uv - 0.5) / px;
	vec2 half_extent = 0.5 / px;
	float radius = length(centered) / length(half_extent);
	vec2 dir = centered / max(length(centered), 1.0);
	// Quadratic falloff keeps the centre untouched and peaks at the corners.
	float shift = min(max_shift_px, 2.0) * s * radius * radius;
	vec2 offset = dir * shift * px;
	// Mip level 0 only: never blur the frame.
	float r = textureLod(screen_texture, uv + offset, 0.0).r;
	vec2 gb = textureLod(screen_texture, uv, 0.0).gb;
	float b = textureLod(screen_texture, uv - offset, 0.0).b;
	vec3 color = vec3(r, gb.x, gb.y);

	// Edge vignette: darken and tint toward the pulse colour, never the centre.
	float edge = smoothstep(0.42, 1.08, radius) * s * vignette_amount;
	vec3 tinted = color * mix(vec3(1.0), pulse_color, 0.78) * 0.58 + pulse_color * 0.045;
	color = mix(color, tinted, edge);
	// A faint luminous rim right at the frame edge sells the "toll" pressure wave.
	float rim = smoothstep(0.86, 1.0, radius) * s * 0.10;
	color += pulse_color * rim;
	COLOR = vec4(color, 1.0);
}
