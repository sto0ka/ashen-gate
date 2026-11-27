class_name StoryDirector
extends Node

## Half-Life style in-world scripted sequence engine for Ashen Gate.
##
## The director never takes the camera, never locks input and never sets player
## aim. Chapter builders register targets, actors, marks, tubes, commits,
## sequences, story volumes, physical transitions and arrivals; then call
## finish_chapter_build(). main.gd calls step_physics() at the start of each
## physics step (a self-tick fallback covers a missing bridge).

const Visuals = preload("res://scripts/visuals.gd")
const LevelBuilder = preload("res://scripts/level_builder.gd")
const Meshes3D = preload("res://scripts/meshes_3d.gd")
const PhysicsSandbox = preload("res://scripts/physics_sandbox.gd")
const SaveSystem = preload("res://scripts/save_system.gd")

signal sequence_started(seq_id: String)
signal beat_applied(seq_id: String, beat_id: String)
signal sequence_finished(seq_id: String)
signal sequence_cancelled(seq_id: String, reason: String)
signal transition_finished(route_id: String, chapter_id: String, checkpoint_written: bool)
signal bell_tolled(mode: String, emitter_pos: Vector3)

const LAYER_WORLD := 1
const LAYER_DEBRIS := 16
const LAYER_PLAYER := 32

const STORY_SHAKE_CAP := 0.12
const WALK_SPEED := 8.5
const WIND_CAP := WALK_SPEED * 0.6
const TUBE_RANGE := 18.0
const TUBE_WAIT := 6.0
const MAX_DEBRIS := 24
const FADE_OUT := 0.20
const FADE_DWELL := 0.05
const FADE_IN := 0.20
const SWAP_WATCHDOG := 3.0
const ARRIVAL_GUARD := 0.75
const PLAYER_RADIUS := 0.35
const PLAYER_HEIGHT := 1.8
const ACTOR_HEAD := 1.6
const DEFAULT_DEADLINE := 20.0

const SPEED_PRESETS := {"limp": 1.4, "walk": 1.3, "run": 4.2, "crawl": 0.6, "stride": 1.8}
const TOLL_COLORS := {"lull": Color("6fe3f0"), "inverted": Color("b07cff"), "local": Color("ffd38a")}

# op -> {target: needs a node target, actor: needs a registered actor, args: required arg keys}
const OPCODES := {
	"voice": {"args": ["line"]},
	"bark": {"args": ["line"]},
	"foley": {"args": ["sound"]},
	"commit": {},
	"await_look": {"target": true},
	"bell_toll": {},
	"resonance": {},
	"rockfall": {"target": true},
	"chandelier_drop": {"target": true},
	"walk_to": {"actor": true},
	"gesture": {"actor": true},
	"look_at": {"actor": true},
	"vanish": {"actor": true},
	"set_hollowing": {"actor": true, "args": ["stage"]},
	"torch_group": {"args": ["group"]},
	"move_body": {"target": true},
	"fissure": {"target": true},
	"ward_chain": {"args": ["ward"]},
	"bell_drop": {"target": true},
	"wind_force": {"args": ["dir"]},
	"seal_ripple": {"target": true},
	"hollowing_motes": {},
	"name_stream": {},
	"glyph_drift": {},
	"pour_stream": {},
	"slag_cascade": {},
	"dust": {},
	"shake": {},
	"chain": {"args": ["sequence"]},
	"cancel_group": {"args": ["group"]},
	"stop_loop": {},
	"noop": {},
}

static var _method_cache: Dictionary = {}
static var _trail_texture: Texture2D
static var _fx_materials: Dictionary = {}

var _game_ref: WeakRef
var _fade_rect: ColorRect
var _fade_layer: CanvasLayer

var _generation := 0
var _chapter := ""
var _level: Node3D
var _state: Dictionary = {}
var _built := false
var _arm_check_pending := false

var _targets: Dictionary = {}
var _actors: Dictionary = {}
var _marks: Dictionary = {}
var _tubes: Dictionary = {}
var _commits: Dictionary = {}
var _specs: Dictionary = {}
var _volumes: Array[Dictionary] = []
var _routes: Dictionary = {}
var _arrivals: Dictionary = {}
var _light_groups: Dictionary = {}
var _ward_chains: Dictionary = {}
var _diagnostics: Array[String] = []

var _jobs: Array[Dictionary] = []
var _jobs_by_serial: Dictionary = {}
var _motions: Array[Dictionary] = []
var _pending_events: Array[Dictionary] = []
var _debris: Array[Node3D] = []
var _completed: Dictionary = {}
var _serial := 0
var _clock := 0.0
var _last_step_frame := -1
var _last_bell_toll_age := 999.0
var _arrival_guard := 0.0
var _travel: Dictionary = {}
var _fx_rng := RandomNumberGenerator.new()


# =============================================================================
# Lifecycle
# =============================================================================

static func trigger_sequence(game, seq_id: String) -> bool:
	if game == null or not is_instance_valid(game):
		return false
	var director: Variant = game.get("story_director")
	if director == null or not is_instance_valid(director) or not (director as Object).has_method("start_sequence"):
		return false
	return bool((director as Object).call("start_sequence", seq_id))


func setup(game: Node, fade_rect: ColorRect) -> void:
	_game_ref = weakref(game)
	if get_parent() == null and game != null and game != self:
		game.add_child(self)
	name = "StoryDirector"
	if fade_rect != null:
		_fade_rect = fade_rect
	elif not is_instance_valid(_fade_rect):
		_fade_layer = CanvasLayer.new()
		_fade_layer.name = "story_fade_layer"
		_fade_layer.layer = 120
		add_child(_fade_layer)
		_fade_rect = ColorRect.new()
		_fade_rect.name = "story_fade"
		_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_fade_layer.add_child(_fade_rect)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.color = Color(0, 0, 0, 0)
	_fade_rect.visible = false
	var narrative: Object = _narrative()
	if narrative != null and narrative.has_signal("speaker_cue"):
		var cb := Callable(self, "_on_speaker_cue")
		if not narrative.is_connected("speaker_cue", cb):
			narrative.connect("speaker_cue", cb)


func begin_chapter(chapter: String, level: Node3D, state: Dictionary) -> void:
	if _built or not _jobs.is_empty() or not _motions.is_empty():
		cancel_chapter("rebuild")
	_generation += 1
	_reset_registries()
	_chapter = chapter
	_level = level
	_state = state
	var world := _story_world()
	var done: Variant = world.get("completed_sequences", {})
	if not done is Dictionary:
		done = {}
		world["completed_sequences"] = done
	_completed = done
	_built = false
	_fx_rng.seed = hash(chapter) ^ (_generation * 2654435761)


func finish_chapter_build() -> void:
	if _built:
		return
	for seq_id: String in _specs.keys():
		var spec: Dictionary = _specs[seq_id]
		var problem := _validate_refs(spec)
		if not problem.is_empty():
			spec["invalid"] = true
			_diagnose(problem)
	for v: Dictionary in _volumes:
		var area: Area3D = v.area
		if is_instance_valid(area):
			area.set_deferred("monitoring", true)
		if not _specs.has(str(v.seq_id)):
			_diagnose("[%s] story volume '%s' names unknown sequence '%s'" % [_chapter, v.trigger_id, v.seq_id])
	for r: Dictionary in _routes.values():
		var area: Area3D = r.area
		if is_instance_valid(area):
			area.set_deferred("monitoring", true)
		r.armed = false
		r.prev_d = NAN
	_built = true
	_arm_check_pending = true
	_arrival_guard = maxf(_arrival_guard, 0.1)


func cancel_chapter(reason: String = "unload") -> void:
	var narrative: Object = _narrative()
	for job: Dictionary in _jobs.duplicate():
		var spec: Dictionary = job.spec
		var reconcile: Variant = spec.get("reconcile", null)
		if reconcile is Callable and (reconcile as Callable).is_valid():
			(reconcile as Callable).call()
			if bool(spec.get("once", true)):
				_completed[str(spec.id)] = true
		if narrative != null and narrative.has_method("cancel_group"):
			narrative.call("cancel_group", str(spec.id))
		sequence_cancelled.emit(str(spec.id), reason)
	_jobs.clear()
	_jobs_by_serial.clear()
	_motions.clear()
	_pending_events.clear()
	for d: Node3D in _debris:
		if is_instance_valid(d) and not (is_instance_valid(_level) and _level.is_ancestor_of(d) and _level.is_queued_for_deletion()):
			d.queue_free()
	_debris.clear()
	_built = false
	_arm_check_pending = false
	_generation += 1
	if not _travel.is_empty() and str(_travel.phase) == "out" and reason != "travel":
		_travel.phase = "in"
		_travel.t = 0.0


func _reset_registries() -> void:
	_targets.clear()
	_actors.clear()
	_marks.clear()
	_tubes.clear()
	_commits.clear()
	_specs.clear()
	_volumes.clear()
	_routes.clear()
	_arrivals.clear()
	_light_groups.clear()
	_ward_chains.clear()
	_jobs.clear()
	_jobs_by_serial.clear()
	_motions.clear()
	_pending_events.clear()
	_diagnostics.clear()


func get_generation() -> int:
	return _generation


func get_chapter() -> String:
	return _chapter


func get_diagnostics() -> Array[String]:
	return _diagnostics.duplicate()


# =============================================================================
# Registration
# =============================================================================

func register_target(id: String, target: Node3D) -> void:
	if id.is_empty() or target == null:
		_diagnose("[%s] register_target rejected an empty id or null node" % _chapter)
		return
	_targets[id] = target


func register_actor(id: String, holder: Node3D, rig: Node3D, marks: Dictionary = {}) -> void:
	if id.is_empty() or holder == null:
		_diagnose("[%s] register_actor rejected an empty id or null holder" % _chapter)
		return
	_actors[id] = {"id": id, "holder": holder, "rig": rig, "hollowing": 0, "speed": 0.0}
	for mark_id: Variant in marks.keys():
		var m: Variant = marks[mark_id]
		if m is Vector3:
			register_mark(str(mark_id), m)
		elif m is Dictionary and (m as Dictionary).get("pos") is Vector3:
			register_mark(str(mark_id), m.pos, float(m.get("yaw", 0.0)))
		elif m is Node3D:
			register_mark(str(mark_id), (m as Node3D).global_position, (m as Node3D).global_rotation.y)


func register_mark(id: String, pos: Vector3, yaw: float = 0.0) -> void:
	if id.is_empty():
		return
	_marks[id] = {"pos": pos, "yaw": yaw}


func register_tube(id: String, node: Node3D) -> void:
	if id.is_empty() or node == null:
		return
	_tubes[id] = node


func register_commit(action_id: String, callback: Callable) -> void:
	if action_id.is_empty() or not callback.is_valid():
		_diagnose("[%s] register_commit rejected '%s'" % [_chapter, action_id])
		return
	_commits[action_id] = callback


func register_light_group(group: String, light: Light3D) -> void:
	if group.is_empty() or light == null:
		return
	if not _light_groups.has(group):
		_light_groups[group] = []
	(_light_groups[group] as Array).append(light)


func register_sequence(spec: Dictionary) -> void:
	var seq_id := str(spec.get("id", ""))
	if seq_id.is_empty():
		_diagnose("[%s] sequence rejected: missing id" % _chapter)
		return
	if _specs.has(seq_id):
		_diagnose("[%s] sequence '%s' rejected: duplicate id" % [_chapter, seq_id])
		return
	var raw_beats: Variant = spec.get("beats", [])
	if not raw_beats is Array:
		_diagnose("[%s] sequence '%s' rejected: beats must be an Array" % [_chapter, seq_id])
		return
	var beats: Array[Dictionary] = []
	var seen := {}
	var order := 0
	for raw: Variant in raw_beats:
		if not raw is Dictionary:
			_diagnose("[%s] %s: beat #%d rejected: not a Dictionary" % [_chapter, seq_id, order])
			return
		var b: Dictionary = raw
		var beat := {
			"id": str(b.get("id", "beat_%d" % order)),
			"at": b.get("at", 0.0),
			"op": str(b.get("op", "")),
			"target": str(b.get("target", "")),
			"args": b.get("args", {}),
			"optional": bool(b.get("optional", false)),
			"order": order,
		}
		var problem := _validate_beat(seq_id, beat)
		if not problem.is_empty():
			_diagnose(problem)
			return
		if seen.has(beat.id):
			_diagnose("[%s] %s/%s rejected: duplicate beat id" % [_chapter, seq_id, beat.id])
			return
		seen[beat.id] = true
		beat.at = float(beat.at)
		beats.append(beat)
		order += 1
	beats.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.at) < float(b.at) or (is_equal_approx(float(a.at), float(b.at)) and int(a.order) < int(b.order))
	)
	var when: Variant = spec.get("when", null)
	var stored := {
		"id": seq_id,
		"once": bool(spec.get("once", true)),
		"when": when if when is Callable else Callable(),
		"reconcile": spec.get("reconcile", null) if spec.get("reconcile", null) is Callable else Callable(),
		"deadline": maxf(float(spec.get("deadline", DEFAULT_DEADLINE)), 0.1),
		"beats": beats,
		"invalid": false,
	}
	_specs[seq_id] = stored
	if _built:
		var problem := _validate_refs(stored)
		if not problem.is_empty():
			stored.invalid = true
			_diagnose(problem)


func register_story_volume(area: Area3D, trigger_id: String, seq_id: String) -> void:
	if area == null or trigger_id.is_empty():
		_diagnose("[%s] story volume rejected: null area or empty trigger id" % _chapter)
		return
	area.monitoring = false
	area.monitorable = false
	var entry := {"area": area, "trigger_id": trigger_id, "seq_id": seq_id, "armed": false}
	_volumes.append(entry)
	var gen := _generation
	area.body_entered.connect(func(body: Node3D) -> void:
		if gen != _generation or body != _player():
			return
		_pending_events.append({"kind": "volume", "entry": entry, "gen": gen})
	)


func register_transition(area: Area3D, marker: Marker3D, route: Dictionary) -> void:
	var route_id := str(route.get("id", ""))
	if area == null or marker == null or route_id.is_empty():
		_diagnose("[%s] transition rejected: missing area, marker or id" % _chapter)
		return
	if _routes.has(route_id):
		_diagnose("[%s] transition '%s' rejected: duplicate id" % [_chapter, route_id])
		return
	if str(route.get("destination", "")).is_empty():
		_diagnose("[%s] transition '%s' rejected: missing destination" % [_chapter, route_id])
		return
	var direction: Variant = route.get("direction_local", Vector3.FORWARD)
	if not direction is Vector3 or (direction as Vector3).length_squared() < 0.0001:
		direction = Vector3.FORWARD
	var open_pred: Variant = route.get("is_open", null)
	area.monitoring = false
	area.monitorable = false
	_routes[route_id] = {
		"id": route_id,
		"destination": str(route.destination),
		"arrival_id": str(route.get("arrival_id", "")),
		"label": str(route.get("label", route_id)),
		"kind": str(route.get("kind", "arch")),
		"direction_local": (direction as Vector3).normalized(),
		"safe_return_id": str(route.get("safe_return_id", "")),
		"is_open": open_pred if open_pred is Callable else Callable(),
		"area": area,
		"marker": marker,
		"armed": false,
		"prev_d": NAN,
	}


func register_arrival(id: String, marker: Marker3D) -> void:
	if id.is_empty() or marker == null:
		return
	_arrivals[id] = marker


func get_arrival(id: String) -> Marker3D:
	var m: Variant = _arrivals.get(id, null)
	if m is Marker3D and is_instance_valid(m):
		return m
	return null


func register_ward_chain(ward_id: String, chain_node: Node3D) -> void:
	if ward_id.is_empty() or chain_node == null:
		return
	if not chain_node.has_meta("anchor"):
		chain_node.set_meta("anchor", chain_node.global_position if chain_node.is_inside_tree() else chain_node.position)
	_ward_chains[ward_id] = chain_node


