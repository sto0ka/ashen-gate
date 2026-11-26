shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_disable;
uniform sampler2D normal_tex : hint_normal, filter_linear, repeat_disable;
uniform float alpha_scissor : hint_range(0.0, 1.0) = 0.45;
uniform float roughness_val : hint_range(0.0, 1.0) = 0.62;
uniform float metallic_val : hint_range(0.0, 1.0) = 0.18;
uniform float normal_strength : hint_range(0.0, 3.0) = 1.65;
uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;
uniform float frost_amount : hint_range(0.0, 1.0) = 0.0;
uniform float burn_amount : hint_range(0.0, 1.0) = 0.0;
uniform float windup_glow : hint_range(0.0, 1.0) = 0.0;
uniform vec3 emissive_tint : source_color = vec3(1.0, 0.45, 0.15);
uniform float emissive_tint_weight : hint_range(0.0, 1.0) = 0.18;

void vertex() {
	// The shadow pass must use the same billboard orientation as the color pass.
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 front = MAIN_CAM_INV_VIEW_MATRIX[3].xyz - MODEL_MATRIX[3].xyz;
	front.y = 0.0;
	if (dot(front, front) < 0.0001) {
		vec3 camera_right = MAIN_CAM_INV_VIEW_MATRIX[0].xyz;
		front = camera_right.x * vec3(0.0, 0.0, 1.0) - camera_right.z * vec3(1.0, 0.0, 0.0);
		if (dot(front, front) < 0.0001) {
			front = vec3(0.0, 0.0, 1.0);
		}
	}
	front = normalize(front);
	vec3 right = cross(up, front);

	// Preserve the rig's deliberate in-plane roll and squash independently of camera pitch.
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	float roll_sin = MODEL_MATRIX[0].y / scale.x;
	float roll_cos = MODEL_MATRIX[1].y / scale.y;
	mat4 billboard = mat4(
		vec4((right * roll_cos + up * roll_sin) * scale.x, 0.0),
		vec4((up * roll_cos - right * roll_sin) * scale.y, 0.0),
		vec4(front * scale.z, 0.0),
		MODEL_MATRIX[3]
	);
	MODELVIEW_MATRIX = VIEW_MATRIX * billboard;
	MODELVIEW_NORMAL_MATRIX = transpose(inverse(mat3(MODELVIEW_MATRIX)));
}

void fragment() {
	vec4 texel = texture(albedo_tex, UV);
	ALPHA = texel.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
	if (!IN_SHADOW_PASS) {
		float peak = max(texel.r, max(texel.g, texel.b));
		float trough = min(texel.r, min(texel.g, texel.b));
		float saturation = (peak - trough) / max(peak, 0.001);
		float luminous = smoothstep(0.35, 0.86, peak) * smoothstep(0.54, 0.87, saturation);
		vec3 glow = mix(texel.rgb / max(peak, 0.001), emissive_tint, emissive_tint_weight);
		vec3 emission = glow * luminous * 3.2;
		vec3 color = texel.rgb;
		float rim = 0.0;
		if (max(frost_amount, max(burn_amount, windup_glow)) > 0.0) {
			vec2 texel_size = 2.0 / vec2(textureSize(albedo_tex, 0));
			vec2 dx = vec2(texel_size.x, 0.0);
			vec2 dy = vec2(0.0, texel_size.y);
			float neighbors = min(
				min(texture(albedo_tex, UV - dx).a, texture(albedo_tex, UV + dx).a),
				min(texture(albedo_tex, UV - dy).a, texture(albedo_tex, UV + dy).a)
			);
			rim = 1.0 - smoothstep(alpha_scissor * 0.5, 0.92, neighbors);
		}

		if (frost_amount > 0.0) {
			vec2 pixel = floor(UV * vec2(textureSize(albedo_tex, 0)));
			float facet = abs(fract((pixel.x + pixel.y * 1.7) / 23.0) - 0.5);
			float crystal = smoothstep(0.42, 0.5, facet) * step(0.48, fract(pixel.y / 13.0));
			vec3 ice = vec3(0.18, 0.68, 1.0);
			color = mix(color, mix(color * 0.38, ice, 0.26 + crystal * 0.24 + rim * 0.30), frost_amount);
			emission = mix(emission, ice * (0.92 * rim + 0.16 * crystal), frost_amount * 0.85);
		}

		float flicker = 0.72 + 0.16 * sin(TIME * 23.0 + UV.y * 32.0) + 0.12 * sin(TIME * 37.0 - UV.x * 19.0);
		vec3 ember = vec3(1.0, 0.18, 0.015);
		color = mix(color, ember, burn_amount * (0.13 + 0.40 * rim));
		emission += ember * burn_amount * flicker * (0.18 + 2.2 * rim);

		float pulse = 0.68 + 0.32 * sin(TIME * 22.0);
		vec3 telegraph = mix(vec3(1.0, 0.035, 0.065), vec3(0.55, 0.035, 1.0), emissive_tint.b);
		color = mix(color, telegraph, windup_glow * pulse * (0.13 + 0.30 * rim));
		emission += telegraph * windup_glow * pulse * (0.12 + 1.8 * rim + luminous);

		ALBEDO = mix(color, vec3(1.0), hit_flash);
		EMISSION = mix(emission, vec3(3.2, 2.9, 2.6), hit_flash);
		NORMAL_MAP = texture(normal_tex, UV).rgb;
		NORMAL_MAP_DEPTH = normal_strength;
		ROUGHNESS = mix(roughness_val, 0.35, frost_amount);
		METALLIC = metallic_val;
	}
}
