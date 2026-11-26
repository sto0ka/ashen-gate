extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	for i in 5:
		await process_frame

	# --- CHAPTER I: THE SUNKEN COURT ---
	assert(game.chapter_id == "ch1_court" and game.story_flags.has("arrival"))
	assert(game.npc_nodes.size() >= 1) # Seraphina in-person behind gatehouse grate!
	# Speak with Seraphina
	game.player.position = Vector3(-3.0, 0.1, 32.0)
	game._use()
	# Flood Cistern & raise Buoyant Rafts
	game.player.position = game.cistern_sluice_lever.position + Vector3(0, 0.1, 1.0)
	game._use()
	assert(game.level_states["ch1_court"].cistern_raised)
	# Pick up Briar Arbalest + Heart of Vaelor Relic
	game.player.position = Vector3(-17.8, 0.9, -1.2)
	game._update_pickups(0.016)
	assert(game.has_arbalest)
	game.player.position = Vector3(-25.7, 3.1, -11.7)
	game._update_pickups(0.016)
	assert(game.max_hp == 135)
	# Pick up Iron Lever in East Ossuary (triggers ambush!)
	game.player.position = Vector3(22.0, 0.3, -13.1)
	game._update_pickups(0.016)
	assert(game.level_states["ch1_court"].has_lever and game.ambush_pending)
	# Insert lever at north gearbox
	game.player.position = game.switch_node.position + Vector3(0, 0.1, 1.5)
	game._use()
	assert(game.level_states["ch1_court"].lever_inserted and not game.gate_open)
	# Drop counterweight cage, freeze channel, press both plates
	for t in game.shootable_targets:
		if is_instance_valid(t) and t.get_meta("shootable_rope", false):
			game._hit_shootable_target(t, "arbalest")
			break
	assert(game.level_states["ch1_court"].cage_dropped and game.pushable_blocks.size() == 2)
	game._handle_frost_world_hit(game.water_channels[0].node, game.water_channels[0].pos)
	game.pushable_blocks[0].global_position = Vector3(-3.8, 0.65, -5.0)
	game.pushable_blocks[1].global_position = Vector3(3.8, 0.65, -5.0)
	game._update_puzzles(0.016)
	assert(game.gate_open)
	# Enter Chapter II portal
	game.player.position = Vector3(0, 0.1, -31.8)
	game._use()
	assert(game.chapter_id == "ch2_tower" and game.boss != null and game.wards.size() == 3)

	# --- CHAPTER II: THE BELL TOWER ---
	# Pick up Voltaic Fork & zap lift power conduit
	game.player.position = Vector3(-22.5, 1.1, -7.2)
	game._update_pickups(0.016)
	assert(game.has_voltaic)
	for t in game.shootable_targets:
		if is_instance_valid(t) and t.get_meta("id", "") == "conduit_lift_power":
			game._activate_voltaic_conduit(t)
			break
	assert(game.level_states["ch2_tower"].lift_powered)
	# Start Counterweight Lift -> jam -> shoot lift_latch -> arrive
	game.player.position = game.lift_call_lever.position + Vector3(0, 0.1, 1.0)
	game._use()
	assert(game.moving_lift.active)
	for i in 40:
		game._update_puzzles(0.1)
	assert(game.moving_lift.jammed)
	for t in game.shootable_targets:
		if is_instance_valid(t) and t.get_meta("lift_latch", false):
			game._hit_shootable_target(t, "arbalest")
			break
	for i in 40:
		game._update_puzzles(0.1)
	assert(game.level_states["ch2_tower"].lift_completed)
	# Ward 1: Freeze steam pipe & shatter ward_1
	for t in game.shootable_targets:
		if is_instance_valid(t) and t.get_meta("steam_pipe", false):
			game._handle_frost_world_hit(t, t.global_position)
			break
	for w in game.wards.duplicate():
		if w.get_meta("id") == "ward_1":
			game._shatter_ward(w)
	# Pick up Cinder Thurible & Ward 2 real PinJoint3D pendulum smash
	game.player.position = Vector3(20.4, 4.4, -7.55)
	game._update_pickups(0.016)
	assert(game.has_thurible)
	game._hit_tower_pendulum()
	game._hit_tower_pendulum()
	await create_timer(0.32).timeout
	assert(game.wards.size() == 1)
	# Ward 3: Harmonic Chimes (Crescent -> Crown -> Skull)
	for expected_idx in 3:
		for t in game.shootable_targets:
			if is_instance_valid(t) and t.get_meta("harmonic_bell", false) and t.get_meta("bell_idx") == expected_idx:
				game._hit_shootable_target(t, "arbalest")
				break
	assert(game.wards.is_empty())
	# Defeat Lord Malcor -> Phase II -> Death -> Drop shaft to Chapter III
	game.player.position = Vector3(0, 9.6, -34.0)
	game._damage_enemy(game.boss, 300)
	assert(game.boss_phase == 1)
	game._damage_enemy(game.boss, 300)
	assert(game.level_states["ch2_tower"].boss_dead)
	game.player.position = Vector3(0, 7.1, -42.0)
	game._use()
	assert(game.chapter_id == "ch3_kiln")

	# --- CHAPTER III: THE KILN OF ASH ---
	# Power aqueduct conduit, freeze 3 spouts, turn valve
	for t in game.shootable_targets:
		if is_instance_valid(t) and t.get_meta("id", "") == "conduit_aqueduct":
			game._activate_voltaic_conduit(t)
			break
	assert(game.level_states["ch3_kiln"].aqueduct_powered)
	for spout in game.water_spouts:
		game._handle_frost_world_hit(spout, spout.global_position)
		assert(spout.get_meta("frozen_timer") > 10.0)
	game.player.position = game.aqueduct_valve.position + Vector3(0, 0.1, 1.0)
	game._use()
	assert(game.level_states["ch3_kiln"].trough_flooded)
	# Smash slag dam with ore-cart
	game.ore_cart.global_position = Vector3(18.9, 0.7, -9.4)
	game._update_puzzles(0.016)
	assert(game.level_states["ch3_kiln"].dam_broken)
	# Pull hoist lever -> forge Ashen Key -> pick up -> spawns Crucible Colossus!
	game.player.position = game.hoist_lever.position + Vector3(0, 0.1, 1.0)
	game._use()
	assert(game.level_states["ch3_kiln"].key_forged)
	game.player.position = Vector3(0, 0.5, -5.0)
	game._update_pickups(0.016)
	assert(game.has_ashen_key and game.level_states["ch3_kiln"].gauntlet_triggered and is_instance_valid(game.boss) and game.boss.get_meta("kind") == "colossus")
	# Defeat Crucible Colossus guardian boss -> unseal Great Gate -> Act I Complete!
	game._damage_enemy(game.boss, 700)
	assert(game.level_states["ch3_kiln"].colossus_dead)
	game.player.position = Vector3(0, 0.5, -36.4)
	game._use()
	assert(game.won and game.level_states["ch3_kiln"].great_gate_open and game.story_flags.has("ending"))

	# Verify extensible checkpoint save/load roundtrip
	game._load_game(true)
	assert(game.chapter_id == "ch3_kiln" and game.has_ashen_key and game.has_voltaic)

	print("SMOKE PASS: Act I Full 3-Chapter Campaign, Set-Pieces, Crucible Colossus, Checkpoint Save/Load")
	if is_instance_valid(game.audio_3d):
		game.audio_3d.stop_all()
	for i in 6:
		await process_frame
	root.remove_child(game)
	game.free()
	game = null
	for i in 3:
		await process_frame
	quit()
