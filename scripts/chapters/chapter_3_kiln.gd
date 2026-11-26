extends RefCounted

const L = preload("res://scripts/level_builder.gd")

const GATE_APPROACH := Vector3(0, 1.5, -36.4)
const COLOSSUS_SPAWN := Vector3(0, 0.1, -31.6)
const COLOSSUS_ID := "colossus"
const COLOSSUS_HP := 640
const KEY_PICKUP := Vector3(0, 1.2, -5)
const FURNACE_LIGHT := Color("ffa05a")
const AQUEDUCT_LIGHT := Color("73e9ff")

static func default_state() -> Dictionary:
	return {
		"trough_flooded": false, "aqueduct_powered": false, "dam_broken": false,
		"key_forged": false, "gauntlet_triggered": false, "dropped_cauldrons": [],
		"colossus_dead": false, "colossus_hp": COLOSSUS_HP, "great_gate_open": false,
	}

static func build(game, st: Dictionary) -> void:
	var root: Node3D = game.level_root
	_observation_deck(game, root)
	_crucible_hall(game, root, st)
	_aqueduct(game, root, st)
	_smeltery(game, root, st)
	_forecourt(game, root)
	_great_gate(game, root, st)
	if st.gauntlet_triggered:
		spawn_meltdown_encounter(game)
	game._scatter_particles("ember", 105, Rect2(-32, -41, 64, 67))

static func _observation_deck(game, root: Node3D) -> void:
	L.slab(root, "observation_landing", Rect2(-11.5, 13.8, 23, 13.2), 0, game.mats.basalt)
	L.box(root, "landing_south_wall", Vector3(0, 5.5, 27), Vector3(23, 11, 1), game.mats.basalt)
	for x: float in [-11.4, 11.4]:
		L.box(root, "observation_side_wall", Vector3(x, 5.5, 20.5), Vector3(1, 11, 13), game.mats.basalt)
		L.box(root, "observation_deck_rail", Vector3(x * 0.797, 0.75, 14.4), Vector3(4.8, 1.5, 0.55), game.mats.iron)
		game._torch(Vector3(x * 0.88, 2.8, 18.4))
		game._torch(Vector3(x * 0.88, 2.8, 24.4))
	for z: float in [15.5, 20.5, 25.5]:
		L.vaulted_rib(root, Vector3(0, 6.85, z), 22, 5.7, game.mats.basalt, game.mats.brass)
		L.hanging_chain_lamp(game, root, Vector3(0, 6.25, z), 5.8, FURNACE_LIGHT, 4.6, 12.0)
	L.focus_light(root, Vector3(-8.2, 5.55, 18.8), Vector3(-6.15, 1.2, 17.4), FURNACE_LIGHT, 3.75, 25.0)
	var lines: Array[String] = [
		"Caelen, I followed the old service stairs. Look at the molds. They poured the memories of the dead into the iron.",
		"Malcor was right about the Choir. If the Gate stays inverted, the city will join it. We need the Ashen Key before the furnace fails.",
		"Divert the aqueduct into the cooling trough. Then run the ore-cart through the dam to power the hoist.",
	]
	game._npc(Vector3(-6.15, 0, 17.4), "seraphina", "seraphina_kiln", "Archivist Seraphina", lines, -0.55)
	L.add_alchemical_font(game, Vector3(-6.5, 0, 22))
	L.add_checkpoint_zone(game, Vector3(0, 1.5, 20.6), Vector3(9, 3, 3.8), "kiln_landing", "Foundry Landing")
	game._portal(Vector3(7.4, 0, 24.8), "ch2_tower", "RETURN TO THE BELL TOWER")
	game._inscription(Vector3(6, 0, 18.2), "THE KILN OF ASH", "Frost followed by Thurible fire can fracture an Ash Sentinel. Shoot the brass chain to drop a slag cauldron on a foe.")

