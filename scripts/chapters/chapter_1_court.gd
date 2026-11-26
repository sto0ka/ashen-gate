extends RefCounted

const L = preload("res://scripts/level_builder.gd")
const Visuals = preload("res://scripts/visuals.gd")
const PhysicsSandbox = preload("res://scripts/physics_sandbox.gd")

const AMBER := Color("ffbd70")
const CISTERN_LIGHT := Color("7ce5d0")
const CRYPT_LIGHT := Color("8adbee")

static func default_state() -> Dictionary:
	return {
		"gate_open": false, "gatehouse_open": false, "has_lever": false, "lever_inserted": false,
		"cage_dropped": false, "shortcut_open": false, "ambush_done": false, "cistern_raised": false,
	}

static func build(game, st: Dictionary) -> void:
	var root: Node3D = game.level_root
	_gatehouse(game, root, st)
	_cloister(game, root)
	_cistern(game, root, st)
	_ossuary(game, root, st)
	_basin(game, root, st)
	_north_viaduct(game, root, st)
	game._scatter_particles("ash", 90, Rect2(-30, -34, 60, 78))

static func _gatehouse(game, root: Node3D, st: Dictionary) -> void:
	L.slab(root, "outer_viaduct", Rect2(-5.8, 35, 11.6, 13), 0, game.mats.floor)
	L.box(root, "viaduct_end", Vector3(0, 2.0, 47.8), Vector3(12, 4, 0.8), game.mats.dark)
	for x: float in [-5.6, 5.6]:
		L.box(root, "viaduct_parapet", Vector3(x, 0.7, 41.5), Vector3(0.7, 1.4, 13), game.mats.stone)
		for z: float in [38, 45]:
			L.box(root, "bridge_buttress", Vector3(x, -3.0, z), Vector3(2.0, 6.0, 2.6), game.mats.dark)
			L.box(root, "weathered_merlon", Vector3(x, 1.75, z), Vector3(1.1, 0.9, 0.9), game.mats.stone, false)
			L.box(root, "viaduct_arch_pier", Vector3(x, 2.8, z), Vector3(0.9, 2.0, 0.85), game.mats.dark, false)
	for z: float in [38, 45]:
		L.vaulted_rib(root, Vector3(0, 3.7, z), 11.2, 3.7, game.mats.stone, game.mats.brass)
		L.hanging_chain_lamp(game, root, Vector3(0, 4.35, z), 2.55, AMBER, 3.2, 9.0)
	L.slab(root, "gatehouse_floor", Rect2(-8, 29, 16, 8), 0, game.mats.floor)
	for x: float in [-8, 8]:
		L.box(root, "gatehouse_wall", Vector3(x, 4, 33), Vector3(1.1, 8, 8), game.mats.dark)
		L.cone(root, "gatehouse_spire", Vector3(x, 11, 35.4), 2.6, 0.16, 6, game.mats.dark, 8)
	for z: float in [30.0, 36.0]:
		L.archway(root, "gatehouse_arch", Vector3(0, 0, z), 7.6, 5.2, 1.4, game.mats.stone, game.mats.brass)
		L.vaulted_rib(root, Vector3(0, 4.25, z), 8, 4.2, game.mats.stone, game.mats.brass)
	L.focus_light(root, Vector3(-3.5, 4.1, 33.2), Vector3(-4.13, 1.1, 32.1), AMBER, 4.0, 28.0)
	L.box(root, "gatehouse_wing_wall_east", Vector3(6.05, 2.6, 30.05), Vector3(3.5, 5.2, 0.9), game.mats.dark)
	L.box(root, "observation_cell_south", Vector3(-6, 2, 34.5), Vector3(4, 4, 0.5), game.mats.dark)
	L.box(root, "observation_cell_north", Vector3(-6, 2, 29.8), Vector3(4, 4, 0.5), game.mats.dark)
	for i in 9:
		L.box(root, "observation_grate", Vector3(-4.15, 1.85, 30.05 + i * 0.52), Vector3(0.17, 3.7, 0.13), game.mats.iron)
	game._torch(Vector3(-6.4, 2.7, 32))
	game._torch(Vector3(5.3, 2.7, 33.8))
	var lines: Array[String] = [
		"Caelen? They told me the exile had sent you east. Come closer. The grate is the only thing between me and the patrol.",
		"Your old resonance lock has inverted. Every toll draws another breath from the living city. I have the gatehouse bar. Go!",
		"Take the Briar Arbalest from the western cistern. The iron lever for the north seal is in the ossuary.",
	]
	game._npc(Vector3(-5.5, 0, 32), "seraphina", "seraphina_gatehouse", "Archivist Seraphina", lines, -PI * 0.5)
	var bar := L.box(root, "gatehouse_bar", Vector3(0, 1.85, 30.05), Vector3(6.65, 3.7, 0.27), game.mats.iron, true) as StaticBody3D
	for x: float in [-2.8, 0, 2.8]:
		L.box(bar, "bar_reinforcement", Vector3(x, 0, 0.18), Vector3(0.13, 3.75, 0.15), game.mats.brass, false)
	if st.gatehouse_open:
		bar.position.y += 4.5
		bar.collision_layer = 0
	else:
		var approach := L.add_trigger_volume(game, Vector3(-3.05, 1.4, 32.4), Vector3(2.2, 2.8, 2.8), "gatehouse_meeting")
		approach.body_entered.connect(func(body: Node3D) -> void:
			if body != game.player or st.gatehouse_open:
				return
			st.gatehouse_open = true
			var opening := bar.create_tween()
			opening.tween_interval(1.25)
			opening.tween_property(bar, "position:y", 6.35, 0.8)
			opening.tween_callback(func() -> void: bar.collision_layer = 0)
		)

