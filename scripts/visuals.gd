class_name Visuals
extends RefCounted

const GODRAY_SHADER := preload("res://shaders/godray.gdshader")
const LIGHTNING_SHADER := preload("res://shaders/lightning.gdshader")
const RESONANCE_SHADER := preload("res://shaders/resonance_pulse.gdshader")

# Transient impact decals keep a per-parent FIFO; the oldest mark retires first.
const SPLATTER_BUDGET := 48
const SPLATTER_KINDS: Array[String] = ["blood", "scorch", "frost", "ash", "soul"]
const SPLATTER_VARIANTS := 3
# Render layer 2 holds actor sprites. Decals skip it so marks stay on the world.
const ACTOR_RENDER_LAYER := 1 << 1
const DECAL_CULL_MASK := 0xFFFFF & ~ACTOR_RENDER_LAYER
const BURST_BUDGET := 4
const BURST_KINDS: Array[String] = ["dust", "ash", "ice", "glass", "sparks", "slag", "blood"]

static var _blood_tex: ImageTexture
static var _scorch_tex: ImageTexture
static var _frost_tex: ImageTexture
static var _splatter_cache: Dictionary = {}
static var _glyph_atlas: ImageTexture
static var _soft_dot: ImageTexture
static var _stream_shader: Shader

# Generates a Sobel normal map from any albedo Texture2D for crisp PBR stone/wood relief!
static func make_normal_map(tex: Texture2D, strength: float = 2.6) -> ImageTexture:
	var src := tex.get_image()
	if src == null:
		return null
	src = src.duplicate()
	src.decompress()
	var w := mini(256, src.get_width())
	var h := mini(256, src.get_height())
	if src.get_width() != w or src.get_height() != h:
		src.resize(w, h, Image.INTERPOLATE_BILINEAR)
	var out := Image.create(w, h, false, Image.FORMAT_RGB8)
	var lum := PackedFloat32Array()
	lum.resize(w * h)
	for y in h:
		for x in w:
			var c := src.get_pixel(x, y)
			lum[y * w + x] = c.r * 0.299 + c.g * 0.587 + c.b * 0.114
	for y in h:
		var ym := (y - 1 + h) % h
		var yp := (y + 1) % h
		for x in w:
			var xm := (x - 1 + w) % w
			var xp := (x + 1) % w
			var tl := lum[ym * w + xm]
			var t  := lum[ym * w + x]
			var tr := lum[ym * w + xp]
			var l  := lum[y * w + xm]
			var r  := lum[y * w + xp]
			var bl := lum[yp * w + xm]
			var b  := lum[yp * w + x]
			var br := lum[yp * w + xp]
			var dx := (tr + 2.0 * r + br) - (tl + 2.0 * l + bl)
			var dy := (bl + 2.0 * b + br) - (tl + 2.0 * t + tr)
			var n := Vector3(-dx * strength, -dy * strength, 1.0).normalized()
			out.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))
	out.generate_mipmaps()
	return ImageTexture.create_from_image(out)

static func make_timber_texture(rng: RandomNumberGenerator) -> ImageTexture:
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	for y in 128:
		var plank := y / 32
		var seam := (y % 32) < 2
		for x in 128:
			var grain := sin(float(x) * 0.22 + sin(float(y) * 0.18 + float(plank) * 2.1) * 2.0) * 0.08
			var fine := rng.randf_range(-0.04, 0.04)
			var base := Color("4b3322") if plank % 2 == 0 else Color("3e2a1c")
			var col := base.darkened(0.62) if seam else base.lightened(maxf(0.0, grain + fine)).darkened(maxf(0.0, -(grain + fine)))
			img.set_pixel(x, y, col)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

static func make_metal_texture(base: Color, rng: RandomNumberGenerator) -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var rivet := ((x % 32 == 4 or x % 32 == 28) and (y % 32 == 4 or y % 32 == 28))
			var border := (x % 32 == 0 or y % 32 == 0)
			var scratch := sin(float(x) * 0.45 + float(y) * 0.08) * 0.05 + rng.randf_range(-0.03, 0.03)
			var col := base.darkened(0.45) if border else base.lightened(0.25) if rivet else base.lightened(maxf(0.0, scratch)).darkened(maxf(0.0, -scratch))
			img.set_pixel(x, y, col)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

static func _make_splat_texture(base: Color, seed_val: int) -> ImageTexture:
	var r := RandomNumberGenerator.new()
	r.seed = seed_val
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 64:
		for x in 64:
			var p := Vector2(float(x) - 31.5, float(y) - 31.5) / 31.5
			var ang := atan2(p.y, p.x)
			var wobble := 0.65 + sin(ang * 5.0 + float(seed_val)) * 0.16 + cos(ang * 9.0) * 0.10
			var d := p.length() / wobble
			if d < 1.0:
				var a := clampf((1.0 - d * d) * 1.15, 0.0, 0.92)
				var shade := r.randf_range(0.85, 1.12)
				img.set_pixel(x, y, Color(minf(1.0, base.r * shade), minf(1.0, base.g * shade), minf(1.0, base.b * shade), a))
	return ImageTexture.create_from_image(img)

# Chapter indices are zero-based; chapter IDs use the same three palettes.
static func configure_environment(env: Environment, stage: Variant) -> void:
	var chapter: int = 0
	match stage:
		0, "ch1_court":
			chapter = 0
		1, "ch2_tower":
			chapter = 1
		2, "ch3_kiln":
			chapter = 2
		_:
			if stage is int:
				chapter = 2
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	if chapter == 0:
		sky_mat.sky_top_color = Color("0a1120")
		sky_mat.sky_horizon_color = Color("36465e")
		sky_mat.ground_bottom_color = Color("080b10")
		sky_mat.ground_horizon_color = Color("1d2633")
		env.fog_light_color = Color("2e3c4e")
		env.fog_density = 0.012
		env.volumetric_fog_albedo = Color("4f6480")
		env.volumetric_fog_density = 0.014
		env.ambient_light_color = Color("9eafca")
		env.ambient_light_energy = 0.70
	elif chapter == 1:
		sky_mat.sky_top_color = Color("110a24")
		sky_mat.sky_horizon_color = Color("49375f")
		sky_mat.ground_bottom_color = Color("090612")
		sky_mat.ground_horizon_color = Color("241738")
		env.fog_light_color = Color("382854")
		env.fog_density = 0.011
		env.volumetric_fog_albedo = Color("664c88")
		env.volumetric_fog_density = 0.016
		env.ambient_light_color = Color("afa2c7")
		env.ambient_light_energy = 0.67
	else:
		sky_mat.sky_top_color = Color("1a0b0a")
		sky_mat.sky_horizon_color = Color("673a2b")
		sky_mat.ground_bottom_color = Color("100605")
		sky_mat.ground_horizon_color = Color("381810")
		env.fog_light_color = Color("46251c")
		env.fog_density = 0.012
		env.volumetric_fog_albedo = Color("78402e")
		env.volumetric_fog_density = 0.016
		env.ambient_light_color = Color("c5a291")
		env.ambient_light_energy = 0.70
	sky_mat.sky_curve = 0.14
	sky_mat.sun_angle_max = 18.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.fog_enabled = true
	env.fog_sky_affect = 0.45

	# Forward+ Vulkan flagship features: Volumetric Fog + SSAO + SSIL + SSR
	env.volumetric_fog_enabled = true
	env.volumetric_fog_anisotropy = 0.58
	env.volumetric_fog_length = 60.0
	env.volumetric_fog_detail_spread = 2.0
	env.ssao_enabled = true
	env.ssao_radius = 1.35
	env.ssao_intensity = 1.25
	env.ssao_power = 1.12
	env.ssil_enabled = true
	env.ssil_radius = 5.0
	env.ssil_intensity = 1.1
	env.ssr_enabled = true
	env.ssr_max_steps = 28

	# Filmic ACES + HDR Bloom + Contrast
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.22
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.72
	env.glow_strength = 1.0
	env.glow_bloom = 0.10
	env.glow_hdr_threshold = 0.85
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.04
	env.adjustment_saturation = 1.10

