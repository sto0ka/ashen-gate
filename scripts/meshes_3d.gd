class_name Meshes3D
extends RefCounted

const LIGHTNING_SHADER := preload("res://shaders/lightning.gdshader")
const SPRITE_SHADER := preload("res://shaders/sprite_lit.gdshader")

static var _sprite_assets: Dictionary[String, Dictionary] = {}


# Viewmodels are grip-centered and point toward -Z. Rigs stand at Y = 0 and also face -Z.
static func build_weapon_viewmodel(weapon_id: String, mats: Dictionary) -> Node3D:
	var root := _pivot(null, weapon_id)
	var kit := _materials(mats)
	match weapon_id:
		"axe":
			_build_axe(root, kit)
		"arbalest":
			_build_arbalest(root, kit)
		"thurible":
			_build_thurible(root, kit)
		"voltaic":
			_build_voltaic(root, kit)
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root


static func _build_axe(root: Node3D, kit: Dictionary) -> void:
	_rod(root, Vector3(0, -0.35, 0), Vector3(0, 0.52, 0), 0.038, kit.timber, 10)
	_rod(root, Vector3(0, -0.26, 0), Vector3(0, 0.11, 0), 0.048, kit.leather, 10)
	for i in 12:
		var wrap := _ring(root, Vector3(0, -0.25 + i * 0.031, 0), 0.046, 0.007, kit.leather_trim)
		wrap.rotation.z = 0.20
	for y: float in [-0.34, -0.28, 0.14, 0.32, 0.48, 0.53]:
		_frustum(root, Vector3(0, y, 0), 0.055, 0.052, 0.032, kit.iron, 10)
	_box(root, Vector3(0, 0.39, 0), Vector3(0.12, 0.20, 0.111), kit.iron)
	var blade := PackedVector2Array([
		Vector2(0.015, 0.47), Vector2(0.16, 0.52), Vector2(0.31, 0.61),
		Vector2(0.40, 0.49), Vector2(0.425, 0.37), Vector2(0.41, 0.27),
		Vector2(0.36, 0.18), Vector2(0.27, 0.11), Vector2(0.17, 0.14),
		Vector2(0.23, 0.23), Vector2(0.22, 0.31), Vector2(0.02, 0.32),
	])
	_prism(root, Vector3.ZERO, blade, 0.048, kit.silver)
	_prism(root, Vector3.ZERO, PackedVector2Array([
		Vector2(0.015, 0.45), Vector2(0.171, 0.49), Vector2(0.30, 0.565),
		Vector2(0.365, 0.47), Vector2(0.39, 0.37), Vector2(0.37, 0.28),
		Vector2(0.325, 0.20), Vector2(0.24, 0.145), Vector2(0.268, 0.248),
		Vector2(0.24, 0.342), Vector2(0.02, 0.34),
	]), 0.070, kit.iron)
	_prism(root, Vector3.ZERO, PackedVector2Array([
		Vector2(-0.026, 0.46), Vector2(-0.22, 0.49), Vector2(-0.16, 0.38), Vector2(-0.035, 0.35),
	]), 0.062, kit.silver)
	for x: float in [0.07, 0.113]:
		_rod(root, Vector3(x, 0.41, -0.05), Vector3(x, 0.41, 0.051), 0.015, kit.brass, 6)
	var rune := _pivot(root, "rune_glow")
	for z: float in [-0.036, 0.036]:
		var top := Vector3(0.24, 0.47, z)
		var mid := Vector3(0.29, 0.41, z)
		var base := Vector3(0.26, 0.35, z)
		_rod(rune, top, mid, 0.007, kit.mana, 5)
		_rod(rune, mid, base, 0.007, kit.mana, 5)
		_rod(rune, top, Vector3(0.19, 0.39, z), 0.007, kit.mana, 5)
		_rod(rune, mid, Vector3(0.335, 0.43, z), 0.006, kit.mana, 5)
	_light(rune, Vector3(0.27, 0.41, 0.12), Color("80efff"), 0.20, 0.8)


