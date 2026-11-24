extends Node3D

const ElementalComponent = preload("res://scripts/elemental.gd")
const LevelBuilder = preload("res://scripts/level_builder.gd")
const Visuals = preload("res://scripts/visuals.gd")
const NarrativeSystem = preload("res://scripts/narrative.gd")

const GRAVITY := 18.0
const SAVE_PATH := "user://ashen_gate_save.json"
const LAYER_WORLD := 1
const LAYER_ENEMY := 2
const LAYER_PUSHABLE := 4
const LAYER_TARGET := 8
const LAYER_DEBRIS := 16
const LAYER_PLAYER := 32

var rng := RandomNumberGenerator.new()
var player: CharacterBody3D
var head: Node3D
var camera: Camera3D
var repulse_cast: ShapeCast3D
var weapon_sprite: TextureRect
var rune_glow_rect: ColorRect
var vignette_rect: ColorRect

var swing_time := 0.0
var swing_contact_done := false
var arbalest_recoil := 0.0
var thurible_time := 0.0
var thurible_release_done := false
var heal_anim_time := 0.0
var hitstop_time := 0.0
var parry_window := 0.0

var level_root: Node3D
var stage := 0
var level_states := {
	0: {"dead": [], "taken": [], "broken": [], "gate_open": false, "has_lever": false, "lever_inserted": false, "cage_dropped": false, "shortcut_open": false, "ambush_done": false},
	1: {"dead": [], "taken": [], "broken": [], "wards": [], "gear_frozen": false, "boss_dead": false, "boss_hp": 520},
	2: {"dead": [], "taken": [], "broken": [], "trough_flooded": false, "dam_broken": false, "key_forged": false, "gauntlet_triggered": false, "dropped_cauldrons": [], "great_gate_open": false}
}

# Player progression & resources
var has_arbalest := false
var has_thurible := false
var has_ashen_key := false
var hp := 100
var max_hp := 100
var mana := 75
var max_mana := 100
var green_mana := 45
var damage_mult := 1.0
var mana_regen_rate := 0.0
var mana_regen_acc := 0.0
var flasks := 2
var dash_cooldown := 0.0
var dash_time := 0.0
var dash_dir := Vector3.ZERO
var held_body: RigidBody3D
var held_was_hurled: Dictionary = {}
var narrative: NarrativeSystem
var seen_echoes: Dictionary = {}
var mode := 0
var cooldown := 0.0
var flash := 0.0
var flash_color := Color(0.75, 0.1, 0.05)
var message_time := 0.0
var elapsed := 0.0
var pitch := 0.0
var gate_open := false
var won := false

# Level interactive references
var gate: StaticBody3D
var switch_node: Node3D
var shortcut_door: StaticBody3D
var pressure_plates: Array[Dictionary] = []
var water_channels: Array[Dictionary] = []
var pushable_blocks: Array[RigidBody3D] = []
var shootable_targets: Array[Node3D] = []
var fonts: Array[Node3D] = []
var portal_nodes: Array[Dictionary] = []
var inscriptions: Array[Dictionary] = []
var breakables: Array[RigidBody3D] = []
var wards: Array[StaticBody3D] = []
var ward_beams: Array[MeshInstance3D] = []
var boss: CharacterBody3D
var boss_phase := 0
var active_shockwaves: Array[Dictionary] = []

# Level 2 specific puzzle refs
var tower_gear: Node3D
var tower_cracked_wall: StaticBody3D
var tower_pendulum: RigidBody3D
var belfry_floorboards: StaticBody3D
var ward3_shutter: StaticBody3D
var bell_sequence_step := 0

# Level 3 specific puzzle refs
var water_spouts: Array[StaticBody3D] = []
var aqueduct_valve: Node3D
var ore_cart: RigidBody3D
var slag_dam: StaticBody3D
var trough_water: Node3D
var key_mold: Node3D
var hoist_lever: Node3D
var great_gate_left: StaticBody3D
var great_gate_right: StaticBody3D
var slag_zones: Array[Dictionary] = []

# Ambush & lighting
var torches: Array[OmniLight3D] = []
var crypt_torches: Array[OmniLight3D] = []
var ambush_dark_timer := 0.0
var ambush_pending := false

# Movement & feel
var hazard_timer := 0.0
var camera_shake := 0.0
var jump_buffer := 0.0
var coyote_time := 0.0
var footstep_time := 0.0
var landing_dip := 0.0
var view_kick := 0.0
var hurt_cooldown := 0.0
var hitmarker_time := 0.0
var weapon_sway := Vector2.ZERO
var equip_offset := 0.0
var hud_bars := {}
var stone_physics_mat: PhysicsMaterial

# Active entities
var particles: Array[Dictionary] = []
var enemies: Array[CharacterBody3D] = []
var pickups: Array[Dictionary] = []
var bolts: Array[Dictionary] = []
var enemy_bolts: Array[Dictionary] = []

# Resources & UI
var sounds := {}
var mats := {}
var labels := {}
var veil: ColorRect
var ending_panel: ColorRect
var map_overlay: Control
var journal_panel: ColorRect
var story_flags: Array[String] = []
var journal_entries: Array[Dictionary] = []
var journal_index := 0
var triggered_volumes: Dictionary = {}
var world_env: Environment
var portal_material: ShaderMaterial
var title_font: FontFile
var spell_glow_texture: ImageTexture
var tex_arbalest: ImageTexture
var tex_thurible: ImageTexture

func _ready() -> void:
	rng.seed = 91475
	title_font = load("res://fonts/Cinzel.ttf")
	_setup_materials()
	spell_glow_texture = _make_glow_texture()
	tex_arbalest = _make_arbalest_texture()
	tex_thurible = _make_thurible_texture()
	_setup_world()
	level_root = Node3D.new()
	add_child(level_root)
	_build_player()
	_build_hud()
	_setup_audio()
	LevelBuilder.build_sunken_court(self)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_objective()
	narrative.show_chapter("CHAPTER I", "THE SUNKEN COURT", "Kingdom of Vaelor — Forty Nights After the Fracture")
	narrative.say("SERAPHINA (RESONANT STONE)", "You made it through the outer seal. The Gate is pulling the living inside—find the Briar Arbalest in the West Cistern and the Iron Lever in the East Catacombs.", 6.0, Color("70d7df"))
	_story_event(
		"arrival",
		"THE SUNKEN COURT",
		"The courtyard sank when the cistern beneath it collapsed. The portal to the Bell Tower hums behind a warded arch, starved of its mechanical lock. Look for the gatehouse lever—and mind the rusted knights still patrolling the cloister.",
		""
	)

func _material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.88
	if glow:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 2.4
	return m

func _setup_materials() -> void:
	stone_physics_mat = PhysicsMaterial.new()
	stone_physics_mat.friction = 0.55
	stone_physics_mat.bounce = 0.14
	var stone_tex: Texture2D = load("res://art/cathedral_stone.png")
	var floor_tex: Texture2D = load("res://art/courtyard_floor.png")
	var stone_nrm := Visuals.make_normal_map(stone_tex, 2.6)
	var floor_nrm := Visuals.make_normal_map(floor_tex, 2.4)
	var timber_tex := Visuals.make_timber_texture(rng)
	var timber_nrm := Visuals.make_normal_map(timber_tex, 2.8)
	var iron_tex := Visuals.make_metal_texture(Color("343d45"), rng)
	var iron_nrm := Visuals.make_normal_map(iron_tex, 2.2)
	var brass_tex := Visuals.make_metal_texture(Color("be8e52"), rng)
	var brass_nrm := Visuals.make_normal_map(brass_tex, 2.0)

	mats.stone = _material(Color("b6bbb8"))
	mats.dark = _material(Color("616f70"))
	mats.floor = _material(Color("7d8680"))
	mats.moss = _material(Color("284236"))
	mats.iron = _material(Color("9aa5ae"))
	mats.brass = _material(Color("e2b97e"))
	mats.copper = _material(Color("4c9480"))
	mats.timber = _material(Color("c9b39d"))
	mats.basalt = _material(Color("41393d"))
	mats.ember = _material(Color("ff9244"), true)
	mats.mana = _material(Color("39d4e8"), true)
	mats.portal = _material(Color("a952d6"), true)
	mats.blood = _material(Color("9e3d32"))
	mats.acid = _material(Color("42a868"), true)
	mats.ice = _material(Color("9ef3ff"), true)
	mats.cinder = _material(Color("f55e28"), true)

	# PBR metallic/roughness & Sobel normal relief with world-space triplanar mapping
	for key in ["stone", "dark", "basalt"]:
		mats[key].albedo_texture = stone_tex
		mats[key].normal_enabled = true
		mats[key].normal_texture = stone_nrm
		mats[key].normal_scale = 1.45
		mats[key].roughness = 0.84
		mats[key].uv1_triplanar = true
		mats[key].uv1_scale = Vector3(0.32, 0.32, 0.32)
		mats[key].texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	mats.floor.albedo_texture = floor_tex
	mats.floor.normal_enabled = true
	mats.floor.normal_texture = floor_nrm
	mats.floor.normal_scale = 1.35
	mats.floor.roughness = 0.78
	mats.floor.uv1_triplanar = true
	mats.floor.uv1_scale = Vector3(0.30, 0.30, 0.30)
	mats.floor.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS

	mats.timber.albedo_texture = timber_tex
	mats.timber.normal_enabled = true
	mats.timber.normal_texture = timber_nrm
	mats.timber.normal_scale = 1.5
	mats.timber.roughness = 0.82
	mats.timber.uv1_triplanar = true
	mats.timber.uv1_scale = Vector3(0.45, 0.45, 0.45)

	mats.iron.albedo_texture = iron_tex
	mats.iron.normal_enabled = true
	mats.iron.normal_texture = iron_nrm
	mats.iron.metallic = 0.82
	mats.iron.roughness = 0.36
	mats.iron.uv1_triplanar = true
	mats.iron.uv1_scale = Vector3(0.5, 0.5, 0.5)
	mats.brass.albedo_texture = brass_tex
	mats.brass.normal_enabled = true
	mats.brass.normal_texture = brass_nrm
	mats.brass.metallic = 0.86
	mats.brass.roughness = 0.30
	mats.brass.uv1_triplanar = true
	mats.brass.uv1_scale = Vector3(0.5, 0.5, 0.5)
	mats.copper.albedo_texture = iron_tex
	mats.copper.normal_enabled = true
	mats.copper.normal_texture = iron_nrm
	mats.copper.metallic = 0.74
	mats.copper.roughness = 0.42
	mats.copper.uv1_triplanar = true
	mats.copper.uv1_scale = Vector3(0.5, 0.5, 0.5)
	mats.clay = _material(Color("876246"))
	mats.clay.albedo_texture = stone_tex
	mats.clay.normal_enabled = true
	mats.clay.normal_texture = stone_nrm
	mats.clay.uv1_triplanar = true
	mats.clay.uv1_scale = Vector3(0.4, 0.4, 0.4)
	mats.ice.roughness = 0.08
	mats.ice.metallic = 0.16
	mats.ice.rim_enabled = true
	mats.ice.rim = 0.7
	mats.ice.emission_energy_multiplier = 1.6

	# Animated custom shaders for water, boiling molten slag, and flickering torch flames
	var water_mat := ShaderMaterial.new()
	water_mat.shader = load("res://shaders/water.gdshader")
	mats.water = water_mat
	var slag_mat := ShaderMaterial.new()
	slag_mat.shader = load("res://shaders/slag.gdshader")
	mats.slag = slag_mat
	var flame_mat := ShaderMaterial.new()
	flame_mat.shader = load("res://shaders/torch_flame.gdshader")
	mats.flame = flame_mat

	mats.warning = _material(Color(1.0, 0.27, 0.12, 0.34), true)
	mats.warning.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mats.warning.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mats.ash = _material(Color("8b8980"))
	mats.acid.emission_energy_multiplier = 1.2
	mats.portal.emission_energy_multiplier = 1.4
	portal_material = ShaderMaterial.new()
	portal_material.shader = load("res://shaders/portal.gdshader")

func _make_glow_texture() -> ImageTexture:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var radius := Vector2(float(x) - 15.5, float(y) - 15.5).length() / 15.5
			var alpha := pow(clampf(1.0 - radius, 0.0, 1.0), 1.8)
			image.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(image)

func _make_arbalest_texture() -> ImageTexture:
	var img := Image.create(64, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var wood := Color("4f3626")
	var wood_hi := Color("73513a")
	var iron := Color("49545c")
	var glow := Color("5be38c")
	# Central stock
	for y in range(18, 48):
		for x in range(28, 36):
			img.set_pixel(x, y, wood_hi if x == 30 or x == 31 else wood)
	# Bow prod (curved arms)
	for x in range(8, 56):
		var dy := int(absf(float(x) - 32.0) * 0.35)
		for t in range(4):
			var py := 16 + dy + t
			if py >= 0 and py < 48:
				img.set_pixel(x, py, iron)
	# Glowing spectral-iron bolt in the groove
	for y in range(4, 34):
		img.set_pixel(31, y, glow)
		img.set_pixel(32, y, glow)
	for x in range(29, 35):
		img.set_pixel(x, 8, glow)
	return ImageTexture.create_from_image(img)

func _make_thurible_texture() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var brass := Color("c2924c")
	var brass_dk := Color("6e4d23")
	var ember := Color("ff7828")
	var gold := Color("ffe085")
	# Chain links from top-right
	for y in range(6, 26):
		if y % 3 != 0:
			img.set_pixel(31, y, brass_dk)
			img.set_pixel(32, y, brass)
	# Censer bowl
	for y in range(26, 54):
		var dy := float(y - 40) / 14.0
		var half_w := int(sqrt(maxf(0.0, 1.0 - dy * dy)) * 16.0)
		for x in range(32 - half_w, 32 + half_w):
			var is_slit: bool = (y >= 34 and y <= 44) and (absi(x - 32) % 5 <= 1)
			img.set_pixel(x, y, gold if is_slit and y % 2 == 0 else ember if is_slit else brass if x < 34 else brass_dk)
	return ImageTexture.create_from_image(img)

func _setup_world() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	Visuals.configure_environment(env, 0)
	world_env = env
	world.environment = env
	add_child(world)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-48, -32, 0)
	moon.light_color = Color("9ab0d4")
	moon.light_energy = 0.72
	moon.shadow_enabled = true
	moon.shadow_blur = 2.0
	add_child(moon)

# --- Shared builders called by LevelBuilder ---
func _portal(pos: Vector3, destination: String, label: String) -> void:
	var holder := Node3D.new()
	holder.position = pos
	level_root.add_child(holder)
	for angle in [0.0, PI * 0.5]:
		var surface := MeshInstance3D.new()
		var plane := QuadMesh.new()
		plane.size = Vector2(2.8, 3.6)
		surface.mesh = plane
		surface.material_override = portal_material
		surface.position.y = 1.95
		surface.rotation.y = angle
		holder.add_child(surface)
	for x in [-1.55, 1.55]:
		LevelBuilder.box(holder, "portal_jamb", Vector3(x, 1.9, 0), Vector3(0.45, 3.8, 0.65), mats.dark, false)
	LevelBuilder.box(holder, "portal_crown", Vector3(0, 3.9, 0), Vector3(3.5, 0.42, 0.75), mats.brass, false)
	LevelBuilder.cylinder(holder, "portal_plinth", Vector3(0, 0.18, 0), 1.65, 0.35, mats.brass, false, 12)
	_light(pos + Vector3(0, 2, 0), Color("aa4dc9"), 2.6, 6.0)
	portal_nodes.append({"node": holder, "destination": destination, "label": label})

func _ward(pos: Vector3, ward_id: String) -> void:
	if level_states[stage].wards.has(ward_id):
		return
	var ward := LevelBuilder.box(level_root, "warding_crystal_" + ward_id, pos + Vector3(0, 1.25, 0), Vector3(0.8, 1.45, 0.8), mats.portal, true, LAYER_TARGET) as StaticBody3D
	LevelBuilder.cylinder(ward, "ward_crown", Vector3(0, 0.85, 0), 0.54, 0.18, mats.brass, false, 8)
	LevelBuilder.cylinder(level_root, "ward_plinth", pos + Vector3(0, 0.35, 0), 0.85, 0.7, mats.dark, true, 8)
	_light(pos + Vector3(0, 1.6, 0), Color("b75bd7"), 1.9, 5.0)
	ward.set_meta("ward", true)
	ward.set_meta("id", ward_id)
	wards.append(ward)

func _shatter_ward(ward: StaticBody3D) -> void:
	if not is_instance_valid(ward) or not wards.has(ward):
		return
	level_states[stage].wards.append(ward.get_meta("id"))
	wards.erase(ward)
	ward.collision_layer = 0
	_sound("frost")
	_spell_impact(ward.global_position, Color("c46df5"))
	var tween := create_tween().bind_node(ward)
	tween.tween_property(ward, "position:y", ward.position.y - 2.0, 0.28)
	tween.tween_callback(ward.queue_free)
	_objective()
	_message("RESONANT WARD SHATTERED  •  %d REMAIN" % wards.size(), 2.4)
	if wards.is_empty():
		_sound("bell")
		_message("ALL WARDS SILENCED  •  THE BELL WARDEN IS VULNERABLE!", 3.5)