static func _cloister(game, root: Node3D) -> void:
	L.slab(root, "south_cloister_floor", Rect2(-12, 16, 21, 14), 0, game.mats.floor)
	L.slab(root, "ossuary_shortcut_landing", Rect2(9, 16, 10, 5), 0, game.mats.floor)
	L.box(root, "cloister_west", Vector3(-12, 4.25, 23), Vector3(1, 8.5, 14), game.mats.dark)
	L.box(root, "cloister_east", Vector3(9.3, 4.25, 24.8), Vector3(1, 8.5, 10.4), game.mats.dark)
	L.box(root, "cloister_south_w", Vector3(-8.5, 3.0, 29.8), Vector3(7, 6, 1), game.mats.stone)
	L.box(root, "cloister_south_e", Vector3(7, 3.0, 29.8), Vector3(5, 6, 1), game.mats.stone)
	L.box(root, "cloister_roof", Vector3(-1.5, 10.25, 23.5), Vector3(22, 0.8, 13), game.mats.dark, false)
	for z: float in [19, 23, 27.5]:
		L.vaulted_rib(root, Vector3(-1, 5.1, z), 17, 4.8, game.mats.stone, game.mats.brass)
		L.hanging_chain_lamp(game, root, Vector3(-1, 5.2, z), 4.2, AMBER, 3.8, 11.5)
		for x: float in [-9.5, 7.5]:
			L.cylinder(root, "cloister_clustered_pier", Vector3(x, 2.55, z), 0.57, 5.1, game.mats.stone, true, 10)
			L.cylinder(root, "cloister_pier_capital", Vector3(x, 5.05, z), 0.78, 0.45, game.mats.brass, false, 10)
		game._stained_glass(Vector3(-11.4, 5.4, z), true)
		Visuals.spawn_godray(root, Vector3(-7.1, 3.7, z), Vector3(0, 0, 54), 2.25, 10.5, Color(0.78, 0.85, 0.94, 0.24))
	L.add_alchemical_font(game, Vector3(-5.8, 0, 23.5))
	L.add_checkpoint_zone(game, Vector3(0, 1.3, 25), Vector3(9, 2.8, 3.2), "court_cloister", "South Cloister")
	L.box(root, "camp_pallet", Vector3(6.5, 0.1, 26.3), Vector3(2.0, 0.2, 3.2), game.mats.timber, false)
	game._torch(Vector3(6.8, 2.25, 25.8))
	game._inscription(Vector3(5.6, 0, 22.8), "THE FALLEN CAMP", "The western cistern holds the Briar Arbalest. The eastern ossuary holds the iron lever. Bring both to the basin seals.")
	game._pickup(Vector3(5.8, 0.55, 27.0), "flask", "court_camp_flask")

