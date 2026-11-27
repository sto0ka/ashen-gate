extends SceneTree
## Run with Godot 4.7.2: godot --headless --path . --script tests/geometry_audit.gd

const Game = preload("res://scripts/main.gd")
const Chapters = preload("res://scripts/chapters/chapter_registry.gd")
const Saves = preload("res://scripts/save_system.gd")
const GRID := 0.5
const MAX_STEP := 0.52
const MAX_WATER_DEPTH := 2.4
const TICK := 1.0 / 60.0
const NEIGHBORS: Array[Vector3] = [
	Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK,
	Vector3(-1, 0, -1), Vector3(-1, 0, 1), Vector3(1, 0, -1), Vector3(1, 0, 1),
]
const ROOM_SEEDS := {
	"ch1_court": [
		Vector3(0, 0, 43), Vector3(0, 0, 32), Vector3(0, 0, 24),
		Vector3(-21, -0.8, 5), Vector3(-25, 2.42, -12), Vector3(-21, 2.42, -16),
		Vector3(23, -0.7, -3), Vector3(0, 0, -9), Vector3(0, 0, -31),
		Vector3(0, 0, -46), Vector3(-9.5, 0, 32), Vector3(-20, 4, 19.5),
	],
	"ch2_tower": [
		Vector3(0, 0, 16), Vector3(-24.5, 0, 1), Vector3(-31, 0, 6),
		Vector3(23, 0, 6), Vector3(23, 3.5, -5), Vector3(0, 6, -19),
		Vector3(0, 9.5, -35), Vector3(0, 7, -42),
	],
	"ch3_kiln": [
		Vector3(0, 0, 21), Vector3(-15, 6, 25), Vector3(15, 6, 25),
		Vector3(-24, 0, 5), Vector3(-24, 3.02, -9), Vector3(0, 0, 5),
		Vector3(21, 0, 5), Vector3(27, -0.65, 5), Vector3(0, 0, -30),
		Vector3(0, 0, -40), Vector3(7.4, 7.8, 32),
	],
}
const WATER_SURFACES := {
	"ch1_court": ["cistern_water", "rushing_water_channel"],
	"ch2_tower": [],
	"ch3_kiln": ["aqueduct_pool", "trough_water", "slag_river", "smeltery_magma"],
}

var game: Game
var space: PhysicsDirectSpaceState3D
var world_ray := PhysicsRayQueryParameters3D.new()
var clearance := PhysicsShapeQueryParameters3D.new()
var edge_motion := PhysicsTestMotionParameters3D.new()
var roof_bounds: Array[AABB] = []
var failures: Array[String] = []

class Findings:
	var count := 0
	var examples: PackedStringArray = []

	func record(description: String) -> void:
		count += 1
		if examples.size() < 8:
			examples.append(description)

# Headless physics can advance faster than the audio mixer's wall clock.
class TestAudio extends "res://scripts/audio_3d.gd":
	var cues: Array[String] = []

	func set_chapter(_id: String, _acoustics: String = "", _crossfade: float = 0.60) -> void:
		pass

	func play_2d(cue: String, _pitch: float = 1.0, _volume: float = -6.0) -> void:
		cues.append(cue)

	func play_at(_parent: Node3D, _cue: String, _pos: Vector3, _pitch: float = 1.0, _distance: float = 30.0, _volume: float = -6.0) -> void:
		pass

	func play_speaker_cue(_cue: String, _parent: Node3D = null, _origin: Variant = null, _channel: String = "", _syllables: int = 8) -> void:
		pass

class TestGame extends "res://scripts/main.gd":
	func _setup_audio() -> void:
		audio_3d = TestAudio.new()
		add_child(audio_3d)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	game = TestGame.new()
	root.add_child(game)
	game.set_physics_process(false)
	# Keep checkpoint and story volumes inert during geometry sampling and capsule sweeps.
	game.player.collision_layer = 0
	game.player.collision_mask = Game.LAYER_WORLD
	world_ray.collision_mask = Game.LAYER_WORLD
	clearance.collision_mask = Game.LAYER_WORLD
	var capsule := game.player.get_child(0) as CollisionShape3D
	clearance.shape = capsule.shape
	space = game.get_world_3d().direct_space_state

	for chapter: String in Chapters.get_chapter_ids():
		for progressed: bool in [false, true]:
			var state := Chapters.default_state(chapter)
			if progressed:
				_progress(chapter, state)
			game.level_states[chapter] = state
			game._load_chapter(chapter, true, false)
			await _physics_frames(3)
			var context := "%s %s" % [chapter, "progressed" if progressed else "initial"]
			_audit_chapter(context)
			if chapter != "ch3_kiln":
				_audit_drowned_bed(context)
		await _audit_stairs(chapter)
	await _audit_falls()

	game.audio_3d.stop_all()
	await _physics_frames(6)
	root.remove_child(game)
	game.free()
	game = null
	await _physics_frames(3)
	if failures.is_empty():
		print("GEOMETRY AUDIT PASS")
		quit(0)
	else:
		printerr("GEOMETRY AUDIT FAIL (%d checks)\n%s" % [failures.size(), "\n".join(failures)])
		quit(1)