# Persistent Prodeus-style blood / scorch / frost decals projected onto stone floors & walls
static func spawn_decal(parent: Node3D, pos: Vector3, kind: String = "blood", scale_xz: float = 1.6) -> void:
	if _blood_tex == null:
		_blood_tex = _make_splat_texture(Color("5e0d0a"), 11)
		_scorch_tex = _make_splat_texture(Color("171210"), 23)
		_frost_tex = _make_splat_texture(Color("7ae4f5"), 37)
	var d := Decal.new()
	d.name = "decal_" + kind
	d.position = pos + Vector3(0, 0.05, 0)
	d.size = Vector3(scale_xz, 0.9, scale_xz)
	d.texture_albedo = _blood_tex if kind == "blood" else _scorch_tex if kind == "scorch" else _frost_tex
	if kind == "frost":
		d.emission_energy = 0.8
	d.modulate = Color(1, 1, 1, 0.92)
	parent.add_child(d)
	var tw := parent.create_tween().bind_node(d)
	tw.tween_interval(28.0)
	tw.tween_property(d, "modulate:a", 0.0, 2.0)
	tw.tween_callback(d.queue_free)

# Prodeus-style chunky physical gibs bursting on heavy kills / frozen shatters!
static func spawn_gibs(parent: Node3D, pos: Vector3, dir: Vector3, mat: Material, rng: RandomNumberGenerator, count: int = 8, decal_kind: String = "blood") -> void:
	spawn_decal(parent, Vector3(pos.x, pos.y - 0.6, pos.z), decal_kind, rng.randf_range(1.7, 2.6))
	for i in count:
		var g := RigidBody3D.new()
		g.name = "gib"
		g.position = pos + Vector3(rng.randf_range(-0.35, 0.35), rng.randf_range(0.2, 1.1), rng.randf_range(-0.35, 0.35))
		g.mass = 0.25
		g.linear_damp = 0.5
		g.angular_damp = 0.8
		g.collision_layer = 16
		g.collision_mask = 1
		parent.add_child(g)
		var sz := Vector3(rng.randf_range(0.14, 0.28), rng.randf_range(0.12, 0.24), rng.randf_range(0.14, 0.28))
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = sz
		mi.mesh = bm
		mi.material_override = mat
		g.add_child(mi)
		var col := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = sz
		col.shape = bs
		g.add_child(col)
		var impulse := (dir * rng.randf_range(3.5, 8.5)) + Vector3(rng.randf_range(-3.5, 3.5), rng.randf_range(2.5, 6.2), rng.randf_range(-3.5, 3.5))
		g.apply_central_impulse(impulse)
		g.apply_torque_impulse(Vector3(rng.randf_range(-4, 4), rng.randf_range(-4, 4), rng.randf_range(-4, 4)))
		var tw := parent.create_tween().bind_node(g)
		tw.tween_interval(7.5)
		tw.tween_callback(g.queue_free)

static func spawn_ambient_particles(parent: Node3D, kind: String, center: Vector3, extents: Vector3, amount: int = 140) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "gpu_" + kind
	p.position = center
	p.amount = amount
	p.lifetime = 5.5 if kind == "ash" else 4.2
	p.preprocess = 3.0
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extents
	if kind == "ash":
		pm.direction = Vector3(0.25, -1.0, 0.15)
		pm.gravity = Vector3(0.0, -0.35, 0.0)
		pm.initial_velocity_min = 0.35
		pm.initial_velocity_max = 0.85
		pm.color = Color(0.75, 0.78, 0.82, 0.65)
	else:
		pm.direction = Vector3(0.0, 1.0, 0.0)
		pm.gravity = Vector3(0.0, 0.45, 0.0)
		pm.initial_velocity_min = 0.55
		pm.initial_velocity_max = 1.35
		pm.color = Color(1.0, 0.52, 0.18, 0.90)
	pm.spread = 28.0
	pm.scale_min = 0.04
	pm.scale_max = 0.10
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.11, 0.11)
	var mat := StandardMaterial3D.new()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	if kind == "ember":
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.emission_enabled = true
		mat.emission = Color("ff7828")
		mat.emission_energy_multiplier = 2.6
	quad.material = mat
	p.draw_pass_1 = quad
	parent.add_child(p)
	return p

static func spawn_impact_light(parent: Node3D, pos: Vector3, color: Color, energy: float = 3.6, reach: float = 7.5, duration: float = 0.24) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = reach
	parent.add_child(l)
	var tw := parent.create_tween().bind_node(l)
	tw.tween_property(l, "light_energy", 0.0, duration)
	tw.tween_callback(l.queue_free)


static func make_pbr_stone_maps(rng: RandomNumberGenerator, base_color: Color, tex_size: int = 256) -> Dictionary:
	var size := maxi(1, tex_size)
	var albedo := Image.create(size, size, false, Image.FORMAT_RGB8)
	var roughness := Image.create(size, size, false, Image.FORMAT_R8)
	var heights := PackedFloat32Array()
	heights.resize(size * size)
	var noise := _rock_noise(rng)
	var block_tints := PackedFloat32Array()
	for index in 32:
		block_tints.append(rng.randf_range(-0.08, 0.10))
	var mortar := base_color.darkened(0.58).lerp(Color("333637"), 0.28)
	var moss := base_color.darkened(0.32).lerp(Color("536247"), 0.57)
	for y in size:
		for x in size:
			var u := (float(x) + 0.5) / float(size)
			var v := (float(y) + 0.5) / float(size)
			var torus := _tile_noise_position(u, v)
			var broad := noise.get_noise_3dv(torus * 3.5)
			var chips := noise.get_noise_3dv(torus * 37.0)
			var grit := noise.get_noise_3dv(torus * 124.0)
			var row_y := v * 8.0 + chips * 0.052
			var row := floori(row_y)
			var block_x := u * 4.0 + float(posmod(row, 2)) * 0.5 + chips * 0.065
			var col := floori(block_x)
			var joints := Vector2(0.5, 0.5) - (Vector2(fposmod(block_x, 1.0), fposmod(row_y, 1.0)) - Vector2(0.5, 0.5)).abs()
			var edge_distance := minf(joints.x * 2.0, joints.y) - grit * 0.016
			var bevel := smoothstep(0.028, 0.12, edge_distance)
			var face := smoothstep(0.022, 0.064, edge_distance)
			var tint := block_tints[posmod(row, 8) * 4 + posmod(col, 4)] + broad * 0.16 + grit * 0.07
			var rock := base_color.lightened(maxf(tint, 0.0)).darkened(maxf(-tint, 0.0))
			rock = rock.darkened((1.0 - bevel) * 0.25)
			var weather := smoothstep(0.10, 0.40, broad + chips * 0.17 + (1.0 - bevel) * 0.17)
			albedo.set_pixel(x, y, mortar.lerp(rock, face).lerp(moss, weather * 0.47 * (0.4 + face * 0.6)))
			roughness.set_pixel(x, y, Color(lerpf(0.98, 0.72 + broad * 0.09 + grit * 0.12, bevel) + weather * 0.08, 0.0, 0.0))
			heights[y * size + x] = bevel * 0.42 + face * broad * 0.12 + grit * 0.038
	return _pbr_textures(albedo, roughness, heights)


