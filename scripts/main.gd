extends Node3D

const ElementalComponent = preload("res://scripts/elemental.gd")
const LevelBuilder = preload("res://scripts/level_builder.gd")
const Visuals = preload("res://scripts/visuals.gd")
const Meshes3D = preload("res://scripts/meshes_3d.gd")
const NarrativeSystem = preload("res://scripts/narrative.gd")
const Audio3D = preload("res://scripts/audio_3d.gd")
const PhysicsSandbox = preload("res://scripts/physics_sandbox.gd")
const CombatSystems = preload("res://scripts/combat_systems.gd")
const EnemyAI = preload("res://scripts/enemy_ai.gd")
const StoryDirector = preload("res://scripts/story_director.gd")
const ChapterCourt = preload("res://scripts/chapters/chapter_1_court.gd")
const ChapterTower = preload("res://scripts/chapters/chapter_2_tower.gd")
const ChapterRegistry = preload("res://scripts/chapters/chapter_registry.gd")
const ChapterKiln = preload("res://scripts/chapters/chapter_3_kiln.gd")
const PauseMenu = preload("res://scripts/ui_menu.gd")
const SaveSystem = preload("res://scripts/save_system.gd")

const GRAVITY := 18.0
const FATAL_FALL_SPEED := 26.5
const HOT_KEY_MESSAGE := "ASHEN KEY STILL TEMPERING — TOO HOT TO HANDLE"
const AXE_SWING_TIMES := [0.38, 0.38, 0.50]
const FIRE_PATCH_RADIUS := 2.6
const FIRE_PATCH_TICK := 0.6
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
var weapon_holder: Node3D
var weapon_rig: Node3D
var vignette_rect: ColorRect

# Weapon & combat animation state
var swing_time := 0.0
var axe_combo_step := 0
var axe_combo_timer := 0.0
var swing_contact_done := false
var arbalest_recoil := 0.0
var thurible_time := 0.0
var thurible_release_done := false
var voltaic_recoil := 0.0
var heal_anim_time := 0.0
var hitstop_time := 0.0
var parry_window := 0.0
var parry_active_timer := 0.0
var parry_cooldown := 0.0

# Modular multi-chapter state
var level_root: Node3D
var chapter_id: String = "ch1_court"
var stage := 0
var level_states: Dictionary = {}
var map_bounds: Rect2 = Rect2(-32, -35, 64, 83)
var map_caption: String = ""

# Player progression & stats
var has_arbalest := false
var has_thurible := false
var has_voltaic := false
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
var mode := 0 # 0=axe, 1=arbalest, 2=thurible, 3=voltaic
var cooldown := 0.0
var offhand_cooldown := 0.0
var flash := 0.0
var flash_color := Color(0.75, 0.1, 0.05)
var message_time := 0.0
var elapsed := 0.0
var pitch := 0.0
var gate_open := false
var won := false

# Mobility & Telekinetic Grasp
var dash_cooldown := 0.0
var dash_time := 0.0
var dash_dir := Vector3.ZERO
var _fall_peak_speed: float = 0.0
var _fall_grace_time: float = 0.0
var held_body: RigidBody3D
var held_was_hurled: Dictionary = {}

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
# Voltaic raycasts check this list with several collider types.
var wards: Array[Node3D] = []
var ward_beams: Array[MeshInstance3D] = []
var boss: CharacterBody3D
var bosses: Array[CharacterBody3D] = []
var boss_phase := 0
var active_shockwaves: Array[Dictionary] = []
var active_fire_patches: Array[Dictionary] = []
var npc_nodes: Array[Dictionary] = []
var wet_zones: Array[Dictionary] = []
var voltaic_conduits: Array[Node3D] = []
var checkpoint_triggers: Array[Area3D] = []
var noise_events: Array[Dictionary] = []

# Chapter-specific dynamic set-piece references
var buoyant_rafts: Array[RigidBody3D] = []
var cistern_water_node: Node3D
var cistern_sluice_lever: Node3D
var tower_gear: Node3D
var tower_cracked_wall: StaticBody3D
var tower_pendulum: RigidBody3D
var hinged_pendulum: Dictionary = {}
var belfry_floorboards: StaticBody3D
var ward3_shutter: StaticBody3D
var bell_sequence_step := 0
var moving_lift: Dictionary = {}
var lift_call_lever: Node3D
var water_spouts: Array[StaticBody3D] = []
var aqueduct_valve: Node3D
var ore_cart: RigidBody3D
var slag_dam: StaticBody3D
var trough_water: Node3D
var key_mold: Node3D
var hoist_lever: Node3D
var great_gate_left: StaticBody3D
var great_gate_right: StaticBody3D
var rising_slag_node: Node3D
var slag_zones: Array[Dictionary] = []

# Ambush & lighting
var torches: Array[OmniLight3D] = []
var crypt_torches: Array[OmniLight3D] = []
var ambush_dark_timer := 0.0
var ambush_pending := false

# Movement, feel & settings
var hazard_timer := 0.0
var camera_shake := 0.0
var story_shake := 0.0
var unpick_held := false
var unpick_lock: Node3D
var unpick_time := 0.0
var unpick_tumblers := 0
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
var settings: Dictionary = {}

# Active entities
var particles: Array[Dictionary] = []
var enemies: Array[CharacterBody3D] = []
var pickups: Array[Dictionary] = []
var bolts: Array[Dictionary] = []
var enemy_bolts: Array[Dictionary] = []

# Subsystems & UI
var audio_3d: Audio3D
var narrative: NarrativeSystem
var story_director: StoryDirector
var resonance_overlay: ColorRect
var pause_menu: PauseMenu
var sounds := {} # Kept for legacy test compatibility
var mats := {}
var labels := {}
var veil: ColorRect
var ending_panel: ColorRect
var map_overlay: Control
var journal_panel: ColorRect
var story_flags: Array[String] = []
var journal_entries: Array[Dictionary] = []
var journal_index := 0
var seen_echoes: Dictionary = {}
var triggered_volumes: Dictionary = {}
var world_env: Environment
var portal_material: ShaderMaterial
var title_font: FontFile
var spell_glow_texture: ImageTexture

func _ready() -> void:
	rng.seed = 91475
	title_font = load("res://fonts/Cinzel.ttf")
	settings = SaveSystem.load_settings()
	_init_level_states()
	_setup_materials()
	spell_glow_texture = _make_glow_texture()
	_setup_world()
	level_root = Node3D.new()
	add_child(level_root)
	_build_player()
	_build_hud()
	_setup_audio()
	story_director = StoryDirector.new()
	add_child(story_director)
	# Setup connects Narrative's speaker cue to Audio3D for the mounted chapter.
	story_director.setup(self, null)
	story_director.set_physics_process(false)
	_load_chapter("ch1_court")
	story_flags.append("visited/ch1_court")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_story_event(
		"arrival",
		"THE EXILE RETURNS",
		"Seven years ago you helped forge Vaelor's resonance locks. Now the Ashen Gate has inverted, draining the living city outside. Meet Archivist Seraphina at the Gatehouse grate and descend into the Sunken Court.",
		""
	)

func _init_level_states() -> void:
	level_states.clear()
	for cid: String in ChapterRegistry.get_chapter_ids():
		level_states[cid] = ChapterRegistry.default_state(cid)

func _state() -> Dictionary:
	if not level_states.has(chapter_id):
		level_states[chapter_id] = ChapterRegistry.default_state(chapter_id)
	return level_states[chapter_id]

func _material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.86
	if glow:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 2.4
	return m

func _setup_materials() -> void:
	stone_physics_mat = PhysicsMaterial.new()
	stone_physics_mat.friction = 0.55
	stone_physics_mat.bounce = 0.14

	var pbr_stone := Visuals.make_pbr_stone_maps(rng, Color("8e9491"), 256)
	var pbr_dark := Visuals.make_pbr_stone_maps(rng, Color("485457"), 256)
	var pbr_basalt := Visuals.make_pbr_basalt_maps(rng, 256)
	var floor_tex: Texture2D = load("res://art/courtyard_floor.png")
	var floor_nrm := Visuals.make_normal_map(floor_tex, 2.4)
	var timber_tex := Visuals.make_timber_texture(rng)
	var timber_nrm := Visuals.make_normal_map(timber_tex, 2.8)
	var iron_tex := Visuals.make_metal_texture(Color("3b454e"), rng)
	var iron_nrm := Visuals.make_normal_map(iron_tex, 2.2)
	var brass_tex := Visuals.make_metal_texture(Color("c99858"), rng)
	var brass_nrm := Visuals.make_normal_map(brass_tex, 2.0)

	mats.stone = _material(Color("c8cecb"))
	mats.stone.albedo_texture = pbr_stone.albedo
	mats.stone.normal_enabled = true
	mats.stone.normal_texture = pbr_stone.normal
	mats.stone.normal_scale = 1.4
	mats.stone.roughness_texture = pbr_stone.roughness
	mats.stone.uv1_triplanar = true
	mats.stone.uv1_scale = Vector3(0.32, 0.32, 0.32)

	mats.dark = _material(Color("7d8b8c"))
	mats.dark.albedo_texture = pbr_dark.albedo
	mats.dark.normal_enabled = true
	mats.dark.normal_texture = pbr_dark.normal
	mats.dark.normal_scale = 1.45
	mats.dark.roughness_texture = pbr_dark.roughness
	mats.dark.uv1_triplanar = true
	mats.dark.uv1_scale = Vector3(0.32, 0.32, 0.32)

	mats.basalt = _material(Color("66595d"))
	mats.basalt.albedo_texture = pbr_basalt.albedo
	mats.basalt.normal_enabled = true
	mats.basalt.normal_texture = pbr_basalt.normal
	mats.basalt.normal_scale = 1.55
	mats.basalt.roughness_texture = pbr_basalt.roughness
	mats.basalt.uv1_triplanar = true
	mats.basalt.uv1_scale = Vector3(0.34, 0.34, 0.34)

	mats.floor = _material(Color("8a938d"))
	mats.floor.albedo_texture = floor_tex
	mats.floor.normal_enabled = true
	mats.floor.normal_texture = floor_nrm
	mats.floor.normal_scale = 1.35
	mats.floor.roughness = 0.74
	mats.floor.uv1_triplanar = true
	mats.floor.uv1_scale = Vector3(0.30, 0.30, 0.30)

	mats.timber = _material(Color("cdb7a0"))
	mats.timber.albedo_texture = timber_tex
	mats.timber.normal_enabled = true
	mats.timber.normal_texture = timber_nrm
	mats.timber.normal_scale = 1.5
	mats.timber.roughness = 0.80
	mats.timber.uv1_triplanar = true
	mats.timber.uv1_scale = Vector3(0.45, 0.45, 0.45)

	mats.iron = _material(Color("9ea9b3"))
	mats.iron.albedo_texture = iron_tex
	mats.iron.normal_enabled = true
	mats.iron.normal_texture = iron_nrm
	mats.iron.metallic = 0.84
	mats.iron.roughness = 0.34
	mats.iron.uv1_triplanar = true
	mats.iron.uv1_scale = Vector3(0.5, 0.5, 0.5)

	mats.brass = _material(Color("e6be82"))
	mats.brass.albedo_texture = brass_tex
	mats.brass.normal_enabled = true
	mats.brass.normal_texture = brass_nrm
	mats.brass.metallic = 0.88
	mats.brass.roughness = 0.28
	mats.brass.uv1_triplanar = true
	mats.brass.uv1_scale = Vector3(0.5, 0.5, 0.5)

	mats.copper = _material(Color("529e8a"))
	mats.copper.albedo_texture = iron_tex
	mats.copper.normal_enabled = true
	mats.copper.normal_texture = iron_nrm
	mats.copper.metallic = 0.76
	mats.copper.roughness = 0.40
	mats.copper.uv1_triplanar = true
	mats.copper.uv1_scale = Vector3(0.5, 0.5, 0.5)

	mats.clay = _material(Color("946c4f"))
	mats.clay.albedo_texture = pbr_stone.albedo
	mats.clay.normal_enabled = true
	mats.clay.normal_texture = pbr_stone.normal
	mats.clay.uv1_triplanar = true
	mats.clay.uv1_scale = Vector3(0.42, 0.42, 0.42)

	mats.moss = _material(Color("284236"))
	mats.ember = _material(Color("ff9244"), true)
	mats.mana = _material(Color("45d8ee"), true)
	mats.portal = _material(Color("b158e0"), true)
	mats.portal.emission_energy_multiplier = 1.4
	mats.blood = _material(Color("9e3d32"))
	mats.acid = _material(Color("42b86f"), true)
	mats.acid.emission_energy_multiplier = 1.25
	mats.ice = _material(Color("9ef3ff"), true)
	mats.ice.roughness = 0.08
	mats.ice.metallic = 0.16
	mats.ice.rim_enabled = true
	mats.ice.rim = 0.7
	mats.ice.emission_energy_multiplier = 1.6
	mats.cinder = _material(Color("f55e28"), true)
	mats.ash = _material(Color("8b8980"))

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

func _setup_world() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	Visuals.configure_environment(env, "ch1_court")
	world_env = env
	world.environment = env
	add_child(world)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-48, -32, 0)
	moon.light_color = Color("9ab0d4")
	moon.light_energy = 0.78
	moon.shadow_enabled = true
	moon.shadow_blur = 2.0
	add_child(moon)

# --- Chapter builder hooks ---
func _portal(pos: Vector3, destination: String, label: String) -> void:
	var holder := Node3D.new()
	holder.position = pos
	level_root.add_child(holder)
	for angle: float in [0.0, PI * 0.5]:
		var surface := MeshInstance3D.new()
		var plane := QuadMesh.new()
		plane.size = Vector2(2.8, 3.6)
		surface.mesh = plane
		surface.material_override = portal_material
		surface.position.y = 1.95
		surface.rotation.y = angle
		holder.add_child(surface)
	for x: float in [-1.55, 1.55]:
		LevelBuilder.box(holder, "portal_jamb", Vector3(x, 1.9, 0), Vector3(0.45, 3.8, 0.65), mats.dark, false)
	LevelBuilder.box(holder, "portal_crown", Vector3(0, 3.9, 0), Vector3(3.5, 0.42, 0.75), mats.brass, false)
	LevelBuilder.cylinder(holder, "portal_plinth", Vector3(0, 0.18, 0), 1.65, 0.35, mats.brass, false, 12)
	_light(pos + Vector3(0, 2, 0), Color("aa4dc9"), 2.8, 6.5)
	portal_nodes.append({"node": holder, "destination": destination, "label": label})

func _npc(pos: Vector3, npc_kind: String, npc_id: String, speaker: String, lines: Array, yaw: float = 0.0) -> void:
	var holder := Node3D.new()
	holder.name = "npc_" + npc_id
	holder.position = pos
	holder.rotation.y = yaw
	level_root.add_child(holder)
	var rig := Meshes3D.build_npc_rig(npc_kind, mats)
	holder.add_child(rig)
	var accent := Color("c7986a")
	match npc_kind:
		"torin", "bellwatch_guard":
			accent = Color("ffab48")
		"seraphina":
			accent = Color("70d7df")
	if not rig.has_meta("lantern_light") and not rig.has_meta("handbell_light"):
		_light(pos + Vector3(0, 1.8, 0), accent, 1.8, 5.5).reparent(holder)
	npc_nodes.append({
		"node": holder, "rig": rig, "kind": npc_kind, "id": npc_id,
		"speaker": speaker, "lines": lines, "accent": accent, "spoken": false,
	})

func _ward(pos: Vector3, ward_id: String) -> void:
	if _state().get("wards", []).has(ward_id):
		return
	var ward := LevelBuilder.box(level_root, "warding_crystal_" + ward_id, pos + Vector3(0, 1.25, 0), Vector3(0.8, 1.45, 0.8), mats.portal, true, LAYER_TARGET) as StaticBody3D
	LevelBuilder.cylinder(ward, "ward_crown", Vector3(0, 0.85, 0), 0.54, 0.18, mats.brass, false, 8)
	LevelBuilder.cylinder(level_root, "ward_plinth", pos + Vector3(0, 0.35, 0), 0.85, 0.7, mats.dark, true, 8)
	_light(pos + Vector3(0, 1.6, 0), Color("b75bd7"), 2.0, 5.5)
	ward.set_meta("ward", true)
	ward.set_meta("id", ward_id)
	wards.append(ward)

