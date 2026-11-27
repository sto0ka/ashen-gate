extends SceneTree

const Kiln = preload("res://scripts/chapters/chapter_3_kiln.gd")
const TestAudio = preload("res://tests/smoke.gd").TestAudio
const Registry = preload("res://scripts/chapters/chapter_registry.gd")
const SaveSystem = preload("res://scripts/save_system.gd")

var game
var lines: Array[String] = []
var sequences: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(35.0).timeout.connect(func() -> void: quit(1))
	game = preload("res://main.tscn").instantiate()
	game.ready.connect(func() -> void: game.set_physics_process(false))
	root.add_child(game)
	game.narrative.line_started.connect(func(id: String) -> void: lines.append(id))
	game.story_director.sequence_started.connect(func(id: String) -> void: sequences.append(id))
	await _frames(3)
	TestAudio.install(game)

	assert(_camera_and_input())
	assert(await _safe_rockfall())
	assert(_siege_hold())
	assert(await _routes_and_bell_drop())
	assert(_tempering_and_gate())
	assert(_confession_branches())
	assert(_bark_discipline())
	assert(game.story_director.get_diagnostics().is_empty())

	game.audio_3d.stop_all()
	await _frames(6)
	game.free()
	game = null
	await _frames(3)
	print("STORY BEATS PASS: 9/9 Act I acceptance checks")
	quit()

func _camera_and_input() -> bool:
	# A running fracture may shake the view, but player input still controls its pose.
	game.player.position = Vector3(0, 0.1, 33.6)
	assert(game.story_director.start_sequence("ch1_court/gatehouse_fracture"))
	var original_pose: Transform3D = game.camera.global_transform
	game.story_director.step_physics(0.1)
	assert(game.camera.global_transform.is_equal_approx(original_pose))
	game.add_story_shake(0.5)
	assert(is_equal_approx(game.story_shake, 0.12))
	game.hitstop_time = 0.03
	var clock: float = game.story_director._clock
	game._physics_process(0.02)
	assert(game.story_director._clock > clock)
	game.hitstop_time = 0.0

	var dash := InputEventKey.new()
	dash.keycode = KEY_C
	dash.pressed = true
	game._input(dash)
	assert(game.dash_time > 0.0)
	# The headless display cannot capture the mouse. Exercise the same attack entry point.
	game._attack()
	assert(game.swing_time > 0.0)
	var before: Vector3 = game.player.global_position
	game._physics_process(1.0 / 60.0)
	assert(game.player.global_position.z < before.z and game.camera.current)
	assert(game.camera.position.length() <= 0.120001 and game.camera.rotation.is_zero_approx())
	assert(game.camera.get_parent() == game.head and game.head.get_parent() == game.player)
	return true

func _safe_rockfall() -> bool:
	var rubble: Node3D = game.story_director._resolve_node("gatehouse_outer_rubble")
	game.player.global_position = Vector3(0, 0.1, 37.1)
	assert(game.story_director._player_overlaps_node(rubble))
	assert(game.story_director.start_sequence("ch1_court/outer_arch_collapse"))
	_advance(0.15)
	await _frames(2)
	assert(game._state().story_world.gatehouse_arch_collapsed)
	assert(not _collision_enabled(rubble))
	game.player.global_position = Vector3(0, 0.1, 33.6)
	_advance(0.15)
	await _frames(2)
	assert(_collision_enabled(rubble))
	return true

func _siege_hold() -> bool:
	var st: Dictionary = game._state()
	st.has_lever = true
	st.lever_inserted = true
	for plate: Dictionary in game.pressure_plates:
		plate.pressed = true
	# The authored siege sees weighted plates but refuses to begin with a dry ram.
	var court := preload("res://scripts/chapters/chapter_1_court.gd")
	court.step(game, 0.05)
	assert(not sequences.has("ch1_court/north_portcullis") and not game.gate_open)
	st.cistern_raised = true
	court.step(game, 0.05)
	_advance(3.2)
	court.step(game, 0.4)
	assert(st.siege_stage == 1 and st.portcullis_height > 0.0 and not st.gate_open)
	var held: float = st.portcullis_height
	game.pressure_plates[1].pressed = false
	court.step(game, 0.8)
	assert(is_equal_approx(st.portcullis_height, held) and is_equal_approx(game.gate.position.y, held))
	game.pressure_plates[1].pressed = true
	court.step(game, 0.4)
	assert(st.portcullis_height > held)
	return true

