extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	for i in 5:
		await process_frame
	# --- LEVEL 1: THE SUNKEN COURT ---
	assert(game.stage == 0 and game.story_flags.has("arrival"))
	# Pick up Briar Arbalest in West Arcade
	game.player.position = Vector3(-16.5, 0.5, -1.0)
	game._update_pickups(0.016)
	assert(game.has_arbalest)
	# Pick up Iron Lever in East Crypts (triggers ambush!)
	game.player.position = Vector3(17.5, 0.5, -2.0)
	game._update_pickups(0.016)
	assert(game.level_states[0].has_lever and game.ambush_pending)
	# Insert Iron Lever in north gearbox
	game.player.position = game.switch_node.position + Vector3(0, 0.1, 1.5)
	game._use()
	assert(game.level_states[0].lever_inserted and not game.gate_open)
	# Shoot counterweight cage rope
	var rope_target: Node3D = null
	for t in game.shootable_targets:
		if is_instance_valid(t) and t.get_meta("shootable_rope", false):
			rope_target = t
			break
	assert(rope_target != null)
	game._hit_shootable_target(rope_target, "arbalest")
	assert(game.level_states[0].cage_dropped and game.pushable_blocks.size() == 2)
	# Freeze rushing water channel and place both blocks on the pressure plates
	game._handle_frost_world_hit(game.water_channels[0].node, game.water_channels[0].pos)
	assert(game.water_channels[0].frozen_timer > 10.0)
	game.pushable_blocks[0].global_position = Vector3(-3.8, 0.65, -5.0)
	game.pushable_blocks[1].global_position = Vector3(3.8, 0.65, -5.0)
	game._update_puzzles(0.016)
	assert(game.gate_open and game.level_states[0].gate_open)
	# Enter Bell Tower portal
	game.player.position = Vector3(0, 0.1, -28.0)
	game._use()
	assert(game.stage == 1 and game.boss != null and game.wards.size() == 3)

	# --- LEVEL 2: THE BELL TOWER (REDESIGNED) ---
	# Ward 1: Freeze steam pipe in Clockwork Gallery to jam cogwheel, then shatter ward_1
	var pipe: Node3D = null
	for t in game.shootable_targets:
		if is_instance_valid(t) and t.get_meta("steam_pipe", false):
			pipe = t
			break
	assert(pipe != null)
	game._handle_frost_world_hit(pipe, pipe.global_position)
	assert(game.level_states[1].gear_frozen)
	for w in game.wards.duplicate():
		if w.get_meta("id") == "ward_1":
			game._shatter_ward(w)
	assert(game.wards.size() == 2)
	# Pick up Cinder Thurible on East Pendulum Balcony
	game.player.position = Vector3(20.0, 4.2, -7.8)
	game._update_pickups(0.016)
	assert(game.has_thurible)
	# Ward 2: Pendulum Physics (2 Repulse hits -> shatters cracked wall + ward_2)
	game._hit_tower_pendulum()
	game._hit_tower_pendulum()
	await create_timer(0.35).timeout
	assert(game.wards.size() == 1)
	# Ward 3: Acoustic Sequence in Choir Loft (Crescent 0 -> Crown 1 -> Skull 2)
	for expected_idx in 3:
		for t in game.shootable_targets:
			if is_instance_valid(t) and t.get_meta("harmonic_bell", false) and t.get_meta("bell_idx") == expected_idx:
				game._hit_shootable_target(t, "arbalest")
				break
	assert(game.wards.is_empty())
	# Enter Belfry Sanctum and defeat Bell Warden -> opens drop-shaft portal to Kiln of Ash
	game.player.position = Vector3(0, 7.1, -30.0)
	game._damage_enemy(game.boss, 300)
	game._update_enemies(0.016)
	assert(game.boss_phase == 1)
	game._damage_enemy(game.boss, 300)
	assert(game.level_states[1].boss_dead)
	# Descend drop-shaft portal to Level 3
	game.player.position = Vector3(0, 7.1, -38.0)
	game._use()
	assert(game.stage == 2)

	# --- LEVEL 3: THE KILN OF ASH ---
	for spout in game.water_spouts:
		game._handle_frost_world_hit(spout, spout.global_position)
		assert(spout.get_meta("frozen_timer") > 10.0)
	game.player.position = game.aqueduct_valve.position + Vector3(0, 0.1, 1.0)
	game._use()
	assert(game.level_states[2].trough_flooded)
	game.ore_cart.global_position = Vector3(18.9, 0.85, -9.5)
	game._update_puzzles(0.016)
	assert(game.level_states[2].dam_broken)
	game.player.position = game.hoist_lever.position + Vector3(0, 0.1, 1.0)
	game._use()
	assert(game.level_states[2].key_forged)
	game.player.position = Vector3(0, 0.5, -5.0)
	game._update_pickups(0.016)
	assert(game.has_ashen_key and game.level_states[2].gauntlet_triggered)
	game.player.position = Vector3(0, 0.5, -19.5)
	game._use()
	assert(game.won and game.level_states[2].great_gate_open and game.story_flags.has("ending"))

	print("SMOKE PASS: Level 1 (Sunken Court), Level 2 (Bell Tower), Level 3 (Kiln of Ash), Act I Complete")
	for i in 30:
		await process_frame
	for audio in game.sounds.values():
		audio.stop()
	for i in 5:
		await process_frame
	root.remove_child(game)
	game.free()
	game = null
	for i in 3:
		await process_frame
	quit()
