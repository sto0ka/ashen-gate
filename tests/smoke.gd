extends SceneTree

const Court = preload("res://scripts/chapters/chapter_1_court.gd")
const Kiln = preload("res://scripts/chapters/chapter_3_kiln.gd")
const SaveSystem = preload("res://scripts/save_system.gd")

# Advancing several minutes of story in one engine frame can exhaust Godot's
# mixer. Keep the cue bridge live with a sink for the accelerated story tests.
class TestAudio extends "res://scripts/audio_3d.gd":
	var speaker_cues := 0
	var mounted_chapter := ""

	func set_chapter(id: String, _acoustics: String = "", _crossfade_seconds: float = 0.60) -> void:
		mounted_chapter = id

	func play_2d(_sname: String, _pitch: float = 1.0, _vol_db: float = -6.0) -> void:
		pass

	func play_at(_parent: Node3D, _sname: String, _pos: Vector3, _pitch: float = 1.0, _max_dist: float = 30.0, _vol_db: float = -6.0) -> void:
		pass

	func play_speaker_cue(_cue_id: String, _parent: Node3D = null, _origin: Variant = null, _channel: String = "", _syllables: int = 8) -> void:
		speaker_cues += 1

	static func install(game) -> void:
		game.audio_3d.stop_all()
		game.audio_3d.queue_free()
		game.audio_3d = TestAudio.new()
		game.add_child(game.audio_3d)

var game
var started: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(35.0).timeout.connect(func() -> void: quit(1))
	game = preload("res://main.tscn").instantiate()
	game.ready.connect(func() -> void: game.set_physics_process(false))
	root.add_child(game)
	game.story_director.sequence_started.connect(func(id: String) -> void: started.append(id))
	assert(game.chapter_id == "ch1_court")
	assert(game.player.position.is_equal_approx(Vector3(0, 6.1, 61)))
	await _frames(4)
	TestAudio.install(game)
	assert(game.narrative.get_signal_connection_list("speaker_cue").size() == 1)
	assert(await _court())
	assert(await _tower())
	assert(await _kiln())
	assert(game.story_director.get_diagnostics().is_empty())
	assert(game.audio_3d.speaker_cues > 0 and game.audio_3d.mounted_chapter == "ch3_kiln")

	game.audio_3d.stop_all()
	await _frames(6)
	game.queue_free()
	await process_frame
	print("SMOKE PASS: Act I Full 3-Chapter Campaign, Set-Pieces, Crucible Colossus, Checkpoint Save/Load")
	quit()

func _court() -> bool:
	var st: Dictionary = game._state()
	_advance(1.0)
	assert(started.has("ch1_court/coldopen_arrival"))
	await _enter_volume(Vector3(0, 0.1, 47))
	assert(started.has("ch1_court/torin_hail"))
	await _enter_volume(Vector3(0, 0.1, 33.6))
	_advance(46.0)
	assert(st.fractured and st.outer_arch_collapsed and st.gatehouse_open)
	_defeat_enemies("court_coldopen")
	_advance(56.0)
	assert(st.coldopen_done)

	_take("court_arbalest")
	_take("relic_heart_vaelor")
	assert(game.has_arbalest and game.max_hp == 135)
	_read(Court.HESK_TITLE)
	assert(st.read_hesk_planks)

	game.player.global_position = game.cistern_sluice_lever.global_position + Vector3.UP
	game._use()
	assert(not st.cistern_raised)
	_unpick()
	assert(st.sluice_lock_unpicked and st.sluice_unpicked and not st.cistern_raised)
	game._use()
	_advance(3.0)
	assert(st.cistern_raised and game.cistern_water_node.position.y > 1.4)

	_take("court_iron_lever")
	_advance(3.0)
	assert(st.has_lever and started.count("ch1_court/ossuary_blackout") == 1 and not game.ambush_pending)
	assert(_enemy("court_ambush_exec") != null)
	game.player.global_position = game.switch_node.global_position + Vector3.UP
	_advance(0.05)
	game._use()
	assert(not st.lever_inserted)
	_unpick()
	game._use()
	assert(st.gearbox_unpicked and st.lever_inserted and not game.gate_open)

	game._hit_shootable_target(_target("shootable_rope"), "arbalest")
	assert(st.cage_dropped and game.pushable_blocks.size() == 2)
	var channel: Dictionary = game.water_channels[0]
	game._handle_frost_world_hit(channel.node, channel.pos)
	for i in 2:
		game.pushable_blocks[i].freeze = true
		game.pushable_blocks[i].global_position = game.pressure_plates[i].pos + Vector3.UP * 0.65
	for stage in range(1, 4):
		_advance(4.0)
		assert(st.siege_stage == stage, "Expected siege stage %d, got %d" % [stage, st.siege_stage])
		_defeat_enemies("court_siege_w")
		_advance(8.5)
	assert(st.gate_open and game.gate_open and game.gate.collision_layer == 0)
	await _enter_volume(Vector3(0, 0.1, -38))
	_advance(3.0)
	assert(st.keep_doors_open)
	await create_timer(2.1).timeout
	assert(await _cross(Vector3(0, 0.1, -42), Vector3(0, 0.1, -44.3), "ch2_tower", Vector3(0, 0.1, 33)))
	return true

