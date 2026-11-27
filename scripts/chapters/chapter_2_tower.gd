extends RefCounted

const L = preload("res://scripts/level_builder.gd")
const Meshes = preload("res://scripts/meshes_3d.gd")
const Visuals = preload("res://scripts/visuals.gd")
const PhysicsSandbox = preload("res://scripts/physics_sandbox.gd")

const BELFRY_SHAFT := Vector3(0, 9.5, -42)
const CHAPTER := "ch2_tower"
const PREFIX := CHAPTER + "/"
const MALCOR_HIDDEN := Vector3(-8.8, 6, -13.5)
const MALCOR_RAIL := Vector3(-6.5, 6, -10.65)
const MALCOR_VIGIL := Vector3(5.8, 6, -22.4)
const CHANDELIER_LAND := Vector3(0, 0, 9.5)
const SEAL_CENTER := Vector3(0, 12.3, -30.8)
const WARD_ANCHORS := {
	"ward_1": Vector3(-31.1, 1.65, 0.5),
	"ward_2": Vector3(31.2, 5.15, -4.8),
	"ward_3": Vector3(-14.25, 7.65, -19.9),
}
const WARD_COLORS := {"ward_1": "82e6ff", "ward_2": "ffc385", "ward_3": "bba1ff"}
const BRONZE_LIGHT := Color("ffc385")
const CYAN_LIGHT := Color("82e6ff")
const VIOLET_LIGHT := Color("bba1ff")

static func default_state() -> Dictionary:
	return {
		"wards": [], "gear_frozen": false, "lift_powered": false, "lift_unjammed": false,
		"lift_completed": false, "boss_dead": false, "boss_hp": 520,
		"vestibule_shut": false, "malcor_balcony_done": false, "nave_woken": false,
		"choir_confronted": false, "lift_ambush_done": false, "bell_fallen": false,
		"malcor_confessed": false,
		"story_world": {
			"nave_chandelier_fallen": false, "malcor_departed": false,
			"belfry_shaft_open": false, "malcor_mark": "malcor_hidden",
			"completed_sequences": {},
		},
	}

static func build(game, st: Dictionary) -> void:
	var root: Node3D = game.level_root
	var director: Node = game.get("story_director")
	var defaults := default_state()
	st.merge(defaults)
	var world: Dictionary = st.story_world
	var legacy_departure: bool = not world.has("malcor_departed") and st.wards.size() >= WARD_ANCHORS.size()
	world.merge(defaults.story_world)
	# Legacy saves and saves taken after the killing blow owe the shaft opening.
	if st.boss_dead:
		st.bell_fallen = true
		world.belfry_shaft_open = true
	elif world.belfry_shaft_open:
		world.belfry_shaft_open = false
	if st.choir_confronted or game.story_flags.has("npc_malcor_choir") or legacy_departure:
		world.malcor_departed = true
		st.choir_confronted = true
	if world.malcor_departed or world.nave_chandelier_fallen or st.malcor_balcony_done:
		st.malcor_balcony_done = true
		world.nave_chandelier_fallen = true
		st.nave_woken = true
	_vestibule(game, root)
	_lower_nave(game, root)
	_clockwork_gallery(game, root, st)
	_pendulum_foundry(game, root, st)
	_counterweight_lift(game, root, st)
	_choir_loft(game, root, st)
	_belfry(game, root)
	L.add_far_landmarks(game, root, Vector3(0, 0, 77), {"keep": false, "bell": false})
	sync_visual_state(game, st)
	if is_instance_valid(director):
		_register_story(game, root, st, director)
	game._scatter_particles("ember", 80, Rect2(-33, -55, 66, 81))

static func _ward_waymark(game, root: Node3D, id: String, pos: Vector3, yaw: float) -> void:
	var ward: Dictionary = L.BELFRY_WARDS[id]
	var plaque := L.box(root, id + "_waymark", pos, Vector3(4.25, 0.72, 0.16), game.mats.dark, false)
	plaque.rotation.y = yaw
	var glow: Material = game._material(ward.color, true)
	for x: float in [-1.93, 1.93]:
		var rune := L.box(plaque, "waymark_rune", Vector3(x, 0, 0.1), Vector3(0.25, 0.25, 0.045), glow, false)
		rune.rotation.z = PI * 0.25
	var label := Label3D.new()
	label.text = ward.label
	label.position.z = 0.09
	label.font_size = 48
	label.pixel_size = 0.008
	label.modulate = ward.color
	plaque.add_child(label)

static func _lower_nave(game, root: Node3D) -> void:
	L.slab(root, "lower_nave", Rect2(-16, -11, 32, 38), 0, game.mats.stone)
	L.box(root, "choir_foundation", Vector3(0, 2.6, -10.99), Vector3(32, 5.2, 0.8), game.mats.dark)
	for x: float in [-9.65, 9.65]:
		L.box(root, "nave_south_wall", Vector3(x, 5.8, 27), Vector3(12.7, 11.6, 1.1), game.mats.dark)
	L.box(root, "nave_south_header", Vector3(0, 9.4, 27), Vector3(6.6, 4.4, 1.1), game.mats.dark)
	for x: float in [-16, 16]:
		L.box(root, "nave_side_wall_south", Vector3(x, 5.8, 19.35), Vector3(1.1, 11.6, 15.3), game.mats.dark)
		L.box(root, "nave_side_wall_north", Vector3(x, 5.8, -10.7), Vector3(1.1, 11.6, 1), game.mats.dark)
		for z: float in [15, 9.5, 3.5, -4.0]:
			L.cylinder(root, "nave_clustered_pier", Vector3(x * 0.90625, 3.65, z), 0.75, 7.3, game.mats.stone, true, 12)
			L.cylinder(root, "nave_capital", Vector3(x * 0.90625, 7.25, z), 0.96, 0.54, game.mats.brass, false, 12)
			game._torch(Vector3(x * 0.91, 3.2, z))
	L.box(root, "nave_roof", Vector3(0, 16, 8), Vector3(32, 0.9, 38), game.mats.dark, false)
	for z: float in [22, 15, 9.5, 3.5, -4]:
		L.vaulted_rib(root, Vector3(0, 7.3, z), 29, 8.4, game.mats.stone, game.mats.brass)
	for z: float in [22, -4]:
		L.hanging_chain_lamp(game, root, Vector3(0, 6.8, z), 8.15, BRONZE_LIGHT, 5.7, 14.0)
	for pos: Vector3 in [Vector3(-5, 9.5, 11), Vector3(5, 9, 5), Vector3(0, 11, -3)]:
		game._hanging_bell(pos)
		L.cylinder(root, "nave_bell_chain", pos + Vector3.UP * 3, 0.14, 6, game.mats.iron, false, 8)
	for z: float in [15, 22]:
		game._stained_glass(Vector3(15.35, 6.7, z), false)
		var window_light := VIOLET_LIGHT if z == 22 else CYAN_LIGHT
		Visuals.spawn_godray(root, Vector3(9.0, 3.5, z), Vector3(0, 0, -63), 2.6, 13.4, Color(window_light, 0.23))
		L.focus_light(root, Vector3(15.15, 6.65, z), Vector3(4.8, 0.15, z), window_light, 7.2, 26.0, 2.15)
	L.hanging_chain_lamp(game, root, Vector3(-14.6, 4.4, 2.4), 1.75, CYAN_LIGHT, 3.8, 9.0)
	L.hanging_chain_lamp(game, root, Vector3(14.6, 4.4, 5), 1.75, BRONZE_LIGHT, 3.8, 9.0)
	L.add_alchemical_font(game, Vector3(-6.5, 0, 19))
	L.add_checkpoint_zone(game, Vector3(0, 1.4, 20), Vector3(11, 2.8, 3), "tower_nave", "Lower Nave")
	_nave_chandelier(game, root)
	L.focus_light(root, Vector3(-4.4, 9.8, -7.65), MALCOR_RAIL + Vector3.UP * 1.3, VIOLET_LIGHT, 4.8, 26.0)
	L.add_explosive_cask(game, Vector3(-5, 0, 6.5), "tower_cask_nave")
	game._pickup(Vector3(10, 0.55, 15.7), "mana", "tower_blue_1")

static func _clockwork_gallery(game, root: Node3D, st: Dictionary) -> void:
	L.slab(root, "clockwork_floor", Rect2(-34, -10, 18, 22), 0, game.mats.stone)
	L.archway(root, "clockwork_entry", Vector3(-16, 0, 2.4), 7.5, 6, 1.5, game.mats.stone, game.mats.brass, PI * 0.5)
	_ward_waymark(game, root, "ward_1", Vector3(-14.95, 6.65, 2.4), PI * 0.5)
	for z: float in [-10, 12]:
		L.box(root, "clockwork_end_wall", Vector3(-25, 4.6, z), Vector3(18, 9.2, 1.0), game.mats.dark)
	L.box(root, "clockwork_outer_wall", Vector3(-34, 4.6, 1), Vector3(1.1, 9.2, 22), game.mats.dark)
	L.box(root, "clockwork_roof", Vector3(-25, 8.8, 1), Vector3(18, 0.8, 22), game.mats.dark, false)
	L.hanging_chain_lamp(game, root, Vector3(-21.4, 4.65, 1.3), 3.35, BRONZE_LIGHT, 4.3, 11.5)
	L.iron_grate_floor(root, Vector3(-22.4, 0, -5.95), Vector2(3.75, 1.15), game.mats.iron)
	for x: float in [-31.5, -24, -19]:
		var rib := L.vaulted_rib(root, Vector3(x, 4.8, 1), 19.5, 4.2, game.mats.stone, game.mats.brass)
		rib.rotation.y = PI * 0.5
	L.box(root, "gear_vault_divider_north", Vector3(-28.2, 2.8, -5.45), Vector3(1.0, 5.6, 9.1), game.mats.dark)
	L.box(root, "gear_vault_divider_south", Vector3(-28.2, 2.8, 6.95), Vector3(1.0, 5.6, 10.1), game.mats.dark)
	L.box(root, "gear_aperture_crown", Vector3(-28.2, 5.55, 0.5), Vector3(1, 2.1, 5.0), game.mats.stone)
	if not st.wards.has("ward_1"):
		game._ward(Vector3(-31.1, 0, 0.5), "ward_1")
		if not st.gear_frozen:
			var gear := L.cylinder(root, "rotating_cogwheel", Vector3(-28, 2.2, 0.5), 2.35, 0.6, game.mats.iron, true, 16)
			gear.rotation.z = PI * 0.5
			gear.set_meta("interact_hint", "MOON-CLOCK ESCAPEMENT — FREEZE THE PIPE OR GEAR [RMB]")
			for i in 12:
				var angle := TAU * float(i) / 12.0
				var tooth := L.box(gear, "gear_tooth", Vector3(cos(angle) * 2.34, 0, sin(angle) * 2.34), Vector3(0.42, 0.77, 0.5), game.mats.brass, false)
				tooth.rotation.y = -angle
			game.tower_gear = gear
			var pipe := L.cylinder(root, "leaking_steam_pipe", Vector3(-24.6, 1.6, -3.25), 0.42, 2.8, game.mats.copper, true, 12, L.LAYER_TARGET)
			pipe.set_meta("steam_pipe", true)
			pipe.set_meta("interact_hint", "MOON-CLOCK STEAM PIPE — FREEZE WITH FROST [RMB]")
			var steam := L.add_steam_jet(root, Vector3(-24.6, 2.7, -3.25), Vector3(-1.0, 0.5, 0.4))
			pipe.set_meta("mist", steam)
			L.watch_puzzle(pipe, func() -> void: steam.emitting = not st.gear_frozen)
			game.shootable_targets.append(pipe)
			game._light(Vector3(-24.6, 2, -3.25), Color("9ee9f5"), 2, 6)
			L.cylinder(root, "steam_feed", Vector3(-24.6, 3.75, -3.25), 0.16, 2.25, game.mats.iron, false, 10)
			L.focus_light(root, Vector3(-23.15, 5.25, -1.5), pipe.position, CYAN_LIGHT, 4.8, 22.0, 0.55)
	game._torch(Vector3(-23.2, 2.7, 7))
	game._torch(Vector3(-23.2, 2.7, -7.5))
	L.box(root, "fork_workbench", Vector3(-22.5, 0.43, -7.2), Vector3(3.4, 0.86, 1.45), game.mats.copper)
	L.box(root, "workbench_terminal", Vector3(-23.65, 0.99, -7.2), Vector3(0.5, 0.26, 0.5), game.mats.mana, false)
	game._pickup(Vector3(-22.5, 1.17, -7.2), "voltaic", "tower_voltaic")
	var power := L.add_voltaic_conduit(game, Vector3(-20, 1.25, -7.2), "conduit_lift_power", "Ascending Lift")
	power.set_meta("interact_hint", "LIFT CONDUIT — STRIKE WITH THE FORK [4]")
	power.set_meta("powered", st.lift_powered)
	L.focus_light(root, Vector3(-22.5, 5.15, -8.65), Vector3(-22.5, 1.17, -7.2), BRONZE_LIGHT, 5.25, 23.0)
	L.focus_light(root, Vector3(-18.65, 4.15, -7.7), Vector3(-20, 1.25, -7.2), CYAN_LIGHT, 3.0, 23.0)
	_moon_clock(game, root, st)
	_pell_workbench(game, root)
	L.add_checkpoint_zone(game, Vector3(-18.5, 1.4, 2.4), Vector3(2.8, 2.8, 5), "tower_west", "Moon-Clock Gallery")
	L.box(root, "gear_secret_back", Vector3(-32.9, 2.2, 8.7), Vector3(1.0, 4.4, 6.0), game.mats.dark)
	L.box(root, "gear_secret_front", Vector3(-30.65, 2.2, 5.9), Vector3(4.5, 4.4, 0.7), game.mats.dark)
	L.add_rotten_barricade(game, Vector3(-30.75, 1.2, 3.55), "tower_secret_bar_1", Vector3(3.5, 2.4, 0.45), true)
	L.focus_light(root, Vector3(-32.4, 3.5, 2.1), Vector3(-30.75, 1.2, 3.55), BRONZE_LIGHT, 1.8, 23.0)
	# Ward chamber opens into a smaller vault beyond the breakable barricade.
	L.box(root, "gear_secret_bar_jamb_w", Vector3(-33.15, 2, 3.55), Vector3(1.35, 4, 0.55), game.mats.dark)
	L.box(root, "gear_secret_bar_jamb_e", Vector3(-28.7, 2, 3.55), Vector3(0.8, 4, 0.55), game.mats.dark)
	game._pickup(Vector3(-31, 0.85, 4.9), "relic_siphon", "relic_siphon_signet")
	game._pickup(Vector3(-32.35, 0.55, 4.9), "flask", "tower_secret_flask_1")
	game._enemy(Vector3(-22.5, 0, 1), true, "tower_west_exec", false, "executioner")
	game._enemy(Vector3(-26.0, 0.0, 6.2), false, "tower_west_aco", false, "acolyte")
	game._enemy(Vector3(-20.5, 0, 8), false, "tower_west_shr_a", false, "shrieker")
	game._enemy(Vector3(-29, 0, -6.5), false, "tower_west_shr_b", false, "shrieker")