static func _crucible_hall(game, root: Node3D, st: Dictionary) -> void:
	L.slab(root, "crucible_procession", Rect2(-8.1, -20.8, 16.2, 34.8), 0, game.mats.basalt)
	var rising := Node3D.new()
	rising.name = "rising_slag"
	rising.position.y = -0.14 if st.gauntlet_triggered else -1.8
	rising.set_meta("lowered_y", -1.8)
	rising.set_meta("raised_y", -0.14)
	root.add_child(rising)
	game.rising_slag_node = rising
	for x: float in [-10, 10]:
		L.slab(root, "slag_river_bed", Rect2(x - 2, -20.8, 4, 34.8), -0.74, game.mats.basalt)
		L.box(root, "slag_river", Vector3(x, -0.58, -3.4), Vector3(3.65, 0.11, 34.8), game.mats.slag, false)
		L.box(rising, "rising_slag_river", Vector3(x, 0, -3.4), Vector3(3.75, 0.14, 34.8), game.mats.slag, false)
		game.slag_zones.append({"pos": Vector3(x, 0, -3.4), "half": Vector2(1.9, 17.35)})
		for z: float in [-14, -3, 10]:
			game._light(Vector3(x, 1.25, z), Color("ff642a"), 2.6, 10.5)
		for z: float in [-10, 4]:
			L.slab(root, "slag_bridge", Rect2(x - 2.55, z - 1.86, 5.1, 3.72), 0.29, game.mats.iron, 0.28)
			L.archway(root, "slag_bridge_mouth", Vector3(x * 1.165, 0.25, z), 4.6, 4.45, 0.9, game.mats.basalt, game.mats.brass, PI * 0.5)
	for z: float in [9, -2, -14]:
		L.vaulted_rib(root, Vector3(0, 6.65, z), 15.3, 5.2, game.mats.basalt, game.mats.iron)
		_gantry(game, root, Vector3(0, 7.05, z), 15.3, 2.3)
		for x: float in [-7.65, 7.65]:
			L.cylinder(root, "crucible_pier", Vector3(x, 3.2, z), 0.48, 6.4, game.mats.basalt, true, 12)
			L.box(root, "gantry_bearing", Vector3(x, 6.75, z), Vector3(1.14, 0.76, 0.98), game.mats.iron, false)
			game._torch(Vector3(x * 0.93, 2.75, z))
	for z: float in [9, -14]:
		L.hanging_chain_lamp(game, root, Vector3(0, 4.95, z), 1.55, FURNACE_LIGHT, 4.75, 11.5)
	for x: float in [-4.0, 4.0]:
		L.box(root, "longitudinal_hoist_rail", Vector3(x, 9.37, -2.5), Vector3(0.37, 0.44, 23.7), game.mats.iron, false)
		L.hanging_chain(root, Vector3(x, 9.18, -5), Vector3(x, 8.43, -5), 0.13, game.mats.iron)
	L.box(root, "west_cauldron_trolley", Vector3(-4, 9.19, 2), Vector3(0.75, 0.38, 0.86), game.mats.brass, false)
	L.box(root, "east_cauldron_trolley", Vector3(4, 9.19, -12), Vector3(0.75, 0.38, 0.86), game.mats.brass, false)
	L.box(root, "cooling_trough_frame", Vector3(0, 0.32, -5), Vector3(3.8, 0.64, 2.8), game.mats.dark)
	var water := L.box(root, "trough_water", Vector3(0, 0.66, -5), Vector3(3.35, 0.12, 2.35), game.mats.water, false)
	water.visible = st.trough_flooded
	game.trough_water = water
	var mold := L.box(root, "key_mold", Vector3(0, 2.4, -5), Vector3(1.2, 0.65, 0.8), game.mats.cinder, false)
	L.cylinder(mold, "mold_chain", Vector3(0, 2.85, 0), 0.105, 5.7, game.mats.iron, false, 8)
	L.box(root, "hoist_crossbeam", Vector3(0, 8.15, -5), Vector3(12.5, 0.55, 0.92), game.mats.iron, false)
	mold.visible = not st.key_forged
	game.key_mold = mold
	if st.key_forged and not game.has_ashen_key:
		game._pickup(KEY_PICKUP, "ashen_key", "kiln_ashen_key")
	game.hoist_lever = L.lever(root, "chain_hoist_lever", Vector3(3.55, 0, -5), game.mats.dark, game.mats.brass)
	L.focus_light(root, Vector3(5.65, 6.8, -3.5), Vector3(3.55, 0.95, -5), FURNACE_LIGHT, 5.6, 24.0)
	L.focus_light(root, Vector3(-3.8, 6.2, -6.55), Vector3(0, 0.66, -5), AQUEDUCT_LIGHT, 4.25, 22.0)
	_add_slag_cauldron(game, root, st, Vector3(-4.0, 6.4, 2.0), "cauldron_0")
	_add_slag_cauldron(game, root, st, Vector3(4.0, 6.4, -12.0), "cauldron_1")
	L.add_explosive_cask(game, Vector3(-4.3, 0, 5.5), "kiln_cask_center_w")
	L.add_explosive_cask(game, Vector3(4.5, 0, -11), "kiln_cask_center_e")
	game._enemy(Vector3(-3.8, 0.1, 2), true, "kiln_ash_1", false, "ash_sentinel")
	game._pickup(Vector3(4.7, 0.55, 12.8), "mana", "kiln_blue_1")
	game._pickup(Vector3(-4.7, 0.55, -15.1), "green", "kiln_green_1")