func snap_ward_chain(ward_id: String) -> void:
	var chain: Variant = _ward_chains.get(ward_id, null)
	_ward_chains.erase(ward_id)
	if chain == null or not is_instance_valid(chain):
		return
	var node: Node3D = chain
	var parent := _level if is_instance_valid(_level) else node.get_parent() as Node3D
	var rng := _event_rng("ward_snap/" + ward_id, 0)
	if parent != null and node.is_inside_tree():
		for child: Node in node.get_children():
			if child is MeshInstance3D and (child as MeshInstance3D).visible:
				var link := child as MeshInstance3D
				var body := RigidBody3D.new()
				body.name = "ward_link_debris"
				body.collision_layer = LAYER_DEBRIS
				body.collision_mask = LAYER_WORLD
				body.mass = 0.4
				var shape := CollisionShape3D.new()
				var box := BoxShape3D.new()
				box.size = Vector3(0.12, 0.08, 0.26)
				shape.shape = box
				body.add_child(shape)
				parent.add_child(body)
				body.global_transform = link.global_transform
				link.reparent(body, true)
				body.apply_central_impulse(Vector3(rng.randf_range(-1, 1), rng.randf_range(0.2, 1.2), rng.randf_range(-1, 1)) * 0.8)
				body.apply_torque_impulse(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 0.05)
				_track_debris(body, 6.0)
		_sound_at("frost", node.global_position, 1.4)
	node.queue_free()


func reanchor_ward_chains(target_pos: Vector3) -> void:
	for ward_id: String in _ward_chains.keys():
		var chain: Variant = _ward_chains[ward_id]
		if chain == null or not is_instance_valid(chain):
			_ward_chains.erase(ward_id)
			continue
		var node: Node3D = chain
		node.set_meta("target", target_pos)
		_build_chain_links(node, node.get_meta("anchor"), target_pos, node.get_meta("color", TOLL_COLORS.inverted))


# =============================================================================
# Queries
# =============================================================================

func is_sequence_completed(seq_id: String) -> bool:
	return _completed.has(seq_id)


func is_sequence_running(seq_id: String) -> bool:
	for job: Dictionary in _jobs:
		if str(job.spec.id) == seq_id:
			return true
	return false


func has_sequence(seq_id: String) -> bool:
	return _specs.has(seq_id) and not bool(_specs[seq_id].invalid)


func is_transitioning() -> bool:
	return not _travel.is_empty()


func get_last_bell_toll_age() -> float:
	return _last_bell_toll_age


func get_exits() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Dictionary in _routes.values():
		var marker: Marker3D = r.marker
		if not is_instance_valid(marker):
			continue
		out.append({
			"id": r.id, "label": r.label, "kind": r.kind, "destination": r.destination,
			"position": marker.global_position if marker.is_inside_tree() else marker.position,
			"active": _route_open(r),
		})
	return out


func get_exit_position(route_id: String, require_open: bool = true) -> Variant:
	var r: Variant = _routes.get(route_id, null)
	if r == null:
		return null
	var marker: Marker3D = r.marker
	if not is_instance_valid(marker):
		return null
	if require_open and not _route_open(r):
		return null
	return marker.global_position if marker.is_inside_tree() else marker.position


func get_actor(id: String) -> Node3D:
	var a: Variant = _actors.get(id, null)
	if a == null or not is_instance_valid(a.holder):
		return null
	return a.holder


func get_mark(id: String) -> Variant:
	var m: Variant = _marks.get(id, null)
	return null if m == null else (m as Dictionary).duplicate()


## Story energy scale applied by torch_group for a light (1.0 when untouched).
## main.gd's own torch flicker multiplies by this so a blackout is not overwritten.
static func get_torch_scale(light: Node) -> float:
	if light == null or not light.has_meta("story_energy_scale"):
		return 1.0
	return float(light.get_meta("story_energy_scale"))


# =============================================================================
# Sequence control
# =============================================================================

func start_sequence(seq_id: String) -> bool:
	var spec: Variant = _specs.get(seq_id, null)
	if spec == null:
		return false
	if bool(spec.invalid) or _g() == null:
		return false
	if bool(spec.once) and _completed.has(seq_id):
		return false
	if is_sequence_running(seq_id):
		return false
	var when: Callable = spec.when
	if when.is_valid() and not bool(when.call()):
		return false
	_serial += 1
	var job := {
		"spec": spec, "serial": _serial, "local_t": 0.0, "post_t": 0.0,
		"next_beat": 0, "hold": {}, "owned": 0, "gen": _generation, "accepted_at": _clock,
	}
	_jobs.append(job)
	_jobs_by_serial[_serial] = job
	sequence_started.emit(seq_id)
	return true


func cancel_sequence(seq_id: String, reason: String = "cancelled") -> void:
	for job: Dictionary in _jobs.duplicate():
		if str(job.spec.id) == seq_id:
			_remove_job(job)
			sequence_cancelled.emit(seq_id, reason)


func step_physics(delta: float) -> void:
	_last_step_frame = Engine.get_physics_frames()
	if delta <= 0.0 or not is_finite(delta):
		return
	if _story_suspended():
		return
	_clock += delta
	_last_bell_toll_age += delta
	_arrival_guard = maxf(0.0, _arrival_guard - delta)
	var gen := _generation
	_drain_events()
	if gen != _generation:
		return
	if _built:
		_update_arming()
		_update_routes()
	if gen != _generation:
		return
	_advance_jobs(delta)
	if gen != _generation:
		return
	_step_motions(delta)
	if gen != _generation:
		return
	_complete_jobs(delta)


func _physics_process(delta: float) -> void:
	# Self-tick fallback in case the game bridge has not been wired.
	if _last_step_frame != Engine.get_physics_frames():
		step_physics(delta)


func _process(delta: float) -> void:
	_update_fade(delta)


func _story_suspended() -> bool:
	var g: Object = _g()
	if g == null:
		return true
	for key: String in ["map_overlay", "journal_panel", "pause_menu"]:
		var n: Variant = g.get(key)
		if n is Object and is_instance_valid(n) and bool((n as Object).get("visible")):
			return true
	return is_inside_tree() and get_tree().paused and process_mode != PROCESS_MODE_ALWAYS


func _drain_events() -> void:
	if _pending_events.is_empty():
		return
	var events := _pending_events.duplicate()
	_pending_events.clear()
	var g: Object = _g()
	for ev: Dictionary in events:
		if int(ev.gen) != _generation or not _built:
			continue
		if str(ev.kind) == "volume":
			var entry: Dictionary = ev.entry
			if not bool(entry.armed):
				continue
			var key := "story/%s/%s" % [_chapter, entry.trigger_id]
			var triggered: Variant = g.get("triggered_volumes") if g != null else null
			if triggered is Dictionary and (triggered as Dictionary).has(key):
				continue
			if start_sequence(str(entry.seq_id)) and triggered is Dictionary:
				(triggered as Dictionary)[key] = true


func _update_arming() -> void:
	var player := _player()
	if player == null:
		return
	if _arm_check_pending:
		_arm_check_pending = false
		for v: Dictionary in _volumes:
			v.armed = not _player_inside_area(v.area)
		return
	for v: Dictionary in _volumes:
		if not bool(v.armed) and not _player_inside_area(v.area):
			v.armed = true


func _advance_jobs(delta: float) -> void:
	for job: Dictionary in _jobs:
		if (job.hold as Dictionary).is_empty():
			job.local_t = float(job.local_t) + delta
		else:
			_update_hold(job, delta)
	var due: Array = []
	for job: Dictionary in _jobs:
		if not (job.hold as Dictionary).is_empty():
			continue
		var beats: Array = job.spec.beats
		for i in range(int(job.next_beat), beats.size()):
			var at := float(beats[i].at)
			if at > float(job.local_t) + 0.000001:
				break
			due.append([_clock - (float(job.local_t) - at), int(job.serial), i, job])
	if due.is_empty():
		return
	due.sort_custom(func(a: Array, b: Array) -> bool:
		if not is_equal_approx(float(a[0]), float(b[0])):
			return float(a[0]) < float(b[0])
		if int(a[1]) != int(b[1]):
			return int(a[1]) < int(b[1])
		return int(a[2]) < int(b[2])
	)
	var gen := _generation
	for d: Array in due:
		if gen != _generation:
			return
		var job: Dictionary = d[3]
		if not _jobs_by_serial.has(int(job.serial)) or not (job.hold as Dictionary).is_empty() or int(job.next_beat) != int(d[2]):
			continue
		job.next_beat = int(d[2]) + 1
		var beat: Dictionary = job.spec.beats[int(d[2])]
		_dispatch(job, beat)
		if gen != _generation:
			return
		beat_applied.emit(str(job.spec.id), str(beat.id))


func _complete_jobs(delta: float) -> void:
	for job: Dictionary in _jobs.duplicate():
		var beats: Array = job.spec.beats
		if int(job.next_beat) < beats.size() or not (job.hold as Dictionary).is_empty():
			continue
		job.post_t = float(job.post_t) + delta
		if int(job.owned) > 0 and float(job.post_t) < float(job.spec.deadline):
			continue
		_finish_job(job)


func _finish_job(job: Dictionary) -> void:
	var seq_id := str(job.spec.id)
	_remove_job(job)
	if bool(job.spec.once):
		_completed[seq_id] = true
	sequence_finished.emit(seq_id)


func _remove_job(job: Dictionary) -> void:
	_jobs.erase(job)
	_jobs_by_serial.erase(int(job.serial))
	for m: Dictionary in _motions:
		if int(m.get("owner", -1)) == int(job.serial):
			m.owner = -1


func _own(job: Dictionary, motion: Dictionary) -> Dictionary:
	motion["owner"] = int(job.serial) if not job.is_empty() else -1
	if not job.is_empty():
		job.owned = int(job.owned) + 1
	_motions.append(motion)
	return motion


func _release_owner(motion: Dictionary) -> void:
	var owner := int(motion.get("owner", -1))
	motion.owner = -1
	if owner >= 0 and _jobs_by_serial.has(owner):
		var job: Dictionary = _jobs_by_serial[owner]
		job.owned = maxi(0, int(job.owned) - 1)


# =============================================================================
# Validation
# =============================================================================

func _validate_beat(seq_id: String, beat: Dictionary) -> String:
	var where := "[%s] %s/%s" % [_chapter, seq_id, beat.id]
	var op := str(beat.op)
	if not OPCODES.has(op):
		return "%s rejected: unknown opcode '%s'" % [where, op]
	var at: Variant = beat.at
	if not (at is float or at is int) or not is_finite(float(at)) or float(at) < 0.0:
		return "%s rejected: 'at' must be a finite number >= 0" % where
	if not beat.args is Dictionary:
		return "%s rejected: args must be a Dictionary" % where
	var args: Dictionary = beat.args
	var rule: Dictionary = OPCODES[op]
	if (bool(rule.get("target", false)) or bool(rule.get("actor", false))) and str(beat.target).is_empty():
		return "%s rejected: opcode '%s' needs a target" % [where, op]
	for key: String in rule.get("args", []):
		if not args.has(key):
			return "%s rejected: opcode '%s' needs args.%s" % [where, op, key]
	match op:
		"voice", "bark":
			if not args.line is String or str(args.line).strip_edges().is_empty():
				return "%s rejected: args.line must be a non-empty String" % where
			if args.has("when") and not args.when is Callable:
				return "%s rejected: args.when must be a Callable" % where
		"foley":
			if not args.sound is String:
				return "%s rejected: args.sound must be a String" % where
		"await_look":
			if args.has("cone_deg") and not _is_num(args.cone_deg):
				return "%s rejected: args.cone_deg must be a number" % where
			if args.has("timeout") and not _is_num(args.timeout):
				return "%s rejected: args.timeout must be a number" % where
		"bell_toll":
			var mode := str(args.get("mode", "lull"))
			if not TOLL_COLORS.has(mode):
				return "%s rejected: bell_toll mode '%s'" % [where, mode]
		"walk_to":
			if not args.has("mark") and not args.has("route"):
				return "%s rejected: walk_to needs args.mark or args.route" % where
			if args.has("route") and not args.route is Array:
				return "%s rejected: args.route must be an Array" % where
			var speed: Variant = args.get("speed", "walk")
			if not (_is_num(speed) and float(speed) > 0.0) and not (speed is String and SPEED_PRESETS.has(speed)):
				return "%s rejected: invalid walk speed" % where
		"set_hollowing":
			if not _is_num(args.stage) or int(args.stage) < 0 or int(args.stage) > 4:
				return "%s rejected: stage must be 0..4" % where
		"torch_group":
			if args.has("scale") and not _is_num(args.scale):
				return "%s rejected: args.scale must be a number" % where
		"move_body":
			if not args.has("end_pos") and not args.has("end_mark") and not args.has("offset"):
				return "%s rejected: move_body needs end_pos, end_mark or offset" % where
			if args.has("end_pos") and not args.end_pos is Vector3:
				return "%s rejected: args.end_pos must be a Vector3" % where
		"wind_force":
			if not args.dir is Vector3:
				return "%s rejected: args.dir must be a Vector3" % where
		"ward_chain":
			var action := str(args.get("action", "spawn"))
			if not action in ["spawn", "reanchor", "snap"]:
				return "%s rejected: ward_chain action '%s'" % [where, action]
		"commit":
			if args.has("state") and not args.state is Dictionary:
				return "%s rejected: args.state must be a Dictionary" % where
			if args.has("story_world") and not args.story_world is Dictionary:
				return "%s rejected: args.story_world must be a Dictionary" % where
	return ""


func _validate_refs(spec: Dictionary) -> String:
	for beat: Dictionary in spec.beats:
		if bool(beat.optional):
			continue
		var where := "[%s] %s/%s" % [_chapter, spec.id, beat.id]
		var rule: Dictionary = OPCODES[str(beat.op)]
		var target := str(beat.target)
		if bool(rule.get("actor", false)) and not _actors.has(target):
			return "%s invalid: actor '%s' is not registered" % [where, target]
		# "$player", "$camera", "$boss", "$level" resolve live at dispatch time.
		if bool(rule.get("target", false)) and not target.begins_with("$") and _resolve_node(target) == null:
			return "%s invalid: target '%s' is not registered" % [where, target]
		var args: Dictionary = beat.args
		var marks: Array = []
		if args.has("mark"):
			marks.append(args.mark)
		if args.has("end_mark"):
			marks.append(args.end_mark)
		if args.get("route") is Array:
			marks.append_array(args.route)
		for m: Variant in marks:
			if m is String and not _marks.has(m) and _resolve_node(str(m)) == null:
				return "%s invalid: mark '%s' is not registered" % [where, m]
		if str(beat.op) == "commit" and not str(args.get("action", "")).is_empty() and not _commits.has(str(args.action)):
			push_warning("%s: commit action '%s' is not registered yet" % [where, args.action])
	return ""


func _diagnose(message: String) -> void:
	_diagnostics.append(message)
	push_warning("StoryDirector: " + message)


static func _is_num(v: Variant) -> bool:
	return (v is float or v is int) and is_finite(float(v))


# =============================================================================
# Dispatch
# =============================================================================

func _dispatch(job: Dictionary, beat: Dictionary) -> void:
	var args: Dictionary = beat.args
	var target_id := str(beat.target)
	match str(beat.op):
		"voice":
			_op_voice(job, beat)
		"bark":
			_op_bark(beat)
		"foley":
			_op_foley(beat)
		"commit":
			_op_commit(beat)
		"await_look":
			if _resolve_node(target_id) != null:
				job.hold = {
					"kind": "look", "target": target_id, "elapsed": 0.0,
					"cone": float(args.get("cone_deg", 38.0)), "timeout": float(args.get("timeout", 3.5)),
					"cue": str(args.get("timeout_cue", "")),
				}
		"bell_toll":
			_op_bell_toll(job, beat)
		"resonance":
			_op_resonance(job, beat)
		"rockfall":
			_op_rockfall(job, beat)
		"chandelier_drop":
			_op_chandelier(job, beat)
		"walk_to":
			_op_walk(job, beat)
		"gesture":
			_op_gesture(job, beat)
		"look_at":
			_op_look_at(job, beat)
		"vanish":
			_op_vanish(beat)
		"set_hollowing":
			_set_hollowing(target_id, int(args.stage))
		"torch_group":
			_op_torch_group(job, beat)
		"move_body":
			_op_move_body(job, beat)
		"fissure":
			_op_fissure(job, beat)
		"ward_chain":
			_op_ward_chain(job, beat)
		"bell_drop":
			_op_bell_drop(job, beat)
		"wind_force":
			_op_wind(job, beat)
		"seal_ripple":
			_op_seal_ripple(beat)
		"hollowing_motes":
			_op_motes(job, beat)
		"name_stream":
			_op_name_stream(job, beat)
		"glyph_drift":
			_op_glyph_drift(job, beat)
		"pour_stream":
			_op_pour_stream(job, beat)
		"slag_cascade":
			_op_slag_cascade(job, beat)
		"dust":
			var pos: Variant = _beat_pos(beat)
			if pos is Vector3:
				_dust(pos, args.get("dir", Vector3.UP), str(args.get("kind", "stone")), _event_seed(job, beat))
		"shake":
			_story_shake(float(args.get("amount", 0.08)), _beat_pos(beat))
		"chain":
			start_sequence(str(args.sequence))
		"cancel_group":
			var narrative: Object = _narrative()
			if narrative != null and narrative.has_method("cancel_group"):
				narrative.call("cancel_group", str(args.group))
		"stop_loop":
			var loop_id := str(args.get("loop_id", target_id))
			for m: Dictionary in _motions:
				if str(m.kind) == "toll_loop" and (loop_id.is_empty() or str(m.loop_id) == loop_id):
					m.done = true
		"noop":
			pass