func _rune_circle(center: Vector3, radius: float) -> void:
	for i in 24:
		var a := float(i) / 24.0 * TAU
		var p := center + Vector3(cos(a) * radius, 0.07, sin(a) * radius)
		var rune := LevelBuilder.box(level_root, "ritual_rune", p, Vector3(1.05, 0.08, 0.16), mats.portal, false)
		rune.rotation.y = -a - PI * 0.5
		if i % 3 == 0:
			LevelBuilder.cylinder(level_root, "warding_stone", p + Vector3(0, 0.34, 0), 0.28, 0.62, mats.brass, false, 6)

func _hanging_bell(pos: Vector3) -> void:
	var bell_sprite := Sprite3D.new()
	bell_sprite.name = "cracked_bell"
	bell_sprite.texture = load("res://art/bell_prop.png")
	bell_sprite.pixel_size = 0.014
	bell_sprite.position = pos
	bell_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bell_sprite.shaded = true
	level_root.add_child(bell_sprite)

func _stained_glass(pos: Vector3, left: bool) -> void:
	var window := Sprite3D.new()
	window.name = "bell_stained_glass"
	window.texture = load("res://art/bell_window.png")
	window.pixel_size = 0.009
	window.position = pos
	window.rotation.y = PI * 0.5 if left else -PI * 0.5
	window.shaded = false
	level_root.add_child(window)

func _inscription(pos: Vector3, title: String, writing: String) -> void:
	var holder := Node3D.new()
	holder.position = pos
	level_root.add_child(holder)
	LevelBuilder.box(holder, "inscribed_stone", Vector3(0, 0.75, 0), Vector3(0.85, 1.5, 0.32), mats.dark, false)
	LevelBuilder.box(holder, "glowing_rune", Vector3(0, 1.0, -0.2), Vector3(0.32, 0.35, 0.04), mats.mana, false)
	inscriptions.append({"node": holder, "title": title, "writing": writing})

func _pot(pos: Vector3, pot_id: String, loot: String) -> void:
	if level_states[stage].broken.has(pot_id):
		return
	var pot := RigidBody3D.new()
	pot.name = "clay_urn"
	pot.position = pos + Vector3(0, 0.43, 0)
	pot.mass = 1.2
	pot.linear_damp = 1.8
	pot.angular_damp = 1.5
	pot.contact_monitor = true
	pot.max_contacts_reported = 4
	pot.collision_layer = LAYER_PUSHABLE
	pot.collision_mask = LAYER_WORLD | LAYER_ENEMY | LAYER_PUSHABLE | LAYER_PLAYER
	level_root.add_child(pot)
	var collider := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.36
	shape.height = 0.76
	collider.shape = shape
	pot.add_child(collider)
	var sprite := Sprite3D.new()
	sprite.texture = load("res://art/funerary_urn.png")
	sprite.pixel_size = 0.004
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = true
	pot.add_child(sprite)
	pot.set_meta("breakable", true)
	pot.set_meta("id", pot_id)
	pot.set_meta("loot", loot)
	breakables.append(pot)

func _debris_piece(pos: Vector3, size: Vector3, material: Material, impulse: Vector3) -> void:
	var piece := RigidBody3D.new()
	piece.name = "fallen_debris"
	piece.position = pos
	piece.mass = 0.15
	piece.linear_damp = 0.8
	piece.angular_damp = 1.0
	piece.collision_layer = LAYER_DEBRIS
	piece.collision_mask = LAYER_WORLD
	level_root.add_child(piece)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	piece.add_child(mesh_instance)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	piece.add_child(collider)
	piece.apply_central_impulse(impulse)
	piece.apply_torque_impulse(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)))
	var tween := create_tween().bind_node(piece)
	tween.tween_interval(3.0)
	tween.tween_callback(piece.queue_free)

func _smash_pot(pot: RigidBody3D) -> void:
	if not is_instance_valid(pot) or not breakables.has(pot):
		return
	if held_body == pot:
		held_body = null
	var pot_id: String = pot.get_meta("id")
	var loot: String = pot.get_meta("loot")
	var is_barricade: bool = pot.get_meta("barricade", false)
	var is_secret: bool = pot.get_meta("secret", false)
	var is_cask: bool = pot.get_meta("explosive_cask", false)
	level_states[stage].broken.append(pot_id)
	breakables.erase(pot)
	var pos := pot.global_position
	pot.collision_layer = 0
	pot.queue_free()
	if is_cask:
		_detonate_cask(pos)
		return
	_sound("hit")
	var mat: Material = mats.timber if is_barricade else mats.clay
	for i in 8:
		_debris_piece(pos + Vector3(rng.randf_range(-0.35, 0.35), rng.randf_range(0.2, 0.6), rng.randf_range(-0.35, 0.35)), Vector3(0.18, 0.14, 0.22), mat, Vector3(rng.randf_range(-3.2, 3.2), rng.randf_range(1.8, 4.2), rng.randf_range(-3.2, 3.2)))
	if loot != "none":
		_pickup(pos + Vector3(0, 0.35, 0), loot, "loot_" + pot_id)
	if is_secret:
		_sound("pickup")
		_message("SECRET CHAMBER UNCOVERED!", 2.8)
		narrative.say("SERAPHINA (RESONANT STONE)", "Well spotted! Hidden reliquaries from the First Order hold permanent Ashen Relics—claim it!", 4.2, Color("70d7df"))
	else:
		_message("BARRICADE SHATTERS" if is_barricade else "CLAY SHATTERS", 0.8)

func _detonate_cask(pos: Vector3) -> void:
	_sound("maul", 0.82)
	camera_shake = maxf(camera_shake, 0.36)
	_shockwave(pos + Vector3(0, 0.15, 0), Color("ff5c1a"), 5.8)
	_spell_impact(pos + Vector3(0, 0.4, 0), Color("ff7828"))
	Visuals.spawn_decal(level_root, pos, "scorch", 3.8)
	Visuals.spawn_impact_light(level_root, pos + Vector3(0, 0.8, 0), Color("ff6e24"), 6.0, 12.0, 0.42)
	for i in 10:
		_debris_piece(pos + Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(0.2, 0.8), rng.randf_range(-0.4, 0.4)), Vector3(0.2, 0.2, 0.2), mats.cinder, Vector3(rng.randf_range(-6, 6), rng.randf_range(3, 7), rng.randf_range(-6, 6)))
	for entry in enemies.duplicate():
		var e: CharacterBody3D = entry
		if is_instance_valid(e) and e.global_position.distance_to(pos) < 5.8:
			var elem: ElementalComponent = e.get_meta("elemental")
			var res := elem.apply_burn(5.0)
			_damage_enemy(e, int(110.0 * damage_mult))
			if res.thermal_shock and is_instance_valid(e) and enemies.has(e):
				_trigger_thermal_shock(e)
	# Chain-reaction detonation of nearby casks & urns!
	for other in breakables.duplicate():
		if is_instance_valid(other) and other.global_position.distance_to(pos) < 5.2:
			_smash_pot(other)
	_message("ALCHEMICAL CASK DETONATES!", 1.8)

func _scatter_particles(kind: String, count: int, area: Rect2) -> void:
	var center := Vector3(area.position.x + area.size.x * 0.5, 4.0, area.position.y + area.size.y * 0.5)
	var extents := Vector3(area.size.x * 0.5, 3.8, area.size.y * 0.5)
	Visuals.spawn_ambient_particles(level_root, kind, center, extents, count * 2)

func _light(pos: Vector3, color: Color, energy: float, reach: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	level_root.add_child(light)
	return light

func _torch(pos: Vector3, group_tag: String = "") -> void:
	LevelBuilder.cylinder(level_root, "torch_bracket", pos, 0.14, 0.75, mats.iron)
	LevelBuilder.cylinder(level_root, "torch_bowl", pos + Vector3(0, 0.38, 0), 0.32, 0.2, mats.brass)
	var flame_mesh := MeshInstance3D.new()
	flame_mesh.name = "torch_flame_shader"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.56, 0.85)
	flame_mesh.mesh = quad
	flame_mesh.material_override = mats.flame
	flame_mesh.position = pos + Vector3(0, 0.86, 0)
	level_root.add_child(flame_mesh)
	var l := _light(pos + Vector3(0, 0.92, 0), Color("ff9248"), 3.2, 10.5)
	torches.append(l)
	if group_tag == "east_crypt":
		crypt_torches.append(l)

func _build_gate() -> void:
	gate = StaticBody3D.new()
	gate.position = Vector3(0, 0, -19)
	gate.collision_layer = LAYER_WORLD
	gate.collision_mask = 0
	level_root.add_child(gate)
	for i in range(-4, 5):
		LevelBuilder.box(gate, "iron_bar", Vector3(i * 1.05, 2.25, 0), Vector3(0.18, 4.5, 0.28), mats.iron, false)
	for y in [0.65, 3.7]:
		LevelBuilder.box(gate, "gate_brace", Vector3(0, y, 0), Vector3(9.6, 0.28, 0.35), mats.brass, false)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(9.6, 4.7, 0.5)
	collider.shape = shape
	collider.position.y = 2.35
	gate.add_child(collider)
	if level_states[0].gate_open:
		gate.position.y = 5.2
		gate.collision_layer = 0
		gate_open = true
	elif level_states[0].get("lever_inserted", false):
		gate.position.y = 1.9

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.position = Vector3(0, 0.1, 30.0)
	player.floor_snap_length = 0.35
	player.collision_layer = LAYER_PLAYER
	player.collision_mask = LAYER_WORLD | LAYER_ENEMY | LAYER_PUSHABLE
	add_child(player)
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.8
	collider.shape = shape
	collider.position.y = 0.9
	player.add_child(collider)
	head = Node3D.new()
	head.position.y = 1.55
	player.add_child(head)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 82.0
	camera.far = 160.0
	head.add_child(camera)
	# Cone-like forward ShapeCast3D for Q REPULSE
	repulse_cast = ShapeCast3D.new()
	var rshape := BoxShape3D.new()
	rshape.size = Vector3(4.2, 2.8, 1.0)
	repulse_cast.shape = rshape
	repulse_cast.target_position = Vector3(0, 0, -6.5)
	repulse_cast.collision_mask = LAYER_ENEMY | LAYER_PUSHABLE | LAYER_DEBRIS
	repulse_cast.enabled = false
	camera.add_child(repulse_cast)

func _build_weapon() -> void:
	if not weapon_sprite:
		return
	equip_offset = 135.0
	if mode == 0:
		weapon_sprite.texture = load("res://art/battleaxe.png")
		weapon_sprite.position = Vector2(660, 105)
		weapon_sprite.size = Vector2(600, 600)
		weapon_sprite.pivot_offset = Vector2(540, 580)
	elif mode == 1:
		weapon_sprite.texture = tex_arbalest
		weapon_sprite.position = Vector2(690, 290)
		weapon_sprite.size = Vector2(460, 345)
		weapon_sprite.pivot_offset = Vector2(230, 300)
	else:
		weapon_sprite.texture = tex_thurible
		weapon_sprite.position = Vector2(680, 220)
		weapon_sprite.size = Vector2(440, 440)
		weapon_sprite.pivot_offset = Vector2(220, 40)
	weapon_sprite.rotation = 0

func _enemy(pos: Vector3, armored: bool, enemy_id: String, is_boss: bool = false, kind: String = "shrieker") -> void:
	if level_states[stage].dead.has(enemy_id):
		return
	var e := CharacterBody3D.new()
	e.position = pos
	e.floor_snap_length = 0.28
	e.collision_layer = LAYER_ENEMY
	e.collision_mask = LAYER_WORLD | LAYER_ENEMY | LAYER_PUSHABLE | LAYER_PLAYER
	var max_hp := 520 if is_boss else 160 if kind == "ash_sentinel" else 120 if kind == "executioner" else 75 if kind == "acolyte" else 60
	e.set_meta("hp", int(level_states[1].boss_hp) if is_boss else max_hp)
	e.set_meta("max_hp", max_hp)
	e.set_meta("attack", rng.randf_range(0.5, 1.4))
	e.set_meta("armored", armored or kind == "executioner" or kind == "ash_sentinel")
	e.set_meta("boss", is_boss)
	e.set_meta("kind", "warden" if is_boss else kind)
	e.set_meta("windup", 0.0)
	e.set_meta("pending", "")
	e.set_meta("guard", 0.0)
	e.set_meta("stagger", 0.0)
	e.set_meta("id", enemy_id)
	level_root.add_child(e)
	var elem := ElementalComponent.new()
	elem.name = "ElementalComponent"
	elem.frost_immune = (kind == "ash_sentinel")
	e.add_child(elem)
	e.set_meta("elemental", elem)
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 1.05 if is_boss else 0.62 if kind == "ash_sentinel" else 0.56 if kind == "executioner" else 0.43
	shape.height = 4.6 if is_boss else 2.5 if kind == "ash_sentinel" else 2.25 if kind == "executioner" else 2.0
	collider.shape = shape
	collider.position.y = shape.height * 0.5
	e.add_child(collider)
	var sprite := Sprite3D.new()
	sprite.name = "enemy_sprite"
	sprite.texture = load("res://art/bell_warden.png") if is_boss else load("res://art/sentinel.png") if (kind == "executioner" or kind == "ash_sentinel") else load("res://art/acolyte.png") if kind == "acolyte" else load("res://art/wretch.png")
	sprite.pixel_size = 0.013 if is_boss else 0.0092 if kind == "ash_sentinel" else 0.008 if kind == "executioner" else 0.0073 if kind == "acolyte" else 0.0068
	sprite.position.y = 2.8 if is_boss else 1.65 if kind == "ash_sentinel" else 1.45 if kind == "executioner" else 1.35
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = true
	if kind == "ash_sentinel":
		sprite.modulate = Color("c96f4b")
	e.add_child(sprite)
	var warning := LevelBuilder.cylinder(e, "attack_warning", Vector3(0, 0.06, 0), 1.8 if is_boss else 1.15 if kind == "acolyte" else 0.95, 0.04, mats.warning, false, 24)
	warning.visible = false
	e.set_meta("sprite", sprite)
	e.set_meta("warning", warning)
	enemies.append(e)
	if is_boss:
		boss = e

func _pickup(pos: Vector3, kind: String, item_id: String) -> void:
	if level_states[stage].taken.has(item_id):
		return
	var node := Node3D.new()
	node.position = pos
	level_root.add_child(node)
	if kind == "mana" or kind == "green":
		var crystal := MeshInstance3D.new()
		var gem := SphereMesh.new()
		gem.radius = 0.28
		gem.height = 0.64
		gem.radial_segments = 4
		gem.rings = 2
		crystal.mesh = gem
		crystal.rotation.z = 0.22
		crystal.material_override = mats.mana if kind == "mana" else mats.acid
		node.add_child(crystal)
		var aura := Sprite3D.new()
		aura.texture = spell_glow_texture
		aura.pixel_size = 0.026
		aura.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		aura.shaded = false
		aura.modulate = Color(0.35, 0.85, 0.95, 0.48) if kind == "mana" else Color(0.35, 0.95, 0.5, 0.48)
		node.add_child(aura)
	elif kind == "flask":
		LevelBuilder.cylinder(node, "healing_flask", Vector3.ZERO, 0.19, 0.44, mats.blood)
		LevelBuilder.cylinder(node, "flask_neck", Vector3(0, 0.26, 0), 0.1, 0.13, mats.brass)
	elif kind == "iron_lever":
		LevelBuilder.cylinder(node, "lever_shaft", Vector3.ZERO, 0.09, 0.85, mats.iron)
		LevelBuilder.box(node, "lever_grip", Vector3(0, 0.4, 0), Vector3(0.35, 0.16, 0.16), mats.brass, false)
	elif kind == "arbalest":
		LevelBuilder.box(node, "arbalest_stock", Vector3.ZERO, Vector3(0.22, 0.2, 0.95), mats.timber, false)
		LevelBuilder.box(node, "arbalest_prod", Vector3(0, 0.05, -0.3), Vector3(0.95, 0.12, 0.14), mats.acid, false)
	elif kind == "thurible":
		LevelBuilder.cylinder(node, "thurible_bowl", Vector3.ZERO, 0.32, 0.48, mats.brass)
		LevelBuilder.cylinder(node, "thurible_core", Vector3(0, 0.05, 0), 0.24, 0.32, mats.cinder)
	elif kind == "ashen_key":
		LevelBuilder.cylinder(node, "key_ring", Vector3(0, 0.25, 0), 0.26, 0.12, mats.ice)
		LevelBuilder.box(node, "key_blade", Vector3(0, -0.15, 0), Vector3(0.14, 0.65, 0.14), mats.brass, false)
	elif kind.begins_with("relic_"):
		var rmat: Material = mats.blood if kind == "relic_heart" else mats.mana if kind == "relic_siphon" else mats.cinder
		LevelBuilder.cylinder(node, "relic_orb", Vector3.ZERO, 0.34, 0.52, rmat, false, 8)
		LevelBuilder.cylinder(node, "relic_halo", Vector3(0, 0, 0), 0.48, 0.08, mats.brass, false, 12)
		_light(pos + Vector3(0, 0.4, 0), Color("ffd875"), 2.2, 5.5)
	pickups.append({"node": node, "kind": kind, "y": pos.y, "id": item_id})

