extends RefCounted

const L = preload("res://scripts/level_builder.gd")
const Visuals = preload("res://scripts/visuals.gd")
const PhysicsSandbox = preload("res://scripts/physics_sandbox.gd")

const BELFRY_SHAFT := Vector3(0, 9.5, -42)
const KILN_PORTAL := Vector3(0, 7, -42)
const BRONZE_LIGHT := Color("ffc385")
const CYAN_LIGHT := Color("82e6ff")
const VIOLET_LIGHT := Color("bba1ff")

static func default_state() -> Dictionary:
	return {
		"wards": [], "gear_frozen": false, "lift_powered": false, "lift_unjammed": false,
		"lift_completed": false, "boss_dead": false, "boss_hp": 520,
	}

static func build(game, st: Dictionary) -> void:
	var root: Node3D = game.level_root
	_lower_nave(game, root)
	_clockwork_gallery(game, root, st)
	_pendulum_foundry(game, root, st)
	_counterweight_lift(game, root, st)
	_choir_loft(game, root, st)
	_belfry(game, root, st)
	game._scatter_particles("ember", 80, Rect2(-33, -55, 66, 81))

static func _lower_nave(game, root: Node3D) -> void:
	L.slab(root, "lower_nave", Rect2(-16, -11, 32, 38), 0, game.mats.stone)
	L.box(root, "choir_foundation", Vector3(0, 2.6, -10.99), Vector3(32, 5.2, 0.8), game.mats.dark)
	L.box(root, "nave_south_wall", Vector3(0, 5.8, 27), Vector3(32, 11.6, 1.1), game.mats.dark)
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
	for z: float in [22, 9.5, -4]:
		L.hanging_chain_lamp(game, root, Vector3(0, 6.8, z), 8.15, BRONZE_LIGHT, 5.7, 14.0)
	for pos: Vector3 in [Vector3(-5, 9.5, 11), Vector3(5, 9, 5), Vector3(0, 11, -3)]:
		game._hanging_bell(pos)
		L.cylinder(root, "nave_bell_chain", pos + Vector3.UP * 3, 0.14, 6, game.mats.iron, false, 8)
	for z: float in [15, 22]:
		game._stained_glass(Vector3(15.35, 6.7, z), false)
		var window_light := VIOLET_LIGHT if z == 22 else CYAN_LIGHT
		Visuals.spawn_godray(root, Vector3(9.0, 3.5, z), Vector3(0, 0, -63), 2.6, 13.4, Color(window_light, 0.23))
		L.focus_light(root, Vector3(15.15, 6.65, z), Vector3(4.8, 0.15, z), window_light, 7.2, 26.0, 2.15)
	L.hanging_chain_lamp(game, root, Vector3(-14.6, 4.4, 2.4), 1.75, BRONZE_LIGHT, 3.8, 9.0)
	L.hanging_chain_lamp(game, root, Vector3(14.6, 4.4, 5), 1.75, BRONZE_LIGHT, 3.8, 9.0)
	L.add_alchemical_font(game, Vector3(-6.5, 0, 19))
	L.add_checkpoint_zone(game, Vector3(0, 1.4, 20), Vector3(11, 2.8, 3), "tower_nave", "Lower Nave")
	game._portal(Vector3(-7.5, 0, 24.4), "ch1_court", "RETURN TO THE SUNKEN COURT")
	game._inscription(Vector3(6.5, 0, 19.5), "THE WARDEN'S OATH", "Freeze the steam pipe in the West Gallery. Swing the clapper in the East Foundry. Ring the hand-bells in the Choir Loft. All three wards feed Malcor's shield.")
	game._enemy(Vector3(-5.4, 0.1, 9), false, "tower_nave_1", false, "shrieker")
	game._enemy(Vector3(6.5, 0.1, 4), false, "tower_nave_2", false, "shrieker")
	L.add_explosive_cask(game, Vector3(-5, 0, 6.5), "tower_cask_nave")
	game._pickup(Vector3(10, 0.55, 15.7), "mana", "tower_blue_1")