func _update_hold(job: Dictionary, delta: float) -> void:
	var hold: Dictionary = job.hold
	hold.elapsed = float(hold.elapsed) + delta
	match str(hold.kind):
		"look":
			var node := _resolve_node(str(hold.target))
			if node == null:
				job.hold = {}
				job.look_result = "missing"
				return
			if _target_in_view(node, float(hold.cone)):
				job.hold = {}
				job.look_result = "seen"
			elif float(hold.elapsed) >= float(hold.timeout):
				job.hold = {}
				job.look_result = "timeout"
				var cue := str(hold.cue)
				if not cue.is_empty():
					_sound_at(cue, _node_center(node), 1.0, 60.0)
		"tube":
			var tube := _nearest_tube()
			if tube != null or float(hold.elapsed) >= TUBE_WAIT:
				job.hold = {}
				_emit_voice(job, hold.beat, tube, true)
		_:
			job.hold = {}


# --- voice / bark / foley / commit ------------------------------------------

func _voice_allowed(args: Dictionary) -> bool:
	var when: Variant = args.get("when", null)
	if when is Callable and (when as Callable).is_valid() and not bool((when as Callable).call()):
		return false
	if args.has("flag") and not _flag_set(str(args.flag)):
		return false
	if args.has("not_flag") and _flag_set(str(args.not_flag)):
		return false
	return true


func _flag_set(flag: String) -> bool:
	var g: Object = _g()
	if g != null:
		var flags: Variant = g.get("story_flags")
		if flags is Array and (flags as Array).has(flag):
			return true
	if _state.has(flag) and _truthy(_state[flag]):
		return true
	var world := _story_world()
	return world.has(flag) and _truthy(world[flag])


static func _truthy(v: Variant) -> bool:
	if v is bool:
		return v
	if v is int or v is float:
		return float(v) != 0.0
	if v is String:
		return not str(v).is_empty()
	if v is Array:
		return not (v as Array).is_empty()
	if v is Dictionary:
		return not (v as Dictionary).is_empty()
	return v != null


func _op_voice(job: Dictionary, beat: Dictionary) -> void:
	var args: Dictionary = beat.args
	if not _voice_allowed(args):
		return
	if str(args.get("channel", "")) == "tube":
		var tube := _nearest_tube()
		if tube == null and not _tubes.is_empty() and bool(args.get("wait_for_tube", true)):
			job.hold = {"kind": "tube", "beat": beat, "elapsed": 0.0}
			return
		_emit_voice(job, beat, tube, true)
		return
	_emit_voice(job, beat, null, false)


func _emit_voice(job: Dictionary, beat: Dictionary, tube: Node3D, via_tube: bool) -> void:
	var args: Dictionary = beat.args
	var narrative: Object = _narrative()
	if narrative == null:
		return
	var seq_id := str(job.spec.id)
	var speaker_arg := str(args.get("speaker", ""))
	var speaker_id := str(args.get("speaker_id", ""))
	var label := str(args.get("label", ""))
	if speaker_id.is_empty():
		if _profiles().has(speaker_arg.to_lower()):
			speaker_id = speaker_arg.to_lower()
		elif label.is_empty():
			label = speaker_arg
	elif label.is_empty() and not _profiles().has(speaker_arg.to_lower()):
		label = speaker_arg
	var line := {
		"id": str(args.get("id", "%s/%s" % [seq_id, beat.id])),
		"group_id": str(args.get("group", seq_id)),
		"speaker_id": speaker_id,
		"line": str(args.line),
		"priority": int(args.get("priority", 1)),
		"interrupt": int(args.get("interrupt", 0)),
		"channel": str(args.get("channel", "")),
	}
	if not label.is_empty():
		line["speaker"] = label
	if args.has("duration"):
		line["duration"] = args.duration
	if args.has("color"):
		line["color"] = args.color
	if args.has("italic"):
		line["italic"] = args.italic
	if via_tube:
		line["channel"] = "tube"
		if not label.is_empty() and not label.ends_with(" — SPEAKING-TUBE"):
			line["speaker"] = label + " — SPEAKING-TUBE"
		if tube != null:
			line["world_origin"] = _node_center(tube)
			_pulse_tube(tube, float(line.get("duration", NarrativeDefaults.duration(str(args.line)))))
		else:
			line["world_origin"] = null
	else:
		var target_id := str(beat.target)
		var origin: Variant = args.get("origin", null)
		if origin is String:
			origin = _resolve_pos(origin)
		if origin is Vector3:
			line["world_origin"] = origin
		elif not target_id.is_empty():
			if _actors.has(target_id):
				var holder: Node3D = _actors[target_id].holder
				if is_instance_valid(holder):
					var last: Vector3 = holder.global_position + Vector3.UP * ACTOR_HEAD
					line["world_origin"] = last
					line["origin_resolver"] = func() -> Variant:
						return holder.global_position + Vector3.UP * ACTOR_HEAD if is_instance_valid(holder) else last
			else:
				var p: Variant = _resolve_pos(target_id)
				if p is Vector3:
					line["world_origin"] = p
	if narrative.has_method("submit_line"):
		narrative.call("submit_line", line)
	else:
		narrative.call("say", str(line.get("speaker", speaker_arg)), str(args.line), float(args.get("duration", 4.8)), Color("70d7df"))


func _op_bark(beat: Dictionary) -> void:
	var args: Dictionary = beat.args
	if not _voice_allowed(args):
		return
	var narrative: Object = _narrative()
	if narrative == null or not narrative.has_method("submit_bark"):
		return
	var speaker_arg := str(args.get("speaker", ""))
	var speaker_id := str(args.get("speaker_id", "")).to_lower()
	var label := str(args.get("label", ""))
	if speaker_id.is_empty():
		speaker_id = speaker_arg.to_lower()
		if not _profiles().has(speaker_id):
			speaker_id = speaker_id.replace(" ", "_")
			if label.is_empty():
				label = speaker_arg
	var origin: Variant = args.get("origin", null)
	if origin is String:
		origin = _resolve_pos(origin)
	if not origin is Vector3 and not str(beat.target).is_empty():
		origin = _resolve_pos(str(beat.target))
		if _actors.has(str(beat.target)) and origin is Vector3:
			origin = (origin as Vector3) + Vector3.UP * (ACTOR_HEAD - 1.0)
	narrative.call("submit_bark", speaker_id, label, str(args.line),
		origin if origin is Vector3 else null,
		float(args.get("ttl", 1.5)), float(args.get("cooldown", args.get("cooldown_per_speaker", 4.0))))


func _op_foley(beat: Dictionary) -> void:
	var args: Dictionary = beat.args
	var sound := str(args.sound)
	var pitch := float(args.get("pitch", 1.0))
	if bool(args.get("2d", false)):
		_sound_2d(sound, pitch, float(args.get("vol_db", -6.0)))
		return
	var pos: Variant = _beat_pos(beat)
	if pos is Vector3:
		_sound_at(sound, pos, pitch, float(args.get("max_dist", 30.0)), float(args.get("vol_db", -6.0)))
	else:
		_sound_2d(sound, pitch, float(args.get("vol_db", -6.0)))


func _op_commit(beat: Dictionary) -> void:
	var args: Dictionary = beat.args
	var action := str(args.get("action", ""))
	if not action.is_empty():
		var cb: Variant = _commits.get(action, null)
		if cb is Callable and (cb as Callable).is_valid():
			var callable: Callable = cb
			if args.has("payload") and callable.get_argument_count() >= 1:
				callable.call(args.payload)
			else:
				callable.call()
		else:
			_diagnose("[%s] commit action '%s' is not registered" % [_chapter, action])
	var state_changes: Variant = args.get("state", {})
	if state_changes is Dictionary:
		for k: Variant in (state_changes as Dictionary).keys():
			_state[k] = state_changes[k]
	var world_changes: Variant = args.get("story_world", {})
	if world_changes is Dictionary:
		var world := _story_world()
		for k: Variant in (world_changes as Dictionary).keys():
			world[k] = world_changes[k]
	var g: Object = _g()
	var journal: Variant = args.get("journal", null)
	if journal is Dictionary and g != null and g.has_method("_story_event"):
		g.call("_story_event", str(journal.get("id", "")), str(journal.get("title", "")), str(journal.get("body", "")), str(journal.get("message", "")))
	var flags: Variant = args.get("flags", [])
	if flags is Array and g != null:
		var story_flags: Variant = g.get("story_flags")
		if story_flags is Array:
			for f: Variant in flags:
				if not (story_flags as Array).has(str(f)):
					(story_flags as Array).append(str(f))


# --- bells, resonance, shake -------------------------------------------------

func get_resonance_pulse() -> float:
	var strength := 0.0
	for m: Dictionary in _motions:
		if str(m.kind) == "pulse":
			strength = maxf(strength, float(m.get("value", 0.0)))
	return strength


func _op_bell_toll(job: Dictionary, beat: Dictionary) -> void:
	var args: Dictionary = beat.args
	var period := float(args.get("period", 0.0))
	var loop_id := str(args.get("loop_id", job.spec.id))
	_do_toll(args, str(beat.target))
	if period > 0.05:
		for m: Dictionary in _motions:
			if str(m.kind) == "toll_loop" and str(m.loop_id) == loop_id:
				m.done = true
		var remaining := int(args.get("count", -1)) - 1
		if remaining != 0:
			_motions.append({
				"kind": "toll_loop", "loop_id": loop_id, "period": period, "t": 0.0,
				"args": args, "emitter": str(beat.target), "owner": -1, "remaining": remaining,
			})


func _do_toll(args: Dictionary, emitter_id: String) -> void:
	var mode := str(args.get("mode", "lull"))
	var color: Color = TOLL_COLORS.get(mode, TOLL_COLORS.lull)
	var pos: Variant = _resolve_pos(emitter_id) if not emitter_id.is_empty() else null
	if not pos is Vector3:
		pos = _resolve_pos(str(args.get("emitter", "")))
	if not pos is Vector3:
		var p := _player()
		pos = p.global_position + Vector3(0, 12, -30) if p != null else Vector3.ZERO
	var emitter: Vector3 = pos
	var max_dist := float(args.get("max_dist", 90.0))
	match mode:
		"lull":
			_sound_at("bell", emitter, float(args.get("pitch", 0.62)), max_dist)
		"inverted":
			if _has_sound("bell_crack"):
				_sound_at("bell_crack", emitter, float(args.get("pitch", 1.0)), max_dist)
			else:
				_sound_at("bell", emitter, float(args.get("pitch", 0.48)), max_dist)
		_:
			_sound_at("bell", emitter, float(args.get("pitch", 1.0)), maxf(max_dist * 0.5, 20.0))
	if is_instance_valid(_level):
		Visuals.spawn_impact_light(_level, emitter, color, 3.2 if mode != "local" else 2.0, 14.0, 0.6)
	var crack := str(args.get("pulse_crack", ""))
	if not crack.is_empty():
		var node := _resolve_node(crack)
		if node != null:
			_pulse_glow(node, color, 2.6, 1.3)
	var vessels: Variant = args.get("pulse_vessels", [])
	if vessels is String:
		vessels = [vessels]
	if vessels is Array:
		for v: Variant in vessels:
			var node := _resolve_node(str(v))
			if node != null:
				_pulse_glow(node, color, 1.8, 1.1)
	var motes: Variant = args.get("motes", args.get("hollowing_motes", []))
	if motes is Array and mode == "inverted":
		for actor_id: Variant in motes:
			_spawn_motes_for(str(actor_id), args.get("motes_dir", Vector3.FORWARD), float(args.get("motes_duration", 2.4)))
	if bool(args.get("shake", mode == "inverted")):
		_story_shake(float(args.get("shake_amount", 0.05)), emitter)
	_last_bell_toll_age = 0.0
	bell_tolled.emit(mode, emitter)


func _op_resonance(job: Dictionary, beat: Dictionary) -> void:
	var args: Dictionary = beat.args
	var pos: Variant = _beat_pos(beat)
	if not pos is Vector3:
		return
	var origin: Vector3 = pos
	if _has_sound("resonance_wave"):
		_sound_at("resonance_wave", origin, float(args.get("pitch", 1.0)), 60.0)
	else:
		_sound_at("bell", origin, 0.42, 60.0)
	var ring: MeshInstance3D = null
	if is_instance_valid(_level):
		ring = MeshInstance3D.new()
		ring.name = "resonance_front"
		var torus := TorusMesh.new()
		torus.inner_radius = 0.92
		torus.outer_radius = 1.0
		torus.rings = 48
		torus.ring_segments = 4
		ring.mesh = torus
		ring.material_override = _fx_material(Color(str(args.get("color", "9ad8ff"))), 0.55)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_level.add_child(ring)
		ring.global_position = origin + Vector3.UP * 0.4
		ring.scale = Vector3.ONE * 0.1
		_dust(origin, Vector3.UP, "stone", _event_seed(job, beat))
	_own(job, {
		"kind": "front", "origin": origin, "r": 0.0, "radius": float(args.get("radius", 24.0)),
		"speed": maxf(float(args.get("speed", 14.0)), 0.5), "strength": clampf(float(args.get("strength", 0.6)), 0.0, 1.0),
		"ring": ring, "hit": false,
	})


func _story_shake(amount: float, origin: Variant = null) -> void:
	var g: Object = _g()
	if g == null:
		return
	var a := clampf(amount, 0.0, STORY_SHAKE_CAP)
	var p := _player()
	if origin is Vector3 and p != null:
		var d := p.global_position.distance_to(origin)
		a *= clampf(1.0 - d / 40.0, 0.2, 1.0)
	if g.has_method("add_story_shake"):
		g.call("add_story_shake", a)
		return
	var current: Variant = g.get("camera_shake")
	if current is float:
		g.set("camera_shake", maxf(float(current), a))


func _apply_resonance_pulse(value: float) -> void:
	var g: Object = _g()
	if g == null:
		return
	if g.has_method("set_resonance_pulse"):
		g.call("set_resonance_pulse", value)
		return
	var mat: Variant = g.get("resonance_material")
	if not mat is ShaderMaterial:
		var rect: Variant = g.get("resonance_rect")
		if rect is CanvasItem and is_instance_valid(rect):
			mat = (rect as CanvasItem).material
	if mat is ShaderMaterial:
		_call_static(Visuals, "set_resonance_pulse", [mat, value])


# --- collapses ------------------------------------------------------------------