static func _aqueduct(game, root: Node3D, st: Dictionary) -> void:
	L.slab(root, "aqueduct_floor", Rect2(-32, -18, 20.15, 36), 0, game.mats.stone)
	L.box(root, "aqueduct_outer_wall", Vector3(-32, 4.75, 0), Vector3(1, 9.5, 36), game.mats.basalt)
	for z: float in [-18, 18]:
		L.box(root, "aqueduct_end_wall", Vector3(-22, 4.75, z), Vector3(20, 9.5, 1), game.mats.basalt)
	var pool := Vector3(-22.1, 0.04, -2.2)
	L.box(root, "aqueduct_pool", pool, Vector3(16.4, 0.08, 22.8), game.mats.water, false)
	L.add_wet_zone(game, pool, Vector2(8.2, 11.4))
	L.slab(root, "valve_platform", Rect2(-28, -13, 8.5, 9.45), 3.02, game.mats.dark)
	for z: float in [-11.8, -3.7, 7.6]:
		L.vaulted_rib(root, Vector3(-22, 5.85, z), 18, 5.05, game.mats.stone, game.mats.brass)
	L.hanging_chain_lamp(game, root, Vector3(-22, 5.25, 7.6), 4.95, AQUEDUCT_LIGHT, 4.3, 11.5)
	L.iron_grate_floor(root, Vector3(-19.05, 0.08, 9.5), Vector2(2.8, 1.9), game.mats.iron)
	L.box(root, "aqueduct_outlet_header", Vector3(-25.03, 6.92, 2.6), Vector3(0.46, 0.46, 7.1), game.mats.iron, false)
	var spouts: Array[Vector3] = [Vector3(-24.15, 0.47, 5.7), Vector3(-24.15, 1.23, 2.6), Vector3(-24.15, 1.99, -0.5)]
	for i in spouts.size():
		var pos := spouts[i]
		var spout := L.box(root, "water_spout_%d" % i, pos, Vector3(2.45, 0.5, 2.72), game.mats.water, true, L.LAYER_TARGET) as StaticBody3D
		var stream := L.cylinder(root, "water_stream_%d" % i, pos + Vector3(-0.88, 2.3, 0), 0.23, 4.6, game.mats.water, false, 10)
		spout.set_meta("water_spout", true)
		spout.set_meta("stream", stream)
		spout.set_meta("frozen_timer", 0.0)
		game.water_spouts.append(spout)
		game.shootable_targets.append(spout)
		game._light(pos + Vector3.UP * 0.85, Color("53c5e8"), 1.4, 5.5)
		var outlet := pos + Vector3(-0.88, 4.58, 0)
		var feed_height := 6.92 - outlet.y
		L.cylinder(root, "outlet_feed", outlet + Vector3.UP * (feed_height * 0.5), 0.2, feed_height, game.mats.iron, false, 10)
		L.cylinder(root, "outlet_flange", outlet, 0.35, 0.24, game.mats.brass, false, 10)
		L.focus_light(root, pos + Vector3(2.4, 4.65, 1.2), pos, AQUEDUCT_LIGHT, 3.75, 22.0, 0.8)
	var valve := Node3D.new()
	valve.name = "aqueduct_valve"
	valve.position = Vector3(-24.15, 3.02, -7.6)
	root.add_child(valve)
	L.cylinder(valve, "valve_post", Vector3(0, 0.65, 0), 0.25, 1.3, game.mats.iron, true, 10)
	var wheel := L.cylinder(valve, "valve_wheel", Vector3(0, 1.42, 0), 0.72, 0.16, game.mats.brass, false, 12)
	valve.set_meta("wheel", wheel)
	game.aqueduct_valve = valve
	var pump := L.add_voltaic_conduit(game, Vector3(-19.05, 1.25, 7.25), "conduit_aqueduct", "Aqueduct Pump")
	pump.set_meta("powered", st.aqueduct_powered)
	L.focus_light(root, Vector3(-16.75, 5.65, 7.9), pump.position, AQUEDUCT_LIGHT, 6.0, 23.0, 1.5)
	L.focus_light(root, Vector3(-26.2, 8.05, -9.75), valve.position + Vector3.UP * 1.35, AQUEDUCT_LIGHT, 4.9, 23.0, 0.62)
	game._inscription(Vector3(-21, 0, 8.4), "THE AQUEDUCT VALVE", "Power the pump with the Voltaic Fork [4]. Freeze the three falls with Frost [RMB] and climb them before they thaw.")
	L.box(root, "secret_cistern_west_wall", Vector3(-30.25, 2.1, 14.5), Vector3(1, 4.2, 6.8), game.mats.dark)
	L.box(root, "secret_cistern_east_wall", Vector3(-24.7, 2.1, 14.5), Vector3(1, 4.2, 6.8), game.mats.dark)
	L.add_rotten_barricade(game, Vector3(-27.48, 1.2, 11.4), "kiln_secret_bar_1", Vector3(4.85, 2.4, 0.45), true)
	L.focus_light(root, Vector3(-28.7, 4.75, 9.6), Vector3(-27.48, 1.2, 11.4), AQUEDUCT_LIGHT, 2.15, 21.0)
	game._pickup(Vector3(-27.5, 0.85, 16.2), "relic_oath", "relic_cinder_oath")
	game._pickup(Vector3(-26.2, 0.55, 15.1), "flask", "kiln_secret_flask_1")
	game._enemy(Vector3(-17.1, 0.1, 1.6), false, "kiln_aq_shr", false, "shrieker")
	game._enemy(Vector3(-21.8, 3.1, -10.6), false, "kiln_aq_aco_1", false, "acolyte")
	game._pickup(Vector3(-25.7, 0.55, 8.65), "mana", "kiln_aq_spout_mana")