func _tower() -> bool:
	var st: Dictionary = game._state()
	assert(game.boss == null and game.wards.size() == 3)
	await _enter_volume(Vector3(0, 0.1, 18))
	_advance(48.0)
	assert(st.malcor_balcony_done and st.story_world.nave_chandelier_fallen)
	_take("tower_voltaic")
	assert(game.has_voltaic)
	game._activate_voltaic_conduit(_by_id("conduit_lift_power"))
	game.player.global_position = game.lift_call_lever.global_position + Vector3.UP
	game._use()
	assert(st.lift_powered and game.moving_lift.active)
	_advance(4.0)
	assert(game.moving_lift.jammed and st.lift_ambush_done)
	game._hit_shootable_target(_target("lift_latch"), "arbalest")
	_advance(4.0)
	assert(st.lift_unjammed and st.lift_completed)

	var seal: StaticBody3D = game.level_root.get_meta("belfry_ward_seal")
	var steam := _target("steam_pipe")
	game._handle_frost_world_hit(steam, steam.global_position)
	for ward: StaticBody3D in game.wards:
		if ward.get_meta("id") == "ward_1":
			game._shatter_ward(ward)
			break
	assert(st.wards.has("ward_1") and seal.collision_layer != 0)
	_take("tower_thurible")
	assert(game.has_thurible)
	game._hit_tower_pendulum()
	game._hit_tower_pendulum()
	await create_timer(0.32).timeout
	assert(st.wards.has("ward_2") and game.wards.size() == 1)
	for index in 3:
		for target: Node3D in game.shootable_targets:
			if target.get_meta("bell_idx", -1) == index:
				game._hit_shootable_target(target, "arbalest")
				break
	assert(st.wards.has("ward_3") and game.wards.is_empty() and seal.collision_layer == 0)
	await _frames(6)
	_advance(42.0)
	assert(st.story_world.malcor_departed)
	await _enter_volume(Vector3(0, 9.6, -33.2))
	assert(is_instance_valid(game.boss))
	game._damage_enemy(game.boss, 300)
	_advance(0.5)
	assert(game.boss_phase == 1 and started.has("ch2_tower/warden_phase_two"))
	game._damage_enemy(game.boss, 300)
	assert(st.boss_dead and game.boss == null and not st.story_world.belfry_shaft_open)
	_advance(38.0)
	await _frames(3)
	assert(st.story_world.belfry_shaft_open and st.bell_fallen and game.belfry_floorboards.collision_layer == 0)
	assert(game.portal_nodes.is_empty())
	assert(await _cross(Vector3(0, 9.6, -42), Vector3(0, 8.1, -42), "ch3_kiln", Vector3(0, 6.1, 24.6)))
	return true