func _op_rockfall(job: Dictionary, beat: Dictionary) -> void:
	var args: Dictionary = beat.args
	var fracture := _resolve_node(str(beat.target))
	if fracture == null:
		return
	var settled := _resolve_node(str(args.get("settled", "")))
	var seed_value := int(args.get("seed", _event_seed(job, beat)))
	var count := clampi(int(args.get("count", 12)), 0, MAX_DEBRIS)
	var center := _node_center(fracture)
	var used_builder := false
	if is_instance_valid(_level):
		var result: Variant = _call_static(LevelBuilder, "trigger_rockfall", [_level, fracture, settled, seed_value, count], true)
		if result is Array:
			used_builder = true
			for body: Variant in result:
				if body is Node3D:
					_track_debris(body, 10.0)
	if not used_builder:
		var extent := _node_extent(fracture)
		_set_node_active(fracture, false)
		_spawn_debris(center, extent, count, seed_value, _first_material(fracture))
	if settled != null:
		_gate_collision(job, settled)
	_sound_at("collapse" if _has_sound("collapse") else "maul", center, float(args.get("pitch", 0.8)), 45.0)
	_dust(center, Vector3.UP, "stone", seed_value)
	_story_shake(float(args.get("shake", 0.1)), center)
	var key := str(args.get("state_key", ""))
	if not key.is_empty():
		_story_world()[key] = true


func _op_chandelier(job: Dictionary, beat: Dictionary) -> void:
	var args: Dictionary = beat.args
	var suspended := _resolve_node(str(beat.target))
	if suspended == null or not is_instance_valid(_level):
		return
	var wreck := _resolve_node(str(args.get("wreck", "")))
	var seed_value := int(args.get("seed", _event_seed(job, beat)))
	var start := _node_center(suspended)
	var body: RigidBody3D = null
	var result: Variant = _call_static(LevelBuilder, "drop_chandelier", [_level, suspended, wreck, seed_value], true)
	if result is RigidBody3D:
		body = result
		# The director owns the impact transaction and the wreck swap (with clearance).
		body.set_meta("auto_settle", false)
	else:
		body = _make_falling_body(suspended, float(args.get("radius", 1.1)), 60.0)
	_sound_at("lever", start, 0.55, 40.0)
	var impact_pos: Variant = _resolve_pos(str(args.get("impact_mark", "")))
	if not impact_pos is Vector3 and wreck != null:
		impact_pos = _node_center(wreck)
	var motion := {
		"kind": "contact", "body": body, "t": 0.0, "deadline": float(args.get("timeout", 1.8)),
		"hit": false, "hit_pos": impact_pos, "fallback_pos": impact_pos if impact_pos is Vector3 else start + Vector3.DOWN * 6.0,
		"style": "chandelier", "wreck": wreck, "args": args, "seq_id": str(job.spec.id), "seed": seed_value,
	}
	_watch_contact(body, motion)
	_own(job, motion)


func _op_bell_drop(job: Dictionary, beat: Dictionary) -> void:
	var args: Dictionary = beat.args
	var bell := _resolve_node(str(beat.target))
	if bell == null or not is_instance_valid(_level):
		return
	var body := _make_falling_body(bell, float(args.get("radius", 1.6)), 240.0)
	var floor_node := _resolve_node(str(args.get("floor", "")))
	var fallback: Variant = _resolve_pos(str(args.get("impact_mark", "")))
	if not fallback is Vector3:
		fallback = _node_center(floor_node) if floor_node != null else _node_center(bell) + Vector3.DOWN * 4.0
	var motion := {
		"kind": "contact", "body": body, "t": 0.0, "deadline": float(args.get("timeout", 2.5)),
		"hit": false, "hit_pos": null, "fallback_pos": fallback, "style": "bell", "floor": floor_node,
		"args": args, "seq_id": str(job.spec.id), "seed": int(args.get("seed", _event_seed(job, beat))),
	}
	_watch_contact(body, motion)
	_own(job, motion)


func _make_falling_body(visual: Node3D, radius: float, mass: float) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = "story_falling_" + str(visual.name)
	body.collision_layer = LAYER_DEBRIS
	body.collision_mask = LAYER_WORLD
	body.mass = mass
	body.continuous_cd = true
	body.contact_monitor = true
	body.max_contacts_reported = 4
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = maxf(radius, 0.2)
	shape.shape = sphere
	body.add_child(shape)
	_level.add_child(body)
	body.global_transform = Transform3D(Basis(), _node_center(visual))
	for cs: Node in _collision_shapes(visual):
		(cs as CollisionShape3D).set_deferred("disabled", true)
	visual.reparent(body, true)
	return body


func _watch_contact(body: RigidBody3D, motion: Dictionary) -> void:
	if body == null:
		return
	body.contact_monitor = true
	body.max_contacts_reported = maxi(body.max_contacts_reported, 4)
	var gen := _generation
	if body.has_user_signal("chandelier_impact"):
		body.connect("chandelier_impact", func(point: Vector3) -> void:
			if gen != _generation or bool(motion.hit):
				return
			motion.hit = true
			motion.hit_pos = point
		)
		return
	body.body_entered.connect(func(other: Node) -> void:
		if gen != _generation or bool(motion.hit) or other == _player():
			return
		var floor_node: Variant = motion.get("floor", null)
		if floor_node is Node and is_instance_valid(floor_node) and other != floor_node and not (floor_node as Node).is_ancestor_of(other):
			if not other is StaticBody3D:
				return
		motion.hit = true
		if is_instance_valid(body):
			motion.hit_pos = body.global_position
	)


func _resolve_impact(m: Dictionary) -> void:
	var body: Variant = m.body
	var pos: Vector3 = m.fallback_pos
	if m.hit_pos is Vector3:
		pos = m.hit_pos
	elif body is Node3D and is_instance_valid(body):
		pos = (body as Node3D).global_position
	var args: Dictionary = m.args
	var seed_value := int(m.get("seed", 0))
	_sound_at("collapse" if _has_sound("collapse") else "maul", pos, float(args.get("pitch", 0.9 if str(m.style) == "chandelier" else 0.6)), 50.0)
	_dust(pos, Vector3.UP, "stone", seed_value)
	_story_shake(float(args.get("shake", 0.12)), pos)
	if is_instance_valid(_level):
		Visuals.spawn_impact_light(_level, pos + Vector3.UP * 0.5, Color("ffb35c"), 4.0, 9.0, 0.35)
	var seq_id := str(m.get("seq_id", ""))
	beat_applied.emit(seq_id, str(args.get("impact_beat", "impact")))
	var action := str(args.get("commit", ""))
	if not action.is_empty():
		_op_commit({"args": {"action": action}})
	var key := str(args.get("state_key", ""))
	if not key.is_empty():
		_story_world()[key] = true
	if str(m.style) == "chandelier":
		var wreck: Variant = m.get("wreck", null)
		if body is RigidBody3D and is_instance_valid(body) and (body as Node).has_meta("settled") and not _method_info(LevelBuilder, "settle_chandelier").is_empty():
			_call_static(LevelBuilder, "settle_chandelier", [body])
		elif body is Node3D and is_instance_valid(body):
			(body as Node3D).queue_free()
		if wreck is Node3D and is_instance_valid(wreck):
			(wreck as Node3D).visible = true
			var owner_job: Dictionary = _jobs_by_serial.get(int(m.get("owner", -1)), {})
			_gate_collision(owner_job, wreck)
		beat_applied.emit(seq_id, str(args.get("settled_beat", "settled")))
	elif body is RigidBody3D and is_instance_valid(body):
		var rb := body as RigidBody3D
		rb.set_deferred("freeze", true)
		for cs: Node in _collision_shapes(rb):
			(cs as CollisionShape3D).set_deferred("disabled", true)
		_motions.append({"kind": "sink", "node": rb, "t": 0.0, "delay": 0.6, "duration": 2.5,
			"depth": float(args.get("sink_depth", 14.0)), "from": rb.global_position, "owner": -1})


## Bring a settled/wreck collider online only once the player capsule is clear.
func _gate_collision(job: Dictionary, node: Node3D) -> void:
	node.visible = true
	if not _player_overlaps_node(node):
		_set_node_active(node, true)
		return
	_set_collision_enabled(node, false)
	var motion := {"kind": "clear", "node": node, "t": 0.0, "timeout": 6.0}
	if job.is_empty():
		motion["owner"] = -1
		_motions.append(motion)
	else:
		_own(job, motion)


# --- actors ----------------------------------------------------------------------

func _op_walk(job: Dictionary, beat: Dictionary) -> void:
	var args: Dictionary = beat.args
	var actor_id := str(beat.target)
	var actor: Variant = _actors.get(actor_id, null)
	if actor == null or not is_instance_valid(actor.holder):
		return
	var refs: Array = []
	if args.get("route") is Array:
		refs.append_array(args.route)
	if args.has("mark"):
		refs.append(args.mark)
	var points: Array[Vector3] = []
	var final_mark := ""
	for r: Variant in refs:
		var p: Variant = _resolve_pos(r)
		if p is Vector3:
			points.append(p)
			if r is String:
				final_mark = str(r)
	if points.is_empty():
		return
	var speed_arg: Variant = args.get("speed", "walk")
	var speed := float(SPEED_PRESETS.get(speed_arg, 1.3)) if speed_arg is String else float(speed_arg)
	for m: Dictionary in _motions:
		if str(m.kind) == "walk" and str(m.actor) == actor_id:
			m.done = true
	var final_yaw: Variant = null
	if args.has("face_yaw"):
		final_yaw = float(args.face_yaw)
	elif not final_mark.is_empty() and _marks.has(final_mark) and bool(args.get("face_mark", true)):
		final_yaw = float(_marks[final_mark].yaw)
	_own(job, {
		"kind": "walk", "actor": actor_id, "points": points, "idx": 0, "speed": maxf(speed, 0.05),
		"final_yaw": final_yaw, "final_mark": final_mark, "state_key": str(args.get("state_key", actor_id + "_mark")),
		"blocked_t": 0.0, "t": 0.0, "animation": str(args.get("animation", "")),
	})


func _op_gesture(job: Dictionary, beat: Dictionary) -> void:
	var args: Dictionary = beat.args
	var actor: Variant = _actors.get(str(beat.target), null)
	if actor == null:
		return
	var gesture := str(args.get("name", args.get("pose", args.get("gesture", "beckon"))))
	var duration := float(args.get("duration", 1.2))
	var rig: Variant = actor.rig
	if rig is Node3D and is_instance_valid(rig):
		var r := rig as Node3D
		r.set_meta("gesture", gesture)
		r.set_meta("gesture_time", duration)
		_call_static(Meshes3D, "play_npc_gesture", [r, gesture, duration])
		var anim := r.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if anim != null and anim.has_animation(gesture):
			anim.play(gesture)
	if duration > 0.0 and not bool(args.get("hold", false)):
		_own(job, {"kind": "gesture", "actor": str(beat.target), "t": 0.0, "duration": duration, "gesture": gesture})


func _op_look_at(job: Dictionary, beat: Dictionary) -> void:
	var args: Dictionary = beat.args
	var actor_id := str(beat.target)
	if not _actors.has(actor_id):
		return
	for m: Dictionary in _motions:
		if str(m.kind) == "turn" and str(m.actor) == actor_id:
			m.done = true
	_own(job, {"kind": "turn", "actor": actor_id, "at": args.get("at", "$player"), "t": 0.0,
		"duration": maxf(float(args.get("duration", 0.6)), 0.05), "rate": float(args.get("rate", 7.0))})


func _op_vanish(beat: Dictionary) -> void:
	var args: Dictionary = beat.args
	var actor_id := str(beat.target)
	var actor: Variant = _actors.get(actor_id, null)
	if actor == null:
		return
	var holder: Node3D = actor.holder
	if is_instance_valid(holder):
		var pos := holder.global_position + Vector3.UP * 1.2
		if bool(args.get("fx", true)):
			var color := Color(str(args.get("color", "ca90f7")))
			var g: Object = _g()
			if g != null and g.has_method("_spell_impact"):
				g.call("_spell_impact", pos, color, Vector3.UP)
			elif is_instance_valid(_level):
				Visuals.spawn_impact_light(_level, pos, color, 3.0, 7.0, 0.5)
			_spawn_particles(pos, color, 48, 1.4, Vector3.UP, 2.2, 0.0, 0.8)
		var sound := str(args.get("sound", "cast"))
		if not sound.is_empty():
			_sound_at(sound, pos, float(args.get("pitch", 0.62)), 30.0)
		_remove_npc_entry(holder)
		holder.visible = false
		for cs: Node in _collision_shapes(holder):
			(cs as CollisionShape3D).set_deferred("disabled", true)
		holder.queue_free()
	_actors.erase(actor_id)
	for m: Dictionary in _motions:
		if str(m.get("actor", "")) == actor_id:
			m.done = true
	var key := str(args.get("state_key", ""))
	if not key.is_empty():
		_story_world()[key] = true


func _remove_npc_entry(holder: Node3D) -> void:
	var g: Object = _g()
	if g == null:
		return
	var npcs: Variant = g.get("npc_nodes")
	if not npcs is Array:
		return
	var arr := npcs as Array
	for i in range(arr.size() - 1, -1, -1):
		var entry: Variant = arr[i]
		if entry is Dictionary and (entry as Dictionary).get("node") == holder:
			arr.remove_at(i)


func _set_hollowing(actor_id: String, stage: int) -> void:
	var actor: Variant = _actors.get(actor_id, null)
	if actor == null:
		return
	stage = clampi(stage, 0, 4)
	actor.hollowing = stage
	var rig: Variant = actor.rig
	if rig is Node3D and is_instance_valid(rig):
		(rig as Node3D).set_meta("hollowing_stage", stage)
		_call_static(Meshes3D, "set_npc_hollowing", [rig, stage])
	var holder: Node3D = actor.holder
	if is_instance_valid(holder):
		for child: Node in holder.get_children():
			if child is OmniLight3D:
				(child as OmniLight3D).light_energy = lerpf(1.8, 0.3, float(stage) / 4.0)
	_story_world()[actor_id + "_hollowing"] = stage


func _animate_actor(actor: Dictionary, speed: float) -> void:
	var rig: Variant = actor.rig
	if not rig is Node3D or not is_instance_valid(rig):
		return
	(rig as Node3D).set_meta("walk_speed", speed)
	var info := _method_info(Meshes3D, "animate_npc_rig")
	if info.is_empty():
		return
	var gesture := str((rig as Node3D).get_meta("gesture", ""))
	if int(info.total) >= 5:
		_call_static(Meshes3D, "animate_npc_rig", [rig, _clock, false, speed, gesture])
	elif int(info.total) >= 4:
		_call_static(Meshes3D, "animate_npc_rig", [rig, _clock, false, speed])
	else:
		_call_static(Meshes3D, "animate_npc_rig", [rig, _clock, false])


# --- lights, bodies, wind ------------------------------------------------------

func _resolve_lights(group: String) -> Array[Light3D]:
	var out: Array[Light3D] = []
	for l: Variant in _light_groups.get(group, []):
		if l is Light3D and is_instance_valid(l):
			out.append(l)
	var g: Object = _g()
	if g != null and (group == "all" or group == "crypt"):
		var src: Variant = g.get("torches" if group == "all" else "crypt_torches")
		if src is Array:
			for l: Variant in src:
				if l is Light3D and is_instance_valid(l) and not out.has(l):
					out.append(l)
	if is_inside_tree():
		for n: Node in get_tree().get_nodes_in_group("story_torch_" + group):
			if n is Light3D and not out.has(n) and (not is_instance_valid(_level) or _level.is_ancestor_of(n)):
				out.append(n)
	return out


func _op_torch_group(job: Dictionary, beat: Dictionary) -> void:
	var args: Dictionary = beat.args
	var group := str(args.group)
	var lights := _resolve_lights(group)
	if lights.is_empty():
		return
	for m: Dictionary in _motions:
		if str(m.kind) == "torch" and str(m.group) == group:
			_release_owner(m)
			m.done = true
	var from_scales: Array[float] = []
	var phases: Array[float] = []
	var rng := _event_rng(str(job.spec.id) + "/" + str(beat.id), int(beat.order))
	for l: Light3D in lights:
		if not l.has_meta("story_base_energy"):
			l.set_meta("story_base_energy", l.light_energy)
		from_scales.append(get_torch_scale(l))
		phases.append(rng.randf_range(0.0, TAU))
	_own(job, {
		"kind": "torch", "group": group, "lights": lights, "from": from_scales, "phases": phases,
		"to": maxf(float(args.get("scale", 1.0)), 0.0), "t": 0.0,
		"duration": maxf(float(args.get("duration", 0.3)), 0.0), "flicker": clampf(float(args.get("flicker", 0.0)), 0.0, 1.0),
	})