func _hud_label(parent: Control, text_value: String, pos: Vector2, size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = pos
	label.size = size
	label.add_theme_font_size_override("font_size", font_size)
	if font_size >= 20:
		label.add_theme_font_override("font", title_font)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(label)
	return label

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var hud := Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(hud)
	var top := ColorRect.new()
	top.color = Color(0.015, 0.025, 0.028, 0.78)
	top.anchor_right = 1
	top.offset_bottom = 44
	hud.add_child(top)
	labels.area = _hud_label(hud, "ASHEN GATE    /    THE SUNKEN COURT", Vector2(20, 8), Vector2(520, 34), 20, Color("d6c6a4"))
	labels.compass = _hud_label(hud, "", Vector2(540, 10), Vector2(220, 30), 15, Color("f0d297"))
	labels.compass.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	labels.goal = _hud_label(hud, "OBJECTIVE: FIND THE IRON LEVER", Vector2(760, 10), Vector2(500, 30), 17, Color("c98d60"))
	labels.goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	labels.boss = _hud_label(hud, "", Vector2(360, 50), Vector2(560, 30), 19, Color("e6b0d6"))
	labels.boss.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var boss_bg := ColorRect.new()
	boss_bg.color = Color(0.05, 0.04, 0.07, 0.85)
	boss_bg.position = Vector2(430, 82)
	boss_bg.size = Vector2(420, 10)
	boss_bg.visible = false
	hud.add_child(boss_bg)
	var boss_fill := ColorRect.new()
	boss_fill.color = Color("b752cc")
	boss_fill.size = Vector2(420, 10)
	boss_bg.add_child(boss_fill)
	var boss_notch := ColorRect.new()
	boss_notch.color = Color("f0d297")
	boss_notch.position = Vector2(209, -2)
	boss_notch.size = Vector2(2, 14)
	boss_bg.add_child(boss_notch)
	hud_bars.boss_bg = boss_bg
	hud_bars.boss_fill = boss_fill
	weapon_sprite = TextureRect.new()
	weapon_sprite.stretch_mode = TextureRect.STRETCH_SCALE
	weapon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	weapon_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(weapon_sprite)
	_build_weapon()
	rune_glow_rect = ColorRect.new()
	rune_glow_rect.color = Color(0.25, 0.95, 1.0, 0.0)
	rune_glow_rect.position = Vector2(900, 340)
	rune_glow_rect.size = Vector2(180, 180)
	rune_glow_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(rune_glow_rect)
	var bottom := ColorRect.new()
	bottom.color = Color(0.015, 0.022, 0.028, 0.88)
	bottom.anchor_top = 1
	bottom.anchor_bottom = 1
	bottom.anchor_right = 1
	bottom.offset_top = -78
	hud.add_child(bottom)
	var trim := ColorRect.new()
	trim.color = Color("8c6c46")
	trim.anchor_top = 1
	trim.anchor_bottom = 1
	trim.anchor_right = 1
	trim.offset_top = -79
	trim.offset_bottom = -77
	hud.add_child(trim)
	for bar_spec in [
		{"key": "hp", "x": 24, "w": 160, "col": Color("b83c32")},
		{"key": "mana", "x": 230, "w": 150, "col": Color("39bdd1")},
		{"key": "green", "x": 420, "w": 150, "col": Color("58b86a")}
	]:
		var bg := ColorRect.new()
		bg.color = Color(0.07, 0.09, 0.11, 0.9)
		bg.position = Vector2(bar_spec.x, 700)
		bg.size = Vector2(bar_spec.w, 8)
		hud.add_child(bg)
		var fill := ColorRect.new()
		fill.color = bar_spec.col
		fill.size = Vector2(bar_spec.w, 8)
		bg.add_child(fill)
		hud_bars[bar_spec.key] = fill
	labels.hp = _hud_label(hud, "HEALTH  100", Vector2(24, 658), Vector2(200, 38), 25, Color("e6c8b0"))
	labels.mana = _hud_label(hud, "BLUE  75", Vector2(230, 658), Vector2(190, 38), 25, Color("70d7df"))
	labels.green = _hud_label(hud, "GREEN  45", Vector2(420, 658), Vector2(195, 38), 24, Color("8ace8a"))
	labels.flask = _hud_label(hud, "FLASK  2", Vector2(625, 666), Vector2(180, 40), 22, Color("be9e91"))
	labels.weapon = _hud_label(hud, "CLEAVER-AXE", Vector2(960, 660), Vector2(295, 45), 26, Color("d8b479"))
	labels.weapon.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	labels.prompt = _hud_label(hud, "", Vector2(310, 525), Vector2(660, 42), 21, Color("f0d297"))
	labels.prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	labels.message = _hud_label(hud, "", Vector2(185, 86), Vector2(910, 96), 22, Color("e4c5a2"))
	labels.message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	labels.message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var crosshair := _hud_label(hud, "+", Vector2(621, 330), Vector2(40, 40), 25, Color("c8d6d3"))
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	labels.hitmarker = _hud_label(hud, "X", Vector2(611, 320), Vector2(60, 60), 34, Color("ffaf7b"))
	labels.hitmarker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	labels.hitmarker.visible = false
	_hud_label(hud, "WASD MOVE • SHIFT RUN • C DASH • SPACE JUMP • 1/2/3 WEAPONS • RMB FROST • Q REPULSE • G GRASP/HURL • E USE • F HEAL • TAB MAP • J JOURNAL", Vector2(18, 622), Vector2(1244, 35), 12, Color("9aa9a5"))
	narrative = NarrativeSystem.new()
	add_child(narrative)
	narrative.setup(hud, title_font)
	veil = ColorRect.new()
	veil.color = Color(0.7, 0.1, 0.04, 0)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(veil)
	vignette_rect = ColorRect.new()
	vignette_rect.color = Color(0.65, 0.08, 0.05, 0.0)
	vignette_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(vignette_rect)
	ending_panel = ColorRect.new()
	ending_panel.color = Color(0.03, 0.025, 0.045, 0.94)
	ending_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ending_panel.visible = false
	hud.add_child(ending_panel)
	var ending := _hud_label(ending_panel, "ACT I COMPLETE — THE GREAT GATE UNSEALS\n\nAsh blows inward from a blinding pale-violet horizon.\nThe three resonant anchors of Vaelor are severed.\n\nCHECKPOINT SAVED   •   PRESS R TO PLAY AGAIN", Vector2(160, 165), Vector2(960, 390), 30, Color("e6cfad"))
	ending.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ending.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	map_overlay = Control.new()
	map_overlay.set_script(load("res://scripts/map_overlay.gd"))
	map_overlay.position = Vector2(160, 88)
	map_overlay.size = Vector2(960, 540)
	map_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_overlay.visible = false
	hud.add_child(map_overlay)
	map_overlay.game = self
	journal_panel = ColorRect.new()
	journal_panel.color = Color(0.025, 0.031, 0.033, 0.98)
	journal_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	journal_panel.visible = false
	hud.add_child(journal_panel)
	labels.journal_heading = _hud_label(journal_panel, "THE ASHEN CHRONICLE", Vector2(168, 80), Vector2(960, 55), 34, Color("dfc29a"))
	labels.journal_title = _hud_label(journal_panel, "", Vector2(175, 170), Vector2(930, 60), 30, Color("c18eae"))
	labels.journal_body = _hud_label(journal_panel, "", Vector2(175, 250), Vector2(930, 290), 24, Color("d6cfbd"))
	labels.journal_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	labels.journal_count = _hud_label(journal_panel, "", Vector2(175, 565), Vector2(930, 40), 19, Color("a59c8c"))
	_hud_label(journal_panel, "J CLOSE    •    LEFT / RIGHT TURN PAGE", Vector2(175, 625), Vector2(930, 32), 17, Color("8b9b99"))

func _setup_audio() -> void:
	for sname in ["axe", "hit", "cast", "lever", "pickup", "ambient", "frost", "maul", "portal", "bell", "repulse", "step", "jump", "land"]:
		var player_audio := AudioStreamPlayer.new()
		player_audio.stream = load("res://audio/%s.wav" % sname)
		player_audio.volume_db = -17 if sname == "ambient" else -15 if sname == "step" else -10 if sname == "jump" or sname == "land" else -6
		if sname == "ambient" and player_audio.stream is AudioStreamWAV:
			player_audio.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		add_child(player_audio)
		sounds[sname] = player_audio
	sounds.ambient.play()

func _sound(sname: String, pitch_scale: float = 1.0) -> void:
	var player_audio: AudioStreamPlayer = sounds[sname]
	player_audio.pitch_scale = pitch_scale
	player_audio.stop()
	player_audio.play()

func _message(text_value: String, seconds: float = 3.0) -> void:
	labels.message.text = text_value
	message_time = seconds

func _story_event(event_id: String, title: String, body: String, short_message: String = "") -> void:
	if story_flags.has(event_id):
		return
	story_flags.append(event_id)
	journal_entries.append({"id": event_id, "title": title, "body": body})
	if journal_panel.visible:
		journal_index = journal_entries.size() - 1
		_refresh_journal()
	if short_message != "":
		_message(short_message, 4.5)

func _on_trigger_entered(trigger_id: String, objective_text: String, journal_id: String, journal_title: String, journal_body: String, short_msg: String, sound_name: String) -> void:
	if triggered_volumes.has(trigger_id):
		return
	triggered_volumes[trigger_id] = true
	if sound_name != "":
		_sound(sound_name)
	if journal_id != "":
		_story_event(journal_id, journal_title, journal_body, short_msg)
	elif short_msg != "":
		_message(short_msg, 3.8)
	if objective_text != "":
		labels.goal.text = "OBJECTIVE: " + objective_text

func _on_memory_echo(echo_id: String, speaker: String, title: String, line: String, col: Color) -> void:
	if seen_echoes.has(echo_id):
		return
	seen_echoes[echo_id] = true
	_sound("portal", 1.35)
	narrative.say(speaker, line, 6.2, col)
	_story_event("echo_" + echo_id, title, "%s: \"%s\"" % [speaker, line], "")

func _toggle_grasp() -> void:
	if hp <= 0 or won:
		return
	if is_instance_valid(held_body):
		held_body.gravity_scale = 1.0
		held_body = null
		_sound("repulse", 1.4)
		_message("OBJECT RELEASED", 0.9)
		return
	var from := camera.global_position
	var to := from + -camera.global_transform.basis.z * 7.5
	var q := PhysicsRayQueryParameters3D.create(from, to, LAYER_PUSHABLE)
	q.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and hit.collider is RigidBody3D and not hit.collider.freeze and not hit.collider.get_meta("ore_cart", false):
		held_body = hit.collider
		held_body.gravity_scale = 0.0
		held_body.linear_velocity = Vector3.ZERO
		_sound("repulse", 1.6)
		_message("TELEKINETIC GRASP  •  LMB TO HURL  •  G TO DROP", 1.8)
	else:
		_message("AIM AT AN URN, WEIGHTED BLOCK, OR ALCHEMICAL CASK", 1.2)

func _hurl_held() -> void:
	if not is_instance_valid(held_body):
		held_body = null
		return
	var body := held_body
	held_body = null
	body.gravity_scale = 1.0
	var dir := -camera.global_transform.basis.z
	body.linear_velocity = dir * 27.0 + Vector3.UP * 2.5
	held_was_hurled[body.get_instance_id()] = 1.5
	cooldown = 0.35
	_sound("repulse", 0.9)
	camera_shake = maxf(camera_shake, 0.14)
	_message("TELEKINETIC HURL!", 1.0)

func _dash() -> void:
	if dash_cooldown > 0.0 or hp <= 0 or won:
		return
	var move := Vector2.ZERO
	if Input.is_key_pressed(KEY_A): move.x -= 1
	if Input.is_key_pressed(KEY_D): move.x += 1
	if Input.is_key_pressed(KEY_W): move.y -= 1
	if Input.is_key_pressed(KEY_S): move.y += 1
	if move.length() < 0.1:
		move = Vector2(0, -1)
	move = move.normalized()
	var dir := player.global_transform.basis * Vector3(move.x, 0, move.y)
	dash_dir = Vector3(dir.x, 0, dir.z).normalized()
	dash_time = 0.17
	dash_cooldown = 1.05 if damage_mult > 1.1 else 1.40
	hurt_cooldown = maxf(hurt_cooldown, 0.22)
	flash = 0.45
	flash_color = Color("44d4e8")
	_sound("jump", 1.45)

func _update_compass() -> void:
	if not labels.has("compass"):
		return
	var target_pos := Vector3.ZERO
	var target_name := ""
	if stage == 0:
		if gate_open:
			target_pos = Vector3(0, 0, -28.0)
			target_name = "BELL TOWER PORTAL"
		elif not has_arbalest:
			target_pos = Vector3(-16.5, 0, -1.0)
			target_name = "BRIAR ARBALEST"
		elif not level_states[0].get("has_lever", false):
			target_pos = Vector3(17.5, 0, -2.0)
			target_name = "IRON LEVER"
		elif not level_states[0].get("lever_inserted", false):
			target_pos = Vector3(-5.2, 0, -17.8)
			target_name = "NORTH GEARBOX"
		else:
			target_pos = Vector3(0, 0, -5.0)
			target_name = "COURT SEALS"
	elif stage == 1:
		if level_states[1].boss_dead:
			target_pos = Vector3(0, 7.0, -38.0)
			target_name = "KILN DROP SHAFT"
		elif not wards.is_empty() and is_instance_valid(wards[0]):
			target_pos = wards[0].global_position
			target_name = "RESONANT WARD"
		else:
			target_pos = Vector3(0, 7.0, -38.0)
			target_name = "BELL WARDEN"
	else:
		if level_states[2].get("great_gate_open", false):
			labels.compass.text = "ACT I COMPLETE"
			return
		elif has_ashen_key:
			target_pos = Vector3(0, 0, -21.5)
			target_name = "GREAT ASHEN GATE"
		elif not level_states[2].get("trough_flooded", false):
			target_pos = Vector3(-22.5, 4.0, -13.5)
			target_name = "AQUEDUCT VALVE"
		elif not level_states[2].get("dam_broken", false):
			target_pos = Vector3(18.9, 0, 5.5)
			target_name = "SMELTERY ORE-CART"
		else:
			target_pos = Vector3(3.4, 0, -5.0)
			target_name = "CRUCIBLE HOIST"
	var to_t := target_pos - player.global_position
	var dist := int(Vector2(to_t.x, to_t.z).length())
	var fwd := -player.global_transform.basis.z
	var right := player.global_transform.basis.x
	var flat_t := Vector3(to_t.x, 0, to_t.z).normalized()
	var dot_r := right.dot(flat_t)
	var dot_f := fwd.dot(flat_t)
	var arrow := "▲" if dot_f > 0.65 else "▼" if dot_f < -0.65 else ("►" if dot_r > 0 else "◄")
	labels.compass.text = "%s %s (%dm)" % [arrow, target_name, dist]

func _refresh_journal() -> void:
	if journal_entries.is_empty():
		labels.journal_title.text = "NO ENTRIES"
		labels.journal_body.text = ""
		labels.journal_count.text = ""
		return
	journal_index = clampi(journal_index, 0, journal_entries.size() - 1)
	var entry: Dictionary = journal_entries[journal_index]
	labels.journal_title.text = entry.title
	labels.journal_body.text = entry.body
	labels.journal_count.text = "ENTRY %d / %d" % [journal_index + 1, journal_entries.size()]

func _refresh_hud_numbers() -> void:
	labels.hp.text = "HEALTH  %d" % hp
	labels.mana.text = "BLUE  %d" % mana
	labels.green.text = "GREEN  %d" % green_mana
	labels.flask.text = "FLASK  %d" % flasks
	labels.weapon.text = "CLEAVER-AXE" if mode == 0 else "BRIAR ARBALEST" if mode == 1 else "CINDER THURIBLE"

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_SPACE and not event.pressed and player.velocity.y > 0:
		player.velocity.y *= 0.55
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not map_overlay.visible and not journal_panel.visible and not won and hp > 0:
		player.rotation.y -= event.relative.x * 0.0022
		pitch = clampf(pitch - event.relative.y * 0.0022, -1.42, 1.42)
		head.rotation.x = pitch
		weapon_sway.x = clampf(weapon_sway.x - event.relative.x * 0.28, -32.0, 32.0)
		weapon_sway.y = clampf(weapon_sway.y - event.relative.y * 0.22, -22.0, 22.0)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				jump_buffer = 0.14
			KEY_TAB:
				journal_panel.visible = false
				map_overlay.visible = not map_overlay.visible
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if map_overlay.visible else Input.MOUSE_MODE_CAPTURED
			KEY_J:
				map_overlay.visible = false
				journal_panel.visible = not journal_panel.visible
				if journal_panel.visible:
					journal_index = journal_entries.size() - 1
					_refresh_journal()
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if journal_panel.visible else Input.MOUSE_MODE_CAPTURED
			KEY_LEFT:
				if journal_panel.visible:
					journal_index -= 1
					_refresh_journal()
			KEY_RIGHT:
				if journal_panel.visible:
					journal_index += 1
					_refresh_journal()
			KEY_ESCAPE:
				if map_overlay.visible or journal_panel.visible:
					map_overlay.visible = false
					journal_panel.visible = false
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				else:
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
			KEY_1:
				mode = 0
				swing_time = 0
				thurible_time = 0
				_build_weapon()
				_refresh_hud_numbers()
			KEY_2:
				if has_arbalest:
					mode = 1
					swing_time = 0
					thurible_time = 0
					_build_weapon()
					_refresh_hud_numbers()
				else:
					_message("FIND THE BRIAR ARBALEST IN THE WEST ARCADE", 2.0)
			KEY_3:
				if has_thurible:
					mode = 2
					swing_time = 0
					thurible_time = 0
					_build_weapon()
					_refresh_hud_numbers()
				else:
					_message("FIND THE CINDER THURIBLE IN THE BELL TOWER", 2.0)
			KEY_Q:
				if is_instance_valid(held_body):
					_hurl_held()
				else:
					_repulse()
			KEY_G:
				_toggle_grasp()
			KEY_C, KEY_ALT:
				_dash()
			KEY_F5:
				_save_game()
			KEY_F9:
				_load_game()
			KEY_F:
				_heal()
			KEY_E:
				_use()
			KEY_R:
				if won or hp <= 0:
					get_tree().reload_current_scene()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif not won and hp > 0 and not map_overlay.visible and not journal_panel.visible:
			if is_instance_valid(held_body):
				_hurl_held()
			else:
				_attack()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT and not won and hp > 0 and not map_overlay.visible and not journal_panel.visible:
		_frost_cast()

func _physics_process(delta: float) -> void:
	if hitstop_time > 0.0:
		hitstop_time = maxf(0.0, hitstop_time - delta)
		return
	elapsed += delta
	if narrative != null:
		narrative.tick(delta)
	cooldown = maxf(0.0, cooldown - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	dash_time = maxf(0.0, dash_time - delta)
	hurt_cooldown = maxf(0.0, hurt_cooldown - delta)
	if mana_regen_rate > 0.0 and hp > 0 and not won:
		mana_regen_acc += mana_regen_rate * delta
		if mana_regen_acc >= 1.0:
			var add_m := int(mana_regen_acc)
			mana_regen_acc -= float(add_m)
			mana = mini(max_mana, mana + add_m)
			green_mana = mini(max_mana, green_mana + add_m)
			_refresh_hud_numbers()
	# Update Telekinetic Grasp held object smoothly in front of camera
	if is_instance_valid(held_body):
		var hold_pos := camera.global_position + -camera.global_transform.basis.z * 2.55
		held_body.linear_velocity = (hold_pos - held_body.global_position) * 14.0
		held_body.angular_velocity *= 0.85
	else:
		held_body = null
	# Track hurled objects smashing enemies for kinetic impact damage!
	for bid in held_was_hurled.keys():
		held_was_hurled[bid] -= delta
		if held_was_hurled[bid] <= 0.0:
			held_was_hurled.erase(bid)
	for blk in pushable_blocks + breakables:
		if is_instance_valid(blk) and held_was_hurled.has(blk.get_instance_id()) and blk.linear_velocity.length() > 8.0:
			for e in enemies.duplicate():
				if is_instance_valid(e) and e.global_position.distance_to(blk.global_position) < 1.65:
					held_was_hurled.erase(blk.get_instance_id())
					if blk.get_meta("explosive_cask", false):
						_smash_pot(blk)
					else:
						_damage_enemy(e, int(90.0 * damage_mult))
						_spell_impact(e.global_position + Vector3(0, 1.0, 0), Color("61dbed"))
						_message("KINETIC SLAM! +90 DAMAGE", 1.6)
					break
	hitmarker_time = maxf(0.0, hitmarker_time - delta)
	parry_window = maxf(0.0, parry_window - delta)
	heal_anim_time = maxf(0.0, heal_anim_time - delta)
	arbalest_recoil = maxf(0.0, arbalest_recoil - delta * 3.5)
	labels.hitmarker.visible = hitmarker_time > 0.0

	# Glowing cyan rune indicator when parry/counter window is active on Cleaver-Axe
	if rune_glow_rect:
		rune_glow_rect.color.a = (0.28 + sin(elapsed * 22.0) * 0.1) if (mode == 0 and parry_window > 0.0) else 0.0

	# Weapon animations
	if swing_time > 0.0:
		swing_time = maxf(0.0, swing_time - delta)
		var age := 0.44 - swing_time
		if not swing_contact_done and age >= 0.19:
			swing_contact_done = true
			_axe_contact()
		if age < 0.11:
			var t := age / 0.11
			weapon_sprite.position = Vector2(660, 105).lerp(Vector2(710, 180), t)
			weapon_sprite.rotation = lerpf(0.0, 0.28, t)
		elif age < 0.28:
			var t := (age - 0.11) / 0.17
			weapon_sprite.position = Vector2(710, 180).lerp(Vector2(300, 65), t)
			weapon_sprite.rotation = lerpf(0.28, -0.92, t)
		else:
			var t := minf(1.0, (age - 0.28) / 0.16)
			weapon_sprite.position = Vector2(300, 65).lerp(Vector2(660, 105), t)
			weapon_sprite.rotation = lerpf(-0.92, 0.0, t)
	elif thurible_time > 0.0:
		thurible_time = maxf(0.0, thurible_time - delta)
		var age := 0.72 - thurible_time
		if not thurible_release_done and age >= 0.30:
			thurible_release_done = true
			_thurible_release()
		var swing_arc := sin(age / 0.72 * PI)
		weapon_sprite.position = Vector2(680 - swing_arc * 180.0, 220 - swing_arc * 95.0)
		weapon_sprite.rotation = -swing_arc * 0.85

	# Screen flash & low-HP vignette pulse
	flash = maxf(0.0, flash - delta * 1.8)
	veil.color = Color(flash_color.r, flash_color.g, flash_color.b, flash * 0.36)
	if hp <= 30 and hp > 0:
		vignette_rect.color = Color(0.65, 0.06, 0.04, 0.12 + absf(sin(elapsed * 4.5)) * 0.12)
	else:
		vignette_rect.color.a = move_toward(vignette_rect.color.a, 0.0, delta * 0.8)

	camera_shake = maxf(0.0, camera_shake - delta * 0.95)
	camera.position = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), 0) * camera_shake
	view_kick = move_toward(view_kick, 0.0, delta * 1.9)
	camera.rotation.x = lerpf(camera.rotation.x, view_kick, minf(1.0, delta * 14.0))

	if message_time > 0.0:
		message_time -= delta
		if message_time <= 0.0:
			labels.message.text = ""

	if won or hp <= 0 or map_overlay.visible or journal_panel.visible:
		return

	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and cooldown <= 0.0:
		_attack()

	# Retro-FPS locomotion: snappy accel, +35% sprint speed, +6° FOV
	var move := Vector2.ZERO
	if Input.is_key_pressed(KEY_A): move.x -= 1
	if Input.is_key_pressed(KEY_D): move.x += 1
	if Input.is_key_pressed(KEY_W): move.y -= 1
	if Input.is_key_pressed(KEY_S): move.y += 1
	move = move.normalized()
	var sprinting := Input.is_key_pressed(KEY_SHIFT) and move.length() > 0.1
	var speed := 8.5 * (1.35 if sprinting else 1.0)
	camera.fov = lerpf(camera.fov, 94.0 if dash_time > 0.0 else 88.0 if sprinting else 82.0, delta * 9.0)
	var direction := player.global_transform.basis * Vector3(move.x, 0, move.y)
	var target := Vector2(dash_dir.x, dash_dir.z) * 23.0 if dash_time > 0.0 else Vector2(direction.x, direction.z) * speed
	var current := Vector2(player.velocity.x, player.velocity.z)
	var accel := 120.0 if dash_time > 0.0 else 48.0 if player.is_on_floor() and move.length() > 0 else 32.0 if player.is_on_floor() else 16.0
	current = current.move_toward(target, accel * delta)
	player.velocity.x = current.x
	player.velocity.z = current.y

	# Crisp jump + 100ms coyote time + ledge-mantle forgiveness
	jump_buffer = maxf(0.0, jump_buffer - delta)
	coyote_time = 0.10 if player.is_on_floor() else maxf(0.0, coyote_time - delta)
	if jump_buffer > 0.0 and coyote_time > 0.0:
		player.velocity.y = 6.3
		jump_buffer = 0.0
		coyote_time = 0.0
		_sound("jump")
	elif not player.is_on_floor():
		player.velocity.y -= GRAVITY * delta
		if move.y < -0.2 and player.velocity.y < 1.5 and player.velocity.y > -5.5:
			_try_ledge_mantle()
	else:
		player.velocity.y = -0.1

	var was_grounded := player.is_on_floor()
	var falling_speed := player.velocity.y
	player.move_and_slide()

	# Safety catch if player falls into Bell Tower central shaft
	if stage == 1 and player.position.y < -5.5:
		player.position = Vector3(0, 0.3, 12.0)
		player.velocity = Vector3.ZERO
		_hurt(12)
		_message("YOU FELL INTO THE TOWER SHAFT", 1.8)

	for index in player.get_slide_collision_count():
		var collision := player.get_slide_collision(index)
		if collision.get_collider() is RigidBody3D:
			var body: RigidBody3D = collision.get_collider()
			body.apply_central_impulse(-collision.get_normal() * minf(6.5, current.length() * 0.45))

	if not was_grounded and player.is_on_floor() and falling_speed < -3.0:
		camera_shake = maxf(camera_shake, minf(0.14, absf(falling_speed) * 0.012))
		landing_dip = 0.11
		_sound("land")
	landing_dip = maxf(0.0, landing_dip - delta * 0.45)

	var bob_amp := 0.032 if sprinting else 0.045
	var bob := sin(elapsed * (16.0 if sprinting else 11.5)) * bob_amp if move.length() > 0.1 and player.is_on_floor() else 0.0
	head.position.y = lerpf(head.position.y, 1.55 + bob - landing_dip, delta * 12.0)
	head.rotation.z = lerpf(head.rotation.z, -move.x * 0.05 + sin(elapsed * 7.0) * 0.007 * move.length(), minf(1.0, delta * 9.0))
	if player.is_on_floor() and move.length() > 0.1:
		footstep_time -= delta
		if footstep_time <= 0.0:
			_sound("step")
			footstep_time = 0.27 if sprinting else 0.40
	else:
		footstep_time = 0.0

	# Idle weapon bob + spring-damped mouse sway + equip drop-in
	weapon_sway = weapon_sway.lerp(Vector2.ZERO, minf(1.0, delta * 9.5))
	equip_offset = move_toward(equip_offset, 0.0, delta * 520.0)
	var bob_scale := 0.65 if sprinting else 1.0
	if mode == 0 and swing_time <= 0.0:
		weapon_sprite.position = Vector2(660 + sin(elapsed * 6.0) * 5.0 * move.length() * bob_scale + weapon_sway.x, 105 + sin(elapsed * 12.0) * 4.0 * bob_scale + weapon_sway.y + equip_offset + (heal_anim_time * 90.0))
		weapon_sprite.rotation = -move.x * 0.035 + weapon_sway.x * 0.0018
	elif mode == 1:
		weapon_sprite.position = Vector2(690 + sin(elapsed * 6.0) * 4.0 * move.length() * bob_scale + weapon_sway.x, 290 + sin(elapsed * 12.0) * 3.0 * bob_scale + weapon_sway.y + equip_offset + arbalest_recoil * 48.0 + (heal_anim_time * 90.0))
		weapon_sprite.rotation = -move.x * 0.025 + weapon_sway.x * 0.0014
	elif mode == 2 and thurible_time <= 0.0:
		weapon_sprite.position = Vector2(680 + sin(elapsed * 5.0) * 6.0 * move.length() * bob_scale + weapon_sway.x, 220 + sin(elapsed * 10.0) * 5.0 * bob_scale + weapon_sway.y + equip_offset + (heal_anim_time * 90.0))
		weapon_sprite.rotation = sin(elapsed * 3.5) * 0.06 - move.x * 0.06 + weapon_sway.x * 0.003

	# Smoothly animate HUD bars
	if hud_bars.has("hp"):
		hud_bars.hp.size.x = lerpf(hud_bars.hp.size.x, 160.0 * clampf(float(hp) / float(max_hp), 0.0, 1.0), minf(1.0, delta * 12.0))
		hud_bars.mana.size.x = lerpf(hud_bars.mana.size.x, 150.0 * clampf(float(mana) / float(max_mana), 0.0, 1.0), minf(1.0, delta * 12.0))
		hud_bars.green.size.x = lerpf(hud_bars.green.size.x, 150.0 * clampf(float(green_mana) / float(max_mana), 0.0, 1.0), minf(1.0, delta * 12.0))
		var show_boss := (stage == 1 and is_instance_valid(boss))
		hud_bars.boss_bg.visible = show_boss
		if show_boss:
			hud_bars.boss_fill.size.x = lerpf(hud_bars.boss_fill.size.x, 420.0 * clampf(float(boss.get_meta("hp")) / 520.0, 0.0, 1.0), minf(1.0, delta * 10.0))

	_update_enemies(delta)
	_update_bolts(delta)
	_update_enemy_bolts(delta)
	_update_shockwaves(delta)
	_update_pickups(delta)
	_update_breakables()
	_update_puzzles(delta)
	_update_particles(delta)
	_update_prompt()
	_update_compass()
	for i in torches.size():
		if is_instance_valid(torches[i]):
			if ambush_dark_timer > 0.0 and crypt_torches.has(torches[i]):
				torches[i].light_energy = 0.05
			else:
				torches[i].light_energy = 2.55 + sin(elapsed * 9.0 + i * 2.3) * 0.38