static func make_pbr_basalt_maps(rng: RandomNumberGenerator, tex_size: int = 256) -> Dictionary:
	var size := maxi(1, tex_size)
	var albedo := Image.create(size, size, false, Image.FORMAT_RGB8)
	var roughness := Image.create(size, size, false, Image.FORMAT_R8)
	var heights := PackedFloat32Array()
	heights.resize(size * size)
	var noise := _rock_noise(rng)
	const CELLS := 7
	var sites := PackedVector2Array()
	var tints := PackedFloat32Array()
	for index in CELLS * CELLS:
		sites.append(Vector2(rng.randf_range(0.23, 0.77), rng.randf_range(0.23, 0.77)))
		tints.append(rng.randf())
	var soot := Color("232027")
	var oxidized := Color("65483f")
	var fissure := Color("100e13")
	for y in size:
		for x in size:
			var u := (float(x) + 0.5) / float(size)
			var v := (float(y) + 0.5) / float(size)
			var torus := _tile_noise_position(u, v)
			var strata := noise.get_noise_3dv(torus * 18.0)
			var grit := noise.get_noise_3dv(torus * 155.0)
			var p := Vector2(u, v) * float(CELLS) + Vector2(strata, noise.get_noise_3dv(torus * 27.0)) * 0.22
			var cell := Vector2i(floori(p.x), floori(p.y))
			var nearest := INF
			var second := INF
			var tint := 0.0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var other := cell + Vector2i(dx, dy)
					var site := posmod(other.y, CELLS) * CELLS + posmod(other.x, CELLS)
					var distance := p.distance_squared_to(Vector2(other) + sites[site])
					if distance < nearest:
						second = nearest
						nearest = distance
						tint = tints[site]
					elif distance < second:
						second = distance
			var crack := second - nearest + grit * 0.018
			var lip := smoothstep(0.011, 0.105, crack)
			var color := soot.lerp(oxidized, clampf(0.12 + tint * 0.35 + strata * 0.48, 0.0, 0.82))
			color = color.lightened(maxf(0.0, grit) * 0.10).darkened(maxf(0.0, -grit) * 0.24)
			albedo.set_pixel(x, y, fissure.lerp(color, lip))
			roughness.set_pixel(x, y, Color(lerpf(0.99, 0.81 + grit * 0.14 + strata * 0.12, lip), 0.0, 0.0))
			heights[y * size + x] = lip * (0.43 + strata * 0.16) + grit * 0.09
	return _pbr_textures(albedo, roughness, heights)


static func _rock_noise(rng: RandomNumberGenerator) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi_range(0, 2147483647)
	noise.frequency = 1.0
	noise.fractal_octaves = 3
	return noise


# A torus in noise space wraps both texture axes continuously.
static func _tile_noise_position(u: float, v: float) -> Vector3:
	var radius := 1.0 + cos(v * TAU) * 0.37
	return Vector3(radius * cos(u * TAU), radius * sin(u * TAU), sin(v * TAU) * 0.37)


static func _pbr_textures(albedo: Image, roughness: Image, heights: PackedFloat32Array) -> Dictionary:
	var size := albedo.get_width()
	var normal := Image.create(size, size, false, Image.FORMAT_RGB8)
	var strength := 1.45 * float(size) / 256.0
	for y in size:
		var above := posmod(y - 1, size) * size
		var below := ((y + 1) % size) * size
		var row := y * size
		for x in size:
			var dx := heights[row + (x + 1) % size] - heights[row + posmod(x - 1, size)]
			var dy := heights[below + x] - heights[above + x]
			var n := Vector3(-dx * strength, -dy * strength, 1.0).normalized() * 0.5 + Vector3.ONE * 0.5
			normal.set_pixel(x, y, Color(n.x, n.y, n.z))
	albedo.generate_mipmaps()
	roughness.generate_mipmaps()
	normal.generate_mipmaps(true)
	return {
		"albedo": ImageTexture.create_from_image(albedo),
		"normal": ImageTexture.create_from_image(normal),
		"roughness": ImageTexture.create_from_image(roughness),
	}


# The narrow source sits on the local +Y end of the open shaft.
static func spawn_godray(parent: Node3D, pos: Vector3, rot_deg: Vector3, radius: float = 1.6, length: float = 9.0, color: Color = Color(0.65, 0.78, 1.0, 0.22)) -> MeshInstance3D:
	var shaft := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = maxf(radius * 0.29, 0.001)
	mesh.bottom_radius = maxf(radius, 0.001)
	mesh.height = maxf(length, 0.001)
	mesh.radial_segments = 32
	mesh.rings = 0
	mesh.cap_top = false
	mesh.cap_bottom = false
	var material := ShaderMaterial.new()
	material.shader = GODRAY_SHADER
	material.set_shader_parameter("shaft_color", color)
	shaft.name = "godray"
	shaft.mesh = mesh
	shaft.material_override = material
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shaft.position = pos
	shaft.rotation_degrees = rot_deg
	parent.add_child(shaft)
	return shaft


# Endpoints are in the parent's local coordinate system.
static func spawn_lightning_arc(parent: Node3D, from: Vector3, to: Vector3, color: Color = Color("6bf0ff"), duration: float = 0.22) -> void:
	var offset := to - from
	var length := offset.length()
	if length < 0.001 or duration <= 0.0:
		return
	var direction := offset / length
	var axis := direction.cross(Vector3.UP if absf(direction.y) < 0.95 else Vector3.RIGHT).normalized()
	var cross_axis := direction.cross(axis)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var count := clampi(ceili(length * 3.0), 7, 24)
	var points := PackedVector3Array([Vector3.ZERO])
	var amplitude := minf(length * 0.12, 0.36)
	for i in range(1, count):
		var progress := float(i) / float(count)
		var jitter := axis * rng.randf_range(-1.0, 1.0) + cross_axis * rng.randf_range(-1.0, 1.0)
		points.append(offset * progress + jitter * amplitude * sin(progress * PI))
	points.append(offset)

	var bolt := MeshInstance3D.new()
	bolt.name = "lightning_arc"
	bolt.position = from
	bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var width := clampf(length * 0.025, 0.035, 0.12)
	_arc_ribbon(mesh, points, axis, width)
	_arc_ribbon(mesh, points, cross_axis, width)
	if length >= 1.0:
		var split := points[count / 2]
		var branch := PackedVector3Array([
			split,
			split + offset * 0.12 + axis * amplitude * 1.3,
			split + offset * 0.22 + axis * amplitude * 1.1,
			split + offset * 0.31 + axis * amplitude * 2.1 + cross_axis * amplitude,
		])
		_arc_ribbon(mesh, branch, axis, width * 0.5, 0.04)
		_arc_ribbon(mesh, branch, cross_axis, width * 0.5, 0.04)
	mesh.surface_end()
	var material := ShaderMaterial.new()
	material.shader = LIGHTNING_SHADER
	material.set_shader_parameter("arc_color", color)
	bolt.mesh = mesh
	bolt.material_override = material
	var flash := OmniLight3D.new()
	flash.position = offset * 0.5
	flash.light_color = color
	flash.light_energy = 3.2
	flash.omni_range = clampf(length * 0.7, 2.0, 8.0)
	bolt.add_child(flash)
	var fade_out := func() -> void:
		var tween := bolt.create_tween().set_parallel()
		var fade := func(value: float) -> void: material.set_shader_parameter("intensity", value)
		tween.tween_method(fade, 1.0, 0.0, duration)
		tween.tween_property(flash, "light_energy", 0.0, duration)
		tween.chain().tween_callback(bolt.queue_free)
	bolt.ready.connect(fade_out, CONNECT_ONE_SHOT)
	parent.add_child(bolt)


static func _arc_ribbon(mesh: ImmediateMesh, points: PackedVector3Array, axis: Vector3, width: float, tip_scale: float = 0.42) -> void:
	var count := points.size() - 1
	for i in count:
		var start_uv := float(i) / float(count)
		var end_uv := float(i + 1) / float(count)
		var start_width := axis * width * lerpf(tip_scale, 1.0, sin(PI * start_uv))
		var end_width := axis * width * lerpf(tip_scale, 1.0, sin(PI * end_uv))
		var corners := PackedVector3Array([
			points[i] - start_width, points[i] + start_width,
			points[i + 1] - end_width, points[i + 1] + end_width,
		])
		var coords := PackedVector2Array([
			Vector2(0.0, start_uv), Vector2(1.0, start_uv),
			Vector2(0.0, end_uv), Vector2(1.0, end_uv),
		])
		for index: int in [0, 1, 2, 1, 3, 2]:
			mesh.surface_set_uv(coords[index])
			mesh.surface_add_vertex(corners[index])