static func _smeltery(game, root: Node3D, st: Dictionary) -> void:
	L.slab(root, "smeltery_rail_bed", Rect2(11.85, -18.5, 11.15, 36.5), 0, game.mats.basalt)
	L.slab(root, "smeltery_magma_bed", Rect2(23, -18.5, 9, 36.5), -0.65, game.mats.basalt)
	L.box(root, "smeltery_magma", Vector3(27.5, -0.49, -0.25), Vector3(9, 0.14, 36.5), game.mats.slag, false)
	game.slag_zones.append({"pos": Vector3(27.5, 0, 0), "half": Vector2(4.5, 18.25)})
	L.box(game.rising_slag_node, "smeltery_slag_rise", Vector3(27.5, 0, 0), Vector3(9, 0.14, 36), game.mats.slag, false)
	L.box(root, "smeltery_outer_wall", Vector3(32, 4.75, -0.25), Vector3(1, 9.5, 36.5), game.mats.basalt)
	for z: float in [-18.5, 18]:
		L.box(root, "smeltery_end_wall", Vector3(22, 4.75, z), Vector3(20, 9.5, 1.0), game.mats.basalt)
	L.slab(root, "smeltery_outer_catwalk", Rect2(28, -14.4, 3.6, 27.8), 0.45, game.mats.iron)
	for z: float in [-12.8, -4.7, 10.7]:
		_gantry(game, root, Vector3(23.45, 6.75, z), 16.1, 1.9)
		L.box(root, "smeltery_gantry_upright", Vector3(15.4, 3.4, z), Vector3(0.54, 6.8, 0.65), game.mats.iron, false)
		L.box(root, "smeltery_gantry_shoe", Vector3(15.4, 0.12, z), Vector3(0.92, 0.24, 0.96), game.mats.brass, false)
		L.hanging_chain_lamp(game, root, Vector3(26, 5.2, z), 1.1, FURNACE_LIGHT, 3.8, 11.0)
		_magma_vent(game, root, Vector3(31.46, 1.6, z))
	for z: float in [-10, 4, 13]:
		L.slab(root, "smeltery_crosswalk", Rect2(22.6, z - 1.55, 7.4, 3.1), 0.45, game.mats.iron)
		var deck_grate := L.iron_grate_floor(root, Vector3(26.35, 0.45, z), Vector2(2.42, 5.2), game.mats.iron)
		deck_grate.rotation.y = PI * 0.5
		game._light(Vector3(25, 1.3, z), Color("ff672e"), 2.2, 9)
	for x: float in [17.98, 19.82]:
		L.box(root, "ore_rail", Vector3(x, 0.06, -2.2), Vector3(0.12, 0.12, 20.7), game.mats.iron, false)
	var cart := RigidBody3D.new()
	cart.name = "heavy_ore_cart"
	cart.position = Vector3(18.9, 0.67, -9.4 if st.dam_broken else 5.5)
	cart.mass = 5.5
	cart.linear_damp = 0.12
	cart.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	var wheel_material := PhysicsMaterial.new()
	wheel_material.friction = 0.035
	wheel_material.rough = true
	cart.physics_material_override = wheel_material
	cart.axis_lock_linear_x = true
	cart.axis_lock_angular_x = true
	cart.axis_lock_angular_y = true
	cart.axis_lock_angular_z = true
	cart.collision_layer = L.LAYER_PUSHABLE
	cart.collision_mask = L.LAYER_WORLD | L.LAYER_ENEMY | L.LAYER_PUSHABLE | L.LAYER_PLAYER
	cart.continuous_cd = true
	cart.set_meta("ore_cart", true)
	L.box(cart, "cart_body", Vector3.ZERO, Vector3(1.98, 1.16, 2.35), game.mats.iron, false)
	L.box(cart, "cart_ore", Vector3(0, 0.58, 0), Vector3(1.65, 0.35, 1.95), game.mats.cinder, false)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.98, 1.16, 2.35)
	collider.shape = shape
	cart.add_child(collider)
	root.add_child(cart)
	game.ore_cart = cart
	game.pushable_blocks.append(cart)
	var dam := L.box(root, "slag_dam", Vector3(18.9, 1.35, -10.55), Vector3(4.0, 2.7, 1.25), game.mats.cinder) as StaticBody3D
	game.slag_dam = dam
	L.focus_light(root, Vector3(19.9, 6.45, -6.8), dam.position, FURNACE_LIGHT, 5.1, 25.0, 0.55)
	if st.dam_broken:
		dam.visible = false
		dam.collision_layer = 0
	L.box(root, "cart_rail_north_stop", Vector3(18.9, 0.72, -16.4), Vector3(3.2, 1.44, 0.9), game.mats.dark)
	L.box(root, "cart_rail_south_stop", Vector3(18.9, 0.5, 8.5), Vector3(3.2, 1, 0.88), game.mats.dark)
	game._inscription(Vector3(15, 0, 7.25), "THE SLAG DAM", "Use Repulse [Q] to send the ore-cart down the rails and break the dam. Its flow powers the crucible hoist.")
	L.add_explosive_cask(game, Vector3(16.1, 0, -2.5), "kiln_cask_smeltery")
	game._enemy(Vector3(21.8, 0.1, -3.5), true, "kiln_smelt_ash", false, "ash_sentinel")
	game._enemy(Vector3(29.9, 0.55, 8.5), true, "kiln_smelt_ash_east", false, "ash_sentinel")
	game._enemy(Vector3(21.1, 0.1, -13), false, "kiln_smelt_stalker", false, "stalker")
	game._pot(Vector3(15.2, 0, -12.8), "kiln_pot_3", "mana")
	game._pickup(Vector3(22.1, 0.55, 10.7), "flask", "kiln_flask_1")