static func _build_arbalest(root: Node3D, kit: Dictionary) -> void:
	# The long stock sits under the flight rail; the prod tips sweep back toward the string catch.
	_prism(root, Vector3.ZERO, PackedVector2Array([
		Vector2(-0.055, 0.42), Vector2(-0.075, 0.26), Vector2(-0.046, -0.27),
		Vector2(-0.058, -0.42), Vector2(0.058, -0.42), Vector2(0.046, -0.27),
		Vector2(0.075, 0.26), Vector2(0.055, 0.42),
	]), 0.105, kit.timber).rotation.x = -PI * 0.5
	_box(root, Vector3(0, -0.105, 0.14), Vector3(0.087, 0.21, 0.10), kit.leather).rotation.x = -0.30
	for x: float in [-0.035, 0.035]:
		_box(root, Vector3(x, 0.057, -0.08), Vector3(0.019, 0.016, 0.59), kit.iron)
	for z: float in [-0.38, -0.26, 0.24, 0.38]:
		_box(root, Vector3(0, 0, z), Vector3(0.127, 0.119, 0.024), kit.brass)
	for side: float in [-1.0, 1.0]:
		var end := Vector3(0.48 * side, 0.04, -0.12)
		var prod := PackedVector3Array([
			Vector3(0.026 * side, 0.015, -0.338), Vector3(0.17 * side, 0.043, -0.357),
			Vector3(0.29 * side, 0.055, -0.305), Vector3(0.41 * side, 0.05, -0.217), end,
		])
		for i in range(prod.size() - 1):
			var thickness := 0.025 - i * 0.0045
			_rod(root, prod[i], prod[i + 1], thickness, kit.iron, 6, thickness - 0.004)
			_rod(root, prod[i] + Vector3.UP * 0.021, prod[i + 1] + Vector3.UP * 0.016, thickness * 0.39, kit.silver, 6)
		_sphere(root, end, Vector3.ONE * 0.018, kit.brass, 8)
		_rod(root, end, Vector3(0, 0.077, 0.19), 0.004, kit.cord, 5)
		for i in 3:
			var z := -0.05 + i * 0.09
			_rod(root, Vector3(side * 0.064, -0.022, z), Vector3(side * 0.071, 0.017, z - 0.05), 0.006, kit.brass, 5)
	_ring(root, Vector3(0, 0, -0.455), 0.082, 0.013, kit.brass).scale.x = 0.8
	var bolt := _pivot(root, "bolt_mesh")
	_rod(bolt, Vector3(0, 0.078, 0.22), Vector3(0, 0.078, -0.41), 0.012, kit.acid, 6)
	_rod(bolt, Vector3(0, 0.078, -0.39), Vector3(0, 0.078, -0.51), 0.034, kit.acid, 4, 0.0)
	for side: float in [-1.0, 1.0]:
		_box(bolt, Vector3(side * 0.015, 0.078, 0.173), Vector3(0.03, 0.008, 0.085), kit.silver).rotation.y = side * 0.16


static func _build_thurible(root: Node3D, kit: Dictionary) -> void:
	_rod(root, Vector3(-0.1, 0, 0), Vector3(0.1, 0, 0), 0.042, kit.leather, 10)
	_ring(root, Vector3(0, -0.042, 0), 0.047, 0.011, kit.brass).rotation.x = PI * 0.5
	# Rotate the whole hanging assembly around the suspension eye.
	var suspension := _pivot(root, "censer_bowl", Vector3(0, -0.08, 0))
	var bowl := _pivot(suspension, "bowl_shell", Vector3(0, -0.54, -0.12))
	for i in 3:
		var azimuth := TAU * i / 3.0
		var anchor := Vector3(cos(azimuth) * 0.145, 0.161, sin(azimuth) * 0.145)
		_chain(bowl, Vector3(0, 0.54, 0.12), anchor, 10, 0.024, kit.brass)
	_cage(bowl, 0.19, 0.32, kit.brass, kit.iron, kit.ember)
	for i in 8:
		var angle := TAU * i / 8.0
		var radial := Vector3(cos(angle), 0, sin(angle))
		_sphere(bowl, radial * 0.178 + Vector3.DOWN * 0.083, Vector3.ONE * 0.018, kit.copper, 6)
	_rod(bowl, Vector3(0, -0.145, 0), Vector3(0, -0.242, 0), 0.051, kit.brass, 8, 0.012)
	_light(bowl, Vector3(0, 0, -0.05), Color("ff822f"), 0.52, 1.25)