static func apply_graphics_settings(env: Environment, viewport: Viewport, settings: Dictionary) -> void:
	if settings.has("volumetric_fog"):
		env.volumetric_fog_enabled = bool(settings["volumetric_fog"])
	if settings.has("ssr"):
		env.ssr_enabled = bool(settings["ssr"])
	if settings.has("ssao"):
		env.ssao_enabled = bool(settings["ssao"])
	if settings.has("msaa"):
		viewport.msaa_3d = Viewport.MSAA_4X if bool(settings["msaa"]) else Viewport.MSAA_DISABLED


# ---------------------------------------------------------------------------
# Resonance pulse: fullscreen chromatic split + tinted vignette (E4 inverted toll)
# ---------------------------------------------------------------------------

# Pass the HUD CanvasLayer or the HUD root Control to slot the pass beneath HUD text in
# that canvas. Any other node receives a dedicated layer-0 canvas, which still draws
# above the 3D view and below the default HUD layer (1). Hidden at rest.
static func create_resonance_overlay(parent: Node) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = "resonance_overlay"
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color.WHITE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	material.shader = RESONANCE_SHADER
	material.set_shader_parameter("strength", 0.0)
	material.set_shader_parameter("pulse_color", Color("b87aff"))
	rect.material = material
	rect.visible = false
	rect.set_meta("resonance_material", material)
	if parent is CanvasLayer or parent is Control:
		parent.add_child(rect)
		parent.move_child(rect, 0)
	else:
		var layer := CanvasLayer.new()
		layer.name = "resonance_layer"
		layer.layer = 0
		parent.add_child(layer)
		layer.add_child(rect)
	return rect


# Accepts the overlay ColorRect (also toggles its visibility, so the screen copy is free
# at rest) or the bare ShaderMaterial.
static func set_resonance_pulse(overlay_or_mat: Variant, strength: float, color: Color = Color("b87aff")) -> void:
	if typeof(overlay_or_mat) != TYPE_OBJECT or not is_instance_valid(overlay_or_mat):
		return
	var amount := clampf(strength, 0.0, 1.0)
	var material: ShaderMaterial = null
	var item: CanvasItem = null
	if overlay_or_mat is ShaderMaterial:
		material = overlay_or_mat
	elif overlay_or_mat is CanvasItem:
		item = overlay_or_mat
		material = item.material as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter("strength", amount)
	material.set_shader_parameter("pulse_color", color)
	if item != null:
		item.visible = amount > 0.002


# One pulse with the plan's 0.06 s attack and 0.24 s decay. Drive camera shake from the
# same returned tween's scalar if desired. Returns null when the overlay is not in a tree.
static func trigger_resonance_pulse(overlay: ColorRect, peak: float = 1.0, color: Color = Color("b87aff"), attack: float = 0.06, decay: float = 0.24) -> Tween:
	if not is_instance_valid(overlay):
		return null
	var previous: Variant = overlay.get_meta("resonance_tween") if overlay.has_meta("resonance_tween") else null
	if previous is Tween and (previous as Tween).is_valid():
		(previous as Tween).kill()
	if not overlay.is_inside_tree():
		set_resonance_pulse(overlay, 0.0, color)
		return null
	var material := overlay.material as ShaderMaterial
	var start := 0.0
	if material != null and overlay.visible:
		start = float(material.get_shader_parameter("strength"))
	var apply := func(value: float) -> void: set_resonance_pulse(overlay, value, color)
	var tween := overlay.create_tween()
	tween.tween_method(apply, start, clampf(peak, 0.0, 1.0), maxf(attack, 0.001))
	tween.tween_method(apply, clampf(peak, 0.0, 1.0), 0.0, maxf(decay, 0.001))
	overlay.set_meta("resonance_tween", tween)
	return tween


# ---------------------------------------------------------------------------
# Oriented surface splatter decals (floors, walls and ceilings)
# ---------------------------------------------------------------------------

# hit_pos is world space; local +Y of the decal follows normal. radius is the footprint's
# half-width in metres. Transient marks share a 48-slot FIFO per parent; persistent marks
# (authored trails) live until the parent (the chapter root) is freed.
static func spawn_surface_splatter(parent: Node3D, hit_pos: Vector3, normal: Vector3, kind: String, radius: float = 1.4, seed_value: int = 0, persistent: bool = false) -> Decal:
	if not is_instance_valid(parent):
		return null
	var surface_kind := kind if SPLATTER_KINDS.has(kind) else "blood"
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([surface_kind, seed_value, hit_pos.snapped(Vector3.ONE * 0.01)])
	var maps := _splatter_maps(surface_kind, rng.randi_range(0, SPLATTER_VARIANTS - 1))
	var up := normal.normalized() if normal.length_squared() > 0.000001 else Vector3.UP
	var reference := Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.92 else Vector3.RIGHT
	var tangent := reference.cross(up).normalized()
	var orientation := Basis(up, rng.randf_range(0.0, TAU)) * Basis(tangent, up, tangent.cross(up).normalized())
	var width := maxf(radius, 0.05) * 2.0
	var stretch := rng.randf_range(0.82, 1.18)

	var decal := Decal.new()
	decal.name = "splatter_" + surface_kind
	decal.size = Vector3(width, clampf(radius * 0.6, 0.3, 1.0), width * stretch)
	decal.texture_albedo = maps.albedo
	decal.texture_normal = maps.normal
	decal.texture_orm = maps.orm
	decal.albedo_mix = 1.0
	decal.normal_fade = 0.35
	decal.upper_fade = 0.2
	decal.lower_fade = 0.35
	decal.cull_mask = DECAL_CULL_MASK
	decal.distance_fade_enabled = true
	decal.distance_fade_begin = 42.0
	decal.distance_fade_length = 12.0
	var alpha: float = {"blood": 0.95, "scorch": 0.9, "frost": 0.88, "ash": 0.8, "soul": 0.92}[surface_kind]
	decal.modulate = Color(1, 1, 1, alpha)
	if maps.has("emission"):
		decal.texture_emission = maps.emission
		decal.emission_energy = {"frost": 0.55, "soul": 1.1, "scorch": 1.6}.get(surface_kind, 0.0)
	decal.set_meta("splatter_kind", surface_kind)
	decal.set_meta("surface_normal", up)
	decal.set_meta("persistent", persistent)
	decal.set_meta("seed", seed_value)
	decal.add_to_group("surface_splatter")
	parent.add_child(decal)
	var pose := Transform3D(orientation, hit_pos + up * 0.01)
	if parent.is_inside_tree():
		decal.global_transform = pose
	else:
		decal.transform = pose
	if surface_kind == "scorch" and decal.is_inside_tree():
		# Hot hits glow briefly before the soot settles.
		var cool := decal.create_tween()
		cool.tween_property(decal, "emission_energy", 0.0, 1.6).set_ease(Tween.EASE_OUT)

	if persistent:
		decal.add_to_group("persistent_splatter")
		var keep := _live_nodes(parent, "_splatter_persistent")
		keep.append(decal)
	else:
		var fifo := _live_nodes(parent, "_splatter_fifo")
		while fifo.size() >= SPLATTER_BUDGET:
			_retire_node(fifo.pop_front(), "modulate:a", 0.3)
		fifo.append(decal)
	return decal


# Live transient (or all) splatter decals under a parent, for tests and save restore.
static func get_surface_splatters(parent: Node, include_persistent: bool = false) -> Array:
	if not is_instance_valid(parent):
		return []
	var out := _live_nodes(parent, "_splatter_fifo").duplicate()
	if include_persistent:
		out.append_array(_live_nodes(parent, "_splatter_persistent"))
	return out