func _try_ledge_mantle() -> void:
	var forward := -player.global_transform.basis.z
	var space := get_world_3d().direct_space_state
	var low_from := player.global_position + Vector3(0, 0.55, 0)
	var low_q := PhysicsRayQueryParameters3D.create(low_from, low_from + forward * 0.72, LAYER_WORLD)
	if space.intersect_ray(low_q).is_empty():
		return
	var high_from := player.global_position + Vector3(0, 1.45, 0)
	var high_q := PhysicsRayQueryParameters3D.create(high_from, high_from + forward * 0.82, LAYER_WORLD)
	if space.intersect_ray(high_q).is_empty():
		player.velocity.y = maxf(player.velocity.y, 5.2)

func _update_puzzles(delta: float) -> void:
	# Level 1: Ambush torches + Water channel + Pressure plates + Counterweight Portcullis
	if stage == 0:
		if ambush_dark_timer > 0.0:
			ambush_dark_timer = maxf(0.0, ambush_dark_timer - delta)
			if ambush_dark_timer <= 0.0 and ambush_pending:
				ambush_pending = false
				_sound("bell")
				_enemy(Vector3(13.5, 0.1, 3.5), true, "court_ambush_exec", false, "executioner")
				_enemy(Vector3(11.8, 0.1, -6.0), false, "court_ambush_shr1", false, "shrieker")
				_enemy(Vector3(15.2, 0.1, 1.0), false, "court_ambush_shr2", false, "shrieker")
				_message("THE SCONCES REIGNITE — AMBUSH IN THE EAST CRYPTS!", 3.2)

		for ch in water_channels:
			if ch.frozen_timer > 0.0:
				ch.frozen_timer = maxf(0.0, ch.frozen_timer - delta)
				if ch.frozen_timer <= 0.0 and is_instance_valid(ch.node):
					ch.node.get_child(0).material_override = mats.water
			else:
				# Rushing water pushes unfrozen blocks off the East pressure plate!
				for blk in pushable_blocks:
					if is_instance_valid(blk):
						var d: Vector3 = blk.global_position - ch.pos
						if absf(d.x) < ch.size.x * 0.5 and absf(d.z) < ch.size.z * 0.5:
							blk.apply_central_force(ch.push_dir * 42.0)

		var pressed_count := 0
		for plate in pressure_plates:
			var is_held := false
			for blk in pushable_blocks:
				if is_instance_valid(blk):
					var horiz := Vector2(blk.global_position.x - plate.pos.x, blk.global_position.z - plate.pos.z).length()
					if horiz < 1.65:
						is_held = true
						break
			plate.pressed = is_held
			if is_instance_valid(plate.node):
				plate.node.position.y = 0.02 if is_held else 0.08
				plate.node.get_child(0).material_override = mats.mana if is_held else mats.brass
			if is_held:
				pressed_count += 1

		if not gate_open and level_states[0].get("lever_inserted", false) and pressed_count >= 2:
			gate_open = true
			level_states[0].gate_open = true
			_sound("lever")
			_sound("bell")
			_objective()
			_message("BOTH COURT SEALS WEIGHTED  •  THE PORTCULLIS LOCKS OPEN!", 4.2)

		if is_instance_valid(gate):
			var target_y := 5.2 if gate_open else 1.9 if level_states[0].get("lever_inserted", false) else 0.0
			gate.position.y = move_toward(gate.position.y, target_y, delta * 2.6)
			if gate_open and gate.position.y >= 4.9:
				gate.collision_layer = 0

	# Level 2: Rotating Cogwheel + Ward Energy Beams
	elif stage == 1:
		if is_instance_valid(tower_gear) and not level_states[1].get("gear_frozen", false):
			tower_gear.rotation.x += delta * 2.2
		_update_ward_beams()

	# Level 3: Frozen Water Spout Ice Bridges + Ore-Cart Slag Dam + Slag Channel Hazards + Great Gate
	elif stage == 2:
		for spout in water_spouts:
			if not is_instance_valid(spout):
				continue
			var ft: float = spout.get_meta("frozen_timer")
			if ft > 0.0:
				ft = maxf(0.0, ft - delta)
				spout.set_meta("frozen_timer", ft)
				if ft <= 0.0:
					spout.collision_layer = LAYER_TARGET
					spout.get_child(0).material_override = mats.water
					spout.get_meta("stream").get_child(0).material_override = mats.water

		# Check if Ore-Cart smashed into the Slag Dam!
		if not level_states[2].get("dam_broken", false) and is_instance_valid(ore_cart) and is_instance_valid(slag_dam):
			if ore_cart.global_position.z < -8.2:
				level_states[2].dam_broken = true
				slag_dam.visible = false
				slag_dam.collision_layer = 0
				_sound("maul")
				camera_shake = maxf(camera_shake, 0.25)
				for i in 8:
					_debris_piece(slag_dam.global_position + Vector3(rng.randf_range(-1, 1), rng.randf_range(0, 1.5), 0), Vector3(0.28, 0.28, 0.28), mats.cinder, Vector3(rng.randf_range(-3, 3), rng.randf_range(2, 5), rng.randf_range(-5, -1)))
				_message("SLAG DAM SHATTERED  •  MOLTEN METAL POWERS THE CRUCIBLE HOIST!", 4.2)
				_objective()

		# Molten Slag Channel hazards (player burn + enemy shove instant kill/heavy burn!)
		hazard_timer = maxf(0.0, hazard_timer - delta)
		for zinfo in slag_zones:
			var pdelta: Vector3 = player.global_position - zinfo.pos
			if hazard_timer <= 0.0 and absf(pdelta.x) < zinfo.half.x and absf(pdelta.z) < zinfo.half.y and player.global_position.y < 0.25:
				# Safe if standing on iron bridges at z = 4 or z = -10
				if absf(player.global_position.z - 4.0) > 1.9 and absf(player.global_position.z + 10.0) > 1.9:
					_hurt(12, Vector3.ZERO, Color("ff5c1a"))
					hazard_timer = 0.7
			for entry in enemies.duplicate():
				var e: CharacterBody3D = entry
				if not is_instance_valid(e):
					continue
				var edelta: Vector3 = e.global_position - zinfo.pos
				if absf(edelta.x) < zinfo.half.x and absf(edelta.z) < zinfo.half.y and e.global_position.y < 0.35:
					if absf(e.global_position.z - 4.0) > 1.9 and absf(e.global_position.z + 10.0) > 1.9:
						_damage_enemy(e, 140)
						_message("FOE INCINERATED IN MOLTEN SLAG!", 1.8)

		# Great Ashen Gate opening animation
		if level_states[2].get("great_gate_open", false) and is_instance_valid(great_gate_left) and is_instance_valid(great_gate_right):
			great_gate_left.position.x = move_toward(great_gate_left.position.x, -8.5, delta * 2.8)
			great_gate_right.position.x = move_toward(great_gate_right.position.x, 8.5, delta * 2.8)