func _routes_and_bell_drop() -> bool:
	game._state().gate_open = true
	assert(game.story_director.start_sequence("ch1_court/keep_doors"))
	_advance(0.05)
	await create_timer(2.1).timeout
	assert(await _cross("court_to_tower", Vector3(0, 0.1, -42), Vector3(0, 0.1, -44.3), "ch2_tower", "tower_from_court", Vector3(0, 0.1, 33), 0.0))
	assert(await _cross("tower_to_court", Vector3(0, 0.1, 33), Vector3(0, 0.1, 35.7), "ch1_court", "court_from_tower", Vector3(0, 0.1, -30), PI))
	assert(game.narrative.chapter_timer == 0.0)
	assert(await _cross("court_to_tower", Vector3(0, 0.1, -42), Vector3(0, 0.1, -44.3), "ch2_tower", "tower_from_court", Vector3(0, 0.1, 33), 0.0))
	assert(game.narrative.chapter_timer == 0.0)

	var st: Dictionary = game._state()
	st.boss_dead = true
	assert(game.story_director.get_exit_position("tower_to_kiln") == null)
	game.player.global_position = Vector3(0, 9.6, -42)
	assert(game.story_director.start_sequence("ch2_tower/belfry_shaft"))
	_advance(34.0)
	var falling_bell: RigidBody3D = game.level_root.get_node_or_null("story_falling_great_bell")
	assert(is_instance_valid(falling_bell))
	assert((falling_bell.collision_mask & game.player.collision_layer) == 0)
	assert((game.player.collision_mask & falling_bell.collision_layer) == 0)
	_advance(3.0)
	await _frames(2)
	assert(st.bell_fallen and st.story_world.belfry_shaft_open and not _collision_enabled(game.belfry_floorboards))
	assert(await _cross("tower_to_kiln", Vector3(0, 9.6, -42), Vector3(0, 8.1, -42), "ch3_kiln", "kiln_from_tower", Vector3(0, 6.1, 24.6), 0.0))
	assert(await _cross("kiln_to_tower", Vector3(7.4, 7.9, 30.4), Vector3(7.4, 7.9, 32.1), "ch2_tower", "tower_from_kiln", Vector3(-2.15, 7.08, -44.2), PI))
	return true

func _cross(id: String, before: Vector3, after: Vector3, chapter: String, marker: String, arrival: Vector3, yaw: float) -> bool:
	var director: Node = game.story_director
	assert(director.get_exit_position(id) is Vector3)
	game.player.global_position = before
	_advance(0.8)
	var collision: KinematicCollision3D = game.player.move_and_collide(after - before)
	assert(collision == null, "Route aperture blocked by %s at %s" % [collision.get_collider(), collision.get_position()] if collision != null else "")
	_advance(0.05)
	assert(director.is_transitioning(), id)
	director._process(0.21)
	await process_frame
	director._process(0.06)
	director._process(0.21)
	assert(not director.is_transitioning() and game.chapter_id == chapter, id)
	assert(game.player.global_position.is_equal_approx(arrival), id)
	assert(absf(angle_difference(game.player.rotation.y, yaw)) < 0.00001, id)
	assert(game.player.velocity.is_zero_approx() and game.dash_time == 0.0 and game.jump_buffer == 0.0)
	var ray := PhysicsRayQueryParameters3D.create(arrival + Vector3.UP * 0.15, arrival - Vector3.UP * 0.25, game.LAYER_WORLD)
	await _frames(2)
	assert(not game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), id + " arrival floor")
	for route: Dictionary in director._routes.values():
		assert(not director._player_inside_area(route.area), id + " overlaps " + str(route.id))
	for volume: Dictionary in director._volumes:
		assert(not director._player_inside_area(volume.area), id + " overlaps " + str(volume.trigger_id))
	_advance(1.0)
	assert(not director.is_transitioning())
	var saved := SaveSystem.read_save(true)
	assert(saved.chapter_id == chapter and saved.level_states[chapter].checkpoint_id == "arrival/%s/%s" % [chapter, marker])
	return true

