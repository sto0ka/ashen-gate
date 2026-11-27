class_name Meshes3D
extends RefCounted

const LIGHTNING_SHADER := preload("res://shaders/lightning.gdshader")
const SPRITE_SHADER := preload("res://shaders/sprite_lit.gdshader")

const SPRITE_PADDING := Vector2(0.09, 0.09)
const DIAGONAL_STEP := 1.41421356
# Torin's lantern energy across Hollowing stages 0..4 (Act I script §2.3).
const HOLLOWING_LANTERN: Array[float] = [1.8, 1.4, 1.0, 0.55, 0.25]
const HOLLOWING_TINT := Color("c9a6ff")
const NPC_GESTURES: Array[String] = [
	"lantern_raise", "lantern_wave", "toll_handbell", "clutch_head", "kneel", "beckon", "winch",
	"crank", "crawl", "rise", "stand", "sit", "unlock", "release_crank",
]

static var _soft_radial: ImageTexture
static var _aegis_shader: Shader
static var _bars_shader: Shader
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
	var rig := _enemy_rig(kind, mats)
	_tag_actor_layers(rig)
	return rig


static func _enemy_rig(kind: String, mats: Dictionary) -> Node3D:
	match kind:
		"executioner":
			var rig := _sprite_rig(kind, "res://art/sentinel.png", 2.55, Vector2(0.50, 0.13), Color("ff9c48"), 0.25, 1.35)
			var arm: Node3D = rig.get_meta("arm_l")
			var shield := _pivot(arm, "shield_node", Vector3(0.04, -0.43, -0.46))
			shield.rotation.y = 0.17
			_shield(shield, _materials(mats))
			rig.set_meta("shield_node", shield)
			return rig
		"acolyte":
			var rig := _sprite_rig(kind, "res://art/acolyte.png", 2.35, Vector2(0.82, 0.15), Color("be66ff"), 0.82, 2.5)
			rig.set_meta("hovering", true)
			var body: Node3D = rig.get_meta("body_pivot")
			body.position.y += 0.16
			_build_levitation(rig, body)
			return rig
		"stalker":
			var path := _sprite_path("stalker", "wretch")
			var fallback := path.ends_with("/wretch.png")
			var glow_uv := Vector2(0.55, 0.13) if fallback else Vector2(0.50, 0.29)
			var rig := _sprite_rig(kind, path, 2.25, glow_uv, Color("ff9cba"), 0.44, 1.65, fallback)
			var sonar := _ring(rig, Vector3.UP * 0.029, 0.76, 0.019, _effect_material(Color("b281b7"), 0.0), 48)
			sonar.name = "sonar_ring"
			sonar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			sonar.hide()
			rig.set_meta("sonar_ring", sonar)
			return rig
		"ash_sentinel":
			var path := _sprite_path("ash_sentinel", "sentinel")
			var rig := _sprite_rig(kind, path, 2.95, Vector2(0.50, 0.36), Color("ff993d"), 1.10, 2.75)
			var body: Node3D = rig.get_meta("body_pivot")
			var hoops := _pivot(body, "hoops_node", Vector3(0, 0.02, 0))
			var ember := _material(Color("d24a19"), 0.4, 0.36, 1.3)
			var hoop := _accent_ring(hoops, 0.70, 0.024, _materials(mats).iron)
			hoop.scale.z = 0.76
			hoop.rotation.z = 0.24
			var fire := _accent_ring(hoops, 0.83, 0.018, ember)
			fire.rotation = Vector3(0.58, 0.0, -0.36)
			_light(hoops, Vector3(0.0, 0.18, -0.28), Color("ff5d20"), 0.32, 1.65)
			rig.set_meta("hoops_node", hoops)
			return rig
		"warden":
			var rig := _sprite_rig(kind, "res://art/bell_warden.png", 4.75, Vector2(0.56, 0.38), Color("9548f2"), 1.55, 3.9)
			_build_warden_aegis(rig)
			return rig
		"colossus":
			var path := _sprite_path("colossus", "bell_warden")
			var fallback := path.ends_with("/bell_warden.png")
			var glow_uv := Vector2(0.56, 0.38) if fallback else Vector2(0.50, 0.37)
			var rig := _sprite_rig(kind, path, 4.95, glow_uv, Color("ff6b26"), 2.25, 4.5, fallback)
			_build_chest_core(rig)
			return rig
		_:
			return _sprite_rig("shrieker", "res://art/wretch.png", 2.15, Vector2(0.55, 0.13), Color("ffb447"), 0.32, 1.4)


static func build_npc_rig(npc_kind: String, _mats: Dictionary) -> Node3D:
	var rig := _npc_rig(npc_kind)
	rig.set_meta("npc_kind", npc_kind)
	_tag_actor_layers(rig)
	return rig


static func _npc_rig(npc_kind: String) -> Node3D:
	match npc_kind:
		"seraphina":
			var path := _sprite_path("seraphina", "acolyte")
			var fallback := path.ends_with("/acolyte.png")
			var glow_uv := Vector2(0.39, 0.55) if fallback else Vector2(0.24, 0.36)
			var rig := _sprite_rig(npc_kind, path, 2.15, glow_uv, Color("9df7e8"), 0.95, 2.6, fallback)
			_tag_lantern(rig, "lantern_light", false)
			return rig
		"torin", "wounded_guard":
			# Brother Torin: kneeling, wounded Bell-Watch guard with halberd and amber lantern.
			var rig := _sprite_rig(npc_kind, _sprite_path("wounded_guard", "sentinel"), 1.68, Vector2(0.26, 0.56), Color("ffab48"), 1.8, 5.2)
			_tag_lantern(rig, "lantern_light", true)
			rig.set_meta("gait", "limp")
			rig.set_meta("hollowing_stage", 0)
			return rig
		"bellwatch_guard":
			# W. Ware in the cold open: the same Bell-Watch kit as a taller standing figure.
			var rig := _sprite_rig(npc_kind, _sprite_path("wounded_guard", "sentinel"), 1.98, Vector2(0.26, 0.56), Color("ffab48"), 1.6, 5.0)
			_tag_lantern(rig, "lantern_light", true)
			rig.set_meta("gait", "walk")
			rig.set_meta("hollowing_stage", 0)
			return rig
		"malcor_live", "malcor_choir", "malcor_dying":
			# Unmasked Choir Vigil form: human and haunted, distinct from the Belfry Bell-Rack armour.
			var path := _sprite_path("malcor_choir", "bell_warden")
			var rig: Node3D
			if path.ends_with("/bell_warden.png"):
				rig = _sprite_rig(npc_kind, path, 4.30, Vector2(0.56, 0.38), Color("cd91df"), 1.25, 3.5)
			else:
				rig = _sprite_rig(npc_kind, path, 2.45, Vector2(0.61, 0.62), Color("c984ff"), 1.4, 4.2)
			_tag_lantern(rig, "handbell_light", false)
			rig.set_meta("gait", "walk")
			return rig
		_:
			return _pivot(null, npc_kind)