static func _pendulum_foundry(game, root: Node3D, st: Dictionary) -> void:
	L.slab(root, "pendulum_foundry_floor", Rect2(16, -10, 18, 22), 0, game.mats.stone)
	L.slab(root, "pendulum_foundry_balcony", Rect2(16, -10, 18, 10), 3.5, game.mats.timber)
	L.archway(root, "pendulum_foundry_entry", Vector3(16, 0, 5), 7.8, 6, 1.4, game.mats.stone, game.mats.brass, PI * 0.5)
	_ward_waymark(game, root, "ward_2", Vector3(14.95, 6.65, 5), -PI * 0.5)
	L.box(root, "foundry_west_wall", Vector3(16, 2.7, -4.8), Vector3(0.85, 5.4, 10.4), game.mats.dark)
	L.box(root, "foundry_outer_wall", Vector3(34, 5.5, 1), Vector3(1, 11, 22), game.mats.dark)
	for z: float in [-10, 12]:
		L.box(root, "foundry_end_wall", Vector3(25, 5.5, z), Vector3(18, 11, 1), game.mats.dark)
	L.box(root, "foundry_roof", Vector3(25, 11, 1), Vector3(18, 0.8, 22), game.mats.dark, false)
	L.hanging_chain_lamp(game, root, Vector3(21.8, 5.3, 4.1), 4.9, BRONZE_LIGHT, 4.5, 11.0)
	L.hanging_chain_lamp(game, root, Vector3(20.4, 7.25, -7.55), 2.95, BRONZE_LIGHT, 2.7, 8.0)
	L.staircase(root, "foundry_guarded_stair", Vector3(21, 0, 8.3), Vector3(21, 3.5, 0.08), 4.5, game.mats.stone, game.mats.iron)
	L.box(root, "foundry_balcony_rail_w", Vector3(17.25, 4.07, -0.15), Vector3(2.5, 1.15, 0.3), game.mats.iron)
	L.box(root, "foundry_balcony_rail_e", Vector3(28.9, 4.07, -0.15), Vector3(9.6, 1.15, 0.3), game.mats.iron)
	L.vaulted_rib(root, Vector3(25, 7.05, -4.7), 16, 3.9, game.mats.stone, game.mats.brass)
	L.box(root, "thurible_altar", Vector3(20.4, 3.77, -7.55), Vector3(2.5, 0.54, 1.82), game.mats.brass)
	if not game.has_thurible:
		game._pickup(Vector3(20.4, 4.48, -7.55), "thurible", "tower_thurible")
	game._light(Vector3(20.4, 5.6, -7.55), Color("ff8f44"), 2.2, 6.5)
	L.box(root, "ward2_divider_south", Vector3(28.1, 6, -1.25), Vector3(0.9, 5, 2.5), game.mats.dark)
	L.box(root, "ward2_divider_north", Vector3(28.1, 6, -8.65), Vector3(0.9, 5, 2.7), game.mats.dark)
	if not st.wards.has("ward_2"):
		game._ward(Vector3(31.2, 3.5, -4.8), "ward_2")
		var wall := L.box(root, "cracked_brick_wall", Vector3(28.1, 5.65, -4.9), Vector3(0.72, 4.3, 4.9), game.mats.clay) as StaticBody3D
		wall.set_meta("interact_hint", "CRACKED BRICK WALL — SWING BRONZE CLAPPER INTO IT")
		_add_foundry_fissures(game, wall)
		game.tower_cracked_wall = wall
		var pivot := Vector3(24.8, 8.5, -4.9)
		L.box(root, "pendulum_support", pivot + Vector3.UP * 0.2, Vector3(1.4, 0.42, 8.4), game.mats.iron, false)
		var pendulum := PhysicsSandbox.create_hinged_pendulum(root, pivot, 3.35, game.mats.brass, game.mats.iron)
		var bob: RigidBody3D = pendulum.bob
		bob.contact_monitor = true
		bob.max_contacts_reported = 4
		bob.set_meta("pendulum", true)
		bob.set_meta("interact_hint", "CROWN CLAPPER — REPULSE [Q] TWICE FROM THE WEST")
		bob.set_meta("hits", 0)
		bob.set_meta("base_pos", bob.position)
		game.hinged_pendulum = pendulum
		game.tower_pendulum = bob
		game._light(bob.position + Vector3.UP * 0.6, Color("f2b955"), 1.9, 6)
		L.focus_light(root, Vector3(23.4, 9.4, -2.55), bob.position, BRONZE_LIGHT, 5.9, 25.0, 0.52)
	_foundry_tableaux(game, root)
	L.add_checkpoint_zone(game, Vector3(18.3, 1.4, 5), Vector3(2.8, 2.8, 4.8), "tower_east", "Bell Foundry")
	game._enemy(Vector3(31.5, 0, 4.4), false, "tower_east_shr", false, "shrieker")
	game._enemy(Vector3(25.5, 3.5, -6.9), false, "tower_east_aco", false, "acolyte")
	game._enemy(Vector3(24.5, 0, 7.5), true, "tower_east_exec", false, "executioner")
	L.add_explosive_cask(game, Vector3(25.9, 0, 5.8), "tower_cask_foundry")

static func _add_foundry_fissures(game, wall: StaticBody3D) -> void:
	var amber: Material = game._material(BRONZE_LIGHT, true)
	var violet: Material = game._material(VIOLET_LIGHT, true)
	var branches: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(-1.9, 1.95), Vector2(-1.2, 0.75), Vector2(-0.43, 0.48), Vector2(-0.2, -0.31), Vector2(0.49, -0.88), Vector2(0.68, -2.06)]),
		PackedVector2Array([Vector2(-0.43, 0.48), Vector2(0.23, 0.97), Vector2(1.23, 1.12), Vector2(1.85, 1.89)]),
		PackedVector2Array([Vector2(-0.2, -0.31), Vector2(-0.98, -0.76), Vector2(-1.41, -0.66), Vector2(-2.28, -1.38)]),
		PackedVector2Array([Vector2(0.49, -0.88), Vector2(1.35, -0.79), Vector2(2.29, -1.23)]),
	]
	for i in branches.size():
		var branch := branches[i]
		for j in range(1, branch.size()):
			var start := branch[j - 1]
			var end := branch[j]
			var mid := (start + end) * 0.5
			var delta := end - start
			var seam := L.box(wall, "glowing_fissure", Vector3(-0.365, mid.y, mid.x), Vector3(0.028, 0.065 if i == 0 else 0.036, delta.length() + 0.035), amber if i == 0 else violet, false)
			seam.rotation.x = -delta.angle()

static func _counterweight_lift(game, root: Node3D, st: Dictionary) -> void:
	var size := Vector3(8.4, 0.44, 6.8)
	var start := Vector3(0, 0.04 - size.y * 0.5, -6.57)
	var finish := Vector3(start.x, 6.0 - size.y * 0.5, start.z)
	for x: float in [-5.1, 5.1]:
		L.box(root, "lift_guide", Vector3(x, 4.7, -8.8), Vector3(0.45, 9.4, 0.44), game.mats.iron)
		L.box(root, "lift_guide", Vector3(x, 4.7, -3.6), Vector3(0.45, 9.4, 0.44), game.mats.iron)
		L.hanging_chain(root, Vector3(x, 9.25, -8.75), Vector3(x, 1.9, -8.75), 0.105, game.mats.iron)
	L.box(root, "lift_guide_crosshead", Vector3(0, 9.3, -8.8), Vector3(10.65, 0.57, 0.78), game.mats.iron, false)
	var lift := PhysicsSandbox.create_moving_lift(root, start, finish, size, game.mats.timber, game.mats.brass)
	var body: AnimatableBody3D = lift.body
	# Open the boarding end of the common lift cage. Keep the flank rails.
	for part: Node3D in body.get_children():
		if is_zero_approx(part.position.x) and part.position.z > size.z * 0.45:
			body.remove_child(part)
			part.queue_free()
	lift["powered"] = st.lift_powered
	if st.lift_unjammed:
		lift.jam_point = INF
	if st.lift_completed:
		body.position = finish
		lift.progress = 1.0
		lift.completed = true
	game.moving_lift = lift
	game.lift_call_lever = L.lever(root, "lift_call_lever", Vector3(-3.35, 0, -2.86), game.mats.dark, game.mats.brass,
		"LIFT CALL LEVER — POWER WEST GALLERY CONDUIT [4], THEN PULL [E]")
	var route := PackedVector3Array([
		Vector3(-20, 0, -7.2), Vector3(-20, 0, 2.4), Vector3(-13.9, 0, 2.4),
		Vector3(-13.9, 0, 8.65), Vector3(-6.2, 0, 8.65), Vector3(-6.2, 0, -2.86), Vector3(-3.35, 0, -2.86),
	])
	var conduit := L.add_floor_conduit(root, route, game._material(Color("9e6941"), true), game._material(CYAN_LIGHT, true), 0.26)
	root.set_meta("floor_conduits", {"lift_power": conduit})
	L.watch_puzzle(conduit, func() -> void: L.set_floor_conduit_powered(conduit, st.lift_powered))
	L.focus_light(root, Vector3(-4.85, 4.3, -3.42), Vector3(-3.35, 0.95, -2.86), BRONZE_LIGHT, 3.7, 26.0)
	if not st.lift_unjammed and not st.lift_completed:
		var latch := L.cylinder(root, "lift_gear_latch", Vector3(0.8, 4.65, -9.72), 0.43, 0.62, game.mats.mana, true, 10, L.LAYER_TARGET)
		latch.set_meta("lift_latch", true)
		latch.set_meta("interact_hint", "LIFT PAWL — YOUR MASTER’S MARK — SHOOT TO CLEAR THE JAM")
		game.shootable_targets.append(latch)
		game._light(latch.position, Color("69dae8"), 1.5, 5)
		L.focus_light(root, Vector3(2.15, 8.9, -8.65), latch.position, CYAN_LIGHT, 5.9, 23.0, 0.72)
	for x: float in [-11.05, 11.05]:
		L.staircase(root, "flanking_choir_stair", Vector3(x, 0, 7.8), Vector3(x, 6, -10.0), 4.5, game.mats.stone, game.mats.iron)
	game._enemy(Vector3(5.9, 0, -7.2), false, "tower_lift_aco", false, "acolyte")
	for x: float in [-4.85, 4.85]:
		var lamp := L.hanging_chain_lamp(game, root, Vector3(x, 4.85, -8.15), 2.7, CYAN_LIGHT, 2.2, 6.0)
		L.watch_puzzle(lamp, func() -> void: lamp.visible = st.lift_powered and not bool(lift.get("jammed", false)))