func _update_ward_beams() -> void:
	if not is_instance_valid(boss) or wards.is_empty():
		for b in ward_beams:
			if is_instance_valid(b):
				b.queue_free()
		ward_beams.clear()
		return
	while ward_beams.size() < wards.size():
		var beam := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.07
		cyl.bottom_radius = 0.07
		cyl.height = 1.0
		beam.mesh = cyl
		beam.material_override = mats.portal
		level_root.add_child(beam)
		ward_beams.append(beam)
	while ward_beams.size() > wards.size():
		var extra: MeshInstance3D = ward_beams.pop_back()
		if is_instance_valid(extra):
			extra.queue_free()
	var target := boss.global_position + Vector3(0, 2.5, 0)
	for i in wards.size():
		var w: StaticBody3D = wards[i]
		var beam: MeshInstance3D = ward_beams[i]
		if not is_instance_valid(w) or not is_instance_valid(beam):
			continue
		var start := w.global_position + Vector3(0, 0.5, 0)
		var diff := target - start
		var dist := diff.length()
		if dist < 0.05:
			beam.visible = false
			continue
		beam.visible = true
		beam.global_position = (start + target) * 0.5
		beam.scale = Vector3(1.0, dist, 1.0)
		var up_vec := Vector3.FORWARD if absf(diff.normalized().dot(Vector3.UP)) > 0.98 else Vector3.UP
		beam.look_at(target, up_vec)
		beam.rotate_object_local(Vector3.RIGHT, PI * 0.5)

func _change_stage(new_stage: int) -> void:
	_sound("portal")
	var old_stage := stage
	if is_instance_valid(level_root):
		remove_child(level_root)
		level_root.queue_free()
	level_root = Node3D.new()
	add_child(level_root)
	stage = new_stage
	enemies.clear()
	pickups.clear()
	bolts.clear()
	enemy_bolts.clear()
	active_shockwaves.clear()
	boss_phase = 0
	torches.clear()
	crypt_torches.clear()
	portal_nodes.clear()
	inscriptions.clear()
	breakables.clear()
	wards.clear()
	ward_beams.clear()
	pressure_plates.clear()
	water_channels.clear()
	pushable_blocks.clear()
	shootable_targets.clear()
	fonts.clear()
	water_spouts.clear()
	slag_zones.clear()
	boss = null
	gate = null
	switch_node = null
	shortcut_door = null
	tower_gear = null
	tower_cracked_wall = null
	tower_pendulum = null
	belfry_floorboards = null
	ward3_shutter = null
	aqueduct_valve = null
	ore_cart = null
	slag_dam = null
	trough_water = null
	key_mold = null
	hoist_lever = null
	great_gate_left = null
	great_gate_right = null
	bell_sequence_step = 0
	ambush_dark_timer = 0.0
	ambush_pending = false
	gate_open = level_states[0].gate_open

	Visuals.configure_environment(world_env, stage)
	held_body = null
	held_was_hurled.clear()
	match stage:
		0:
			LevelBuilder.build_sunken_court(self)
			player.position = Vector3(0, 0.1, -24.0) if old_stage == 1 else Vector3(0, 0.1, 30.0)
			narrative.show_chapter("CHAPTER I", "THE SUNKEN COURT", "The Cloister Remembers Your Passage")
		1:
			LevelBuilder.build_bell_tower(self)
			player.position = Vector3(0, 0.1, 18.0)
			narrative.show_chapter("CHAPTER II", "THE BELL TOWER", "Three Resonant Wards Bind Lord Malcor")
			narrative.say("LORD MALCOR (BELL WARDEN)", "You crossed the Sunken Court. Come then—listen to the three chimes of Vaelor before I silence you!", 5.5, Color("d99cbd"))
			_story_event("bell_tower_entry", "THE BELL TOWER", "The Warden cannot be slain while its three resonant wards sing. Explore the West Clockwork Gallery, East Pendulum Foundry, and North Choir Loft to break all three wards before ascending to the Belfry Sanctum.", "")
		2:
			LevelBuilder.build_kiln_of_ash(self)
			player.position = Vector3(0, 0.1, 19.5)
			narrative.show_chapter("CHAPTER III", "THE KILN OF ASH", "Where Vaelor Forged the Great Gate")
			narrative.say("SERAPHINA (RESONANT STONE)", "You're beneath the tower now! Flood the Crucible trough from the West Aqueduct, smash the East Smeltery dam with the ore-cart, and temper the Ashen Key.", 6.0, Color("70d7df"))
			_story_event("kiln_entry", "THE KILN OF ASH", "Beneath the tower lies the furnace that tempered the Gate's iron. Molten slag seals the main chamber. Divert the underground river, cool the crucible, and claim the Ashen Key.", "")
	player.velocity = Vector3.ZERO
	jump_buffer = 0.0
	coyote_time = 0.0
	footstep_time = 0.0
	landing_dip = 0.0
	view_kick = 0.0
	camera.rotation.x = 0
	head.rotation.z = 0
	hurt_cooldown = 0.0
	hitmarker_time = 0.0
	player.rotation.y = 0
	head.rotation.x = 0
	pitch = 0
	_objective()

func _objective() -> void:
	if stage == 0:
		labels.area.text = "ASHEN GATE    /    THE SUNKEN COURT"
		if gate_open:
			labels.goal.text = "OBJECTIVE: ENTER THE BELL TOWER"
		elif level_states[0].get("has_lever", false):
			labels.goal.text = "OBJECTIVE: ALIGN THE COURT SEALS"
		else:
			labels.goal.text = "OBJECTIVE: FIND THE IRON LEVER"
	elif stage == 1:
		labels.area.text = "ASHEN GATE    /    THE BELL TOWER"
		if level_states[1].boss_dead:
			labels.goal.text = "OBJECTIVE: DESCEND TO THE KILN OF ASH"
		elif wards.is_empty():
			labels.goal.text = "OBJECTIVE: DEFEAT THE BELL WARDEN"
		else:
			labels.goal.text = "OBJECTIVE: BREAK THE THREE WARDS (%d LEFT)" % wards.size()
	else:
		labels.area.text = "ASHEN GATE    /    THE KILN OF ASH"
		if level_states[2].get("great_gate_open", false):
			labels.goal.text = "ACT I COMPLETE"
		elif has_ashen_key:
			labels.goal.text = "OBJECTIVE: UNSEAL THE GREAT GATE"
		elif level_states[2].get("trough_flooded", false) and level_states[2].get("dam_broken", false):
			labels.goal.text = "OBJECTIVE: FORGE THE ASHEN KEY"
		else:
			labels.goal.text = "OBJECTIVE: RESTORE THE COOLING SLUICES"
	labels.boss.text = "BELL WARDEN   %d / 520" % boss.get_meta("hp") if stage == 1 and is_instance_valid(boss) else ""

func _update_prompt() -> void:
	labels.prompt.text = ""
	for font in fonts:
		if is_instance_valid(font) and player.position.distance_to(font.position + Vector3(0, 1.0, 0)) < 2.6:
			labels.prompt.text = "[ E ] REFILL FLASKS AT ALCHEMICAL FONT"
			return
	if stage == 0:
		if is_instance_valid(switch_node) and not gate_open and player.position.distance_to(switch_node.position + Vector3(0, 1.2, 0)) < 2.8:
			labels.prompt.text = "[ E ] PULL GATEHOUSE LEVER" if level_states[0].get("lever_inserted", false) else "[ E ] INSERT IRON LEVER" if level_states[0].get("has_lever", false) else "NEEDS IRON LEVER FROM EAST CRYPTS"
			return
		if is_instance_valid(shortcut_door) and not level_states[0].get("shortcut_open", false) and player.position.distance_to(shortcut_door.position + Vector3(0, 1.5, 0)) < 2.6:
			labels.prompt.text = "[ E ] UNBAR SHORTCUT DOOR" if player.position.x > 8.5 else "BARRED FROM THE EAST CRYPTS"
			return
	elif stage == 2:
		if is_instance_valid(aqueduct_valve) and not level_states[2].get("trough_flooded", false) and player.position.distance_to(aqueduct_valve.position + Vector3(0, 1.0, 0)) < 2.8:
			labels.prompt.text = "[ E ] TURN AQUEDUCT VALVE"
			return
		if is_instance_valid(hoist_lever) and not level_states[2].get("key_forged", false) and player.position.distance_to(hoist_lever.position + Vector3(0, 1.2, 0)) < 2.8:
			labels.prompt.text = "[ E ] PULL CHAIN HOIST LEVER"
			return
		if is_instance_valid(key_mold) and key_mold.visible and player.position.distance_to(key_mold.position) < 2.4:
			labels.prompt.text = "WHITE-HOT MOLD — COOL IN FLOODED TROUGH FIRST"
			return
		if not level_states[2].get("great_gate_open", false) and player.position.distance_to(Vector3(0, 1.5, -20.0)) < 3.8:
			labels.prompt.text = "[ E ] UNSEAL THE GREAT ASHEN GATE" if has_ashen_key else "SEALED — FORGE THE ASHEN KEY"
			return
	for inscription in inscriptions:
		if is_instance_valid(inscription.node) and player.position.distance_to(inscription.node.position + Vector3(0, 1, 0)) < 2.3:
			labels.prompt.text = "[ E ] READ %s" % inscription.title
			return
	for portal in portal_nodes:
		if is_instance_valid(portal.node) and player.position.distance_to(portal.node.position + Vector3(0, 1.4, 0)) < 2.8:
			labels.prompt.text = "[ E ] %s" % portal.label
			return

func _update_enemies(delta: float) -> void:
	for entry in enemies.duplicate():
		var enemy: CharacterBody3D = entry
		if not is_instance_valid(enemy):
			continue
		var elem: ElementalComponent = enemy.get_meta("elemental")
		var sprite: Sprite3D = enemy.get_meta("sprite")
		var warning: Node3D = enemy.get_meta("warning")
		var is_boss: bool = enemy.get_meta("boss")
		var kind: String = enemy.get_meta("kind")

		var elem_events := elem.tick(delta)
		if elem_events.burn_tick:
			_damage_enemy(enemy, 10, false)
			if not is_instance_valid(enemy) or not enemies.has(enemy):
				continue

		var guard: float = enemy.get_meta("guard")
		enemy.set_meta("guard", maxf(0.0, guard - delta))

		if elem.is_solid_frozen():
			warning.visible = false
			sprite.modulate = elem.status_tint()
			continue

		var stagger: float = enemy.get_meta("stagger")
		if stagger > 0.0:
			warning.visible = false
			enemy.set_meta("stagger", maxf(0.0, stagger - delta))
			var pre_speed := Vector2(enemy.velocity.x, enemy.velocity.z).length()
			enemy.velocity.x = move_toward(enemy.velocity.x, 0, delta * 12.0)
			enemy.velocity.z = move_toward(enemy.velocity.z, 0, delta * 12.0)
			enemy.velocity.y -= GRAVITY * delta
			enemy.move_and_slide()
			if pre_speed > 7.5 and enemy.is_on_wall() and not enemy.get_meta("wall_slammed", false):
				enemy.set_meta("wall_slammed", true)
				_spell_impact(enemy.global_position + Vector3(0, 1.0, 0), Color("d6c6a4"))
				camera_shake = maxf(camera_shake, 0.12)
				_message("WALL SLAM! +25 STAGGER DAMAGE", 1.5)
				_damage_enemy(enemy, 25, false)
				if not is_instance_valid(enemy) or not enemies.has(enemy):
					continue
			if stagger - delta <= 0.0:
				enemy.set_meta("wall_slammed", false)
			sprite.modulate = Color("ffb89a")
			continue

		if is_boss and player.global_position.z > -24.0:
			continue
		var to_player := player.global_position - enemy.global_position
		var distance := Vector2(to_player.x, to_player.z).length()
		var vertical_diff := absf(to_player.y)
		if distance >= 26.0 or (not is_boss and vertical_diff > 5.0):
			continue

		# Boss levitation in Phase 2
		if is_boss and boss_phase >= 1:
			enemy.position.y = lerpf(enemy.position.y, 9.4 + sin(elapsed * 2.6) * 0.45, delta * 2.5)

		if distance > 0.05:
			enemy.look_at(Vector3(player.global_position.x, enemy.global_position.y, player.global_position.z), Vector3.UP)
		var slow := elem.slow_multiplier()
		var windup: float = enemy.get_meta("windup")
		if windup > 0.0:
			warning.visible = true
			windup -= delta * slow
			enemy.set_meta("windup", maxf(0.0, windup))
			enemy.velocity.x = move_toward(enemy.velocity.x, 0, delta * 14.0)
			enemy.velocity.z = move_toward(enemy.velocity.z, 0, delta * 14.0)
			sprite.modulate = Color("d887e7") if is_boss or kind == "acolyte" else Color("ff8e75")
			sprite.scale = Vector3.ONE * (1.0 + sin(elapsed * 25.0) * 0.025)
			if not (is_boss and boss_phase >= 1):
				enemy.velocity.y -= GRAVITY * delta
				enemy.move_and_slide()
			if windup <= 0.0:
				warning.visible = false
				var pending: String = enemy.get_meta("pending")
				if pending == "melee" and distance < (4.0 if is_boss else 2.7):
					_hurt(24 if is_boss else 20 if kind == "ash_sentinel" else 16 if kind == "executioner" else 11, enemy.global_position)
					camera_shake = maxf(camera_shake, 0.16)
				elif pending == "cast":
					_enemy_cast(enemy, false)
				elif pending == "tolling_wave":
					_spawn_tolling_wave(enemy.global_position)
				elif pending == "dread_summon":
					_sound("bell")
					_enemy(Vector3(-8.5, 7.1, -43.0), false, "warden_shr_%d_a" % int(elapsed * 10), false, "shrieker")
					_enemy(Vector3(8.5, 7.1, -43.0), false, "warden_shr_%d_b" % int(elapsed * 10), false, "shrieker")
					_message("THE WARDEN TOLLS HIS BELLS — SHRIEKERS RISE!", 2.5)
				elif pending == "boss_triple":
					_enemy_cast_triple(enemy)
				enemy.set_meta("pending", "")
				enemy.set_meta("attack", 1.7 if is_boss and boss_phase > 0 else 2.3 if is_boss else 2.1 if kind == "acolyte" else 1.7 if kind == "ash_sentinel" else 1.5 if kind == "executioner" else 1.25)
				sprite.modulate = elem.status_tint() if elem.is_frozen() or elem.is_burning() else (Color("c96f4b") if kind == "ash_sentinel" else Color.WHITE)
				sprite.scale = Vector3.ONE
			continue

		sprite.modulate = elem.status_tint() if elem.is_frozen() or elem.is_burning() else (Color("c96f4b") if kind == "ash_sentinel" else Color.WHITE)
		sprite.scale = Vector3.ONE
		warning.visible = false
		var horizontal := Vector3(to_player.x, 0, to_player.z).normalized()
		var base_speed := 2.0 if is_boss else 2.1 if kind == "ash_sentinel" else 2.35 if kind == "executioner" else 2.2 if kind == "acolyte" else 4.1
		var move_speed := base_speed * slow
		var desired := Vector3.ZERO
		if kind == "acolyte":
			if distance < 4.5:
				desired = -horizontal * move_speed
			elif distance > 9.0:
				desired = horizontal * move_speed
		elif distance > (3.5 if is_boss else 1.85):
			desired = horizontal * move_speed
		enemy.velocity.x = move_toward(enemy.velocity.x, desired.x, delta * 10.0)
		enemy.velocity.z = move_toward(enemy.velocity.z, desired.z, delta * 10.0)
		if not (is_boss and boss_phase >= 1):
			enemy.velocity.y -= GRAVITY * delta
			enemy.move_and_slide()

		var attack: float = enemy.get_meta("attack") - delta * slow
		if attack <= 0.0:
			var next_attack := ""
			if kind == "acolyte" and distance < 18.0:
				next_attack = "cast"
			elif is_boss:
				if boss_phase >= 1:
					next_attack = "boss_triple"
				else:
					var roll := rng.randf()
					if roll < 0.55:
						next_attack = "tolling_wave"
					elif roll < 0.78 and enemies.size() < 4:
						next_attack = "dread_summon"
					else:
						next_attack = "melee" if distance < 4.0 else "tolling_wave"
			elif distance < 2.35:
				next_attack = "melee"
			if next_attack != "":
				enemy.set_meta("pending", next_attack)
				enemy.set_meta("windup", 0.65 if next_attack == "tolling_wave" else 0.55 if is_boss else 0.52 if kind == "executioner" or kind == "ash_sentinel" else 0.44 if kind == "acolyte" else 0.32)
				attack = 0.0
		enemy.set_meta("attack", attack)

		# Boss Phase 2 transition at <= 260 HP
		if is_boss and enemy.get_meta("hp") <= 260 and boss_phase == 0:
			boss_phase = 1
			world_env.background_color = Color("0a0612")
			world_env.fog_light_color = Color("251835")
			_sound("bell")
			_message("PHASE II — THE SKY DARKENS! REFLECT SONIC ORBS WITH Q REPULSE!", 4.0)

