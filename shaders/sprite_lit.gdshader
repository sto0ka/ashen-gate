shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_disable;
uniform sampler2D normal_tex : hint_normal, filter_linear, repeat_disable;
uniform sampler2D volume_tex : hint_default_black, filter_linear, repeat_disable;
uniform float alpha_scissor : hint_range(0.0, 1.0) = 0.45;
uniform float roughness_val : hint_range(0.0, 1.0) = 0.62;
uniform float metallic_val : hint_range(0.0, 1.0) = 0.18;
uniform float normal_strength : hint_range(0.0, 3.0) = 1.8;
uniform float hit_flash : hint_range(0.0, 1.0) = 0.0;
uniform float frost_amount : hint_range(0.0, 1.0) = 0.0;
uniform float burn_amount : hint_range(0.0, 1.0) = 0.0;
uniform float windup_glow : hint_range(0.0, 1.0) = 0.0;
uniform vec3 emissive_tint : source_color = vec3(1.0, 0.45, 0.15);
uniform float emissive_tint_weight : hint_range(0.0, 1.0) = 0.18;

uniform float walk_phase = 0.0;
uniform float walk_speed : hint_range(0.0, 1.0) = 0.0;
uniform float attack_phase : hint_range(0.0, 1.0) = 0.0;
uniform float hit_recoil : hint_range(0.0, 1.0) = 0.0;
uniform float idle_time = 0.0;
uniform float facing_flip = 1.0;
uniform float parry_flash : hint_range(0.0, 1.0) = 0.0;
uniform float bounds_v_min = 0.0;
uniform float bounds_v_max = 1.0;
uniform float bounds_u_min = 0.0;
uniform float bounds_u_max = 1.0;
uniform vec2 uv_padding = vec2(0.0);
uniform vec2 weapon_uv = vec2(0.25, 0.45);
uniform float ground_lift = 0.0;
uniform float relief_yaw = 0.0;
uniform float speaking : hint_range(0.0, 1.0) = 0.0;

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

// Inverse deformation samples the painted art from the position that moved into this pixel.
vec2 pose_uv(vec2 uv) {
	vec2 span = max(vec2(bounds_u_max - bounds_u_min, bounds_v_max - bounds_v_min), vec2(0.001));
	float rel_u = (uv.x - bounds_u_min) / span.x * 2.0 - 1.0;
	float rel_v = clamp((uv.y - bounds_v_min) / span.y, 0.0, 1.0);
	float step_wave = sin(walk_phase);
	float leg_side = smoothstep(-0.12, 0.12, rel_u);
	float leg_cycle = mix(step_wave, -step_wave, leg_side);
	float lift = max(leg_cycle, 0.0);
	float legs = smoothstep(0.62, 0.91, rel_v);
	float swing_side = mix(-1.0, 1.0, leg_side);
	vec2 legs_offset = vec2(-swing_side * lift * 0.047, lift * 0.078) * legs * walk_speed;
	// Counter the root bob at the boots so the supporting foot stays on the floor.
	legs_offset.y -= ground_lift * legs;

	float hips = smoothstep(0.25, 0.47, rel_v) * (1.0 - smoothstep(0.52, 0.69, rel_v));
	float chest = smoothstep(0.08, 0.28, rel_v) * (1.0 - smoothstep(0.43, 0.74, rel_v));
	float breath = sin(idle_time * 2.4) * 0.014 * (1.0 - walk_speed);
	float voice = speaking * (0.55 * sin(idle_time * 10.0) + 0.45 * sin(idle_time * 15.0));
	float run_shear = step_wave * walk_speed * walk_speed * 0.018;
	vec2 trunk = vec2(-step_wave * 0.034 * hips * walk_speed - (rel_u * (breath + voice * 0.009) + run_shear) * chest,
		(breath + voice * 0.005 - run_shear * rel_u) * chest + rel_u * step_wave * hips * walk_speed * 0.018);

	float strike = smoothstep(0.78, 1.0, attack_phase);
	float coil = smoothstep(0.0, 0.78, attack_phase) * (1.0 - strike);
	float weapon_side = sign(weapon_uv.x - (bounds_u_min + bounds_u_max) * 0.5);
	float upper = 1.0 - smoothstep(0.32, 0.62, rel_v);
	float arm = smoothstep(-0.38, 0.66, rel_u * weapon_side) * (1.0 - smoothstep(0.43, 0.65, rel_v));
	vec2 attack = vec2(weapon_side * (strike * 0.13 - coil * 0.068) * (upper * 0.4 + arm * 0.6),
		(coil * 0.077 - strike * 0.106) * arm - strike * 0.028 * upper);
	vec2 recoil = vec2(0.034 + 0.013 * sin(idle_time * 39.0), 0.027) * upper * hit_recoil;
	return uv + (legs_offset + trunk + attack + recoil) * span;
}