static func _build_voltaic(root: Node3D, kit: Dictionary) -> void:
	_frustum(root, Vector3(0, -0.12, 0), 0.071, 0.051, 0.35, kit.ceramic, 12)
	for i in 7:
		_frustum(root, Vector3(0, -0.26 + i * 0.045, 0), 0.069 + i * 0.002, 0.07 + i * 0.002, 0.018, kit.copper, 12)
	_frustum(root, Vector3(0, 0.069, 0), 0.111, 0.071, 0.06, kit.brass, 8)
	for side: float in [-1.0, 1.0]:
		var fork := PackedVector2Array([
			Vector2(0.032, 0.091), Vector2(0.105, 0.102), Vector2(0.176, 0.21),
			Vector2(0.186, 0.47), Vector2(0.167, 0.53), Vector2(0.125, 0.505),
			Vector2(0.124, 0.235), Vector2(0.055, 0.154),
		])
		for i in fork.size():
			fork[i] = Vector2(fork[i].x * side, fork[i].y)
		_prism(root, Vector3.ZERO, fork, 0.071, kit.silver)
		_rod(root, Vector3(side * 0.156, 0.24, 0.041), Vector3(side * 0.157, 0.445, 0.041), 0.017, kit.brass, 6, 0.010)
		_sphere(root, Vector3(side * 0.148, 0.475, 0), Vector3(0.039, 0.027, 0.035), kit.brass, 8)
	var plasma := ShaderMaterial.new()
	plasma.shader = LIGHTNING_SHADER
	plasma.set_shader_parameter("plasma_orb", true)
	var orb := SphereMesh.new()
	orb.radius = 0.102
	orb.height = 0.194
	orb.radial_segments = 20
	orb.rings = 10
	var spark := _mesh(root, Vector3(0, 0.467, 0), orb, plasma)
	spark.name = "spark_core"
	_sphere(spark, Vector3.ZERO, Vector3.ONE * 0.034, kit.mana, 12)
	_light(spark, Vector3.ZERO, Color("6bf0ff"), 0.64, 1.4)