func _spawn_tolling_wave(origin: Vector3) -> void:
	_sound("bell")
	camera_shake = maxf(camera_shake, 0.22)
	var wave := MeshInstance3D.new()
	wave.name = "tolling_wave"
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.86
	mesh.outer_radius = 1.0
	wave.mesh = mesh
	wave.material_override = mats.cinder
	wave.position = Vector3(origin.x, 7.15, origin.z)
	level_root.add_child(wave)
	active_shockwaves.append({"node": wave, "origin": wave.position, "radius": 1.0, "max_radius": 15.0, "speed": 9.0, "hit_player": false})

func _update_shockwaves(delta: float) -> void:
	for sw in active_shockwaves.duplicate():
		var node: Node3D = sw.node
		if not is_instance_valid(node):
			active_shockwaves.erase(sw)
			continue
		sw.radius += sw.speed * delta
		node.scale = Vector3(sw.radius, 1.0, sw.radius)
		var pdist := Vector2(player.global_position.x - sw.origin.x, player.global_position.z - sw.origin.z).length()
		if not sw.hit_player and absf(pdist - sw.radius) < 0.85 and player.global_position.y < sw.origin.y + 0.65:
			sw.hit_player = true
			_hurt(22, sw.origin, Color("e75528"))
			_message("JUMP OVER THE TOLLING WAVE!", 1.4)
		if sw.radius >= sw.max_radius:
			node.queue_free()
			active_shockwaves.erase(sw)

func _spell_orb(pos: Vector3, kind: String, powerful: bool = false) -> Node3D:
	var orb := Node3D.new()
	orb.name = kind + "_proj"
	level_root.add_child(orb)
	orb.global_position = pos
	var color := Color("bd69f3") if kind == "curse" else Color("88e9f5") if kind == "frost" else Color("ff7828") if kind == "cinder" else Color("5be38c") if kind == "arbalest" else Color("61dbed")
	orb.set_meta("color", color)
	orb.set_meta("trail_time", 0.0)
	var core := MeshInstance3D.new()
	if kind == "arbalest":
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.05
		cyl.bottom_radius = 0.05
		cyl.height = 0.7
		core.mesh = cyl
		core.rotation.x = PI * 0.5
		core.material_override = mats.acid
	else:
		var sphere := SphereMesh.new()
		sphere.radius = 0.30 if powerful else 0.22 if kind == "cinder" or kind == "curse" else 0.18
		sphere.height = sphere.radius * 2.0
		sphere.radial_segments = 10
		sphere.rings = 6
		core.mesh = sphere
		core.material_override = mats.portal if kind == "curse" else mats.ice if kind == "frost" else mats.cinder if kind == "cinder" else mats.mana
	orb.add_child(core)
	var glow := Sprite3D.new()
	glow.texture = spell_glow_texture
	glow.pixel_size = 0.052 if powerful else 0.038
	glow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	glow.shaded = false
	glow.modulate = Color(color.r, color.g, color.b, 0.72)
	orb.add_child(glow)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.4 if powerful else 0.8
	light.omni_range = 3.2 if powerful else 2.2
	orb.add_child(light)
	return orb

func _spell_trail(pos: Vector3, color: Color, size: float = 0.023) -> void:
	var trail := Sprite3D.new()
	trail.name = "spell_afterimage"
	trail.texture = spell_glow_texture
	trail.pixel_size = size
	trail.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	trail.shaded = false
	trail.modulate = color
	trail.position = pos
	level_root.add_child(trail)
	var tween := create_tween().bind_node(trail)
	tween.tween_property(trail, "transparency", 1.0, 0.22)
	tween.tween_callback(trail.queue_free)

func _spell_impact(pos: Vector3, color: Color) -> void:
	Visuals.spawn_impact_light(level_root, pos, color, 3.0, 6.5, 0.22)
	for i in 6:
		var offset := Vector3(rng.randf_range(-0.65, 0.65), rng.randf_range(-0.45, 0.45), rng.randf_range(-0.65, 0.65))
		var spark := Sprite3D.new()
		spark.texture = spell_glow_texture
		spark.pixel_size = 0.02
		spark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		spark.shaded = false
		spark.modulate = color
		spark.position = pos
		level_root.add_child(spark)
		var tween := create_tween().bind_node(spark)
		tween.set_parallel(true)
		tween.tween_property(spark, "position", pos + offset, 0.28)
		tween.tween_property(spark, "transparency", 1.0, 0.28)
		tween.set_parallel(false)
		tween.tween_callback(spark.queue_free)

func _shockwave(pos: Vector3, color: Color, radius: float) -> void:
	var wave := MeshInstance3D.new()
	wave.name = "expanding_magic_wave"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 0.025
	mesh.radial_segments = 28
	wave.mesh = mesh
	var material := _material(Color(color.r, color.g, color.b, 0.28), true)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wave.material_override = material
	wave.position = pos
	level_root.add_child(wave)
	var tween := create_tween().bind_node(wave)
	tween.set_parallel(true)
	tween.tween_property(wave, "scale", Vector3(radius, 1, radius), 0.36)
	tween.tween_property(wave, "transparency", 1.0, 0.36)
	tween.set_parallel(false)
	tween.tween_callback(wave.queue_free)

func _step_spell_trail(node: Node3D, delta: float) -> void:
	var timer: float = node.get_meta("trail_time") - delta
	if timer <= 0.0:
		_spell_trail(node.global_position, node.get_meta("color"))
		timer = 0.055
	node.set_meta("trail_time", timer)

func _enemy_cast(source: CharacterBody3D, powerful: bool) -> void:
	var orb := _spell_orb(source.global_position + Vector3(0, 2.5 if powerful else 1.65, 0), "curse", powerful)
	var direction := (camera.global_position - orb.global_position).normalized()
	enemy_bolts.append({"node": orb, "source": source, "direction": direction, "life": 4.0, "speed": 9.5 if powerful else 8.8, "damage": 18 if powerful else 12, "homing": not powerful})
	_sound("cast")

func _enemy_cast_triple(source: CharacterBody3D) -> void:
	var origin := source.global_position + Vector3(0, 2.2, 0)
	var base_dir := (camera.global_position - origin).normalized()
	for angle in [-0.24, 0.0, 0.24]:
		var dir := base_dir.rotated(Vector3.UP, angle)
		var orb := _spell_orb(origin, "curse", true)
		enemy_bolts.append({"node": orb, "source": source, "direction": dir, "life": 4.2, "speed": 10.5, "damage": 16, "homing": false})
	_sound("cast")

func _update_enemy_bolts(delta: float) -> void:
	for bolt in enemy_bolts.duplicate():
		var node: Node3D = bolt.node
		if not is_instance_valid(node):
			enemy_bolts.erase(bolt)
			continue
		_step_spell_trail(node, delta)
		if bolt.get("homing", false):
			var desired := (camera.global_position - node.global_position).normalized()
			bolt.direction = bolt.direction.lerp(desired, minf(1.0, delta * 1.4)).normalized()
		var from: Vector3 = node.global_position
		var to: Vector3 = from + bolt.direction * bolt.speed * delta
		var query := PhysicsRayQueryParameters3D.create(from, to, LAYER_WORLD | LAYER_PUSHABLE | LAYER_PLAYER)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			if hit.collider == player:
				_hurt(bolt.damage, node.global_position, Color("bd69f3"))
			_spell_impact(hit.position, node.get_meta("color"))
			node.queue_free()
			enemy_bolts.erase(bolt)
			continue
		node.global_position = to
		bolt.life -= delta
		if bolt.life <= 0.0:
			_spell_impact(node.global_position, node.get_meta("color"))
			node.queue_free()
			enemy_bolts.erase(bolt)