static func clear_surface_splatters(parent: Node, include_persistent: bool = false) -> void:
	for decal: Variant in get_surface_splatters(parent, include_persistent):
		(decal as Node).queue_free()
	if is_instance_valid(parent):
		parent.set_meta("_splatter_fifo", [])
		if include_persistent:
			parent.set_meta("_splatter_persistent", [])


# Returns the live list stored on holder[key] (stale entries dropped). Mutating the
# returned array mutates the stored one.
static func _live_nodes(holder: Node, key: String) -> Array:
	var live: Array = []
	for node: Variant in holder.get_meta(key, []):
		if is_instance_valid(node) and not (node as Node).is_queued_for_deletion():
			live.append(node)
	holder.set_meta(key, live)
	return live


static func _retire_node(node: Variant, fade_property: String, fade_time: float) -> void:
	if not is_instance_valid(node):
		return
	var target := node as Node
	if target is GPUParticles3D:
		(target as GPUParticles3D).emitting = false
	if target.is_inside_tree() and fade_time > 0.0 and not fade_property.is_empty():
		var tween := target.create_tween()
		tween.tween_property(target, fade_property, 0.0, fade_time)
		tween.tween_callback(target.queue_free)
	else:
		target.queue_free()


# Frees node after seconds of scene time. Works headless and before the node enters a tree.
static func _free_after(node: Node, seconds: float) -> void:
	var start := func() -> void:
		var tween := node.create_tween()
		tween.tween_interval(maxf(seconds, 0.0))
		tween.tween_callback(node.queue_free)
	if node.is_inside_tree():
		start.call()
	else:
		node.tree_entered.connect(start, CONNECT_ONE_SHOT)


static func _splatter_maps(kind: String, variant: int) -> Dictionary:
	var key := "%s_%d" % [kind, variant]
	if _splatter_cache.has(key):
		return _splatter_cache[key]
	const SIZE := 128
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key) + 4099
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi_range(0, 2147483647)
	noise.frequency = 0.045
	noise.fractal_octaves = 3
	var albedo := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var orm := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var emissive := kind == "frost" or kind == "soul" or kind == "scorch"
	var emission: Image = Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8) if emissive else null
	var heights := PackedFloat32Array()
	heights.resize(SIZE * SIZE)
	var lobes := float(rng.randi_range(4, 7))
	var phase := rng.randf() * TAU
	var splash_angle := rng.randf() * TAU

	for y in SIZE:
		for x in SIZE:
			var p := Vector2(float(x) + 0.5, float(y) + 0.5) / float(SIZE) * 2.0 - Vector2.ONE
			var r := p.length()
			var ang := atan2(p.y, p.x)
			var n := noise.get_noise_2d(float(x), float(y))
			var a := 0.0
			var h := 0.0
			var rough := 0.8
			var col := Color.BLACK
			var glow := Color.BLACK
			match kind:
				"blood":
					var lean := pow(maxf(0.0, cos(ang - splash_angle)), 4.0)
					var edge := 0.40 + sin(ang * lobes + phase) * 0.06 + n * 0.14 + lean * 0.20
					a = (1.0 - smoothstep(edge - 0.05, edge + 0.02, r)) * 0.95
					var pool := 1.0 - smoothstep(0.0, edge, r)
					col = Color("6e100b").lerp(Color("2b0403"), clampf(pool * 0.75 + n * 0.25, 0.0, 1.0))
					h = a * (0.3 + smoothstep(edge - 0.14, edge - 0.02, r) * 0.6)
					rough = 0.18 + (1.0 - pool) * 0.22
				"scorch":
					var rays := pow(absf(sin(ang * lobes * 1.5 + n * 2.0 + phase)), 6.0)
					var edge := 0.40 + rays * 0.40 + n * 0.12
					a = (1.0 - smoothstep(edge * 0.30, edge, r)) * 0.94
					col = Color("0d0a09").lerp(Color("3a291d"), smoothstep(0.15, 1.0, r / maxf(edge, 0.01)))
					h = a * (0.22 + n * 0.12)
					rough = 0.96
					glow = Color(1.0, 0.36, 0.07) * (1.0 - smoothstep(0.0, 0.26, r + n * 0.12))
				"frost":
					var arms := pow(absf(cos(ang * 3.0 + phase)), 14.0)
					var twigs := pow(absf(cos(ang * 6.0 + phase + 0.5)), 30.0)
					var edge := 0.34 + arms * 0.52 + twigs * 0.24 + n * 0.10
					a = (1.0 - smoothstep(edge - 0.07, edge, r)) * 0.9
					var facet := smoothstep(0.32, 0.5, absf(fposmod(n * 6.0 + r * 5.0, 1.0) - 0.5))
					col = Color("e2f7ff").lerp(Color("5cbcdf"), clampf(r / maxf(edge, 0.01), 0.0, 1.0) * 0.7)
					h = a * (0.35 + facet * 0.45)
					rough = 0.12
					glow = Color("7fd8ff") * (arms * 0.55 + facet * 0.45) * a
				"ash":
					var grain := noise.get_noise_2d(float(x) * 5.3, float(y) * 5.3)
					var edge := 0.55 + n * 0.25 + sin(ang * lobes + phase) * 0.05
					a = clampf((1.0 - smoothstep(edge * 0.25, edge, r)) * (0.55 + grain * 0.4), 0.0, 0.72)
					col = Color("8d8881").lerp(Color("4c4844"), clampf(0.5 + grain * 0.6, 0.0, 1.0))
					h = a * 0.3
					rough = 0.97
				"soul":
					var ring := exp(-pow((r - 0.62 - n * 0.05) * 14.0, 2.0))
					var inner := exp(-pow((r - 0.40) * 22.0, 2.0)) * 0.6
					var band := smoothstep(0.66, 0.68, r) * (1.0 - smoothstep(0.80, 0.82, r))
					var ticks := smoothstep(0.82, 0.98, absf(sin(ang * 12.0 + phase))) * band
					var mist := (1.0 - smoothstep(0.0, 0.7, r)) * 0.22
					a = clampf(ring + inner + ticks + mist, 0.0, 1.0)
					col = Color("cdb0ff").lerp(Color("5a3c99"), clampf(r, 0.0, 1.0))
					glow = Color("b88cff") * clampf(ring * 1.2 + inner + ticks, 0.0, 1.0)
					h = (ring + ticks) * 0.4
					rough = 0.4
			albedo.set_pixel(x, y, Color(col.r, col.g, col.b, a))
			orm.set_pixel(x, y, Color(1.0, rough, 0.0))
			heights[y * SIZE + x] = h
			if emission != null:
				emission.set_pixel(x, y, Color(minf(glow.r, 1.0), minf(glow.g, 1.0), minf(glow.b, 1.0)))

	# Satellite droplets for wet or powdery kinds, biased toward the splash direction.
	var drops: int = {"blood": 18, "scorch": 5, "ash": 12}.get(kind, 0)
	var drop_color: Color = {"blood": Color("5a0c08"), "scorch": Color("120e0c"), "ash": Color("77726c")}.get(kind, Color.BLACK)
	for i in drops:
		var ang := splash_angle + rng.randfn(0.0, 0.85)
		var dist := rng.randf_range(0.48, 0.92)
		var center := (Vector2(cos(ang), sin(ang)) * dist + Vector2.ONE) * 0.5 * float(SIZE)
		var drop_r := rng.randf_range(1.2, 4.2) * (1.0 - dist * 0.45)
		for py in range(maxi(0, floori(center.y - drop_r - 1.0)), mini(SIZE, ceili(center.y + drop_r + 1.0))):
			for px in range(maxi(0, floori(center.x - drop_r - 1.0)), mini(SIZE, ceili(center.x + drop_r + 1.0))):
				var d := Vector2(float(px) + 0.5, float(py) + 0.5).distance_to(center)
				var cover := clampf(drop_r - d + 0.5, 0.0, 1.0) * (0.92 if kind == "blood" else 0.7)
				var prior := albedo.get_pixel(px, py)
				if cover > prior.a:
					albedo.set_pixel(px, py, Color(drop_color.r, drop_color.g, drop_color.b, cover))
					heights[py * SIZE + px] = maxf(heights[py * SIZE + px], cover * 0.5)

	var normal := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	for y in SIZE:
		for x in SIZE:
			var dx := heights[y * SIZE + mini(x + 1, SIZE - 1)] - heights[y * SIZE + maxi(x - 1, 0)]
			var dy := heights[mini(y + 1, SIZE - 1) * SIZE + x] - heights[maxi(y - 1, 0) * SIZE + x]
			var nrm := Vector3(-dx * 3.2, -dy * 3.2, 1.0).normalized() * 0.5 + Vector3.ONE * 0.5
			normal.set_pixel(x, y, Color(nrm.x, nrm.y, nrm.z))
	albedo.generate_mipmaps()
	orm.generate_mipmaps()
	normal.generate_mipmaps(true)
	var maps := {
		"albedo": ImageTexture.create_from_image(albedo),
		"normal": ImageTexture.create_from_image(normal),
		"orm": ImageTexture.create_from_image(orm),
	}
	if emission != null:
		emission.generate_mipmaps()
		maps["emission"] = ImageTexture.create_from_image(emission)
	_splatter_cache[key] = maps
	return maps


