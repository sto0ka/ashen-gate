shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

uniform vec4 deep_color : source_color = vec4(0.05, 0.14, 0.19, 0.90);
uniform vec4 shallow_color : source_color = vec4(0.16, 0.38, 0.48, 0.86);
uniform vec4 foam_color : source_color = vec4(0.68, 0.88, 0.95, 1.0);
uniform vec2 flow_dir = vec2(0.0, 0.45);
uniform float wave_scale = 5.5;
uniform float speed = 1.4;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 uv1 = UV * wave_scale + flow_dir * TIME * speed;
	vec2 uv2 = UV * (wave_scale * 1.7) - flow_dir.yx * TIME * (speed * 0.7);
	float n1 = noise(uv1);
	float n2 = noise(uv2);
	float ripple = (n1 + n2) * 0.5;
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float crest = smoothstep(0.68, 0.88, ripple);
	vec3 col = mix(deep_color.rgb, shallow_color.rgb, ripple * 0.65 + fresnel * 0.5);
	col = mix(col, foam_color.rgb, crest * 0.55);
	ALBEDO = col;
	ALPHA = mix(deep_color.a, 0.96, fresnel * 0.5 + crest * 0.4);
	ROUGHNESS = mix(0.18, 0.05, fresnel);
	METALLIC = 0.15;
	SPECULAR = 0.85;
	EMISSION = shallow_color.rgb * (0.14 + crest * 0.28);
	// Perturb normal for crisp moving light reflections
	float eps = 0.08;
	float nx = noise(uv1 + vec2(eps, 0.0)) - n1;
	float ny = noise(uv1 + vec2(0.0, eps)) - n1;
	NORMAL_MAP = normalize(vec3(-nx * 2.2, -ny * 2.2, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.65;
}
