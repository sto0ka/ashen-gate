class_name Visuals
extends RefCounted

static var _blood_tex: ImageTexture
static var _scorch_tex: ImageTexture
static var _frost_tex: ImageTexture

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

# Configure Forward+ Vulkan rendering: Volumetric Fog, SSAO, SSIL, SSR, ACES Filmic, Bloom, Dusk Sky!
static func configure_environment(env: Environment, stage: int) -> void:
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	if stage == 0:
		sky_mat.sky_top_color = Color("0a1120")
		sky_mat.sky_horizon_color = Color("2b364c")
		sky_mat.ground_bottom_color = Color("080b10")
		sky_mat.ground_horizon_color = Color("1d2633")
		env.fog_light_color = Color("2e3c4e")
		env.fog_density = 0.012
		env.volumetric_fog_albedo = Color("4f6480")
		env.volumetric_fog_density = 0.017
		env.ambient_light_color = Color("7b92b8")
		env.ambient_light_energy = 0.60
	elif stage == 1:
		sky_mat.sky_top_color = Color("110a24")
		sky_mat.sky_horizon_color = Color("3e2859")
		sky_mat.ground_bottom_color = Color("090612")
		sky_mat.ground_horizon_color = Color("241738")
		env.fog_light_color = Color("382854")
		env.fog_density = 0.011
		env.volumetric_fog_albedo = Color("664c88")
		env.volumetric_fog_density = 0.016
		env.ambient_light_color = Color("8c7bb0")
		env.ambient_light_energy = 0.58
	else:
		sky_mat.sky_top_color = Color("1a0b0a")
		sky_mat.sky_horizon_color = Color("522316")
		sky_mat.ground_bottom_color = Color("100605")
		sky_mat.ground_horizon_color = Color("381810")
		env.fog_light_color = Color("46251c")
		env.fog_density = 0.012
		env.volumetric_fog_albedo = Color("78402e")
		env.volumetric_fog_density = 0.018
		env.ambient_light_color = Color("a07768")
		env.ambient_light_energy = 0.60
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
	env.ssao_intensity = 2.2
	env.ssao_power = 1.4
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
	env.glow_bloom = 0.24
	env.glow_hdr_threshold = 0.85
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.12
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
