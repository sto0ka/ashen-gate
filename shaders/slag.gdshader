shader_type spatial;
render_mode cull_back, specular_schlick_ggx;

uniform vec3 crust_color : source_color = vec3(0.11, 0.07, 0.06);
uniform vec3 magma_mid : source_color = vec3(0.95, 0.24, 0.04);
uniform vec3 magma_hot : source_color = vec3(1.0, 0.78, 0.28);
uniform float scale = 4.2;
uniform float speed = 0.35;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
	           mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.05;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV * scale;
	float warp = fbm(uv + vec2(TIME * speed * 0.5, -TIME * speed));
	float n = fbm(uv + vec2(warp * 1.4, TIME * speed * 0.7));
	float vein = smoothstep(0.36, 0.68, n);
	float hot = smoothstep(0.60, 0.84, n);
	float pulse = 0.85 + 0.15 * sin(TIME * 3.0 + n * 8.0);
	vec3 col = mix(crust_color, magma_mid, vein);
	col = mix(col, magma_hot, hot);
	ALBEDO = col;
	ROUGHNESS = mix(0.92, 0.22, vein);
	METALLIC = 0.05;
	EMISSION = mix(vec3(0.0), magma_mid * 2.2, vein) + magma_hot * hot * 2.8 * pulse;
}
