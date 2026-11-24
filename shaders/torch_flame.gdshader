shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec3 core_color : source_color = vec3(1.0, 0.92, 0.62);
uniform vec3 outer_color : source_color = vec3(1.0, 0.34, 0.06);

void vertex() {
	// Y-axis cylindrical billboard so flame always faces camera smoothly
	vec3 cam_right = vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z);
	if (length(cam_right) > 0.001) {
		cam_right = normalize(cam_right);
	} else {
		cam_right = vec3(1.0, 0.0, 0.0);
	}
	vec3 world_pos = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float sway = sin(TIME * 8.5 + world_pos.x * 2.3 + world_pos.z * 1.9) * 0.08 * (1.0 - UV.y);
	vec3 displaced = cam_right * (VERTEX.x + sway) + vec3(0.0, VERTEX.y, 0.0);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world_pos + displaced, 1.0);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.y = -p.y;
	float flicker = sin(TIME * 14.0 + p.y * 5.0) * 0.09 + cos(TIME * 21.0 - p.y * 7.0) * 0.05;
	float width = mix(0.68, 0.08, clamp((p.y + 1.0) * 0.5, 0.0, 1.0));
	float dx = abs(p.x + flicker * (p.y + 1.0));
	float shape = smoothstep(width, width * 0.15, dx) * smoothstep(-1.0, -0.55, p.y) * smoothstep(1.0, 0.1, p.y);
	float core = smoothstep(width * 0.55, 0.0, dx) * smoothstep(-0.9, -0.2, p.y) * smoothstep(0.55, -0.35, p.y);
	vec3 col = mix(outer_color, core_color, core);
	ALBEDO = col * 1.85;
	ALPHA = clamp(shape * 0.95, 0.0, 1.0);
}