static func build_enemy_rig(kind: String, mats: Dictionary) -> Node3D:
	match kind:
		"executioner":
			var rig := _sprite_rig(kind, "res://art/sentinel.png", 2.55, Vector2(0.50, 0.13), Color("ff9c48"), 0.25, 1.35)
			var arm: Node3D = rig.get_meta("arm_l")
			var shield := _pivot(arm, "shield_node", Vector3(-0.16, -0.45, -0.26))
			shield.rotation.y = 0.17
			_shield(shield, _materials(mats))
			rig.set_meta("shield_node", shield)
			return rig
		"acolyte":
			var rig := _sprite_rig(kind, "res://art/acolyte.png", 2.35, Vector2(0.82, 0.15), Color("be66ff"), 0.82, 2.5)
			rig.set_meta("hovering", true)
			var body: Node3D = rig.get_meta("body_pivot")
			body.position.y += 0.16
			return rig
		"stalker":
			var path := _sprite_path("stalker", "wretch")
			var fallback := path.ends_with("/wretch.png")
			var glow_uv := Vector2(0.55, 0.13) if fallback else Vector2(0.50, 0.29)
			return _sprite_rig(kind, path, 2.25, glow_uv, Color("ff9cba"), 0.44, 1.65, fallback)
		"ash_sentinel":
			var path := _sprite_path("ash_sentinel", "sentinel")
			var rig := _sprite_rig(kind, path, 2.95, Vector2(0.50, 0.36), Color("ff993d"), 1.10, 2.75)
			var body: Node3D = rig.get_meta("body_pivot")
			var hoops := _pivot(body, "hoops_node", Vector3(0, 0.02, 0))
			var hoop := _ring(hoops, Vector3.ZERO, 0.36, 0.023, _materials(mats).iron, 16)
			hoop.scale.z = 0.62
			hoop.rotation.z = 0.09
			rig.set_meta("hoops_node", hoops)
			return rig
		"warden":
			return _sprite_rig(kind, "res://art/bell_warden.png", 4.75, Vector2(0.56, 0.38), Color("9548f2"), 1.55, 3.9)
		"colossus":
			var path := _sprite_path("colossus", "bell_warden")
			var fallback := path.ends_with("/bell_warden.png")
			var glow_uv := Vector2(0.56, 0.38) if fallback else Vector2(0.50, 0.37)
			return _sprite_rig(kind, path, 4.95, glow_uv, Color("ff6b26"), 2.25, 4.5, fallback)
		_:
			return _sprite_rig("shrieker", "res://art/wretch.png", 2.15, Vector2(0.55, 0.13), Color("ffb447"), 0.32, 1.4)


static func build_npc_rig(npc_kind: String, _mats: Dictionary) -> Node3D:
	match npc_kind:
		"seraphina":
			var path := _sprite_path("seraphina", "acolyte")
			var fallback := path.ends_with("/acolyte.png")
			var glow_uv := Vector2(0.39, 0.55) if fallback else Vector2(0.24, 0.36)
			return _sprite_rig(npc_kind, path, 2.15, glow_uv, Color("9df7e8"), 0.95, 2.6, fallback)
		"malcor_live":
			return _sprite_rig(npc_kind, "res://art/bell_warden.png", 4.30, Vector2(0.56, 0.38), Color("cd91df"), 1.25, 3.5)
		_:
			return _pivot(null, npc_kind)


static func _sprite_path(preferred: String, fallback: String) -> String:
	var path := "res://art/%s.png" % preferred
	return path if ResourceLoader.exists(path, "Texture2D") else "res://art/%s.png" % fallback