static func _cistern(game, root: Node3D, st: Dictionary) -> void:
	L.slab(root, "cistern_bed", Rect2(-30, -14, 20, 32), -0.8, game.mats.stone)
	L.slab(root, "cistern_entry_quay", Rect2(-13, -8, 4, 20), 0, game.mats.floor)
	L.staircase(root, "cistern_entry_steps", Vector3(-12.8, 0, 4), Vector3(-16.2, -0.8, 4), 3.6, game.mats.stone, game.mats.iron)
	L.slab(root, "sluice_causeway", Rect2(-27, 8, 15, 4), 0, game.mats.floor)
	L.iron_grate_floor(root, Vector3(-21.3, 0, 10), Vector2(2.8, 1.5), game.mats.iron)
	for x: float in [-30, -10]:
		for z: float in [-10, 13.4]:
			L.box(root, "cistern_side_wall", Vector3(x, 3.3, z), Vector3(1, 8.2, 8.2 if x == -10 else 9.2), game.mats.dark)
	L.box(root, "cistern_outer_wall", Vector3(-30, 3.3, 1.7), Vector3(1, 8.2, 16), game.mats.dark)
	for z: float in [-14, 18]:
		L.box(root, "cistern_end_wall", Vector3(-20, 3.3, z), Vector3(20, 8.2, 1), game.mats.dark)
	for z: float in [-9, 0, 11]:
		L.vaulted_rib(root, Vector3(-20, 4.6, z), 19, 6.1, game.mats.stone, game.mats.brass)
		game._torch(Vector3(-28.8, 2.2, z))
	L.hanging_chain_lamp(game, root, Vector3(-23.75, 3.7, 11), 5.6, AMBER, 4.4, 11.0)
	L.hanging_chain_lamp(game, root, Vector3(-17.8, 4.15, 0), 5.65, CISTERN_LIGHT, 3.3, 10.0)
	L.focus_light(root, Vector3(-19.6, 5.0, 1.4), Vector3(-17.8, 0.95, -1.2), CISTERN_LIGHT, 4.2, 23.0)
	L.add_wet_zone(game, Vector3(-20.7, -0.5, 2), Vector2(8.7, 15.5))
	var water_y := 1.45 if st.cistern_raised else -0.53
	var water := L.box(root, "cistern_water", Vector3(-20.7, water_y, 2), Vector3(17.4, 0.1, 31), game.mats.water, false)
	water.set_meta("raised_y", 1.45)
	water.set_meta("lowered_y", -0.53)
	game.cistern_water_node = water
	var sluice := L.lever(root, "cistern_sluice_lever", Vector3(-24, 0, 10), game.mats.dark, game.mats.brass)
	sluice.set_meta("raised_y", 1.45)
	game.cistern_sluice_lever = sluice
	L.slab(root, "arbalest_altar_island", Rect2(-20, -3.9, 4.6, 5.5), -0.05, game.mats.dark)
	L.staircase(root, "arbalest_altar_steps", Vector3(-17.8, -0.8, 4.1), Vector3(-17.8, -0.05, 1.7), 2.8, game.mats.stone, game.mats.iron)
	L.box(root, "arbalest_altar", Vector3(-17.8, 0.28, -1.2), Vector3(2.4, 0.66, 1.75), game.mats.brass)
	game._light(Vector3(-17.8, 2, -1.2), Color("63da93"), 2.1, 7)
	if not game.has_arbalest:
		game._pickup(Vector3(-17.8, 0.95, -1.2), "arbalest", "court_arbalest")
	L.slab(root, "sluice_boarding_pier", Rect2(-27, 4.6, 4.3, 4.2), 0.92, game.mats.stone)
	L.staircase(root, "sluice_boarding_steps", Vector3(-25, 0, 11.45), Vector3(-25, 0.92, 8.95), 2.2, game.mats.stone, game.mats.iron)
	for z: float in [2.0, -2.65]:
		var raft := PhysicsSandbox.create_buoyant_raft(root, Vector3(-25, water_y, z), Vector3(3.4, 0.35, 4.0), game.mats.timber, game.mats.iron)
		raft.axis_lock_linear_x = true
		raft.axis_lock_linear_z = true
		raft.axis_lock_angular_y = true
		game.buoyant_rafts.append(raft)
	L.slab(root, "west_parapet", Rect2(-29.5, -13.5, 7.7, 8.8), 2.42, game.mats.stone)
	L.box(root, "parapet_vault_wall_w", Vector3(-28.9, 3.9, -10.2), Vector3(0.6, 3, 5.3), game.mats.dark)
	L.box(root, "parapet_vault_wall_e", Vector3(-22.5, 3.9, -10.2), Vector3(0.6, 3, 5.3), game.mats.dark)
	L.box(root, "parapet_vault_face_w", Vector3(-28, 3.9, -8.1), Vector3(2.4, 3, 0.65), game.mats.dark)
	L.box(root, "parapet_vault_face_e", Vector3(-23.4, 3.9, -8.1), Vector3(2.4, 3, 0.65), game.mats.dark)
	L.add_rotten_barricade(game, Vector3(-25.7, 3.62, -8.1), "court_secret_bar_1", Vector3(2.6, 2.4, 0.45), true)
	L.focus_light(root, Vector3(-28.25, 5.55, -6.15), Vector3(-25.7, 3.62, -8.1), AMBER, 2.2, 22.0)
	game._pickup(Vector3(-25.7, 3.15, -11.7), "relic_heart", "relic_heart_vaelor")
	game._inscription(Vector3(-24, 2.42, -11.8), "THE KING'S EDICT", "King Vaelor sealed the Gate while half the lower ward still breathed. The bell was ordered to silence the witnesses.")
	game._inscription(Vector3(-22.1, 0, 10.5), "CISTERN SLUICE", "Raise the sluice at the quay. The timber rafts will float high enough to reach the western parapet.")
	game._enemy(Vector3(-16.2, -0.7, 7), false, "court_west_1", false, "shrieker")
	game._enemy(Vector3(-21.1, -0.7, -5.9), false, "court_west_2", false, "shrieker")
	L.add_explosive_cask(game, Vector3(-15, 0, 10.4), "court_cask_west")