func _progress(chapter: String, state: Dictionary) -> void:
	match chapter:
		"ch1_court":
			state.merge({
				"cistern_raised": true, "gatehouse_open": true, "coldopen_done": true,
				"outer_arch_collapsed": true, "shortcut_open": true, "gate_open": true,
				"keep_doors_open": true, "broken": ["court_watchwalk_bar"],
			}, true)
		"ch2_tower":
			state.merge({
				"wards": ["ward_1", "ward_2", "ward_3"], "lift_powered": true,
				"lift_unjammed": true, "lift_completed": true, "boss_dead": true,
				"bell_fallen": true,
			}, true)
			state.story_world.merge({"nave_chandelier_fallen": true, "belfry_shaft_open": true}, true)
		"ch3_kiln":
			state.merge({
				"aqueduct_powered": true, "trough_flooded": true, "dam_broken": true,
				"colossus_dead": true, "great_gate_open": true, "gate_turns": 3,
			}, true)

func _audit_chapter(context: String) -> void:
	var water_samples := _audit_water(context)
	roof_bounds.clear()
	for mesh: MeshInstance3D in game.level_root.find_children("*", "MeshInstance3D", true, false):
		var parent_name := String(mesh.get_parent().name)
		if mesh.is_visible_in_tree() and (parent_name.ends_with("_roof") or parent_name.ends_with("_ceiling") or parent_name.ends_with("_vault")):
			roof_bounds.append(mesh.global_transform * mesh.get_aabb())

	var cells: Array[Vector3] = []
	var visited: Dictionary[Vector3i, bool] = {}
	var void_edges := Findings.new()
	var sky_leaks := Findings.new()
	var indoor_cells := 0
	var bounds := game.map_bounds.grow(8.0)
	_seed_cell(game.player.global_position, cells, visited)
	_check(not cells.is_empty(), "%s: spawn has no walkable floor" % context)
	for seed: Vector3 in ROOM_SEEDS[game.chapter_id]:
		_seed_cell(seed, cells, visited)
	var index := 0
	while index < cells.size():
		var cell := cells[index]
		index += 1
		for direction: Vector3 in NEIGHBORS:
			var neighbor := cell + direction * GRID
			var step_height := MAX_STEP * direction.length()
			var hit := _support(neighbor, step_height, game._chapter_kill_y())
			if hit.is_empty():
				if not _hollow_edge(neighbor) and not _edge_blocked(cell, neighbor):
					void_edges.record("%s -> %s" % [cell, neighbor])
				continue
			var next: Vector3 = hit.position
			if next.y < cell.y - step_height:
				# Safe lower floors may be walkable but do not connect two levels by a step.
				continue
			if not bounds.has_point(Vector2(next.x, next.z)) or visited.has(_cell_key(next)):
				continue
			if _has_clearance(next) and not _wall_between(cell, next):
				_add_cell(next, cells, visited)
		var ceiling := _ceiling_height(cell)
		if ceiling < INF:
			indoor_cells += 1
			_audit_sky_rays(cell, ceiling, sky_leaks)
	_report_samples(context, "unprotected void edges", void_edges)
	_report_samples(context, "indoor sky leaks", sky_leaks)
	_check(indoor_cells > 0, "%s: no indoor walkable cells audited" % context)
	print("%s: %d water samples, %d walkable cells (%d indoor), %d void edges, %d sky leaks" % [
		context, water_samples, cells.size(), indoor_cells, void_edges.count, sky_leaks.count,
	])