static func _choir_loft(game, root: Node3D, st: Dictionary) -> void:
	L.slab(root, "choir_loft", Rect2(-16, -28, 32, 18), 6, game.mats.stone)
	for x: float in [-16, 16]:
		L.box(root, "choir_side_wall", Vector3(x, 8.9, -19), Vector3(1.0, 7.0, 18), game.mats.dark)
		for z: float in [-22.5, -15.2]:
			game._stained_glass(Vector3(x * 0.959, 10.5, z), x < 0)
			game._torch(Vector3(x * 0.92, 8.3, z))
		var window_light := CYAN_LIGHT if x < 0 else VIOLET_LIGHT
		var shaft_z := -15.2 if x < 0 else -22.5
		Visuals.spawn_godray(root, Vector3(x * 0.675, 8.1, shaft_z), Vector3(0, 0, -signf(x) * 63), 2.6, 10.2, Color(window_light, 0.26))
		L.focus_light(root, Vector3(x * 0.951, 10.55, shaft_z), Vector3(x * 0.4, 6.15, shaft_z), window_light, 6.9, 27.0, 2.0)
	for z: float in [-26.2, -20.3, -13]:
		L.vaulted_rib(root, Vector3(0, 10.8, z), 31, 5.6, game.mats.stone, game.mats.brass)
		if z > -26:
			L.hanging_chain_lamp(game, root, Vector3(0, 11, z), 4.9, BRONZE_LIGHT, 4.4, 12.0)
	for x: float in [-14.75, -6.53, 6.53, 14.75]:
		# Open balusters preserve the view of Malcor from the Nave.
		var width := 2.5 if absf(x) > 14 else 4.63
		L.box(root, "choir_south_rail", Vector3(x, 7.05, -10.15), Vector3(width, 0.16, 0.18), game.mats.iron)
		for i in range(6):
			L.box(root, "choir_baluster", Vector3(x + width * (float(i) / 5.0 - 0.5), 6.5, -10.15), Vector3(0.105, 1.05, 0.13), game.mats.iron)
	for x: float in [-9.74, 9.74]:
		L.box(root, "choir_north_guard", Vector3(x, 6.64, -27.85), Vector3(12.6, 1.28, 0.5), game.mats.iron)
	L.box(root, "choir_balcony_pier", Vector3(-8.8, 8.4, -12.25), Vector3(1.55, 4.8, 0.95), game.mats.stone)
	_vigil_altar(game, root)
	L.archway(root, "choir_watch_arch", Vector3(0, 6, -27.6), 4.8, 5.4, 0.65, game.mats.stone, game.mats.brass)
	L.add_checkpoint_zone(game, Vector3(0, 7.45, -16.8), Vector3(13, 3, 4.6), "tower_choir", "Choir Loft")
	_ward_waymark(game, root, "ward_3", Vector3(-11.15, 10.7, -19.9), PI * 0.5)
	if not st.wards.has("ward_3"):
		game._ward(Vector3(-14.25, 6, -19.9), "ward_3")
		for z: float in [-22.35, -17.45]:
			L.box(root, "ward3_niche_wall", Vector3(-14.15, 7.95, z), Vector3(3.2, 3.9, 0.6), game.mats.dark)
		var shutter := L.box(root, "ward3_shutter", Vector3(-12.55, 7.9, -19.9), Vector3(0.5, 3.8, 4.8), game.mats.iron) as StaticBody3D
		game.ward3_shutter = shutter
		shutter.set_meta("interact_hint", "TITHE CHIME FRAME — YOUR MASTER’S MARK")
		var names: Array[String] = ["CRESCENT", "CROWN", "SKULL"]
		var pitches: Array[float] = [0.78, 1.0, 1.28]
		var metals: Array[Material] = [game.mats.mana, game.mats.brass, game.mats.portal]
		var bell_lights: Array[Color] = [CYAN_LIGHT, BRONZE_LIGHT, VIOLET_LIGHT]
		var bell_routes: Array[Node3D] = []
		var brass_wire: Material = game._material(Color("9e6941"), true)
		for i in names.size():
			var pos := Vector3(-10.2, 8.5 + 0.4 * i, -23 + 3 * i)
			var bell := L.cylinder(root, "harmonic_bell_" + names[i].to_lower(), pos, 0.48, 0.9, metals[i], true, 12, L.LAYER_TARGET)
			bell.set_meta("harmonic_bell", true)
			bell.set_meta("bell_idx", i)
			bell.set_meta("bell_name", names[i])
			bell.set_meta("bell_pitch", pitches[i])
			bell.set_meta("interact_hint", "BELL %d/3: %s — SHOOT [2/4] OR STRIKE" % [i + 1, names[i]])
			game.shootable_targets.append(bell)
			L.cylinder(root, "bell_suspension", pos + Vector3.UP * 1.28, 0.058, 1.8, game.mats.iron, false, 8)
			L.focus_light(root, pos + Vector3(2.0, 2.75, 1.0), pos, bell_lights[i], 2.7, 22.0)
			var tone: Material = game._material(bell_lights[i], true)
			var plaque := L.box(root, "chime_order_plaque", Vector3(pos.x, 6.85, pos.z), Vector3(0.19, 1.05, 1.75), game.mats.dark, false)
			var text := Label3D.new()
			text.text = "%d  %s" % [i + 1, names[i]]
			text.position = Vector3(0.104, 0.09, 0)
			text.rotation.y = PI * 0.5
			text.font_size = 42
			text.pixel_size = 0.006
			text.modulate = bell_lights[i]
			plaque.add_child(text)
			for pip in range(i + 1):
				var z := (float(pip) - float(i) * 0.5) * 0.24
				var rune := L.box(plaque, "chime_order_pip", Vector3(0.106, -0.25, z), Vector3(0.028, 0.13, 0.13), tone, false)
				rune.rotation.x = PI * 0.25
			var terminal_z := shutter.position.z + (i - 1) * 1.45
			var wire := L.add_floor_conduit(root, PackedVector3Array([
				Vector3(pos.x, 6, pos.z), Vector3(-11.45 - i * 0.22, 6, pos.z),
				Vector3(-11.45 - i * 0.22, 6, terminal_z), Vector3(-12.25, 6, terminal_z),
			]), brass_wire, tone, 0.14)
			L.box(shutter, "chime_wire_terminal", Vector3(0.28, -1.65, terminal_z - shutter.position.z), Vector3(0.1, 0.31, 0.19), tone, false)
			bell_routes.append(wire)
		root.set_meta("harmonic_conduits", bell_routes)
		L.watch_puzzle(shutter, func() -> void:
			for i in bell_routes.size():
				L.set_floor_conduit_powered(bell_routes[i], i < game.bell_sequence_step or st.wards.has("ward_3"))
		)
	game._inscription(Vector3(-7.7, 6, -16.3), "THE TITHE CHIMES", "As it was rung upon the quay: Moon (cyan). Crown (gold). Skull (violet). A false note wakes the Choir.")
	L.add_explosive_cask(game, Vector3(6.2, 6, -18.9), "tower_cask_choir")
	game._pot(Vector3(12.8, 6, -18.8), "tower_choir_urn_s", "mana")
	game._pot(Vector3(12.9, 6, -24.1), "tower_choir_urn_n", "flask")

static func _belfry(game, root: Node3D) -> void:
	L.staircase(root, "belfry_grand_stair", Vector3(0, 6, -22.5), Vector3(0, 9.5, -29.58), 5.8, game.mats.stone, game.mats.iron)
	L.archway(root, "belfry_arch", Vector3(0, 9.5, -30.8), 7.6, 6.2, 1.5, game.mats.stone, game.mats.brass)
	L.slab(root, "belfry_threshold", Rect2(-3.4, -31.6, 6.8, 2.01), 9.5, game.mats.stone)
	var seal := L.add_belfry_ward_seal(game, root, Vector3(0, 9.5, -30.8), 7.4, 5.6)
	root.set_meta("belfry_ward_seal", seal)
	L.hanging_chain_lamp(game, root, Vector3(0, 13.4, -30.8), 1.9, BRONZE_LIGHT, 3.7, 10.5)
	L.slab(root, "sanctum_south", Rect2(-14, -39, 28, 9.3), 9.5, game.mats.stone)
	L.slab(root, "sanctum_north", Rect2(-14, -56, 28, 11), 9.5, game.mats.stone)
	L.slab(root, "sanctum_west", Rect2(-14, -45, 11, 6), 9.5, game.mats.stone)
	L.slab(root, "sanctum_east", Rect2(3, -45, 11, 6), 9.5, game.mats.stone)
	for x: float in [-8.65, 8.65]:
		L.box(root, "belfry_entry_abutment", Vector3(x, 12.3, -30.1), Vector3(10.95, 5.6, 0.72), game.mats.dark)
	var center := Vector3(0, 9.5, -43.1)
	var segments := 12
	for i in segments:
		# The southern chord is the entrance from the guarded staircase.
		if i == 2:
			continue
		var a := TAU * float(i) / float(segments) + PI / 12.0
		var b := a + TAU / float(segments)
		var p1 := center + Vector3(cos(a), 0, sin(a)) * 12.9
		var p2 := center + Vector3(cos(b), 0, sin(b)) * 12.9
		var edge := p2 - p1
		var wall := L.box(root, "belfry_parapet", (p1 + p2) * 0.5 + Vector3.UP * 1.65, Vector3(edge.length() + 0.55, 3.3, 0.72), game.mats.dark)
		wall.rotation.y = atan2(-edge.z, edge.x)
		L.box(root, "pinnacle_plinth", p1 + Vector3.UP * 3.24, Vector3(1.38, 0.39, 1.38), game.mats.stone, false)
		if i % 3 == 1:
			var stump := L.cone(root, "broken_belfry_pinnacle", p1 + Vector3.UP * 3.83, 0.66, 0.43, 0.95, game.mats.stone)
			stump.rotation.z = -0.16
			L.hanging_chain(root, p1 + Vector3.UP * 3.9, p1.lerp(center, 0.075) + Vector3.UP * 0.65, 0.14, game.mats.iron)
		else:
			L.cone(root, "belfry_pinnacle", p1 + Vector3.UP * 4.6, 0.68, 0.12, 3.2, game.mats.stone)
			var outer_face := (p1 - center).normalized()
			L.hanging_chain(root, p1 + outer_face * 0.32 + Vector3.UP * 4.4, p1 + outer_face * 0.9 + Vector3.UP * 0.1, 0.14, game.mats.iron)
	for x: float in [-7, 7]:
		for z: float in [-36.3, -47.1]:
			L.cylinder(root, "belfry_cover_pillar", Vector3(x, 12.2, z), 0.96, 5.4, game.mats.stone, true, 12)
			L.cylinder(root, "belfry_pillar_cap", Vector3(x, 14.95, z), 1.22, 0.38, game.mats.brass, false, 12)
			game._torch(Vector3(x * 0.86, 11.6, z))
	game._rune_circle(BELFRY_SHAFT, 5.5)
	L.add_explosive_cask(game, Vector3(-6, 9.5, -34.8), "tower_cask_arena_w")
	L.add_explosive_cask(game, Vector3(6, 9.5, -34.8), "tower_cask_arena_e")
	L.add_explosive_cask(game, Vector3(0, 9.5, -49.5), "tower_cask_arena_n")
	game._pickup(Vector3(0, 10, -51.9), "flask", "tower_arena_flask")
	game._pickup(Vector3(-5.5, 10, -46.4), "mana", "tower_blue_2")
	game._pickup(Vector3(5.5, 10, -46.4), "green", "tower_green_2")
	game._pickup(Vector3(-7, 10, -49), "mana", "tower_arena_north_mana")
	game._pickup(Vector3(7, 10, -49), "green", "tower_arena_north_green")
	_belfry_shaft(game, root)
	var yoke := Node3D.new()
	yoke.name = "crown_yoke"
	yoke.position.z = BELFRY_SHAFT.z + 120.0
	root.add_child(yoke)
	L._landmark_bell(yoke, game.mats.iron, game.mats.brass)
	root.set_meta("crown_yoke", yoke)
	_shaft_tethers(game, root)
	L.add_checkpoint_zone(game, Vector3(0, 10.85, -32.0), Vector3(6.4, 2.7, 1.5), "tower_belfry", "Belfry Sanctum")