func _op_move_body(job: Dictionary, beat: Dictionary) -> void:
	var args: Dictionary = beat.args
	var node := _resolve_node(str(beat.target))
	if node == null:
		return
	var from := node.global_position
	var to: Vector3 = from
	if args.get("end_pos") is Vector3:
		to = args.end_pos
	elif args.has("end_mark"):
		var p: Variant = _resolve_pos(args.end_mark)
		if p is Vector3:
			to = p
	elif args.get("offset") is Vector3:
		to = from + (args.offset as Vector3)
	if node is AnimatableBody3D:
		(node as AnimatableBody3D).sync_to_physics = true
	for m: Dictionary in _motions:
		if str(m.kind) == "move" and m.node == node:
			_release_owner(m)
			m.done = true
	var cue := str(args.get("cue", ""))
	if not cue.is_empty():
		_sound_at(cue, from, float(args.get("pitch", 1.0)), 40.0)
	var duration := float(args.get("duration", 0.0))
	if args.has("speed") and float(args.speed) > 0.0:
		duration = from.distance_to(to) / float(args.speed)
	_own(job, {
		"kind": "move", "node": node, "from": from, "to": to, "t": 0.0, "duration": maxf(duration, 0.0),
		"disable_collision": bool(args.get("disable_collision", false)), "commit": str(args.get("commit", "")),
		"ease": str(args.get("ease", "inout")),
	})


func _op_wind(job: Dictionary, beat: Dictionary) -> void:
	var args: Dictionary = beat.args
	var dir: Vector3 = args.dir
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	_own(job, {"kind": "wind", "dir": dir.normalized(), "accel": clampf(float(args.get("accel", 3.0)), 0.0, 20.0),
		"t": 0.0, "duration": maxf(float(args.get("duration", 2.0)), 0.05)})


# --- environmental fx -------------------------------------------------------------

func _op_fissure(job: Dictionary, beat: Dictionary) -> void:
	var args: Dictionary = beat.args
	var target := _resolve_node(str(beat.target))
	if target == null:
		return
	var color := Color(str(args.get("color", "b07cff")))
	var branches := clampi(int(args.get("branches", 4)), 1, 12)
	var grow := maxf(float(args.get("grow_time", 1.2)), 0.05)
	if is_instance_valid(_level) and not _method_info(LevelBuilder, "add_fissure").is_empty():
		var size: Vector2 = args.get("size", Vector2(2.4, 2.2))
		var built: Variant = _call_static(LevelBuilder, "add_fissure", [_level, _node_center(target) + (args.get("offset", Vector3.ZERO) as Vector3), target.global_rotation.y, size, color])
		if built is Node3D:
			var seam := built as Node3D
			var full := seam.scale
			seam.scale = Vector3(full.x, full.y * 0.02, full.z)
			var grow_tw := seam.create_tween()
			grow_tw.tween_property(seam, "scale", full, grow).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_sound_at("frost", _node_center(target), 0.55, 30.0)
			return
	var rng := _event_rng(str(job.spec.id) + "/" + str(beat.id), int(args.get("seed", 0)))
	var holder := Node3D.new()
	holder.name = "story_fissure"
	target.add_child(holder)
	holder.position = Vector3(0, 0, float(args.get("depth_offset", 0.0)))
	var mat := _fx_material(color, 0.95)
	for i in branches:
		var seam := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		var length := rng.randf_range(0.8, 2.4)
		mesh.size = Vector3(0.05, length, 0.04)
		seam.mesh = mesh
		seam.material_override = mat
		seam.position = Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.2, 0.6), 0.02)
		seam.rotation.z = rng.randf_range(-1.1, 1.1)
		seam.scale = Vector3(1, 0.01, 1)
		holder.add_child(seam)
		var tw := seam.create_tween()
		tw.tween_interval(rng.randf_range(0.0, grow * 0.4))
		tw.tween_property(seam, "scale:y", 1.0, grow).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_sound_at("frost", _node_center(target), 0.55, 30.0)


func _op_ward_chain(job: Dictionary, beat: Dictionary) -> void:
	var args: Dictionary = beat.args
	var ward_id := str(args.ward)
	match str(args.get("action", "spawn")):
		"snap":
			snap_ward_chain(ward_id)
		"reanchor":
			var p: Variant = _resolve_pos(args.get("to", "$player"))
			if p is Vector3:
				if ward_id == "*" or ward_id == "all":
					reanchor_ward_chains(p)
				elif _ward_chains.has(ward_id) and is_instance_valid(_ward_chains[ward_id]):
					var chain: Node3D = _ward_chains[ward_id]
					chain.set_meta("target", p)
					_build_chain_links(chain, chain.get_meta("anchor"), p, chain.get_meta("color", TOLL_COLORS.inverted))
		_:
			if not is_instance_valid(_level):
				return
			var from: Variant = _resolve_pos(args.get("from", str(beat.target)))
			var to: Variant = _resolve_pos(args.get("to", ""))
			if not from is Vector3 or not to is Vector3:
				return
			if _ward_chains.has(ward_id) and is_instance_valid(_ward_chains[ward_id]):
				(_ward_chains[ward_id] as Node3D).queue_free()
			var chain := Node3D.new()
			chain.name = "ward_chain_" + ward_id
			_level.add_child(chain)
			chain.global_position = from
			var color := Color(str(args.get("color", "b07cff")))
			chain.set_meta("anchor", from)
			chain.set_meta("target", to)
			chain.set_meta("color", color)
			_ward_chains[ward_id] = chain
			_build_chain_links(chain, from, to, color)
			for c: Node in chain.get_children():
				(c as Node3D).visible = false
			_own(job, {"kind": "whip", "chain": chain, "t": 0.0, "duration": float(args.get("whip", 0.4))})
			_sound_at("voltaic", from, 0.7, 30.0)


func _build_chain_links(chain: Node3D, a: Vector3, b: Vector3, color: Color) -> void:
	for c: Node in chain.get_children():
		if c is MeshInstance3D:
			c.queue_free()
	var span := b - a
	var dist := span.length()
	if dist < 0.05 or not chain.is_inside_tree():
		return
	var dir := span / dist
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var count := clampi(int(dist / 0.3), 2, 72)
	var mat := _fx_material(color, 0.9)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.11, 0.035, minf(0.3, dist / float(count) * 1.15))
	var inv := chain.global_transform.affine_inverse()
	for i in count:
		var link := MeshInstance3D.new()
		link.name = "link_%d" % i
		link.mesh = mesh
		link.material_override = mat
		link.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var p := a + span * ((float(i) + 0.5) / float(count))
		var basis := Basis.looking_at(dir, up)
		if i % 2 == 1:
			basis = basis * Basis(Vector3.FORWARD, PI * 0.5)
		link.transform = inv * Transform3D(basis, p)
		chain.add_child(link)


func _op_seal_ripple(beat: Dictionary) -> void:
	var args: Dictionary = beat.args
	var seal := _resolve_node(str(beat.target))
	if seal == null:
		return
	var color := Color(str(args.get("color", "b07cff")))
	var pos: Variant = _resolve_pos(args.get("at", ""))
	if not pos is Vector3:
		pos = _node_center(seal)
	if is_instance_valid(_level):
		Visuals.spawn_impact_light(_level, pos, color, 3.6, 8.0, 0.5)
	_spawn_particles(pos, color, 40, 0.9, Vector3.UP, 1.4, 0.0, 0.5)
	for mi: Node in _meshes(seal, 12):
		var mesh := mi as MeshInstance3D
		var base := mesh.scale
		var tw := mesh.create_tween()
		tw.tween_property(mesh, "scale", base * Vector3(1.0, 1.0, 1.6), 0.12)
		tw.tween_property(mesh, "scale", base * Vector3(1.0, 1.0, 0.8), 0.18)
		tw.tween_property(mesh, "scale", base, 0.25)
		var shader_mat := mesh.material_override as ShaderMaterial
		if shader_mat != null:
			shader_mat.set_shader_parameter("ripple", 1.0)
	_sound_at("portal" if _has_sound("portal") else "cast", pos, 0.7, 25.0)


func _op_motes(job: Dictionary, beat: Dictionary) -> void:
	var args: Dictionary = beat.args
	var target_id := str(args.get("actor", beat.target))
	_spawn_motes_for(target_id, args.get("target_dir", args.get("dir", Vector3.FORWARD)), float(args.get("duration", 2.4)), _event_seed(job, beat))


func _spawn_motes_for(target_id: String, dir_ref: Variant, duration: float, seed_value: int = 0) -> void:
	var pos: Variant = _resolve_pos(target_id)
	if not pos is Vector3 or not is_instance_valid(_level):
		return
	var head: Vector3 = pos
	if _actors.has(target_id):
		head = (_actors[target_id].holder as Node3D).global_position + Vector3.UP * ACTOR_HEAD
	var dir := Vector3.FORWARD
	if dir_ref is Vector3 and (dir_ref as Vector3).length_squared() > 0.0001:
		dir = (dir_ref as Vector3).normalized()
	else:
		var p: Variant = _resolve_pos(dir_ref)
		if p is Vector3 and head.distance_to(p) > 0.1:
			dir = head.direction_to(p)
	var made: Variant = _call_static(Visuals, "spawn_hollowing_motes", [_level, head, dir, duration, seed_value], true)
	if made == null:
		_spawn_particles(head, Color("b07cff"), 36, 2.2, (dir + Vector3.UP).normalized(), 0.8, -0.2, duration)


func _op_name_stream(job: Dictionary, beat: Dictionary) -> void:
	var args: Dictionary = beat.args
	var from: Variant = _resolve_pos(args.get("from", str(beat.target)))
	var to: Variant = _resolve_pos(args.get("to", ""))
	if not from is Vector3 or not to is Vector3 or not is_instance_valid(_level):
		return
	var duration := float(args.get("duration", 3.0))
	var stream_color := Color(str(args.get("color", "d8c8ff")))
	var made: Variant = _call_static(Visuals, "spawn_name_stream", [_level, from, to, duration, stream_color], true)
	if made == null:
		var a: Vector3 = from
		var b: Vector3 = to
		var dir := a.direction_to(b) if a.distance_to(b) > 0.01 else Vector3.UP
		_spawn_particles(a, Color(str(args.get("color", "c8a7fe"))), 64, clampf(a.distance_to(b) / 3.0, 0.6, 4.0), dir, 0.15, 0.0, duration, 3.0)


func _op_glyph_drift(job: Dictionary, beat: Dictionary) -> void:
	var args: Dictionary = beat.args
	var pos: Variant = _beat_pos(beat)
	if not pos is Vector3 or not is_instance_valid(_level):
		return
	var extents: Vector3 = args.get("extents", Vector3(3, 2, 3))
	var duration := float(args.get("duration", 6.0))
	var glyph_color := Color(str(args.get("color", "e5dcff")))
	var made: Variant = _call_static(Visuals, "spawn_glyph_drift", [_level, pos, int(args.get("count", 16)), duration, glyph_color], true)
	if made == null:
		_spawn_particles(pos, Color(str(args.get("color", "c8a7fe"))), 48, 3.0, Vector3.UP, 1.5, -0.05, duration, 0.4)