func _audit_water(context: String) -> int:
	var names: Array = WATER_SURFACES[game.chapter_id]
	var found: Dictionary[String, int] = {}
	var misses := Findings.new()
	var samples := 0
	for mesh: MeshInstance3D in game.level_root.find_children("*", "MeshInstance3D", true, false):
		if not mesh.is_visible_in_tree():
			continue
		var surface := String(mesh.get_parent().name)
		# Repeated river siblings may receive generated names from add_child().
		if mesh.material_override == game.mats.slag and mesh.mesh is BoxMesh:
			var size := (mesh.mesh as BoxMesh).size
			if is_equal_approx(size.z, 34.8) and size.x < 4.0:
				surface = "slag_river"
		if surface not in names:
			continue
		found[surface] = found.get(surface, 0) + 1
		var box := mesh.get_aabb()
		var x_steps := ceili(box.size.x / GRID)
		var z_steps := ceili(box.size.z / GRID)
		for x in range(x_steps + 1):
			for z in range(z_steps + 1):
				# Include a sample just inside each boundary as well as the interior grid.
				var local := Vector3(
					clampf(box.position.x + x * GRID, box.position.x + 0.001, box.end.x - 0.001),
					box.end.y,
					clampf(box.position.z + z * GRID, box.position.z + 0.001, box.end.z - 0.001)
				)
				var point := mesh.to_global(local)
				samples += 1
				if _support(point, 0.005, point.y - MAX_WATER_DEPTH).is_empty():
					misses.record("%s at %s" % [surface, point])
	for surface: String in names:
		var expected := 2 if surface == "slag_river" else 1
		if surface == "trough_water" and not game._state().trough_flooded:
			expected = 0
		_check(found.get(surface, 0) >= expected, "%s: expected %d visible %s, found %d" % [
			context, expected, surface, found.get(surface, 0),
		])
	_report_samples(context, "water samples lack a solid floor", misses)
	print("%s: %d water floor misses, sampled meshes=%s" % [context, misses.count, found])
	return samples

func _audit_drowned_bed(context: String) -> void:
	var failure_count := failures.size()
	var ward := game.level_root.find_child("drowned_lower_ward", true, false) as Node3D
	var surface := ward.get_node_or_null("drowned_water") as MeshInstance3D if ward != null else null
	var bed := ward.get_node_or_null("drowned_water_bed") as StaticBody3D if ward != null else null
	if surface == null or bed == null:
		_check(false, "%s: drowned water or catch floor is missing" % context)
		return
	var collision := bed.get_child(0) as CollisionShape3D
	var shape := collision.shape as BoxShape3D
	_check(bed.collision_layer == Game.LAYER_WORLD and shape != null and shape.size.is_equal_approx(Vector3(240, 0.4, 260)),
		"%s: drowned catch floor has the wrong layer or size" % context)
	_check(is_equal_approx(surface.global_position.y, -14.0) and bed.global_position.is_equal_approx(surface.global_position - Vector3.UP * 0.2),
		"%s: drowned water and catch floor are misaligned" % context)
	_check(bed.find_children("*", "MeshInstance3D", true, false).is_empty(), "%s: drowned catch floor has a visual mesh" % context)
	for offset: Vector3 in [Vector3.ZERO, Vector3(-119, 0, -129), Vector3(119, 0, 129)]:
		var point := surface.global_position + offset
		var hit := _ray(point + Vector3.UP * 0.1, point - Vector3.UP * 0.5)
		_check(hit.get("collider") == bed, "%s: drowned catch floor did not intercept %s" % [context, point])
	print("%s: %d failed drowned catch floor checks" % [context, failures.size() - failure_count])

func _seed_cell(seed: Vector3, cells: Array[Vector3], visited: Dictionary[Vector3i, bool]) -> void:
	seed.x = snappedf(seed.x, GRID)
	seed.z = snappedf(seed.z, GRID)
	var hit := _support(seed, MAX_STEP, seed.y - MAX_STEP)
	if not hit.is_empty() and _has_clearance(hit.position):
		_add_cell(hit.position, cells, visited)

func _add_cell(cell: Vector3, cells: Array[Vector3], visited: Dictionary[Vector3i, bool]) -> void:
	var key := _cell_key(cell)
	if not visited.has(key):
		visited[key] = true
		cells.append(cell)

func _cell_key(cell: Vector3) -> Vector3i:
	return Vector3i(roundi(cell.x / GRID), roundi(cell.y * 8.0), roundi(cell.z / GRID))