static func _vestibule(game, root: Node3D) -> void:
	L.slab(root, "south_keep_vestibule", Rect2(-4, 26.95, 8, 9.05), 0, game.mats.stone)
	L.box(root, "vestibule_vault", Vector3(0, 7.2, 31.5), Vector3(8.5, 0.45, 9), game.mats.dark)
	for x: float in [-4, 4]:
		L.box(root, "vestibule_wall", Vector3(x, 3.5, 31.5), Vector3(0.85, 7, 9), game.mats.dark)
	for z: float in [27, 35]:
		L.archway(root, "keep_door_arch", Vector3(0, 0, z), 6, 6.2, 1.0, game.mats.stone, game.mats.brass)
	var leaves: Array[AnimatableBody3D] = []
	for side: float in [-1, 1]:
		var leaf := AnimatableBody3D.new()
		leaf.name = "keep_door_l" if side < 0 else "keep_door_r"
		leaf.position = Vector3(side * 2.56, 0, 35)
		leaf.rotation.y = -side * deg_to_rad(55.0)
		leaf.collision_layer = L.LAYER_WORLD
		leaf.collision_mask = 0
		root.add_child(leaf)
		var center := Vector3(-side * 1.28, 2.45, 0)
		var size := Vector3(2.56, 4.9, 0.35)
		L.box(leaf, "keep_door_leaf", center, size, game.mats.timber, false)
		for y: float in [0.7, 2.0, 3.8, 4.72]:
			L.box(leaf, "door_iron_band", Vector3(center.x, y, 0), Vector3(2.56, 0.18, 0.43), game.mats.iron, false)
		var collar := L.cylinder(leaf, "door_pull_ring", Vector3(-side * 2.07, 1.25, -0.27), 0.16, 0.09, game.mats.brass, false, 12)
		collar.rotation.x = PI * 0.5
		var shape := BoxShape3D.new()
		shape.size = size
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.position = center
		leaf.add_child(collider)
		leaves.append(leaf)
	root.set_meta("vestibule_leaves", leaves)
	L.hanging_chain_lamp(game, root, Vector3(0, 4.6, 30.5), 1.85, BRONZE_LIGHT, 2.8, 7.5)

static func _nave_chandelier(game, root: Node3D) -> void:
	var chandelier := Node3D.new()
	chandelier.name = "nave_chandelier"
	chandelier.position = CHANDELIER_LAND + Vector3.UP * 9.0
	chandelier.set_meta("ring_radius", 2.2)
	root.add_child(chandelier)
	L._build_chandelier_visual(chandelier, 2.2)
	L.hanging_chain(chandelier, Vector3.UP * 6.55, Vector3.UP * 1.4, 0.14, game.mats.iron)
	root.set_meta("nave_chandelier", chandelier)

	var wreck := Node3D.new()
	wreck.name = "nave_chandelier_wreck"
	wreck.position = CHANDELIER_LAND + Vector3.UP * 0.22
	root.add_child(wreck)
	var ring := MeshInstance3D.new()
	var hoop := TorusMesh.new()
	hoop.outer_radius = 2.2
	hoop.inner_radius = 1.92
	ring.mesh = hoop
	ring.material_override = game.mats.iron
	ring.rotation = Vector3(0.085, 0, 0.06)
	wreck.add_child(ring)
	for i in 12:
		var angle := TAU * float(i) / 12.0
		var cup := L.cylinder(wreck, "bent_candle_cup", Vector3(cos(angle) * 2.05, 0, sin(angle) * 2.05), 0.11, 0.2, game.mats.brass, false, 8)
		cup.rotation = Vector3(0.8 * sin(angle), angle, 0.65 * cos(angle))
	L.hanging_chain(wreck, Vector3(-1.7, -0.12, 0.3), Vector3(1.4, -0.12, -0.7), 0.12, game.mats.iron)
	root.set_meta("nave_chandelier_wreck", wreck)

static func _moon_clock(game, root: Node3D, st: Dictionary) -> void:
	var dial := L.cylinder(root, "moon_clock", Vector3(-33.39, 6, 0.5), 2.5, 0.23, game.mats.brass, false, 32)
	dial.rotation.z = -PI * 0.5
	L.cylinder(dial, "blackened_clock_face", Vector3(0, 0.125, 0), 2.29, 0.12, game.mats.dark, false, 32)
	for i in 12:
		var angle := TAU * float(i) / 12.0
		var index := L.box(dial, "third_bell_index", Vector3(cos(angle) * 1.98, 0.21, sin(angle) * 1.98), Vector3(0.26, 0.05, 0.095), game.mats.brass, false)
		index.rotation.y = -angle
	for i in range(5):
		var phase := L.cylinder(dial, "moon_phase", Vector3(0.6, 0.212, (i - 2) * 0.43), 0.15, 0.038, game.mats.mana, false, 20)
		if i != 2:
			L.cylinder(phase, "moon_shadow", Vector3(0.073 * signf(i - 2), 0.026, 0), 0.12, 0.025, game.mats.dark, false, 16)
	var hand := Node3D.new()
	hand.name = "moon_clock_hand"
	hand.rotation.y = -0.22 if st.wards.has("ward_1") else 0.0
	dial.add_child(hand)
	L.box(hand, "minute_hand", Vector3(0, 0.26, 0.85), Vector3(0.075, 0.055, 1.7), game.mats.copper, false)
	L.box(dial, "hour_hand", Vector3(-0.5, 0.25, 0), Vector3(1, 0.055, 0.105), game.mats.brass, false)
	root.set_meta("moon_clock_hand", hand)
	game._inscription(Vector3(-32.8, 0, 3.4), "THE MOON-CLOCK", "The Keep’s escapement, by Master C., Guild of Wards. It keeps the bell’s hours. Its hands have stayed at the Third Bell.")

static func _pell_workbench(game, root: Node3D) -> void:
	var director_script: Script = load("res://scripts/story_director.gd")
	director_script.add_fallen_guard(root, Transform3D(Basis.from_euler(Vector3(0, 0.75, PI * 0.47)), Vector3(-23.58, 0.91, -7.62)), "artificer", game.mats)
	for i in 3:
		var angle := 0.38 + float(i) * 1.16
		var pos := Vector3(-22.5 + cos(angle) * 2.4, 0, -7.2 + sin(angle) * 2.4)
		director_script.add_fallen_guard(root, Transform3D(Basis(Vector3.UP, angle), pos), "acolyte_scorched", game.mats)
		Visuals.spawn_surface_splatter(root, pos, Vector3.UP, "scorch", 0.72, 3011 + i, true)
	for side: float in [-1, 1]:
		var shield := L.box(root, "split_executioner_shield", Vector3(-25.2 + side * 0.27, 0.12, -6.1), Vector3(0.46, 0.14, 0.9), game.mats.iron, false)
		shield.rotation.y = side * 0.3
	var slate := L.box(root, "pell_slate", Vector3(-22.5, 2.25, -9.42), Vector3(2.75, 1.7, 0.12), game.mats.dark, false)
	_label(slate, Vector3(0, 0, 0.07), "3,011 PINS\nNOT HARMONICS — NAMES?\nMASTER’S NOTCH IS WIDENING", Color("e5dacf"), 0.004)
	game._inscription(Vector3(-23.95, 0, -8.6), "PELL’S SLATE", "3,011 PINS. NOT HARMONICS — NAMES? Master’s notch is widening. 40 tolls left?")
	L.add_memory_echo(game, Vector3(-21, 0, -5.5), "pell_bench", "JOURNEYMAN PELL — ECHO", "PELL’S WORKBENCH", "Master’s notch is widening. The Warden says we ring the Lull until our arms fall off.")
	L.add_memory_echo(game, Vector3(-26.5, 0, 0.5), "pell_drum", "JOURNEYMAN PELL — ECHO", "THE PINNED DRUM", "The drum isn’t tuned to the Gate. It’s tuned to people. Every pin is someone.")
	game._inscription(Vector3(-32.25, 0, 5.3), "PELL’S SIGNET", "Inside the band: FOR MASTER C., WHO TAUGHT ME TO LISTEN.")

static func _foundry_tableaux(game, root: Node3D) -> void:
	# Keep the western mold clear of the stair and the approach from the Nave.
	var first := L.cone(root, "clay_bell_mold", Vector3(20.2, 1.8, 10.05), 2.05, 0.94, 3.6, game.mats.clay, 16)
	L.cylinder(first, "casting_flange", Vector3(0, -1.68, 0), 2.12, 0.24, game.mats.iron, false, 16)
	var sister := Node3D.new()
	sister.name = "sister_bell"
	sister.position = Vector3(27.5, 1.8, 6.5)
	root.add_child(sister)
	L.cone(sister, "sister_bell_body", Vector3.ZERO, 2.0, 0.89, 3.4, game.mats.brass, 20)
	L.cylinder(sister, "sister_bell_lip", Vector3(0, -1.62, 0), 2.16, 0.26, game.mats.brass, false, 20)
	var fissure := L.add_fissure(sister, Vector3(0.25, 0, -1.52), PI, Vector2(0.52, 3.2), BRONZE_LIGHT)
	fissure.rotation.x = -0.27
	L.cone(sister, "split_clay_mold_a", Vector3(1.85, -0.64, 0.2), 0.73, 0.47, 2.25, game.mats.clay, 7).rotation.z = 0.33
	L.cone(sister, "split_clay_mold_b", Vector3(-1.7, -1.0, -1.0), 0.86, 0.32, 1.55, game.mats.clay, 6).rotation.z = -0.4
	L.cylinder(sister, "sister_bell_footprint", Vector3(0, -1.02, 0), 1.6, 1.56, game.mats.iron, true, 14).get_child(0).hide()
	for i in 7:
		var x := 26.4 - float(i) * 0.63
		var z := 5.45 - float(i) * 0.53 + sin(i) * 0.36
		var spill := L.cylinder(root, "hardened_bronze_spill", Vector3(x, 0.017, z), 0.69 - float(i) * 0.046, 0.034, game.mats.copper, false, 9)
		spill.scale.z = 0.68

	var table := L.box(root, "founders_table", Vector3(18.6, 4.39, -3.4), Vector3(1.2, 0.15, 3.24), game.mats.timber)
	for x: float in [-0.47, 0.47]:
		for z: float in [-1.42, 1.42]:
			L.box(table, "oak_table_leg", Vector3(x, -0.47, z), Vector3(0.14, 0.88, 0.15), game.mats.timber, false)
	var memories := ["O. — A FIRST FORGE-FIRE", "M. — A WEDDING MORNING", "S. — A MOTHER’S FACE", "C. — HIS FIRST LOCK", "V. — A CORONATION"]
	for i in memories.size():
		var z := (float(i) - 2.0) * 0.59
		L.cone(table, "founders_ash_bowl", Vector3(-0.13, 0.16, z), 0.13, 0.23, 0.17, game.mats.brass, 12)
		L.cylinder(table, "founder_ash", Vector3(-0.13, 0.25, z), 0.19, 0.026, game.mats.dark, false, 12)
		var tag := _label(table, Vector3(0.31, 0.093, z), memories[i], Color("e8cdac"), 0.0012)
		tag.rotation = Vector3(-PI * 0.5, 0, -PI * 0.5)
	game._inscription(Vector3(19.35, 3.5, -4.45), "THE FOUNDERS' OFFERING", "Before the bronze was poured, each Founder gave one memory freely, that the Bell might know its makers. — Ledger of the Casting")
	game._inscription(Vector3(24, 0, 9.6), "THE GREAT BELL OF VAELOR", "Cast in the Year of the Grey Tide. Bronze of the Crown, quenched in the Founders’ ash. Let it remember for us.")