static func _sprite_rig(kind: String, path: String, height: float, glow_uv: Vector2, glow_color: Color, energy: float, light_range: float, retint_glow: bool = false) -> Node3D:
	if not _sprite_assets.has(path):
		var albedo := load(path) as Texture2D
		var image := albedo.get_image()
		if image.is_compressed():
			image.decompress()
		_sprite_assets[path] = {
			"albedo": albedo,
			"normal": Visuals.make_normal_map(albedo, 1.35),
			"bounds": image.get_used_rect(),
		}
	var art := _sprite_assets[path]
	var material := ShaderMaterial.new()
	material.shader = SPRITE_SHADER
	material.set_shader_parameter("albedo_tex", art.albedo)
	material.set_shader_parameter("normal_tex", art.normal)
	material.set_shader_parameter("emissive_tint", glow_color)
	if retint_glow:
		material.set_shader_parameter("emissive_tint_weight", 0.85)

	var hip_y := height * 0.44
	var rig := _pivot(null, kind)
	var body := _pivot(rig, "body_pivot", Vector3.UP * hip_y)
	var quad := QuadMesh.new()
	# Keep the visible silhouette at the requested height with its feet at the rig origin.
	var image_size: Vector2 = art.albedo.get_size()
	var bounds: Rect2i = art.bounds
	var texel_scale := height / float(bounds.size.y)
	var bottom_padding := image_size.y - bounds.end.y
	quad.size = image_size * texel_scale
	quad.center_offset.y = quad.size.y * 0.5 - bottom_padding * texel_scale - hip_y
	var sprite := _mesh(body, Vector3.ZERO, quad, material)
	sprite.name = "sprite_mesh"
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	# The shader can turn the quad in any horizontal direction and roll it during recoil.
	var half_width := quad.size.x * 0.5
	var radius := Vector2(half_width, quad.size.y * 0.5 + absf(quad.center_offset.y)).length()
	sprite.custom_aabb = AABB(Vector3.ONE * -radius, Vector3.ONE * radius * 2.0)

	var shoulder := Vector3(quad.size.x * 0.25, height * 0.20, -0.05)
	var arm_r := _pivot(body, "arm_r", shoulder)
	var arm_l := _pivot(body, "arm_l", Vector3(-shoulder.x, shoulder.y, shoulder.z))
	var head := _pivot(body, "head_node", Vector3.UP * (height * 0.86 - hip_y))
	var glow := _pivot(body, "eye_glow", Vector3(
		(0.5 - glow_uv.x) * quad.size.x,
		quad.center_offset.y + (0.5 - glow_uv.y) * quad.size.y,
		-0.28
	))
	_light(glow, Vector3.ZERO, glow_color, energy, light_range)
	rig.set_meta("body_pivot", body)
	rig.set_meta("sprite_mesh", sprite)
	rig.set_meta("sprite_mat", material)
	rig.set_meta("arm_r", arm_r)
	rig.set_meta("arm_l", arm_l)
	rig.set_meta("head_node", head)
	rig.set_meta("eye_glow", glow)
	rig.set_meta("hip_y", hip_y)
	return rig


static func _shield(shield: Node3D, kit: Dictionary) -> void:
	var outline := PackedVector2Array([
		Vector2(-0.27, 0.55), Vector2(0, 0.64), Vector2(0.27, 0.55), Vector2(0.27, -0.39),
		Vector2(0.18, -0.57), Vector2(0, -0.63), Vector2(-0.18, -0.57), Vector2(-0.27, -0.39),
	])
	_prism(shield, Vector3.ZERO, outline, 0.088, kit.iron)
	for i in outline.size():
		outline[i] *= 0.89
	_prism(shield, Vector3(0, 0, -0.037), outline, 0.053, kit.rust)
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		_rod(shield, Vector3(a.x, a.y, -0.062), Vector3(b.x, b.y, -0.062), 0.014, kit.brass, 6)
	for x: float in [-0.185, 0.185]:
		for y: float in [-0.37, -0.02, 0.38]:
			_sphere(shield, Vector3(x, y, -0.068), Vector3.ONE * 0.029, kit.brass, 6)
	var boss := _ring(shield, Vector3(0, 0.05, -0.071), 0.121, 0.023, kit.iron)
	boss.rotation.x = PI * 0.5
	_sphere(shield, Vector3(0, 0.05, -0.085), Vector3(0.098, 0.098, 0.060), kit.iron, 10)
	_rod(shield, Vector3(0, -0.09, -0.078), Vector3(0, -0.51, -0.070), 0.027, kit.iron, 4, 0.009)
	for x: float in [-0.11, 0.11]:
		_rod(shield, Vector3(x, -0.16, 0.035), Vector3(x, 0.17, 0.055), 0.023, kit.leather, 6)