# ---------------------------------------------------------------------------
# One-shot particle bursts (vault seams, impacts, shattering glass and ice)
# ---------------------------------------------------------------------------

static func spawn_dust_burst(parent: Node3D, world_pos: Vector3, direction: Vector3, kind: String = "dust", seed_value: int = 0) -> GPUParticles3D:
	if not is_instance_valid(parent):
		return null
	var burst_kind := kind if BURST_KINDS.has(kind) else "dust"
	var spec := _burst_spec(burst_kind)
	var p := GPUParticles3D.new()
	p.name = "burst_" + burst_kind
	p.one_shot = true
	p.explosiveness = 0.9
	p.randomness = 0.35
	p.amount = spec.amount
	p.lifetime = spec.lifetime
	p.use_fixed_seed = true
	p.seed = absi(seed_value)
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = spec.radius
	pm.direction = _parent_dir(parent, direction if direction.length_squared() > 0.000001 else Vector3.UP)
	pm.spread = spec.spread
	pm.initial_velocity_min = spec.vmin
	pm.initial_velocity_max = spec.vmax
	pm.gravity = spec.gravity
	pm.damping_min = spec.damping * 0.7
	pm.damping_max = spec.damping
	pm.scale_min = spec.scale_min
	pm.scale_max = spec.scale_max
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.angular_velocity_min = -spec.spin
	pm.angular_velocity_max = spec.spin
	pm.color = spec.color
	pm.color_ramp = _alpha_ramp(spec.fade_in, 0.55)
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, spec.scale_start))
	grow.add_point(Vector2(1.0, spec.scale_end))
	var grow_tex := CurveTexture.new()
	grow_tex.curve = grow
	pm.scale_curve = grow_tex
	if spec.streak:
		pm.particle_flag_align_y = true
	p.process_material = pm

	var quad := QuadMesh.new()
	quad.size = spec.quad
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _shard_texture() if spec.shard else _soft_dot_texture()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y if spec.streak else BaseMaterial3D.BILLBOARD_PARTICLES
	if spec.streak:
		mat.billboard_keep_scale = true
	if spec.hot:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	else:
		mat.roughness = spec.roughness
		if spec.shard:
			mat.metallic_specular = 0.9
			mat.emission_enabled = burst_kind == "ice"
			mat.emission = Color("6fcfff")
			mat.emission_energy_multiplier = 0.35
	quad.material = mat
	p.draw_pass_1 = quad

	var gravity: Vector3 = spec.gravity
	var life: float = spec.lifetime
	var gravity_drop := 0.5 * gravity.length() * life * life * 0.6
	var reach := minf(float(spec.vmax) * life + gravity_drop + float(spec.radius) + 0.6, 24.0)
	p.visibility_aabb = AABB(Vector3.ONE * -reach, Vector3.ONE * reach * 2.0)
	p.set_meta("burst_kind", burst_kind)
	p.add_to_group("dust_burst")
	parent.add_child(p)
	if parent.is_inside_tree():
		p.global_position = world_pos
	else:
		p.position = world_pos
	p.emitting = true

	var active := _live_nodes(parent, "_burst_fifo")
	while active.size() >= BURST_BUDGET:
		_retire_node(active.pop_front(), "", 0.0)
	active.append(p)
	_free_after(p, life * (1.0 + p.randomness) + 0.4)
	return p


static func _burst_spec(kind: String) -> Dictionary:
	var spec := {
		"amount": 48, "lifetime": 1.6, "radius": 0.35, "spread": 55.0, "vmin": 1.2, "vmax": 3.2,
		"gravity": Vector3(0, -1.2, 0), "damping": 2.6, "scale_min": 0.8, "scale_max": 1.6,
		"scale_start": 0.55, "scale_end": 1.6, "spin": 40.0, "color": Color(0.62, 0.58, 0.53, 0.55),
		"quad": Vector2(0.42, 0.42), "fade_in": 0.08, "roughness": 1.0,
		"hot": false, "shard": false, "streak": false,
	}
	match kind:
		"ash":
			spec.merge({"amount": 56, "lifetime": 2.4, "vmin": 0.6, "vmax": 1.8, "gravity": Vector3(0, -0.35, 0),
				"damping": 1.4, "color": Color(0.5, 0.48, 0.47, 0.6), "quad": Vector2(0.18, 0.18), "scale_end": 1.1}, true)
		"ice":
			spec.merge({"amount": 40, "lifetime": 1.25, "spread": 70.0, "vmin": 2.4, "vmax": 5.6, "gravity": Vector3(0, -9.8, 0),
				"damping": 0.4, "scale_min": 0.6, "scale_max": 1.3, "scale_start": 1.0, "scale_end": 0.6, "spin": 420.0,
				"color": Color(0.78, 0.94, 1.0, 0.9), "quad": Vector2(0.13, 0.16), "fade_in": 0.0, "roughness": 0.08, "shard": true}, true)
		"glass":
			spec.merge({"amount": 64, "lifetime": 1.4, "spread": 75.0, "vmin": 2.0, "vmax": 6.2, "gravity": Vector3(0, -9.8, 0),
				"damping": 0.3, "scale_min": 0.5, "scale_max": 1.4, "scale_start": 1.0, "scale_end": 0.8, "spin": 520.0,
				"color": Color(0.82, 0.74, 0.92, 0.75), "quad": Vector2(0.12, 0.15), "fade_in": 0.0, "roughness": 0.04, "shard": true}, true)
		"sparks":
			spec.merge({"amount": 64, "lifetime": 0.7, "radius": 0.08, "spread": 48.0, "vmin": 4.0, "vmax": 9.5,
				"gravity": Vector3(0, -9.8, 0), "damping": 1.0, "scale_min": 0.6, "scale_max": 1.2, "scale_start": 1.0,
				"scale_end": 0.2, "spin": 0.0, "color": Color(4.2, 2.2, 0.7, 1.0), "quad": Vector2(0.035, 0.22),
				"fade_in": 0.0, "hot": true, "streak": true}, true)
		"slag":
			spec.merge({"amount": 40, "lifetime": 1.3, "radius": 0.18, "spread": 42.0, "vmin": 2.6, "vmax": 6.0,
				"gravity": Vector3(0, -9.8, 0), "damping": 0.6, "scale_min": 0.7, "scale_max": 1.5, "scale_start": 1.0,
				"scale_end": 0.45, "spin": 0.0, "color": Color(3.4, 1.15, 0.25, 1.0), "quad": Vector2(0.09, 0.16),
				"fade_in": 0.0, "hot": true, "streak": true}, true)
		"blood":
			spec.merge({"amount": 44, "lifetime": 0.95, "radius": 0.12, "spread": 38.0, "vmin": 2.2, "vmax": 5.2,
				"gravity": Vector3(0, -9.8, 0), "damping": 0.8, "scale_min": 0.6, "scale_max": 1.4, "scale_start": 1.0,
				"scale_end": 0.7, "spin": 0.0, "color": Color(0.36, 0.03, 0.02, 0.95), "quad": Vector2(0.1, 0.1),
				"fade_in": 0.0, "roughness": 0.25}, true)
	return spec