static func _ossuary(game, root: Node3D, st: Dictionary) -> void:
	L.slab(root, "ossuary_upper_path", Rect2(9, -6, 9, 8), 0, game.mats.floor)
	L.slab(root, "ossuary_crypt_floor", Rect2(16, -18, 14, 34), -0.7, game.mats.floor)
	L.slab(root, "ossuary_shortcut_quay", Rect2(9, 15.7, 21, 4.1), 0, game.mats.floor)
	L.staircase(root, "ossuary_descent", Vector3(17.5, 0, -2), Vector3(21.5, -0.7, -2), 3.7, game.mats.stone, game.mats.iron)
	L.staircase(root, "ossuary_return_steps", Vector3(21.6, -0.7, 11.6), Vector3(21.6, 0, 15.82), 3.6, game.mats.stone, game.mats.iron)
	L.box(root, "ossuary_west_cutoff", Vector3(15.8, 2.7, 8.7), Vector3(0.9, 6.8, 13.5), game.mats.dark)
	L.box(root, "ossuary_west_north", Vector3(15.8, 2.7, -12), Vector3(0.9, 6.8, 12), game.mats.dark)
	L.box(root, "ossuary_east_wall", Vector3(30, 2.7, 1), Vector3(1.1, 6.8, 38), game.mats.dark)
	for z: float in [-18, 19.8]:
		L.box(root, "ossuary_end_wall", Vector3(22.9, 2.7, z), Vector3(15, 6.8, 0.9), game.mats.dark)
	L.box(root, "ossuary_roof", Vector3(23, 6.1, 0.5), Vector3(14.6, 0.7, 37), game.mats.dark, false)
	# Cool route lights leave the central crypt in contrast when the wall torches dim.
	for pos: Vector3 in [Vector3(20.1, 3.55, -2), Vector3(26.5, 3.9, -6.1), Vector3(23, 3.65, -13.1), Vector3(19, 3.65, 8.7)]:
		L.hanging_chain_lamp(game, root, pos, 5.75 - pos.y - 0.4, CRYPT_LIGHT, 1.55, 7.8)
	var bone: Material = game._material(Color("c8b99c"))
	for z: float in [-15.5, -8.2, -1.5, 3.3, 13.5]:
		L.ossuary_niche(root, Vector3(29.42, 1.03, z), -PI * 0.5, game.mats.stone, bone)
	for z: float in [-15.1, -10.1, 8.0]:
		L.ossuary_niche(root, Vector3(16.28, 0.98, z), PI * 0.5, game.mats.stone, bone)
	L.box(root, "ossuary_north_partition", Vector3(20, 2.3, -6), Vector3(8, 6, 0.7), game.mats.dark)
	L.box(root, "ossuary_south_partition", Vector3(26, 2.3, 5.5), Vector3(8, 6, 0.7), game.mats.dark)
	L.archway(root, "ossuary_north_arch", Vector3(26.5, -0.7, -6), 4.6, 3.5, 1.15, game.mats.stone, game.mats.brass)
	L.archway(root, "ossuary_south_arch", Vector3(18.4, -0.7, 5.5), 3.9, 3.5, 1.15, game.mats.stone, game.mats.brass)
	var shortcut := L.box(root, "shortcut_door", Vector3(9, 0, 17.85), Vector3(0.5, 3.7, 3.9), game.mats.iron, true) as StaticBody3D
	var shape := shortcut.get_child(1) as CollisionShape3D
	shape.position.y = 1.85
	var mesh := shortcut.get_child(0) as MeshInstance3D
	mesh.visible = false
	for i in 6:
		L.box(shortcut, "shortcut_bar", Vector3(0, 1.85, -1.65 + i * 0.66), Vector3(0.22, 3.7, 0.16), game.mats.iron, false)
	for y: float in [0.38, 2.8]:
		L.box(shortcut, "shortcut_brace", Vector3(0, y, 0), Vector3(0.25, 0.17, 3.9), game.mats.brass, false)
	if st.shortcut_open:
		shortcut.position.y = 4.6
		shortcut.collision_layer = 0
	game.shortcut_door = shortcut
	L.box(root, "shortcut_north_wall", Vector3(12.2, 2.0, 15.7), Vector3(6.8, 4, 0.65), game.mats.dark)
	L.box(root, "shortcut_south_wall", Vector3(14.3, 2.0, 20), Vector3(10, 4, 0.65), game.mats.dark)
	L.box(root, "ossuary_lever_altar", Vector3(22, -0.46, -13.1), Vector3(2.65, 0.48, 1.6), game.mats.brass)
	if not st.has_lever:
		game._pickup(Vector3(22, 0.32, -13.1), "iron_lever", "court_iron_lever")
		L.focus_light(root, Vector3(23.8, 3.7, -11.65), Vector3(22, 0.32, -13.1), AMBER, 2.65, 24.0)
	for z: float in [-15.5, -8.2, -1.5, 7.5, 13.5]:
		game._torch(Vector3(28.9, 2.0, z), "east_crypt")
		L.box(root, "carved_sarcophagus", Vector3(28.65, -0.18, z + 0.6), Vector3(1.6, 1.0, 2.5), game.mats.stone)
	L.box(root, "reliquary_wall", Vector3(27.8, 1.3, 8.9), Vector3(4.5, 4, 0.65), game.mats.dark)
	L.box(root, "reliquary_side", Vector3(25.4, 1.3, 12.9), Vector3(0.65, 4, 7.4), game.mats.dark)
	L.add_rotten_barricade(game, Vector3(27.8, 0.5, 16.7), "court_secret_bar_2", Vector3(4.1, 2.4, 0.45), true)
	L.focus_light(root, Vector3(29, 2.7, 18.35), Vector3(27.8, 0.8, 16.7), CRYPT_LIGHT, 1.55, 24.0)
	game._pickup(Vector3(27.8, -0.05, 13.8), "mana", "court_secret_mana_2")
	game._pickup(Vector3(27.8, -0.05, 11.5), "flask", "court_secret_flask_2")
	for pos: Vector3 in [Vector3(21.5, -0.7, -11), Vector3(25, -0.7, 2.8), Vector3(18.7, -0.7, 8.1)]:
		game._pot(pos, "court_crypt_urn_%d" % int(pos.z), "mana")
	game._enemy(Vector3(25.5, -0.6, -10), true, "court_stalker", false, "stalker")
	game._enemy(Vector3(22.5, -0.6, 2.0), false, "court_east_1", false, "shrieker")
	game._enemy(Vector3(20.7, -0.6, 10.1), false, "court_east_aco", false, "acolyte")
	game._inscription(Vector3(12.5, 0, -4.8), "THE OSSUARY KEEPER", "The keeper hunts by sound. Hurl an urn with [G] to draw it away from the iron lever.")