func _op_pour_stream(job: Dictionary, beat: Dictionary) -> void:
	var args: Dictionary = beat.args
	var from: Variant = _resolve_pos(args.get("from", str(beat.target)))
	var to: Variant = _resolve_pos(args.get("to", ""))
	if not from is Vector3 or not to is Vector3 or not is_instance_valid(_level):
		return
	var a: Vector3 = from
	var b: Vector3 = to
	var length := a.distance_to(b)
	if length < 0.05:
		return
	var color := Color(str(args.get("color", "ff7a2a")))
	var duration := maxf(float(args.get("duration", 2.0)), 0.2)
	var stream := MeshInstance3D.new()
	stream.name = "story_pour_stream"
	var cyl := CylinderMesh.new()
	cyl.top_radius = float(args.get("radius", 0.12))
	cyl.bottom_radius = cyl.top_radius * 1.3
	cyl.height = length
	cyl.radial_segments = 10
	stream.mesh = cyl
	stream.material_override = _fx_material(color, 1.0, false)
	stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_level.add_child(stream)
	var dir := (b - a) / length
	var up := Vector3.FORWARD if absf(dir.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var x := up.cross(dir).normalized()
	stream.global_transform = Transform3D(Basis(x, dir, x.cross(dir)), (a + b) * 0.5)
	stream.scale = Vector3(0.05, 1, 0.05)
	var tw := stream.create_tween()
	tw.tween_property(stream, "scale", Vector3.ONE, 0.25)
	tw.tween_interval(duration)
	tw.tween_property(stream, "scale", Vector3(0.05, 1, 0.05), 0.4)
	tw.tween_callback(stream.queue_free)
	Visuals.spawn_impact_light(_level, b + Vector3.UP * 0.3, color, 2.6, 6.0, duration + 0.6)
	_sound_at(str(args.get("sound", "splash")), b, float(args.get("pitch", 0.7)), 30.0)
	_spawn_particles(b, color, 32, 0.8, Vector3.UP, 2.5, 1.0, duration, 1.8)
	_event_seed(job, beat)


func _op_slag_cascade(job: Dictionary, beat: Dictionary) -> void:
	var args: Dictionary = beat.args
	var pos: Variant = _beat_pos(beat)
	if not pos is Vector3 or not is_instance_valid(_level):
		return
	var color := Color(str(args.get("color", "ff5c1a")))
	var duration := float(args.get("duration", 2.5))
	var made: Variant = _call_static(Visuals, "spawn_dust_burst", [_level, pos, args.get("dir", Vector3.UP), "slag", _event_seed(job, beat)], true)
	if made == null:
		_spawn_particles(pos, color, 72, 1.6, args.get("dir", Vector3.UP), 0.9, 2.4, duration, 4.5)
	Visuals.spawn_impact_light(_level, pos + Vector3.UP * 0.5, color, 4.2, 10.0, duration)
	_sound_at(str(args.get("sound", "splash")), pos, float(args.get("pitch", 0.55)), 40.0)
	_story_shake(float(args.get("shake", 0.05)), pos)


func _dust(pos: Vector3, dir: Variant, kind: String, seed_value: int) -> void:
	if not is_instance_valid(_level):
		return
	var d: Vector3 = dir if dir is Vector3 else Vector3.UP
	var made: Variant = _call_static(Visuals, "spawn_dust_burst", [_level, pos, d, kind, seed_value], true)
	if made == null:
		_spawn_particles(pos, Color(0.72, 0.68, 0.6, 0.6), 48, 1.6, d, 1.4, 0.6, 0.4, 2.2)


func _pulse_tube(tube: Node3D, duration: float) -> void:
	var light: Light3D = null
	if tube.has_meta("mouth_light") and tube.get_meta("mouth_light") is Light3D:
		light = tube.get_meta("mouth_light")
	else:
		light = tube.find_child("*", true, false) as Light3D
		if light == null:
			for c: Node in tube.get_children():
				if c is Light3D:
					light = c
					break
	if light == null or not is_instance_valid(light):
		if is_instance_valid(_level):
			Visuals.spawn_impact_light(_level, _node_center(tube), Color("70d7df"), 1.4, 3.5, duration)
		return
	if not light.has_meta("story_base_energy"):
		light.set_meta("story_base_energy", light.light_energy)
	var base := float(light.get_meta("story_base_energy"))
	var tw := light.create_tween()
	tw.tween_property(light, "light_energy", base * 2.6 + 0.6, 0.15)
	tw.tween_interval(maxf(duration - 0.3, 0.1))
	tw.tween_property(light, "light_energy", base, 0.3)


func _pulse_glow(node: Node3D, color: Color, strength: float, duration: float) -> void:
	if is_instance_valid(_level):
		Visuals.spawn_impact_light(_level, _node_center(node), color, strength, 9.0, duration)
	var pulse: Variant = node.get_meta("pulse", null) if node.has_meta("pulse") else null
	if pulse is Callable and (pulse as Callable).is_valid():
		(pulse as Callable).call(strength, duration)
	for mi: Node in _meshes(node, 24):
		var mesh := mi as MeshInstance3D
		var mat := mesh.material_override as StandardMaterial3D
		if mat == null or not mat.emission_enabled:
			continue
		if not mesh.has_meta("story_pulse_mat"):
			mat = mat.duplicate() as StandardMaterial3D
			mesh.material_override = mat
			mesh.set_meta("story_pulse_mat", true)
			mesh.set_meta("story_pulse_base", mat.emission_energy_multiplier)
		var base := float(mesh.get_meta("story_pulse_base"))
		var tw := mesh.create_tween()
		tw.tween_property(mat, "emission_energy_multiplier", base + strength, 0.08)
		tw.tween_property(mat, "emission_energy_multiplier", base, duration)


# =============================================================================
# Motions
# =============================================================================

func _step_motions(delta: float) -> void:
	var gen := _generation
	for m: Dictionary in _motions.duplicate():
		if gen != _generation:
			return
		if bool(m.get("done", false)):
			continue
		if _step_motion(m, delta):
			m.done = true
			_release_owner(m)
	for i in range(_motions.size() - 1, -1, -1):
		if bool(_motions[i].get("done", false)):
			_release_owner(_motions[i])
			_motions.remove_at(i)


func _step_motion(m: Dictionary, delta: float) -> bool:
	m.t = float(m.get("t", 0.0)) + delta
	match str(m.kind):
		"walk":
			return _step_walk(m, delta)
		"turn":
			var actor: Variant = _actors.get(str(m.actor), null)
			if actor == null or not is_instance_valid(actor.holder):
				return true
			var holder: Node3D = actor.holder
			var p: Variant = _resolve_pos(m.at)
			if p is Vector3:
				var to: Vector3 = (p as Vector3) - holder.global_position
				to.y = 0.0
				if to.length_squared() > 0.0004:
					holder.rotation.y = lerp_angle(holder.rotation.y, atan2(-to.x, -to.z), minf(1.0, delta * float(m.rate)))
			return float(m.t) >= float(m.duration)
		"gesture":
			if float(m.t) < float(m.duration):
				return false
			var actor: Variant = _actors.get(str(m.actor), null)
			if actor != null and actor.rig is Node3D and is_instance_valid(actor.rig) and str((actor.rig as Node3D).get_meta("gesture", "")) == str(m.gesture):
				(actor.rig as Node3D).set_meta("gesture", "")
			return true
		"move":
			var node: Variant = m.node
			if not node is Node3D or not is_instance_valid(node):
				return true
			var k := 1.0 if float(m.duration) <= 0.0 else clampf(float(m.t) / float(m.duration), 0.0, 1.0)
			var e := k
			match str(m.ease):
				"inout":
					e = k * k * (3.0 - 2.0 * k)
				"in":
					e = k * k
				"out":
					e = 1.0 - (1.0 - k) * (1.0 - k)
			(node as Node3D).global_position = (m.from as Vector3).lerp(m.to, e)
			if k >= 1.0:
				if bool(m.disable_collision):
					_set_collision_enabled(node, false)
				if not str(m.commit).is_empty():
					_op_commit({"args": {"action": str(m.commit)}})
				return true
			return false
		"torch":
			var lights: Array = m.lights
			var k := 1.0 if float(m.duration) <= 0.0 else clampf(float(m.t) / float(m.duration), 0.0, 1.0)
			var flicker := float(m.flicker)
			for i in lights.size():
				var l: Variant = lights[i]
				if not l is Light3D or not is_instance_valid(l):
					continue
				var light := l as Light3D
				var s := lerpf(float(m.from[i]), float(m.to), k)
				var ph := float(m.phases[i])
				var noise := 0.0
				if flicker > 0.0 and k < 1.0:
					noise = (sin(_clock * 23.0 + ph) * 0.6 + sin(_clock * 41.0 + ph * 1.7) * 0.4) * flicker
				var applied := maxf(0.0, s * (1.0 + noise))
				light.set_meta("story_energy_scale", applied)
				light.light_energy = float(light.get_meta("story_base_energy", light.light_energy)) * applied
			if k >= 1.0:
				for l: Variant in lights:
					if l is Light3D and is_instance_valid(l):
						(l as Light3D).set_meta("story_energy_scale", float(m.to))
				return true
			return false
		"wind":
			var p := _player() as CharacterBody3D
			if p == null:
				return true
			var k := float(m.t) / float(m.duration)
			var env := sin(clampf(k, 0.0, 1.0) * PI)
			var dir: Vector3 = m.dir
			var along := Vector2(p.velocity.x, p.velocity.z).dot(Vector2(dir.x, dir.z))
			var add := float(m.accel) * env * delta
			if along + add > WIND_CAP:
				add = maxf(0.0, WIND_CAP - along)
			p.velocity += dir * add
			return k >= 1.0
		"front":
			return _step_front(m, delta)
		"pulse":
			var t := float(m.t)
			var v := 0.0
			if t < 0.06:
				v = t / 0.06
			elif t < 0.30:
				v = 1.0 - (t - 0.06) / 0.24
			m.value = v * float(m.strength)
			_apply_resonance_pulse(maxf(float(m.value), get_resonance_pulse()))
			if t >= 0.30:
				m.value = 0.0
				_apply_resonance_pulse(0.0)
				return true
			return false
		"contact":
			var body: Variant = m.body
			if bool(m.hit) or float(m.t) >= float(m.deadline) or not (body is Node3D and is_instance_valid(body)):
				_resolve_impact(m)
				return true
			return false
		"clear":
			var node: Variant = m.node
			if not node is Node3D or not is_instance_valid(node):
				return true
			if not _player_overlaps_node(node):
				_set_node_active(node, true)
				return true
			if float(m.t) > 0.4:
				var p := _player() as CharacterBody3D
				if p != null:
					var away := p.global_position - _node_center(node)
					away.y = 0.0
					if away.length_squared() < 0.0001:
						away = Vector3.RIGHT
					p.velocity += away.normalized() * 6.0 * delta
			return float(m.t) >= float(m.timeout)
		"sink":
			var node: Variant = m.node
			if not node is Node3D or not is_instance_valid(node):
				return true
			var t := float(m.t) - float(m.delay)
			if t <= 0.0:
				return false
			var k := clampf(t / float(m.duration), 0.0, 1.0)
			(node as Node3D).global_position = (m.from as Vector3) + Vector3.DOWN * float(m.depth) * k * k
			if k >= 1.0:
				(node as Node3D).queue_free()
				return true
			return false
		"whip":
			var chain: Variant = m.chain
			if not chain is Node3D or not is_instance_valid(chain):
				return true
			var links := (chain as Node3D).get_children()
			var k := 1.0 if float(m.duration) <= 0.0 else clampf(float(m.t) / float(m.duration), 0.0, 1.0)
			var shown := int(ceil(k * float(links.size())))
			for i in links.size():
				(links[i] as Node3D).visible = i < shown
			return k >= 1.0
		"toll_loop":
			if float(m.t) >= float(m.period):
				m.t = 0.0
				_do_toll(m.args, str(m.emitter))
				if int(m.remaining) > 0:
					m.remaining = int(m.remaining) - 1
					if int(m.remaining) == 0:
						return true
			return false
	return true


func _step_walk(m: Dictionary, delta: float) -> bool:
	var actor: Variant = _actors.get(str(m.actor), null)
	if actor == null or not is_instance_valid(actor.holder):
		return true
	var holder: Node3D = actor.holder
	var points: Array = m.points
	var idx := int(m.idx)
	if idx >= points.size():
		return _walk_arrive(m, actor)
	var target: Vector3 = points[idx]
	var speed := float(m.speed)
	var to := target - holder.global_position
	var flat := Vector3(to.x, 0.0, to.z)
	var step := speed * delta
	var body := holder as CharacterBody3D
	var dist := flat.length() if body != null else to.length()
	if dist <= maxf(step, 0.04):
		if body == null:
			holder.global_position = target
		m.idx = idx + 1
		if int(m.idx) >= points.size():
			return _walk_arrive(m, actor)
		return false
	var dir := (flat if body != null else to) / dist
	if flat.length_squared() > 0.0004:
		holder.rotation.y = lerp_angle(holder.rotation.y, atan2(-flat.x, -flat.z), minf(1.0, delta * 8.0))
	if body != null:
		var before := body.global_position
		body.velocity = Vector3(dir.x * speed, body.velocity.y - 18.0 * delta if not body.is_on_floor() else 0.0, dir.z * speed)
		body.move_and_slide()
		var moved := Vector2(body.global_position.x - before.x, body.global_position.z - before.z).length()
		if moved < step * 0.25:
			m.blocked_t = float(m.blocked_t) + delta
			if float(m.blocked_t) > 1.6:
				body.global_position = points.back()
				m.idx = points.size()
				return _walk_arrive(m, actor)
		else:
			m.blocked_t = 0.0
	else:
		holder.global_position += dir * step
	actor.speed = speed
	_animate_actor(actor, speed)
	return false


func _walk_arrive(m: Dictionary, actor: Dictionary) -> bool:
	var holder: Node3D = actor.holder
	if m.final_yaw != null and is_instance_valid(holder):
		holder.rotation.y = float(m.final_yaw)
	if holder is CharacterBody3D:
		(holder as CharacterBody3D).velocity = Vector3.ZERO
	actor.speed = 0.0
	_animate_actor(actor, 0.0)
	if not str(m.final_mark).is_empty():
		_story_world()[str(m.state_key)] = str(m.final_mark)
	return true


func _step_front(m: Dictionary, delta: float) -> bool:
	var prev_r := float(m.r)
	m.r = minf(float(m.radius), prev_r + float(m.speed) * delta)
	var ring: Variant = m.ring
	var k := float(m.r) / maxf(float(m.radius), 0.01)
	if ring is MeshInstance3D and is_instance_valid(ring):
		var mi := ring as MeshInstance3D
		mi.scale = Vector3(maxf(float(m.r), 0.1), 1.0 + 2.0 * (1.0 - k), maxf(float(m.r), 0.1))
		var mat := mi.material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_color.a = 0.55 * (1.0 - k)
	var p := _player()
	if p != null and not bool(m.hit):
		var origin: Vector3 = m.origin
		var d := Vector2(p.global_position.x - origin.x, p.global_position.z - origin.z).length()
		if d >= prev_r and d <= float(m.r):
			m.hit = true
			var falloff := clampf(1.0 - d / maxf(float(m.radius), 0.01), 0.25, 1.0)
			_story_shake(STORY_SHAKE_CAP * float(m.strength) * falloff)
			for other: Dictionary in _motions:
				if str(other.kind) == "pulse":
					other.done = true
			_motions.append({"kind": "pulse", "t": 0.0, "strength": float(m.strength) * falloff, "value": 0.0, "owner": -1})
	if float(m.r) >= float(m.radius):
		if ring is Node3D and is_instance_valid(ring):
			(ring as Node3D).queue_free()
		return true
	return false


# =============================================================================
# Physical chapter transitions
# =============================================================================

func _route_open(r: Dictionary) -> bool:
	if not is_instance_valid(r.area):
		return false
	var pred: Callable = r.is_open
	if pred.is_valid():
		return bool(pred.call())
	return true


func _route_distance(r: Dictionary, p: Node3D) -> float:
	var marker: Marker3D = r.marker
	if str(r.kind) == "drop":
		return marker.global_position.y - p.global_position.y
	var area: Area3D = r.area
	var dir := (area.global_basis * (r.direction_local as Vector3)).normalized()
	return (p.global_position - marker.global_position).dot(dir)


func _update_routes() -> void:
	if not _travel.is_empty():
		return
	var p := _player()
	if p == null:
		return
	for r: Dictionary in _routes.values():
		if not is_instance_valid(r.area) or not is_instance_valid(r.marker) or not (r.area as Node).is_inside_tree():
			continue
		var inside := _player_inside_area(r.area)
		var d := _route_distance(r, p)
		if not bool(r.armed):
			if not inside and _arrival_guard <= 0.0:
				r.armed = true
			r.prev_d = d
			continue
		var prev := float(r.prev_d)
		r.prev_d = d
		if inside and is_finite(prev) and prev < 0.0 and d >= 0.0 and _route_open(r):
			if request_transition(str(r.id)):
				return


func request_transition(route_id: String) -> bool:
	if not _travel.is_empty() or not _built:
		return false
	var r: Variant = _routes.get(route_id, null)
	if r == null or not _route_open(r):
		return false
	var g: Object = _g()
	if g == null:
		return false
	if not g.has_method("_mount_chapter_arrival") and not g.has_method("_load_chapter"):
		return false
	var hp: Variant = g.get("hp")
	if (hp is int or hp is float) and float(hp) <= 0.0:
		return false
	if g.get("held_body") != null:
		g.set("held_body", null)
	_travel = {
		"route_id": route_id, "destination": str(r.destination), "arrival_id": str(r.arrival_id),
		"safe_return_id": str(r.safe_return_id), "source": _chapter, "phase": "out", "t": 0.0,
		"ok": false, "written": false,
	}
	_fade_rect.visible = true
	_fade_rect.color = Color(0, 0, 0, 0)
	return true


func _update_fade(delta: float) -> void:
	if _travel.is_empty() or not is_instance_valid(_fade_rect):
		return
	_travel.t = float(_travel.t) + maxf(delta, 0.0)
	match str(_travel.phase):
		"out":
			_fade_rect.color.a = clampf(float(_travel.t) / FADE_OUT, 0.0, 1.0)
			if float(_travel.t) >= FADE_OUT:
				_fade_rect.color.a = 1.0
				_set_hud(false)
				_travel.phase = "swap"
				_travel.t = 0.0
				call_deferred("_travel_swap")
		"swap":
			_fade_rect.color.a = 1.0
			if float(_travel.t) >= SWAP_WATCHDOG:
				push_warning("StoryDirector: travel swap watchdog fired for '%s'" % _travel.route_id)
				_travel.phase = "in"
				_travel.t = 0.0
		"dwell":
			_fade_rect.color.a = 1.0
			if float(_travel.t) >= FADE_DWELL:
				_travel.phase = "in"
				_travel.t = 0.0
				_set_hud(true)
		"in":
			_fade_rect.color.a = 1.0 - clampf(float(_travel.t) / FADE_IN, 0.0, 1.0)
			if float(_travel.t) >= FADE_IN:
				_fade_rect.color.a = 0.0
				_fade_rect.visible = false
				var done := _travel
				_travel = {}
				_set_hud(true)
				if bool(done.ok):
					transition_finished.emit(str(done.route_id), str(done.destination), bool(done.written))


func _travel_swap() -> void:
	if _travel.is_empty() or str(_travel.phase) != "swap":
		return
	var g: Object = _g()
	var dest := str(_travel.destination)
	var arrival_id := str(_travel.arrival_id)
	var ok := false
	if g != null:
		if g.has_method("_mount_chapter_arrival"):
			var result: Variant = g.call("_mount_chapter_arrival", dest, arrival_id)
			ok = bool(result) if result is bool else str(g.get("chapter_id")) == dest
		elif g.has_method("_load_chapter"):
			g.call("_load_chapter", dest, true)
			ok = str(g.get("chapter_id")) == dest
			var marker := get_arrival(arrival_id)
			var p := _player() as CharacterBody3D
			if ok and marker != null and p != null:
				p.global_position = marker.global_position
				p.rotation.y = marker.global_rotation.y
				p.velocity = Vector3.ZERO
				p.reset_physics_interpolation()
	if _travel.is_empty():
		return
	_travel.ok = ok
	if ok:
		_travel.written = _write_arrival_checkpoint(dest, arrival_id)
		for r: Dictionary in _routes.values():
			r.armed = false
			r.prev_d = NAN
		_arrival_guard = ARRIVAL_GUARD
	else:
		push_warning("StoryDirector: travel to '%s' failed; staying in '%s'" % [dest, _travel.source])
	_travel.phase = "dwell"
	_travel.t = 0.0


func _write_arrival_checkpoint(dest: String, arrival_id: String) -> bool:
	var g: Object = _g()
	if g == null:
		return false
	var checkpoint_id := "arrival/%s/%s" % [dest, arrival_id]
	if g.has_method("_write_arrival_checkpoint"):
		return bool(g.call("_write_arrival_checkpoint", checkpoint_id))
	if g.has_method("_state"):
		var st: Variant = g.call("_state")
		if st is Dictionary:
			(st as Dictionary)["checkpoint_id"] = checkpoint_id
	return SaveSystem.write_save(g, true)


func _set_hud(active: bool) -> void:
	var narrative: Object = _narrative()
	if narrative != null and narrative.has_method("set_gameplay_hud_visible"):
		narrative.call("set_gameplay_hud_visible", active)


# =============================================================================
# Helpers: game access, resolution, geometry
# =============================================================================

func _g() -> Object:
	if _game_ref == null:
		return null
	var g: Variant = _game_ref.get_ref()
	if g == null or not is_instance_valid(g):
		return null
	return g


func _narrative() -> Object:
	var g: Object = _g()
	if g == null:
		return null
	var n: Variant = g.get("narrative")
	if n is Object and is_instance_valid(n):
		return n
	return null


func _player() -> Node3D:
	var g: Object = _g()
	if g == null:
		return null
	var p: Variant = g.get("player")
	if p is Node3D and is_instance_valid(p) and (p as Node3D).is_inside_tree():
		return p
	return null


func _camera() -> Camera3D:
	var g: Object = _g()
	if g != null:
		var c: Variant = g.get("camera")
		if c is Camera3D and is_instance_valid(c) and (c as Camera3D).is_inside_tree():
			return c
	if is_inside_tree():
		return get_viewport().get_camera_3d()
	return null


func _story_world() -> Dictionary:
	var w: Variant = _state.get("story_world", null)
	if not w is Dictionary:
		w = {}
		_state["story_world"] = w
	return w


func _profiles() -> Dictionary:
	var narrative: Object = _narrative()
	if narrative != null:
		var p: Variant = narrative.get("SPEAKER_PROFILES")
		if p is Dictionary:
			return p
	return {}


func _resolve_node(id: String) -> Node3D:
	if id.is_empty():
		return null
	match id:
		"$player":
			return _player()
		"$camera":
			return _camera()
		"$level":
			return _level if is_instance_valid(_level) else null
		"$boss":
			var g: Object = _g()
			var b: Variant = g.get("boss") if g != null else null
			return b if b is Node3D and is_instance_valid(b) else null
	var t: Variant = _targets.get(id, null)
	if t is Node3D and is_instance_valid(t):
		return t
	var a: Variant = _actors.get(id, null)
	if a != null and is_instance_valid(a.holder):
		return a.holder
	var tube: Variant = _tubes.get(id, null)
	if tube is Node3D and is_instance_valid(tube):
		return tube
	var chain: Variant = _ward_chains.get(id, null)
	if chain is Node3D and is_instance_valid(chain):
		return chain
	return null


func _resolve_pos(ref: Variant) -> Variant:
	if ref is Vector3:
		return ref
	if ref is Node3D and is_instance_valid(ref):
		return _node_center(ref)
	if not ref is String or str(ref).is_empty():
		return null
	var id := str(ref)
	if _marks.has(id):
		return _marks[id].pos
	var node := _resolve_node(id)
	if node == null:
		return null
	if _actors.has(id) or node == _player():
		return node.global_position
	return _node_center(node)


func _beat_pos(beat: Dictionary) -> Variant:
	var args: Dictionary = beat.args
	for key: String in ["pos", "at_pos", "mark", "emitter"]:
		if args.has(key):
			var p: Variant = _resolve_pos(args[key])
			if p is Vector3:
				return p
	var target := str(beat.target)
	if not target.is_empty():
		return _resolve_pos(target)
	return null


func _node_center(node: Node3D) -> Vector3:
	if node == null or not is_instance_valid(node):
		return Vector3.ZERO
	if not node.is_inside_tree():
		return node.position
	if node.has_meta("look_center") and node.get_meta("look_center") is Vector3:
		return node.global_transform * (node.get_meta("look_center") as Vector3)
	if node is VisualInstance3D:
		return node.global_transform * (node as VisualInstance3D).get_aabb().get_center()
	var total := AABB()
	var found := false
	for mi: Node in _meshes(node, 24):
		var vi := mi as VisualInstance3D
		var box := vi.global_transform * vi.get_aabb()
		total = box if not found else total.merge(box)
		found = true
	if found:
		return total.get_center()
	return node.global_position


func _node_extent(node: Node3D) -> Vector3:
	var total := AABB()
	var found := false
	for mi: Node in _meshes(node, 24):
		var vi := mi as VisualInstance3D
		var box := vi.global_transform * vi.get_aabb()
		total = box if not found else total.merge(box)
		found = true
	return total.size * 0.5 if found else Vector3(1.0, 1.0, 1.0)


func _meshes(node: Node, limit: int) -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [node]
	while not stack.is_empty() and out.size() < limit:
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			out.append(n)
		for c: Node in n.get_children():
			stack.append(c)
	return out


func _collision_shapes(node: Node) -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is CollisionShape3D:
			out.append(n)
		for c: Node in n.get_children():
			stack.append(c)
	return out


func _first_material(node: Node3D) -> Material:
	for mi: Node in _meshes(node, 8):
		var mesh := mi as MeshInstance3D
		if mesh.material_override != null:
			return mesh.material_override
		if mesh.mesh != null and mesh.mesh.get_surface_count() > 0 and mesh.get_active_material(0) != null:
			return mesh.get_active_material(0)
	return null


func _set_collision_enabled(node: Node, enabled: bool) -> void:
	for cs: Node in _collision_shapes(node):
		(cs as CollisionShape3D).set_deferred("disabled", not enabled)


func _set_node_active(node: Node3D, active: bool) -> void:
	node.visible = active
	_set_collision_enabled(node, active)


## Geometric (signal-free) test of the player capsule against an Area3D's shapes.
func _player_inside_area(area: Variant) -> bool:
	var p := _player()
	if p == null or not area is Area3D or not is_instance_valid(area) or not (area as Node).is_inside_tree():
		return false
	var center := p.global_position + Vector3.UP * (PLAYER_HEIGHT * 0.5)
	var margin := Vector3(PLAYER_RADIUS, PLAYER_HEIGHT * 0.5, PLAYER_RADIUS)
	for cs: Node in _collision_shapes(area):
		var shape := cs as CollisionShape3D
		if shape.shape == null or shape.disabled:
			continue
		var local := shape.global_transform.affine_inverse() * center
		var box := _shape_aabb(shape.shape).grow(0.0)
		box.position -= margin
		box.size += margin * 2.0
		if box.has_point(local):
			return true
	return false


## True when the player capsule AABB overlaps any collision shape under `node`
## (enabled or not), used to hold settled/wreck collision until clear.
func _player_overlaps_node(node: Node3D) -> bool:
	var p := _player()
	if p == null:
		return false
	var capsule := AABB(p.global_position + Vector3(-PLAYER_RADIUS, 0.05, -PLAYER_RADIUS), Vector3(PLAYER_RADIUS * 2.0, PLAYER_HEIGHT - 0.05, PLAYER_RADIUS * 2.0))
	for cs: Node in _collision_shapes(node):
		var shape := cs as CollisionShape3D
		if shape.shape == null or not shape.is_inside_tree():
			continue
		var world_box := shape.global_transform * _shape_aabb(shape.shape)
		if world_box.intersects(capsule):
			return true
	return false


static func _shape_aabb(shape: Shape3D) -> AABB:
	if shape is BoxShape3D:
		var s := (shape as BoxShape3D).size
		return AABB(-s * 0.5, s)
	if shape is SphereShape3D:
		var r := (shape as SphereShape3D).radius
		return AABB(Vector3.ONE * -r, Vector3.ONE * r * 2.0)
	if shape is CapsuleShape3D:
		var c := shape as CapsuleShape3D
		return AABB(Vector3(-c.radius, -c.height * 0.5, -c.radius), Vector3(c.radius * 2.0, c.height, c.radius * 2.0))
	if shape is CylinderShape3D:
		var cy := shape as CylinderShape3D
		return AABB(Vector3(-cy.radius, -cy.height * 0.5, -cy.radius), Vector3(cy.radius * 2.0, cy.height, cy.radius * 2.0))
	var mesh := shape.get_debug_mesh()
	return mesh.get_aabb() if mesh != null else AABB(Vector3.ONE * -0.5, Vector3.ONE)


func _target_in_view(node: Node3D, cone_deg: float) -> bool:
	var cam := _camera()
	if cam == null:
		return false
	var center := _node_center(node)
	var origin := cam.global_position
	var to := center - origin
	if to.length_squared() < 0.0001:
		return true
	var forward := -cam.global_basis.z
	if rad_to_deg(forward.angle_to(to)) > cone_deg:
		return false
	var space := cam.get_world_3d().direct_space_state if cam.get_world_3d() != null else null
	if space == null:
		return true
	var query := PhysicsRayQueryParameters3D.create(origin, center, LAYER_WORLD)
	var p := _player()
	if p is CollisionObject3D:
		query.exclude = [(p as CollisionObject3D).get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider: Variant = hit.get("collider")
	if collider is Node and (collider == node or node.is_ancestor_of(collider) or (collider as Node).is_ancestor_of(node)):
		return true
	return (hit.position as Vector3).distance_to(center) < 0.9


func _nearest_tube() -> Node3D:
	var p := _player()
	if p == null:
		return null
	var best: Node3D = null
	var best_d := TUBE_RANGE
	for tube: Variant in _tubes.values():
		if not tube is Node3D or not is_instance_valid(tube) or not (tube as Node3D).is_inside_tree():
			continue
		var d := p.global_position.distance_to((tube as Node3D).global_position)
		if d <= best_d:
			best_d = d
			best = tube
	return best


func _event_seed(job: Dictionary, beat: Dictionary) -> int:
	return absi(hash(str(job.spec.id)) ^ (int(beat.get("order", 0)) * 7919))


func _event_rng(key: String, index: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash(key) ^ (index * 104729))
	return rng


func _track_debris(body: Node3D, lifetime: float) -> void:
	_debris.append(body)
	while _debris.size() > MAX_DEBRIS:
		var old: Node3D = _debris.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	if body.is_inside_tree():
		var tw := body.create_tween()
		tw.tween_interval(lifetime)
		tw.tween_callback(body.queue_free)


func _spawn_debris(center: Vector3, extent: Vector3, count: int, seed_value: int, mat: Material) -> void:
	if not is_instance_valid(_level) or count <= 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in count:
		var body := RigidBody3D.new()
		body.name = "story_debris_%d" % i
		body.collision_layer = LAYER_DEBRIS
		body.collision_mask = LAYER_WORLD
		var size := Vector3(rng.randf_range(0.25, 0.7), rng.randf_range(0.2, 0.5), rng.randf_range(0.25, 0.7))
		body.mass = size.x * size.y * size.z * 40.0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		var mesh := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		mesh.mesh = bm
		if mat != null:
			mesh.material_override = mat
		body.add_child(mesh)
		_level.add_child(body)
		body.global_position = center + Vector3(rng.randf_range(-extent.x, extent.x), rng.randf_range(0.0, extent.y), rng.randf_range(-extent.z, extent.z))
		body.rotation = Vector3(rng.randf_range(-PI, PI), rng.randf_range(-PI, PI), rng.randf_range(-PI, PI))
		body.apply_central_impulse(Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.2, 0.6), rng.randf_range(-1, 1)) * body.mass * 2.0)
		body.apply_torque_impulse(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * body.mass * 0.2)
		_track_debris(body, 8.0)