func _support(at: Vector3, rise: float, bottom_y: float) -> Dictionary:
	var from := at + Vector3.UP * rise
	var to := Vector3(at.x, bottom_y, at.z)
	var floor_normal := cos(game.player.floor_max_angle)
	var excluded: Array[RID] = []
	var hit := _ray(from, to)
	# A sample can start inside a pier or skim the side of a collider over a floor.
	while not hit.is_empty() and (hit.normal as Vector3).y < floor_normal:
		excluded.append(hit.rid)
		world_ray.exclude = excluded
		hit = _ray(from, to)
	if not excluded.is_empty():
		world_ray.exclude = []
	return hit

func _ray(origin: Vector3, end: Vector3) -> Dictionary:
	world_ray.from = origin
	world_ray.to = end
	return space.intersect_ray(world_ray)

func _has_clearance(feet: Vector3) -> bool:
	clearance.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * 1.01)
	return space.intersect_shape(clearance, 1).is_empty()

func _wall_between(cell: Vector3, next: Vector3) -> bool:
	var y := maxf(cell.y, next.y)
	for height: float in [0.55, 1.5]:
		if not _ray(Vector3(cell.x, y + height, cell.z), Vector3(next.x, y + height, next.z)).is_empty():
			return true
	return false

func _edge_blocked(cell: Vector3, next: Vector3) -> bool:
	edge_motion.from = Transform3D(Basis.IDENTITY, cell + Vector3.UP * 0.105)
	edge_motion.motion = next - cell
	return PhysicsServer3D.body_test_motion(game.player.get_rid(), edge_motion)

func _hollow_edge(next: Vector3) -> bool:
	return game.chapter_id == "ch3_kiln" and next.z < -39.0 and game._state().great_gate_open

func _ceiling_height(cell: Vector3) -> float:
	var height := INF
	var above_feet := cell + Vector3.UP * 1.8
	var hit := _ray(above_feet, cell + Vector3.UP * 24.0)
	if not hit.is_empty() and (hit.normal as Vector3).y < -0.5:
		height = (hit.position as Vector3).y
	for box: AABB in roof_bounds:
		if box.position.y >= above_feet.y and cell.x >= box.position.x and cell.x <= box.end.x and cell.z >= box.position.z and cell.z <= box.end.z:
			height = minf(height, box.position.y)
	return height

func _audit_sky_rays(cell: Vector3, ceiling: float, leaks: Findings) -> void:
	for height: float in [0.6, 1.5, 2.6]:
		var origin := cell + Vector3.UP * height
		if origin.y >= ceiling:
			continue
		for i in 16:
			var angle := TAU * float(i) / 16.0
			var direction := Vector3(cos(angle), 0.0, sin(angle))
			if not _ray(origin, origin + direction * 180.0).is_empty():
				continue
			# Locate the first uncovered point along a clear sightline. A floor
			# continuing through the roof boundary identifies an outdoor passage.
			for step in range(1, ceili(180.0 / GRID) + 1):
				var distance := step * GRID
				var next := cell + direction * distance
				if _ceiling_height(next) < INF:
					continue
				if _support(next, MAX_STEP, next.y - 3.5).is_empty() and not _arrow_slit(origin, direction, distance):
					leaks.record("%s -> %s at height %.1f" % [cell, next, height])
				break

func _arrow_slit(origin: Vector3, direction: Vector3, distance: float) -> bool:
	if game.chapter_id != "ch1_court" or absf(direction.z) < 0.001:
		return false
	var t := (-17.9 - origin.z) / direction.z
	if t < 0.0 or t > distance + GRID or origin.y < 3.42 or origin.y > 4.8:
		return false
	var x := origin.x + direction.x * t
	return minf(absf(x + 22.0), minf(absf(x + 17.0), absf(x + 12.0))) <= 0.151

func _report_samples(context: String, label: String, findings: Findings) -> void:
	if findings.count > 0:
		failures.append("%s: %s %s (first %d: %s)" % [
			context, findings.count, label, findings.examples.size(), ", ".join(findings.examples),
		])

func _audit_stairs(chapter: String) -> void:
	match chapter:
		"ch1_court":
			await _stair_round_trip("approach_stair")
			await _stair_round_trip("cistern_entry_steps")
		"ch2_tower":
			await _stair_round_trip("belfry_grand_stair")
		"ch3_kiln":
			await _stair_round_trip("west_rim_stair")
			await _stair_round_trip("east_gantry_stair")

