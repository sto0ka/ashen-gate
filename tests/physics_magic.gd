extends SceneTree

const CombatSystems = preload("res://scripts/combat_systems.gd")
const LevelBuilder = preload("res://scripts/level_builder.gd")
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

	# The three real Ossuary ambush spawns start on the crypt floor and settle through EnemyAI.
	game.ambush_pending = true
	game.ambush_dark_timer = 0.01
	game._update_puzzles(0.016)
	var ambush: Array = game.enemies.filter(func(e: CharacterBody3D) -> bool: return str(e.get_meta("id")).begins_with("court_ambush_"))
	assert(ambush.size() == 3)
	for i in 8:
		await physics_frame
	for enemy: CharacterBody3D in ambush:
		assert(enemy.is_on_floor() and absf(enemy.global_position.y + 0.7) < 0.02, "%s grounded=%s y=%s" % [enemy.get_meta("id"), enemy.is_on_floor(), enemy.global_position.y])

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

	assert(game.active_fire_patches.size() > 0)
	assert(await _test_axe_and_fire_patch(game))
	assert(await _test_belfry_combat(game))

	# Verify Chapter III Ash Sentinel Frost immunity + Voltaic overload + Cauldron crush
	game._load_chapter("ch3_kiln", true)
	assert(game.active_fire_patches.is_empty())
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

	print("PHYSICS PASS: Enemy grounding, Axe combo, dual-hand casting, fire patches, Voltaic targets, Warden Aegis, and original physics checks")
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

func _test_axe_and_fire_patch(game) -> bool:
	game.set_physics_process(false)
	LevelBuilder.slab(game.level_root, "combat_test_floor", Rect2(90, -12, 20, 24), 0.0, game.mats.stone)
	game.player.position = Vector3(100, 0, 0)
	game.player.rotation = Vector3.ZERO
	game.head.rotation = Vector3.ZERO
	game.camera.transform = Transform3D.IDENTITY
	game._enemy(Vector3(100, 0, -2.6), true, "test_combo_executioner", false, "executioner")
	var primary: CharacterBody3D = game.enemies.back()
	primary.set_meta("hp", 400)
	game._enemy(Vector3(101.35, 0, -2.8), false, "test_cleave_secondary")
	var secondary: CharacterBody3D = game.enemies.back()
	secondary.set_meta("hp", 100)
	await physics_frame
	await physics_frame

	game.mode = 0
	game.axe_combo_timer = 0.0
	game.parry_window = 0.0
	game.offhand_cooldown = 0.0
	game.mana = 20
	for step in 3:
		game.cooldown = 0.0
		game._attack()
		assert(game.axe_combo_step == step)
		assert(is_equal_approx(game.cooldown, 0.50 if step == 2 else 0.38))
		if step == 0:
			var mainhand_time: float = game.cooldown
			game._frost_cast()
			assert(game.cooldown == mainhand_time and game.offhand_cooldown > 0.0 and game.mana == 10)
		game._animate_weapon_3d(0.3, Vector2.ZERO, false)
		assert(game.swing_contact_done)
		assert(game.mana == [16, 22, 34][step])
		assert(int(primary.get_meta("hp")) == [354, 308, 242][step])
		assert(int(secondary.get_meta("hp")) == (34 if step == 2 else 100))
	assert(not primary.get_meta("has_shield") and primary.get_meta("shield_hp") == 0.0)

	# A fresh shield breaks on the Counter-Cleave after a single parry.
	game._enemy(Vector3(108, 0, -2.6), true, "test_counter_executioner", false, "executioner")
	var counter: CharacterBody3D = game.enemies.back()
	game.player.position.x = 108.0
	await physics_frame
	await physics_frame
	game.parry_cooldown = 0.0
	game._start_parry()
	game._hurt(20, counter.global_position, Color.RED, counter)
	assert(counter.get_meta("shield_hp") == 40.0)
	game.axe_combo_step = 0
	game._axe_contact()
	assert(not counter.get_meta("has_shield") and counter.get_meta("hp") == 47)

	var patch_count: int = game.active_fire_patches.size()
	game._cinder_aoe_burst(primary.global_position)
	assert(game.active_fire_patches.size() == patch_count + 1)
	var hp_after_blast: int = primary.get_meta("hp")
	game._update_fire_patches(0.59)
	assert(primary.get_meta("hp") == hp_after_blast)
	game._update_fire_patches(0.02)
	assert(primary.get_meta("hp") == hp_after_blast - 14)
	assert(primary.get_meta("elemental").is_burning())
	game._update_fire_patches(3.4)
	assert(game.active_fire_patches.is_empty())
	game._cinder_aoe_burst(primary.global_position)
	return true

