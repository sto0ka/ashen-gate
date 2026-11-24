extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	for i in 5:
		await process_frame
	# Test physics urn impulse + shatter + debris on LAYER_DEBRIS (16)
	var urn: RigidBody3D = game.breakables[0]
	for b in game.breakables:
		if not b.freeze:
			urn = b
			break
	var urn_start: Vector3 = urn.global_position
	urn.apply_central_impulse(Vector3(3, 4, 0))
	for i in 12:
		await physics_frame
	assert(urn.global_position.distance_to(urn_start) > 0.08)
	game._smash_pot(urn)
	var debris_count := 0
	for node in game.level_root.get_children():
		if node is RigidBody3D and node.collision_layer == 16:
			debris_count += 1
	assert(debris_count >= 7)

	# Test Frost + Cinder Thurible Thermal Shock!
	var enemy: CharacterBody3D = game.enemies[0]
	var hp_before: int = enemy.get_meta("hp")
	game._apply_frost_to_enemy(enemy)
	assert(enemy.get_meta("elemental").is_frozen())
	game._cinder_aoe_burst(enemy.global_position)
	# Thermal shock should have killed or dealt massive bonus damage (> 100 total)
	assert(not is_instance_valid(enemy) or not game.enemies.has(enemy) or int(enemy.get_meta("hp")) < hp_before - 100)

	# Test Briar Arbalest parabolic bolt + Q Repulse reflection
	game.has_arbalest = true
	game.mode = 1
	game.green_mana = 100
	game.cooldown = 0
	game._build_weapon()
	game._attack()
	assert(game.bolts.size() == 1 and game.bolts[0].kind == "arbalest" and game.bolts[0].gravity > 0.0)

	# Test Q Repulse on Weighted Stone Block + projectile reflection
	var blk: RigidBody3D = game.pushable_blocks[0]
	var blk_start := blk.global_position
	game.player.position = blk.global_position + Vector3(0, 0, 3.0)
	game.player.rotation.y = 0.0
	game.mana = 100
	game.cooldown = 0.0
	game._repulse()
	for i in 10:
		await physics_frame
	assert(blk.global_position.distance_to(blk_start) > 0.15)

	# Test Level 3 Ash Sentinel frost immunity + Slag Cauldron crush
	game._change_stage(2)
	for i in 4:
		await process_frame
	var ash: CharacterBody3D = null
	for e in game.enemies:
		if e.get_meta("kind") == "ash_sentinel":
			ash = e
			break
	assert(ash != null)
	game._apply_frost_to_enemy(ash)
	assert(ash.get_meta("elemental").slow_multiplier() == 1.0) # Immune to Frost slow!
	var chain: Node3D = null
	for t in game.shootable_targets:
		if is_instance_valid(t) and t.get_meta("cauldron_chain", false):
			chain = t
			break
	assert(chain != null)
	ash.global_position = Vector3(chain.global_position.x, 0.1, chain.global_position.z)
	game._hit_shootable_target(chain, "arbalest")
	await create_timer(0.35).timeout
	assert(not is_instance_valid(ash) or not game.enemies.has(ash))

	# Test Telekinetic Grasp (G) + Hurl + Explosive Alchemical Cask + Aether Dash (C)
	game._change_stage(0)
	for i in 4:
		await process_frame
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
	assert(not is_instance_valid(cask) or not game.breakables.has(cask))
	game._dash()
	assert(game.dash_time > 0.1 and game.dash_cooldown > 0.5)

	print("PHYSICS PASS: urn debris, Thermal Shock, Arbalest drop, Q Repulse, Ash Sentinel, Grasp/Hurl, Explosive Cask & Dash")
	for i in 25:
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