func _kiln() -> bool:
	var st: Dictionary = game._state()
	game._activate_voltaic_conduit(_by_id("conduit_aqueduct"))
	for spout: Node3D in game.water_spouts:
		game._handle_frost_world_hit(spout, spout.global_position)
		assert(spout.get_meta("frozen_timer") > 10.0)
	game.player.global_position = game.aqueduct_valve.global_position + Vector3.UP
	game._use()
	assert(st.aqueduct_powered and st.trough_flooded)
	_read("THE TITHE ROLL")
	assert(st.read_tithe_roll)
	await _enter_volume(Vector3(-18.6, 0.1, -6.0))
	_advance(4.0)
	assert(st.ilse_heard)

	var dormant: Dictionary = game.level_root.get_meta("kiln_dormant")
	assert(not dormant.is_empty() and not st.smelt_awake)
	game.player.global_position = Vector3(18.9, 0.7, 2.0)
	game.ore_cart.global_position = Vector3(18.9, 0.7, -8.0)
	game.ore_cart.linear_velocity = Vector3.FORWARD * 9.0
	for i in 12:
		await physics_frame
		game._update_puzzles(1.0 / 60.0)
		if st.dam_broken:
			break
	assert(st.dam_broken)
	_advance(2.0)
	assert(st.smelt_awake and started.has("ch3_kiln/seraphina_descends"))
	var sentinel := _enemy("kiln_smelt_ash")
	assert(is_instance_valid(sentinel))
	sentinel.global_position = game.ore_cart.global_position + Vector3.RIGHT
	var sentinel_hp := int(sentinel.get_meta("hp"))
	game.ore_cart.linear_velocity = Vector3.FORWARD * 6.0
	Kiln._cart_impacts(game)
	assert(int(sentinel.get_meta("hp")) == sentinel_hp)
	game.ore_cart.linear_velocity = Vector3.FORWARD * 7.0
	Kiln._cart_impacts(game)
	Kiln._cart_impacts(game)
	assert(int(sentinel.get_meta("hp")) == sentinel_hp - 120 and float(sentinel.get_meta("stagger")) >= 0.6)

	_defeat_enemies()
	game.player.global_position = game.hoist_lever.global_position + Vector3.UP
	game._use()
	assert(started.has(Kiln.SEQ_TEMPER))
	_advance(4.5)
	var hot_key: Node3D = game.level_root.get_meta("hot_key")
	assert(st.key_forged and hot_key.get_meta("too_hot"))
	game.player.global_position = hot_key.global_position
	game._update_pickups(0.0)
	assert(not game.has_ashen_key and game.labels.message.text.contains("TOO HOT TO HANDLE"))
	_advance(21.95)
	game._update_pickups(0.0)
	assert(not game.has_ashen_key)
	_advance(0.05)
	game._update_pickups(0.0)
	assert(game.has_ashen_key and st.gauntlet_triggered and is_instance_valid(game.boss))
	assert(game.boss.get_meta("display_name") == Kiln.COLOSSUS_NAME)
	assert(started.count(Kiln.SEQ_MELTDOWN) == 1)
	game._damage_enemy(game.boss, 320)
	assert(game.boss_phase == 1 and started.has(Kiln.SEQ_OVERDRIVE))
	_advance(1.0)
	game._damage_enemy(game.boss, 320)
	assert(st.colossus_dead and game.boss == null and started.has(Kiln.SEQ_FALLS))
	game.player.global_position = Kiln.GATE_APPROACH
	for turn in range(1, 4):
		game._use()
		assert(st.gate_turns == turn and st.great_gate_open == (turn == 3))
		_advance(2.55)
	_advance(25.0)
	assert(st.act_complete and game.won and game.story_flags.has("ending"))
	assert(game.narrative.is_act_banner_visible() and not game.ending_panel.visible)
	var saved := SaveSystem.read_save(true)
	assert(saved.level_states.ch3_kiln.checkpoint_id == "kiln_act_complete")
	game._load_game(true)
	assert(game.chapter_id == "ch3_kiln" and game.has_ashen_key and game.has_voltaic and game.won)
	assert(game._state().great_gate_open and game._state().gate_turns == 3 and not game.ending_panel.visible)
	return true

func _advance(seconds: float) -> void:
	# Advance story and puzzle clocks at a fixed cadence while AI and locomotion are off.
	for i in range(ceili(seconds / 0.05 - 0.00001)):
		game.elapsed += 0.05
		game.story_director.step_physics(0.05)
		game._update_puzzles(0.05)
		game.narrative.tick(0.05)

func _frames(count: int) -> void:
	for i in count:
		await physics_frame

func _enter_volume(pos: Vector3) -> void:
	game.player.global_position = pos
	await _frames(6)
	_advance(0.05)

func _cross(before: Vector3, after: Vector3, chapter: String, arrival: Vector3) -> bool:
	game.player.global_position = before
	_advance(0.8)
	var collision: KinematicCollision3D = game.player.move_and_collide(after - before)
	assert(collision == null, "Route aperture blocked by %s at %s" % [collision.get_collider(), collision.get_position()] if collision != null else "")
	_advance(0.05)
	assert(game.story_director.is_transitioning())
	game.story_director._process(0.21)
	await process_frame
	game.story_director._process(0.06)
	game.story_director._process(0.21)
	assert(game.chapter_id == chapter and game.player.global_position.is_equal_approx(arrival))
	assert(not game.story_director.is_transitioning())
	_advance(0.05)
	return true

func _unpick() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_E
	key.pressed = true
	game._input(key)
	for duration: float in [0.33, 0.33, 0.34]:
		game._step_unpick(duration)
		game._update_prompt()
		assert(game.labels.prompt.text.contains(["• ○ ○", "• • ○", "• • •"][game.unpick_tumblers - 1]))
	assert(game.unpick_tumblers == 3)
	key.pressed = false
	game._input(key)

func _take(id: String) -> void:
	for item: Dictionary in game.pickups:
		if item.id == id:
			game.player.global_position = item.node.global_position
			game._update_pickups(0.0)
			return

func _read(title: String) -> void:
	for inscription: Dictionary in game.inscriptions:
		if inscription.title == title:
			game.player.global_position = inscription.node.global_position
			game._use()
			return

func _target(meta: String) -> Node3D:
	for target: Node3D in game.shootable_targets:
		if is_instance_valid(target) and target.get_meta(meta, false):
			return target
	return null

func _by_id(id: String) -> Node3D:
	for target: Node3D in game.shootable_targets:
		if is_instance_valid(target) and target.get_meta("id", "") == id:
			return target
	return null

func _enemy(id: String) -> CharacterBody3D:
	for enemy: CharacterBody3D in game.enemies:
		if enemy.get_meta("id") == id:
			return enemy
	return null

func _defeat_enemies(prefix: String = "") -> void:
	for enemy: CharacterBody3D in game.enemies.duplicate():
		if str(enemy.get_meta("id")).begins_with(prefix):
			game._damage_enemy(enemy, 999)