# t is elapsed seconds, speed is horizontal world speed, and windup is progress through the charge.
static func animate_enemy_rig(rig: Node3D, t: float, speed: float, windup: float, is_frozen: bool, is_staggered: bool) -> void:
	var body := rig.get_meta("body_pivot", null) as Node3D
	var material := rig.get_meta("sprite_mat", null) as ShaderMaterial
	if body == null or material == null:
		return

	# Match the shader's yaw for the physical attachments while leaving AI facing on the parent.
	if rig.is_inside_tree():
		var camera := rig.get_viewport().get_camera_3d()
		if camera != null:
			var to_camera := rig.to_local(camera.global_position) - body.position
			if Vector2(to_camera.x, to_camera.z).length_squared() >= 0.0001:
				body.rotation.y = atan2(-to_camera.x, -to_camera.z)

	var last_time: float = rig.get_meta("pose_time", t - 1.0 / 60.0)
	var delta := clampf(t - last_time, 0.0, 0.1)
	rig.set_meta("pose_time", t)
	if is_frozen != bool(rig.get_meta("solid_frozen", false)):
		rig.set_meta("solid_frozen", is_frozen)
		var frost: float = rig.get_meta("status_frost", 0.0)
		material.set_shader_parameter("frost_amount", 1.0 if is_frozen else frost)
	if is_frozen:
		material.set_shader_parameter("windup_glow", 0.0)
		return

	var hip_y: float = rig.get_meta("hip_y")
	var hovering: bool = rig.get_meta("hovering", false)
	var stride := clampf(speed / 3.4, 0.0, 1.0)
	var phase: float = rig.get_meta("walk_phase", 0.0)
	phase = fposmod(phase + delta * maxf(speed, 0.0) * 2.3, TAU)
	rig.set_meta("walk_phase", phase)

	var progress := 0.0 if is_staggered else clampf(windup, 0.0, 1.0)
	var strike := smoothstep(0.89, 1.0, progress)
	var charge := smoothstep(0.0, 0.89, progress) * (1.0 - strike)
	var stagger := 1.0 if is_staggered else 0.0
	var step := sin(phase)
	var lift := 1.0 - absf(cos(phase))
	var bob := lift * lift * stride * hip_y * 0.15
	var sway := step * stride * hip_y * 0.065
	if hovering:
		bob = 0.16 + sin(t * 2.8) * 0.09
		sway *= 0.40

	var pose_scale := Vector3(1.0 + 0.10 * charge - 0.05 * strike, 1.0 - 0.22 * charge + 0.07 * strike, 1.0)
	var sway_axis := Vector3(cos(body.rotation.y), 0.0, -sin(body.rotation.y))
	var pose := sway_axis * sway
	pose.y = hip_y * (pose_scale.y + 0.06 * stagger) + bob
	pose.z += hip_y * (0.32 * charge - 0.44 * strike + 0.22 * stagger)
	var roll := step * stride * 0.045 - 0.09 * charge + 0.11 * strike + 0.23 * stagger
	var blend := 1.0 - exp(-delta * lerpf(14.0, 100.0, strike))
	body.scale = body.scale.lerp(pose_scale, blend)
	body.position = body.position.lerp(pose, blend)
	body.rotation.z = lerpf(body.rotation.z, roll, blend)
	if rig.has_meta("shield_node"):
		var arm_l: Node3D = rig.get_meta("arm_l")
		var shield_pose := Vector3(0.32 * charge - 0.25 * strike, 0.13 * charge, -0.10 * stagger)
		arm_l.rotation = arm_l.rotation.lerp(shield_pose, blend)
	material.set_shader_parameter("windup_glow", smoothstep(0.0, 0.9, progress))


# Status strengths are normalized. Solid freeze overrides the supplied frost strength until thaw.
static func set_rig_status(rig: Node3D, hit_flash: float, frost_amount: float, burn_amount: float) -> void:
	var material := rig.get_meta("sprite_mat", null) as ShaderMaterial
	if material == null:
		return
	var frost := clampf(frost_amount, 0.0, 1.0)
	rig.set_meta("status_frost", frost)
	material.set_shader_parameter("hit_flash", clampf(hit_flash, 0.0, 1.0))
	material.set_shader_parameter("frost_amount", 1.0 if rig.get_meta("solid_frozen", false) else frost)
	material.set_shader_parameter("burn_amount", clampf(burn_amount, 0.0, 1.0))