func _stair_round_trip(stair: String) -> void:
	var ramp := game.level_root.get_node_or_null("%s/%s_walk" % [stair, stair]) as StaticBody3D
	if ramp == null:
		_check(false, "%s: staircase collision ramp is missing" % stair)
		return
	var collider := ramp.get_child(0) as CollisionShape3D
	var shape := collider.shape as BoxShape3D
	var half_run := (shape.size.z - 0.5) * 0.5
	var start := collider.to_global(Vector3(0, shape.size.y * 0.5, -half_run))
	var end := collider.to_global(Vector3(0, shape.size.y * 0.5, half_run))
	var run := Vector3(end.x - start.x, 0.0, end.z - start.z).normalized()
	start -= run * 0.45
	end += run * 0.45
	var failure_count := failures.size()
	await _walk_stair(stair, start, end)
	await _walk_stair(stair, end, start)
	print("%s: %d failed capsule traversals" % [stair, failures.size() - failure_count])

func _walk_stair(label: String, start: Vector3, end: Vector3) -> void:
	game.player.global_position = start + Vector3.UP * 0.15
	game.player.velocity = Vector3.ZERO
	for i in 24:
		await physics_frame
		_move_capsule(Vector3.ZERO)
	var start_error := absf(game.player.global_position.y - start.y)
	var direction := Vector3(end.x - start.x, 0.0, end.z - start.z).normalized()
	var longest_airborne := 0
	var airborne := 0
	for i in ceili(start.distance_to(end) / (2.0 * TICK)) + 45:
		await physics_frame
		var offset := end - game.player.global_position
		if Vector2(offset.x, offset.z).length() <= 0.15:
			break
		_move_capsule(direction * 3.5)
		airborne = 0 if game.player.is_on_floor() else airborne + 1
		longest_airborne = maxi(longest_airborne, airborne)
	var reached := game.player.global_position
	var remaining := Vector2(end.x - reached.x, end.z - reached.z).length()
	var contacts: PackedStringArray = []
	for i in game.player.get_slide_collision_count():
		var collider := game.player.get_slide_collision(i).get_collider() as Node
		if collider != null:
			contacts.append(String(game.level_root.get_path_to(collider)))
	_check(start_error <= 0.36 and remaining <= 0.15 and absf(reached.y - end.y) <= 0.36 and longest_airborne <= 4,
		"%s: capsule going %s -> %s stopped at %s (start height error %.2f, %d airborne frames, contacts %s)" % [
			label, start, end, reached, start_error, longest_airborne, contacts,
		])

func _move_capsule(horizontal: Vector3) -> void:
	var vertical := -0.1 if game.player.is_on_floor() else game.player.velocity.y - Game.GRAVITY * TICK
	game.player.velocity = horizontal + Vector3.UP * vertical
	game.player.move_and_slide()

func _audit_falls() -> void:
	var failure_count := failures.size()
	game._init_level_states()
	game._load_chapter("ch1_court", true, false)
	var floor := Vector3(100, 0, 0)
	LevelBuilder.slab(game.level_root, "fall_audit_floor", Rect2(94, -6, 12, 12), floor.y, game.mats.stone)
	await _physics_frames(3)
	game._reset_arrival_motion()
	var protected_landing := await _drop(floor, 7.5)
	_check(protected_landing and game.hp == 100 and game._fall_grace_time > 0.0, "Arrival grace did not protect a 7.5 m fall")
	var dry_damage := 0
	for height: float in [2.5, 7.5, 20.0]:
		var start_hp := 135 if height == 20.0 else 100
		game.hp = start_hp
		game.player.global_position = floor + Vector3.UP * 0.1
		game._reset_arrival_motion()
		for tick in ceili(1.2 / TICK) + 1:
			await physics_frame
			game._physics_process(TICK)
		_check(is_zero_approx(game._fall_grace_time), "Fall grace did not expire")
		# Simulate an enemy hit shortly before contact. Landing damage must still apply.
		game.hurt_cooldown = 3.0
		var landed := await _drop(floor, height)
		match height:
			2.5:
				_check(landed and game.hp == 100, "2.5 m drop: expected safe landing, got y=%s hp=%d" % [game.player.global_position.y, game.hp])
			7.5:
				_check(landed and game.hp > 0 and game.hp < 100, "7.5 m drop: expected survivable damage, got y=%s hp=%d" % [game.player.global_position.y, game.hp])
				dry_damage = start_hp - game.hp
			20.0:
				_check(landed and _is_dead("YOU FELL TO YOUR DEATH"), "20 m drop: expected fatal landing, got y=%s hp=%d message=%s" % [
					game.player.global_position.y, game.hp, game.labels.message.text,
				])
	LevelBuilder.add_wet_zone(game, floor, Vector2(2, 2))
	game.hp = 100
	var audio := game.audio_3d as TestAudio
	audio.cues.clear()
	var wet_landing := await _drop(floor, 7.5)
	_check(wet_landing and 100 - game.hp == roundi(dry_damage * 0.5) and "splash" in audio.cues,
		"Wet landing did not halve damage and play a splash (dry=%d, wet=%d, cues=%s)" % [dry_damage, 100 - game.hp, audio.cues])
	for chapter: String in Chapters.get_chapter_ids():
		await _audit_abyss(chapter)
	print("Fall damage and abyss behavior: %d failed checks" % (failures.size() - failure_count))