static func _clockwork_gallery(game, root: Node3D, st: Dictionary) -> void:
	L.slab(root, "clockwork_floor", Rect2(-34, -10, 18, 22), 0, game.mats.stone)
	L.archway(root, "clockwork_entry", Vector3(-16, 0, 2.4), 7.5, 6, 1.5, game.mats.stone, game.mats.brass, PI * 0.5)
	for z: float in [-10, 12]:
		L.box(root, "clockwork_end_wall", Vector3(-25, 4.6, z), Vector3(18, 9.2, 1.0), game.mats.dark)
	L.box(root, "clockwork_outer_wall", Vector3(-34, 4.6, 1), Vector3(1.1, 9.2, 22), game.mats.dark)
	L.box(root, "clockwork_roof", Vector3(-25, 8.8, 1), Vector3(18, 0.8, 22), game.mats.dark, false)
	L.hanging_chain_lamp(game, root, Vector3(-21.4, 4.65, 1.3), 3.35, BRONZE_LIGHT, 4.3, 11.5)
	L.iron_grate_floor(root, Vector3(-22.4, 0, -5.95), Vector2(3.75, 1.15), game.mats.iron)
	for x: float in [-31.5, -24, -19]:
		var rib := L.vaulted_rib(root, Vector3(x, 4.8, 1), 19.5, 4.2, game.mats.stone, game.mats.brass)
		rib.rotation.y = PI * 0.5
	L.box(root, "gear_vault_divider_north", Vector3(-28.2, 2.8, -5.05), Vector3(1.0, 5.6, 9.9), game.mats.dark)
	L.box(root, "gear_vault_divider_south", Vector3(-28.2, 2.8, 6.55), Vector3(1.0, 5.6, 10.9), game.mats.dark)
	L.box(root, "gear_aperture_crown", Vector3(-28.2, 5.55, 0.5), Vector3(1, 2.1, 5.0), game.mats.stone)
	if not st.wards.has("ward_1"):
		game._ward(Vector3(-31.1, 0, 0.5), "ward_1")
		if not st.gear_frozen:
			var gear := L.cylinder(root, "rotating_cogwheel", Vector3(-28, 2.2, 0.5), 2.35, 0.6, game.mats.iron, true, 16)
			gear.rotation.z = PI * 0.5
			for i in 12:
				var angle := TAU * float(i) / 12.0
				var tooth := L.box(gear, "gear_tooth", Vector3(cos(angle) * 2.34, 0, sin(angle) * 2.34), Vector3(0.42, 0.77, 0.5), game.mats.brass, false)
				tooth.rotation.y = -angle
			game.tower_gear = gear
			var pipe := L.cylinder(root, "leaking_steam_pipe", Vector3(-24.6, 1.6, -3.25), 0.42, 2.8, game.mats.copper, true, 12, L.LAYER_TARGET)
			pipe.set_meta("steam_pipe", true)
			game.shootable_targets.append(pipe)
			game._light(Vector3(-24.6, 2, -3.25), Color("9ee9f5"), 2, 6)
			L.cylinder(root, "steam_feed", Vector3(-24.6, 3.75, -3.25), 0.16, 2.25, game.mats.iron, false, 10)
			L.focus_light(root, Vector3(-23.15, 5.25, -1.5), pipe.position, CYAN_LIGHT, 4.8, 22.0, 0.55)
	game._torch(Vector3(-23.2, 2.7, 7))
	game._torch(Vector3(-23.2, 2.7, -7.5))
	L.box(root, "fork_workbench", Vector3(-22.5, 0.43, -7.2), Vector3(3.4, 0.86, 1.45), game.mats.copper)
	L.box(root, "workbench_terminal", Vector3(-23.65, 0.99, -7.2), Vector3(0.5, 0.26, 0.5), game.mats.mana, false)
	game._pickup(Vector3(-22.5, 1.17, -7.2), "voltaic", "tower_voltaic")
	L.add_voltaic_conduit(game, Vector3(-20, 1.25, -7.2), "conduit_lift_power", "Ascending Lift")
	L.focus_light(root, Vector3(-22.5, 5.15, -8.65), Vector3(-22.5, 1.17, -7.2), BRONZE_LIGHT, 5.25, 23.0)
	L.focus_light(root, Vector3(-18.65, 4.15, -7.7), Vector3(-20, 1.25, -7.2), CYAN_LIGHT, 3.0, 23.0)
	game._inscription(Vector3(-20.7, 0, -5.2), "LIFT POWER", "Equip the tuning fork [4] and strike the copper conduit. The lift call lever is in the central nave.")
	L.box(root, "gear_secret_back", Vector3(-32.9, 2.2, 8.7), Vector3(1.0, 4.4, 6.0), game.mats.dark)
	L.box(root, "gear_secret_front", Vector3(-30.65, 2.2, 5.9), Vector3(4.5, 4.4, 0.7), game.mats.dark)
	L.add_rotten_barricade(game, Vector3(-30.75, 1.2, 3.55), "tower_secret_bar_1", Vector3(3.5, 2.4, 0.45), true)
	L.focus_light(root, Vector3(-32.4, 3.5, 2.1), Vector3(-30.75, 1.2, 3.55), BRONZE_LIGHT, 1.8, 23.0)
	# Ward chamber opens into a smaller vault beyond the breakable barricade.
	L.box(root, "gear_secret_bar_jamb_w", Vector3(-33.15, 2, 3.55), Vector3(1.35, 4, 0.55), game.mats.dark)
	L.box(root, "gear_secret_bar_jamb_e", Vector3(-28.7, 2, 3.55), Vector3(0.8, 4, 0.55), game.mats.dark)
	game._pickup(Vector3(-31, 0.85, 4.9), "relic_siphon", "relic_siphon_signet")
	game._pickup(Vector3(-32.35, 0.55, 4.9), "flask", "tower_secret_flask_1")
	game._enemy(Vector3(-22.5, 0.1, 1), true, "tower_west_exec", false, "executioner")