func _spawn_particles(pos: Vector3, color: Color, amount: int, lifetime: float, direction: Variant, spread: float, gravity_y: float, duration: float, speed: float = 1.2) -> GPUParticles3D:
	if not is_instance_valid(_level):
		return null
	var p := GPUParticles3D.new()
	p.name = "story_fx_particles"
	p.amount = clampi(amount, 1, 96)
	p.lifetime = maxf(lifetime, 0.1)
	p.one_shot = duration <= 0.6
	p.explosiveness = 0.85 if p.one_shot else 0.0
	p.fixed_fps = 30
	p.visibility_aabb = AABB(Vector3(-8, -4, -8), Vector3(16, 12, 16))
	var mat := ParticleProcessMaterial.new()
	var dir: Vector3 = direction if direction is Vector3 and (direction as Vector3).length_squared() > 0.0001 else Vector3.UP
	mat.direction = dir.normalized()
	mat.spread = clampf(spread * 40.0, 2.0, 180.0)
	mat.initial_velocity_min = speed * 0.6
	mat.initial_velocity_max = speed * 1.4
	mat.gravity = Vector3(0, -gravity_y, 0)
	mat.scale_min = 0.05
	mat.scale_max = 0.14
	mat.color = color
	p.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	var draw := _fx_material(color, color.a, true)
	quad.material = draw
	p.draw_pass_1 = quad
	_level.add_child(p)
	p.global_position = pos
	p.emitting = true
	var tw := p.create_tween()
	tw.tween_interval(maxf(duration, 0.0) + p.lifetime + 0.2)
	tw.tween_callback(p.queue_free)
	if not p.one_shot:
		var stop := p.create_tween()
		stop.tween_interval(maxf(duration, 0.1))
		stop.tween_callback(func() -> void: p.emitting = false)
	return p


static func _fx_material(color: Color, alpha: float, billboard: bool = false) -> StandardMaterial3D:
	var key := "%s/%.2f/%s" % [color.to_html(false), alpha, billboard]
	if _fx_materials.has(key) and not billboard:
		return (_fx_materials[key] as StandardMaterial3D).duplicate()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(color.r, color.g, color.b, clampf(alpha, 0.0, 1.0))
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.6
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if billboard:
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.vertex_color_use_as_albedo = true
	_fx_materials[key] = mat
	return mat.duplicate() if not billboard else mat


# --- audio ---------------------------------------------------------------------

func _audio() -> Object:
	var g: Object = _g()
	if g == null:
		return null
	var a: Variant = g.get("audio_3d")
	if a is Object and is_instance_valid(a):
		return a
	return null


func _has_sound(sname: String) -> bool:
	var a: Object = _audio()
	if a == null:
		return false
	if a.has_method("has_stream"):
		return bool(a.call("has_stream", sname))
	var streams: Variant = a.get("_streams")
	return streams is Dictionary and (streams as Dictionary).has(sname)


func _sound_at(sname: String, pos: Vector3, pitch: float = 1.0, max_dist: float = 30.0, vol_db: float = -6.0) -> void:
	var a: Object = _audio()
	if a != null and is_instance_valid(_level) and _level.is_inside_tree() and a.has_method("play_at"):
		if a.get_method_argument_count("play_at") >= 6:
			a.call("play_at", _level, sname, pos, pitch, max_dist, vol_db)
		else:
			a.call("play_at", _level, sname, pos, pitch, max_dist)
		return
	var g: Object = _g()
	if g != null and g.has_method("_sound_at"):
		g.call("_sound_at", sname, pos, pitch)


func _sound_2d(sname: String, pitch: float = 1.0, vol_db: float = -6.0) -> void:
	var a: Object = _audio()
	if a != null and a.has_method("play_2d"):
		a.call("play_2d", sname, pitch, vol_db)


func _on_speaker_cue(cue_id: String, world_origin: Variant, channel: String = "", syllables: int = 0) -> void:
	# Bridge only when the game has not connected its own handler.
	var narrative: Object = _narrative()
	if narrative == null or narrative.get_signal_connection_list("speaker_cue").size() > 1:
		return
	var a: Object = _audio()
	if a == null or not a.has_method("play_speaker_cue"):
		return
	var parent: Node3D = _level if is_instance_valid(_level) and _level.is_inside_tree() else null
	if parent == null:
		var g: Variant = _g()
		if g is Node3D:
			parent = g
	if a.get_method_argument_count("play_speaker_cue") >= 5:
		a.call("play_speaker_cue", cue_id, parent, world_origin, channel, syllables)
	else:
		a.call("play_speaker_cue", cue_id, parent, world_origin)


# --- static method adapters (modules built in parallel) --------------------------

static func _method_info(script: Script, method: String) -> Dictionary:
	var key := "%s::%s" % [script.resource_path, method]
	if _method_cache.has(key):
		return _method_cache[key]
	var info := {}
	if script.has_method(method):
		for m: Dictionary in script.get_script_method_list():
			if str(m.name) == method:
				var total := (m.args as Array).size()
				info = {"total": total, "required": total - (m.default_args as Array).size()}
				break
	_method_cache[key] = info
	return info