static func _vigil_altar(game, root: Node3D) -> void:
	var altar := L.box(root, "malcor_vigil_altar", Vector3(6.8, 6.48, -24.0), Vector3(1.55, 0.96, 0.75), game.mats.stone)
	L.box(altar, "vigil_altar_top", Vector3.UP * 0.5, Vector3(1.72, 0.14, 0.92), game.mats.brass, false)
	L.hanging_chain_lamp(game, root, Vector3(7.35, 9.4, -22.7), 2.5, BRONZE_LIGHT, 2.6, 7.0)
	var cot := L.box(root, "vigil_cot", Vector3(11, 6.42, -24.6), Vector3(1.2, 0.22, 2.9), game.mats.timber)
	L.box(cot, "captain_sash", Vector3(0.17, 0.16, 0.64), Vector3(0.57, 0.108, 0.73), game.mats.blood, false)
	for x: float in [-0.51, 0.51]:
		for z: float in [-1.26, 1.26]:
			L.box(cot, "cot_leg", Vector3(x, -0.24, z), Vector3(0.14, 0.43, 0.14), game.mats.iron, false)
	var pillar := L.box(root, "vigil_tally_pillar", Vector3(8.2, 7.6, -25), Vector3(0.68, 3.2, 0.68), game.mats.stone)
	L.box(root, "vigil_bread_ledge", Vector3(15.15, 6.9, -19.75), Vector3(0.54, 0.14, 13.5), game.mats.timber, false)
	for i in 40:
		var loaf_mat: Material = game.mats.clay if i > 25 else game.mats.timber if i > 11 else game.mats.dark
		var bread := L.cylinder(root, "uneaten_vigil_loaf", Vector3(15.14, 7.065, -26.1 + float(i) * 0.325), 0.14, 0.19, loaf_mat, false, 9)
		bread.scale.x = 1.48
		var notch := L.box(pillar, "vigil_tally_notch", Vector3((float(i % 5) - 2.0) * 0.091, 0.37 - floorf(float(i) / 5.0) * 0.127, 0.345), Vector3(0.016, 0.042 if i == 39 else 0.082, 0.014), game.mats.dark, false)
		notch.rotation.z = -0.18 if i % 5 < 4 else 1.12
	_name_spiral(root)
	L.add_rotten_barricade(game, Vector3(-14.1, 7.2, -26.6), "tower_secret_bar_2", Vector3(2.4, 2.4, 0.42), true)
	L.box(root, "vigil_secret_side", Vector3(-12.65, 7.5, -27.05), Vector3(0.5, 3, 1.6), game.mats.dark)
	L.box(root, "vigil_secret_head", Vector3(-14.1, 8.65, -26.6), Vector3(2.5, 0.5, 0.6), game.mats.dark)
	# Place the wisp behind masonry and let the opening gate its proximity signal.
	var echo_script: Script = load("res://scripts/story_director.gd")
	var echo: Area3D = echo_script.add_echo_wisp(game, Transform3D(Basis(), Vector3(-14.05, 6, -27.15)), "seraphina_loft", {
		"speaker": "ARCHIVIST SERAPHINA — ECHO", "title": "THE WARDEN’S RECEIPT",
		"line": "Warden. The Roll is complete. Three thousand and eleven. The King thanks you.",
		"radius": 1.15,
	})
	L.watch_puzzle(echo, func() -> void:
		var revealed: bool = L.chapter_state(game).get("broken", []).has("tower_secret_bar_2")
		echo.get_parent().visible = revealed
		if echo.monitoring != revealed:
			echo.set_deferred("monitoring", revealed)
	)

static func _label(parent: Node3D, pos: Vector3, value: String, color: Color, pixel_size: float) -> Label3D:
	var label := Label3D.new()
	label.text = value
	label.position = pos
	label.font_size = 36
	label.pixel_size = pixel_size
	label.modulate = color
	label.outline_size = 0
	parent.add_child(label)
	return label

static func _name_spiral(root: Node3D) -> void:
	var names := ["MARA HESK", "TOMAS HESK", "ANNA HESK", "EFA MERE", "ROWAN SEDGE", "ADA VENN", "OSRIC BELL", "NELL ROOK"]
	var center := Vector3(6.5, 6.022, -21.35)
	for i in 148:
		var t := float(i) / 147.0
		var angle := t * TAU * 8.2
		var radius := lerpf(0.24, 2.52, t)
		var pos := center + Vector3(cos(angle), 0, sin(angle)) * radius
		var line := _label(root, pos, names[i % names.size()], Color(0.77, 0.72, 0.62, 0.64), lerpf(0.00048, 0.00102, t))
		line.rotation = Vector3(-PI * 0.5, 0, PI * 0.5 - angle)
	var signature := _label(root, center + Vector3.UP * 0.003, "MALCOR\nMALC\nMALK—", Color("d3bba0"), 0.00125)
	signature.rotation.x = -PI * 0.5

static func _belfry_shaft(game, root: Node3D) -> void:
	# The arena slabs surround a six-metre square opening. The return stair runs
	# along its west wall, outside the central drop sensor.
	var floorboards := L.slab(root, "belfry_floorboards", Rect2(-3.02, -45.02, 6.04, 6.04), 9.5, game.mats.timber, 0.36)
	game.belfry_floorboards = floorboards
	for i in 8:
		var x := -2.67 + float(i) * 0.76
		L.box(floorboards, "floorboard_seam", Vector3(x, 0.183, 0), Vector3(0.032, 0.011, 6), game.mats.iron, false)
	L.slab(root, "drop_shaft_landing", Rect2(-3.08, -45.08, 6.16, 6.16), 7, game.mats.stone)
	for x: float in [-3.17, 3.17]:
		L.box(root, "shaft_sidewall", Vector3(x, 8.125, -42), Vector3(0.33, 2.55, 6.65), game.mats.stone)
	for z: float in [-45.17, -38.83]:
		L.box(root, "shaft_endwall", Vector3(0, 8.125, z), Vector3(6.65, 2.55, 0.33), game.mats.stone)
	# Return stair along the shaft's west wall, hidden under intact floorboards so rails never poke through.
	var steps := L.staircase(root, "shaft_return_steps", Vector3(-2.12, 7, -43.4), Vector3(-2.12, 9.5, -38.52), 1.66, game.mats.stone, game.mats.iron)
	for _r in 2:
		var rail := steps.get_child(steps.get_child_count() - 1)
		steps.remove_child(rail)
		rail.queue_free()
	root.set_meta("shaft_return_steps", steps)
	var light: OmniLight3D = game._light(Vector3(0.5, 7.65, -42), Color("f0915a"), 2.6, 6.8)
	root.set_meta("shaft_light", light)

static func _shaft_tethers(game, root: Node3D) -> void:
	var tethers := Node3D.new()
	tethers.name = "great_bell_tethers"
	root.add_child(tethers)
	for x: float in [-1.45, 0, 1.45]:
		L.hanging_chain(tethers, Vector3(x, 19.82, -42), Vector3(x * 0.38, 12.45, -42), 0.13, game.mats.iron)
	tethers.hide()
	root.set_meta("great_bell_tethers", tethers)

static func sync_visual_state(game, st: Dictionary) -> void:
	var root: Node3D = game.level_root
	var world: Dictionary = st.get("story_world", {})
	var fallen := bool(world.get("nave_chandelier_fallen", false))
	L.set_assembly_active(root.get_meta("nave_chandelier"), not fallen, false)
	L.set_assembly_active(root.get_meta("nave_chandelier_wreck"), fallen, false)
	var shaft_open := bool(st.get("boss_dead", false)) and bool(world.get("belfry_shaft_open", false))
	L.set_assembly_active(game.belfry_floorboards, not shaft_open, false)
	if root.has_meta("shaft_return_steps"):
		L.set_assembly_active(root.get_meta("shaft_return_steps"), shaft_open, false)
	var yoke: Node3D = root.get_meta("crown_yoke")
	var bell: Node3D = yoke.get_meta("bell")
	bell.visible = not shaft_open
	var chain := yoke.get_node("hanging_iron_chain") as Node3D
	chain.visible = not shaft_open
	var shaft_light: OmniLight3D = root.get_meta("shaft_light")
	shaft_light.visible = shaft_open
	var leaves: Array = root.get_meta("vestibule_leaves")
	for leaf: AnimatableBody3D in leaves:
		var side := signf(leaf.position.x)
		leaf.rotation.y = -side * deg_to_rad(4.0 if st.get("vestibule_shut", false) else 55.0)

static func _marker(root: Node3D, id: String, pos: Vector3, yaw: float = 0.0) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = id
	marker.position = pos
	marker.rotation.y = yaw
	root.add_child(marker)
	return marker

static func _register_routes(root: Node3D, st: Dictionary, director: Node) -> void:
	director.register_arrival("tower_from_court", _marker(root, "tower_from_court", Vector3(0, 0.1, 33)))
	director.register_arrival("tower_from_kiln", _marker(root, "tower_from_kiln", Vector3(-2.15, 7.08, -44.2), PI))

	var court := L.add_transition_zone(root, Transform3D(Basis(), Vector3(0, 1.25, 35.0)), Vector3(4.9, 2.5, 2.2), "tower_to_court")
	var court_plane: Marker3D = court.get_meta("aperture")
	court_plane.position = Vector3(0, -1.25, 0.45)
	director.register_transition(court, court_plane, {
		"id": "tower_to_court", "destination": "ch1_court", "arrival_id": "court_from_tower",
		"safe_return_id": "tower_from_court", "label": "RETURN TO THE SUNKEN COURT",
		"kind": "arch", "direction_local": Vector3.BACK, "is_open": func() -> bool: return true,
	})

	var shaft := L.add_transition_zone(root, Transform3D(Basis(), Vector3(0, 8.3, -42)), Vector3(2.75, 2.6, 4.0), "tower_to_kiln")
	director.register_transition(shaft, shaft.get_meta("aperture"), {
		"id": "tower_to_kiln", "destination": "ch3_kiln", "arrival_id": "kiln_from_tower",
		"safe_return_id": "tower_from_kiln", "label": "DESCEND THE BELFRY SHAFT",
		"kind": "drop", "direction_local": Vector3.DOWN,
		"is_open": func() -> bool: return bool(st.get("boss_dead", false)) and bool(st.story_world.belfry_shaft_open),
	})