static func _forecourt(game, root: Node3D) -> void:
	L.slab(root, "gate_forecourt", Rect2(-13, -38.6, 26, 18.1), 0, game.mats.basalt)
	for x: float in [-12.8, 12.8]:
		L.box(root, "forecourt_side_wall", Vector3(x, 4.7, -29.4), Vector3(1.1, 9.4, 18.4), game.mats.basalt)
		L.box(root, "forecourt_south_wall", Vector3(x * 0.76, 4.7, -20.55), Vector3(6.7, 9.4, 0.9), game.mats.basalt)
		for z: float in [-25.5, -33.9]:
			L.cylinder(root, "forecourt_pillar", Vector3(x * 0.55, 3.05, z), 0.85, 6.1, game.mats.basalt, true, 12)
			game._torch(Vector3(x * 0.64, 2.9, z))
		_monumental_brazier(game, root, Vector3(x * 0.82, 0, -27.1))
	L.archway(root, "forecourt_entry_arch", Vector3(0, 0, -21.1), 13.1, 7.1, 1.55, game.mats.basalt, game.mats.brass)
	L.vaulted_rib(root, Vector3(0, 6.3, -28.1), 25.4, 8.5, game.mats.basalt, game.mats.brass)
	_gantry(game, root, Vector3(0, 9.18, -28.75), 24.6, 1.8)
	L.box(root, "forecourt_hoist_trolley", Vector3(0, 9.16, -28.75), Vector3(1.15, 0.52, 0.82), game.mats.brass, false)
	game._rune_circle(Vector3(0, 0, -30.8), 6.0)
	L.add_explosive_cask(game, Vector3(8.7, 0, -30.8), "kiln_guardian_cask")
	game._pickup(Vector3(-9.5, 0.55, -30.8), "flask", "kiln_guardian_flask")