func _tempering_and_gate() -> bool:
	_mount_kiln(false, false, false)
	game.player.global_position = game.hoist_lever.global_position + Vector3.UP
	game._use()
	_advance(4.5)
	var key: Node3D = game.level_root.get_meta("hot_key")
	assert(key.get_meta("too_hot"))
	game.player.global_position = key.global_position
	_advance(21.95)
	game._update_pickups(0.0)
	assert(not game.has_ashen_key)
	_advance(0.05)
	game._update_pickups(0.0)
	game._update_pickups(0.0)
	assert(game.has_ashen_key and sequences.count(Kiln.SEQ_MELTDOWN) == 1)
	assert(is_instance_valid(game.boss))
	game.player.global_position = Kiln.GATE_APPROACH
	game._use()
	assert(game._state().gate_turns == 0)
	game._damage_enemy(game.boss, 640)
	var st: Dictionary = game._state()
	for turn in range(1, 4):
		game._use()
		assert(st.gate_turns == turn and st.great_gate_open == (turn == 3))
		assert(not st.act_complete and not game.won)
		if turn == 3:
			break
		game._use()
		_advance(2.45)
		game._use()
		assert(st.gate_turns == turn)
		_advance(0.051)
	_advance(22.5)
	assert(st.act_complete and game.won and not game.ending_panel.visible)
	assert(game.narrative.is_act_banner_visible())
	var saved := SaveSystem.read_save(true)
	assert(saved.level_states.ch3_kiln.act_complete and saved.level_states.ch3_kiln.checkpoint_id == "kiln_act_complete")
	var dash := InputEventKey.new()
	dash.keycode = KEY_C
	dash.pressed = true
	game._input(dash)
	var before: Vector3 = game.player.global_position
	game._physics_process(1.0 / 60.0)
	assert(game.player.global_position.z < before.z)
	game.player.global_position = Vector3(0, 0.1, -36.4)
	assert(game.player.move_and_collide(Vector3.FORWARD * 5.0) == null)
	assert(game.player.global_position.z < -41.0)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	assert(game.pause_menu.visible and paused and not game.narrative.is_gameplay_hud_visible())
	root.push_input(escape)
	assert(not game.pause_menu.visible and not paused and game.narrative.is_gameplay_hud_visible())
	return true

func _confession_branches() -> bool:
	for flags in 8:
		var tithe := bool(flags & 1)
		var hesk := bool(flags & 2)
		var ilse := bool(flags & 4)
		_mount_kiln(tithe, hesk, ilse)
		lines.clear()
		game.player.global_position = game.hoist_lever.global_position + Vector3.UP
		game._use()
		_advance(76.0)
		assert(lines.has("c3.ser.24a") == tithe and lines.has("c3.ser.24b") != tithe, "Tithe branch for %d" % flags)
		assert(lines.has("c3.ser.24c") == hesk, "Hesk branch for %d" % flags)
		assert(lines.has("c3.ser.26a") == ilse and lines.has("c3.ser.26b") != ilse, "Ilse branch for %d" % flags)
	return true

func _bark_discipline() -> bool:
	var narrative: Node = game.narrative
	narrative.clear_chapter()
	narrative.tick(0.0)
	assert(narrative.submit_bark("whisper", "", "A whisper", null, 1.5, 0.0))
	assert(narrative.get_active_line().bark)
	assert(narrative.submit_line({"id": "immediate_story", "line": "Start immediately.", "duration": 2.0}))
	narrative.tick(0.0)
	assert(narrative.is_line_active("immediate_story"))

	assert(narrative.submit_line({"id": "queued_story", "line": "Next story line.", "duration": 0.2}))
	assert(narrative.submit_bark("whisper", "", "Stale whisper", null, 1.5, 0.0))
	narrative.tick(2.0)
	assert(narrative.is_line_active("queued_story"))
	narrative.tick(0.21)
	assert(not narrative.is_busy())

	assert(narrative.submit_line({"id": "short_story", "line": "A short line.", "duration": 0.2}))
	assert(narrative.submit_bark("whisper", "", "Still fresh", null, 1.5, 0.0))
	narrative.tick(0.21)
	assert(narrative.get_active_line().line == "Still fresh")
	return true

func _mount_kiln(tithe: bool, hesk: bool, ilse: bool) -> void:
	game.has_ashen_key = false
	game.won = false
	game.level_states["ch1_court"].read_hesk_planks = hesk
	var st := Registry.default_state("ch3_kiln")
	st.read_tithe_roll = tithe
	st.ilse_heard = ilse
	st.trough_flooded = true
	st.dam_broken = true
	game.level_states["ch3_kiln"] = st
	game._load_chapter("ch3_kiln", true, false)
	for enemy: CharacterBody3D in game.enemies.duplicate():
		game._damage_enemy(enemy, 999)

func _advance(seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.000001:
		var delta := minf(0.05, remaining)
		remaining -= delta
		game.elapsed += delta
		var camera_pose: Transform3D = game.camera.global_transform
		game.story_director.step_physics(delta)
		assert(game.camera.global_transform.is_equal_approx(camera_pose))
		assert(game.story_shake <= 0.120001)
		game.narrative.tick(delta)

func _frames(count: int) -> void:
	for i in count:
		await physics_frame

func _collision_enabled(node: Node) -> bool:
	if node is CollisionObject3D and node.collision_layer != 0:
		for child in node.get_children():
			if child is CollisionShape3D and not child.disabled:
				return true
	for child in node.get_children():
		if _collision_enabled(child):
			return true
	return false
