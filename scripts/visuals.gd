class_name Visuals
extends RefCounted

const GODRAY_SHADER := preload("res://shaders/godray.gdshader")
const LIGHTNING_SHADER := preload("res://shaders/lightning.gdshader")

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