static func _tag_lantern(rig: Node3D, meta_name: String, flicker: bool) -> void:
	var glow: Node3D = rig.get_meta("eye_glow")
	var light := glow.get_node("glow_light") as OmniLight3D
	rig.set_meta(meta_name, light)
	if meta_name != "lantern_light":
		rig.set_meta("lantern_light", light)
	rig.set_meta("lantern_energy", light.light_energy)
	rig.set_meta("lantern_base_energy", light.light_energy)
	rig.set_meta("lantern_base_range", light.omni_range)
	rig.set_meta("lantern_flicker", flicker)


# Render layer 2 marks actors so world decals never project onto sprite cards.
static func _tag_actor_layers(rig: Node3D) -> void:
	var layer := Visuals.ACTOR_RENDER_LAYER
	for node in rig.find_children("*", "VisualInstance3D", true, false):
		if not (node is Light3D):
			(node as VisualInstance3D).layers = layer


static func _sprite_path(preferred: String, fallback: String) -> String:
	var path := "res://art/%s.png" % preferred
	return path if ResourceLoader.exists(path, "Texture2D") else "res://art/%s.png" % fallback


static func _sprite_rig(kind: String, path: String, height: float, glow_uv: Vector2, glow_color: Color, energy: float, light_range: float, retint_glow: bool = false) -> Node3D:
	if not _sprite_assets.has(path):
		var albedo := load(path) as Texture2D
		var image := albedo.get_image()
		if image.is_compressed():
			image.decompress()
		var maps := _sculpt_sprite(image)
		maps["albedo"] = albedo
		_sprite_assets[path] = maps
	var art := _sprite_assets[path]
	var material := ShaderMaterial.new()
	material.shader = SPRITE_SHADER
	material.set_shader_parameter("albedo_tex", art.albedo)
	material.set_shader_parameter("normal_tex", art.normal)
	material.set_shader_parameter("volume_tex", art.volume)
	material.set_shader_parameter("emissive_tint", glow_color)
	material.set_shader_parameter("alpha_scissor", 0.5)
	material.set_shader_parameter("weapon_uv", _weapon_glint_uv(kind))
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
	var art_size := image_size * texel_scale
	var bottom_padding := image_size.y - bounds.end.y
	quad.size = art_size * (Vector2.ONE + 2.0 * SPRITE_PADDING)
	quad.center_offset.y = art_size.y * 0.5 - bottom_padding * texel_scale - hip_y - 0.02
	var uv_min := Vector2(bounds.position) / image_size
	var uv_max := Vector2(bounds.end) / image_size
	material.set_shader_parameter("bounds_u_min", uv_min.x)
	material.set_shader_parameter("bounds_u_max", uv_max.x)
	material.set_shader_parameter("bounds_v_min", uv_min.y)
	material.set_shader_parameter("bounds_v_max", uv_max.y)
	material.set_shader_parameter("uv_padding", SPRITE_PADDING)
	var sprite := _mesh(body, Vector3.ZERO, quad, material)
	sprite.name = "sprite_mesh"
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	# The shader can turn the quad in any horizontal direction and roll it during recoil.
	var half_width := quad.size.x * 0.5
	var radius := Vector2(half_width, quad.size.y * 0.5 + absf(quad.center_offset.y)).length()
	sprite.custom_aabb = AABB(Vector3.ONE * -radius, Vector3.ONE * radius * 2.0)

	var shoulder := Vector3(art_size.x * 0.25, height * 0.20, -0.05)
	var arm_r := _pivot(body, "arm_r", shoulder)
	var arm_l := _pivot(body, "arm_l", Vector3(-shoulder.x, shoulder.y, shoulder.z))
	var head := _pivot(body, "head_node", Vector3.UP * (height * 0.86 - hip_y))
	var glow := _pivot(body, "eye_glow", Vector3(
		(0.5 - glow_uv.x) * art_size.x,
		quad.center_offset.y + (0.5 - glow_uv.y) * art_size.y,
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
	rig.set_meta("sprite_height", height)
	rig.set_meta("glow_rest_x", glow.position.x)
	rig.set_meta("glow_rest_y", glow.position.y)
	rig.set_meta("glow_color", glow_color)
	rig.set_meta("tint_weight_rest", 0.85 if retint_glow else 0.18)
	rig.set_meta("step_triggered", false)
	var shadow := _floor_glow(rig, "contact_shadow", 0.018, art_size.x * 0.42, Color(0.027, 0.017, 0.032, 0.78))
	rig.set_meta("contact_shadow", shadow)
	return rig


static func _weapon_glint_uv(kind: String) -> Vector2:
	match kind:
		"executioner":
			return Vector2(0.23, 0.55)
		"acolyte":
			return Vector2(0.82, 0.23)
		"warden":
			return Vector2(0.23, 0.43)
		"colossus":
			return Vector2(0.73, 0.53)
		"torin", "wounded_guard", "bellwatch_guard":
			return Vector2(0.26, 0.56)
		"malcor_live", "malcor_choir", "malcor_dying":
			return Vector2(0.61, 0.62)
		_:
			return Vector2(0.24, 0.51)


static func _sculpt_sprite(image: Image) -> Dictionary:
	var width := image.get_width()
	var height := image.get_height()
	var distance := PackedFloat32Array()
	var luma := PackedFloat32Array()
	var row_width := PackedFloat32Array()
	distance.resize(width * height)
	luma.resize(distance.size())
	row_width.resize(height)
	var bounds := Rect2i()
	var has_pixels := false
	for y in height:
		var first_x := width
		var last_x := -1
		for x in width:
			var color := image.get_pixel(x, y)
			if color.a <= 0.5:
				continue
			var i := y * width + x
			distance[i] = float(mini(mini(x + 1, width - x), mini(y + 1, height - y)))
			luma[i] = color.get_luminance()
			first_x = mini(first_x, x)
			last_x = x
		if last_x >= first_x:
			row_width[y] = float(last_x - first_x + 1)
			var row := Rect2i(first_x, y, int(row_width[y]), 1)
			bounds = bounds.merge(row) if has_pixels else row
			has_pixels = true
	if not has_pixels:
		bounds = Rect2i(0, 0, width, height)

	# A forward and backward chamfer sweep approaches the nearest transparent texel.
	_distance_sweep(distance, width, height, 1)
	_distance_sweep(distance, width, height, -1)
	var relief := PackedFloat32Array()
	relief.resize(distance.size())
	for y in range(bounds.position.y, bounds.end.y):
		var span_above := row_width[maxi(bounds.position.y, y - 5)]
		var span_below := row_width[mini(bounds.end.y - 1, y + 5)]
		var local_half_span := (span_above + 2.0 * row_width[y] + span_below) * 0.125
		local_half_span = clampf(local_half_span, bounds.size.y * 0.039, bounds.size.y * 0.115)
		for x in range(bounds.position.x, bounds.end.x):
			var i := y * width + x
			var fill := clampf((distance[i] - 1.0) / local_half_span, 0.0, 1.0)
			relief[i] = fill * (2.0 - fill)

	# Smooth the chamfer ridges before differencing, while keeping the cutout at zero thickness.
	for pass_index in 2:
		var softened := relief.duplicate()
		for y in range(1, height - 1):
			for x in range(1, width - 1):
				var i := y * width + x
				if distance[i] > 1.0:
					softened[i] = (4.0 * relief[i] + relief[i - 1] + relief[i + 1] + relief[i - width] + relief[i + width]) * 0.125
		relief = softened

	var normal := Image.create(width, height, false, Image.FORMAT_RGB8)
	normal.fill(Color(0.5, 0.5, 1.0))
	var volume := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var depth_in_texels := bounds.size.y * 0.043
	for y in range(bounds.position.y, bounds.end.y):
		var zone := (float(y - bounds.position.y) + 0.5) / float(bounds.size.y)
		var top := maxi(y - 1, 0) * width
		var bottom := mini(y + 1, height - 1) * width
		var row := y * width
		for x in range(bounds.position.x, bounds.end.x):
			var i := row + x
			if distance[i] == 0.0:
				continue
			var left := maxi(x - 1, 0)
			var right := mini(x + 1, width - 1)
			var gradient := Vector2(relief[row + left] - relief[row + right], relief[bottom + x] - relief[top + x]) * (depth_in_texels * 0.5)
			if distance[i] >= 2.0:
				var sobel_x := luma[top + left] + 2.0 * luma[row + left] + luma[bottom + left] - luma[top + right] - 2.0 * luma[row + right] - luma[bottom + right]
				var sobel_y := luma[bottom + left] + 2.0 * luma[bottom + x] + luma[bottom + right] - luma[top + left] - 2.0 * luma[top + x] - luma[top + right]
				gradient += Vector2(sobel_x, sobel_y) * (0.40 * smoothstep(1.5, 4.0, distance[i]))
			var n := Vector3(gradient.x, gradient.y, 1.0).normalized() * 0.5 + Vector3.ONE * 0.5
			normal.set_pixel(x, y, Color(n.x, n.y, n.z))

			var color := image.get_pixel(x, y)
			var muted := 1.0 - smoothstep(0.18, 0.65, color.s)
			var cool := smoothstep(-0.20, 0.16, color.b - color.r)
			var metal := smoothstep(0.22, 0.64, luma[i]) * muted * lerpf(0.5, 1.0, cool)
			var cloth := (1.0 - metal) * (1.0 - 0.65 * smoothstep(0.12, 0.59, luma[i]))
			volume.set_pixel(x, y, Color(relief[i], metal, cloth * 0.65, zone))
	return {
		"bounds": bounds,
		"normal": ImageTexture.create_from_image(normal),
		"volume": ImageTexture.create_from_image(volume),
	}


static func _distance_sweep(distance: PackedFloat32Array, width: int, height: int, step: int) -> void:
	var start_x := 0 if step > 0 else width - 1
	var start_y := 0 if step > 0 else height - 1
	for offset_y in height:
		var y := start_y + offset_y * step
		var row := y * width
		var adjacent := (y - step) * width
		for offset_x in width:
			var x := start_x + offset_x * step
			var i := row + x
			var d := distance[i]
			if d == 0.0:
				continue
			var prev_x := x - step
			var next_x := x + step
			if prev_x >= 0 and prev_x < width:
				d = minf(d, distance[row + prev_x] + 1.0)
			if adjacent >= 0 and adjacent < distance.size():
				d = minf(d, distance[adjacent + x] + 1.0)
				if prev_x >= 0 and prev_x < width:
					d = minf(d, distance[adjacent + prev_x] + DIAGONAL_STEP)
				if next_x >= 0 and next_x < width:
					d = minf(d, distance[adjacent + next_x] + DIAGONAL_STEP)
			distance[i] = d


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


static func _effect_material(color: Color, glow: float) -> StandardMaterial3D:
	var material := _material(color, 0.6, 0.0, glow)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return material


static func _floor_glow(rig: Node3D, node_name: String, y: float, radius: float, color: Color) -> MeshInstance3D:
	if _soft_radial == null:
		const SIZE := 64
		var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
		for iy in SIZE:
			for ix in SIZE:
				var point := (Vector2(ix, iy) + Vector2.ONE * 0.5) * (2.0 / SIZE) - Vector2.ONE
				var falloff := 1.0 - smoothstep(0.12, 1.0, point.length())
				image.set_pixel(ix, iy, Color(1, 1, 1, falloff * falloff))
		_soft_radial = ImageTexture.create_from_image(image)
	var material := _effect_material(color, 0.0)
	material.albedo_texture = _soft_radial
	var quad := QuadMesh.new()
	quad.size = Vector2(radius * 2.0, radius * 1.48)
	var disc := _mesh(rig, Vector3.UP * y, quad, material)
	disc.name = node_name
	disc.rotation.x = -PI * 0.5
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return disc


static func _accent_ring(parent: Node3D, radius: float, thickness: float, material: Material) -> MeshInstance3D:
	var ring := _ring(parent, Vector3.ZERO, radius, thickness, material, 48)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return ring


static func _rune_ring(parent: Node3D, radius: float, metal: Material, rune: Material) -> MeshInstance3D:
	var ring := _accent_ring(parent, radius, radius * 0.015, metal)
	# Build the glyph strokes as one mesh so the rotating ring stays cheap.
	var glyphs := SurfaceTool.new()
	glyphs.begin(Mesh.PRIMITIVE_TRIANGLES)
	for mark in 12:
		var angle := TAU * float(mark) / 12.0
		var outward := Vector3(cos(angle), 0.0, sin(angle))
		var tangent := outward.cross(Vector3.UP)
		var center := outward * (radius * 0.90) + Vector3.UP * radius * 0.021
		var stem := outward * radius * 0.042
		var serif := tangent * radius * 0.033
		for stroke: Vector3 in [stem, serif + stem * 0.4]:
			var width := stroke.cross(Vector3.UP).normalized() * radius * 0.008
			var a := center - stroke - width
			var b := center - stroke + width
			var c := center + stroke + width
			var d := center + stroke - width
			_triangle(glyphs, a, b, c, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
			_triangle(glyphs, a, c, d, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
	var runes := _mesh(ring, Vector3.ZERO, glyphs.commit(), rune)
	runes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return ring


static func _build_levitation(rig: Node3D, body: Node3D) -> void:
	var ring_root := _pivot(rig, "levitation_ring", Vector3.UP * 0.04)
	var violet := Color("a959fb")
	var glyph := _effect_material(Color(0.72, 0.36, 1.0, 0.78), 1.0)
	glyph.cull_mode = BaseMaterial3D.CULL_DISABLED
	_rune_ring(ring_root, 0.72, _material(violet, 0.48, 0.28, 0.8), glyph)
	_floor_glow(rig, "levitation_glow", 0.032, 1.10, Color(0.32, 0.075, 0.66, 0.31))
	var orbit := _pivot(body, "arcane_orbit", Vector3.UP * 0.55)
	orbit.rotation.z = 0.15
	var crystal_mat := _material(Color("b368fa"), 0.28, 0.25, 1.5)
	for side: float in [-1.0, 1.0]:
		var crystal := _pivot(orbit, "arcane_crystal", Vector3(side * 0.63, side * 0.075, 0))
		crystal.rotation.z = side * 0.23
		_rod(crystal, Vector3.ZERO, Vector3.UP * 0.14, 0.077, crystal_mat, 5, 0.0)
		_rod(crystal, Vector3.ZERO, Vector3.DOWN * 0.098, 0.077, crystal_mat, 5, 0.0)
	rig.set_meta("levitation_ring", ring_root)
	rig.set_meta("arcane_orbit", orbit)


static func _build_warden_aegis(rig: Node3D) -> void:
	var body: Node3D = rig.get_meta("body_pivot")
	var aegis := _pivot(body, "aegis_node", Vector3.UP * 0.24)
	if _aegis_shader == null:
		_aegis_shader = Shader.new()
		_aegis_shader.code = """
shader_type spatial;
render_mode unshaded, depth_draw_never, shadows_disabled;
uniform float shield = 1.0;
uniform float warded = 0.0;
varying vec3 shell_pos;

void vertex() {
	shell_pos = normalize(VERTEX);
}

void fragment() {
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), VIEW)), 2.1);
	float arc = sin(dot(shell_pos, vec3(4.0, 9.0, 6.0)) + TIME * 2.2);
	float split = sin(shell_pos.x * 33.0 + 3.0 * sin(shell_pos.y * 14.0))
		* cos(shell_pos.z * 25.0 - shell_pos.y * 12.0);
	float fissure = (1.0 - smoothstep(0.0, 0.085, abs(split)))
		* smoothstep(0.16, 0.92, arc) * (1.0 - shield) * (1.0 - warded);
	float pulse = 0.82 + 0.18 * sin(TIME * (4.0 + (1.0 - shield) * 6.0));
	vec3 violet = mix(vec3(0.26, 0.055, 1.0), vec3(0.70, 0.29, 1.0), arc * 0.5 + 0.5);
	vec3 amber = vec3(1.0, 0.48, 0.095);
	ALBEDO = mix(violet, amber, clamp(fissure * 2.0 + (1.0 - warded) * rim * 0.24, 0.0, 1.0));
	EMISSION = ALBEDO * (fissure * 1.8 + rim * pulse * (0.75 + warded * 0.55));
	ALPHA = clamp(0.025 + (0.12 + warded * 0.14 + shield * 0.13) * rim * pulse + fissure * 0.30, 0.0, 0.62);
}
"""
	var shell := ShaderMaterial.new()
	shell.shader = _aegis_shader
	shell.render_priority = 1
	var dome := _sphere(aegis, Vector3.ZERO, Vector3(1.67, 2.58, 1.40), shell, 48)
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var brass := _material(Color("ab8055"), 0.42, 0.57, 0.32)
	var glyph := _effect_material(Color("dbac68"), 1.25)
	glyph.cull_mode = BaseMaterial3D.CULL_DISABLED
	var inner := _rune_ring(aegis, 1.58, brass, glyph)
	inner.rotation.z = 0.32
	var outer := _rune_ring(aegis, 1.71, _material(Color("8753c8"), 0.40, 0.35, 0.9), glyph)
	outer.rotation.z = -0.50
	aegis.hide()
	rig.set_meta("aegis_node", aegis)
	rig.set_meta("aegis_material", shell)
	rig.set_meta("aegis_inner_ring", inner)
	rig.set_meta("aegis_outer_ring", outer)


static func set_warden_aegis(rig: Node3D, shield_ratio: float, wards_left: int) -> void:
	var aegis := rig.get_node_or_null("body_pivot/aegis_node") as Node3D
	if aegis == null:
		return
	aegis.visible = wards_left > 0 or shield_ratio > 0.0
	var material: ShaderMaterial = rig.get_meta("aegis_material")
	var shield := clampf(shield_ratio, 0.0, 1.0)
	material.set_shader_parameter("shield", shield)
	material.set_shader_parameter("warded", 1.0 if wards_left > 0 else 0.0)
	aegis.scale = Vector3.ONE * (1.05 if wards_left > 0 else lerpf(0.95, 1.02, shield))


static func set_shield_damage(rig: Node3D, damage_ratio: float) -> void:
	var shield := rig.get_node_or_null("body_pivot/arm_l/shield_node") as Node3D
	if shield == null:
		return
	var damage := clampf(damage_ratio, 0.0, 1.0)
	var cracks := shield.get_node_or_null("impact_cracks") as Node3D
	if cracks == null:
		if damage == 0.0:
			return
		cracks = _pivot(shield, "impact_cracks", Vector3(0.13, 0.27, -0.074))
		var crack_mat := _material(Color("ff9e53"), 0.56, 0.12, 1.0)
		cracks.set_meta("material", crack_mat)
		var branches: Array[Vector2] = [
			Vector2(0, 0), Vector2(-0.046, 0.079),
			Vector2(-0.046, 0.079), Vector2(-0.031, 0.159),
			Vector2(0, 0), Vector2(0.056, -0.064),
			Vector2(0, 0), Vector2(-0.126, -0.067),
			Vector2(-0.126, -0.067), Vector2(-0.198, -0.171),
		]
		for i in range(0, branches.size(), 2):
			var a := branches[i]
			var b := branches[i + 1]
			_rod(cracks, Vector3(a.x, a.y, 0), Vector3(b.x, b.y, 0), 0.009, crack_mat, 5, 0.003)
	cracks.visible = damage > 0.0
	cracks.scale = Vector3.ONE * lerpf(0.35, 1.0, damage)
	var material: StandardMaterial3D = cracks.get_meta("material")
	material.emission_energy_multiplier = lerpf(0.25, 3.1, damage)


static func trigger_sonar_pulse(rig: Node3D) -> void:
	var ring := rig.get_node_or_null("sonar_ring") as MeshInstance3D
	if ring == null or not ring.is_inside_tree():
		return
	if ring.has_meta("pulse_tween"):
		var previous: Tween = ring.get_meta("pulse_tween")
		if previous.is_valid():
			previous.kill()
	var material := ring.material_override as StandardMaterial3D
	material.albedo_color.a = 0.58
	ring.scale = Vector3(0.55, 0.55, 0.55)
	ring.show()
	var tween := ring.create_tween().set_parallel()
	tween.tween_property(ring, "scale", Vector3(3.25, 0.25, 3.25), 0.54).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.54)
	tween.chain().tween_callback(ring.hide)
	ring.set_meta("pulse_tween", tween)


static func trigger_slash_arc(rig: Node3D, color: Color = Color("ff8c42")) -> void:
	if not rig.is_inside_tree():
		return
	var height := float(rig.get_meta("sprite_height", 2.15))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	const SEGMENTS := 28
	for i in range(SEGMENTS + 1):
		var along := float(i) / SEGMENTS
		var angle := lerpf(-0.95, 0.95, along)
		var outer := Vector3(sin(angle), 0.18 * cos(PI * along), -cos(angle))
		var width := pow(maxf(sin(PI * along), 0.0), 0.85) * 0.30
		surface.add_vertex(outer * height * 0.64)
		surface.add_vertex(outer * (1.0 - width) * height * 0.64)
	color.a = 0.83
	var trail := _effect_material(color, 1.6)
	trail.cull_mode = BaseMaterial3D.CULL_DISABLED
	var arc := _mesh(rig, Vector3.UP * height * 0.57, surface.commit(), trail)
	arc.name = "slash_arc"
	arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arc.rotation = Vector3(-0.18, -0.63, -0.34)
	var tween := arc.create_tween().set_parallel()
	tween.tween_property(arc, "rotation:y", 0.61, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(arc, "position:y", height * 0.43, 0.22)
	tween.tween_property(trail, "albedo_color:a", 0.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(arc.queue_free)


static func update_enemy_bars(rig: Node3D, hp_ratio: float, shield_ratio: float = 0.0, visible: bool = true) -> void:
	var bars := rig.get_node_or_null("enemy_bars") as MeshInstance3D
	var hp := clampf(hp_ratio, 0.0, 1.0)
	var shield := clampf(shield_ratio, 0.0, 1.0)
	var is_boss := rig.name in [&"warden", &"colossus"]
	if rig.get_parent() != null:
		is_boss = bool(rig.get_parent().get_meta("boss", is_boss))
	if is_boss or not visible or (hp >= 1.0 and shield == 0.0):
		if bars != null:
			bars.hide()
		return
	if bars == null:
		bars = _build_enemy_bars(rig)
	var material := bars.material_override as ShaderMaterial
	material.set_shader_parameter("hp", hp)
	material.set_shader_parameter("shield", shield)
	bars.show()


static func _build_enemy_bars(rig: Node3D) -> MeshInstance3D:
	if _bars_shader == null:
		_bars_shader = Shader.new()
		_bars_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform float hp = 1.0;
uniform float shield = 0.0;

void vertex() {
	mat4 camera = MAIN_CAM_INV_VIEW_MATRIX;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(camera[0], camera[1], camera[2], MODEL_MATRIX[3]);
}

void fragment() {
	bool shield_row = UV.y < 0.36;
	if ((!shield_row && UV.y < 0.53) || (shield_row && shield <= 0.0)) {
		discard;
	}
	float y = shield_row ? UV.y / 0.36 : (UV.y - 0.53) / 0.47;
	float value = shield_row ? shield : hp;
	vec3 fill = shield_row ? vec3(0.17, 0.65, 0.90) : vec3(0.73, 0.14, 0.085);
	bool border = UV.x < 0.016 || UV.x > 0.984 || y < 0.13 || y > 0.87;
	bool filled = !border && UV.x <= mix(0.016, 0.984, value);
	ALBEDO = filled ? fill * mix(1.15, 0.74, y) : vec3(0.033, 0.018, 0.024);
	ALPHA = filled ? 0.97 : 0.78;
}
"""
	var material := ShaderMaterial.new()
	material.shader = _bars_shader
	var height := float(rig.get_meta("sprite_height", 2.15))
	var quad := QuadMesh.new()
	quad.size = Vector2(height * 0.32, height * 0.061)
	var bars := _mesh(rig, Vector3.UP * (height + 0.24), quad, material)
	bars.name = "enemy_bars"
	bars.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var extent := Vector3.ONE * quad.size.x * 0.5
	bars.custom_aabb = AABB(-extent, extent * 2.0)
	rig.set_meta("enemy_bars", bars)
	return bars


static func _face_rig_camera(rig: Node3D, body: Node3D) -> void:
	if not rig.is_inside_tree():
		return
	var camera := rig.get_viewport().get_camera_3d()
	if camera == null:
		return
	# Align attachments with the shader's billboard while leaving the parent's AI facing intact.
	var to_camera := rig.to_local(camera.global_position) - body.position
	if Vector2(to_camera.x, to_camera.z).length_squared() >= 0.0001:
		body.rotation.y = atan2(-to_camera.x, -to_camera.z)


# t is elapsed seconds, speed is horizontal world speed, and windup is progress through the charge.
static func animate_enemy_rig(rig: Node3D, t: float, speed: float, windup: float, is_frozen: bool, is_staggered: bool, move_dir_world: Vector3 = Vector3.ZERO, parry_glint: float = 0.0) -> void:
	if not rig.has_meta("sprite_mat"):
		return
	var body: Node3D = rig.get_meta("body_pivot")
	var material: ShaderMaterial = rig.get_meta("sprite_mat")

	_face_rig_camera(rig, body)
	var last_time: float = rig.get_meta("pose_time", t - 1.0 / 60.0)
	var delta := clampf(t - last_time, 0.0, 0.1)
	rig.set_meta("pose_time", t)
	rig.set_meta("step_triggered", false)
	material.set_shader_parameter("relief_yaw", sin(body.rotation.y) * 0.47)
	if is_frozen != bool(rig.get_meta("solid_frozen", false)):
		rig.set_meta("solid_frozen", is_frozen)
		var frost: float = rig.get_meta("status_frost", 0.0)
		material.set_shader_parameter("frost_amount", 1.0 if is_frozen else frost)
	if is_frozen:
		material.set_shader_parameter("windup_glow", 0.0)
		material.set_shader_parameter("parry_flash", 0.0)
		return

	var hip_y: float = rig.get_meta("hip_y")
	var hovering: bool = rig.get_meta("hovering", false)
	var stride := clampf(speed / 3.4, 0.0, 1.0)
	var previous_phase: float = rig.get_meta("walk_phase", 0.0)
	var next_phase := previous_phase + delta * maxf(speed, 0.0) * 2.3
	var phase := fposmod(next_phase, TAU)
	rig.set_meta("walk_phase", phase)
	if not hovering and stride > 0.10 and floori(next_phase / PI) > floori(previous_phase / PI):
		rig.set_meta("step_triggered", true)

	var progress := 0.0 if is_staggered else clampf(windup, 0.0, 1.0)
	var strike := smoothstep(0.78, 1.0, progress)
	var charge := smoothstep(0.0, 0.78, progress) * (1.0 - strike)
	var hit: float = rig.get_meta("status_hit_flash", 0.0)
	var recoil := maxf(0.72 if is_staggered else 0.0, hit)
	var step_wave := sin(phase)
	var bob := lerpf(-0.03, 0.05, step_wave * step_wave) * stride * hip_y
	var sway := -step_wave * stride * hip_y * 0.045
	if hovering:
		bob = 0.22 + sin(t * 2.8) * 0.10
		sway *= 0.40

	var pose_scale := Vector3(1.0 + 0.07 * charge - 0.035 * strike, 1.0 - 0.14 * charge + 0.055 * strike, 1.0)
	var sway_axis := Vector3(cos(body.rotation.y), 0.0, -sin(body.rotation.y))
	var pose := sway_axis * sway
	pose.y = hip_y * pose_scale.y + bob
	pose.z += hip_y * (0.31 * charge - 0.43 * strike + 0.19 * recoil)
	var roll := -step_wave * stride * 0.021 - 0.065 * charge + 0.082 * strike + 0.095 * recoil
	var blend := 1.0 - exp(-delta * lerpf(17.0, 92.0, maxf(strike, recoil)))
	body.scale = body.scale.lerp(pose_scale, blend)
	body.position = body.position.lerp(pose, blend)
	body.rotation.z = lerpf(body.rotation.z, roll, blend)
	if rig.has_meta("shield_node"):
		var arm_l: Node3D = rig.get_meta("arm_l")
		var shield_pose := Vector3(0.24 * charge - 0.18 * strike, 0.09 * charge, -0.09 * recoil)
		arm_l.rotation = arm_l.rotation.lerp(shield_pose, blend)

	var movement := move_dir_world
	if movement == Vector3.ZERO and rig.get_parent() is CharacterBody3D:
		movement = (rig.get_parent() as CharacterBody3D).velocity
	var facing: float = rig.get_meta("facing_flip", 1.0)
	if stride > 0.10 and movement.length_squared() > 0.0001:
		var world_right := rig.global_basis * -sway_axis if rig.is_inside_tree() else -sway_axis
		var lateral := Vector3(movement.x, 0.0, movement.z).normalized().dot(world_right.normalized())
		if absf(lateral) > 0.30:
			# Most weapon art is on the painted left. Mirror for sustained rightward travel.
			facing = -signf(lateral)
	rig.set_meta("facing_flip", facing)
	var glow: Node3D = rig.get_meta("eye_glow")
	glow.position.x = float(rig.get_meta("glow_rest_x")) * facing

	var height: float = rig.get_meta("sprite_height")
	var actual_lift := body.position.y - hip_y * body.scale.y
	material.set_shader_parameter("walk_phase", phase)
	material.set_shader_parameter("walk_speed", stride * (0.18 if hovering else 1.0))
	material.set_shader_parameter("ground_lift", 0.0 if hovering else actual_lift / (height * body.scale.y))
	material.set_shader_parameter("idle_time", t)
	material.set_shader_parameter("facing_flip", facing)
	material.set_shader_parameter("attack_phase", progress)
	material.set_shader_parameter("hit_recoil", recoil)
	material.set_shader_parameter("parry_flash", clampf(parry_glint, 0.0, 1.0))
	material.set_shader_parameter("windup_glow", smoothstep(0.0, 0.9, progress))
	_animate_rig_accents(rig, t, actual_lift)


static func _animate_rig_accents(rig: Node3D, t: float, lift: float) -> void:
	var shadow: MeshInstance3D = rig.get_meta("contact_shadow")
	var shadow_mat := shadow.material_override as StandardMaterial3D
	var rise := clampf(lift * 2.2, 0.0, 1.0)
	shadow.scale = Vector3.ONE * (1.0 + rise * 0.25)
	shadow_mat.albedo_color.a = lerpf(0.78, 0.37, rise)

	if rig.has_meta("levitation_ring"):
		var circle: Node3D = rig.get_meta("levitation_ring")
		var orbit: Node3D = rig.get_meta("arcane_orbit")
		circle.rotation.y = fposmod(t * 0.75, TAU)
		orbit.rotation.y = fposmod(-t * 1.7, TAU)
		orbit.position.y = 0.55 + sin(t * 2.8) * 0.085
	if rig.has_meta("hoops_node"):
		var hoops: Node3D = rig.get_meta("hoops_node")
		hoops.rotation = Vector3(0.21 * sin(t * 2.3), fposmod(t * 1.9, TAU), 0.13 * cos(t * 2.1))
	if rig.has_meta("aegis_node"):
		var inner: Node3D = rig.get_meta("aegis_inner_ring")
		var outer: Node3D = rig.get_meta("aegis_outer_ring")
		inner.rotation.y = fposmod(t * 0.86, TAU)
		outer.rotation.y = fposmod(-t * 0.62, TAU)
		inner.rotation.x = 0.22 * sin(t * 1.5)
		outer.rotation.x = 0.31 * cos(t * 1.3)
	if rig.has_meta("chest_core") and bool(rig.get_meta("overdrive", false)):
		_pulse_chest_core(rig, t)
	var bars := rig.get_node_or_null("enemy_bars") as MeshInstance3D
	if bars != null:
		bars.position.y = float(rig.get_meta("sprite_height")) + 0.24 + maxf(lift, 0.0)


# speed is horizontal world speed (limp 1.3-1.6, walk 1.0-1.4, run 4.0-5.2, crawl 0.6).
# gesture is one of NPC_GESTURES or "". The rig sets "step_triggered" on footfalls and
# "gesture_beat" on a handbell strike or a crank/winch turn so audio can sync to it.
static func animate_npc_rig(rig: Node3D, t: float, is_speaking: bool = false, speed: float = 0.0, gesture: String = "") -> void:
	if not rig.has_meta("sprite_mat"):
		return
	var body: Node3D = rig.get_meta("body_pivot")
	var material: ShaderMaterial = rig.get_meta("sprite_mat")
	_face_rig_camera(rig, body)
	var last_time: float = rig.get_meta("pose_time", t - 1.0 / 60.0)
	var delta := clampf(t - last_time, 0.0, 0.1)
	rig.set_meta("pose_time", t)
	rig.set_meta("step_triggered", false)
	rig.set_meta("gesture_beat", false)
	var hip_y: float = rig.get_meta("hip_y")
	var height: float = rig.get_meta("sprite_height")

	if gesture != str(rig.get_meta("gesture_name", "")):
		rig.set_meta("gesture_name", gesture)
		rig.set_meta("gesture_t0", t)
		rig.set_meta("gesture_beats", 0)
	var gt := maxf(t - float(rig.get_meta("gesture_t0", t)), 0.0)

	# Locomotion: drive the shader's leg stride and a weight bob so walking NPCs never slide.
	var crawling := gesture == "crawl"
	var limp := str(rig.get_meta("gait", "walk")) == "limp"
	var moving := speed > 0.05
	var stride := clampf(speed / 2.6, 0.0, 1.0) if moving else 0.0
	if crawling:
		stride *= 0.55
	var previous_phase: float = rig.get_meta("walk_phase", 0.0)
	var cadence := 3.4 if crawling else 2.3
	if limp:
		# Hurry off the wounded leg, linger on the sound one.
		cadence *= lerpf(0.6, 1.4, 0.5 + 0.5 * sin(previous_phase))
	var next_phase := previous_phase + delta * maxf(speed, 0.0) * cadence if moving else previous_phase
	var phase := fposmod(next_phase, TAU)
	rig.set_meta("walk_phase", phase)
	if moving and stride > 0.10 and floori(next_phase / PI) > floori(previous_phase / PI):
		rig.set_meta("step_triggered", true)
	var step_wave := sin(phase)
	var bob := lerpf(-0.03, 0.05, step_wave * step_wave) * stride * hip_y
	var sway := -step_wave * stride * hip_y * 0.045
	var roll := -step_wave * stride * 0.021
	if limp and moving:
		var bad_leg := maxf(0.0, -step_wave)
		bob -= bad_leg * 0.07 * hip_y * stride
		roll += bad_leg * 0.06 * stride

	# Gestures layer restrained whole-body and arm motion over the stride.
	var squash := 1.0
	var widen := 1.0
	var arm := 0.0
	var arm_rate := 10.0
	var tremble := 0.0
	var glow_shift := Vector2.ZERO
	var light_boost := 1.0
	var beats := -1.0
	match gesture:
		"lantern_raise":
			var up := smoothstep(0.0, 0.45, gt)
			arm = 0.62 * up
			glow_shift = Vector2(0.0, 0.11 * height * up)
			light_boost = 1.0 + 0.3 * up
		"lantern_wave":
			var wave := sin(gt * TAU * 0.8)
			arm = 0.48 + 0.2 * wave
			glow_shift = Vector2(wave * 0.05 * height, 0.08 * height)
			roll += wave * 0.02
			light_boost = 1.15
		"toll_handbell":
			# One toll every 1.25 s: a coil, then a sharp strike with a flare of the bell light.
			var cycle := fposmod(gt * 0.8, 1.0)
			arm = cycle
			arm_rate = 40.0
			beats = floorf(gt * 0.8 + 0.15)
			var since_strike := fposmod(cycle - 0.85, 1.0) / 0.8
			light_boost = 1.0 + 2.2 * exp(-since_strike * 6.0) * float(gt > 1.0)
			roll += 0.03 * smoothstep(0.78, 1.0, cycle)
			glow_shift = Vector2(0.0, -0.04 * height * smoothstep(0.78, 1.0, cycle))
		"clutch_head":
			squash = 0.95
			widen = 1.02
			arm = 0.38
			tremble = 0.22 + 0.1 * sin(gt * 3.0)
			roll += sin(gt * 1.7) * 0.05
		"kneel":
			var k := smoothstep(0.0, 0.5, gt)
			squash = lerpf(1.0, 0.82, k)
			widen = lerpf(1.0, 1.04, k)
		"sit":
			var k := smoothstep(0.0, 0.6, gt)
			squash = lerpf(1.0, 0.76, k)
			widen = lerpf(1.0, 1.06, k)
		"rise":
			var k := smoothstep(0.0, 1.2, gt)
			squash = lerpf(0.82, 1.0, k)
			widen = lerpf(1.04, 1.0, k)
			tremble = (1.0 - k) * 0.15
			roll += (1.0 - k) * 0.04 * sin(gt * 5.0)
		"beckon":
			var c := 0.5 + 0.5 * sin(gt * TAU * 0.9)
			arm = 0.25 + 0.35 * c
			roll -= 0.03 * c
		"winch", "crank", "release_crank":
			var rate := 3.2 if gesture == "winch" else 4.4
			var turn := gt * rate
			var amplitude := 1.0
			if gesture == "release_crank":
				turn = rate * (1.0 - exp(-gt * 2.5)) / 2.5
				amplitude = exp(-gt * 2.5)
			var c := sin(turn)
			arm = 0.4 + (0.22 if gesture == "winch" else 0.28) * c * amplitude
			bob += 0.02 * hip_y * cos(turn) * amplitude
			roll += (0.02 if gesture == "winch" else -0.025) * c * amplitude
			beats = floorf(turn / TAU)
		"unlock":
			arm = 0.5 + 0.08 * sin(gt * 14.0) * (1.0 - smoothstep(0.8, 1.2, gt))
		"crawl":
			squash = 0.55
			widen = 1.14
			roll += step_wave * stride * 0.06
	if beats >= 0.0 and int(beats) > int(rig.get_meta("gesture_beats", 0)):
		rig.set_meta("gesture_beats", int(beats))
		rig.set_meta("gesture_beat", true)

	# Late Hollowing: a faint involuntary tremor even at rest.
	var stage: int = rig.get_meta("hollowing_stage", 0)
	if stage >= 3:
		tremble = maxf(tremble, (0.05 if stage == 3 else 0.1) * smoothstep(0.6, 1.0, sin(t * 0.9)))
	if is_speaking:
		roll += sin(t * 6.2) * 0.015

	var sway_axis := Vector3(cos(body.rotation.y), 0.0, -sin(body.rotation.y))
	var pose := sway_axis * sway
	pose.y = hip_y * squash + bob
	var blend := 1.0 - exp(-delta * 14.0)
	body.scale = body.scale.lerp(Vector3(widen, squash, 1.0), blend)
	body.position = body.position.lerp(pose, blend)
	body.rotation.z = lerpf(body.rotation.z, roll, blend)
	var arm_now := lerpf(float(rig.get_meta("gesture_arm", 0.0)), arm, 1.0 - exp(-delta * arm_rate))
	if gesture == "toll_handbell" and arm < arm_now:
		arm_now = arm
	rig.set_meta("gesture_arm", arm_now)

	# Mirror the art for sustained sideways travel, as the enemy rigs do.
	var facing: float = rig.get_meta("facing_flip", 1.0)
	if rig.is_inside_tree():
		var world := rig.global_position
		var last_pos: Vector3 = rig.get_meta("last_world_pos", world)
		rig.set_meta("last_world_pos", world)
		var travel := Vector3(world.x - last_pos.x, 0.0, world.z - last_pos.z)
		if moving and travel.length_squared() > 0.000001:
			var world_right := (rig.global_basis * -sway_axis).normalized()
			var lateral := travel.normalized().dot(world_right)
			if absf(lateral) > 0.30:
				facing = -signf(lateral)
	rig.set_meta("facing_flip", facing)
	var glow: Node3D = rig.get_meta("eye_glow")
	glow.position.x = (float(rig.get_meta("glow_rest_x")) + glow_shift.x) * facing
	glow.position.y = float(rig.get_meta("glow_rest_y", glow.position.y)) + glow_shift.y
	if rig.has_meta("lantern_light"):
		var light := rig.get_meta("lantern_light") as OmniLight3D
		if is_instance_valid(light):
			var flicker := 1.0
			if bool(rig.get_meta("lantern_flicker", false)):
				flicker = 0.93 + 0.05 * sin(t * 11.3) + 0.03 * sin(t * 23.7 + 1.3)
			light.light_energy = float(rig.get_meta("lantern_energy", light.light_energy)) * flicker * light_boost

	var actual_lift := body.position.y - hip_y * body.scale.y
	material.set_shader_parameter("relief_yaw", sin(body.rotation.y) * 0.47)
	material.set_shader_parameter("idle_time", t)
	material.set_shader_parameter("speaking", 1.0 if is_speaking else 0.0)
	material.set_shader_parameter("walk_phase", phase)
	material.set_shader_parameter("walk_speed", stride)
	material.set_shader_parameter("ground_lift", actual_lift / (height * maxf(body.scale.y, 0.1)))
	material.set_shader_parameter("facing_flip", facing)
	material.set_shader_parameter("attack_phase", clampf(arm_now, 0.0, 1.0))
	material.set_shader_parameter("hit_recoil", clampf(tremble, 0.0, 1.0))
	_animate_rig_accents(rig, t, actual_lift)


# Stage 0..4 dims the lantern (1.8 -> 0.25 for Torin) and cools the sprite toward a
# frost-violet rim so the player watches the Hollowing take him across Chapter I.
static func set_npc_hollowing(rig: Node3D, stage: int) -> void:
	if not is_instance_valid(rig) or not rig.has_meta("sprite_mat"):
		return
	var level := clampi(stage, 0, HOLLOWING_LANTERN.size() - 1)
	var k := float(level) / float(HOLLOWING_LANTERN.size() - 1)
	rig.set_meta("hollowing_stage", level)
	var warm: Color = rig.get_meta("glow_color", Color("ffab48"))
	if rig.has_meta("lantern_light"):
		var base: float = rig.get_meta("lantern_base_energy", HOLLOWING_LANTERN[0])
		var energy := base * HOLLOWING_LANTERN[level] / HOLLOWING_LANTERN[0]
		rig.set_meta("lantern_energy", energy)
		var light := rig.get_meta("lantern_light") as OmniLight3D
		if is_instance_valid(light):
			light.light_energy = energy
			light.light_color = warm.lerp(Color("b9a8e0"), k * 0.45)
			light.omni_range = float(rig.get_meta("lantern_base_range", light.omni_range)) * lerpf(1.0, 0.72, k)
	var material: ShaderMaterial = rig.get_meta("sprite_mat")
	material.set_shader_parameter("emissive_tint", warm.lerp(HOLLOWING_TINT, k))
	material.set_shader_parameter("emissive_tint_weight", lerpf(float(rig.get_meta("tint_weight_rest", 0.18)), 0.6, k))
	material.set_shader_parameter("frost_amount", 0.2 * k * k)


# The Ladle's cracked chest: hidden until Phase II Overdrive (HP <= 320).
static func _build_chest_core(rig: Node3D) -> void:
	var body: Node3D = rig.get_meta("body_pivot")
	var height: float = rig.get_meta("sprite_height")
	var hip_y: float = rig.get_meta("hip_y")
	var core := _pivot(body, "chest_core", Vector3(0.0, height * 0.63 - hip_y, -0.42))
	var heart := _sphere(core, Vector3.ZERO, Vector3.ONE * 0.2, _effect_material(Color("f6efff"), 9.0), 16)
	heart.name = "core_heart"
	var halo_mat := _effect_material(Color(0.78, 0.6, 1.0, 0.32), 4.0)
	halo_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var halo := _sphere(core, Vector3.ZERO, Vector3.ONE * 0.44, halo_mat, 16)
	halo.name = "core_halo"
	var cracks := _pivot(core, "core_cracks")
	var crack_mat := _effect_material(Color("e6d0ff"), 6.0)
	for i in 7:
		var angle := TAU * float(i) / 7.0 + 0.3 * sin(float(i) * 2.7)
		var length := 0.34 + 0.22 * absf(sin(float(i) * 1.9))
		var shard := _box(cracks, Vector3(cos(angle), sin(angle), 0.0) * (0.14 + length * 0.5), Vector3(length, 0.035, 0.02), crack_mat)
		shard.rotation.z = angle
	for node in core.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := _light(core, Vector3(0.0, 0.0, -0.2), Color("e6d4ff"), 0.0, 7.0)
	light.name = "core_light"
	core.visible = false
	rig.set_meta("chest_core", core)
	rig.set_meta("chest_core_light", light)
	rig.set_meta("overdrive", false)


# Reveals and pulses the blinding white-violet chest weakpoint in Phase II Overdrive.
static func set_colossus_overdrive(rig: Node3D, active: bool) -> void:
	if not is_instance_valid(rig) or not rig.has_meta("chest_core"):
		return
	var core: Node3D = rig.get_meta("chest_core")
	var light: OmniLight3D = rig.get_meta("chest_core_light")
	var was_active: bool = rig.get_meta("overdrive", false)
	rig.set_meta("overdrive", active)
	core.visible = active
	if active and not was_active:
		rig.set_meta("overdrive_since", float(rig.get_meta("pose_time", 0.0)))
		core.scale = Vector3.ONE * 0.01
	light.light_energy = 4.5 if active else 0.0
	var material: ShaderMaterial = rig.get_meta("sprite_mat")
	var rest: Color = rig.get_meta("glow_color", Color("ff6b26"))
	material.set_shader_parameter("emissive_tint", rest.lerp(Color("efe2ff"), 0.7) if active else rest)
	material.set_shader_parameter("emissive_tint_weight", 0.6 if active else float(rig.get_meta("tint_weight_rest", 0.18)))


static func _pulse_chest_core(rig: Node3D, t: float) -> void:
	var core: Node3D = rig.get_meta("chest_core")
	var light: OmniLight3D = rig.get_meta("chest_core_light")
	var since := maxf(t - float(rig.get_meta("overdrive_since", t)), 0.0)
	var reveal := clampf(since / 0.35, 0.0, 1.0)
	var pop := reveal + sin(reveal * PI) * 0.25
	var throb := pow(0.5 + 0.5 * sin(t * 7.5), 3.0)
	core.scale = Vector3.ONE * maxf(pop * (0.92 + 0.16 * throb), 0.01)
	var cracks := core.get_node_or_null("core_cracks") as Node3D
	if cracks != null:
		cracks.rotation.z = sin(t * 0.8) * 0.12
	light.light_energy = (3.2 + 2.6 * throb) * reveal


# Status strengths are normalized. Solid freeze overrides the supplied frost strength until thaw.
static func set_rig_status(rig: Node3D, hit_flash: float, frost_amount: float, burn_amount: float) -> void:
	if not rig.has_meta("sprite_mat"):
		return
	var material: ShaderMaterial = rig.get_meta("sprite_mat")
	var frost := clampf(frost_amount, 0.0, 1.0)
	rig.set_meta("status_frost", frost)
	var hit := clampf(hit_flash, 0.0, 1.0)
	rig.set_meta("status_hit_flash", hit)
	material.set_shader_parameter("hit_flash", hit)
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


static func _light(parent: Node3D, pos: Vector3, color: Color, energy: float, radius: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.name = "glow_light"
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	parent.add_child(light)
	return light