func _test_belfry_combat(game) -> bool:
	game._load_chapter("ch2_tower", true)
	assert(game.active_fire_patches.is_empty())
	var seal: StaticBody3D = game.level_root.get_meta("belfry_ward_seal")
	assert(seal.collision_layer != 0 and game.wards.size() == 3)
	assert(game.boss == null)
	var st: Dictionary = game._state()
	st.nave_woken = true
	game._enemy(Vector3(0, 6, -26.8), true, "tower_choir_exec", false, "executioner")
	var exec: CharacterBody3D
	for enemy in game.enemies:
		if enemy.get_meta("kind") == "executioner":
			exec = enemy
			break
	assert(is_instance_valid(exec))
	var bell: Node3D
	for target in game.shootable_targets:
		if target.get_meta("bell_idx", -1) == 0:
			bell = target
			break
	assert(is_instance_valid(bell))

	# Separate actual chapter colliders so each ray has an unobstructed target.
	exec.global_position = Vector3(95, 0, 0)
	bell.global_position = Vector3(105, 1, 0)
	var wards: Array = game.wards.duplicate()
	for i in wards.size():
		wards[i].global_position = Vector3(112.0 + i * 5.0, 1.0, 0)
	await physics_frame
	await physics_frame

	assert(_fire_voltaic_at(game, exec.global_position + Vector3.UP).hit_type == "enemy")
	assert(not exec.get_meta("has_shield") and exec.get_meta("shield_hp") == 0.0)
	assert(_fire_voltaic_at(game, bell.global_position).hit_type == "target")
	assert(game.bell_sequence_step == 1)

	for ward: StaticBody3D in wards:
		var ward_id: String = ward.get_meta("id")
		assert(_fire_voltaic_at(game, ward.global_position).hit_type == "ward")
		assert(not seal.get_meta("sigil_nodes").has(ward_id))
	assert(game.wards.is_empty() and seal.collision_layer == 0)
	assert(not game.labels.ward_status.visible)
	assert(game.npc_nodes.all(func(npc: Dictionary) -> bool: return npc.id != "malcor_choir"))

	# At this point the combat fixture has cleared the wards. Advance the actual
	# Belfry awakening commit after Malcor's departure.
	st.story_world.malcor_departed = true
	assert(game.story_director.start_sequence("ch2_tower/belfry_awakens"))
	game.story_director.step_physics(0.016)
	var warden: CharacterBody3D = game.boss
	assert(is_instance_valid(warden) and warden.get_meta("aegis_hp") == CombatSystems.AEGIS_HP)
	warden.global_position = Vector3(135, 0, 0)
	await physics_frame
	await physics_frame
	assert(_fire_voltaic_at(game, warden.global_position + Vector3.UP).hit_type == "enemy")
	assert(warden.get_meta("aegis_hp") == 100.0)
	var hp_before_reflect: int = warden.get_meta("hp")
	var impact := warden.global_position + Vector3.UP
	var orb: Node3D = game._spell_orb(impact, "reflected")
	var reflected := {"kind": "reflected", "node": orb}
	var hit := {"collider": warden, "position": impact}
	game._resolve_bolt_hit(reflected, hit)
	assert(warden.get_meta("aegis_hp") == 10.0 and warden.get_meta("stagger") >= 3.0)
	assert(warden.get_meta("hp") == hp_before_reflect - roundi(65.0 * CombatSystems.AEGIS_BLEED_THROUGH))

	game.parry_cooldown = 0.0
	game._start_parry()
	game._hurt(25, warden.global_position, Color.RED, warden)
	assert(warden.get_meta("aegis_hp") == 0.0 and warden.get_meta("aegis_exposed_timer") > 0.0)
	var exposed_hp: int = warden.get_meta("hp")
	game._resolve_bolt_hit(reflected, hit)
	assert(warden.get_meta("hp") == exposed_hp - roundi(65.0 * CombatSystems.AEGIS_EXPOSED_MULTIPLIER))
	assert(game.labels.aegis.text.contains("EXPOSED"))
	orb.queue_free()
	game.set_physics_process(true)
	return true

func _fire_voltaic_at(game, target: Vector3) -> Dictionary:
	return CombatSystems.fire_voltaic_arc(game, target + Vector3.BACK * 3.0, Vector3.FORWARD, 6.0)