static func _great_gate(game, root: Node3D, st: Dictionary) -> void:
	L.slab(root, "ashen_threshold", Rect2(-7.1, -43, 14.2, 5), 0, game.mats.basalt)
	for x: float in [-9.7, 9.7]:
		L.box(root, "great_gate_jamb", Vector3(x, 5.15, -38), Vector3(6.45, 10.3, 1.9), game.mats.basalt)
		L.box(root, "threshold_side", Vector3(x * 0.731, 3, -40.5), Vector3(0.8, 6, 5.1), game.mats.basalt)
		L.gothic_buttress(root, Vector3(x * 1.21, 0, -37.05), 9.8, 2.4, game.mats.basalt, game.mats.iron)
		_monumental_brazier(game, root, Vector3(x * 1.04, 0, -34.0))
	L.focus_light(root, Vector3(0, 9.9, -33.5), Vector3(0, 2.4, -37.2), Color("f1c4ff"), 6.3, 28.0, 1.45)
	L.box(root, "great_gate_crown", Vector3(0, 9.1, -38), Vector3(14, 2.2, 1.9), game.mats.basalt)
	L.vaulted_rib(root, Vector3(0, 6.8, -36.85), 13, 5.2, game.mats.basalt, game.mats.brass)
	var left := L.box(root, "great_gate_left", Vector3(-3.3, 4, -38), Vector3(6.6, 8, 1), game.mats.iron) as StaticBody3D
	var right := L.box(root, "great_gate_right", Vector3(3.3, 4, -38), Vector3(6.6, 8, 1), game.mats.iron) as StaticBody3D
	for door: StaticBody3D in [left, right]:
		for y: float in [-2.8, 0, 2.8]:
			L.box(door, "gate_crossbrace", Vector3(0, y, 0.55), Vector3(6.3, 0.4, 0.17), game.mats.brass, false)
		for x: float in [-1.75, 0, 1.75]:
			L.box(door, "gate_rib", Vector3(x, 0, 0.6), Vector3(0.2, 8, 0.2), game.mats.dark, false)
	game.great_gate_left = left
	game.great_gate_right = right
	if st.great_gate_open:
		left.position.x = -8.5
		right.position.x = 8.5
		left.collision_layer = 0
		right.collision_layer = 0
	L.box(root, "ashen_threshold_backstop", Vector3(0, 4.7, -42.65), Vector3(14.0, 9.4, 0.55), game.mats.portal)
	game._light(Vector3(0, 3.65, -40.1), Color("ddc0ff"), 4.6, 12)
	L.add_trigger_volume(game, Vector3(0, 1.45, -35), Vector3(7.6, 3.2, 3.1), "hollow_choir", "", "hollow_choir", "THE HOLLOW CHOIR", "The voices behind the iron speak in unison. “Caelen, open the gate. Give us back our names.”", "The Hollow Choir speaks from beyond the Gate.")