## Calls a static helper if present, trimming optional trailing args to its arity.
## Returns null when the method is missing or needs more args than supplied.
static func _call_static(script: Script, method: String, args: Array, _optional: bool = false) -> Variant:
	if script == null:
		return null
	var info := _method_info(script, method)
	if info.is_empty():
		return null
	var total := int(info.total)
	if args.size() < int(info.required):
		return null
	var use := args.slice(0, mini(args.size(), total))
	var result: Variant = script.callv(method, use)
	return true if result == null else result


# =============================================================================
# Static environmental tableaux helpers
# =============================================================================

static func _mat(mats: Dictionary, key: String, fallback: Color) -> Material:
	var m: Variant = mats.get(key, null)
	if m is Material:
		return m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = fallback
	mat.roughness = 0.85
	return mat


static func _part(parent: Node3D, node_name: String, mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _box_mesh(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func add_fallen_guard(parent: Node3D, pose: Transform3D, variant: String, mats: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "fallen_guard_" + variant
	root.transform = pose
	parent.add_child(root)
	root.set_meta("tableau", "fallen_guard")
	root.set_meta("variant", variant)
	var cloth := _mat(mats, "timber", Color("6b5a48"))
	var armor := _mat(mats, "iron", Color("8a949c"))
	var skin := _mat(mats, "clay", Color("8c6a55"))
	match variant:
		"acolyte_scorched":
			cloth = _mat(mats, "ash", Color("3a3430"))
			skin = cloth
		"collared_skeleton":
			cloth = _mat(mats, "ash", Color("6f6a60"))
			skin = _mat(mats, "stone", Color("d8d0bc"))
		"frozen_worker":
			cloth = _mat(mats, "ice", Color("9ef3ff"))
			armor = _mat(mats, "ice", Color("9ef3ff"))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(variant) ^ hash(str(pose.origin))
	var body := Node3D.new()
	body.name = "body"
	root.add_child(body)
	if variant == "seated":
		_part(body, "pelvis", _box_mesh(Vector3(0.42, 0.22, 0.34)), cloth, Vector3(0, 0.14, 0))
		_part(body, "torso", _box_mesh(Vector3(0.46, 0.6, 0.26)), armor, Vector3(0, 0.52, -0.06), Vector3(-0.22, 0, 0))
		var head := SphereMesh.new()
		head.radius = 0.13
		head.height = 0.27
		_part(body, "head", head, skin, Vector3(0.05, 0.92, -0.02), Vector3(0.5, 0.2, 0.35))
		for side: float in [-1.0, 1.0]:
			_part(body, "thigh", _box_mesh(Vector3(0.15, 0.14, 0.46)), cloth, Vector3(0.12 * side, 0.1, 0.26))
			_part(body, "shin", _box_mesh(Vector3(0.13, 0.42, 0.13)), cloth, Vector3(0.12 * side, 0.1, 0.5), Vector3(1.3, 0, 0))
			_part(body, "arm", _box_mesh(Vector3(0.11, 0.48, 0.11)), armor, Vector3(0.3 * side, 0.36, 0.02), Vector3(0.4, 0, 0.15 * side))
	else:
		_part(body, "torso", _box_mesh(Vector3(0.48, 0.24, 0.66)), armor, Vector3(0, 0.13, 0), Vector3(0, rng.randf_range(-0.2, 0.2), 0))
		_part(body, "pelvis", _box_mesh(Vector3(0.4, 0.2, 0.3)), cloth, Vector3(0, 0.11, 0.46))
		var head := SphereMesh.new()
		head.radius = 0.13
		head.height = 0.27
		_part(body, "head", head, skin, Vector3(0.04, 0.13, -0.44))
		for side: float in [-1.0, 1.0]:
			_part(body, "leg", _box_mesh(Vector3(0.15, 0.15, 0.86)), cloth, Vector3(0.13 * side, 0.08, 1.0), Vector3(0, 0.12 * side + rng.randf_range(-0.15, 0.15), 0))
			_part(body, "arm", _box_mesh(Vector3(0.11, 0.11, 0.56)), armor, Vector3(0.36 * side, 0.08, -0.12), Vector3(0, 0.6 * side + rng.randf_range(-0.3, 0.3), 0))
	if variant == "collared_skeleton":
		var torus := TorusMesh.new()
		torus.inner_radius = 0.12
		torus.outer_radius = 0.17
		_part(body, "iron_collar", torus, _mat(mats, "iron", Color("7d868c")), Vector3(0, 0.15, -0.3) if variant != "seated" else Vector3(0, 0.8, -0.04))
	if variant == "artificer":
		_part(root, "dropped_tongs", _box_mesh(Vector3(0.05, 0.04, 0.55)), _mat(mats, "brass", Color("c9a46a")), Vector3(0.62, 0.03, -0.2), Vector3(0, 0.9, 0))
	elif variant != "frozen_worker":
		var weapon := Node3D.new()
		weapon.name = "dropped_weapon"
		root.add_child(weapon)
		weapon.position = Vector3(rng.randf_range(0.55, 0.85), 0.04, rng.randf_range(-0.4, 0.2))
		weapon.rotation.y = rng.randf_range(-PI, PI)
		_part(weapon, "haft", _box_mesh(Vector3(0.05, 0.05, 1.5)), _mat(mats, "timber", Color("6b5a48")), Vector3.ZERO)
		_part(weapon, "blade", _box_mesh(Vector3(0.32, 0.03, 0.26)), armor, Vector3(0, 0, -0.78))
	return root


static func add_supply_scatter(parent: Node3D, pose: Transform3D, mats: Dictionary, seed_value: int, count: int = 5) -> Node3D:
	var root := Node3D.new()
	root.name = "supply_scatter"
	root.transform = pose
	parent.add_child(root)
	root.set_meta("tableau", "supply_scatter")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var timber := _mat(mats, "timber", Color("8a6f52"))
	var iron := _mat(mats, "iron", Color("7d868c"))
	var sack := _mat(mats, "clay", Color("9c8466"))
	for i in clampi(count, 0, 24):
		var kind := rng.randi_range(0, 2)
		var pos := Vector3(rng.randf_range(-1.6, 1.6), 0.0, rng.randf_range(-1.2, 1.2))
		var yaw := rng.randf_range(-PI, PI)
		match kind:
			0:
				var s := rng.randf_range(0.45, 0.8)
				var size := Vector3(s, s * rng.randf_range(0.7, 1.0), s)
				var crate := StaticBody3D.new()
				crate.name = "crate_%d" % i
				crate.collision_layer = LAYER_WORLD
				crate.position = pos + Vector3.UP * size.y * 0.5
				crate.rotation = Vector3(0, yaw, rng.randf_range(-0.05, 0.05))
				root.add_child(crate)
				var cs := CollisionShape3D.new()
				var box := BoxShape3D.new()
				box.size = size
				cs.shape = box
				crate.add_child(cs)
				_part(crate, "planks", _box_mesh(size), timber, Vector3.ZERO)
				_part(crate, "band", _box_mesh(Vector3(size.x + 0.02, 0.05, size.z + 0.02)), iron, Vector3(0, size.y * 0.3, 0))
			1:
				var sm := SphereMesh.new()
				sm.radius = rng.randf_range(0.22, 0.32)
				sm.height = sm.radius * 1.3
				_part(root, "sack_%d" % i, sm, sack, pos + Vector3.UP * sm.height * 0.45, Vector3(0, yaw, rng.randf_range(-0.3, 0.3)))
			_:
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.24
				cyl.bottom_radius = 0.26
				cyl.height = 0.62
				var tipped := rng.randf() < 0.5
				_part(root, "barrel_%d" % i, cyl, timber, pos + Vector3.UP * (0.25 if tipped else 0.31), Vector3(PI * 0.5 if tipped else 0.0, yaw, 0))
	return root


static func add_masonry_pile(parent: Node3D, pose: Transform3D, material: Material, seed_value: int, solid: bool = false) -> Node3D:
	var root: Node3D
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = LAYER_WORLD
		root = body
	else:
		root = Node3D.new()
	root.name = "masonry_pile"
	root.transform = pose
	parent.add_child(root)
	root.set_meta("tableau", "masonry_pile")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mat := material if material != null else _mat({}, "", Color("8f8c86"))
	var span := Vector3(1.8, 0.0, 1.4)
	var top := 0.0
	for i in 14:
		var size := Vector3(rng.randf_range(0.35, 0.9), rng.randf_range(0.22, 0.5), rng.randf_range(0.3, 0.7))
		var r := 1.0 - float(i) / 16.0
		var pos := Vector3(rng.randf_range(-span.x, span.x) * r, 0.0, rng.randf_range(-span.z, span.z) * r)
		pos.y = size.y * 0.4 + (1.0 - r) * 0.9 * rng.randf_range(0.5, 1.0)
		top = maxf(top, pos.y + size.y * 0.5)
		_part(root, "block_%d" % i, _box_mesh(size), mat, pos, Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(-PI, PI), rng.randf_range(-0.4, 0.4)))
	if solid:
		var cs := CollisionShape3D.new()
		cs.name = "coarse_collider"
		var box := BoxShape3D.new()
		box.size = Vector3(span.x * 1.6, maxf(top * 0.7, 0.4), span.z * 1.6)
		cs.shape = box
		cs.position = Vector3(0, box.size.y * 0.5, 0)
		root.add_child(cs)
	return root


static func add_blood_trail(parent: Node3D, points: PackedVector3Array, normals: PackedVector3Array, seed_value: int) -> Node3D:
	var root := Node3D.new()
	root.name = "blood_trail"
	parent.add_child(root)
	root.set_meta("tableau", "blood_trail")
	if _trail_texture == null:
		_trail_texture = Visuals._make_splat_texture(Color("4e0b08"), 71)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in points.size():
		var n := normals[i] if i < normals.size() and normals[i].length_squared() > 0.0001 else Vector3.UP
		n = n.normalized()
		var ref := Vector3.FORWARD if absf(n.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
		var x := ref.cross(n).normalized()
		var z := x.cross(n).normalized()
		var basis := Basis(x, n, z).rotated(n, rng.randf_range(-PI, PI))
		var d := Decal.new()
		d.name = "trail_mark_%d" % i
		var s := rng.randf_range(0.35, 0.8)
		d.size = Vector3(s, 0.3, s * rng.randf_range(0.8, 1.6))
		d.texture_albedo = _trail_texture
		d.modulate = Color(1, 1, 1, rng.randf_range(0.7, 0.95))
		d.cull_mask = 1
		d.transform = Transform3D(basis, points[i] + n * 0.04)
		root.add_child(d)
	return root


static func add_broken_lantern(parent: Node3D, pose: Transform3D, mats: Dictionary, light_group: String = "") -> Node3D:
	var root := Node3D.new()
	root.name = "broken_lantern"
	root.transform = pose
	parent.add_child(root)
	root.set_meta("tableau", "broken_lantern")
	var iron := _mat(mats, "iron", Color("7d868c"))
	var brass := _mat(mats, "brass", Color("c9a46a"))
	var lantern := Node3D.new()
	lantern.name = "lantern_body"
	lantern.position = Vector3(0, 0.16, 0)
	lantern.rotation = Vector3(0, 0, 1.35)
	root.add_child(lantern)
	var hood := CylinderMesh.new()
	hood.top_radius = 0.04
	hood.bottom_radius = 0.16
	hood.height = 0.12
	_part(lantern, "hood", hood, brass, Vector3(0, 0.2, 0))
	var base := CylinderMesh.new()
	base.top_radius = 0.15
	base.bottom_radius = 0.15
	base.height = 0.05
	_part(lantern, "base", base, brass, Vector3(0, -0.18, 0))
	for i in 4:
		var a := TAU * float(i) / 4.0
		_part(lantern, "cage_bar", _box_mesh(Vector3(0.025, 0.36, 0.025)), iron, Vector3(cos(a), 0, sin(a)) * 0.13)
	var ember := _fx_material(Color("ffb05a"), 0.9)
	var coal := SphereMesh.new()
	coal.radius = 0.05
	coal.height = 0.1
	_part(lantern, "guttering_wick", coal, ember, Vector3.ZERO)
	var shard_mat := _mat(mats, "ice", Color(0.8, 0.9, 1.0, 0.5))
	for i in 3:
		_part(root, "glass_shard_%d" % i, _box_mesh(Vector3(0.09, 0.008, 0.06)), shard_mat, Vector3(0.25 + 0.1 * i, 0.005, -0.1 + 0.12 * i), Vector3(0, float(i) * 1.1, 0))
	var light := OmniLight3D.new()
	light.name = "lantern_glow"
	light.light_color = Color("ffb05a")
	light.light_energy = 0.9
	light.omni_range = 3.2
	light.position = Vector3(0.05, 0.2, 0)
	root.add_child(light)
	light.set_meta("story_base_energy", light.light_energy)
	if not light_group.is_empty():
		light.add_to_group("story_torch_" + light_group)
	root.set_meta("glow", light)
	return root


static func add_echo_wisp(game, pose: Transform3D, echo_id: String, line: Dictionary) -> Area3D:
	if game == null or not is_instance_valid(game):
		return null
	var level: Variant = game.get("level_root")
	if not level is Node3D or not is_instance_valid(level):
		return null
	var holder := Node3D.new()
	holder.name = "echo_wisp_" + echo_id
	holder.transform = pose
	(level as Node3D).add_child(holder)
	var color := Color.from_string(str(line.get("color", "8ce8f5")), Color("8ce8f5")) if not line.get("color") is Color else line.color as Color
	var orb := SphereMesh.new()
	orb.radius = 0.16
	orb.height = 0.32
	_part(holder, "wisp_core", orb, _fx_material(color, 0.75), Vector3(0, 1.4, 0))
	var light := OmniLight3D.new()
	light.name = "wisp_light"
	light.light_color = color
	light.light_energy = 0.9
	light.omni_range = 3.8
	light.position = Vector3(0, 1.4, 0)
	holder.add_child(light)
	var area := Area3D.new()
	area.name = "echo_area"
	area.position = Vector3(0, 1.0, 0)
	area.collision_layer = 0
	area.collision_mask = LAYER_PLAYER
	area.monitorable = false
	area.monitoring = true
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = float(line.get("radius", 3.0))
	cs.shape = sphere
	area.add_child(cs)
	holder.add_child(area)
	var speaker := str(line.get("speaker", "ECHO"))
	var text := str(line.get("line", ""))
	var title := str(line.get("title", speaker))
	area.body_entered.connect(func(body: Node3D) -> void:
		if not is_instance_valid(game) or body != game.get("player"):
			return
		var seen: Variant = game.get("seen_echoes")
		if seen is Dictionary:
			if (seen as Dictionary).has(echo_id):
				return
			(seen as Dictionary)[echo_id] = true
		var audio: Variant = game.get("audio_3d")
		if audio is Object and is_instance_valid(audio) and is_instance_valid(holder):
			(audio as Object).call("play_at", level, str(line.get("sound", "cast")), holder.global_position + Vector3.UP * 1.4, float(line.get("pitch", 1.35)), 18.0)
		var narrative: Variant = game.get("narrative")
		if narrative is Object and is_instance_valid(narrative) and not text.is_empty():
			if (narrative as Object).has_method("submit_line"):
				(narrative as Object).call("submit_line", {
					"id": "echo/" + echo_id, "group_id": "echo/" + echo_id,
					"speaker_id": str(line.get("speaker_id", "echo")), "speaker": speaker,
					"line": text, "duration": float(line.get("duration", 6.2)), "color": color,
					"channel": "echo", "world_origin": holder.global_position + Vector3.UP * 1.4 if is_instance_valid(holder) else null,
				})
			else:
				(narrative as Object).call("say", speaker, text, 6.2, color)
		if (game as Object).has_method("_story_event"):
			game.call("_story_event", "echo_" + echo_id, title, "%s: \"%s\"" % [speaker, text], "")
	)
	return area


# Small namespace for the narrative default duration rule, avoiding a dependency on NarrativeSystem.
class NarrativeDefaults:
	static func duration(text: String) -> float:
		return clampf(1.2 + 0.055 * float(text.length()), 2.0, 7.0)