func _drop(floor: Vector3, height: float) -> bool:
	game.player.global_position = floor + Vector3.UP * height
	game.player.velocity = Vector3.ZERO
	for tick in 140:
		await physics_frame
		game._physics_process(TICK)
		if game.hp == 0 or (game.player.is_on_floor() and tick > 1):
			break
	return game.player.is_on_floor() and absf(game.player.global_position.y - floor.y) < 0.03

func _audit_abyss(chapter: String) -> void:
	game.level_states[chapter] = Chapters.default_state(chapter)
	game.hp = game.max_hp
	game._load_chapter(chapter, true, false)
	await _physics_frames(3)
	var spawn := game.player.global_position
	var kill_y := -6.0 if chapter == "ch3_kiln" else -11.5
	_check(is_equal_approx(game._chapter_kill_y(), kill_y), "%s: incorrect abyss plane elevation" % chapter)
	game.player.global_position = Vector3(100.0, kill_y - 0.1, 0.0)
	game.player.velocity = Vector3(2.0, -20.0, 0.0)
	var below_plane := game.player.global_position
	game._physics_process(TICK)
	var death_text := "YOU FELL INTO THE ABYSS" if chapter == "ch3_kiln" else "YOU FELL INTO THE SUNKEN ABYSS"
	_check(_is_dead(death_text), "%s: abyss plane did not stop and kill player on first tick" % chapter)
	await physics_frame
	game._physics_process(TICK)
	_check(game.player.global_position.is_equal_approx(below_plane), "%s: dead player moved after abyss death" % chapter)

	# Use the real checkpoint input path and restore any user's existing save in the same frame.
	var had_checkpoint := FileAccess.file_exists(Saves.CHECKPOINT_PATH)
	var previous := PackedByteArray()
	if had_checkpoint:
		var existing := FileAccess.open(Saves.CHECKPOINT_PATH, FileAccess.READ)
		if existing == null:
			_check(false, "%s: couldn't read existing checkpoint for restoration" % chapter)
			return
		previous = existing.get_buffer(existing.get_length())
	game.hp = game.max_hp
	game.player.global_position = spawn
	var saved := Saves.write_save(game, true)
	game.hp = 0
	game.player.global_position = below_plane
	if saved:
		var retry := InputEventKey.new()
		retry.keycode = KEY_R
		retry.pressed = true
		# The death message still promises a checkpoint after Act I is complete.
		game.won = chapter == "ch3_kiln"
		game._input(retry)
	if had_checkpoint:
		var original := FileAccess.open(Saves.CHECKPOINT_PATH, FileAccess.WRITE)
		_check(original != null, "%s: couldn't restore existing checkpoint" % chapter)
		if original != null:
			original.store_buffer(previous)
			original.close()
	elif FileAccess.file_exists(Saves.CHECKPOINT_PATH):
		_check(DirAccess.remove_absolute(Saves.CHECKPOINT_PATH) == OK, "%s: couldn't remove test checkpoint" % chapter)
	_check(saved and game.hp == game.max_hp and game.player.global_position.is_equal_approx(spawn)
		and game.player.velocity.is_zero_approx() and is_equal_approx(game._fall_grace_time, 1.2)
		and not game.labels.message.text.contains(death_text), "%s: checkpoint did not restore live player at spawn" % chapter)
	await _physics_frames(3)
	for i in 30:
		await physics_frame
		game._physics_process(TICK)
		if game.player.is_on_floor():
			break
	var jump := InputEventKey.new()
	jump.keycode = KEY_SPACE
	jump.pressed = true
	game._input(jump)
	game._physics_process(TICK)
	_check(game.player.velocity.y > 0.0, "%s: player could not jump after checkpoint reload" % chapter)

func _is_dead(message: String) -> bool:
	return game.hp == 0 and game.player.velocity.is_zero_approx() and game.labels.message.text.begins_with(message)

func _physics_frames(count: int) -> void:
	for i in count:
		await physics_frame

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
