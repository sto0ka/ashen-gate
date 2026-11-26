extends SceneTree

const CombatSystems = preload("res://scripts/combat_systems.gd")
const PhysicsSandbox = preload("res://scripts/physics_sandbox.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	for i in 5:
		await process_frame

	# Verify 3D articulated weapon viewmodel built for all 4 modes
	for m in 4:
		game.mode = m
		game._build_weapon()
		assert(is_instance_valid(game.weapon_rig) and game.weapon_rig.get_child_count() > 0)

	# Verify Buoyant Raft rises when Cistern water rises
	assert(game.buoyant_rafts.size() == 2)
	var raft: RigidBody3D = game.buoyant_rafts[0]
	var raft_y0 := raft.global_position.y
	game.level_states["ch1_court"].cistern_raised = true
	for i in 40:
		game._update_puzzles(0.05)
		await physics_frame
	assert(raft.global_position.y > raft_y0 + 0.5)

	# Verify Executioner Shield Yank -> physical RigidBody3D shield!
	var exec: CharacterBody3D = null
	for e in game.enemies:
		if e.get_meta("kind") == "executioner":
			exec = e
			break
	assert(exec != null and exec.get_meta("has_shield", false))
	var yanked := CombatSystems.try_yank_shield(game, exec)
	assert(yanked != null and not exec.get_meta("has_shield", false))

	# Verify Timed Perfect Parry negates damage and restores +25 Blue Mana
	game.mana = 20
	game.hp = 100
	game._start_parry()
	game._hurt(25, exec.global_position, Color.RED, exec)
	assert(game.hp == 100 and game.mana == 45)

	# Verify Sound-Reactive Stalker detects hurled urn noise pings
	PhysicsSandbox.emit_noise(game.noise_events, Vector3(24.0, 0.0, -9.0), 20.0, 2.0)
	var ping := PhysicsSandbox.get_nearest_noise(game.noise_events, Vector3(25.5, 0.0, -10.0), 24.0)
	assert(not ping.is_empty())

	# Verify Grasp/Hurl Explosive Cask + Aether Dash
	var cask: RigidBody3D = null
	for b in game.breakables:
		if is_instance_valid(b) and b.get_meta("explosive_cask", false):
			cask = b
			break
	assert(cask != null)
	game.held_body = cask
	game._hurl_held()
	assert(game.held_body == null and cask.linear_velocity.length() > 15.0)
	game._smash_pot(cask)
	game._dash()
	assert(game.dash_time > 0.1 and game.dash_cooldown > 0.5)

	# Verify Thermal Shock (Frost + Cinder Thurible)
	var target_e: CharacterBody3D = game.enemies[0]
	var hp_before: int = target_e.get_meta("hp")
	game._apply_frost_to_enemy(target_e)
	game._cinder_aoe_burst(target_e.global_position)
	assert(not is_instance_valid(target_e) or not game.enemies.has(target_e) or int(target_e.get_meta("hp")) < hp_before - 100)

	# Verify Chapter III Ash Sentinel Frost immunity + Voltaic overload + Cauldron crush
	game._load_chapter("ch3_kiln", true)
	for i in 4:
		await process_frame
	var ash: CharacterBody3D = null
	for e in game.enemies:
		if e.get_meta("kind") == "ash_sentinel":
			ash = e
			break
	assert(ash != null)
	game._apply_frost_to_enemy(ash)
	assert(ash.get_meta("elemental").slow_multiplier() == 1.0)
	var ash_hp := int(ash.get_meta("hp"))
	var dir := (ash.global_position + Vector3(0, 1.0, 0) - (ash.global_position + Vector3(0, 1.0, 4.0))).normalized()
	var vres := CombatSystems.fire_voltaic_arc(game, ash.global_position + Vector3(0, 1.0, 4.0), dir, 12.0)
	assert(vres.hit_type == "enemy" and (not is_instance_valid(ash) or int(ash.get_meta("hp")) < ash_hp - 80))

	print("PHYSICS PASS: 3D viewmodels, Buoyancy, Shield Yank, Perfect Parry, Stalker Noise, Thermal Shock, Voltaic Overload, Cask & Dash")
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