static func _register_story(game, root: Node3D, st: Dictionary, director: Node) -> void:
	_register_routes(root, st, director)
	for tube: Array in [
		["tube_nave", Vector3(8.6, 2.2, 23.5), -PI * 0.5],
		["tube_west", Vector3(-17, 2, -3), -PI * 0.5],
		["tube_east", Vector3(17, 2, 9), PI * 0.5],
		["tube_lift", Vector3(-4.6, 2, -3.6), PI * 0.5],
		["tube_loft", Vector3(-8.2, 8, -11), 0.0],
	]:
		var horn := L.add_speaking_tube(root, tube[0], tube[1], tube[2], game.mats.brass, game.mats.iron)
		director.register_tube(tube[0], horn)

	var world: Dictionary = st.story_world
	var live: Node3D
	director.register_mark("malcor_hidden", MALCOR_HIDDEN)
	director.register_mark("malcor_rail", MALCOR_RAIL, PI)
	director.register_mark("malcor_vigil", MALCOR_VIGIL, -PI * 0.5)
	director.register_mark("malcor_stair", Vector3(0, 6, -22.5))
	director.register_mark("malcor_stair_top", Vector3(0, 9.5, -29.58))
	director.register_mark("malcor_beyond_seal", Vector3(0, 9.5, -32.15))
	director.register_mark("chandelier_land", CHANDELIER_LAND)
	director.register_mark("belfry_center", BELFRY_SHAFT)
	director.register_mark("belfry_seal_center", SEAL_CENTER)
	if not world.malcor_departed:
		live = _malcor_actor(game, root, director, "malcor_live", MALCOR_VIGIL if st.malcor_balcony_done else MALCOR_HIDDEN)
		if st.malcor_balcony_done:
			live.rotation.y = -PI * 0.5
			live.get_child(0).set_meta("gesture", "kneel")
	director.register_target("belfry_seal", root.get_meta("belfry_ward_seal"))
	director.register_target("nave_chandelier", root.get_meta("nave_chandelier"))
	director.register_target("nave_chandelier_wreck", root.get_meta("nave_chandelier_wreck"))
	director.register_target("belfry_floorboards", game.belfry_floorboards)
	director.register_target("great_bell", root.get_meta("crown_yoke").get_meta("bell"))
	director.register_target("shaft_emitter", _marker(root, "shaft_emitter", Vector3(0, 2, -42)))
	director.register_target("belfry_voice", _marker(root, "belfry_voice", Vector3(0, 11.2, -38.6)))
	for ward: Node3D in game.wards:
		ward.set_meta("interact_hint", "WARDING CRYSTAL — STRIKE TO SHATTER")
		director.register_target(str(ward.get_meta("id")), ward)
	if st.malcor_balcony_done:
		_restore_ward_chains(root, director, st)
	if st.nave_woken:
		_spawn_nave(game)
	if st.lift_ambush_done:
		_spawn_lift_ambush(game, "all")
	if world.malcor_departed:
		_spawn_choir(game)
	if not st.boss_dead and (int(st.boss_hp) < 520 or director.is_sequence_completed(PREFIX + "belfry_awakens")):
		_spawn_warden(game)
	if not st.boss_dead and int(st.boss_hp) <= 260:
		_set_storm_rain(game, root, true)

	_register_arrival_and_balcony(game, root, st, director)
	_register_ward_and_lift(game, root, st, director)
	_register_choir_and_belfry(game, root, st, director, live)
	_watch_story(game, root, st, director)

static func _malcor_actor(game, root: Node3D, director: Node, id: String, pos: Vector3) -> Node3D:
	var holder := Node3D.new()
	holder.name = id
	holder.position = pos
	root.add_child(holder)
	var rig := Meshes.build_npc_rig(id, game.mats)
	holder.add_child(rig)
	director.register_actor(id, holder, rig)
	return holder

static func _beat(id: String, at: float, op: String, target: String = "", args: Dictionary = {}) -> Dictionary:
	return {"id": id, "at": at, "op": op, "target": target, "args": args}

static func _action(id: String, at: float, action: String, payload: Variant = null) -> Dictionary:
	var args := {"action": action}
	if payload != null:
		args.payload = payload
	return _beat(id, at, "commit", "", args)

static func _voice(id: String, at: float, speaker: String, line: String, duration: float, target: String = "") -> Dictionary:
	var args := {"id": id, "speaker": speaker, "line": line, "duration": duration}
	if speaker == "seraphina":
		args.channel = "tube"
		args.label = "SERAPHINA"
	return _beat(id, at, "voice", target, args)

static func _seq(director: Node, id: String, beats: Array, when: Callable = Callable(), reconcile: Callable = Callable()) -> void:
	director.register_sequence({"id": PREFIX + id, "once": true, "beats": beats, "when": when, "reconcile": reconcile})

static func _volume(root: Node3D, director: Node, id: String, center: Vector3, size: Vector3, sequence: String = "") -> void:
	var area := L.add_transition_zone(root, Transform3D(Basis(), center), size, id)
	area.name = "story_" + id
	director.register_story_volume(area, id, PREFIX + (id if sequence.is_empty() else sequence))

static func _restore_ward_chains(root: Node3D, director: Node, st: Dictionary) -> void:
	for id: String in WARD_ANCHORS:
		if st.wards.has(id):
			continue
		var chain := Node3D.new()
		chain.name = "ward_chain_" + id
		chain.position = WARD_ANCHORS[id]
		root.add_child(chain)
		var color := Color(WARD_COLORS[id])
		chain.set_meta("color", color)
		director.register_ward_chain(id, chain)
		director._build_chain_links(chain, chain.global_position, SEAL_CENTER, color)

static func _register_arrival_and_balcony(game, root: Node3D, st: Dictionary, director: Node) -> void:
	var world: Dictionary = st.story_world
	director.register_commit("shut_vestibule", func() -> void: st.vestibule_shut = true)
	director.register_commit("chandelier_ignites", func() -> void:
		if game.has_method("_spawn_fire_patch"):
			for x: float in [-2.35, 2.35]:
				game._spawn_fire_patch(CHANDELIER_LAND + Vector3(x, 0.1, 0.65))
				if not game.active_fire_patches.is_empty():
					game.active_fire_patches.back()["time_left"] = 12.0
	)
	director.register_commit("anchor_ward_chains", func() -> void:
		for id: String in WARD_ANCHORS:
			var chain := root.get_node_or_null("ward_chain_" + id) as Node3D
			if is_instance_valid(chain):
				if st.wards.has(id):
					director.snap_ward_chain(id)
				else:
					chain.set_meta("anchor", WARD_ANCHORS[id])
	)
	director.register_commit("finish_balcony", func() -> void:
		st.malcor_balcony_done = true
		world.malcor_mark = "malcor_vigil"
	)
	director.register_commit("wake_nave", func() -> void:
		if not st.nave_woken:
			st.nave_woken = true
			_spawn_nave(game)
	)
	_seq(director, "arrival", [
		_beat("rain_behind_doors", 0, "foley", "", {"pos": Vector3(0, 2, 35.5), "sound": "wind_gust", "vol_db": -13.0}),
	])
	_seq(director, "vestibule_doors", [
		_beat("door_slam", 0, "foley", "", {"pos": Vector3(0, 2, 35), "sound": "door_slam"}),
		_action("doors_shut", 0, "shut_vestibule"),
	], func() -> bool: return not st.vestibule_shut)
	_volume(root, director, "vestibule_doors", Vector3(0, 1.5, 28.5), Vector3(8, 3, 1))

	var beats := [
		_beat("step_to_rail", 0, "walk_to", "malcor_live", {"route": [Vector3(-6.5, 6, -13.5), "malcor_rail"], "speed": 1.75}),
		_beat("find_malcor", 1.8, "await_look", "malcor_live", {"cone_deg": 40.0, "timeout": 3.0, "timeout_cue": "bell"}),
		_beat("clerestory_thunder", 1.81, "foley", "malcor_live", {"sound": "thunder_far"}),
		_beat("face_caelen", 1.81, "look_at", "malcor_live", {"at": "$player"}),
		_voice("c2.mal.01", 2.0, "malcor", "Lock-smith.", 2.0, "malcor_live"),
		_voice("c2.mal.02", 4.0, "malcor", "I knew your step on the causeway. Guild boots. Ward-iron. Guilt.", 4.6, "malcor_live"),
		_voice("c2.mal.03", 8.6, "malcor", "Forty nights I rang the Lull for them. Tonight your little mercy cracked my bell.", 5.2, "malcor_live"),
		_beat("peal", 13.8, "gesture", "malcor_live", {"name": "toll_handbell", "duration": 1.1}),
		_beat("handbell", 13.8, "foley", "malcor_live", {"sound": "bell", "pitch": 0.8}),
		_beat("nave_resonance", 13.8, "resonance", "malcor_live", {"radius": 32.0, "speed": 22.0, "strength": 0.10, "mode": "inverted"}),
		_beat("chain_slip", 14.15, "foley", "nave_chandelier", {"sound": "chain_strain"}),
		_beat("find_chandelier", 14.2, "await_look", "nave_chandelier", {"cone_deg": 44.0, "timeout": 2.2, "timeout_cue": "chain_snap"}),
		_beat("release", 14.45, "chandelier_drop", "nave_chandelier", {
			"wreck": "nave_chandelier_wreck", "impact_mark": "chandelier_land", "timeout": 1.8,
			"state_key": "nave_chandelier_fallen", "commit": "chandelier_ignites",
		}),
	]
	var ward_lines := [
		["c2.mal.04", "Hear me bind it. One for the moon that saw it.", 3.6],
		["c2.mal.05", "One for the crown that willed it.", 2.8],
		["c2.mal.06", "One for the skull that paid it.", 2.8],
	]
	var t := 16.1
	var i := 0
	for id: String in WARD_ANCHORS:
		beats.append(_beat(id + "_whip", t, "ward_chain", "malcor_live", {
			"ward": id, "from": MALCOR_RAIL + Vector3.UP * 1.65, "to": id, "color": WARD_COLORS[id],
		}))
		beats.append(_voice(ward_lines[i][0], t, "malcor", ward_lines[i][1], ward_lines[i][2], "malcor_live"))
		t += ward_lines[i][2]
		i += 1
	beats.append_array([
		_action("relink_anchors", t, "anchor_ward_chains"),
		_beat("relink_seal", t, "ward_chain", "", {"ward": "*", "action": "reanchor", "to": "belfry_seal_center"}),
		_beat("seal_ignites", t, "seal_ripple", "belfry_seal"),
		_voice("c2.mal.07", t, "malcor", "Break them, and you break me. Then the bell is yours again. As it always was.", 5.2, "malcor_live"),
		_beat("return_to_loft", t + 5.2, "walk_to", "malcor_live", {
			"route": [Vector3(-6.5, 6, -14.5), Vector3(0, 6, -17.2), Vector3(4.9, 6, -20.6), "malcor_vigil"],
			"speed": 2.5, "state_key": "malcor_mark",
		}),
		_beat("kneel_at_vigil", t + 13.0, "gesture", "malcor_live", {"name": "kneel", "duration": 10000.0, "hold": true}),
		_action("balcony_done", t + 13.05, "finish_balcony"),
		_beat("start_nave_wake", t + 14.55, "chain", "", {"sequence": PREFIX + "nave_wake"}),
	])
	for beat: Dictionary in beats:
		# A settled revisit registers the same IDs with the departed actor omitted.
		if beat.target == "malcor_live":
			beat.optional = true
	_seq(director, "malcor_balcony", beats, func() -> bool: return not st.malcor_balcony_done, func() -> void:
		st.malcor_balcony_done = true
		st.nave_woken = true
		world.malcor_mark = "malcor_vigil"
		world.nave_chandelier_fallen = true
	)
	_volume(root, director, "malcor_balcony", Vector3(0, 1.5, 18), Vector3(14, 3, 2.5))
	_seq(director, "nave_wake", [
		_action("spawn_nave", 0, "wake_nave"),
		_beat("wake_bark", 0.15, "bark", "", {"speaker_id": "hollow_choir", "line": "—the bell, the bell—", "origin": Vector3(-13.6, 1.4, 9)}),
	], func() -> bool: return not st.nave_woken)
	_seq(director, "tube_intro", [
		_voice("c2.ser.01", 0, "seraphina", "Caelen, can you hear me? The Watch tubes still carry. I’m on the archive stair.", 5.0),
		_voice("c2.ser.02", 5, "seraphina", "He’s bound the bell to himself. Those chains are his name, split three ways.", 4.4),
		_voice("c2.ser.03", 9.4, "seraphina", "West is the Moon-Clock. East, the old foundry. The Choir he keeps for himself.", 4.4),
	])
	_seq(director, "tube_west", [
		_voice("c2.ser.04", 0, "seraphina", "Pell’s workshop. He was your journeyman, wasn’t he?", 3.9),
		_voice("c2.ser.05", 3.9, "seraphina", "He wrote to me near the end. I didn’t answer.", 3.4),
	])
	_seq(director, "tube_east", [
		_voice("c2.ser.06", 0, "seraphina", "The foundry. They cast the Great Bell here.", 3.4),
		_voice("c2.ser.07", 3.4, "seraphina", "Don’t look at the table on the balcony. ...Please.", 3.9),
	])
	_volume(root, director, "tube_west", Vector3(-16, 1.5, 2.4), Vector3(3, 3, 7))
	_volume(root, director, "tube_east", Vector3(16, 1.5, 5), Vector3(3, 3, 7))