static func _cage(parent: Node3D, radius: float, height: float, metal: Material, frame: Material, core: Material) -> void:
	_frustum(parent, Vector3(0, -height * 0.37, 0), radius, radius * 0.68, height * 0.29, metal, 8)
	_frustum(parent, Vector3(0, height * 0.36, 0), radius * 0.54, radius * 0.94, height * 0.28, metal, 8)
	_ring(parent, Vector3(0, -height * 0.21, 0), radius * 0.96, radius * 0.073, metal, 8)
	_ring(parent, Vector3(0, height * 0.23, 0), radius * 0.91, radius * 0.068, metal, 8)
	_sphere(parent, Vector3.ZERO, Vector3(radius * 0.73, height * 0.37, radius * 0.73), core, 7)
	for i in 8:
		var angle := TAU * i / 8.0
		var radial := Vector3(cos(angle), 0, sin(angle))
		var top := radial * radius * 0.83 + Vector3.UP * height * 0.25
		var bottom := radial * radius * 0.93 + Vector3.DOWN * height * 0.25
		_rod(parent, bottom, top, radius * 0.084, frame, 5, radius * 0.066)
		var scroll := _ring(parent, radial * radius * 0.94, radius * 0.18, radius * 0.044, metal, 6)
		scroll.rotation.x = PI * 0.5
		scroll.rotation.y = PI * 0.5 - angle


static func _chain(parent: Node3D, start: Vector3, finish: Vector3, links: int, radius: float, material: Material) -> void:
	var direction := (finish - start).normalized()
	var alignment := Quaternion(Vector3.UP, direction)
	for i in links:
		var link := _ring(parent, start.lerp(finish, (float(i) + 0.5) / float(links)), radius, radius * 0.25, material, 8, 5)
		var turn := float(i % 2) * PI * 0.5
		link.quaternion = alignment * Quaternion(Vector3.UP, turn) * Quaternion(Vector3.RIGHT, PI * 0.5)
		link.scale.z = 1.24


static func _materials(overrides: Dictionary) -> Dictionary:
	var kit := {
		"timber": _material(Color("4c3022"), 0.87),
		"iron": _material(Color("535e69"), 0.46, 0.74),
		"silver": _material(Color("b8c9cd"), 0.29, 0.57),
		"brass": _material(Color("b8894e"), 0.42, 0.65),
		"copper": _material(Color("b76a45"), 0.44, 0.61),
		"leather": _material(Color("30231f"), 0.92),
		"leather_trim": _material(Color("654737"), 0.85),
		"ceramic": _material(Color("40323e"), 0.43, 0.1),
		"cord": _material(Color("baa890"), 0.94),
		"ember": _material(Color("ff6726"), 0.50, 0.0, 2.8),
		"mana": _material(Color("4dddf6"), 0.35, 0.0, 2.5),
		"acid": _material(Color("83f756"), 0.39, 0.15, 2.1),
		"pale": _material(Color("bbac93"), 0.82),
		"hot_eyes": _material(Color("ff5e28"), 0.54, 0.0, 3.2),
		"hot_magma": _material(Color("ffbc5b"), 0.50, 0.0, 3.8),
		"portal": _material(Color("ad91f6"), 0.4, 0.0, 2.4),
		"void": _material(Color("171319"), 0.98),
		"rags": _material(Color("504039"), 0.97),
		"robe": _material(Color("4c2e41"), 0.95),
		"archivist": _material(Color("36545d"), 0.88),
		"rust": _material(Color("805042"), 0.70, 0.38),
		"ash": _material(Color("a9a39b"), 0.75, 0.21),
		"basalt": _material(Color("454048"), 0.94),
		"royal": _material(Color("513046"), 0.93),
		"foundry": _material(Color("584449"), 0.66, 0.51),
	}
	for key: String in kit:
		var supplied := overrides.get(key) as Material
		if supplied != null:
			kit[key] = supplied
	return kit