func _shatter_ward(ward: StaticBody3D) -> void:
	if not is_instance_valid(ward) or not wards.has(ward):
		return
	var ward_id: String = ward.get_meta("id")
	_state().wards.append(ward_id)
	wards.erase(ward)
	ward.collision_layer = 0
	_sound_at("frost", ward.global_position)
	_spell_impact(ward.global_position, Color("c46df5"))
	var tween := create_tween().bind_node(ward)
	tween.tween_property(ward, "position:y", ward.position.y - 2.0, 0.28)
	tween.tween_callback(ward.queue_free)
	story_director.snap_ward_chain(ward_id)
	story_director.start_sequence("ch2_tower/" + ward_id + "_broken")
	_update_belfry_seal(ward_id)
	if is_instance_valid(boss) and boss.get_meta("kind") == "warden":
		Meshes3D.set_warden_aegis(boss.get_meta("rig"), 1.0, wards.size())
	_objective()
	narrative.show_style_banner("WARD SHATTERED (%d LEFT)" % wards.size(), Color("d68ef5"))
	if wards.is_empty() and not story_director.has_sequence("ch2_tower/" + ward_id + "_broken"):
		narrative.say("LORD MALCOR (BELL WARDEN)", "My wards are broken! Ascend to the Belfry Sanctum, Caelen—let us see if your conviction matches your axe!", 5.0, Color("d99cbd"))