static func _spawn_nave(game) -> void:
	game._enemy(Vector3(-13.6, 0, 9), false, "tower_nave_1", false, "shrieker")
	game._enemy(Vector3(13.6, 0, 4), false, "tower_nave_2", false, "shrieker")

static func _register_ward_and_lift(game, root: Node3D, st: Dictionary, director: Node) -> void:
	director.register_target("moon_clock_hand", root.get_meta("moon_clock_hand"))
	director.register_commit("advance_moon_clock", func() -> void:
		var hand: Node3D = root.get_meta("moon_clock_hand")
		hand.create_tween().tween_property(hand, "rotation:y", -0.22, 0.28)
	)
	var losses := {
		"ward_1": ["c2.mal.10", "...the moon over the quay. I remember the— no. It’s gone.", 4.0],
		"ward_2": ["c2.mal.11", "Crown that willed it... whose crown? I knelt to someone. I knelt...", 4.6],
		"ward_3": ["c2.mal.12", "Skull that paid it. I don’t remember paying. I remember only the count.", 4.4],
	}
	for id: String in losses:
		var line: Array = losses[id]
		var beats := [
			_beat("snap_chain", 0, "ward_chain", "", {"ward": id, "action": "snap"}),
			_voice(line[0], 0.1, "malcor", line[1], line[2], "belfry_voice"),
		]
		if id == "ward_1":
			beats.append(_action("clock_tick", 0, "advance_moon_clock"))
		elif id == "ward_3":
			beats.append(_beat("seal_shatters", 0, "seal_ripple", "belfry_seal"))
			beats.append(_voice("c2.mal.13", 4.5, "malcor", "It’s done, then. Come up, Lock-smith. Bring your hands.", 3.6, "belfry_voice"))
		_seq(director, id + "_broken", beats, func() -> bool: return st.wards.has(id))

	director.register_commit("jam_lift", func() -> void:
		st.lift_ambush_done = true
		game.narrative.show_style_banner("LIFT JAMMED — SHOOT THE GLOWING PAWL", CYAN_LIGHT)
	)
	director.register_commit("spawn_lift_ambush", func(group: String) -> void: _spawn_lift_ambush(game, group))
	_seq(director, "lift_ambush", [
		_beat("gear_grind", 0, "foley", "", {"pos": Vector3(0, 3.1, -6.57), "sound": "gear_grind"}),
		_beat("jam_lurch", 0, "shake", "", {"pos": Vector3(0, 3.1, -6.57), "amount": 0.06}),
		_action("pawl_hint", 0.3, "jam_lift"),
		_action("ambush_rail", 0.6, "spawn_lift_ambush", "rail"),
		_beat("rail_bark", 0.66, "bark", "", {"speaker_id": "hollow_choir", "line": "—none rise—", "origin": Vector3(-5, 7.4, -11)}),
		_action("ambush_drop", 1.4, "spawn_lift_ambush", "drop"),
		_voice("c2.ser.08", 2.0, "seraphina", "That pawl is a Guild escapement— yours. Shoot it loose!", 4.1, "tube_lift"),
		_action("ambush_stairs", 2.5, "spawn_lift_ambush", "stairs"),
	], Callable(), func() -> void: st.lift_ambush_done = true)

static func _spawn_lift_ambush(game, group: String) -> void:
	if group == "all" or group == "rail":
		game._enemy(Vector3(-5, 6, -11), false, "tower_liftamb_aco_a", false, "acolyte")
		game._enemy(Vector3(5, 6, -11), false, "tower_liftamb_aco_b", false, "acolyte")
	if group == "all" or group == "drop":
		game._enemy(Vector3(-2, 7.5, -8.5), false, "tower_liftamb_shr_a", false, "shrieker")
		game._enemy(Vector3(2, 7.5, -5), false, "tower_liftamb_shr_b", false, "shrieker")
	if group == "all" or group == "stairs":
		game._enemy(Vector3(-11.05, 3.75, -3.0), false, "tower_liftamb_aco_c", false, "acolyte")
		game._enemy(Vector3(11.05, 3.75, -3.0), false, "tower_liftamb_aco_d", false, "acolyte")

static func _spawn_choir(game) -> void:
	game._enemy(Vector3(-1.5, 6, -26.75), true, "tower_choir_exec", false, "executioner")
	game._enemy(Vector3(2.0, 6, -27.05), false, "tower_choir_stalker", false, "stalker")

static func _spawn_warden(game) -> void:
	if not is_instance_valid(game.boss):
		game._enemy(Vector3(0, 9.5, -44.2), true, "warden", true, "warden")

static func _register_choir_and_belfry(game, root: Node3D, st: Dictionary, director: Node, live: Node3D) -> void:
	var world: Dictionary = st.story_world
	director.register_commit("finish_choir_departure", func() -> void:
		st.choir_confronted = true
		world.malcor_departed = true
		_spawn_choir(game)
	)
	_seq(director, "choir_departure", [
		_beat("address", 0, "gesture", "malcor_live", {"name": "rise", "duration": 1.2}),
		_beat("turn", 0.3, "look_at", "malcor_live", {"at": "$player"}),
		_voice("c2.mal.30", 0.3, "malcor", "Closer. My eyes are going. The rest of me is following.", 3.5, "malcor_live"),
		_voice("c2.mal.31", 3.8, "malcor", "Forty nights, Lock-smith. Every night, every name. Three thousand and eleven. Here.", 5.0, "malcor_live"),
		_voice("c2.mal.32", 8.8, "malcor", "Tonight I lost the hundredth. A fisher’s boy. I knew him. I knew him.", 4.4, "malcor_live"),
		_voice("c2.mal.33", 13.2, "malcor", "You came to fix the bell. You can’t. You built it to take, and it remembers how.", 5.0, "malcor_live"),
		_voice("c2.mal.34", 19.4, "malcor", "The Archivist sent for you. Ask why she needs a lock-smith... and not a bell-wright.", 5.1, "malcor_live"),
		_voice("c2.mal.35", 24.5, "malcor", "Ring the skull as they rang it on the quay. Come up. We’ll finish what we started.", 5.0, "malcor_live"),
		_beat("retreat", 29.5, "walk_to", "malcor_live", {
			"route": ["malcor_stair", "malcor_stair_top", "malcor_beyond_seal"], "speed": 2.1, "state_key": "malcor_mark",
		}),
		_beat("through_seal", 36.4, "seal_ripple", "belfry_seal"),
		_beat("dissolve", 37.5, "vanish", "malcor_live", {"state_key": "malcor_departed", "sound": ""}),
		_voice("c2.mal.36", 38.0, "malcor", "Let them test you.", 2.4, "belfry_voice"),
		_action("spawn_testers", 39.0, "finish_choir_departure"),
	].map(func(beat: Dictionary) -> Dictionary:
		beat.optional = beat.target == "malcor_live"
		return beat
	), func() -> bool: return is_instance_valid(live) and st.malcor_balcony_done and not world.malcor_departed, func() -> void:
		st.choir_confronted = true
		world.malcor_departed = true
	)

	director.register_commit("awaken_warden", func() -> void:
		_spawn_warden(game)
		game.triggered_volumes["belfry_sanctum"] = true
		game.narrative.show_style_banner("LORD MALCOR — BELL WARDEN", VIOLET_LIGHT)
	)
	_seq(director, "belfry_awakens", [
		_action("awaken", 0, "awaken_warden"),
		_voice("c2.mal.14", 0.15, "malcor", "Here. Under it. Where I stood on the third bell.", 3.8, "$boss"),
		_beat("distant_thunder", 0.3, "foley", "great_bell", {"sound": "thunder_far"}),
		_voice("c2.mal.15", 4.0, "malcor", "The Kiln is under my feet, Lock-smith. Take it from me.", 4.0, "$boss"),
	], func() -> bool: return st.wards.size() >= WARD_ANCHORS.size() and world.malcor_departed and not st.boss_dead)
	_volume(root, director, "belfry_sanctum", Vector3(0, 10.9, -33.2), Vector3(7, 3.8, 3.2), "belfry_awakens")

	director.register_commit("storm_phase_two", func() -> void: _set_storm_rain(game, root, true))
	director.register_commit("reflect_tolls", func() -> void:
		game.narrative.show_style_banner("PHASE II — REFLECT HIS TOLLS", VIOLET_LIGHT)
	)
	_seq(director, "warden_phase_two", [
		_action("storm_breaks", 0, "storm_phase_two"),
		_beat("phase_toll", 0, "foley", "great_bell", {"sound": "thunder_far", "max_dist": 65.0}),
		_action("orb_callout", 0.2, "reflect_tolls"),
		_voice("c2.mal.16", 0.2, "malcor", "Then let the storm count with me!", 3.6, "$boss"),
	], func() -> bool: return not st.boss_dead and int(st.boss_hp) <= 260)

	director.register_commit("begin_confession", func() -> void:
		_set_storm_rain(game, root, false)
		var last: Vector3 = root.get_meta("warden_death_position", root.get_meta("warden_last_position", BELFRY_SHAFT))
		last.y = BELFRY_SHAFT.y
		_malcor_actor(game, root, director, "malcor_dying", last)
	)
	director.register_commit("release_great_bell", func() -> void:
		var yoke: Node3D = root.get_meta("crown_yoke")
		yoke.get_node("hanging_iron_chain").hide()
	)
	director.register_commit("open_shaft", func() -> void:
		st.malcor_confessed = true
		st.bell_fallen = true
		world.belfry_shaft_open = true
		L.trigger_rockfall(root, game.belfry_floorboards, null, 3011, 24)
		var light: OmniLight3D = root.get_meta("shaft_light")
		light.show()
		director.start_sequence(PREFIX + "shaft_aftermath")
		game._objective()
		game._message("OBJECTIVE: DESCEND THE BELFRY SHAFT", 4.5)
	)
	_seq(director, "belfry_shaft", [
		_action("dying_breath", 0, "begin_confession"),
		_beat("kneel", 0.05, "gesture", "malcor_dying", {"name": "kneel", "duration": 8.0}),
		_beat("crawl", 0.2, "walk_to", "malcor_dying", {"mark": "belfry_center", "speed": "crawl", "animation": "crawl"}),
		_voice("c2.mal.17", 0.2, "malcor", "Wait. Wait. Let me— while I still have it.", 3.2, "malcor_dying"),
		_voice("c2.mal.18", 3.4, "malcor", "I found your notch. The night before the Tithe. A hairline in the governor tooth.", 5.0, "malcor_dying"),
		_voice("c2.mal.19", 8.4, "malcor", "I could have filed it true. I left it.", 3.0, "malcor_dying"),
		_voice("c2.mal.20", 11.4, "malcor", "I thought: let it fail on the first toll. Let me be the man who rang... and nothing came.", 5.6, "malcor_dying"),
		_voice("c2.mal.21", 17.0, "malcor", "It held for three thousand and eleven. Then it waited forty nights. For tonight.", 5.2, "malcor_dying"),
		_voice("c2.mal.22", 22.2, "malcor", "Ask the Archivist whose hand wrote the Roll.", 3.6, "malcor_dying"),
		_voice("c2.mal.23", 25.8, "malcor", "Caelen. My name is... my name was...", 4.0, "malcor_dying"),
		_beat("joist_crack", 31.3, "foley", "belfry_floorboards", {"sound": "timber_groan"}),
		_beat("floorboard_dust", 31.3, "dust", "belfry_floorboards", {"kind": "stone", "dir": Vector3.UP}),
		_beat("find_bell", 31.35, "await_look", "great_bell", {"cone_deg": 45.0, "timeout": 1.6, "timeout_cue": "chain_strain"}),
		_beat("tethers_break", 31.75, "foley", "great_bell", {"sound": "chain_snap"}),
		_action("release_bell", 31.75, "release_great_bell"),
		_beat("bell_drop", 31.75, "bell_drop", "great_bell", {
			"floor": "belfry_floorboards", "impact_mark": "belfry_center",
			"impact_beat": "open_shaft", "commit": "open_shaft", "radius": 2.2, "timeout": 2.4, "sink_depth": 46.0,
		}),
	].map(func(beat: Dictionary) -> Dictionary:
		beat.optional = beat.target == "malcor_dying"
		return beat
	), func() -> bool: return st.boss_dead and not world.belfry_shaft_open, func() -> void:
		st.malcor_confessed = true
		st.bell_fallen = true
		world.belfry_shaft_open = true
	)
	_seq(director, "shaft_aftermath", [
		{"id": "warden_falls", "at": 0, "op": "vanish", "target": "malcor_dying", "args": {"sound": ""}, "optional": true},
		_beat("kiln_answer", 1.65, "foley", "shaft_emitter", {"sound": "impact_deep", "max_dist": 45.0}),
		_voice("c2.cho.04", 2.1, "hollow_choir", "...key-maker... come down...", 3.0, "shaft_emitter"),
	])