static func _pendulum_foundry(game, root: Node3D, st: Dictionary) -> void:
	L.slab(root, "pendulum_foundry_floor", Rect2(16, -10, 18, 22), 0, game.mats.stone)
	L.slab(root, "pendulum_foundry_balcony", Rect2(16, -10, 18, 10), 3.5, game.mats.timber)
	L.archway(root, "pendulum_foundry_entry", Vector3(16, 0, 5), 7.8, 6, 1.4, game.mats.stone, game.mats.brass, PI * 0.5)
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
		game.tower_cracked_wall = wall
		var pivot := Vector3(24.8, 8.5, -4.9)
		L.box(root, "pendulum_support", pivot + Vector3.UP * 0.2, Vector3(1.4, 0.42, 8.4), game.mats.iron, false)
		var pendulum := PhysicsSandbox.create_hinged_pendulum(root, pivot, 3.35, game.mats.brass, game.mats.iron)
		var bob: RigidBody3D = pendulum.bob
		bob.contact_monitor = true
		bob.max_contacts_reported = 4
		bob.set_meta("pendulum", true)
		bob.set_meta("hits", 0)
		bob.set_meta("base_pos", bob.position)
		game.hinged_pendulum = pendulum
		game.tower_pendulum = bob
		game._light(bob.position + Vector3.UP * 0.6, Color("f2b955"), 1.9, 6)
		L.focus_light(root, Vector3(23.4, 9.4, -2.55), bob.position, BRONZE_LIGHT, 5.9, 25.0, 0.52)
	game._inscription(Vector3(24.1, 3.5, -1.2), "WARD II — THE PENDULUM", "Stand west of the clapper and strike it with Repulse [Q]. The swing can break through the cracked wall.")
	game._enemy(Vector3(28.5, 0.1, 5.8), false, "tower_east_shr", false, "shrieker")
	game._enemy(Vector3(25.5, 3.6, -6.9), false, "tower_east_aco", false, "acolyte")

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
	game.lift_call_lever = L.lever(root, "lift_call_lever", Vector3(-3.35, 0, -2.86), game.mats.dark, game.mats.brass)
	L.focus_light(root, Vector3(-4.85, 4.3, -3.42), Vector3(-3.35, 0.95, -2.86), BRONZE_LIGHT, 3.7, 26.0)
	if not st.lift_unjammed and not st.lift_completed:
		var latch := L.cylinder(root, "lift_gear_latch", Vector3(0.8, 4.65, -9.72), 0.43, 0.62, game.mats.mana, true, 10, L.LAYER_TARGET)
		latch.set_meta("lift_latch", true)
		game.shootable_targets.append(latch)
		game._light(latch.position, Color("69dae8"), 1.5, 5)
		L.focus_light(root, Vector3(2.15, 8.9, -8.65), latch.position, CYAN_LIGHT, 5.9, 23.0, 0.72)
	for x: float in [-11.05, 11.05]:
		L.staircase(root, "flanking_choir_stair", Vector3(x, 0, 7.8), Vector3(x, 6, -10.0), 4.5, game.mats.stone, game.mats.iron)
	game._enemy(Vector3(5.9, 0.1, -7.2), false, "tower_lift_aco", false, "acolyte")
	game._enemy(Vector3(6.3, 6.1, -14.5), false, "tower_choir_aco", false, "acolyte")

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
		L.box(root, "choir_south_guard", Vector3(x, 6.58, -10.15), Vector3(2.5 if absf(x) > 14 else 4.63, 1.16, 0.38), game.mats.iron)
	for x: float in [-9.74, 9.74]:
		L.box(root, "choir_north_guard", Vector3(x, 6.64, -27.85), Vector3(12.6, 1.28, 0.5), game.mats.iron)
	var lines: Array[String] = [
		"Caelen. You remember how the bronze rang on the day we sealed the breach. You should hear what answers it now.",
		"I have rung this bell for forty nights to keep the Hollow Choir asleep. The crack is drawing lives from the city. I know every name I have failed to save.",
		"If you break my wards, come finish the work in the belfry. Then go below and see what your king made of the dead.",
	]
	game._npc(Vector3(5.8, 6, -22.4), "malcor_live", "malcor_choir", "Lord Malcor", lines, 0.28)
	L.add_checkpoint_zone(game, Vector3(0, 7.45, -16.8), Vector3(13, 3, 4.6), "tower_choir", "Choir Loft")
	if not st.wards.has("ward_3"):
		game._ward(Vector3(-14.25, 6, -19.9), "ward_3")
		for z: float in [-22.35, -17.45]:
			L.box(root, "ward3_niche_wall", Vector3(-14.15, 7.95, z), Vector3(3.2, 3.9, 0.6), game.mats.dark)
		var shutter := L.box(root, "ward3_shutter", Vector3(-12.55, 7.9, -19.9), Vector3(0.5, 3.8, 4.8), game.mats.iron) as StaticBody3D
		game.ward3_shutter = shutter
		var names: Array[String] = ["CRESCENT", "CROWN", "SKULL"]
		var pitches: Array[float] = [0.78, 1.0, 1.28]
		var metals: Array[Material] = [game.mats.mana, game.mats.brass, game.mats.portal]
		var bell_lights: Array[Color] = [CYAN_LIGHT, BRONZE_LIGHT, VIOLET_LIGHT]
		for i in names.size():
			var pos := Vector3(-10.2, 8.5 + 0.4 * i, -23 + 3 * i)
			var bell := L.cylinder(root, "harmonic_bell_" + names[i].to_lower(), pos, 0.48, 0.9, metals[i], true, 12, L.LAYER_TARGET)
			bell.set_meta("harmonic_bell", true)
			bell.set_meta("bell_idx", i)
			bell.set_meta("bell_name", names[i])
			bell.set_meta("bell_pitch", pitches[i])
			game.shootable_targets.append(bell)
			L.cylinder(root, "bell_suspension", pos + Vector3.UP * 1.28, 0.058, 1.8, game.mats.iron, false, 8)
			L.focus_light(root, pos + Vector3(2.0, 2.75, 1.0), pos, bell_lights[i], 2.7, 22.0)
	game._inscription(Vector3(-7.7, 6, -16.3), "WARD III — HARMONIC CHIMES", "Ring the three hand-bells with the Arbalest. Crescent (cyan), Crown (gold), then Skull (violet).")
	L.add_explosive_cask(game, Vector3(6.2, 6, -18.9), "tower_cask_choir")
	game._enemy(Vector3(-4.8, 6.1, -20.1), true, "tower_choir_exec", false, "executioner")