func _update_belfry_seal(ward_id: String) -> void:
	var seal := level_root.get_meta("belfry_ward_seal", null) as StaticBody3D if level_root.has_meta("belfry_ward_seal") else null
	if not is_instance_valid(seal):
		return
	var sigils: Dictionary = seal.get_meta("sigil_nodes")
	var sigil: Node3D = sigils.get(ward_id)
	if is_instance_valid(sigil):
		sigils.erase(ward_id)
		sigil.hide()
		sigil.queue_free()
	if wards.is_empty():
		seal.collision_layer = 0
		var pos := seal.global_position
		var color := Color("c994ff")
		_sound_at("bell", pos, 0.66)
		_spell_impact(pos + Vector3.UP * 2.4, color, Vector3.UP)
		_shockwave(pos + Vector3.UP * 0.12, color, 8.0)
		var tween := seal.create_tween().set_parallel()
		tween.tween_property(seal, "scale:y", 0.025, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_property(seal.get_child(0), "transparency", 1.0, 0.4)
		tween.chain().tween_callback(level_root.remove_meta.bind("belfry_ward_seal"))
		tween.tween_callback(seal.queue_free)

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

func _inscription(pos: Vector3, title: String, writing: String, parent: Node3D = null) -> void:
	var holder := Node3D.new()
	holder.position = pos
	(parent if parent != null else level_root).add_child(holder)
	LevelBuilder.box(holder, "inscribed_stone", Vector3(0, 0.75, 0), Vector3(0.85, 1.5, 0.32), mats.dark, false)
	LevelBuilder.box(holder, "glowing_rune", Vector3(0, 1.0, -0.2), Vector3(0.32, 0.35, 0.04), mats.mana, false)
	inscriptions.append({"node": holder, "title": title, "writing": writing})

func _pot(pos: Vector3, pot_id: String, loot: String) -> void:
	if _state().broken.has(pot_id):
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
	_state().broken.append(pot_id)
	breakables.erase(pot)
	var pos := pot.global_position
	pot.collision_layer = 0
	pot.queue_free()
	PhysicsSandbox.emit_noise(noise_events, pos, 22.0, 2.2)
	if is_cask:
		_detonate_cask(pos)
		return
	_sound_at("hit", pos)
	var mat: Material = mats.timber if is_barricade else mats.clay
	for i in 8:
		_debris_piece(pos + Vector3(rng.randf_range(-0.35, 0.35), rng.randf_range(0.2, 0.6), rng.randf_range(-0.35, 0.35)), Vector3(0.18, 0.14, 0.22), mat, Vector3(rng.randf_range(-3.2, 3.2), rng.randf_range(1.8, 4.2), rng.randf_range(-3.2, 3.2)))
	if loot != "none":
		_pickup(pos + Vector3(0, 0.35, 0), loot, "loot_" + pot_id)
	if is_secret:
		_sound("pickup")
		narrative.show_style_banner("SECRET VAULT DISCOVERED!", Color("ffd875"))
	else:
		_message("BARRICADE SHATTERS" if is_barricade else "CLAY SHATTERS", 0.8)

func _detonate_cask(pos: Vector3) -> void:
	_sound_at("maul", pos, 0.82)
	PhysicsSandbox.emit_noise(noise_events, pos, 30.0, 3.5)
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
			CombatSystems.damage_executioner_shield(self, e, CombatSystems.SHIELD_HP)
			_apply_warden_hit(e, int(115.0 * damage_mult), 150.0, "ALCHEMICAL BLAST!")
			if res.thermal_shock and is_instance_valid(e) and enemies.has(e):
				_trigger_thermal_shock(e)
	for other in breakables.duplicate():
		if is_instance_valid(other) and other.global_position.distance_to(pos) < 5.2:
			_smash_pot(other)
	narrative.show_style_banner("ALCHEMICAL DETONATION!", Color("ff8c42"))

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
	var l := _light(pos + Vector3(0, 0.92, 0), Color("ff9248"), 3.2, 11.0)
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
	for y: float in [0.65, 3.7]:
		LevelBuilder.box(gate, "gate_brace", Vector3(0, y, 0), Vector3(9.6, 0.28, 0.35), mats.brass, false)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(9.6, 4.7, 0.5)
	collider.shape = shape
	collider.position.y = 2.35
	gate.add_child(collider)
	var st := _state()
	if st.get("gate_open", false):
		gate.position.y = 5.2
		gate.collision_layer = 0
		gate_open = true
	elif st.get("lever_inserted", false):
		gate.position.y = 1.9

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.position = Vector3(0, 0.1, 42.0)
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
	camera.far = 180.0
	head.add_child(camera)
	weapon_holder = Node3D.new()
	weapon_holder.name = "WeaponViewmodelHolder"
	camera.add_child(weapon_holder)
	repulse_cast = ShapeCast3D.new()
	var rshape := BoxShape3D.new()
	rshape.size = Vector3(4.2, 2.8, 1.0)
	repulse_cast.shape = rshape
	repulse_cast.target_position = Vector3(0, 0, -6.5)
	repulse_cast.collision_mask = LAYER_ENEMY | LAYER_PUSHABLE | LAYER_DEBRIS
	repulse_cast.enabled = false
	camera.add_child(repulse_cast)
	_build_weapon()

func _weapon_rest_transform() -> Dictionary:
	match mode:
		0:
			return {"pos": Vector3(0.42, -0.38, -0.68), "rot": Vector3(0.18, -0.35, 0.12)}
		1:
			return {"pos": Vector3(0.32, -0.26, -0.62), "rot": Vector3(0.02, -0.05, 0.0)}
		2:
			return {"pos": Vector3(0.42, -0.06, -0.74), "rot": Vector3(0.0, -0.18, 0.0)}
		_:
			return {"pos": Vector3(0.36, -0.30, -0.64), "rot": Vector3(0.16, -0.12, -0.06)}

func _build_weapon() -> void:
	if not is_instance_valid(weapon_holder):
		return
	for child in weapon_holder.get_children():
		child.queue_free()
	var wid := "axe" if mode == 0 else "arbalest" if mode == 1 else "thurible" if mode == 2 else "voltaic"
	weapon_rig = Meshes3D.build_weapon_viewmodel(wid, mats)
	weapon_holder.add_child(weapon_rig)
	equip_offset = 0.26
	var rest := _weapon_rest_transform()
	weapon_holder.position = rest.pos + Vector3(0, -equip_offset, 0)
	weapon_holder.rotation = rest.rot

func _enemy(pos: Vector3, armored: bool, enemy_id: String, is_boss: bool = false, kind: String = "shrieker") -> void:
	if _state().dead.has(enemy_id):
		return
	var e := CharacterBody3D.new()
	e.position = pos
	e.floor_snap_length = 0.28
	e.collision_layer = LAYER_ENEMY
	e.collision_mask = LAYER_WORLD | LAYER_ENEMY | LAYER_PUSHABLE | LAYER_PLAYER
	var max_hp_e := 640 if kind == "colossus" else 520 if is_boss else 165 if kind == "ash_sentinel" else 125 if kind == "executioner" else 110 if kind == "stalker" else 80 if kind == "acolyte" else 65
	var cur_hp := max_hp_e
	if kind == "warden":
		cur_hp = int(_state().get("boss_hp", max_hp_e))
	elif kind == "colossus":
		cur_hp = int(_state().get("colossus_hp", max_hp_e))
	e.set_meta("hp", cur_hp)
	e.set_meta("max_hp", max_hp_e)
	e.set_meta("attack", rng.randf_range(0.5, 1.4))
	e.set_meta("armored", armored or kind == "executioner" or kind == "ash_sentinel" or kind == "colossus")
	e.set_meta("has_shield", kind == "executioner")
	if kind == "executioner":
		e.set_meta("shield_hp", CombatSystems.SHIELD_HP)
	elif kind == "warden":
		e.set_meta("aegis_hp", CombatSystems.AEGIS_HP)
		e.set_meta("aegis_max_hp", CombatSystems.AEGIS_HP)
	e.set_meta("boss", is_boss)
	e.set_meta("kind", kind)
	e.set_meta("windup", 0.0)
	e.set_meta("windup_max", 0.5)
	e.set_meta("pending", "")
	e.set_meta("guard", 0.0)
	e.set_meta("stagger", 0.0)
	e.set_meta("hit_flash", 0.0)
	e.set_meta("id", enemy_id)
	level_root.add_child(e)
	var elem := ElementalComponent.new()
	elem.name = "ElementalComponent"
	elem.frost_immune = (kind == "ash_sentinel" or kind == "colossus")
	e.add_child(elem)
	e.set_meta("elemental", elem)
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 1.25 if kind == "colossus" else 1.05 if is_boss else 0.68 if kind == "ash_sentinel" else 0.56 if kind == "executioner" else 0.46
	shape.height = 4.6 if (is_boss or kind == "colossus") else 2.6 if kind == "ash_sentinel" else 2.25 if kind == "executioner" else 2.0
	collider.shape = shape
	collider.position.y = shape.height * 0.5
	e.add_child(collider)

	# Articulated 3D-hybrid enemy rig!
	var rig := Meshes3D.build_enemy_rig(kind, mats)
	e.add_child(rig)
	e.set_meta("rig", rig)
	if kind == "warden":
		Meshes3D.set_warden_aegis(rig, 1.0, wards.size())
	var warning := LevelBuilder.cylinder(e, "attack_warning", Vector3(0, 0.06, 0), 2.1 if is_boss else 1.15 if kind == "acolyte" else 0.95, 0.04, mats.warning, false, 24)
	warning.visible = false
	e.set_meta("warning", warning)
	enemies.append(e)
	if is_boss:
		boss = e
		bosses.append(e)

func _pickup(pos: Vector3, kind: String, item_id: String) -> void:
	if _state().taken.has(item_id):
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
	elif kind == "flask":
		LevelBuilder.cylinder(node, "healing_flask", Vector3.ZERO, 0.19, 0.44, mats.blood)
		LevelBuilder.cylinder(node, "flask_neck", Vector3(0, 0.26, 0), 0.1, 0.13, mats.brass)
	elif kind == "iron_lever":
		LevelBuilder.cylinder(node, "lever_shaft", Vector3.ZERO, 0.09, 0.85, mats.iron)
		LevelBuilder.box(node, "lever_grip", Vector3(0, 0.4, 0), Vector3(0.35, 0.16, 0.16), mats.brass, false)
	elif kind == "arbalest":
		var vm := Meshes3D.build_weapon_viewmodel("arbalest", mats)
		vm.scale = Vector3.ONE * 1.1
		node.add_child(vm)
	elif kind == "thurible":
		var vm := Meshes3D.build_weapon_viewmodel("thurible", mats)
		vm.scale = Vector3.ONE * 1.1
		node.add_child(vm)
	elif kind == "voltaic":
		var vm := Meshes3D.build_weapon_viewmodel("voltaic", mats)
		vm.scale = Vector3.ONE * 1.1
		node.add_child(vm)
	elif kind == "ashen_key":
		LevelBuilder.cylinder(node, "key_ring", Vector3(0, 0.25, 0), 0.26, 0.12, mats.ice)
		LevelBuilder.box(node, "key_blade", Vector3(0, -0.15, 0), Vector3(0.14, 0.65, 0.14), mats.brass, false)
	elif kind.begins_with("relic_"):
		var rmat: Material = mats.blood if kind == "relic_heart" else mats.mana if kind == "relic_siphon" else mats.cinder
		LevelBuilder.cylinder(node, "relic_orb", Vector3.ZERO, 0.34, 0.52, rmat, false, 8)
		LevelBuilder.cylinder(node, "relic_halo", Vector3.ZERO, 0.48, 0.08, mats.brass, false, 12)
		_light(pos + Vector3(0, 0.4, 0), Color("ffd875"), 2.2, 5.5)
	pickups.append({"node": node, "kind": kind, "y": pos.y, "id": item_id})

func _hud_label(parent: Control, text_value: String, pos: Vector2, size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = pos
	label.size = size
	label.add_theme_font_size_override("font_size", font_size)
	if font_size >= 18:
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
	resonance_overlay = Visuals.create_resonance_overlay(hud)
	var top := ColorRect.new()
	top.color = Color(0.015, 0.025, 0.028, 0.80)
	top.anchor_right = 1
	top.offset_bottom = 44
	hud.add_child(top)
	labels.area = _hud_label(hud, "ASHEN GATE    /    THE SUNKEN COURT", Vector2(20, 8), Vector2(510, 34), 19, Color("d6c6a4"))
	labels.compass = _hud_label(hud, "", Vector2(530, 10), Vector2(230, 30), 15, Color("f0d297"))
	labels.compass.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	labels.goal = _hud_label(hud, "OBJECTIVE: MEET SERAPHINA", Vector2(760, 10), Vector2(500, 30), 16, Color("c98d60"))
	labels.goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	labels.ward_status = _hud_label(hud, "", Vector2(290, 44), Vector2(700, 23), 13, Color("e0ccf5"))
	labels.ward_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	labels.ward_status.hide()
	labels.boss = _hud_label(hud, "", Vector2(360, 67), Vector2(560, 30), 19, Color("e6b0d6"))
	labels.boss.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var boss_bg := ColorRect.new()
	boss_bg.color = Color(0.05, 0.04, 0.07, 0.85)
	boss_bg.position = Vector2(430, 97)
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

	var aegis_bg := ColorRect.new()
	aegis_bg.color = Color(0.08, 0.05, 0.14, 0.9)
	aegis_bg.position = Vector2(430, 111)
	aegis_bg.size = Vector2(420, 6)
	aegis_bg.hide()
	hud.add_child(aegis_bg)
	var aegis_fill := ColorRect.new()
	aegis_fill.color = Color("74d8ff")
	aegis_fill.size = Vector2(420, 6)
	aegis_bg.add_child(aegis_fill)
	hud_bars.aegis_bg = aegis_bg
	hud_bars.aegis_fill = aegis_fill
	labels.aegis = _hud_label(aegis_bg, "", Vector2(-70, 7), Vector2(560, 22), 13, Color.WHITE)
	labels.aegis.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

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
		{"key": "mana", "x": 225, "w": 150, "col": Color("39bdd1")},
		{"key": "green", "x": 410, "w": 150, "col": Color("58b86a")}
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
	labels.hp = _hud_label(hud, "HEALTH  100", Vector2(24, 658), Vector2(200, 38), 24, Color("e6c8b0"))
	labels.mana = _hud_label(hud, "BLUE  75", Vector2(225, 658), Vector2(180, 38), 24, Color("70d7df"))
	labels.green = _hud_label(hud, "GREEN  45", Vector2(410, 658), Vector2(185, 38), 23, Color("8ace8a"))
	labels.flask = _hud_label(hud, "FLASK  2", Vector2(610, 666), Vector2(160, 40), 21, Color("be9e91"))
	labels.weapon = _hud_label(hud, "CLEAVER-AXE", Vector2(930, 660), Vector2(325, 45), 25, Color("d8b479"))
	labels.weapon.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	labels.prompt = _hud_label(hud, "", Vector2(290, 492), Vector2(700, 42), 20, Color("f0d297"))
	labels.prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	labels.message = _hud_label(hud, "", Vector2(185, 143), Vector2(910, 80), 21, Color("e4c5a2"))
	labels.message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	labels.message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	labels.crosshair = _hud_label(hud, "+", Vector2(621, 330), Vector2(40, 40), 25, Color("c8d6d3"))
	labels.crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	labels.reticle_hint = _hud_label(hud, "", Vector2(340, 368), Vector2(600, 28), 13, Color("d9e3df"))
	labels.reticle_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	labels.hitmarker = _hud_label(hud, "X", Vector2(611, 320), Vector2(60, 60), 34, Color("ffaf7b"))
	labels.hitmarker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	labels.hitmarker.visible = false
	_hud_label(hud, "WASD • SHIFT RUN • C DASH • 1-4 WEAPONS • RMB FROST • X/MMB PARRY • Q REPULSE • G GRASP/HURL • E USE • F HEAL • TAB MAP • J JOURNAL • ESC MENU", Vector2(16, 622), Vector2(1248, 35), 11, Color("9aa9a5"))

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
	var ending := _hud_label(ending_panel, "ACT I COMPLETE — THE GREAT GATE UNSEALS\n\nAsh blows inward from a blinding pale-violet horizon.\nThe Crucible Colossus has fallen, and the Hollow Choir stirs beyond.\n\nTO BE CONTINUED IN CHAPTER IV: THE HOLLOW BEYOND\nPRESS R TO REPLAY ACT I   •   ESC FOR MENU", Vector2(140, 155), Vector2(1000, 410), 27, Color("e6cfad"))
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

	pause_menu = PauseMenu.new()
	pause_menu.handle_escape = false
	hud.add_child(pause_menu)
	pause_menu.setup(title_font, settings)
	pause_menu.visibility_changed.connect(func() -> void:
		# The pause menu still receives Escape while the gameplay tree is paused.
		pause_menu.handle_escape = pause_menu.visible
		var travelling := is_instance_valid(story_director) and story_director.is_transitioning()
		narrative.set_gameplay_hud_visible(not pause_menu.visible and not travelling)
		if pause_menu.visible:
			unpick_held = false
			_step_unpick(0.0)
	)
	pause_menu.resume_requested.connect(func() -> void: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	pause_menu.load_checkpoint_requested.connect(func() -> void:
		pause_menu.close_menu()
		_load_game(true)
	)
	pause_menu.restart_chapter_requested.connect(func() -> void:
		pause_menu.close_menu()
		level_states[chapter_id] = ChapterRegistry.default_state(chapter_id)
		_load_chapter(chapter_id, true)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	)
	pause_menu.settings_changed.connect(func(new_settings: Dictionary) -> void:
		settings = new_settings
		SaveSystem.save_settings(settings)
		Visuals.apply_graphics_settings(world_env, get_viewport(), settings)
	)
	pause_menu.quit_requested.connect(func() -> void: get_tree().quit())

func _setup_audio() -> void:
	audio_3d = Audio3D.new()
	audio_3d.setup(self)

func _sound(sname: String, pitch_scale: float = 1.0) -> void:
	if is_instance_valid(audio_3d):
		audio_3d.play_2d(sname, pitch_scale)

func _sound_at(sname: String, pos: Vector3, pitch_scale: float = 1.0) -> void:
	if is_instance_valid(audio_3d) and is_instance_valid(level_root):
		audio_3d.play_at(level_root, sname, pos, pitch_scale)

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
	if trigger_id == "gatehouse_meeting":
		for npc in npc_nodes:
			if npc.id == "seraphina_gatehouse" and not npc.spoken:
				_trigger_npc_dialogue(npc)

func _on_checkpoint_reached(checkpoint_id: String, zone_label: String) -> void:
	if _state().get("checkpoint_id", "") == checkpoint_id:
		return
	_state()["checkpoint_id"] = checkpoint_id
	SaveSystem.write_save(self, true)
	narrative.show_checkpoint_toast(zone_label)

func _on_memory_echo(echo_id: String, speaker: String, title: String, line: String, col: Color) -> void:
	if seen_echoes.has(echo_id):
		return
	seen_echoes[echo_id] = true
	_sound("portal", 1.35)
	narrative.say(speaker, line, 6.2, col)
	_story_event("echo_" + echo_id, title, "%s: \"%s\"" % [speaker, line], "")

func _trigger_npc_dialogue(npc: Dictionary) -> void:
	npc.spoken = true
	var seq: Array = []
	for line in npc.lines:
		seq.append({"speaker": npc.speaker.to_upper(), "line": str(line), "duration": 4.8, "color": npc.accent})
	narrative.play_sequence(seq)
	_story_event("npc_" + str(npc.id), str(npc.speaker).to_upper(), "\n".join(PackedStringArray(npc.lines)), "")
	_sound("portal", 1.15)

func _activate_voltaic_conduit(target: Node3D) -> void:
	var cid: String = target.get_meta("id", "")
	if target.get_meta("powered", false):
		return
	target.set_meta("powered", true)
	_sound_at("voltaic", target.global_position, 0.9)
	Visuals.spawn_impact_light(level_root, target.global_position + Vector3(0, 0.5, 0), Color("6bf0ff"), 4.2, 8.5, 0.4)
	if cid == "conduit_lift_power":
		_state().lift_powered = true
		if not moving_lift.is_empty():
			moving_lift["powered"] = true
		narrative.show_style_banner("ASCENDING LIFT POWERED!", Color("6bf0ff"))
		narrative.say("SERAPHINA (RESONANT STONE)", "The central lift is live! Pull the call lever in the nave—and watch for jammed gear latches on the way up.", 4.8, Color("70d7df"))
	elif cid == "conduit_aqueduct":
		_state().aqueduct_powered = true
		narrative.show_style_banner("AQUEDUCT PUMP ENERGIZED!", Color("6bf0ff"))
		_message("AQUEDUCT PUMP POWERED — FREEZE THE FALLS & TURN THE VALVE!", 3.2)

func _toggle_grasp() -> void:
	if hp <= 0:
		return
	if is_instance_valid(held_body):
		held_body.gravity_scale = 1.0
		held_body = null
		_sound("repulse", 1.4)
		_message("OBJECT RELEASED", 0.9)
		return
	var target := CombatSystems.find_grasp_target(self, camera.global_position, -camera.global_transform.basis.z, 11.0)
	if target is CharacterBody3D:
		var yanked := CombatSystems.try_yank_shield(self, target)
		if yanked != null:
			held_body = yanked
			held_body.gravity_scale = 0.0
			_sound("repulse", 1.55)
			narrative.show_style_banner("SHIELD RIPPED! LMB TO HURL!", Color("70d7df"))
			return
	elif target is RigidBody3D:
		held_body = target
		held_body.gravity_scale = 0.0
		held_body.linear_velocity = Vector3.ZERO
		_sound("repulse", 1.6)
		_message("TELEKINETIC GRASP  •  LMB TO HURL  •  G TO DROP", 1.8)
		return
	_message("AIM AT AN URN, CASK, BLOCK, OR SHIELDED EXECUTIONER", 1.2)

func _hurl_held() -> void:
	if not is_instance_valid(held_body):
		held_body = null
		return
	var body := held_body
	held_body = null
	body.gravity_scale = 1.0
	var dir := -camera.global_transform.basis.z
	body.linear_velocity = dir * 28.0 + Vector3.UP * 2.5
	held_was_hurled[body.get_instance_id()] = 1.6
	cooldown = 0.35
	_sound("repulse", 0.9)
	camera_shake = maxf(camera_shake, 0.14)
	PhysicsSandbox.emit_noise(noise_events, player.global_position, 14.0, 1.5)
	_message("TELEKINETIC HURL!", 1.0)

func _dash() -> void:
	if dash_cooldown > 0.0 or hp <= 0:
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
	flash = 0.42
	flash_color = Color("44d4e8")
	_sound("jump", 1.45)

func _start_parry() -> void:
	if parry_cooldown > 0.0 or hp <= 0:
		return
	parry_active_timer = 0.28
	parry_cooldown = 0.72
	_sound("axe", 1.45)
	_message("PARRY STANCE!", 0.45)

func get_objective_target() -> Variant:
	var st := _state()
	match chapter_id:
		"ch1_court":
			return ChapterCourt.objective_target(st)
		"ch2_tower":
			if st.get("boss_dead", false):
				return Vector3(0, 7.0, -42.0)
			if not wards.is_empty() and is_instance_valid(wards[0]):
				return wards[0].global_position
			return Vector3(0, 9.5, -42.0)
		"ch3_kiln":
			if st.get("great_gate_open", false):
				return null if st.get("act_complete", false) else ChapterKiln.MARKS.S5_edge.pos
			if has_ashen_key:
				return boss.global_position if is_instance_valid(boss) else Vector3(0, 0, -38.0)
			if not st.get("aqueduct_powered", false):
				return Vector3(-19.05, 1.25, 7.25)
			if not st.get("trough_flooded", false):
				return Vector3(-24.15, 3.02, -7.6)
			if not st.get("dam_broken", false):
				return Vector3(18.9, 0.7, 5.5)
			return Vector3(3.55, 0, -5.0)
	return null

func _update_compass() -> void:
	if not labels.has("compass"):
		return
	var target: Variant = get_objective_target()
	if not target is Vector3:
		labels.compass.text = "ACT I COMPLETE"
		return
	var target_pos: Vector3 = target
	var to_t := target_pos - player.global_position
	var dist := int(Vector2(to_t.x, to_t.z).length())
	var fwd := -player.global_transform.basis.z
	var right := player.global_transform.basis.x
	var flat_t := Vector3(to_t.x, 0, to_t.z).normalized()
	var dot_r := right.dot(flat_t)
	var dot_f := fwd.dot(flat_t)
	var arrow := "▲" if dot_f > 0.65 else "▼" if dot_f < -0.65 else ("►" if dot_r > 0 else "◄")
	labels.compass.text = "%s OBJECTIVE (%dm)" % [arrow, dist]

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
	labels.weapon.text = "CLEAVER-AXE" if mode == 0 else "BRIAR ARBALEST" if mode == 1 else "CINDER THURIBLE" if mode == 2 else "VOLTAIC FORK"

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_E and not event.pressed:
		unpick_held = false
		_step_unpick(0.0)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if map_overlay.visible or journal_panel.visible:
			map_overlay.visible = false
			journal_panel.visible = false
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif pause_menu.visible:
			pause_menu.close_menu()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			pause_menu.open_menu(settings)
		return
	if pause_menu != null and pause_menu.visible:
		return
	if event is InputEventKey and event.keycode == KEY_SPACE and not event.pressed and player.velocity.y > 0:
		player.velocity.y *= 0.55
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not map_overlay.visible and not journal_panel.visible and hp > 0:
		var sens: float = float(settings.get("mouse_sens", 1.0))
		player.rotation.y -= event.relative.x * 0.0022 * sens
		pitch = clampf(pitch - event.relative.y * 0.0022 * sens, -1.42, 1.42)
		head.rotation.x = pitch
		weapon_sway.x = clampf(weapon_sway.x - event.relative.x * 0.0018, -0.08, 0.08)
		weapon_sway.y = clampf(weapon_sway.y - event.relative.y * 0.0014, -0.06, 0.06)
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
					_message("FIND THE BRIAR ARBALEST IN THE WEST CISTERN", 2.0)
			KEY_3:
				if has_thurible:
					mode = 2
					swing_time = 0
					thurible_time = 0
					_build_weapon()
					_refresh_hud_numbers()
				else:
					_message("FIND THE CINDER THURIBLE IN THE PENDULUM FOUNDRY", 2.0)
			KEY_4:
				if has_voltaic:
					mode = 3
					swing_time = 0
					thurible_time = 0
					_build_weapon()
					_refresh_hud_numbers()
				else:
					_message("FIND THE VOLTAIC TUNING FORK IN THE CLOCKWORK GALLERY", 2.0)
			KEY_Q:
				if is_instance_valid(held_body):
					_hurl_held()
				else:
					_repulse()
			KEY_G:
				_toggle_grasp()
			KEY_C, KEY_ALT:
				_dash()
			KEY_X:
				_start_parry()
			KEY_F5:
				_save_game()
			KEY_F9:
				_load_game(false)
			KEY_F:
				_heal()
			KEY_E:
				if not map_overlay.visible and not journal_panel.visible and hp > 0:
					unpick_held = true
					_use()
			KEY_R:
				if hp <= 0:
					if SaveSystem.has_checkpoint():
						_load_game(true)
					else:
						get_tree().reload_current_scene()
				elif won:
					get_tree().reload_current_scene()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			elif hp > 0 and not map_overlay.visible and not journal_panel.visible:
				if is_instance_valid(held_body):
					_hurl_held()
				else:
					_attack()
		elif event.button_index == MOUSE_BUTTON_RIGHT and hp > 0 and not map_overlay.visible and not journal_panel.visible:
			_frost_cast()
		elif event.button_index == MOUSE_BUTTON_MIDDLE and hp > 0 and not map_overlay.visible and not journal_panel.visible:
			_start_parry()

func _physics_process(delta: float) -> void:
	var hud_visible := not (pause_menu.visible or map_overlay.visible or journal_panel.visible)
	_fall_grace_time = maxf(0.0, _fall_grace_time - delta)
	if hp <= 0:
		player.velocity = Vector3.ZERO
	elif hud_visible:
		_check_abyss()
	narrative.set_gameplay_hud_visible(hud_visible and not story_director.is_transitioning())
	if hud_visible and hp > 0:
		story_director.step_physics(delta)
		_step_unpick(delta)
	else:
		unpick_held = false
		_step_unpick(0.0)
	if hitstop_time > 0.0:
		hitstop_time = maxf(0.0, hitstop_time - delta)
		return
	elapsed += delta
	if narrative != null:
		narrative.tick(delta)
	if is_instance_valid(audio_3d):
		audio_3d.tick(delta)
	cooldown = maxf(0.0, cooldown - delta)
	offhand_cooldown = maxf(0.0, offhand_cooldown - delta)
	axe_combo_timer = maxf(0.0, axe_combo_timer - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	dash_time = maxf(0.0, dash_time - delta)
	hurt_cooldown = maxf(0.0, hurt_cooldown - delta)
	hitmarker_time = maxf(0.0, hitmarker_time - delta)
	parry_window = maxf(0.0, parry_window - delta)
	parry_active_timer = maxf(0.0, parry_active_timer - delta)
	parry_cooldown = maxf(0.0, parry_cooldown - delta)
	heal_anim_time = maxf(0.0, heal_anim_time - delta)
	arbalest_recoil = maxf(0.0, arbalest_recoil - delta * 3.5)
	voltaic_recoil = maxf(0.0, voltaic_recoil - delta * 4.0)
	labels.hitmarker.visible = hitmarker_time > 0.0

	PhysicsSandbox.tick_noises(noise_events, delta)

	if mana_regen_rate > 0.0 and hp > 0:
		mana_regen_acc += mana_regen_rate * delta
		if mana_regen_acc >= 1.0:
			var add_m := int(mana_regen_acc)
			mana_regen_acc -= float(add_m)
			mana = mini(max_mana, mana + add_m)
			green_mana = mini(max_mana, green_mana + add_m)
			_refresh_hud_numbers()

	# Held Telekinetic Grasp object + hurled impact detection
	if is_instance_valid(held_body):
		var hold_pos := camera.global_position + -camera.global_transform.basis.z * 2.55
		held_body.linear_velocity = (hold_pos - held_body.global_position) * 14.0
		held_body.angular_velocity *= 0.85
	else:
		held_body = null
	for bid in held_was_hurled.keys():
		held_was_hurled[bid] -= delta
		if held_was_hurled[bid] <= 0.0:
			held_was_hurled.erase(bid)
	for blk in pushable_blocks + breakables:
		if is_instance_valid(blk) and held_was_hurled.has(blk.get_instance_id()) and blk.linear_velocity.length() > 7.5:
			for e in enemies.duplicate():
				if is_instance_valid(e) and e.global_position.distance_to(blk.global_position) < 1.8:
					held_was_hurled.erase(blk.get_instance_id())
					if blk.get_meta("explosive_cask", false):
						_smash_pot(blk)
					else:
						var bonus := 110 if blk.get_meta("yanked_shield", false) else 90
						_damage_enemy(e, int(float(bonus) * damage_mult))
						_spell_impact(e.global_position + Vector3(0, 1.0, 0), Color("61dbed"))
						narrative.show_style_banner("SHIELD SLAM!" if bonus > 90 else "KINETIC SLAM!", Color("61dbed"))
					break

	# Screen flash & low-HP vignette pulse
	flash = maxf(0.0, flash - delta * 1.8)
	veil.color = Color(flash_color.r, flash_color.g, flash_color.b, flash * 0.36)
	if hp <= 30 and hp > 0:
		vignette_rect.color = Color(0.65, 0.06, 0.04, 0.12 + absf(sin(elapsed * 4.5)) * 0.12)
	else:
		vignette_rect.color.a = move_toward(vignette_rect.color.a, 0.0, delta * 0.8)

	camera_shake = maxf(0.0, camera_shake - delta * 0.95)
	story_shake = maxf(0.0, story_shake - delta * 0.95)
	var shake_direction := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), 0).limit_length()
	camera.position = shake_direction * (camera_shake + story_shake)
	view_kick = move_toward(view_kick, 0.0, delta * 1.9)
	camera.rotation.x = lerpf(camera.rotation.x, view_kick, minf(1.0, delta * 14.0))

	if message_time > 0.0:
		message_time -= delta
		if message_time <= 0.0:
			labels.message.text = ""

	if hp <= 0 or not hud_visible:
		return

	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and cooldown <= 0.0 and not is_instance_valid(held_body):
		_attack()

	# Retro-FPS locomotion + Aether Dash
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
	if not was_grounded:
		_fall_peak_speed = maxf(_fall_peak_speed, maxf(0.0, -falling_speed))
	player.move_and_slide()
	if _check_abyss():
		return
	if not was_grounded and player.is_on_floor():
		var impact_speed := maxf(_fall_peak_speed, absf(falling_speed))
		_fall_peak_speed = 0.0
		if impact_speed > 3.0:
			_play_landing(impact_speed)
			if hp <= 0:
				return

	for index in player.get_slide_collision_count():
		var collision := player.get_slide_collision(index)
		if collision.get_collider() is RigidBody3D:
			var body: RigidBody3D = collision.get_collider()
			if not buoyant_rafts.has(body):
				body.apply_central_impulse(-collision.get_normal() * minf(6.5, current.length() * 0.45))

	landing_dip = maxf(0.0, landing_dip - delta * 0.45)

	var bob_amp := 0.032 if sprinting else 0.045
	var bob := sin(elapsed * (16.0 if sprinting else 11.5)) * bob_amp if move.length() > 0.1 and player.is_on_floor() else 0.0
	head.position.y = lerpf(head.position.y, 1.55 + bob - landing_dip, delta * 12.0)
	head.rotation.z = lerpf(head.rotation.z, -move.x * 0.05 + sin(elapsed * 7.0) * 0.007 * move.length(), minf(1.0, delta * 9.0))
	if player.is_on_floor() and move.length() > 0.1:
		footstep_time -= delta
		if footstep_time <= 0.0:
			_sound("step")
			if sprinting:
				PhysicsSandbox.emit_noise(noise_events, player.global_position, 16.0, 1.1)
			footstep_time = 0.27 if sprinting else 0.40
	else:
		footstep_time = 0.0

	_animate_weapon_3d(delta, move, sprinting)
	_update_enemies(delta)
	_update_bolts(delta)
	_update_fire_patches(delta)
	_update_enemy_bolts(delta)
	_update_shockwaves(delta)
	_update_pickups(delta)
	_update_breakables()
	_update_puzzles(delta)
	_update_prompt()
	_update_reticle_hint()
	_update_compass()

	# Adaptive combat audio crossfade
	if is_instance_valid(audio_3d):
		var in_combat := false
		for e in enemies:
			if is_instance_valid(e) and e.global_position.distance_to(player.global_position) < 20.0:
				in_combat = true
				break
		audio_3d.set_combat_intensity(in_combat)

	# Smooth HUD bars
	if hud_bars.has("hp"):
		hud_bars.hp.size.x = lerpf(hud_bars.hp.size.x, 160.0 * clampf(float(hp) / float(max_hp), 0.0, 1.0), minf(1.0, delta * 12.0))
		hud_bars.mana.size.x = lerpf(hud_bars.mana.size.x, 150.0 * clampf(float(mana) / float(max_mana), 0.0, 1.0), minf(1.0, delta * 12.0))
		hud_bars.green.size.x = lerpf(hud_bars.green.size.x, 150.0 * clampf(float(green_mana) / float(max_mana), 0.0, 1.0), minf(1.0, delta * 12.0))
		var show_boss := _should_show_boss_hud()
		hud_bars.boss_bg.visible = show_boss
		labels.boss.visible = show_boss
		if show_boss:
			var bname := _boss_display_name()
			labels.boss.text = "%s   %d / %d" % [bname, maxi(0, int(boss.get_meta("hp"))), int(boss.get_meta("max_hp"))]
			var bmax := float(boss.get_meta("max_hp", 520))
			hud_bars.boss_fill.size.x = lerpf(hud_bars.boss_fill.size.x, 420.0 * clampf(float(boss.get_meta("hp")) / bmax, 0.0, 1.0), minf(1.0, delta * 10.0))
		_refresh_aegis_hud()

	for i in torches.size():
		if is_instance_valid(torches[i]):
			if ambush_dark_timer > 0.0 and crypt_torches.has(torches[i]):
				torches[i].light_energy = 0.05 * StoryDirector.get_torch_scale(torches[i])
			else:
				torches[i].light_energy = (2.9 + sin(elapsed * 9.0 + i * 2.3) * 0.4) * StoryDirector.get_torch_scale(torches[i])

func _animate_weapon_3d(delta: float, move: Vector2, sprinting: bool) -> void:
	if not is_instance_valid(weapon_holder):
		return
	weapon_sway = weapon_sway.lerp(Vector2.ZERO, minf(1.0, delta * 10.0))
	equip_offset = move_toward(equip_offset, 0.0, delta * 1.4)
	var rest := _weapon_rest_transform()
	var pos: Vector3 = rest.pos
	var rot: Vector3 = rest.rot
	var bob_scale := 0.65 if sprinting else 1.0
	pos.x += sin(elapsed * 6.0) * 0.015 * move.length() * bob_scale + weapon_sway.x
	pos.y += sin(elapsed * 12.0) * 0.014 * move.length() * bob_scale + weapon_sway.y - equip_offset - heal_anim_time * 0.25
	rot.z += -move.x * 0.055

	if swing_time > 0.0:
		swing_time = maxf(0.0, swing_time - delta)
		var duration: float = AXE_SWING_TIMES[axe_combo_step]
		var progress := 1.0 - swing_time / duration
		var windup_pos := Vector3(0.16, 0.14, 0.08)
		var windup_rot := Vector3(0.35, -0.45, -0.35)
		var follow_pos := Vector3(-0.48, -0.10, -0.18)
		var follow_rot := Vector3(-0.75, 1.05, 0.95)
		var windup_end := 0.25
		match axe_combo_step:
			1:
				windup_pos = Vector3(-0.42, -0.06, 0.08)
				windup_rot = Vector3(-0.28, 0.95, 0.78)
				follow_pos = Vector3(0.34, 0.16, -0.18)
				follow_rot = Vector3(0.44, -0.98, -0.66)
			2:
				windup_pos = Vector3(-0.22, 0.48, 0.18)
				windup_rot = Vector3(1.25, 0.16, 0.30)
				follow_pos = Vector3(-0.21, -0.31, -0.36)
				follow_rot = Vector3(-1.25, 0.06, 0.12)
				windup_end = 0.42
		if not swing_contact_done and progress >= lerpf(windup_end, 0.66, 0.48):
			swing_contact_done = true
			_axe_contact()
		if progress < windup_end:
			var t := smoothstep(0.0, windup_end, progress)
			pos += windup_pos * t
			rot += windup_rot * t
		elif progress < 0.66:
			var t := smoothstep(windup_end, 0.66, progress)
			pos += windup_pos.lerp(follow_pos, t)
			rot += windup_rot.lerp(follow_rot, t)
		else:
			var recovery := 1.0 - smoothstep(0.66, 1.0, progress)
			pos += follow_pos * recovery
			rot += follow_rot * recovery
	elif parry_active_timer > 0.0:
		pos += Vector3(-0.22, 0.14, 0.08)
		rot += Vector3(0.25, 0.95, 0.85)
	elif thurible_time > 0.0:
		thurible_time = maxf(0.0, thurible_time - delta)
		var age := 0.72 - thurible_time
		if not thurible_release_done and age >= 0.30:
			thurible_release_done = true
			_thurible_release()
		var arc := sin(age / 0.72 * PI)
		pos += Vector3(-arc * 0.28, arc * 0.12, -arc * 0.18)
		rot.x -= arc * 0.85
	elif mode == 1:
		pos.z += arbalest_recoil * 0.12
		rot.x += arbalest_recoil * 0.16
	elif mode == 3:
		pos.z += voltaic_recoil * 0.09
		rot.x += voltaic_recoil * 0.14
		if is_instance_valid(weapon_rig):
			var spark := weapon_rig.get_node_or_null("spark_core")
			if spark is Node3D:
				spark.rotation.y += delta * 6.0

	if mode == 0 and is_instance_valid(weapon_rig):
		var rune := weapon_rig.get_node_or_null("rune_glow")
		if rune is Node3D:
			var s := (1.18 + sin(elapsed * 20.0) * 0.12) if parry_window > 0.0 else 1.0
			rune.scale = Vector3.ONE * s

	weapon_holder.position = pos
	weapon_holder.rotation = rot

func _try_ledge_mantle() -> void:
	var forward := -player.global_transform.basis.z
	var space := get_world_3d().direct_space_state
	var low_from := player.global_position + Vector3(0, 0.55, 0)
	var low_q := PhysicsRayQueryParameters3D.create(low_from, low_from + forward * 0.75, LAYER_WORLD)
	if space.intersect_ray(low_q).is_empty():
		return
	var high_from := player.global_position + Vector3(0, 1.48, 0)
	var high_q := PhysicsRayQueryParameters3D.create(high_from, high_from + forward * 0.85, LAYER_WORLD)
	if space.intersect_ray(high_q).is_empty():
		player.velocity.y = maxf(player.velocity.y, 5.4)

func _update_puzzles(delta: float) -> void:
	var st := _state()

	# --- CHAPTER I: Ambush + Buoyant Cistern Lock + Counterweight Portcullis ---
	if chapter_id == "ch1_court":
		var was_open := gate_open
		if ambush_dark_timer > 0.0:
			ambush_dark_timer = maxf(0.0, ambush_dark_timer - delta)
			if ambush_dark_timer <= 0.0 and ambush_pending:
				ambush_pending = false
				_sound("bell")
				_enemy(Vector3(24.0, -0.7, -5.0), true, "court_ambush_exec", false, "executioner")
				_enemy(Vector3(19.5, -0.7, -9.0), false, "court_ambush_shr1", false, "shrieker")
				_enemy(Vector3(25.5, -0.7, -15.0), false, "court_ambush_shr2", false, "shrieker")
				narrative.show_style_banner("OSSUARY AMBUSH!", Color("ff7844"))

		if is_instance_valid(cistern_water_node):
			var target_y: float = cistern_water_node.get_meta("raised_y", 1.45) if st.get("cistern_raised", false) else cistern_water_node.get_meta("lowered_y", -0.53)
			cistern_water_node.position.y = move_toward(cistern_water_node.position.y, target_y, delta * 0.95)
			PhysicsSandbox.update_buoyancy(buoyant_rafts, cistern_water_node.position.y, delta)

		for ch in water_channels:
			if ch.frozen_timer > 0.0:
				ch.frozen_timer = maxf(0.0, ch.frozen_timer - delta)
				if ch.frozen_timer <= 0.0 and is_instance_valid(ch.node):
					ch.node.get_child(0).material_override = mats.water
			else:
				for blk in pushable_blocks:
					if is_instance_valid(blk):
						var d: Vector3 = blk.global_position - ch.pos
						if absf(d.x) < ch.size.x * 0.5 and absf(d.z) < ch.size.z * 0.5:
							blk.apply_central_force(ch.push_dir * 42.0)

		for plate in pressure_plates:
			var is_held := false
			for blk in pushable_blocks:
				if not is_instance_valid(blk) or not blk.get_meta("pushable_block", false) or blk == held_body:
					continue
				var offset: Vector3 = plate.pos - blk.global_position
				if absf(offset.y) > 1.25:
					continue
				offset.y = 0.0
				if offset.length_squared() >= 1.65 * 1.65:
					continue
				# Keep centering after first contact, until the block settles on the plate.
				if blk.linear_velocity.length_squared() < 3.5 * 3.5 and offset.length_squared() > 0.025:
					var settled_velocity := (offset * 1.8).limit_length(1.25)
					settled_velocity.y = blk.linear_velocity.y
					blk.linear_velocity = blk.linear_velocity.lerp(settled_velocity, minf(1.0, delta * 9.0))
					blk.angular_velocity *= exp(-delta * 6.0)
				is_held = true
				break
			plate.pressed = is_held
			if is_instance_valid(plate.node):
				plate.node.position.y = 0.02 if is_held else 0.08
				plate.node.get_child(0).material_override = mats.mana if is_held else mats.brass

		ChapterCourt.step(self, delta)
		if gate_open and not was_open:
			_objective()

	# --- CHAPTER II: Cogwheel + Moving Lift Set-Piece + PinJoint Pendulum + Ward Beams ---
	elif chapter_id == "ch2_tower":
		if is_instance_valid(tower_gear) and not st.get("gear_frozen", false):
			tower_gear.rotation.x += delta * 2.2
		if not moving_lift.is_empty():
			var lift_event := PhysicsSandbox.step_moving_lift(moving_lift, delta, 0.15)
			if lift_event == "jammed":
				story_director.start_sequence("ch2_tower/lift_ambush")
			elif lift_event == "arrived":
				st.lift_completed = true
				_sound("lever")
				narrative.show_style_banner("CHOIR LOFT REACHED!", Color("ffd875"))
		# Check real PinJoint3D pendulum swinging into cracked brick wall
		if not hinged_pendulum.is_empty() and not hinged_pendulum.get("broken", false):
			var bob: RigidBody3D = hinged_pendulum.get("bob")
			if is_instance_valid(bob) and is_instance_valid(tower_cracked_wall):
				if int(hinged_pendulum.get("hits", 0)) >= 2 and bob.global_position.x > 26.8:
					_break_pendulum_wall()
		_update_ward_beams()

	# --- CHAPTER III: Frozen Spouts + Ore-Cart + Rising Slag Meltdown + Great Gate ---
	elif chapter_id == "ch3_kiln":
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

		if not st.get("dam_broken", false) and is_instance_valid(ore_cart) and is_instance_valid(slag_dam):
			if ore_cart.global_position.z < -8.2:
				st.dam_broken = true
				slag_dam.visible = false
				slag_dam.collision_layer = 0
				story_director.start_sequence("ch3_kiln/dam_break")
				_objective()

		if st.get("gauntlet_triggered", false) and is_instance_valid(rising_slag_node):
			var ry: float = rising_slag_node.get_meta("raised_y", -0.14)
			rising_slag_node.position.y = move_toward(rising_slag_node.position.y, ry, delta * 0.28)

		hazard_timer = maxf(0.0, hazard_timer - delta)
		for zinfo in slag_zones:
			var pdelta: Vector3 = player.global_position - zinfo.pos
			if hazard_timer <= 0.0 and absf(pdelta.x) < zinfo.half.x and absf(pdelta.z) < zinfo.half.y and player.global_position.y < 0.20:
				if absf(player.global_position.z - 4.0) > 1.9 and absf(player.global_position.z + 10.0) > 1.9:
					_hurt(12, Vector3.ZERO, Color("ff5c1a"))
					hazard_timer = 0.7
			for entry in enemies.duplicate():
				var e: CharacterBody3D = entry
				if not is_instance_valid(e) or e.get_meta("boss", false):
					continue
				var edelta: Vector3 = e.global_position - zinfo.pos
				if absf(edelta.x) < zinfo.half.x and absf(edelta.z) < zinfo.half.y and e.global_position.y < 0.30:
					if absf(e.global_position.z - 4.0) > 1.9 and absf(e.global_position.z + 10.0) > 1.9:
						_damage_enemy(e, 160)
						narrative.show_style_banner("SLAG INCINERATION!", Color("ff5c1a"))

		if st.get("great_gate_open", false) and is_instance_valid(great_gate_left) and is_instance_valid(great_gate_right):
			great_gate_left.position.x = move_toward(great_gate_left.position.x, -8.5, delta * 2.8)
			great_gate_right.position.x = move_toward(great_gate_right.position.x, 8.5, delta * 2.8)

func _break_pendulum_wall() -> void:
	if not hinged_pendulum.is_empty():
		hinged_pendulum["broken"] = true
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
	narrative.show_style_banner("PENDULUM SMASH — WARD 2 BROKEN!", Color("ffd875"))

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
	var ids := ChapterRegistry.get_chapter_ids()
	if new_stage >= 0 and new_stage < ids.size():
		_load_chapter(ids[new_stage], true)

func _load_chapter(new_chapter_id: String, reset_spawn: bool = true, show_title_card: bool = true) -> void:
	story_director.cancel_chapter("unload")
	narrative.clear_chapter()
	narrative.chapter_timer = 0.0
	set_resonance_pulse(0.0)
	story_shake = 0.0
	unpick_held = false
	_step_unpick(0.0)
	if is_instance_valid(audio_3d):
		_sound("portal")
	if is_instance_valid(level_root):
		remove_child(level_root)
		level_root.queue_free()
	level_root = Node3D.new()
	add_child(level_root)

	chapter_id = new_chapter_id
	var meta := ChapterRegistry.get_chapter_meta(chapter_id)
	stage = int(meta.get("index", 0))
	map_bounds = meta.get("map_bounds", Rect2(-32, -32, 64, 64))
	map_caption = str(meta.get("map_caption", ""))

	# Clear per-chapter references
	enemies.clear()
	pickups.clear()
	bolts.clear()
	enemy_bolts.clear()
	active_shockwaves.clear()
	active_fire_patches.clear()
	swing_time = 0.0
	axe_combo_timer = 0.0
	offhand_cooldown = 0.0
	labels.reticle_hint.text = ""
	labels.crosshair.modulate = Color.WHITE
	bosses.clear()
	boss = null
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
	wet_zones.clear()
	voltaic_conduits.clear()
	npc_nodes.clear()
	buoyant_rafts.clear()
	checkpoint_triggers.clear()
	noise_events.clear()
	hinged_pendulum.clear()
	moving_lift.clear()
	gate = null
	switch_node = null
	shortcut_door = null
	cistern_water_node = null
	cistern_sluice_lever = null
	tower_gear = null
	tower_cracked_wall = null
	tower_pendulum = null
	belfry_floorboards = null
	ward3_shutter = null
	lift_call_lever = null
	aqueduct_valve = null
	ore_cart = null
	slag_dam = null
	trough_water = null
	key_mold = null
	hoist_lever = null
	great_gate_left = null
	great_gate_right = null
	rising_slag_node = null
	held_body = null
	held_was_hurled.clear()
	bell_sequence_step = 0
	ambush_dark_timer = 0.0
	ambush_pending = false
	var st := ChapterRegistry.ensure_state_defaults(chapter_id, _state())
	gate_open = bool(st.get("gate_open", false))

	Visuals.configure_environment(world_env, chapter_id)
	Visuals.apply_graphics_settings(world_env, get_viewport(), settings)
	audio_3d.set_chapter(chapter_id, str(meta.get("acoustics", "cathedral")))

	story_director.begin_chapter(chapter_id, level_root, st)
	ChapterRegistry.build(self, chapter_id)
	story_director.finish_chapter_build()

	if reset_spawn:
		player.position = meta.get("default_spawn", Vector3(0, 0.1, 20))
		player.rotation.y = 0
		head.rotation.x = 0
		pitch = 0
	_reset_arrival_motion()
	landing_dip = 0.0
	view_kick = 0.0
	camera.rotation.x = 0
	head.rotation.z = 0
	hurt_cooldown = 0.0
	hitmarker_time = 0.0

	if show_title_card:
		narrative.show_chapter(str(meta.get("chapter_num", "")), str(meta.get("title", "")), str(meta.get("subtitle", "")))
	_objective()

func _reset_arrival_motion() -> void:
	player.velocity = Vector3.ZERO
	_fall_peak_speed = 0.0
	_fall_grace_time = 1.2
	dash_time = 0.0
	dash_cooldown = 0.0
	dash_dir = Vector3.ZERO
	jump_buffer = 0.0
	coyote_time = 0.0
	player.reset_physics_interpolation()

func _mount_chapter_arrival(dest_chapter_id: String, arrival_id: String) -> bool:
	if not ChapterRegistry.CHAPTERS.has(dest_chapter_id):
		return false
	var visited := "visited/" + dest_chapter_id
	_load_chapter(dest_chapter_id, false, not story_flags.has(visited))
	var arrival := story_director.get_arrival(arrival_id)
	player.global_position = arrival.global_position if arrival != null else ChapterRegistry.get_chapter_meta(dest_chapter_id).default_spawn
	player.rotation.y = arrival.global_rotation.y if arrival != null else 0.0
	pitch = 0.0
	head.rotation.x = 0.0
	_reset_arrival_motion()
	if not story_flags.has(visited):
		story_flags.append(visited)
	# The director writes the same checkpoint on a physical crossing and reports its result.
	if not story_director.is_transitioning():
		_write_arrival_checkpoint("arrival/%s/%s" % [dest_chapter_id, arrival_id])
	_objective()
	_update_compass()
	_refresh_hud_numbers()
	return true

func _write_arrival_checkpoint(checkpoint_id: String) -> bool:
	_state().checkpoint_id = checkpoint_id
	return SaveSystem.write_save(self, true)

func add_story_shake(amount: float) -> void:
	story_shake = maxf(story_shake, clampf(amount, 0.0, StoryDirector.STORY_SHAKE_CAP))

func set_resonance_pulse(value: float, color: Color = Color("b87aff")) -> void:
	Visuals.set_resonance_pulse(resonance_overlay, value, color)

func _objective() -> void:
	var meta := ChapterRegistry.get_chapter_meta(chapter_id)
	var st := _state()
	labels.area.text = "ASHEN GATE    /    %s" % str(meta.get("title", ""))
	if chapter_id == "ch1_court":
		labels.goal.text = "OBJECTIVE: " + ChapterCourt.objective_text(st)
	elif chapter_id == "ch2_tower":
		if st.get("boss_dead", false):
			labels.goal.text = "OBJECTIVE: DESCEND TO THE KILN OF ASH" if st.story_world.belfry_shaft_open else "OBJECTIVE: LISTEN TO MALCOR"
		elif wards.is_empty():
			labels.goal.text = "OBJECTIVE: DEFEAT LORD MALCOR"
		else:
			labels.goal.text = "OBJECTIVE: BREAK THE THREE WARDS (%d LEFT)" % wards.size()
	else:
		if st.get("act_complete", false):
			labels.goal.text = "ACT I COMPLETE — [ESC] MENU"
		elif st.get("great_gate_open", false):
			labels.goal.text = "OBJECTIVE: APPROACH THE HOLLOW BEYOND"
		elif has_ashen_key and not st.get("colossus_dead", false):
			labels.goal.text = "OBJECTIVE: DEFEAT " + _boss_display_name()
		elif has_ashen_key:
			labels.goal.text = "OBJECTIVE: UNSEAL THE GREAT ASHEN GATE"
		elif st.get("trough_flooded", false) and st.get("dam_broken", false):
			labels.goal.text = "OBJECTIVE: TEMPER THE ASHEN KEY"
		else:
			labels.goal.text = "OBJECTIVE: FLOOD TROUGH & SMASH SLAG DAM"
	var show_boss := _should_show_boss_hud()
	if show_boss:
		var bname := _boss_display_name()
		labels.boss.text = "%s   %d / %d" % [bname, maxi(0, int(boss.get_meta("hp"))), int(boss.get_meta("max_hp"))]
	else:
		labels.boss.text = ""
	labels.boss.visible = show_boss
	labels.ward_status.visible = chapter_id == "ch2_tower" and not st.get("boss_dead", false) and not wards.is_empty()
	if labels.ward_status.visible:
		var status := PackedStringArray()
		for ward_id in LevelBuilder.BELFRY_WARDS:
			var name: String = LevelBuilder.BELFRY_WARDS[ward_id].label.get_slice(" ·  ", 1)
			status.append("[%s %s]" % ["✓" if st.wards.has(ward_id) else "●", name])
		labels.ward_status.text = "WARDS:   " + "   ".join(status)
	hud_bars.boss_bg.visible = show_boss
	_refresh_aegis_hud()

func _boss_display_name() -> String:
	var fallback := ChapterKiln.COLOSSUS_NAME if chapter_id == "ch3_kiln" else "LORD MALCOR — BELL WARDEN"
	return str(boss.get_meta("display_name", fallback)) if is_instance_valid(boss) else fallback

func _should_show_boss_hud() -> bool:
	if not is_instance_valid(boss) or not enemies.has(boss):
		return false
	if boss.get_meta("kind") == "warden":
		return wards.is_empty() or (is_instance_valid(player) and player.global_position.z < -27.0)
	return true

func _refresh_aegis_hud() -> void:
	var show_aegis: bool = _should_show_boss_hud() and boss.get_meta("kind") == "warden"
	hud_bars.aegis_bg.visible = show_aegis
	labels.aegis.visible = show_aegis
	if not show_aegis:
		return
	var ratio := float(boss.get_meta("aegis_hp")) / float(boss.get_meta("aegis_max_hp"))
	var color := Color("74d8ff")
	var caption := "RESONANT AEGIS"
	if not wards.is_empty():
		ratio = 1.0
		color = Color("b490ed")
		caption = "SEALED BY %d TOWER WARDS" % wards.size()
	elif float(boss.get_meta("aegis_exposed_timer", 0.0)) > 0.0:
		ratio = 1.0
		color = Color("ffd875").lerp(Color("b67e39"), (1.0 + sin(elapsed * 10.0)) * 0.5)
		caption = "AEGIS SHATTERED — EXPOSED (1.75x)!"
	hud_bars.aegis_fill.size.x = 420.0 * clampf(ratio, 0.0, 1.0)
	hud_bars.aegis_fill.color = color
	labels.aegis.modulate = color
	labels.aegis.text = caption

func _update_prompt() -> void:
	labels.prompt.text = ""
	if unpick_tumblers == 3 or _find_unpick_lock() != null:
		var tumblers := ["○ ○ ○", "• ○ ○", "• • ○", "• • •"]
		labels.prompt.text = "[ HOLD E ] UNPICK LOCK  [ %s ]" % tumblers[unpick_tumblers]
		return
	for font in fonts:
		if is_instance_valid(font) and player.position.distance_to(font.position + Vector3(0, 1.0, 0)) < 2.6:
			labels.prompt.text = "[ E ] REFILL FLASKS & MANA AT ALCHEMICAL FONT"
			return
	var st := _state()
	if chapter_id == "ch1_court":
		if is_instance_valid(cistern_sluice_lever) and not st.get("cistern_raised", false) and player.position.distance_to(cistern_sluice_lever.position + Vector3(0, 1.0, 0)) < 2.8:
			labels.prompt.text = "[ E ] PULL CISTERN SLUICE LEVER (FLOAT RAFTS)"
			return
		if is_instance_valid(switch_node) and not gate_open and player.position.distance_to(switch_node.position + Vector3(0, 1.2, 0)) < 2.8:
			labels.prompt.text = str(switch_node.get_meta("interact_hint", ""))
			return
		if is_instance_valid(shortcut_door) and not st.get("shortcut_open", false) and player.position.distance_to(shortcut_door.position + Vector3(0, 1.5, 0)) < 2.8:
			labels.prompt.text = "[ E ] UNBAR SHORTCUT DOOR" if player.global_position.x > shortcut_door.global_position.x else "BARRED FROM THE EAST OSSUARY"
			return
	elif chapter_id == "ch2_tower":
		if is_instance_valid(lift_call_lever) and not st.get("lift_completed", false) and player.position.distance_to(lift_call_lever.position + Vector3(0, 1.0, 0)) < 2.8:
			labels.prompt.text = "[ E ] ACTIVATE ASCENDING LIFT" if st.get("lift_powered", false) else "LIFT UNPOWERED — ZAP CONDUIT IN CLOCKWORK GALLERY [4]"
			return
	elif chapter_id == "ch3_kiln":
		if is_instance_valid(aqueduct_valve) and not st.get("trough_flooded", false) and player.position.distance_to(aqueduct_valve.position + Vector3(0, 1.0, 0)) < 2.8:
			labels.prompt.text = "[ E ] TURN AQUEDUCT VALVE" if st.get("aqueduct_powered", false) else "PUMP UNPOWERED — ZAP AQUEDUCT CONDUIT WITH [4]"
			return
		if is_instance_valid(hoist_lever) and not st.get("key_forged", false) and player.position.distance_to(hoist_lever.position + Vector3(0, 1.2, 0)) < 2.8:
			labels.prompt.text = str(hoist_lever.get_meta("interact_hint", "[ E ] PULL CHAIN HOIST LEVER"))
			return
		if not st.get("great_gate_open", false) and player.global_position.distance_to(ChapterKiln.GATE_APPROACH) < 4.0:
			var lock_plate: Node3D = level_root.get_meta("lock_plate_hitbox")
			labels.prompt.text = str(lock_plate.get_meta("interact_hint"))
			return
	for inscription in inscriptions:
		if is_instance_valid(inscription.node) and player.global_position.distance_to(inscription.node.global_position + Vector3.UP) < 2.4:
			labels.prompt.text = str(inscription.get("interact_hint", "[ E ] READ %s" % inscription.title))
			return
	for npc in npc_nodes:
		if is_instance_valid(npc.node) and npc.node.is_visible_in_tree() and player.global_position.distance_to(npc.node.global_position + Vector3(0, 1.2, 0)) < 4.0:
			labels.prompt.text = "[ E ] SPEAK WITH %s" % str(npc.speaker).to_upper()
			return

func _update_reticle_hint() -> void:
	var origin := camera.global_position
	var ray := PhysicsRayQueryParameters3D.create(origin, origin - camera.global_basis.z * 14.0, CombatSystems.ARC_MASK)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	var target := hit.get("collider") as Node3D
	var hint := ""
	var tint := Color.WHITE
	if is_instance_valid(target):
		var mechanism := target if target.has_meta("interact_hint") else target.get_parent()
		if is_instance_valid(mechanism) and mechanism.has_meta("interact_hint"):
			hint = mechanism.get_meta("interact_hint")
			tint = Color("9ee6e8")
		elif target in wards:
			hint = "WARDING CRYSTAL — SHATTER [1 / 2 / 3 / 4]"
			tint = Color("9ee6e8")
		elif target is CharacterBody3D and target in enemies:
			hint = _enemy_reticle_hint(target)
			tint = Color("ffb18b")
	if not hint.is_empty() and not labels.prompt.text.is_empty():
		var lead := hint.get_slice(" — ", 0)
		if labels.prompt.text.contains(lead):
			hint = ""
	labels.reticle_hint.text = hint
	labels.crosshair.modulate = tint

func _enemy_reticle_hint(enemy: CharacterBody3D) -> String:
	match enemy.get_meta("kind"):
		"executioner":
			return "IRON EXECUTIONER [SHIELDED] — GRASP [G] • SHOCK [4] • PARRY [X]" if enemy.get_meta("has_shield", false) else "IRON EXECUTIONER"
		"warden":
			if not wards.is_empty():
				return "LORD MALCOR — SEALED BY %d TOWER WARDS" % wards.size()
			return "LORD MALCOR [AEGIS] — REFLECT [Q] • SHOCK [4] • PARRY [X]" if float(enemy.get_meta("aegis_hp")) > 0.0 else "LORD MALCOR — BELL WARDEN"
		"stalker":
			return "BELL-BOUND STALKER — BLIND HUNTER (LURE WITH URN [G])"
		"ash_sentinel":
			return "ASH SENTINEL — FROST IMMUNE (SHOCK [4] • THERMAL SHOCK)"
		"colossus":
			return "THE LADLE [OVERDRIVE] — STRIKE WHITE CHEST CORE!" if int(enemy.get_meta("hp", 640)) <= 320 else "THE LADLE — FROST IMMUNE (SHOCK [4] • CAULDRON CHAIN)"
		_:
			return str(enemy.get_meta("kind")).capitalize().to_upper()

func _update_enemies(delta: float) -> void:
	EnemyAI.update_all(self, delta)

func _spawn_tolling_wave(origin: Vector3, floor_y: float) -> void:
	_sound_at("bell", origin)
	camera_shake = maxf(camera_shake, 0.22)
	var wave := MeshInstance3D.new()
	wave.name = "tolling_wave"
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.86
	mesh.outer_radius = 1.0
	wave.mesh = mesh
	wave.material_override = mats.cinder
	wave.position = Vector3(origin.x, floor_y, origin.z)
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
			_message("JUMP OVER THE SHOCKWAVE!", 1.4)
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

func _spell_impact(pos: Vector3, color: Color, direction: Vector3 = Vector3.ZERO) -> void:
	Visuals.spawn_impact_light(level_root, pos, color, 3.0, 6.5, 0.22)
	for i in 5:
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
		if not direction.is_zero_approx():
			offset += direction * rng.randf_range(0.75, 1.6)
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
	_sound_at("cast", source.global_position)

func _enemy_cast_triple(source: CharacterBody3D) -> void:
	var origin := source.global_position + Vector3(0, 2.2, 0)
	var base_dir := (camera.global_position - origin).normalized()
	for angle: float in [-0.24, 0.0, 0.24]:
		var dir := base_dir.rotated(Vector3.UP, angle)
		var orb := _spell_orb(origin, "curse", true)
		enemy_bolts.append({"node": orb, "source": source, "direction": dir, "life": 4.2, "speed": 10.5, "damage": 16, "homing": false})
	_sound_at("cast", source.global_position)

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
				_hurt(bolt.damage, node.global_position, Color("bd69f3"), bolt.source)
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
	var col: Object = hit.collider
	var hit_pos: Vector3 = hit.position
	if bolt.kind == "cinder":
		_cinder_aoe_burst(hit_pos)
		return
	var impact_color: Color = bolt.node.get_meta("color")
	if bolt.kind == "frost":
		_handle_frost_world_hit(col, hit_pos)
	if col is CharacterBody3D and enemies.has(col):
		match bolt.kind:
			"frost":
				_apply_frost_to_enemy(col)
			"reflected":
				if col.get_meta("kind") == "warden" and wards.is_empty():
					_apply_warden_hit(col, int(65.0 * damage_mult), 90.0, "SONIC REFLECT!")
				else:
					_damage_enemy(col, int(60.0 * damage_mult))
				if enemies.has(col) and col.get_meta("boss"):
					col.set_meta("stagger", maxf(3.0, float(col.get_meta("stagger"))))
					col.set_meta("windup", 0.0)
					col.set_meta("pending", "")
					if col.get_meta("kind") != "warden":
						narrative.show_style_banner("REFLECTED STUN (3s)!", Color("61dbed"))
			"arbalest":
				if col.get_meta("has_shield", false):
					CombatSystems.damage_executioner_shield(self, col, 18.0)
					_sound_at("parry", hit_pos, 0.8)
					_message("SHIELD BLOCKS BOLT — GRASP [G], SHOCK [4], OR PARRY [X]!", 1.8)
				else:
					var weakpoint: bool = (col.get_meta("kind") != "warden" or wards.is_empty()) and CombatSystems.is_weakpoint_hit(col, hit_pos)
					var dmg := int(42.0 * damage_mult * (1.5 if weakpoint else 1.0))
					_apply_warden_hit(col, dmg, 24.0, "")
					if weakpoint:
						impact_color = Color("ffd875")
						hitmarker_time = 0.18
						labels.hitmarker.modulate = impact_color
						narrative.show_style_banner("WEAKPOINT CRIT!", impact_color)
					if enemies.has(col) and col.get_meta("kind") == "shrieker":
						col.velocity += bolt.velocity.normalized() * 10.0
	elif col is RigidBody3D and breakables.has(col):
		_smash_pot(col)
	elif col is StaticBody3D and wards.has(col):
		_shatter_ward(col)
	elif col is Node3D and shootable_targets.has(col):
		_hit_shootable_target(col, bolt.kind)
	_spell_impact(hit_pos, impact_color)

func _apply_frost_to_enemy(enemy: CharacterBody3D) -> void:
	var elem: ElementalComponent = enemy.get_meta("elemental")
	var low_hp: bool = int(enemy.get_meta("hp")) <= int(enemy.get_meta("max_hp")) * 0.5
	var res := elem.apply_frost(5.0 if not enemy.get_meta("boss") else 2.2, low_hp)
	_damage_enemy(enemy, int(16.0 * damage_mult))
	if res.thermal_shock and is_instance_valid(enemy) and enemies.has(enemy):
		_trigger_thermal_shock(enemy)
	elif is_instance_valid(enemy) and enemies.has(enemy) and elem.is_solid_frozen():
		narrative.show_style_banner("FROZEN SOLID!", Color("88e9f5"))

func _trigger_thermal_shock(enemy: CharacterBody3D) -> void:
	_sound_at("frost", enemy.global_position)
	_sound_at("maul", enemy.global_position)
	_shockwave(enemy.global_position + Vector3(0, 0.8, 0), Color("88e9f5"), 3.8)
	_spell_impact(enemy.global_position + Vector3(0, 1.2, 0), Color("ff9352"))
	narrative.show_style_banner("THERMAL SHOCK! +80", Color("ff9352"))
	_damage_enemy(enemy, int(80.0 * damage_mult))

func _cinder_aoe_burst(pos: Vector3) -> void:
	_sound_at("maul", pos)
	_shockwave(pos + Vector3(0, 0.1, 0), Color("ff6e24"), 4.2)
	_spell_impact(pos, Color("ff7828"))
	_spawn_fire_patch(pos)
	camera_shake = maxf(camera_shake, 0.16)
	for entry in enemies.duplicate():
		var e: CharacterBody3D = entry
		if is_instance_valid(e) and e.global_position.distance_to(pos) < 4.5:
			var elem: ElementalComponent = e.get_meta("elemental")
			var res := elem.apply_burn(5.0)
			CombatSystems.damage_executioner_shield(self, e, 45.0)
			_apply_warden_hit(e, int(48.0 * damage_mult), 35.0, "CINDER BLAST")
			if res.thermal_shock and is_instance_valid(e) and enemies.has(e):
				_trigger_thermal_shock(e)
	for pot in breakables.duplicate():
		if is_instance_valid(pot) and pot.global_position.distance_to(pos) < 4.2:
			_smash_pot(pot)
	for w in wards.duplicate():
		if is_instance_valid(w) and w.global_position.distance_to(pos) < 4.2:
			_shatter_ward(w)
	for target in shootable_targets.duplicate():
		if is_instance_valid(target) and shootable_targets.has(target) and target.global_position.distance_to(pos) < 4.2:
			_hit_shootable_target(target, "cinder")
	if is_instance_valid(tower_pendulum) and tower_pendulum.global_position.distance_to(pos) < 4.8:
		_hit_tower_pendulum()

func _spawn_fire_patch(impact_pos: Vector3) -> void:
	var ray := PhysicsRayQueryParameters3D.create(impact_pos + Vector3.UP * 0.15, impact_pos + Vector3.DOWN * 40.0, LAYER_WORLD)
	var ground := get_world_3d().direct_space_state.intersect_ray(ray)
	var pos: Vector3 = ground.get("position", impact_pos)
	var tint := Color(1.0, 0.26, 0.06, 0.24)
	var material := _material(tint, true)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var patch := LevelBuilder.cylinder(level_root, "burning_embers", pos + Vector3.UP * 0.02, FIRE_PATCH_RADIUS, 0.035, material, false, 32)
	var light := _light(pos + Vector3.UP * 0.4, Color("ff631f"), 2.6, 5.5)
	light.reparent(patch)
	Visuals.spawn_decal(level_root, pos, "scorch", 2.8)
	active_fire_patches.append({"node": patch, "light": light, "time_left": 4.0, "tick_in": FIRE_PATCH_TICK})

func _update_fire_patches(delta: float) -> void:
	for i in range(active_fire_patches.size() - 1, -1, -1):
		var patch := active_fire_patches[i]
		patch.tick_in -= minf(delta, patch.time_left)
		patch.time_left -= delta
		while patch.tick_in <= 0.0:
			patch.tick_in += FIRE_PATCH_TICK
			var pos: Vector3 = patch.node.global_position
			_spell_trail(pos + Vector3(rng.randf_range(-1.6, 1.6), 0.22, rng.randf_range(-1.6, 1.6)), Color("ff7828"), 0.018)
			for enemy in enemies.duplicate():
				if not is_instance_valid(enemy) or enemy.global_position.distance_squared_to(pos) > FIRE_PATCH_RADIUS * FIRE_PATCH_RADIUS:
					continue
				var elem: ElementalComponent = enemy.get_meta("elemental")
				var result := elem.apply_burn(3.0)
				_apply_warden_hit(enemy, int(14.0 * damage_mult), 0.0, "", false)
				if result.thermal_shock and enemies.has(enemy):
					_trigger_thermal_shock(enemy)
		if patch.time_left <= 0.0:
			patch.node.queue_free()
			active_fire_patches.remove_at(i)
		else:
			var fade := minf(1.0, patch.time_left * 2.0)
			patch.light.light_energy = (2.2 + sin(elapsed * 13.0 + i) * 0.65) * fade
			patch.node.get_child(0).transparency = 1.0 - fade

func _handle_frost_world_hit(col: Object, hit_pos: Vector3) -> void:
	if chapter_id == "ch1_court":
		for ch in water_channels:
			if col == ch.node or hit_pos.distance_to(ch.pos) < 3.4:
				ch.frozen_timer = 12.0
				ch.node.get_child(0).material_override = mats.ice
				_sound_at("frost", hit_pos)
				narrative.show_style_banner("WATER FROZEN (12s)", Color("8ce8f5"))
				return
	if chapter_id == "ch2_tower" and col is Node3D and (col.get_meta("steam_pipe", false) or col == tower_gear):
		if not _state().get("gear_frozen", false):
			_state().gear_frozen = true
			if is_instance_valid(tower_gear):
				tower_gear.get_child(0).material_override = mats.ice
				tower_gear.collision_layer = 0
				create_tween().bind_node(tower_gear).tween_property(tower_gear, "position:y", -2.5, 0.45)
			_sound_at("frost", hit_pos)
			narrative.show_style_banner("COGWHEEL FROZEN!", Color("8ce8f5"))
			return
	if chapter_id == "ch3_kiln" and col is StaticBody3D and col.get_meta("water_spout", false):
		col.set_meta("frozen_timer", 12.0)
		col.collision_layer = LAYER_WORLD | LAYER_TARGET
		col.get_child(0).material_override = mats.ice
		col.get_meta("stream").get_child(0).material_override = mats.ice
		_sound_at("frost", hit_pos)
		_message("ICE STEPPING STONE FORMED (12s)!", 1.8)

func _hit_shootable_target(target: Node3D, bolt_kind: String) -> void:
	if target.get_meta("shootable_rope", false):
		var cage: Node3D = target.get_meta("cage")
		var drop_pos := Vector3(cage.global_position.x, 0.75, cage.global_position.z)
		shootable_targets.erase(target)
		target.queue_free()
		cage.queue_free()
		_state().cage_dropped = true
		LevelBuilder.add_pushable_block(self, drop_pos, "counterweight_east", Vector3(1.4, 1.2, 1.4), mats.iron)
		_sound_at("land", drop_pos)
		camera_shake = maxf(camera_shake, 0.22)
		narrative.show_style_banner("COUNTERWEIGHT DROPPED!", Color("ffd875"))
		return
	if target.get_meta("lift_latch", false):
		shootable_targets.erase(target)
		target.queue_free()
		_state().lift_unjammed = true
		if not moving_lift.is_empty():
			moving_lift["jammed"] = false
			moving_lift["jam_point"] = INF
			moving_lift["active"] = true
		_sound("lever")
		_sound("lift")
		narrative.show_style_banner("LIFT UNJAMMED — ASCENDING!", Color("69dae8"))
		return
	if target.get_meta("harmonic_bell", false):
		var idx: int = target.get_meta("bell_idx")
		var bname: String = target.get_meta("bell_name")
		var bpitch: float = target.get_meta("bell_pitch")
		_sound_at("bell", target.global_position, bpitch)
		PhysicsSandbox.emit_noise(noise_events, target.global_position, 24.0, 2.0)
		if idx == bell_sequence_step:
			bell_sequence_step += 1
			_message("CHIME %d/3: %s RESONATES!" % [bell_sequence_step, bname], 2.0)
			if bell_sequence_step >= 3:
				if is_instance_valid(ward3_shutter):
					ward3_shutter.collision_layer = 0
					create_tween().bind_node(ward3_shutter).tween_property(ward3_shutter, "position:y", 3.0, 0.5)
				for w in wards.duplicate():
					if is_instance_valid(w) and w.get_meta("id") == "ward_3":
						_shatter_ward(w)
		else:
			bell_sequence_step = 0
			_message("DISCORDANT CHIME — RESET! (CRESCENT → CROWN → SKULL)", 2.4)
		return
	if target.get_meta("cauldron_chain", false):
		var cauldron: Node3D = target.get_meta("cauldron")
		var cid: String = target.get_meta("id")
		var impact_pos := Vector3(cauldron.global_position.x, 0.3, cauldron.global_position.z)
		shootable_targets.erase(target)
		target.queue_free()
		_state().dropped_cauldrons.append(cid)
		var tw := create_tween().bind_node(cauldron)
		tw.tween_property(cauldron, "position:y", 0.5, 0.22)
		tw.tween_callback(func() -> void:
			_sound_at("maul", impact_pos)
			camera_shake = maxf(camera_shake, 0.35)
			_shockwave(impact_pos, Color("ff5c1a"), 4.6)
			for e in enemies.duplicate():
				if is_instance_valid(e) and Vector2(e.global_position.x - impact_pos.x, e.global_position.z - impact_pos.z).length() < 4.5:
					_damage_enemy(e, 320)
					narrative.show_style_banner("CAULDRON CRUSH!", Color("ff7832"))
			cauldron.queue_free()
		)
		return
	if bolt_kind == "frost":
		_handle_frost_world_hit(target, target.global_position)

func _update_pickups(delta: float) -> void:
	# In the scripted pour the hot prop becomes a pickup only when quenching ends.
	if level_root.has_meta("hot_key"):
		_show_hot_key_hint(level_root.get_meta("hot_key"))
	for item in pickups.duplicate():
		var node: Node3D = item.node
		if not is_instance_valid(node):
			pickups.erase(item)
			continue
		node.rotation.y += delta * 1.8
		node.position.y = item.y + sin(elapsed * 3.0 + item.y) * 0.08
		if player.global_position.distance_to(node.global_position) < 1.85:
			if node.get_meta("too_hot", false):
				_show_hot_key_hint(node)
				continue
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
				"iron_lever":
					_state().has_lever = true
					_message("IRON LEVER ACQUIRED  •  INSERT AT NORTH GEARBOX", 3.5)
					if story_director.start_sequence("ch1_court/ossuary_blackout"):
						story_director.start_sequence("ch1_court/torin_relocates")
					elif not story_director.has_sequence("ch1_court/ossuary_blackout") and not _state().get("ambush_done", false):
						_state().ambush_done = true
						ambush_dark_timer = 2.0
						ambush_pending = true
						_message("THE OSSUARY SCONCES SNUFF OUT...", 2.0)
					_objective()
				"arbalest":
					has_arbalest = true
					mode = 1
					_build_weapon()
					narrative.show_style_banner("BRIAR ARBALEST [2]", Color("5be38c"))
					_story_event("arbalest_unlock", "THE BRIAR ARBALEST", "Heavy spectral-iron bolts (5 Green Mana) with parabolic drop. Shoot ropes, lift latches, cauldron chains, and harmonic bells.", "")
				"thurible":
					has_thurible = true
					mode = 2
					_build_weapon()
					narrative.show_style_banner("CINDER THURIBLE [3]", Color("ff8c42"))
					_story_event("thurible_unlock", "THE CINDER THURIBLE", "Chained brass censer (10 Blue + 10 Green Mana) that lobs burning ember-oil. Ignites frozen foes for massive Thermal Shock!", "")
				"voltaic":
					has_voltaic = true
					mode = 3
					_build_weapon()
					narrative.show_style_banner("VOLTAIC TUNING FORK [4]", Color("6bf0ff"))
					_story_event("voltaic_unlock", "THE VOLTAIC TUNING FORK", "Arcs chain-lightning (12 Blue Mana) across wet water and armor, strips shields/hoops, and powers clockwork conduits!", "")
				"relic_heart":
					max_hp = 135
					hp = max_hp
					narrative.show_style_banner("RELIC: HEART OF VAELOR (MAX HP 135)", Color("ffd875"))
					_story_event("relic_heart", "ASHEN RELIC: HEART OF VAELOR", "Permanently raises Max Health to 135 and restores full vitality.", "")
				"relic_siphon":
					max_mana = 135
					mana = max_mana
					green_mana = max_mana
					mana_regen_rate = 2.0
					narrative.show_style_banner("RELIC: SIPHON SIGNET (MANA REGEN)", Color("70d7df"))
					_story_event("relic_siphon", "ASHEN RELIC: SIPHON SIGNET", "Permanently raises Max Mana to 135 and grants continuous Blue & Green Mana regeneration.", "")
				"relic_oath":
					damage_mult = 1.25
					narrative.show_style_banner("RELIC: CINDER-BREAKER'S OATH (+25% DMG)", Color("ff8c42"))
					_story_event("relic_oath", "ASHEN RELIC: CINDER-BREAKER'S OATH", "Permanently increases all melee & spell damage by +25% and shortens Aether Dash cooldown.", "")
				"ashen_key":
					has_ashen_key = true
					_trigger_kiln_meltdown()
					_objective()
			_refresh_hud_numbers()
			_state().taken.append(item.id)
			_sound("pickup")
			node.queue_free()
			pickups.erase(item)

func _show_hot_key_hint(key: Node3D) -> void:
	if not is_instance_valid(key) or player.global_position.distance_to(key.global_position) >= 1.85:
		return
	if labels.message.text != HOT_KEY_MESSAGE or message_time <= 0.0:
		_message(HOT_KEY_MESSAGE, 1.6)

func _trigger_kiln_meltdown() -> void:
	if _state().get("gauntlet_triggered", false):
		return
	_state().gauntlet_triggered = true
	ChapterKiln.spawn_meltdown_encounter(self)

func _update_breakables() -> void:
	for pot in breakables.duplicate():
		if is_instance_valid(pot) and not pot.freeze and pot.linear_velocity.length() > 7.5 and not pot.get_colliding_bodies().is_empty():
			_smash_pot(pot)

func _attack() -> void:
	if cooldown > 0.0:
		return
	if mode == 0:
		axe_combo_step = (axe_combo_step + 1) % 3 if axe_combo_timer > 0.0 else 0
		axe_combo_timer = 1.15
		cooldown = AXE_SWING_TIMES[axe_combo_step]
		swing_time = cooldown
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
	elif mode == 2:
		if mana < 10 or green_mana < 10:
			_message("CINDER THURIBLE NEEDS 10 BLUE + 10 GREEN MANA", 1.5)
			return
		mana -= 10
		green_mana -= 10
		_refresh_hud_numbers()
		cooldown = 0.72
		thurible_time = 0.72
		thurible_release_done = false
	else:
		if mana < 12:
			_message("VOLTAIC FORK NEEDS 12 BLUE MANA", 1.2)
			return
		mana -= 12
		_refresh_hud_numbers()
		cooldown = 0.48
		voltaic_recoil = 1.0
		_sound("voltaic")
		var origin := camera.global_position + -camera.global_transform.basis.z * 0.55 + camera.global_transform.basis.x * 0.2
		var dir := -camera.global_transform.basis.z
		var res := CombatSystems.fire_voltaic_arc(self, origin, dir, 20.0)
		if res.chained > 0:
			narrative.show_style_banner("VOLTAIC CHAIN x%d!" % (res.chained + 1), Color("6bf0ff"))

func _thurible_release() -> void:
	_sound("maul", 1.25)
	view_kick = -0.07
	var dir := -camera.global_transform.basis.z
	var orb := _spell_orb(camera.global_position + dir * 0.75, "cinder")
	bolts.append({"node": orb, "direction": dir, "velocity": dir * 18.0 + Vector3(0, 4.8, 0), "gravity": 14.0, "life": 2.2, "kind": "cinder"})

func _frost_cast() -> void:
	if offhand_cooldown > 0.0 or hp <= 0:
		return
	if mana < 10:
		_message("NOT ENOUGH BLUE MANA FOR FROST (NEEDS 10)", 1.2)
		return
	mana -= 10
	_refresh_hud_numbers()
	offhand_cooldown = 0.48
	_sound("frost")
	var dir := -camera.global_transform.basis.z
	var bolt := _spell_orb(camera.global_position + dir * 0.7, "frost")
	bolts.append({"node": bolt, "direction": dir, "velocity": dir * 28.0, "gravity": 0.0, "life": 1.8, "kind": "frost"})

func _repulse() -> void:
	if offhand_cooldown > 0.0 or hp <= 0:
		return
	if mana < 15:
		_message("NOT ENOUGH BLUE MANA FOR REPULSE (NEEDS 15)", 1.2)
		return
	mana -= 15
	_refresh_hud_numbers()
	offhand_cooldown = 0.45
	_sound("repulse")
	_shockwave(player.global_position + Vector3(0, 0.12, 0), Color("61dbed"), 6.5)
	camera_shake = maxf(camera_shake, 0.12)
	PhysicsSandbox.emit_noise(noise_events, player.global_position, 20.0, 2.0)

	var forward := -camera.global_transform.basis.z
	var flat_fwd := Vector3(forward.x, 0, forward.z).normalized()
	if flat_fwd.length() < 0.01:
		flat_fwd = -player.global_transform.basis.z

	var hit_bodies: Array = []
	if is_instance_valid(repulse_cast):
		repulse_cast.force_shapecast_update()
		for i in repulse_cast.get_collision_count():
			var c := repulse_cast.get_collider(i)
			if c != null and not hit_bodies.has(c):
				hit_bodies.append(c)

	for e in enemies.duplicate():
		if is_instance_valid(e) and not hit_bodies.has(e) and e.global_position.distance_to(player.global_position) < 6.8:
			var to_e: Vector3 = (e.global_position - player.global_position).normalized()
			if to_e.dot(flat_fwd) > 0.2 or e.global_position.distance_to(player.global_position) < 2.6:
				hit_bodies.append(e)
	for blk in pushable_blocks:
		if is_instance_valid(blk) and not hit_bodies.has(blk) and blk.global_position.distance_to(player.global_position) < 6.8:
			hit_bodies.append(blk)
	if is_instance_valid(tower_pendulum) and not hit_bodies.has(tower_pendulum) and tower_pendulum.global_position.distance_to(player.global_position) < 7.5:
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
			CombatSystems.damage_executioner_shield(self, body, 40.0)
			_damage_enemy(body, int(16.0 * damage_mult))
			parry_window = 1.6
		elif body == tower_pendulum:
			_hit_tower_pendulum()
		elif body is RigidBody3D and body.get_meta("ore_cart", false):
			body.apply_central_impulse(Vector3(0, 0, -56.0))
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

	var reflected := 0
	for bolt in enemy_bolts.duplicate():
		if not is_instance_valid(bolt.node):
			enemy_bolts.erase(bolt)
			continue
		if bolt.node.global_position.distance_to(player.global_position) > 8.5:
			continue
		var target_enemy: CharacterBody3D = bolt.source if is_instance_valid(bolt.source) and enemies.has(bolt.source) else (enemies[0] if not enemies.is_empty() else null)
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
	if reflected > 0:
		narrative.show_style_banner("REFLECTED x%d!" % reflected, Color("61dbed"))

func _hit_tower_pendulum() -> void:
	if hinged_pendulum.is_empty():
		return
	var hits := PhysicsSandbox.apply_pendulum_impulse(hinged_pendulum, Vector3(44.0, 5.0, 0.0))
	_sound("bell", 0.72 + hits * 0.14)
	if hits < 2:
		_message("PENDULUM MOMENTUM BUILDING (1/2) — REPULSE AGAIN!", 2.4)
	else:
		# Allow physical swing + guaranteed break callback shortly after impact
		var tw := create_tween()
		tw.tween_interval(0.24)
		tw.tween_callback(func() -> void:
			if not hinged_pendulum.get("broken", false):
				_break_pendulum_wall()
		)

func _axe_contact() -> void:
	_sound("axe")
	var forward := -camera.global_transform.basis.z
	var heavy := axe_combo_step == 2
	var sweep := CombatSystems.melee_cleave_sweep(self, camera.global_position, forward, 3.85 if heavy else 3.65, axe_combo_step)
	var had_counter := parry_window > 0.0
	if not sweep.enemies.is_empty():
		parry_window = 0.0
		hitstop_time = 0.035
		camera_shake = maxf(camera_shake, 0.14 if heavy else 0.09)
		view_kick = -0.08 if heavy else -0.05

	for enemy: CharacterBody3D in sweep.enemies:
		mana = mini(max_mana, mana + 6)
		_refresh_hud_numbers()
		var elem: ElementalComponent = enemy.get_meta("elemental")
		var frozen := elem.is_solid_frozen()
		var shield_chip := 55.0 if heavy else 25.0
		var base_damage := 46.0 * (CombatSystems.HEAVY_CLEAVE_MULTIPLIER if heavy else 1.0)
		var hit_color := Color("ffad70") if enemy.get_meta("armored", false) else Color("e2533c")
		if frozen:
			base_damage = 125.0
			shield_chip = CombatSystems.SHIELD_HP
			hit_color = Color("88e9f5")
			elem.clear_all()
			_sound_at("frost", enemy.global_position)
			narrative.show_style_banner("FROZEN SHATTER!", hit_color)
		elif had_counter:
			base_damage = 78.0
			shield_chip = CombatSystems.SHIELD_HP
			hit_color = Color("ffd875")
			narrative.show_style_banner("COUNTER-CLEAVE!", hit_color)
		var shield_broken := CombatSystems.damage_executioner_shield(self, enemy, shield_chip)
		var contact := enemy.global_position + Vector3.UP * (1.7 if enemy.get_meta("boss", false) else 1.15) - forward * 0.35
		var across := camera.global_basis.x * (-1.0 if axe_combo_step == 0 else 1.0)
		var spray := (forward * 0.55 + (Vector3.DOWN if heavy else across) * 0.55).normalized()
		_spell_impact(contact, hit_color, spray)
		_apply_warden_hit(enemy, int(base_damage * damage_mult), shield_chip, "")
		if heavy and (shield_broken or not enemies.has(enemy)):
			narrative.show_style_banner("EXECUTION CLEAVE!", Color("ffd875"))

	for pot: RigidBody3D in sweep.breakables:
		_smash_pot(pot)
		hitstop_time = 0.035
		camera_shake = maxf(camera_shake, 0.05)
	for ward: StaticBody3D in sweep.wards:
		_shatter_ward(ward)
		hitstop_time = 0.035
		camera_shake = maxf(camera_shake, 0.08)
	for target: Node3D in sweep.targets:
		if is_instance_valid(target) and shootable_targets.has(target):
			_hit_shootable_target(target, "axe")
	if sweep.pendulum:
		_hit_tower_pendulum()
	elif sweep.hit_world and sweep.enemies.is_empty() and sweep.breakables.is_empty() and sweep.wards.is_empty() and sweep.targets.is_empty():
		_message("STEEL STRIKES STONE", 0.5)
		camera_shake = maxf(camera_shake, 0.03)

func _apply_warden_hit(enemy: CharacterBody3D, base_dmg: int, aegis_chip: float, source_label: String, knockback: bool = true) -> void:
	var final_dmg := base_dmg
	if enemy.get_meta("kind") == "warden" and wards.is_empty():
		if float(enemy.get_meta("aegis_hp", 0.0)) > 0.0:
			CombatSystems.damage_warden_aegis(self, enemy, aegis_chip, source_label)
			final_dmg = maxi(1, roundi(base_dmg * CombatSystems.AEGIS_BLEED_THROUGH))
		elif float(enemy.get_meta("aegis_exposed_timer", 0.0)) > 0.0:
			final_dmg = roundi(base_dmg * CombatSystems.AEGIS_EXPOSED_MULTIPLIER)
	_damage_enemy(enemy, final_dmg, knockback)

func _damage_enemy(enemy: CharacterBody3D, damage: int, knockback: bool = true) -> void:
	if not is_instance_valid(enemy) or not enemies.has(enemy):
		return
	var kind: String = enemy.get_meta("kind")
	if kind == "warden" and not wards.is_empty():
		_message("RESONANT WARDS BLOCK ALL DAMAGE (%d REMAIN)!" % wards.size(), 1.4)
		_sound_at("hit", enemy.global_position)
		return
	var health: int = int(enemy.get_meta("hp")) - damage
	enemy.set_meta("hp", health)
	enemy.set_meta("hit_flash", 1.0)
	if health > 0 and knockback:
		var away := enemy.global_position - player.global_position
		away.y = 0
		if away.length() < 0.01:
			away = -player.global_transform.basis.z
		enemy.velocity += away.normalized() * (2.5 if enemy.get_meta("boss") else 4.2 if enemy.get_meta("armored") else 6.2)
		enemy.velocity.y = maxf(enemy.velocity.y, 1.5 if enemy.get_meta("boss") else 2.2)
		if float(enemy.get_meta("windup")) > 0.0:
			parry_window = 1.6
		enemy.set_meta("pending", "")
		enemy.set_meta("windup", 0.0)
		enemy.set_meta("stagger", maxf(float(enemy.get_meta("stagger")), 0.16 if enemy.get_meta("boss") else 0.30))
		enemy.set_meta("attack", maxf(float(enemy.get_meta("attack")), 0.55))
	hitmarker_time = 0.18
	labels.hitmarker.modulate = Color("ffd579") if health <= 0 else Color("ffaf7b")

	if kind == "warden":
		_state().boss_hp = maxi(0, health)
		_objective()
		if health > 0 and health <= 260 and boss_phase == 0:
			boss_phase = 1
			if story_director.has_sequence("ch2_tower/warden_phase_two"):
				story_director.start_sequence("ch2_tower/warden_phase_two")
			else:
				narrative.show_style_banner("PHASE II — REFLECT SONIC ORBS!", Color("d99cbd"))
	elif kind == "colossus":
		_state().colossus_hp = maxi(0, health)
		_objective()
		if health > 0 and health <= 320 and boss_phase == 0:
			boss_phase = 1
			Meshes3D.set_colossus_overdrive(enemy.get_meta("rig"), true)
			enemy.set_meta("colossus_overdrive_visual", true)
			story_director.start_sequence("ch3_kiln/colossus_overdrive")

	_sound_at("hit", enemy.global_position)
	var spark := LevelBuilder.cylinder(level_root, "impact", enemy.global_position + Vector3(0, 1.3, 0), 0.25, 0.4, mats.ember, false, 5)
	var spark_tween := create_tween().bind_node(spark)
	spark_tween.tween_property(spark, "scale", Vector3.ZERO, 0.22)
	spark_tween.tween_callback(spark.queue_free)
	enemy.scale = Vector3.ONE * 1.08
	create_tween().bind_node(enemy).tween_property(enemy, "scale", Vector3.ONE, 0.16)

	if health <= 0:
		enemy.get_meta("warning").visible = false
		var enemy_id: String = enemy.get_meta("id")
		if not _state().dead.has(enemy_id):
			_state().dead.append(enemy_id)
		enemy.collision_layer = 0
		enemy.collision_mask = 0
		enemies.erase(enemy)
		bosses.erase(enemy)
		var away_dir := enemy.global_position - player.global_position
		away_dir.y = 0
		away_dir = away_dir.normalized() if away_dir.length() > 0.01 else -player.global_transform.basis.z
		var gib_mat: Material = mats.ice if enemy.get_meta("elemental").is_frozen() else mats.cinder if (kind == "ash_sentinel" or kind == "colossus") else mats.blood
		var dec_kind := "frost" if enemy.get_meta("elemental").is_frozen() else "scorch" if (kind == "ash_sentinel" or kind == "colossus") else "blood"
		Visuals.spawn_gibs(level_root, enemy.global_position + Vector3(0, 0.9, 0), away_dir, gib_mat, rng, 12 if enemy.get_meta("boss") else 9, dec_kind)

		if kind == "warden":
			_state().boss_dead = true
			level_root.set_meta("warden_death_position", enemy.global_position)
			boss = null
			story_director.start_sequence("ch2_tower/belfry_shaft")
			ChapterTower.sync_visual_state(self, _state())
			_objective()
			enemy.queue_free()
		elif kind == "colossus":
			_state().colossus_dead = true
			boss = null
			level_root.set_meta("ladle_fall_pos", enemy.global_position)
			story_director.register_mark("ladle_fall", enemy.global_position + Vector3.UP)
			story_director.start_sequence("ch3_kiln/colossus_falls")
			_objective()
			enemy.queue_free()
		else:
			if kind == "executioner" or kind == "ash_sentinel" or kind == "stalker":
				_pickup(enemy.global_position + Vector3(0, 0.4, 0), "flask", "drop_" + enemy_id)
			enemy.queue_free()
			_message("FOE VANQUISHED", 1.0)

func _play_landing(impact_speed: float) -> void:
	camera_shake = maxf(camera_shake, minf(0.14, impact_speed * 0.012))
	landing_dip = 0.11
	var pos := player.global_position
	PhysicsSandbox.emit_noise(noise_events, pos, 14.0, 1.3)
	var wet := _is_wet_landing(pos)
	if wet:
		_sound("splash")
	var ash_heap := chapter_id == "ch3_kiln" and pos.distance_to(Vector3(0, 6.0, 25.4)) < 2.8
	if _fall_grace_time > 0.0 or impact_speed < 13.0 or ash_heap:
		_sound("land")
		return
	var fall_dmg := clampi(roundi((impact_speed - 12.2) * 7.5), 10, 120)
	if wet:
		fall_dmg = roundi(fall_dmg * 0.5)
	elif impact_speed >= FATAL_FALL_SPEED:
		fall_dmg = maxi(fall_dmg, hp)
	_apply_fall_damage(fall_dmg)

func _is_wet_landing(pos: Vector3) -> bool:
	for zone: Dictionary in wet_zones:
		if not zone.get("active", true) or zone.get("frozen", false) or float(zone.get("frozen_timer", 0.0)) > 0.0:
			continue
		var center: Vector3 = zone.pos
		var half: Vector2 = zone.half
		if absf(pos.x - center.x) <= half.x and absf(pos.z - center.z) <= half.y:
			var surface_y := center.y
			if is_instance_valid(cistern_water_node):
				var cistern := cistern_water_node.global_position
				if Vector2(center.x, center.z).is_equal_approx(Vector2(cistern.x, cistern.z)):
					surface_y = cistern.y
			if pos.y >= surface_y - 2.4 and pos.y <= surface_y + 0.15:
				return true
	return false

func _apply_fall_damage(fall_dmg: int, death_msg: String = "YOU FELL TO YOUR DEATH  •  PRESS R TO LOAD CHECKPOINT") -> void:
	if hp <= 0:
		return
	_sound("land")
	var tint := Color(0.75, 0.1, 0.05)
	if fall_dmg >= hp:
		_kill_player_by_fall(death_msg, tint)
		return
	hp -= fall_dmg
	flash = 1.0
	flash_color = tint
	camera_shake = maxf(camera_shake, 0.18)
	_sound("hurt")
	_refresh_hud_numbers()

func _chapter_kill_y() -> float:
	return -6.0 if chapter_id == "ch3_kiln" else -11.5

func _check_abyss() -> bool:
	if player.global_position.y >= _chapter_kill_y():
		return false
	if chapter_id == "ch3_kiln":
		_kill_player_by_fall("YOU FELL INTO THE ABYSS  •  PRESS R TO LOAD CHECKPOINT", Color(0.85, 0.25, 0.08))
	else:
		_kill_player_by_fall("YOU FELL INTO THE SUNKEN ABYSS  •  PRESS R TO LOAD CHECKPOINT", Color(0.15, 0.35, 0.55))
	return true

func _kill_player_by_fall(death_text: String, tint: Color) -> void:
	if hp <= 0:
		return
	hp = 0
	player.velocity = Vector3.ZERO
	flash = 1.0
	flash_color = tint
	camera_shake = maxf(camera_shake, 0.28)
	_sound("hurt")
	if chapter_id != "ch3_kiln" and player.global_position.y < _chapter_kill_y():
		_sound("splash")
	_refresh_hud_numbers()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_message(death_text, 9999.0)

func _hurt(amount: int, source: Vector3 = Vector3.ZERO, tint: Color = Color(0.75, 0.1, 0.05), attacker: CharacterBody3D = null) -> void:
	if CombatSystems.evaluate_parry(self, attacker, amount):
		_refresh_hud_numbers()
		narrative.show_style_banner("PERFECT PARRY! (+25 MANA)", Color("ffd875"))
		return
	if hurt_cooldown > 0.0 or hp <= 0:
		return
	var diff_mult := SaveSystem.difficulty_damage_multiplier(str(settings.get("difficulty", "Cinder-Breaker")))
	var scaled := maxi(1, roundi(float(amount) * diff_mult))
	hurt_cooldown = 0.55
	var away := player.global_position - source if source != Vector3.ZERO else player.global_transform.basis.z
	away.y = 0
	if away.length() > 0.01:
		player.velocity += away.normalized() * (4.0 + scaled * 0.08)
	view_kick = 0.11
	hp = maxi(0, hp - scaled)
	flash = 1.0
	flash_color = tint
	camera_shake = maxf(camera_shake, 0.18)
	_refresh_hud_numbers()
	if hp <= 0:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		labels.message.text = "YOU HAVE FALLEN  •  PRESS R TO LOAD CHECKPOINT"
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

func _find_unpick_lock() -> Node3D:
	if chapter_id != "ch1_court":
		return null
	var st := _state()
	var nearest: Node3D
	var distance := 2.8
	for node: Node3D in [cistern_sluice_lever, switch_node, shortcut_door]:
		if not _is_locked(node, st):
			continue
		var gap := player.global_position.distance_to(node.global_position + Vector3.UP)
		if gap < distance:
			nearest = node
			distance = gap
	if nearest != null:
		return nearest
	var origin := camera.global_position
	var ray := PhysicsRayQueryParameters3D.create(origin, origin - camera.global_basis.z * 3.5, LAYER_WORLD | LAYER_TARGET, [player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	var target := hit.get("collider") as Node3D
	while is_instance_valid(target) and target != level_root:
		if _is_locked(target, st):
			return target
		target = target.get_parent_node_3d()
	return null

func _is_locked(node: Node3D, st: Dictionary) -> bool:
	if not is_instance_valid(node) or not node.get_meta("unpick", false):
		return false
	var id := str(node.get_meta("lock_id", ""))
	return not id.is_empty() and not st.get(id + "_unpicked", false)

func _step_unpick(delta: float) -> void:
	if unpick_held and unpick_tumblers == 3:
		return
	var target := _find_unpick_lock() if unpick_held else null
	if target != unpick_lock or target == null:
		unpick_lock = target
		unpick_time = 0.0
		unpick_tumblers = 0
	if target == null:
		return
	unpick_time += delta
	var thresholds := [0.33, 0.66, 1.0]
	while unpick_tumblers < thresholds.size() and unpick_time + 0.000001 >= thresholds[unpick_tumblers]:
		_sound_at("key_turn", target.global_position, 0.85 + unpick_tumblers * 0.18)
		unpick_tumblers += 1
	if unpick_tumblers == 3:
		var id := str(target.get_meta("lock_id"))
		var st := _state()
		st[id + "_unpicked"] = true
		if id == "sluice_lock":
			st.sluice_unpicked = true
		_sound_at("lever", target.global_position)
		ChapterCourt.sync_visual_state(self, st)
		_message("LOCK UNPICKED  [ • • • ]", 0.9)

func _use() -> void:
	if hp <= 0 or _find_unpick_lock() != null:
		return
	for font in fonts:
		if is_instance_valid(font) and player.position.distance_to(font.position + Vector3(0, 1.0, 0)) < 2.6:
			flasks = maxi(flasks, 3)
			mana = max_mana
			green_mana = max_mana
			_sound("pickup")
			_refresh_hud_numbers()
			narrative.show_style_banner("FLASKS & MANA RESTORED", Color("70d7df"))
			return
	var st := _state()
	if chapter_id == "ch1_court":
		if is_instance_valid(cistern_sluice_lever) and not st.get("cistern_raised", false) and player.position.distance_to(cistern_sluice_lever.position + Vector3(0, 1.0, 0)) < 2.8:
			if not st.sluice_lock_unpicked:
				return
			st.cistern_raised = true
			story_director.start_sequence("ch1_court/cistern_sluice")
			ChapterCourt.sync_visual_state(self, st)
			_objective()
			return
		if is_instance_valid(switch_node) and not gate_open and player.position.distance_to(switch_node.position + Vector3(0, 1.2, 0)) < 2.8:
			if not st.get("has_lever", false):
				_message("THE GEARBOX NEEDS THE IRON LEVER FROM THE EAST OSSUARY", 2.8)
				return
			if not st.gearbox_unpicked:
				return
			if not st.lever_inserted:
				st.lever_inserted = true
				switch_node.get_meta("lever_arm").visible = true
				_sound("lever")
			ChapterCourt.sync_visual_state(self, st)
			_message(str(switch_node.get_meta("interact_hint", "")), 2.8)
			_objective()
			return
		if is_instance_valid(shortcut_door) and not st.get("shortcut_open", false) and player.position.distance_to(shortcut_door.position + Vector3(0, 1.5, 0)) < 2.8:
			if player.position.x > shortcut_door.global_position.x and st.ossuary_gate_unpicked:
				st.shortcut_open = true
				shortcut_door.collision_layer = 0
				create_tween().bind_node(shortcut_door).tween_property(shortcut_door, "position:y", 4.6, 0.5)
				_sound("lever")
				narrative.show_style_banner("CLOISTER SHORTCUT UNBARRED!", Color("ffd875"))
			else:
				_message("BARRED FROM THE EAST OSSUARY SIDE", 2.0)
			return
	elif chapter_id == "ch2_tower":
		if is_instance_valid(lift_call_lever) and not st.get("lift_completed", false) and player.position.distance_to(lift_call_lever.position + Vector3(0, 1.0, 0)) < 2.8:
			if not st.get("lift_powered", false):
				_message("LIFT UNPOWERED — ZAP THE COPPER CONDUIT IN THE CLOCKWORK GALLERY [4]", 3.0)
				return
			moving_lift["active"] = true
			_sound("lever")
			_sound("lift")
			narrative.show_style_banner("COUNTERWEIGHT LIFT ENGAGED!", Color("69dae8"))
			return
	elif chapter_id == "ch3_kiln":
		if is_instance_valid(aqueduct_valve) and not st.get("trough_flooded", false) and player.position.distance_to(aqueduct_valve.position + Vector3(0, 1.0, 0)) < 2.8:
			if not st.get("aqueduct_powered", false):
				_message("AQUEDUCT PUMP UNPOWERED — ZAP THE CONDUIT WITH VOLTAIC FORK [4]!", 3.0)
				return
			st.trough_flooded = true
			if is_instance_valid(trough_water):
				trough_water.visible = true
			create_tween().bind_node(aqueduct_valve.get_meta("wheel")).tween_property(aqueduct_valve.get_meta("wheel"), "rotation:y", TAU, 0.6)
			story_director.start_sequence("ch3_kiln/aqueduct_surge")
			_objective()
			return
		if is_instance_valid(hoist_lever) and player.position.distance_to(hoist_lever.position + Vector3(0, 1.2, 0)) < 2.8:
			var feedback := ChapterKiln.pull_hoist_lever(self)
			if not feedback.is_empty():
				_message(feedback, 2.8)
			return
		if not st.get("great_gate_open", false) and player.global_position.distance_to(ChapterKiln.GATE_APPROACH) < 4.0:
			var feedback := ChapterKiln.turn_great_gate(self)
			if not feedback.is_empty():
				_message(feedback, 2.8)
			return

	for inscription in inscriptions:
		if is_instance_valid(inscription.node) and player.global_position.distance_to(inscription.node.global_position + Vector3.UP) < 2.4:
			_message("%s\n%s" % [inscription.title, inscription.writing], 5.5)
			_story_event("inscription_" + inscription.title.to_lower().replace(" ", "_"), inscription.title, inscription.writing)
			var on_read: Callable = inscription.get("on_read", Callable())
			if on_read.is_valid():
				on_read.call()
			var inscription_id := str(inscription.get("id", ""))
			var title := str(inscription.title).to_upper()
			if inscription_id == "hesk_planks" or title in ["HESK", ChapterCourt.HESK_TITLE]:
				level_states["ch1_court"].read_hesk_planks = true
			if inscription_id == "tithe_roll" or title == "THE TITHE ROLL":
				level_states["ch3_kiln"].read_tithe_roll = true
			return
	for npc in npc_nodes:
		if is_instance_valid(npc.node) and npc.node.is_visible_in_tree() and player.global_position.distance_to(npc.node.global_position + Vector3(0, 1.2, 0)) < 4.0:
			_trigger_npc_dialogue(npc)
			return

func _win() -> void:
	won = true
	narrative.show_act_complete_banner()
	_on_checkpoint_reached("kiln_act_complete", "Act I Complete")
	_objective()

func _save_game() -> void:
	if hp <= 0:
		return
	if SaveSystem.write_save(self, false):
		narrative.show_style_banner("QUICKSAVE WRITTEN", Color("ffd875"))

func _load_game(from_checkpoint: bool = false) -> void:
	var data := SaveSystem.read_save(from_checkpoint)
	if data.is_empty():
		_message("NO SAVED GAME FOUND", 2.0)
		return
	_message("", 0.0)
	_init_level_states()
	var saved_states: Dictionary = data.get("level_states", {})
	for cid: String in saved_states:
		var merged := ChapterRegistry.default_state(cid)
		merged.merge(saved_states[cid], true)
		level_states[cid] = merged
	has_arbalest = bool(data.get("has_arbalest", false))
	has_thurible = bool(data.get("has_thurible", false))
	has_voltaic = bool(data.get("has_voltaic", false))
	has_ashen_key = bool(data.get("has_ashen_key", false))
	hp = int(data.get("hp", 100))
	max_hp = int(data.get("max_hp", 100))
	mana = int(data.get("mana", 75))
	max_mana = int(data.get("max_mana", 100))
	green_mana = int(data.get("green_mana", 45))
	damage_mult = float(data.get("damage_mult", 1.0))
	mana_regen_rate = float(data.get("mana_regen_rate", 0.0))
	flasks = int(data.get("flasks", 2))
	mode = int(data.get("mode", 0))
	story_flags.clear()
	for flag in data.get("story_flags", []):
		story_flags.append(str(flag))
	journal_entries.clear()
	for entry in data.get("journal_entries", []):
		if entry is Dictionary:
			journal_entries.append(entry)
	seen_echoes = data.get("seen_echoes", {}).duplicate(true)
	triggered_volumes = data.get("triggered_volumes", {}).duplicate(true)

	_load_chapter(str(data.get("chapter_id", "ch1_court")), false, false)
	var pos: Array = data.get("pos", [])
	var default_spawn: Vector3 = ChapterRegistry.get_chapter_meta(chapter_id).default_spawn
	player.position = Vector3(float(pos[0]), float(pos[1]), float(pos[2])) if pos.size() == 3 else default_spawn
	player.rotation.y = float(data.get("yaw", 0.0))
	pitch = float(data.get("pitch", 0.0))
	head.rotation.x = pitch
	_build_weapon()
	_refresh_hud_numbers()
	_reset_arrival_motion()
	won = bool(level_states["ch3_kiln"].get("act_complete", false))
	ending_panel.visible = false
	_objective()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	narrative.show_style_banner("CHECKPOINT LOADED" if from_checkpoint else "QUICKSAVE LOADED", Color("70d7df"))