static func _gantry(game, root: Node3D, pos: Vector3, span: float, rise: float) -> void:
	var truss := Node3D.new()
	truss.name = "foundry_gantry"
	truss.position = pos
	root.add_child(truss)
	for y: float in [0.0, rise]:
		L.box(truss, "truss_chord", Vector3(0, y, 0), Vector3(span + 0.32, 0.27, 0.48), game.mats.iron, false)
	var bay := span * 0.25
	for i in 4:
		var x := -span * 0.5 + bay * (float(i) + 0.5)
		var dy := rise if i % 2 == 0 else -rise
		var brace := L.box(truss, "angle_iron_brace", Vector3(x, rise * 0.5, 0), Vector3(Vector2(bay, rise).length(), 0.24, 0.33), game.mats.iron, false)
		brace.rotation.z = atan2(dy, bay)
	for x: float in [-span * 0.5, span * 0.5]:
		L.box(truss, "end_stanchion", Vector3(x, rise * 0.5, 0), Vector3(0.4, rise + 0.2, 0.55), game.mats.iron, false)
		for y: float in [0, rise]:
			L.box(truss, "gusset_plate", Vector3(x, y, 0.27), Vector3(0.67, 0.4, 0.08), game.mats.brass, false)

static func _magma_vent(game, root: Node3D, pos: Vector3) -> void:
	var vent := Node3D.new()
	vent.name = "magma_wall_vent"
	vent.position = pos
	root.add_child(vent)
	L.box(vent, "vent_frame", Vector3.ZERO, Vector3(0.34, 1.48, 2.98), game.mats.iron, false)
	L.box(vent, "glowing_magma", Vector3(-0.17, 0, 0), Vector3(0.09, 0.93, 2.5), game.mats.slag, false)
	for i in 7:
		L.box(vent, "vent_louver", Vector3(-0.25, 0, (i - 3) * 0.34), Vector3(0.12, 1.08, 0.12), game.mats.iron, false)
	L.focus_light(vent, Vector3(-0.36, 0.1, 0), Vector3(-3.9, -0.9, 0), Color("ff5926"), 4.7, 38.0, 0.5)