static func _basin(game, root: Node3D, st: Dictionary) -> void:
	L.slab(root, "basin_court_floor", Rect2(-10, -19.2, 20, 35.4), 0, game.mats.floor)
	L.box(root, "basin_east_wall", Vector3(9.8, 3, 7), Vector3(1, 6, 10), game.mats.dark)
	L.box(root, "basin_east_wall_north", Vector3(9.8, 3, -12.6), Vector3(1, 6, 12.4), game.mats.dark)
	L.box(root, "basin_west_north", Vector3(-10, 3, -16), Vector3(1, 6, 6), game.mats.dark)
	L.box(root, "basin_shortcut_partition", Vector3(9, 2.2, 13.7), Vector3(0.9, 4.4, 4.6), game.mats.dark)
	L.archway(root, "basin_south_arch", Vector3(0, 0, 15.7), 11.8, 6.5, 1.4, game.mats.stone, game.mats.brass)
	for x: float in [-7.2, 7.2]:
		for z: float in [-13.1, 3, 10.8]:
			L.cylinder(root, "basin_column", Vector3(x, 2.8, z), 0.74, 5.6, game.mats.stone, true, 12)
			game._torch(Vector3(x * 0.88, 2.6, z))
	for x: float in [-3.8, 3.8]:
		var pos := Vector3(x, 0, -5)
		var plate := L.box(root, "press_plate", pos + Vector3.UP * 0.06, Vector3(2.3, 0.12, 2.3), game.mats.brass, false)
		game.pressure_plates.append({"node": plate, "pos": pos, "pressed": false, "wet": x > 0})
		L.focus_light(root, Vector3(x * 1.6, 5.6, -7.2), pos, CRYPT_LIGHT if x > 0 else AMBER, 3.8, 24.0)
	var channel_pos := Vector3(3.8, 0, -5)
	var channel := L.box(root, "rushing_water_channel", channel_pos + Vector3.UP * 0.07, Vector3(3.3, 0.12, 6.2), game.mats.water, true, L.LAYER_TARGET)
	game.water_channels.append({"node": channel, "pos": channel_pos, "size": Vector3(3.3, 1.5, 6.2), "push_dir": Vector3.BACK, "frozen_timer": 0.0})
	L.add_pushable_block(game, Vector3(-3.8, 0.65, -0.4), "plinth_west")
	if st.cage_dropped:
		L.add_pushable_block(game, Vector3(3.8, 0.65, -9.5), "counterweight_east", Vector3(1.4, 1.2, 1.4), game.mats.iron)
	else:
		var cage := L.box(root, "suspended_cage", Vector3(3.8, 5.6, -9.5), Vector3(1.4, 1.2, 1.4), game.mats.iron, false)
		var rope := L.cylinder(root, "cage_rope", Vector3(3.8, 7.2, -9.5), 0.32, 2.6, game.mats.brass, true, 8, L.LAYER_TARGET)
		rope.set_meta("shootable_rope", true)
		rope.set_meta("cage", cage)
		game.shootable_targets.append(rope)
		game._light(Vector3(3.8, 6.6, -9.5), Color("e5b96d"), 1.75, 6)
	game._enemy(Vector3(0, 0.1, 10.6), false, "court_entry_shr", false, "shrieker")
	game._enemy(Vector3(-2, 0.1, 2.5), false, "court_shrieker_1", false, "shrieker")
	game._enemy(Vector3(5, 0.1, -12.6), true, "court_north_exec", false, "executioner")
	game._pickup(Vector3(4.8, 0.5, 12.6), "mana", "court_blue_1")
	game._inscription(Vector3(0, 0, -1), "THE COURT SEALS", "Insert the Iron Lever at the north gearbox. Drop the hanging cage with the Arbalest and use both weights on the seals. Freeze the current with [RMB] before weighting the east seal.")