static func _belfry(game, root: Node3D, st: Dictionary) -> void:
	L.staircase(root, "belfry_grand_stair", Vector3(0, 6, -22.5), Vector3(0, 9.5, -29.58), 5.8, game.mats.stone, game.mats.iron)
	L.archway(root, "belfry_arch", Vector3(0, 9.5, -30.8), 7.6, 6.2, 1.5, game.mats.stone, game.mats.brass)
	L.hanging_chain_lamp(game, root, Vector3(0, 13.4, -30.8), 1.9, BRONZE_LIGHT, 3.7, 10.5)
	L.slab(root, "sanctum_south", Rect2(-14, -39, 28, 9.3), 9.5, game.mats.stone)
	L.slab(root, "sanctum_north", Rect2(-14, -56, 28, 11), 9.5, game.mats.stone)
	L.slab(root, "sanctum_west", Rect2(-14, -45, 11, 6), 9.5, game.mats.stone)
	L.slab(root, "sanctum_east", Rect2(3, -45, 11, 6), 9.5, game.mats.stone)
	for x: float in [-8.65, 8.65]:
		L.box(root, "belfry_entry_abutment", Vector3(x, 10.8, -30.1), Vector3(10.95, 2.6, 0.72), game.mats.dark)
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
	game._pickup(Vector3(0, 10, -51.9), "flask", "tower_arena_flask")
	game._pickup(Vector3(-5.5, 10, -46.4), "mana", "tower_blue_2")
	game._pickup(Vector3(5.5, 10, -46.4), "green", "tower_green_2")
	var floorboards := L.slab(root, "belfry_floorboards", Rect2(-3.02, -45.02, 6.04, 6.04), 9.5, game.mats.timber, 0.44)
	game.belfry_floorboards = floorboards
	L.slab(root, "drop_shaft_landing", Rect2(-3.15, -45.15, 6.3, 6.3), 7, game.mats.stone)
	# Climb the inset ledges to return from the portal.
	L.slab(root, "shaft_return_step_lower", Rect2(-2.6, -41.7, 2.4, 1.55), 7.84, game.mats.stone, 1.0)
	L.slab(root, "shaft_return_step_upper", Rect2(-2.6, -40.15, 2.4, 1.2), 8.67, game.mats.stone, 1.8)
	if st.boss_dead:
		floorboards.visible = false
		floorboards.collision_layer = 0
		game._portal(KILN_PORTAL, "ch3_kiln", "DESCEND TO THE KILN OF ASH")
		L.focus_light(root, BELFRY_SHAFT + Vector3(2.3, 5.5, -1.3), KILN_PORTAL, VIOLET_LIGHT, 4.25, 23.0, 0.85)
	else:
		game._enemy(Vector3(0, 9.6, -44.2), true, "warden", true, "warden")
	L.add_trigger_volume(game, Vector3(0, 10.9, -31.7), Vector3(7, 3.8, 3.2), "belfry_sanctum", "", "belfry_sanctum", "THE BELFRY SANCTUM", "Malcor rises with the bell rack on his back. The three wards resonate through the floorboards.", "THE BELL WARDEN AWAKENS", "bell")