static func _alpha_ramp(fade_in: float, hold_until: float) -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0.0 if fade_in > 0.0 else 1.0))
	gradient.set_color(1, Color(1, 1, 1, 0.0))
	if fade_in > 0.0:
		gradient.add_point(clampf(fade_in, 0.01, 0.4), Color(1, 1, 1, 1))
	gradient.add_point(clampf(hold_until, 0.45, 0.95), Color(1, 1, 1, 0.8))
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	texture.width = 64
	return texture


static func _parent_dir(parent: Node3D, world_dir: Vector3) -> Vector3:
	var local := parent.global_basis.inverse() * world_dir if parent.is_inside_tree() else world_dir
	return local.normalized() if local.length_squared() > 0.000001 else Vector3.UP


static func _parent_point(parent: Node3D, world_pos: Vector3) -> Vector3:
	return parent.to_local(world_pos) if parent.is_inside_tree() else world_pos


static func _soft_dot_texture() -> ImageTexture:
	if _soft_dot == null:
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for y in 32:
			for x in 32:
				var d := Vector2(float(x) - 15.5, float(y) - 15.5).length() / 15.5
				var a := clampf(1.0 - d, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a * a * (3.0 - 2.0 * a)))
		img.generate_mipmaps()
		_soft_dot = ImageTexture.create_from_image(img)
	return _soft_dot


static func _shard_texture() -> ImageTexture:
	const KEY := "_shard"
	if _splatter_cache.has(KEY):
		return _splatter_cache[KEY]
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var tri := PackedVector2Array([Vector2(15.0, 1.0), Vector2(30.0, 29.0), Vector2(3.0, 23.0)])
	for y in 32:
		for x in 32:
			var q := Vector2(float(x) + 0.5, float(y) + 0.5)
			var inside := Geometry2D.is_point_in_polygon(q, tri)
			var lum := 0.75 + 0.25 * float((x + y) % 7 == 0)
			img.set_pixel(x, y, Color(lum, lum, lum, 1.0 if inside else 0.0))
	img.generate_mipmaps()
	var texture := ImageTexture.create_from_image(img)
	_splatter_cache[KEY] = texture
	return texture


# ---------------------------------------------------------------------------
# Soul-light glyph VFX (E10 hollowing motes, E11 name stream and glyph drift)
# ---------------------------------------------------------------------------

# Pale-violet glyph motes rise from an actor's head (origin, world space) and drift toward
# target_dir (world direction toward the Keep or the Gate). Emits for duration seconds.
static func spawn_hollowing_motes(parent: Node3D, origin: Vector3, target_dir: Vector3, duration: float = 2.8) -> GPUParticles3D:
	if not is_instance_valid(parent):
		return null
	var heading := Vector3(target_dir.x, 0.0, target_dir.z)
	heading = heading.normalized() if heading.length_squared() > 0.000001 else Vector3.FORWARD
	var local_heading := _parent_dir(parent, heading)
	var p := _glyph_emitter("hollowing_motes", 44, 2.1, Color("c9a8ff"), 0.07, 0.13)
	var pm := p.process_material as ParticleProcessMaterial
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.2
	pm.direction = (Vector3.UP * 1.4 + local_heading).normalized()
	pm.spread = 24.0
	pm.initial_velocity_min = 0.45
	pm.initial_velocity_max = 0.95
	pm.gravity = local_heading * 0.85 + Vector3.UP * 0.16
	pm.damping_min = 0.1
	pm.damping_max = 0.3
	pm.turbulence_noise_strength = 0.7
	pm.turbulence_noise_scale = 1.6
	pm.turbulence_influence_min = 0.06
	pm.turbulence_influence_max = 0.16
	var reach := 1.0 * 2.1 + 0.5 * 0.9 * 2.1 * 2.1 + 1.0
	p.visibility_aabb = AABB(Vector3(-reach, -0.5, -reach), Vector3(reach * 2.0, reach + 0.5, reach * 2.0))
	p.set_meta("target_dir", heading)
	_glyph_light(p, Color("b48cff"), 0.75, 2.6, duration)
	_launch_timed_emitter(parent, p, _parent_point(parent, origin), duration)
	return p


# Luminous curved threads of soul-light plus moving wisps flowing along a gentle arc from
# from_pos to to_pos (world space). Grows toward the target, holds, then drains into it.
static func spawn_name_stream(parent: Node3D, from_pos: Vector3, to_pos: Vector3, duration: float = 2.4, color: Color = Color("d8c8ff")) -> Node3D:
	if not is_instance_valid(parent):
		return null
	var a := _parent_point(parent, from_pos)
	var b := _parent_point(parent, to_pos)
	var chord := b - a
	var length := chord.length()
	var holder := Node3D.new()
	holder.name = "name_stream"
	holder.add_to_group("name_stream")
	parent.add_child(holder)
	if length < 0.01:
		holder.queue_free()
		return holder
	var dir := chord / length
	var side := dir.cross(Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT).normalized()
	var lift := side.cross(dir).normalized()
	if lift.y < 0.0:
		lift = -lift
	var control := (a + b) * 0.5 + lift * (length * 0.22 + 0.35)
	var curve := func(u: float) -> Vector3:
		var inv := 1.0 - u
		return a * inv * inv + control * 2.0 * inv * u + b * u * u

	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	const THREADS := 3
	const POINTS := 32
	var width := clampf(length * 0.012, 0.025, 0.07)
	for thread in THREADS:
		var points := PackedVector3Array()
		var radius := 0.06 + 0.05 * float(thread)
		var turn_phase := TAU * float(thread) / float(THREADS)
		for i in POINTS + 1:
			var u := float(i) / float(POINTS)
			var swirl := (side * cos(u * TAU * 1.5 + turn_phase) + lift * sin(u * TAU * 1.5 + turn_phase)) * radius * sin(u * PI)
			points.append(curve.call(u) + swirl)
		_arc_ribbon(mesh, points, side, width, 0.2)
		_arc_ribbon(mesh, points, lift, width, 0.2)
	mesh.surface_end()
	var threads := MeshInstance3D.new()
	threads.name = "threads"
	threads.mesh = mesh
	threads.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var thread_mat := ShaderMaterial.new()
	thread_mat.shader = _name_stream_shader()
	thread_mat.set_shader_parameter("thread_color", color)
	thread_mat.set_shader_parameter("reveal", 0.0)
	thread_mat.set_shader_parameter("tail", 0.0)
	thread_mat.set_shader_parameter("intensity", 0.0)
	threads.material_override = thread_mat
	holder.add_child(threads)

	var wisp_mat := StandardMaterial3D.new()
	wisp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wisp_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wisp_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	wisp_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	wisp_mat.albedo_texture = _soft_dot_texture()
	wisp_mat.albedo_color = Color(minf(color.r * 2.2, 4.0), minf(color.g * 2.2, 4.0), minf(color.b * 2.2, 4.0), 0.0)
	var wisp_quad := QuadMesh.new()
	wisp_quad.size = Vector2(0.22, 0.22)
	var wisps: Array[MeshInstance3D] = []
	for i in 7:
		var wisp := MeshInstance3D.new()
		wisp.name = "wisp_%d" % i
		wisp.mesh = wisp_quad
		wisp.material_override = wisp_mat
		wisp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wisp.position = a
		holder.add_child(wisp)
		wisps.append(wisp)
	var glow := OmniLight3D.new()
	glow.name = "stream_light"
	glow.light_color = color
	glow.light_energy = 0.0
	glow.omni_range = 3.6
	glow.position = a
	holder.add_child(glow)
	holder.set_meta("from", a)
	holder.set_meta("to", b)
	holder.set_meta("duration", duration)

	var span := maxf(duration, 0.2)
	var update := func(elapsed: float) -> void:
		var k := elapsed / span
		var reveal := clampf(k / 0.35, 0.0, 1.0)
		var tail := clampf((k - 0.7) / 0.3, 0.0, 1.0)
		var intensity := clampf(elapsed / 0.2, 0.0, 1.0) * (1.0 - smoothstep(0.92, 1.0, k))
		thread_mat.set_shader_parameter("reveal", reveal * 1.08)
		thread_mat.set_shader_parameter("tail", tail)
		thread_mat.set_shader_parameter("intensity", intensity)
		wisp_mat.albedo_color.a = intensity
		for i in wisps.size():
			var u := fposmod(elapsed * 0.62 + float(i) / float(wisps.size()), 1.0)
			var visible_span := clampf(u, tail, reveal)
			var wisp := wisps[i]
			wisp.position = curve.call(visible_span)
			var size := sin(clampf((visible_span - tail) / maxf(reveal - tail, 0.001), 0.0, 1.0) * PI)
			wisp.scale = Vector3.ONE * maxf(size * (0.7 + 0.3 * sin(elapsed * 9.0 + float(i))), 0.001)
		glow.position = curve.call(clampf(reveal * 0.9, tail, 1.0))
		glow.light_energy = 1.3 * intensity
	var start := func() -> void:
		var tween := holder.create_tween()
		tween.tween_method(update, 0.0, span, span)
		tween.tween_callback(holder.queue_free)
	if holder.is_inside_tree():
		start.call()
	else:
		holder.tree_entered.connect(start, CONNECT_ONE_SHOT)
	return holder