func _update_bolts(delta: float) -> void:
	for bolt in bolts.duplicate():
		var node: Node3D = bolt.node
		if not is_instance_valid(node):
			bolts.erase(bolt)
			continue
		_step_spell_trail(node, delta)
		var from: Vector3 = node.global_position
		var grav: float = bolt.get("gravity", 0.0)
		var vel: Vector3 = bolt.get("velocity", bolt.direction * (32.0 if bolt.kind == "reflected" else 26.0))
		vel.y -= grav * delta
		bolt.velocity = vel
		var to: Vector3 = from + vel * delta
		var query := PhysicsRayQueryParameters3D.create(from, to, LAYER_WORLD | LAYER_ENEMY | LAYER_PUSHABLE | LAYER_TARGET)
		query.exclude = [player.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			_resolve_bolt_hit(bolt, hit)
			node.queue_free()
			bolts.erase(bolt)
			continue
		node.global_position = to
		bolt.life -= delta
		if bolt.life <= 0.0:
			if bolt.kind == "cinder":
				_cinder_aoe_burst(node.global_position)
			else:
				_spell_impact(node.global_position, node.get_meta("color"))
			node.queue_free()
			bolts.erase(bolt)

func _resolve_bolt_hit(bolt: Dictionary, hit: Dictionary) -> void:
	var col = hit.collider
	var hit_pos: Vector3 = hit.position
	if bolt.kind == "cinder":
		_cinder_aoe_burst(hit_pos)
		return
	if bolt.kind == "frost":
		_handle_frost_world_hit(col, hit_pos)
	if col is CharacterBody3D and enemies.has(col):
		if bolt.kind == "arbalest" and col.get_meta("kind") == "executioner" and float(col.get_meta("stagger")) <= 0.0 and not col.get_meta("elemental").is_frozen() and float(col.get_meta("guard")) <= 0.0:
			col.set_meta("guard", 1.8)
			_sound("hit")
			_message("IRON EXECUTIONER BLOCKS THE BOLT WITH HIS CLEAVER!", 1.5)
		elif bolt.kind == "frost":
			_apply_frost_to_enemy(col)
		elif bolt.kind == "reflected":
			_damage_enemy(col, 55)
			if is_instance_valid(col) and col.get_meta("boss"):
				col.set_meta("stagger", 3.0)
				_message("REFLECTED ORB STUNS THE BELL WARDEN FOR 3 SECONDS!", 2.5)
		else:
			_damage_enemy(col, 40)
			if is_instance_valid(col) and col.get_meta("kind") == "shrieker":
				col.velocity += bolt.velocity.normalized() * 10.0
	elif col is RigidBody3D and breakables.has(col):
		_smash_pot(col)
	elif col is StaticBody3D and wards.has(col):
		_shatter_ward(col)
	elif col is Node3D and shootable_targets.has(col):
		_hit_shootable_target(col, bolt.kind)
	_spell_impact(hit_pos, bolt.node.get_meta("color"))

func _apply_frost_to_enemy(enemy: CharacterBody3D) -> void:
	var elem: ElementalComponent = enemy.get_meta("elemental")
	var low_hp: bool = int(enemy.get_meta("hp")) <= int(enemy.get_meta("max_hp")) * 0.5
	var res := elem.apply_frost(5.0 if not enemy.get_meta("boss") else 2.2, low_hp)
	_damage_enemy(enemy, 16)
	if res.thermal_shock and is_instance_valid(enemy) and enemies.has(enemy):
		_trigger_thermal_shock(enemy)
	elif is_instance_valid(enemy) and enemies.has(enemy):
		enemy.get_meta("sprite").modulate = elem.status_tint()
		if elem.is_solid_frozen():
			_message("FROZEN SOLID — STRIKE WITH AXE TO SHATTER!", 1.6)

func _trigger_thermal_shock(enemy: CharacterBody3D) -> void:
	_sound("frost")
	_sound("maul")
	_shockwave(enemy.global_position + Vector3(0, 0.8, 0), Color("88e9f5"), 3.8)
	_spell_impact(enemy.global_position + Vector3(0, 1.2, 0), Color("ff9352"))
	_message("THERMAL SHOCK! +75 BONUS DAMAGE!", 2.0)
	_damage_enemy(enemy, 75)

func _cinder_aoe_burst(pos: Vector3) -> void:
	_sound("maul")
	_shockwave(pos + Vector3(0, 0.1, 0), Color("ff6e24"), 4.2)
	_spell_impact(pos, Color("ff7828"))
	Visuals.spawn_decal(level_root, pos, "scorch", 2.8)
	camera_shake = maxf(camera_shake, 0.16)
	for entry in enemies.duplicate():
		var e: CharacterBody3D = entry
		if is_instance_valid(e) and e.global_position.distance_to(pos) < 4.5:
			var elem: ElementalComponent = e.get_meta("elemental")
			var res := elem.apply_burn(5.0)
			_damage_enemy(e, 46)
			if res.thermal_shock and is_instance_valid(e) and enemies.has(e):
				_trigger_thermal_shock(e)
	for pot in breakables.duplicate():
		if is_instance_valid(pot) and pot.global_position.distance_to(pos) < 4.2:
			_smash_pot(pot)
	for w in wards.duplicate():
		if is_instance_valid(w) and w.global_position.distance_to(pos) < 4.2:
			_shatter_ward(w)

func _handle_frost_world_hit(col: Object, hit_pos: Vector3) -> void:
	# Level 1 rushing water channel -> freeze 12s!
	if stage == 0:
		for ch in water_channels:
			if col == ch.node or hit_pos.distance_to(ch.pos) < 3.4:
				ch.frozen_timer = 12.0
				ch.node.get_child(0).material_override = mats.ice
				_sound("frost")
				_message("WATER CHANNEL FROZEN FOR 12 SECONDS!", 2.2)
				return
	# Level 2 steam pipe -> freeze cogwheel!
	if stage == 1 and col is Node3D and (col.get_meta("steam_pipe", false) or col == tower_gear):
		if not level_states[1].get("gear_frozen", false):
			level_states[1].gear_frozen = true
			if is_instance_valid(tower_gear):
				tower_gear.get_child(0).material_override = mats.ice
				tower_gear.collision_layer = 0
				create_tween().bind_node(tower_gear).tween_property(tower_gear, "position:y", -2.5, 0.45)
			_sound("frost")
			_message("STEAM PIPE FROZEN  •  COGWHEEL JAMMED! SHATTER WARD 1!", 3.2)
			return
	# Level 3 water spouts -> freeze into walkable 12s ice bridges!
	if stage == 2 and col is StaticBody3D and col.get_meta("water_spout", false):
		col.set_meta("frozen_timer", 12.0)
		col.collision_layer = LAYER_WORLD | LAYER_TARGET
		col.get_child(0).material_override = mats.ice
		col.get_meta("stream").get_child(0).material_override = mats.ice
		_sound("frost")
		_message("ICE BRIDGE FORMED FOR 12 SECONDS!", 1.8)

func _hit_shootable_target(target: Node3D, bolt_kind: String) -> void:
	# Level 1 Counterweight Cage Rope
	if target.get_meta("shootable_rope", false):
		var cage: Node3D = target.get_meta("cage")
		var drop_pos := Vector3(cage.global_position.x, 0.75, cage.global_position.z)
		shootable_targets.erase(target)
		target.queue_free()
		cage.queue_free()
		level_states[0].cage_dropped = true
		LevelBuilder.add_pushable_block(self, drop_pos, "counterweight_east", Vector3(1.4, 1.2, 1.4), mats.iron)
		_sound("land")
		camera_shake = maxf(camera_shake, 0.22)
		_message("COUNTERWEIGHT BLOCK DROPPED INTO THE COURTYARD!", 3.0)
		return
	# Level 2 Tier 3 Harmonic Hand-Bells (Crescent -> Crown -> Skull)
	if target.get_meta("harmonic_bell", false):
		var idx: int = target.get_meta("bell_idx")
		var bname: String = target.get_meta("bell_name")
		var bpitch: float = target.get_meta("bell_pitch")
		_sound("bell", bpitch)
		if idx == bell_sequence_step:
			bell_sequence_step += 1
			_message("CHIME %d/3: %s RESONATES!" % [bell_sequence_step, bname], 2.0)
			if bell_sequence_step >= 3:
				if is_instance_valid(ward3_shutter):
					ward3_shutter.collision_layer = 0
					create_tween().bind_node(ward3_shutter).tween_property(ward3_shutter, "position:y", 6.5, 0.5)
				for w in wards.duplicate():
					if is_instance_valid(w) and w.get_meta("id") == "ward_3":
						_shatter_ward(w)
				_message("HARMONIC SEQUENCE COMPLETE  •  WARD 3 SHATTERED!", 3.2)
		else:
			bell_sequence_step = 0
			_message("DISCORDANT CHIME — RESET! (CRESCENT → CROWN → SKULL)", 2.4)
		return
	# Level 3 Suspended Slag Cauldron Chains
	if target.get_meta("cauldron_chain", false):
		var cauldron: Node3D = target.get_meta("cauldron")
		var cid: String = target.get_meta("id")
		var impact_pos := Vector3(cauldron.global_position.x, 0.3, cauldron.global_position.z)
		shootable_targets.erase(target)
		target.queue_free()
		level_states[2].dropped_cauldrons.append(cid)
		var tw := create_tween().bind_node(cauldron)
		tw.tween_property(cauldron, "position:y", 0.5, 0.22)
		tw.tween_callback(func() -> void:
			_sound("maul")
			camera_shake = maxf(camera_shake, 0.35)
			_shockwave(impact_pos, Color("ff5c1a"), 4.2)
			for e in enemies.duplicate():
				if is_instance_valid(e) and Vector2(e.global_position.x - impact_pos.x, e.global_position.z - impact_pos.z).length() < 4.2:
					_damage_enemy(e, 300)
					_message("CRUSHED BY FALLING SLAG CAULDRON!", 2.5)
			cauldron.queue_free()
		)
		return
	if bolt_kind == "frost":
		_handle_frost_world_hit(target, target.global_position)

func _update_pickups(delta: float) -> void:
	for item in pickups.duplicate():
		var node: Node3D = item.node
		if not is_instance_valid(node):
			pickups.erase(item)
			continue
		node.rotation.y += delta * 1.8
		node.position.y = item.y + sin(elapsed * 3.0 + item.y) * 0.08
		if player.global_position.distance_to(node.global_position) < 1.65:
			match item.kind:
				"mana":
					mana = mini(max_mana, mana + 35)
					_message("BLUE MANA +35", 1.6)
				"green":
					green_mana = mini(max_mana, green_mana + 30)
					_message("GREEN MANA +30", 1.6)
				"flask":
					flasks = mini(5, flasks + 1)
					_message("ALCHEMICAL FLASK +1", 1.6)
				"relic_heart":
					max_hp = 135
					hp = max_hp
					_story_event("relic_heart", "ASHEN RELIC: HEART OF VAELOR", "A crystallized ember-heart from the First Order. Permanently raises Max Health to 135 and restores you to full strength.", "ASHEN RELIC: HEART OF VAELOR  •  MAX HEALTH 135!")
				"relic_siphon":
					max_mana = 135
					mana = max_mana
					green_mana = max_mana
					mana_regen_rate = 2.0
					_story_event("relic_siphon", "ASHEN RELIC: SIPHON SIGNET", "An arcane ring of the Bell Choir. Permanently raises Max Mana to 135 and grants steady Blue & Green Mana regeneration.", "ASHEN RELIC: SIPHON SIGNET  •  MAX MANA 135 + REGEN!")
				"relic_oath":
					damage_mult = 1.25
					_story_event("relic_oath", "ASHEN RELIC: CINDER-BREAKER'S OATH", "The vow of the original vanguard. Permanently boosts all melee & spell damage by +25% and shortens Aether Dash cooldown.", "ASHEN RELIC: CINDER-BREAKER'S OATH  •  +25% DAMAGE & FASTER DASH!")
				"iron_lever":
					level_states[0].has_lever = true
					_message("IRON LEVER ACQUIRED  •  INSERT AT NORTH GEARBOX", 3.5)
					if not level_states[0].get("ambush_done", false):
						level_states[0].ambush_done = true
						ambush_dark_timer = 2.0
						ambush_pending = true
						_message("THE EAST CRYPT SCONCES SNUFF OUT...", 2.0)
					_objective()
				"arbalest":
					has_arbalest = true
					mode = 1
					_build_weapon()
					_story_event("arbalest_unlock", "THE BRIAR ARBALEST", "Heavy spectral-iron bolts (5 Green Mana) with parabolic drop. Shoot distant ropes, cauldron chains, and harmonic bells.", "BRIAR ARBALEST ACQUIRED  •  PRESS 2")
				"thurible":
					has_thurible = true
					mode = 2
					_build_weapon()
					_story_event("thurible_unlock", "THE CINDER THURIBLE", "Chained brass censer (10 Blue + 10 Green Mana) that lobs burning ember-oil. Ignites frozen foes for massive Thermal Shock!", "CINDER THURIBLE ACQUIRED  •  PRESS 3")
				"ashen_key":
					has_ashen_key = true
					_objective()
					_trigger_kiln_gauntlet()
			_refresh_hud_numbers()
			level_states[stage].taken.append(item.id)
			_sound("pickup")
			node.queue_free()
			pickups.erase(item)

func _trigger_kiln_gauntlet() -> void:
	if level_states[2].get("gauntlet_triggered", false):
		return
	level_states[2].gauntlet_triggered = true
	_sound("bell", 0.65)
	camera_shake = maxf(camera_shake, 0.30)
	_message("FOUNDRY ALARM! SLAG GRATES RISE — SURVIVE THE GAUNTLET & UNSEAL THE GREAT GATE!", 5.0)
	# 2 Ash Sentinels, 2 Iron Executioners, 3 Cinder Acolytes
	_enemy(Vector3(-3.8, 0.1, 2.0), true, "gauntlet_ash_1", false, "ash_sentinel")
	_enemy(Vector3(3.8, 0.1, -11.5), true, "gauntlet_ash_2", false, "ash_sentinel")
	_enemy(Vector3(-5.2, 0.1, -8.0), true, "gauntlet_exec_1", false, "executioner")
	_enemy(Vector3(5.2, 0.1, 4.0), true, "gauntlet_exec_2", false, "executioner")
	_enemy(Vector3(-12.0, 4.2, -10.0), false, "gauntlet_aco_1", false, "acolyte")
	_enemy(Vector3(12.0, 0.1, -4.0), false, "gauntlet_aco_2", false, "acolyte")
	_enemy(Vector3(0.0, 0.1, -15.5), false, "gauntlet_aco_3", false, "acolyte")

func _update_breakables() -> void:
	for pot in breakables.duplicate():
		if is_instance_valid(pot) and not pot.freeze and pot.linear_velocity.length() > 7.5 and not pot.get_colliding_bodies().is_empty():
			_smash_pot(pot)

func _update_particles(delta: float) -> void:
	for particle in particles:
		if not is_instance_valid(particle.node):
			continue
		var node: Node3D = particle.node
		node.position.x = particle.base_x + sin(elapsed * particle.speed + particle.phase) * 0.7
		node.position.y += delta * (0.7 if particle.kind == "ember" else -0.6)
		if node.position.y > 7.8:
			node.position.y = 0.2
		elif node.position.y < 0.2:
			node.position.y = 7.6

func _attack() -> void:
	if cooldown > 0.0:
		return
	if mode == 0:
		cooldown = 0.44
		swing_time = 0.44
		swing_contact_done = false
	elif mode == 1:
		if green_mana < 5:
			_message("NOT ENOUGH GREEN MANA (NEEDS 5)", 1.2)
			return
		green_mana -= 5
		_refresh_hud_numbers()
		cooldown = 0.42
		arbalest_recoil = 1.0
		_sound("cast", 1.25)
		var dir := -camera.global_transform.basis.z
		var bolt := _spell_orb(camera.global_position + dir * 0.75, "arbalest")
		bolts.append({"node": bolt, "direction": dir, "velocity": dir * 32.0 + Vector3(0, 1.2, 0), "gravity": 9.0, "life": 2.4, "kind": "arbalest"})
	else:
		if mana < 10 or green_mana < 10:
			_message("CINDER THURIBLE NEEDS 10 BLUE + 10 GREEN MANA", 1.5)
			return
		mana -= 10
		green_mana -= 10
		_refresh_hud_numbers()
		cooldown = 0.72
		thurible_time = 0.72
		thurible_release_done = false

func _thurible_release() -> void:
	_sound("maul", 1.25)
	view_kick = -0.07
	var dir := -camera.global_transform.basis.z
	var orb := _spell_orb(camera.global_position + dir * 0.75, "cinder")
	bolts.append({"node": orb, "direction": dir, "velocity": dir * 18.0 + Vector3(0, 4.8, 0), "gravity": 14.0, "life": 2.2, "kind": "cinder"})

func _frost_cast() -> void:
	if cooldown > 0.0 or hp <= 0:
		return
	if mana < 10:
		_message("NOT ENOUGH BLUE MANA FOR FROST (NEEDS 10)", 1.2)
		return
	mana -= 10
	_refresh_hud_numbers()
	cooldown = 0.48
	_sound("frost")
	var dir := -camera.global_transform.basis.z
	var bolt := _spell_orb(camera.global_position + dir * 0.7, "frost")
	bolts.append({"node": bolt, "direction": dir, "velocity": dir * 28.0, "gravity": 0.0, "life": 1.8, "kind": "frost"})

func _repulse() -> void:
	if cooldown > 0.0 or hp <= 0:
		return
	if mana < 15:
		_message("NOT ENOUGH BLUE MANA FOR REPULSE (NEEDS 15)", 1.2)
		return
	mana -= 15
	_refresh_hud_numbers()
	cooldown = 0.45
	_sound("repulse")
	_shockwave(player.global_position + Vector3(0, 0.12, 0), Color("61dbed"), 6.5)
	camera_shake = maxf(camera_shake, 0.12)

	var forward := -camera.global_transform.basis.z
	var flat_fwd := Vector3(forward.x, 0, forward.z).normalized()
	if flat_fwd.length() < 0.01:
		flat_fwd = -player.global_transform.basis.z

	# Query cone-shaped ShapeCast3D for enemies, pushable puzzle props, and debris
	var hit_bodies: Array = []
	if is_instance_valid(repulse_cast):
		repulse_cast.force_shapecast_update()
		for i in repulse_cast.get_collision_count():
			var c := repulse_cast.get_collider(i)
			if c != null and not hit_bodies.has(c):
				hit_bodies.append(c)

	# Also include close-range directional cone fallback so point-blank pushes always register
	for e in enemies.duplicate():
		if is_instance_valid(e) and not hit_bodies.has(e) and e.global_position.distance_to(player.global_position) < 6.8:
			var to_e: Vector3 = (e.global_position - player.global_position).normalized()
			if to_e.dot(flat_fwd) > 0.2 or e.global_position.distance_to(player.global_position) < 2.6:
				hit_bodies.append(e)
	for blk in pushable_blocks:
		if is_instance_valid(blk) and not hit_bodies.has(blk) and blk.global_position.distance_to(player.global_position) < 6.8:
			hit_bodies.append(blk)
	if is_instance_valid(tower_pendulum) and not hit_bodies.has(tower_pendulum) and tower_pendulum.global_position.distance_to(player.global_position) < 7.2:
		hit_bodies.append(tower_pendulum)
	for pot in breakables:
		if is_instance_valid(pot) and not hit_bodies.has(pot) and pot.global_position.distance_to(player.global_position) < 6.5:
			hit_bodies.append(pot)

	for body in hit_bodies:
		if not is_instance_valid(body):
			continue
		if body is CharacterBody3D and enemies.has(body):
			var push_dir: Vector3 = body.global_position - player.global_position
			push_dir.y = 0
			push_dir = push_dir.normalized() if push_dir.length() > 0.01 else flat_fwd
			body.velocity += push_dir * (7.5 if body.get_meta("boss") else 16.5) + Vector3.UP * 3.0
			_damage_enemy(body, 15)
			parry_window = 1.6
		elif body == tower_pendulum:
			_hit_tower_pendulum()
		elif body is RigidBody3D and body.get_meta("ore_cart", false):
			body.apply_central_impulse(Vector3(0, 0, -52.0))
			_message("ORE-CART SURGES DOWN THE RAILS!", 1.8)
		elif body is RigidBody3D and body.get_meta("pushable_block", false):
			body.apply_central_impulse(flat_fwd * 32.0 + Vector3.UP * 2.5)
		elif body is RigidBody3D and breakables.has(body):
			if body.freeze:
				_smash_pot(body)
			else:
				body.apply_central_impulse(flat_fwd * 10.0 + Vector3.UP * 2.5)
		elif body is RigidBody3D and body.collision_layer == LAYER_DEBRIS:
			body.apply_central_impulse(flat_fwd * 9.0 + Vector3.UP * 3.0)

	# Deflect incoming projectiles!
	var reflected := 0
	for bolt in enemy_bolts.duplicate():
		if not is_instance_valid(bolt.node):
			enemy_bolts.erase(bolt)
			continue
		if bolt.node.global_position.distance_to(player.global_position) > 8.5:
			continue
		var target_enemy: CharacterBody3D = bolt.source if is_instance_valid(bolt.source) and enemies.has(bolt.source) else null
		if target_enemy == null and not enemies.is_empty():
			target_enemy = enemies[0]
		if target_enemy != null:
			var rdir: Vector3 = (target_enemy.global_position + Vector3(0, 1.4, 0) - bolt.node.global_position).normalized()
			bolts.append({"node": bolt.node, "direction": rdir, "velocity": rdir * 32.0, "gravity": 0.0, "life": 1.8, "kind": "reflected"})
			bolt.node.get_child(0).material_override = mats.mana
			bolt.node.get_child(1).modulate = Color("61dbed")
			bolt.node.set_meta("color", Color("61dbed"))
			reflected += 1
			parry_window = 2.0
		else:
			bolt.node.queue_free()
		enemy_bolts.erase(bolt)
	_message("REPULSE  •  %d ORBS REFLECTED!" % reflected if reflected > 0 else "TELEKINETIC REPULSE", 1.4)

func _hit_tower_pendulum() -> void:
	if not is_instance_valid(tower_pendulum):
		return
	var hits: int = int(tower_pendulum.get_meta("hits")) + 1
	tower_pendulum.set_meta("hits", hits)
	_sound("bell", 0.72 + hits * 0.14)
	var base_pos: Vector3 = tower_pendulum.get_meta("base_pos")
	var tw := create_tween().bind_node(tower_pendulum)
	if hits < 2:
		tw.tween_property(tower_pendulum, "position:x", base_pos.x + 2.1, 0.25)
		tw.tween_property(tower_pendulum, "position:x", base_pos.x - 0.8, 0.30)
		tw.tween_property(tower_pendulum, "position:x", base_pos.x, 0.25)
		_message("PENDULUM MOMENTUM BUILDING (1/2) — REPULSE AGAIN!", 2.4)
	else:
		tw.tween_property(tower_pendulum, "position:x", base_pos.x + 3.0, 0.22)
		tw.tween_callback(func() -> void:
			_sound("maul")
			camera_shake = maxf(camera_shake, 0.30)
			if is_instance_valid(tower_cracked_wall):
				var wpos := tower_cracked_wall.global_position
				tower_cracked_wall.queue_free()
				for i in 8:
					_debris_piece(wpos + Vector3(0, rng.randf_range(-0.6, 0.8), rng.randf_range(-1, 1)), Vector3(0.24, 0.24, 0.24), mats.clay, Vector3(rng.randf_range(1, 5), rng.randf_range(1, 4), rng.randf_range(-2, 2)))
			for w in wards.duplicate():
				if is_instance_valid(w) and w.get_meta("id") == "ward_2":
					_shatter_ward(w)
			_message("PENDULUM SHATTERS THE CRACKED WALL AND WARD 2!", 3.2)
		)
		tw.tween_property(tower_pendulum, "position:x", base_pos.x, 0.45)

func _axe_contact() -> void:
	_sound("axe")
	var from := camera.global_position
	var to := from + -camera.global_transform.basis.z * 3.4
	var query := PhysicsRayQueryParameters3D.create(from, to, LAYER_WORLD | LAYER_ENEMY | LAYER_PUSHABLE | LAYER_TARGET)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var col = hit.collider
	if col is CharacterBody3D and enemies.has(col):
		hitstop_time = 0.035 # 35ms melee hitstop!
		var elem: ElementalComponent = col.get_meta("elemental")
		var dmg := 44
		if elem.is_solid_frozen():
			dmg = 120
			elem.clear_all()
			_sound("frost")
			_message("FROZEN FOE SHATTERED!", 1.5)
		elif parry_window > 0.0:
			dmg = int(72.0 * damage_mult)
			parry_window = 0.0
			mana = mini(max_mana, mana + 15)
			_refresh_hud_numbers()
			_message("RUNED COUNTER-CLEAVE! (+15 BLUE MANA)", 1.5)
		else:
			dmg = int(float(dmg) * damage_mult)
		_damage_enemy(col, dmg)
		camera_shake = maxf(camera_shake, 0.09)
		view_kick = -0.05
	elif col is RigidBody3D and breakables.has(col):
		hitstop_time = 0.035
		_smash_pot(col)
		camera_shake = maxf(camera_shake, 0.05)
	elif col is StaticBody3D and wards.has(col):
		hitstop_time = 0.035
		_shatter_ward(col)
		camera_shake = maxf(camera_shake, 0.08)
	elif col is Node3D and shootable_targets.has(col) and col.get_meta("shootable_rope", false):
		_hit_shootable_target(col, "axe")
	else:
		_message("STEEL STRIKES STONE", 0.5)
		camera_shake = maxf(camera_shake, 0.03)

func _spawn_corpse(enemy: CharacterBody3D) -> void:
	var corpse := RigidBody3D.new()
	corpse.name = "fallen_" + str(enemy.get_meta("kind"))
	corpse.position = enemy.position + Vector3(0, 0.75, 0)
	corpse.mass = 2.0
	corpse.linear_damp = 1.1
	corpse.angular_damp = 1.3
	corpse.collision_layer = LAYER_DEBRIS
	corpse.collision_mask = LAYER_WORLD
	level_root.add_child(corpse)
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.4
	collider.shape = shape
	corpse.add_child(collider)
	var old_sprite: Sprite3D = enemy.get_meta("sprite")
	var sprite := Sprite3D.new()
	sprite.texture = old_sprite.texture
	sprite.pixel_size = old_sprite.pixel_size
	sprite.position.y = old_sprite.position.y - 0.75
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = true
	sprite.modulate = old_sprite.modulate
	corpse.add_child(sprite)
	var away := enemy.global_position - player.global_position
	away.y = 0
	if away.length() < 0.01:
		away = -player.global_transform.basis.z
	corpse.apply_central_impulse(away.normalized() * 8.0 + Vector3.UP * 3.2)
	corpse.apply_torque_impulse(Vector3(rng.randf_range(-2, 2), rng.randf_range(-1, 1), rng.randf_range(-2, 2)))
	var tween := create_tween().bind_node(corpse)
	tween.tween_interval(8.0)
	tween.tween_callback(corpse.queue_free)

func _damage_enemy(enemy: CharacterBody3D, damage: int, knockback: bool = true) -> void:
	if not is_instance_valid(enemy) or not enemies.has(enemy):
		return
	if enemy.get_meta("boss") and not wards.is_empty():
		_message("RESONANT WARDS BLOCK ALL DAMAGE (%d REMAIN)!" % wards.size(), 1.4)
		_sound("hit")
		return
	var health: int = int(enemy.get_meta("hp")) - damage
	enemy.set_meta("hp", health)
	if health > 0 and knockback:
		var away := enemy.global_position - player.global_position
		away.y = 0
		if away.length() < 0.01:
			away = -player.global_transform.basis.z
		enemy.velocity += away.normalized() * (2.5 if enemy.get_meta("boss") else 4.2 if enemy.get_meta("armored") else 6.2)
		enemy.velocity.y = maxf(enemy.velocity.y, 1.5 if enemy.get_meta("boss") else 2.2)
		if float(enemy.get_meta("windup")) > 0.0:
			parry_window = 1.5
		enemy.set_meta("pending", "")
		enemy.set_meta("windup", 0.0)
		enemy.set_meta("stagger", maxf(float(enemy.get_meta("stagger")), 0.16 if enemy.get_meta("boss") else 0.30))
		enemy.set_meta("attack", maxf(float(enemy.get_meta("attack")), 0.55))
	hitmarker_time = 0.18
	labels.hitmarker.modulate = Color("ffd579") if health <= 0 else Color("ffaf7b")
	if enemy.get_meta("boss"):
		level_states[1].boss_hp = maxi(0, health)
		labels.boss.text = "BELL WARDEN   %d / %d" % [maxi(0, health), enemy.get_meta("max_hp")]
		if health > 0 and health <= 260 and boss_phase == 0:
			boss_phase = 1
			world_env.background_color = Color("0a0612")
			world_env.fog_light_color = Color("251835")
			_sound("bell")
			_message("PHASE II — THE SKY DARKENS! REFLECT SONIC ORBS WITH Q REPULSE!", 4.0)
	_sound("hit")
	var spark := LevelBuilder.cylinder(level_root, "impact", enemy.global_position + Vector3(0, 1.3, 0), 0.25, 0.4, mats.ember, false, 5)
	var spark_tween := create_tween().bind_node(spark)
	spark_tween.tween_property(spark, "scale", Vector3.ZERO, 0.22)
	spark_tween.tween_callback(spark.queue_free)
	enemy.scale = Vector3.ONE * 1.08
	create_tween().bind_node(enemy).tween_property(enemy, "scale", Vector3.ONE, 0.16)

	if health <= 0:
		enemy.get_meta("warning").visible = false
		var enemy_id: String = enemy.get_meta("id")
		if not level_states[stage].dead.has(enemy_id):
			level_states[stage].dead.append(enemy_id)
		enemy.collision_layer = 0
		enemy.collision_mask = 0
		enemies.erase(enemy)
		if enemy.get_meta("boss"):
			var tween := create_tween().bind_node(enemy)
			tween.tween_property(enemy, "position:y", enemy.position.y - 2.5, 0.5)
			tween.tween_callback(enemy.queue_free)
			level_states[1].boss_dead = true
			_sound("bell", 0.6)
			_sound("maul")
			boss = null
			labels.boss.text = ""
			if is_instance_valid(belfry_floorboards):
				belfry_floorboards.visible = false
				belfry_floorboards.collision_layer = 0
			_portal(Vector3(0, 7.0, -38.0), "kiln", "DESCEND TO THE KILN OF ASH")
			_objective()
			_message("BELL WARDEN SLAIN  •  THE FLOOR SHATTERS OPEN TO THE KILN OF ASH!", 5.5)
			_story_event("warden_slain", "THE WARDEN'S FALL", "The Bell Warden's iron rack shatters through the belfry floor, opening a vertical shaft into the flooded subterranean foundry below.")
		else:
			if enemy.get_meta("kind") == "executioner" or enemy.get_meta("kind") == "ash_sentinel":
				_pickup(enemy.global_position + Vector3(0, 0.4, 0), "flask", "drop_" + enemy_id)
			var away_dir := (enemy.global_position - player.global_position)
			away_dir.y = 0
			away_dir = away_dir.normalized() if away_dir.length() > 0.01 else -player.global_transform.basis.z
			var gib_mat: Material = mats.ice if enemy.get_meta("elemental").is_frozen() else mats.cinder if enemy.get_meta("kind") == "ash_sentinel" else mats.blood
			var dec_kind := "frost" if enemy.get_meta("elemental").is_frozen() else "scorch" if enemy.get_meta("kind") == "ash_sentinel" else "blood"
			Visuals.spawn_gibs(level_root, enemy.global_position + Vector3(0, 0.9, 0), away_dir, gib_mat, rng, 9, dec_kind)
			_spawn_corpse(enemy)
			enemy.queue_free()
			_message("FOE VANQUISHED", 1.0)

func _hurt(amount: int, source: Vector3 = Vector3.ZERO, tint: Color = Color(0.75, 0.1, 0.05)) -> void:
	if hurt_cooldown > 0.0 or hp <= 0:
		return
	hurt_cooldown = 0.55
	var away := player.global_position - source if source != Vector3.ZERO else player.global_transform.basis.z
	away.y = 0
	if away.length() > 0.01:
		player.velocity += away.normalized() * (4.0 + amount * 0.08)
	view_kick = 0.11
	hp = maxi(0, hp - amount)
	flash = 1.0
	flash_color = tint
	camera_shake = maxf(camera_shake, 0.18)
	_refresh_hud_numbers()
	if hp <= 0:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		labels.message.text = "YOU HAVE FALLEN  •  PRESS R TO RETRY"
		message_time = 9999.0

func _heal() -> void:
	if flasks <= 0 or hp >= max_hp or hp <= 0 or heal_anim_time > 0.0:
		return
	flasks -= 1
	hp = mini(max_hp, hp + 45)
	heal_anim_time = 0.6
	_sound("pickup", 1.35)
	_refresh_hud_numbers()
	_message("ALCHEMICAL FLASK RESTORES 45 HP", 1.7)

func _use() -> void:
	if hp <= 0 or won:
		return
	for font in fonts:
		if is_instance_valid(font) and player.position.distance_to(font.position + Vector3(0, 1.0, 0)) < 2.6:
			flasks = maxi(flasks, 3)
			mana = 100
			green_mana = 100
			_sound("pickup")
			_refresh_hud_numbers()
			_message("ALCHEMICAL FONT REFILLS FLASKS & MANA", 2.2)
			return

	if stage == 0:
		if is_instance_valid(switch_node) and not gate_open and player.position.distance_to(switch_node.position + Vector3(0, 1.2, 0)) < 2.8:
			if not level_states[0].get("has_lever", false):
				_message("THE GEARBOX IS MISSING ITS IRON LEVER (CHECK EAST CRYPTS)", 2.8)
				return
			level_states[0].lever_inserted = true
			switch_node.get_meta("lever_arm").visible = true
			_sound("lever")
			var pressed := 0
			for p in pressure_plates:
				if p.pressed:
					pressed += 1
			if pressed >= 2:
				gate_open = true
				level_states[0].gate_open = true
				_message("PORTCULLIS LOCKED OPEN — ENTER THE BELL TOWER!", 3.5)
			else:
				_message("CHAIN SLIPS HALFWAY! WEIGHT BOTH BASIN PLATES TO COUNTERBALANCE!", 3.8)
			_objective()
			return
		if is_instance_valid(shortcut_door) and not level_states[0].get("shortcut_open", false) and player.position.distance_to(shortcut_door.position + Vector3(0, 1.5, 0)) < 2.6:
			if player.position.x > 9.0:
				level_states[0].shortcut_open = true
				shortcut_door.collision_layer = 0
				create_tween().bind_node(shortcut_door).tween_property(shortcut_door, "position:y", 4.6, 0.5)
				_sound("lever")
				_message("SHORTCUT TO ENTRY CLOISTER UNBARRED!", 2.5)
			else:
				_message("BARRED FROM THE EAST CRYPTS SIDE", 2.0)
			return

	elif stage == 2:
		if is_instance_valid(aqueduct_valve) and not level_states[2].get("trough_flooded", false) and player.position.distance_to(aqueduct_valve.position + Vector3(0, 1.0, 0)) < 2.8:
			level_states[2].trough_flooded = true
			if is_instance_valid(trough_water):
				trough_water.visible = true
			create_tween().bind_node(aqueduct_valve.get_meta("wheel")).tween_property(aqueduct_valve.get_meta("wheel"), "rotation:y", TAU, 0.6)
			_sound("lever")
			_message("AQUEDUCT VALVE OPENED  •  CRUCIBLE TROUGH FLOODED!", 3.5)
			_objective()
			return
		if is_instance_valid(hoist_lever) and not level_states[2].get("key_forged", false) and player.position.distance_to(hoist_lever.position + Vector3(0, 1.2, 0)) < 2.8:
			if not level_states[2].get("trough_flooded", false):
				_message("COOLING TROUGH IS DRY — OPEN THE AQUEDUCT VALVE FIRST!", 2.8)
				return
			if not level_states[2].get("dam_broken", false):
				_message("HOIST UNPOWERED — SMASH THE SMELTERY SLAG DAM WITH THE ORE-CART!", 3.0)
				return
			level_states[2].key_forged = true
			_sound("lever")
			_sound("frost")
			if is_instance_valid(key_mold):
				key_mold.visible = false
			_shockwave(Vector3(0, 0.8, -5.0), Color("8ce8f5"), 4.0)
			_pickup(Vector3(0, 1.2, -5.0), "ashen_key", "kiln_ashen_key")
			_message("THERMAL SHOCK CRACKS THE MOLD  •  CLAIM THE COOLED ASHEN KEY!", 4.2)
			_objective()
			return
		if is_instance_valid(key_mold) and key_mold.visible and player.position.distance_to(key_mold.position) < 2.4:
			_hurt(12, key_mold.position, Color("ff5c1a"))
			_message("THE MOLD IS WHITE-HOT! COOL IT IN THE FLOODED TROUGH!", 2.5)
			return
		if not level_states[2].get("great_gate_open", false) and player.position.distance_to(Vector3(0, 1.5, -20.0)) < 3.8:
			if has_ashen_key:
				level_states[2].great_gate_open = true
				if is_instance_valid(great_gate_left):
					great_gate_left.collision_layer = 0
				if is_instance_valid(great_gate_right):
					great_gate_right.collision_layer = 0
				_sound("bell", 0.55)
				_sound("lever")
				_win()
			else:
				_message("THE GREAT GATE IS SEALED  •  FORGE THE ASHEN KEY", 2.8)
			return

	for inscription in inscriptions:
		if is_instance_valid(inscription.node) and player.position.distance_to(inscription.node.position + Vector3(0, 1, 0)) < 2.3:
			_message("%s\n%s" % [inscription.title, inscription.writing], 5.5)
			_story_event("inscription_" + inscription.title.to_lower().replace(" ", "_"), inscription.title, inscription.writing)
			return

	for portal in portal_nodes:
		if not is_instance_valid(portal.node) or player.position.distance_to(portal.node.position + Vector3(0, 1.4, 0)) >= 2.8:
			continue
		match portal.destination:
			"courtyard":
				_change_stage(0)
			"tower":
				_change_stage(1)
			"kiln":
				_change_stage(2)
		return

func _win() -> void:
	_story_event("ending", "THE GREAT GATE UNSEALS", "You severed the citadel's three resonant anchors and forged the Ashen Key. As the twin iron doors grind open, ash blows inward from a pale-violet horizon.", "ACT I COMPLETE")
	_save_game()
	won = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ending_panel.visible = true
	_objective()

func _save_game() -> void:
	if hp <= 0:
		return
	var data := {
		"stage": stage,
		"s0": level_states[0],
		"s1": level_states[1],
		"s2": level_states[2],
		"arbalest": has_arbalest,
		"thurible": has_thurible,
		"ashen_key": has_ashen_key,
		"hp": hp,
		"mana": mana,
		"green": green_mana,
		"flasks": flasks,
		"mode": mode,
		"pos": [player.position.x, player.position.y, player.position.z],
		"yaw": player.rotation.y,
		"pitch": pitch,
		"story_flags": story_flags,
		"journal_entries": journal_entries
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data))
	file.close()
	_message("CHECKPOINT SAVED", 1.5)