void fragment() {
	vec2 frame_uv = UV * (1.0 + 2.0 * uv_padding) - uv_padding;
	frame_uv.x = mix(frame_uv.x, 1.0 - frame_uv.x, step(facing_flip, 0.0));
	vec2 uv = pose_uv(frame_uv);
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) {
		discard;
	}
	vec4 texel = texture(albedo_tex, uv);
	ALPHA = texel.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
	if (!IN_SHADOW_PASS) {
		vec3 plane_normal = normalize(NORMAL);
		vec3 right = normalize(TANGENT);
		vec3 up = normalize(cross(plane_normal, right));
		float mirror = sign(facing_flip);
		vec4 volume = texture(volume_tex, uv);
		vec2 tangent_view = vec2((dot(VIEW, right) + relief_yaw) * mirror, -dot(VIEW, up));
		vec2 relief_uv = uv + clamp(tangent_view, vec2(-0.75), vec2(0.75)) * volume.r * vec2(0.027, 0.019);
		if (all(greaterThanEqual(relief_uv, vec2(0.0))) && all(lessThanEqual(relief_uv, vec2(1.0)))) {
			vec4 relief = texture(albedo_tex, relief_uv);
			float solid = smoothstep(alpha_scissor, min(alpha_scissor + 0.16, 1.001), relief.a);
			uv = mix(uv, relief_uv, solid);
			texel.rgb = mix(texel.rgb, relief.rgb, solid);
			volume = texture(volume_tex, uv);
		}
		vec2 slope = (texture(normal_tex, uv).rg * 2.0 - 1.0) * vec2(mirror, 1.0);
		vec3 sculpted = vec3(slope, sqrt(max(1.0 - dot(slope, slope), 0.001)));
		vec3 lit_normal = normalize(right * sculpted.x * normal_strength +
			up * sculpted.y * normal_strength + plane_normal * sculpted.z);
		float fresnel = pow(1.0 - abs(dot(lit_normal, VIEW)), 2.5);
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
				min(texture(albedo_tex, uv - dx).a, texture(albedo_tex, uv + dx).a),
				min(texture(albedo_tex, uv - dy).a, texture(albedo_tex, uv + dy).a)
			);
			rim = 1.0 - smoothstep(alpha_scissor * 0.5, 0.92, neighbors);
		}

		if (frost_amount > 0.0) {
			vec2 pixel = floor(uv * vec2(textureSize(albedo_tex, 0)));
			float facet = abs(fract((pixel.x + pixel.y * 1.7) / 23.0) - 0.5);
			float crystal = smoothstep(0.42, 0.5, facet) * step(0.48, fract(pixel.y / 13.0));
			vec3 ice = vec3(0.18, 0.68, 1.0);
			color = mix(color, mix(color * 0.38, ice, 0.26 + crystal * 0.24 + rim * 0.30), frost_amount);
			emission = mix(emission, ice * (0.92 * rim + 0.16 * crystal), frost_amount * 0.85);
		}

		float flicker = 0.72 + 0.16 * sin(TIME * 23.0 + uv.y * 32.0) + 0.12 * sin(TIME * 37.0 - uv.x * 19.0);
		vec3 ember = vec3(1.0, 0.18, 0.015);
		color = mix(color, ember, burn_amount * (0.13 + 0.40 * rim));
		emission += ember * burn_amount * flicker * (0.18 + 2.2 * rim);

		float pulse = 0.68 + 0.32 * sin(TIME * 22.0);
		vec3 telegraph = mix(vec3(1.0, 0.035, 0.065), vec3(0.55, 0.035, 1.0), emissive_tint.b);
		color = mix(color, telegraph, windup_glow * pulse * (0.13 + 0.30 * rim));
		emission += telegraph * windup_glow * pulse * (0.12 + 1.8 * rim + luminous);

		vec3 rim_tint = mix(vec3(0.24, 0.39, 0.60), vec3(0.65, 0.27, 0.085),
			smoothstep(-0.6, 0.6, slope.x));
		emission += rim_tint * fresnel * (0.18 + 0.16 * peak);

		vec2 glint_pos = (uv - weapon_uv) / vec2(0.10, 0.067);
		vec2 glint_axis = abs(glint_pos);
		float rays = max(exp(-glint_axis.x * 3.0 - glint_axis.y * 18.0),
			exp(-glint_axis.y * 3.0 - glint_axis.x * 18.0));
		float glint_core = exp(-dot(glint_pos, glint_pos) * 17.0);
		float upper_glint = 1.0 - smoothstep(bounds_v_min, mix(bounds_v_min, bounds_v_max, 0.67), uv.y);
		emission += parry_flash * (vec3(3.8, 1.52, 0.19) * (rays + fresnel * upper_glint * 0.38)
			+ vec3(4.0, 3.1, 1.8) * glint_core);

		float source_zone = (uv.y - bounds_v_min) / max(bounds_v_max - bounds_v_min, 0.001);
		float contact = smoothstep(0.90, 1.0, min(volume.a, source_zone));
		ALBEDO = mix(color * (1.0 - contact * 0.62), vec3(1.0), hit_flash);
		EMISSION = mix(emission * (1.0 - contact * 0.75), vec3(3.2, 2.9, 2.6), hit_flash);
		NORMAL = lit_normal;
		ROUGHNESS = mix(clamp(roughness_val + volume.b * 0.56 - volume.g * 0.28, 0.22, 0.92), 0.35, frost_amount);
		METALLIC = clamp(metallic_val + volume.g * 0.50, 0.0, 0.78);
	}
}