static func _set_storm_rain(game, root: Node3D, raining: bool) -> void:
	var rain := root.get_node_or_null("belfry_storm_rain") as GPUParticles3D
	if raining and rain == null:
		rain = GPUParticles3D.new()
		rain.name = "belfry_storm_rain"
		rain.position = Vector3(0, 24.0, -42)
		rain.amount = 280
		rain.lifetime = 0.91
		rain.preprocess = 0.9
		rain.visibility_aabb = AABB(Vector3(-14, -15, -14), Vector3(28, 17, 28))
		var process := ParticleProcessMaterial.new()
		process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		process.emission_box_extents = Vector3(12.8, 1.1, 12.8)
		process.direction = Vector3(0.12, -1, 0.08)
		process.spread = 3.0
		process.initial_velocity_min = 14.0
		process.initial_velocity_max = 16.0
		process.gravity = Vector3(0, -3, 0)
		rain.process_material = process
		var streak := QuadMesh.new()
		streak.size = Vector2(0.021, 0.62)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.66, 0.73, 0.94, 0.38)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		streak.material = material
		rain.draw_pass_1 = streak
		root.add_child(rain)
	if rain != null:
		rain.emitting = raining
	if raining and not root.has_meta("belfry_wet_zone"):
		root.set_meta("belfry_wet_zone", L.add_wet_zone(game, BELFRY_SHAFT, Vector2(12.0, 12.0)))
	if root.has_meta("belfry_wet_zone"):
		L.set_wet_zone_active(root.get_meta("belfry_wet_zone"), raining)

static func _watch_story(game, root: Node3D, st: Dictionary, director: Node) -> void:
	var world: Dictionary = st.story_world
	var leaves: Array = root.get_meta("vestibule_leaves")
	var sequence_state := {
		"wards": st.wards.duplicate(), "intro_wait": 0.0, "murmur_wait": 0.0,
		"thunder_wait": 11.0, "pending": "", "toll": 0, "low_hp_line": false,
		"chime_step": int(game.bell_sequence_step),
	}
	var timer := Timer.new()
	timer.name = "tower_story_sensors"
	timer.wait_time = 0.05
	timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
	timer.autostart = true
	timer.timeout.connect(func() -> void:
		if director.get_chapter() != CHAPTER or director.is_transitioning() or not is_instance_valid(game.player) or game.hp <= 0:
			return
		if game.map_overlay.visible or game.journal_panel.visible or game.pause_menu.visible:
			return

		var pos: Vector3 = game.player.global_position
		# An outward approach reopens the leaves, and waiting travellers keep them clear.
		var approaching_doors := pos.z > 31.9 and absf(pos.x) < 3.5 and absf(pos.y) < 2.0
		var door_angle := 4.0 if st.vestibule_shut and not approaching_doors else 55.0
		for leaf: AnimatableBody3D in leaves:
			var target_angle := -signf(leaf.position.x) * deg_to_rad(door_angle)
			var next := move_toward(leaf.rotation.y, target_angle, deg_to_rad(51.0) * timer.wait_time / 1.6)
			if not is_equal_approx(leaf.rotation.y, next):
				leaf.rotation.y = next
		if not st.vestibule_shut and pos.z < 29 and pos.z > 20 and pos.y < 2.0:
			director.start_sequence(PREFIX + "vestibule_doors")
		if not st.malcor_balcony_done and pos.z < 19.2 and not st.boss_dead:
			director.start_sequence(PREFIX + "malcor_balcony")
		if st.malcor_balcony_done and not st.nave_woken and director.is_sequence_completed(PREFIX + "malcor_balcony"):
			director.start_sequence(PREFIX + "nave_wake")
		if st.nave_woken and not director.is_sequence_completed(PREFIX + "tube_intro"):
			sequence_state.intro_wait += timer.wait_time
			var dead: Array = st.get("dead", [])
			if sequence_state.intro_wait >= 25.0 or (dead.has("tower_nave_1") and dead.has("tower_nave_2")):
				director.start_sequence(PREFIX + "tube_intro")

		for id: String in st.wards:
			if not sequence_state.wards.has(id):
				sequence_state.wards.append(id)
				director.start_sequence(PREFIX + id + "_broken")
		if not st.lift_ambush_done and bool(game.moving_lift.get("jammed", false)):
			director.start_sequence(PREFIX + "lift_ambush")
		var step: int = game.bell_sequence_step
		if step != sequence_state.chime_step:
			sequence_state.chime_step = step
			var origin := Vector3(-11.8, 8.4, -19.9)
			if step > 0 and step <= 3:
				game.narrative.submit_bark("hollow_choir", "THE HOLLOW CHOIR", ["…moon…", "…crown…", "…skull…"][step - 1], origin, 1.6, 0.0)
			elif step == 0:
				game.narrative.submit_bark("whisper", "— WHISPER —", "—wrong bell—", origin, 1.5, 0.0)
		var live: Node3D = director.get_actor("malcor_live")
		if is_instance_valid(live):
			var rig := live.get_child(0) as Node3D
			Meshes.animate_npc_rig(rig, game.elapsed, false, float(rig.get_meta("walk_speed", 0.0)), str(rig.get_meta("gesture", "")))
			if st.malcor_balcony_done and not world.malcor_departed and not director.is_sequence_running(PREFIX + "choir_departure"):
				var loft_clear := pos.y > 5.75 and pos.distance_to(MALCOR_VIGIL) < 7.0 and _vigil_clear(game, pos)
				if loft_clear or st.wards.size() >= WARD_ANCHORS.size():
					director.start_sequence(PREFIX + "choir_departure")
				elif pos.y > 5.75 and pos.distance_to(MALCOR_VIGIL) < 13.0:
					sequence_state.murmur_wait += timer.wait_time
					if sequence_state.murmur_wait >= 3.0:
						sequence_state.murmur_wait = 0.0
						game.narrative.submit_bark("malcor", "— WHISPER —", "...Hesk, Mara. Hesk, Tomas. Hesk, Anna. Hesk— the little one...", MALCOR_VIGIL + Vector3.UP, 1.5, 2.9)
		var dying: Node3D = director.get_actor("malcor_dying")
		if is_instance_valid(dying):
			var rig := dying.get_child(0) as Node3D
			Meshes.animate_npc_rig(rig, game.elapsed, false, float(rig.get_meta("walk_speed", 0.0)), str(rig.get_meta("gesture", "")))

		# Retry a crossing if the player reached the threshold during the dialogue.
		if pos.y > 9.1 and pos.z < -31.55 and not is_instance_valid(game.boss) and not st.boss_dead:
			director.start_sequence(PREFIX + "belfry_awakens")
		if st.boss_dead and not world.belfry_shaft_open:
			director.start_sequence(PREFIX + "belfry_shaft")
		_watch_warden(game, root, st, director, sequence_state, timer.wait_time)
	)
	root.add_child(timer)

static func _vigil_clear(game, pos: Vector3) -> bool:
	for hostile: Node3D in game.enemies:
		if is_instance_valid(hostile) and hostile.global_position.distance_to(pos) < 12.0:
			return false
	var ray := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 1.55, MALCOR_VIGIL + Vector3.UP * 1.25, L.LAYER_WORLD)
	return game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

static func _watch_warden(game, root: Node3D, st: Dictionary, director: Node, clocks: Dictionary, delta: float) -> void:
	var tethers: Node3D = root.get_meta("great_bell_tethers")
	var boss: CharacterBody3D = game.boss
	var active: bool = is_instance_valid(boss) and not st.boss_dead
	var phase_two: bool = active and bool(boss.get_meta("aegis_phase_two", int(st.boss_hp) <= 260))
	tethers.visible = active and not phase_two
	if not active:
		return
	root.set_meta("warden_last_position", boss.global_position)
	if phase_two:
		director.start_sequence(PREFIX + "warden_phase_two")
	else:
		for link: Node3D in tethers.get_children():
			var rack := boss.global_position + Vector3(link.position.x * 0.38, 3.3, 0.15)
			var span := rack - link.global_position
			if span.length_squared() > 0.01:
				link.basis = Basis(Quaternion(Vector3.DOWN, span.normalized())).scaled_local(Vector3(1, span.length() / 7.4, 1))

	clocks.thunder_wait -= delta
	if clocks.thunder_wait <= 0.0:
		clocks.thunder_wait = 11.0
		game._sound_at("thunder_far", BELFRY_SHAFT + Vector3.UP * 19.0)
	var pending := str(boss.get_meta("pending", ""))
	if pending != clocks.pending:
		clocks.pending = pending
		var bark := ""
		match pending:
			"tolling_wave":
				bark = ["MOON!", "CROWN!", "SKULL!"][int(clocks.toll) % 3]
				clocks.toll += 1
			"sonic_volley":
				bark = "Count them!"
			"dread_summon":
				bark = "Rise, Watch! Hold the Court!"
			"boss_triple":
				if phase_two:
					var crown := BELFRY_SHAFT + Vector3.UP * 22.3
					Visuals.spawn_lightning_arc(root, crown + Vector3(5, 17, 3), crown, Color("d6dcff"), 0.16)
					Visuals.spawn_impact_light(root, crown, Color("d6dcff"), 12.0, 38.0, 0.24)
		if not bark.is_empty():
			game.narrative.submit_bark("malcor", "LORD MALCOR", bark, boss.global_position + Vector3.UP * 3.6, 1.5, 1.5)
	if int(st.boss_hp) <= 80 and not clocks.low_hp_line:
		clocks.low_hp_line = true
		game.narrative.submit_bark("malcor", "LORD MALCOR", "Not yet— I haven’t— finished the count—", boss.global_position + Vector3.UP * 3.6, 1.5, 1.5)