static func _north_viaduct(game, root: Node3D, st: Dictionary) -> void:
	L.slab(root, "north_viaduct", Rect2(-5.6, -34.6, 11.2, 16), 0, game.mats.floor)
	L.box(root, "portcullis_wall_w", Vector3(-7.7, 4, -19), Vector3(5.8, 8, 1.25), game.mats.dark)
	L.box(root, "portcullis_wall_e", Vector3(7.7, 4, -19), Vector3(5.8, 8, 1.25), game.mats.dark)
	L.box(root, "portcullis_lintel", Vector3(0, 6.2, -19), Vector3(10.2, 2.8, 1.4), game.mats.dark)
	for x: float in [-5.45, 5.45]:
		L.box(root, "north_viaduct_parapet", Vector3(x, 1.25, -26.8), Vector3(0.8, 2.5, 15.6), game.mats.stone)
		L.cone(root, "bell_viaduct_pinnacle", Vector3(x, 5.3, -31.4), 1.2, 0.15, 4.8, game.mats.dark, 8)
		L.gothic_buttress(root, Vector3(x * 1.45, 0, -18.45), 8.25, 3.3, game.mats.stone, game.mats.dark)
		L.gothic_buttress(root, Vector3(x, 0, -34.25), 6.7, 2.3, game.mats.stone, game.mats.dark)
		L.box(root, "bell_tower_pier", Vector3(x * 0.75, 7.25, -36.3), Vector3(2.25, 14.5, 2.6), game.mats.dark, false)
		L.cone(root, "bell_tower_corner_spire", Vector3(x * 0.75, 16.05, -36.3), 1.45, 0.11, 3.9, game.mats.stone, 8)
	L.box(root, "viaduct_north_end", Vector3(0, 2.3, -34.5), Vector3(11.2, 4.6, 0.9), game.mats.dark)
	L.archway(root, "viaduct_portal_arch", Vector3(0, 0, -31.8), 7, 5.8, 1.5, game.mats.stone, game.mats.brass)
	L.box(root, "bell_chamber_cornice", Vector3(0, 14.35, -36.3), Vector3(10.7, 0.66, 3.75), game.mats.stone, false)
	L.box(root, "bell_chamber_sill", Vector3(0, 9.0, -36.3), Vector3(10.5, 0.8, 3.3), game.mats.stone, false)
	L.cone(root, "bell_tower_spire", Vector3(0, 18.3, -36.3), 4.0, 0.13, 7.4, game.mats.dark, 6)
	L.cone(root, "silhouette_bell", Vector3(0, 11.75, -36.3), 1.5, 0.61, 2.4, game.mats.iron, 12)
	L.hanging_chain(root, Vector3(0, 14.0, -36.3), Vector3(0, 12.9, -36.3), 0.17, game.mats.iron)
	L.focus_light(root, Vector3(0, 12.9, -37.6), Vector3(0, 11.6, -35), CRYPT_LIGHT, 4.4, 34.0)
	var shaft_source := Vector3(-5.2, 8.4, -18.1)
	var shaft_target := Vector3(-0.65, 0.4, -13.6)
	L.box(root, "portcullis_coping", Vector3(-5.2, 8.16, -18.95), Vector3(1.7, 0.55, 1.6), game.mats.stone, false)
	var mist := FogVolume.new()
	mist.name = "portcullis_mist"
	mist.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	mist.size = Vector3(5.2, 10.8, 5.2)
	mist.position = shaft_source.lerp(shaft_target, 0.54)
	mist.quaternion = Quaternion(Vector3.UP, shaft_target.direction_to(shaft_source))
	var mist_material := FogMaterial.new()
	mist_material.density = 0.048
	mist_material.albedo = Color("8497ae")
	mist.material = mist_material
	root.add_child(mist)
	L.focus_light(root, shaft_source, shaft_target, CRYPT_LIGHT, 7.05, 28.0, 4.2)
	L.focus_light(root, Vector3(-8.1, 4.7, -16.55), Vector3(-5.8, 0.95, -16.9), AMBER, 4.4, 27.0)
	L.focus_light(root, Vector3(3.1, 7.1, -29.2), Vector3(0, 0.5, -31.8), CRYPT_LIGHT, 5.4, 27.0, 0.55)
	game.switch_node = L.lever(root, "north_gearbox", Vector3(-5.8, 0, -16.9), game.mats.dark, game.mats.brass)
	game.switch_node.get_meta("lever_arm").visible = st.lever_inserted
	game._build_gate()
	L.add_trigger_volume(game, Vector3(0, 1.5, -23.8), Vector3(9, 3.5, 3.5), "court_exit_bell", "", "", "", "", "A deep bell tolls across the viaduct.", "bell")
	game._portal(Vector3(0, 0, -31.8), "ch2_tower", "ENTER THE BELL TOWER")