static func _material(color: Color, roughness: float, metallic: float = 0.0, emission: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	return material


static func _pivot(parent: Node3D, node_name: String, pos: Vector3 = Vector3.ZERO) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = node_name
	pivot.position = pos
	if parent != null:
		parent.add_child(pivot)
	return pivot


static func _mesh(parent: Node3D, pos: Vector3, mesh: Mesh, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = "mesh"
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	parent.add_child(instance)
	return instance


static func _box(parent: Node3D, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent, pos, mesh, material)


static func _sphere(parent: Node3D, pos: Vector3, radii: Vector3, material: Material, segments: int) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radial_segments = segments
	mesh.rings = maxi(4, segments / 2)
	var instance := _mesh(parent, pos, mesh, material)
	instance.scale = radii * 2.0
	return instance


static func _frustum(parent: Node3D, pos: Vector3, top: float, bottom: float, height: float, material: Material, segments: int, cap_top: bool = true) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 0
	mesh.cap_top = cap_top
	return _mesh(parent, pos, mesh, material)


static func _rod(parent: Node3D, start: Vector3, finish: Vector3, radius: float, material: Material, segments: int, end_radius: float = -1.0) -> MeshInstance3D:
	var offset := finish - start
	var top := radius if end_radius < 0.0 else end_radius
	var segment := _frustum(parent, start + offset * 0.5, top, radius, offset.length(), material, segments, top > 0.0)
	segment.quaternion = Quaternion(Vector3.UP, offset.normalized())
	return segment


static func _ring(parent: Node3D, pos: Vector3, radius: float, thickness: float, material: Material, segments: int = 16, cross_segments: int = 6) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius + thickness
	mesh.rings = segments
	mesh.ring_segments = cross_segments
	return _mesh(parent, pos, mesh, material)


static func _prism(parent: Node3D, pos: Vector3, outline: PackedVector2Array, thickness: float, material: Material) -> MeshInstance3D:
	var polygon := outline.duplicate()
	if Geometry2D.is_polygon_clockwise(polygon):
		polygon.reverse()
	var faces := Geometry2D.triangulate_polygon(polygon)
	var half := thickness * 0.5
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0, faces.size(), 3):
		var a := polygon[faces[i]]
		var b := polygon[faces[i + 1]]
		var c := polygon[faces[i + 2]]
		_triangle(surface, Vector3(a.x, a.y, -half), Vector3(b.x, b.y, -half), Vector3(c.x, c.y, -half), a, b, c)
		_triangle(surface, Vector3(c.x, c.y, half), Vector3(b.x, b.y, half), Vector3(a.x, a.y, half), c, b, a)
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		var af := Vector3(a.x, a.y, -half)
		var ab := Vector3(a.x, a.y, half)
		var bf := Vector3(b.x, b.y, -half)
		var bb := Vector3(b.x, b.y, half)
		var side_uv := Vector2(a.distance_to(b), thickness)
		_triangle(surface, af, ab, bf, Vector2.ZERO, Vector2(0, side_uv.y), Vector2(side_uv.x, 0))
		_triangle(surface, bf, ab, bb, Vector2(side_uv.x, 0), Vector2(0, side_uv.y), side_uv)
	surface.generate_tangents()
	return _mesh(parent, pos, surface.commit(), material)


static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, uv_a: Vector2, uv_b: Vector2, uv_c: Vector2) -> void:
	surface.set_normal((c - a).cross(b - a).normalized())
	surface.set_uv(uv_a)
	surface.add_vertex(a)
	surface.set_uv(uv_b)
	surface.add_vertex(b)
	surface.set_uv(uv_c)
	surface.add_vertex(c)


static func _light(parent: Node3D, pos: Vector3, color: Color, energy: float, radius: float) -> void:
	var light := OmniLight3D.new()
	light.name = "glow_light"
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	parent.add_child(light)