func _load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_message("NO SAVED GAME FOUND", 2.0)
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if not data is Dictionary:
		return
	level_states[0] = data.get("s0", level_states[0])
	level_states[1] = data.get("s1", level_states[1])
	level_states[2] = data.get("s2", level_states[2])
	has_arbalest = bool(data.get("arbalest", false))
	has_thurible = bool(data.get("thurible", false))
	has_ashen_key = bool(data.get("ashen_key", false))
	hp = int(data.get("hp", 100))
	mana = int(data.get("mana", 75))
	green_mana = int(data.get("green", 45))
	flasks = int(data.get("flasks", 2))
	mode = int(data.get("mode", 0))
	story_flags.clear()
	journal_entries.clear()
	for flag in data.get("story_flags", []):
		story_flags.append(str(flag))
	for entry in data.get("journal_entries", []):
		if entry is Dictionary:
			journal_entries.append(entry)
	_change_stage(int(data.get("stage", 0)))
	var pos: Array = data.get("pos", [0, 0.1, 15])
	player.position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	player.rotation.y = float(data.get("yaw", 0))
	pitch = float(data.get("pitch", 0))
	head.rotation.x = pitch
	_build_weapon()
	_refresh_hud_numbers()
	won = false
	ending_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_message("CHECKPOINT LOADED", 1.5)