static func _monumental_brazier(game, root: Node3D, pos: Vector3) -> void:
	var brazier := Node3D.new()
	brazier.name = "processional_brazier"
	brazier.position = pos
	root.add_child(brazier)
	L.cylinder(brazier, "basalt_plinth", Vector3.UP * 0.24, 1.1, 0.48, game.mats.basalt, false, 8)
	L.cone(brazier, "pedestal", Vector3.UP * 1.65, 0.78, 0.49, 2.45, game.mats.basalt, 8)
	L.cylinder(brazier, "capital_ring", Vector3.UP * 2.8, 0.7, 0.23, game.mats.brass, false, 8)
	L.cone(brazier, "iron_fire_bowl", Vector3.UP * 3.18, 0.53, 1.16, 0.65, game.mats.iron, 12)
	L.cylinder(brazier, "brazier_rim", Vector3.UP * 3.51, 1.19, 0.16, game.mats.brass, false, 12)
	L.cylinder(brazier, "molten_coals", Vector3.UP * 3.59, 1.02, 0.13, game.mats.slag, false, 12)
	var flame := MeshInstance3D.new()
	flame.name = "brazier_flame"
	var quad := QuadMesh.new()
	quad.size = Vector2(2.35, 2.7)
	flame.mesh = quad
	flame.material_override = game.mats.flame
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.position.y = 4.74
	brazier.add_child(flame)
	var light: OmniLight3D = game._light(pos + Vector3.UP * 4.12, FURNACE_LIGHT, 6.1, 14.0)
	light.light_volumetric_fog_energy = 0.48

static func spawn_meltdown_encounter(game) -> void:
	var root: Node3D = game.level_root
	if root.has_meta("meltdown_spawned"):
		return
	root.set_meta("meltdown_spawned", true)
	var st := L.chapter_state(game)
	if not st.colossus_dead:
		game._enemy(COLOSSUS_SPAWN, true, COLOSSUS_ID, true, "colossus")
	_add_slag_cauldron(game, root, st, Vector3(0, 6.45, -28.75), "cauldron_colossus")
	game._enemy(Vector3(-6.5, 0.1, -27.2), true, "kiln_meltdown_ash", false, "ash_sentinel")
	game._enemy(Vector3(6.4, 0.1, -32.6), false, "kiln_meltdown_aco", false, "acolyte")

static func _add_slag_cauldron(game, root: Node3D, st: Dictionary, pos: Vector3, id: String) -> void:
	if st.dropped_cauldrons.has(id):
		return
	var pot := L.cylinder(root, id, pos, 1.05, 1.22, game.mats.iron, false, 14)
	L.cylinder(pot, "slag_inside_cauldron", Vector3.UP * 0.58, 0.92, 0.15, game.mats.slag, false, 14)
	var chain := L.cylinder(root, id + "_chain", pos + Vector3.UP * 1.64, 0.33, 2.2, game.mats.brass, true, 10, L.LAYER_TARGET)
	chain.set_meta("cauldron_chain", true)
	chain.set_meta("cauldron", pot)
	chain.set_meta("id", id)
	game.shootable_targets.append(chain)
	game._light(pos + Vector3.DOWN * 0.16, Color("ff7832"), 2.1, 7)