# Swirling pale luminous ash/letter specks peeling off a surface (The Ladle, slag dam).
static func spawn_glyph_drift(parent: Node3D, origin: Vector3, count: int = 16, duration: float = 2.6, color: Color = Color("e5dcff")) -> GPUParticles3D:
	if not is_instance_valid(parent):
		return null
	var p := _glyph_emitter("glyph_drift", clampi(count, 4, 160), 2.2, color, 0.06, 0.12)
	var pm := p.process_material as ParticleProcessMaterial
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.55
	pm.direction = Vector3.UP
	pm.spread = 60.0
	pm.initial_velocity_min = 0.25
	pm.initial_velocity_max = 0.7
	pm.gravity = Vector3.UP * 0.22
	pm.damping_min = 0.2
	pm.damping_max = 0.5
	pm.turbulence_noise_strength = 2.4
	pm.turbulence_noise_scale = 1.3
	pm.turbulence_noise_speed = Vector3(0.3, 0.6, 0.3)
	pm.turbulence_influence_min = 0.25
	pm.turbulence_influence_max = 0.45
	p.visibility_aabb = AABB(Vector3(-3.0, -1.0, -3.0), Vector3(6.0, 5.0, 6.0))
	_glyph_light(p, color, 0.55, 2.4, duration)
	_launch_timed_emitter(parent, p, _parent_point(parent, origin), duration)
	return p


static func _glyph_emitter(node_name: String, amount: int, lifetime: float, color: Color, scale_min: float, scale_max: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = node_name
	p.amount = amount
	p.lifetime = lifetime
	p.randomness = 0.3
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.turbulence_enabled = true
	pm.scale_min = 1.0
	pm.scale_max = scale_max / maxf(scale_min, 0.001)
	pm.angle_min = -25.0
	pm.angle_max = 25.0
	pm.anim_offset_min = 0.0
	pm.anim_offset_max = 1.0
	pm.anim_speed_min = 0.0
	pm.anim_speed_max = 0.0
	pm.color = Color(color.r * 2.2, color.g * 2.2, color.b * 2.2, 1.0)
	pm.color_ramp = _alpha_ramp(0.15, 0.7)
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * scale_min
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _glyph_texture()
	mat.particles_anim_h_frames = 4
	mat.particles_anim_v_frames = 4
	mat.particles_anim_loop = false
	quad.material = mat
	p.draw_pass_1 = quad
	p.add_to_group("glyph_vfx")
	return p


static func _glyph_light(p: GPUParticles3D, color: Color, energy: float, reach: float, duration: float) -> void:
	var light := OmniLight3D.new()
	light.name = "glyph_light"
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	light.position = Vector3.UP * 0.4
	p.add_child(light)
	var fade := func() -> void:
		var tween := light.create_tween()
		tween.tween_interval(maxf(duration, 0.0))
		tween.tween_property(light, "light_energy", 0.0, 0.6)
	light.tree_entered.connect(fade, CONNECT_ONE_SHOT)


# Emits for duration seconds, then stops and frees after the last particle expires.
static func _launch_timed_emitter(parent: Node3D, p: GPUParticles3D, local_pos: Vector3, duration: float) -> void:
	p.position = local_pos
	p.one_shot = false
	p.emitting = true
	var run := func() -> void:
		var tween := p.create_tween()
		tween.tween_interval(maxf(duration, 0.05))
		tween.tween_callback(func() -> void: p.emitting = false)
		tween.tween_interval(p.lifetime * (1.0 + p.randomness) + 0.4)
		tween.tween_callback(p.queue_free)
	p.tree_entered.connect(run, CONNECT_ONE_SHOT)
	parent.add_child(p)


static func _glyph_texture() -> ImageTexture:
	if _glyph_atlas != null:
		return _glyph_atlas
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7741
	for cell in 16:
		var origin := Vector2i((cell % 4) * 16, (cell / 4) * 16)
		var stem_x := rng.randf_range(6.5, 9.5)
		var segments: Array[PackedVector2Array] = [PackedVector2Array([Vector2(stem_x, 2.5), Vector2(stem_x, 13.5)])]
		for branch in rng.randi_range(1, 3):
			var y0 := rng.randf_range(3.0, 12.5)
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			segments.append(PackedVector2Array([Vector2(stem_x, y0), Vector2(stem_x + side * rng.randf_range(3.0, 5.5), y0 + rng.randf_range(-3.5, 3.5))]))
		for py in 16:
			for px in 16:
				var q := Vector2(float(px) + 0.5, float(py) + 0.5)
				var d := INF
				for seg in segments:
					d = minf(d, Geometry2D.get_closest_point_to_segment(q, seg[0], seg[1]).distance_to(q))
				var a := clampf(1.3 - d, 0.0, 1.0) + exp(-d * d / 5.0) * 0.35
				img.set_pixel(origin.x + px, origin.y + py, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	img.generate_mipmaps()
	_glyph_atlas = ImageTexture.create_from_image(img)
	return _glyph_atlas


static func _name_stream_shader() -> Shader:
	if _stream_shader == null:
		_stream_shader = Shader.new()
		_stream_shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 thread_color : source_color = vec4(0.85, 0.78, 1.0, 1.0);
uniform float intensity = 0.0;
uniform float reveal = 1.0;
uniform float tail = 0.0;
uniform float flow_speed = 1.6;

void fragment() {
	float along = UV.y;
	float across = abs(UV.x - 0.5) * 2.0;
	float core = exp(-across * across * 6.0);
	float pulses = 0.4 + 0.6 * pow(0.5 + 0.5 * sin(along * 22.0 - TIME * flow_speed * 6.0), 3.0);
	float head = 1.0 - smoothstep(reveal - 0.08, reveal, along);
	float tail_mask = smoothstep(tail, tail + 0.1, along);
	float a = clamp(core * pulses * head * tail_mask * intensity, 0.0, 1.0);
	ALBEDO = thread_color.rgb * 2.6;
	ALPHA = a;
}
"""
	return _stream_shader
