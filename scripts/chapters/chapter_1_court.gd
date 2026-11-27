extends RefCounted

## Chapter I — THE SUNKEN COURT ("The Night the Bell Cracked").
##
## A Hexen mini-hub (Gatehouse • Cloister • West Cistern • East Ossuary • Court
## of Seals • Bell Causeway) wrapped around a playable Half-Life cold open.
## Every scripted beat is registered with the StoryDirector when one is present
## (`game.story_director`); without it the chapter still builds and plays in a
## reduced legacy mode (the gatehouse bar opens on approach, the Keep threshold
## loads the Tower directly).
##
## Integration contract for main.gd:
##   * call `story_director.begin_chapter("ch1_court", level_root, state)` before
##     ChapterRegistry.build() and `finish_chapter_build()` after it;
##   * call `Court.step(game, delta)` once per physics frame from
##     `_update_puzzles()` (a 20 Hz Timer fallback drives the chapter otherwise);
##   * in ch1, let the chapter own the portcullis while `siege_stage > 0`
##     (drop the legacy instant `gate_open` on plates + lever and the legacy
##     `gate.position.y` move_toward);
##   * use `Court.objective_text(state)` / `Court.objective_target(state)`.

const L = preload("res://scripts/level_builder.gd")
const Visuals = preload("res://scripts/visuals.gd")
const PhysicsSandbox = preload("res://scripts/physics_sandbox.gd")
const Meshes3D = preload("res://scripts/meshes_3d.gd")
const SD = preload("res://scripts/story_director.gd")

const SEQ := "ch1_court/"
const AMBER := Color("ffbd70")
const CISTERN_LIGHT := Color("7ce5d0")
const CRYPT_LIGHT := Color("8adbee")
const TORIN_COLOR := Color("e8b25c")
const GUARD_COLOR := Color("c9b8a0")
const CHOIR_COLOR := Color("b9a8ff")
const ECHO_COLOR := Color("d8c7b0")
const VIOLET := Color("bba1ff")
const BELL_RANGE := 320.0
const SIEGE_HEIGHTS := [0.0, 1.7, 3.4, 5.2]
const SIEGE_RISE_SPEED := 0.68
const KEEP_DOOR_AJAR := 20.0
const KEEP_DOOR_OPEN := 55.0

const COLDOPEN_IDS := ["court_coldopen_shr_1", "court_coldopen_shr_2"]
const CLOISTER_IDS := ["court_cloister_shr_1", "court_cloister_shr_2", "court_cloister_shr_3"]
const RISEN_IDS := ["court_cistern_risen_1", "court_cistern_risen_2"]
const AMBUSH_IDS := ["court_ambush_shr1", "court_ambush_shr2", "court_ambush_exec"]
const WAVE_IDS := {
	1: ["court_siege_w1_a", "court_siege_w1_b", "court_siege_w1_c"],
	2: ["court_siege_w2_aco_a", "court_siege_w2_aco_b", "court_siege_w2_shr"],
	3: ["court_siege_w3_exec", "court_siege_w3_shr_a", "court_siege_w3_shr_b"],
}

# Stable story spawns, each grounded flush on its floor slab (y 0, -0.8, -0.7,
# the 3.0 cloister sills and the 2.42 Watch Walk lip).
const SPAWNS := {
	"court_coldopen_shr_1": [Vector3(-3.0, 0.0, 19.5), false, "shrieker"],
	"court_coldopen_shr_2": [Vector3(3.5, 0.0, 18.8), false, "shrieker"],
	"court_cloister_shr_1": [Vector3(-10.95, 3.0, 19.0), false, "shrieker"],
	"court_cloister_shr_2": [Vector3(-10.95, 3.0, 23.0), false, "shrieker"],
	"court_cloister_shr_3": [Vector3(-10.95, 3.0, 27.5), false, "shrieker"],
	"court_cistern_risen_1": [Vector3(-21.5, -0.8, 6.0), false, "shrieker"],
	"court_cistern_risen_2": [Vector3(-19.0, -0.8, -6.5), false, "shrieker"],
	"court_ambush_shr1": [Vector3(19.8, -0.7, -12.0), false, "shrieker"],
	"court_ambush_shr2": [Vector3(24.3, -0.7, -14.4), false, "shrieker"],
	"court_ambush_exec": [Vector3(26.5, -0.7, -5.0), true, "executioner"],
	"court_siege_w1_a": [Vector3(-3.0, 0.0, 14.5), false, "shrieker"],
	"court_siege_w1_b": [Vector3(0.0, 0.0, 15.5), false, "shrieker"],
	"court_siege_w1_c": [Vector3(3.0, 0.0, 14.5), false, "shrieker"],
	"court_siege_w2_aco_a": [Vector3(-10.4, 2.42, -16.4), false, "acolyte"],
	"court_siege_w2_aco_b": [Vector3(9.0, 0.0, -2.0), false, "acolyte"],
	"court_siege_w2_shr": [Vector3(0.0, 0.0, 15.0), false, "shrieker"],
	"court_siege_w3_exec": [Vector3(9.2, 0.0, -2.0), true, "executioner"],
	"court_siege_w3_shr_a": [Vector3(-10.4, 2.42, -16.9), false, "shrieker"],
	"court_siege_w3_shr_b": [Vector3(-10.4, 2.42, -15.5), false, "shrieker"],
}

# Actor marks: id -> [position, yaw]. Yaw 0 faces -Z (north).
const MARKS := {
	"torin_wicket": [Vector3(2.6, 0.0, 38.0), PI],
	"torin_grate": [Vector3(-3.4, 0.0, 33.6), PI * 0.5],
	"torin_bar": [Vector3(0.8, 0.0, 30.8), 0.0],
	"torin_camp": [Vector3(6.2, 0.0, 25.6), PI * 0.5],
	"torin_gearbox": [Vector3(-5.0, 0.0, -15.8), PI],
	"seraphina_grate": [Vector3(-5.0, 0.0, 32.4), -PI * 0.5],
	"seraphina_step_back": [Vector3(-5.8, 0.0, 32.6), -PI * 0.5],
	"seraphina_winch": [Vector3(-6.4, 0.0, 30.6), -PI * 0.5],
	"seraphina_wicket": [Vector3(-4.75, 0.0, 31.0), -PI * 0.5],
	"seraphina_exit": [Vector3(-7.55, 0.0, 32.2), PI * 0.5],
	"guard_start": [Vector3(2.0, 0.0, 21.0), PI],
	"guard_bar": [Vector3(0.8, 0.0, 29.4), PI],
	"guard_mid": [Vector3(1.6, 0.0, 33.0), PI],
	"guard_fall": [Vector3(1.6, 0.0, 36.8), PI],
	"seraphina_cistern": [Vector3(-20.0, 4.0, 18.9), 0.0],
	"seraphina_cistern_exit": [Vector3(-21.4, 4.0, 19.9), PI * 0.5],
	"seraphina_gallery": [Vector3(-4.0, 5.0, -17.7), PI],
	"seraphina_gallery_door": [Vector3(-9.2, 5.0, -17.7), -PI * 0.5],
}

const WATCHMAN_SEATS := [
	Vector3(24.25, -0.7, -11.8), Vector3(19.8, -0.7, -12.0), Vector3(22.0, -0.7, -10.5),
	Vector3(19.75, -0.7, -14.4), Vector3(24.3, -0.7, -14.4), Vector3(22.0, -0.7, -15.7),
]
const CAPTAIN_SEAT := 2

const TORIN_HOLLOW_LINES := [
	"Hm? Oh. Hello.",
	"Are you lost too?",
	"I had a sister. I think.",
	"(He hums two notes of the rhyme, and stops.)",
]

const WRIT_TEXT := "To Master Caelen, late of the Guild of Wards: the Bell of Vaelor rings flat. Your lock is failing. Come by the east road. Burn this. — S.V., Archivist."
const EDICT_TEXT := "By the King's hand: the Lower Ward is a debt to the Gate. Let it be paid at the Third Bell, and let the Register be its receipt. The bell shall then silence the witnesses. — VAELOR."
const SHRINE_TEXT := "Left at Her feet: one Bell-Watch arbalest, loaded, unfired. They told us to keep the crowd on the quay. I could not. Forgive me. — W. Ware."
const WATCH_ORDERS_TEXT := "Archers to the walk. None to leave the Court until the toll is done. — Captain M."
const AVUN_TEXT := "Keeper Avun put out his own eyes on the night of the Third Bell. He said the dead were looking back. He hunts by sound now. Give him something else to hear."
const TITHE_TEXT := "BY ORDER OF THE CROWN — All souls of the Lower Ward shall assemble upon the Cistern Quay at the Third Bell, to be carried by raft above the Grey Tide. Be written in the Register, that none be left behind."
const HYDRAULIC_TEXT := "Ram & escapement by Master C., Guild of Wards. Weight both seal-plates. Hold the east current with frost while the sluice runs. Seat the crank. Do not raise while the Court is occupied."
const CAUSEWAY_TEXT := "Raised in the reign of Vaelor the Second, that the Keep might always hear the Court."
const HESK_TITLE := "CHALKED PLANKS"
const HESK_TEXT := "Chalked across the raft deck in a clerk's square hand: HESK — 4 — WRITTEN."

const SEQUENCE_IDS := [
	"coldopen_arrival", "lull_loop", "torin_hail", "gatehouse_meeting", "gatehouse_fracture",
	"outer_arch_collapse", "gatehouse_aftermath", "torin_camp", "cloister_breach", "torin_rhyme",
	"cistern_arrival", "hesk_planks", "cistern_sluice", "cistern_high_water", "seraphina_leaves_cistern",
	"watchmen_whisper", "ossuary_blackout", "torin_relocates", "north_portcullis", "siege_crown",
	"siege_skull", "torin_hollows", "viaduct_toll", "keep_doors", "ambient_toll",
]


# =============================================================================
# State
# =============================================================================

static func default_state() -> Dictionary:
	return {
		# Existing puzzle flags (authoritative, unchanged semantics).
		"gate_open": false, "gatehouse_open": false, "has_lever": false, "lever_inserted": false,
		"cage_dropped": false, "shortcut_open": false, "ambush_done": false, "cistern_raised": false,
		# Act I script §3.9.
		"coldopen_done": false, "fractured": false, "outer_arch_collapsed": false,
		"torin_stage": 0, "torin_mark": "wicket", "torin_hollowed": false,
		"seraphina_mark": "gatehouse_grate",
		"sluice_unpicked": false, "sluice_lock_unpicked": false, "gearbox_unpicked": false, "ossuary_gate_unpicked": false,
		"drain_grate_open": false, "watchwalk_open": false, "read_hesk_planks": false,
		"siege_stage": 0, "portcullis_height": 0.0, "keep_doors_open": false, "basin_checkpoint_done": false,
		"story_world": {
			"gatehouse_arch_collapsed": false, "seraphina_mark": "gatehouse_grate",
			"torin_mark": "torin_wicket", "torin_hollowing": 0,
			"seraphina_cistern_left": false, "keep_doors_open": false,
		},
	}


## Live objective copy for the HUD; main.gd's `_objective()` should use it in ch1.
static func objective_text(st: Dictionary) -> String:
	var done: Dictionary = _world(st).get("completed_sequences", {})
	if bool(st.get("gate_open", false)):
		return "ENTER THE BELL KEEP" if bool(st.get("keep_doors_open", false)) else "CROSS THE BELL CAUSEWAY"
	if int(st.get("siege_stage", 0)) > 0:
		return "HOLD THE COURT — KEEP THEM OFF TORIN AT THE GEARBOX"
	if not bool(st.get("fractured", false)):
		return "FOLLOW THE LANTERN TO THE GATEHOUSE"
	if not bool(st.get("coldopen_done", false)):
		return "SURVIVE THE BREACH"
	if not done.has(SEQ + "torin_camp"):
		return "FOLLOW TORIN TO THE CLOISTER CAMP"
	if bool(st.get("lever_inserted", false)):
		if not bool(st.get("cistern_raised", false)):
			return "HYDRAULIC RAM DRY — RAISE THE CISTERN SLUICE"
		return "WEIGHT BOTH SEAL-PLATES TO RAISE THE PORTCULLIS"
	if bool(st.get("has_lever", false)):
		return "SEAT THE GEARBOX CRANK AT THE NORTH PORTCULLIS"
	return "FIND THE GEARBOX CRANK (OSSUARY) & THE ARBALEST (CISTERN)"


## Compass/map target matching objective_text().
static func objective_target(st: Dictionary) -> Variant:
	if bool(st.get("gate_open", false)):
		return Vector3(0, 0, -44)
	if not bool(st.get("coldopen_done", false)):
		return Vector3(0, 0, 33.6)
	if not _world(st).get("completed_sequences", {}).has(SEQ + "torin_camp"):
		return Vector3(6.2, 0, 25.6)
	if not bool(st.get("has_lever", false)):
		return Vector3(22, -0.7, -13.1)
	if not bool(st.get("lever_inserted", false)):
		return Vector3(-5.8, 0, -16.9)
	if not bool(st.get("cistern_raised", false)):
		return Vector3(-24, 0, 10)
	return Vector3(0, 0, -5.0)


static func _world(st: Dictionary) -> Dictionary:
	var w: Variant = st.get("story_world", null)
	if not w is Dictionary:
		w = {}
		st["story_world"] = w
	var world: Dictionary = w
	if not world.get("completed_sequences") is Dictionary:
		world["completed_sequences"] = {}
	return world


static func _is_done(st: Dictionary, seq: String) -> bool:
	return (_world(st).completed_sequences as Dictionary).has(SEQ + seq)


static func _mark_done(st: Dictionary, seqs: Array) -> void:
	var done: Dictionary = _world(st).completed_sequences
	for s: Variant in seqs:
		done[SEQ + str(s)] = true


# Fill defaults, derive the §3.9 keys from authoritative puzzle flags and make
# legacy saves coherent (gate_open ⇒ siege 3 + Torin hollowed, etc.).
static func _normalize_state(st: Dictionary) -> void:
	var defaults := default_state()
	for k: String in defaults:
		if not st.has(k):
			st[k] = defaults[k].duplicate(true) if defaults[k] is Dictionary else defaults[k]
	var world := _world(st)
	var dw: Dictionary = defaults.story_world
	for k: String in dw:
		if not world.has(k):
			world[k] = dw[k]
	for list_key: String in ["dead", "taken", "broken"]:
		if not st.get(list_key) is Array:
			st[list_key] = []
	if bool(st.gate_open):
		st.siege_stage = 3
		st.portcullis_height = 5.2
		st.torin_hollowed = true
		st.lever_inserted = true
		st.has_lever = true
	if bool(st.torin_hollowed):
		st.torin_stage = 4
	var progressed := bool(st.gatehouse_open) or bool(st.has_lever) or bool(st.cistern_raised) \
		or bool(st.lever_inserted) or int(st.siege_stage) > 0 or bool(st.fractured)
	if progressed:
		st.fractured = true
		st.coldopen_done = true
		st.gatehouse_open = true
		st.torin_stage = maxi(int(st.torin_stage), 1)
	if bool(world.gatehouse_arch_collapsed) or bool(st.outer_arch_collapsed):
		world.gatehouse_arch_collapsed = true
		st.outer_arch_collapsed = true
	if bool(st.coldopen_done):
		_mark_done(st, ["coldopen_arrival", "torin_hail", "gatehouse_meeting", "gatehouse_fracture", "outer_arch_collapse", "gatehouse_aftermath"])
		if str(world.seraphina_mark) in ["gatehouse_grate", "seraphina_grate", "seraphina_step_back", "seraphina_winch", "seraphina_wicket", "gatehouse_winch"]:
			world.seraphina_mark = "archive"
	if bool(st.cistern_raised):
		st.sluice_unpicked = true
		st.sluice_lock_unpicked = true
		_mark_done(st, ["cistern_sluice", "cistern_high_water"])
	if bool(st.has_lever):
		st.ambush_done = true
		_mark_done(st, ["ossuary_blackout", "torin_relocates", "watchmen_whisper"])
	if bool(st.lever_inserted):
		st.gearbox_unpicked = true
	if bool(st.shortcut_open):
		st.ossuary_gate_unpicked = true
	if (st.broken as Array).has("court_watchwalk_bar"):
		st.watchwalk_open = true
	st.siege_stage = clampi(int(st.siege_stage), 0, 3)
	st.torin_stage = clampi(int(st.torin_stage), 0, 4)
	st.portcullis_height = clampf(float(st.portcullis_height), 0.0, 5.2)
	if int(st.siege_stage) >= 1:
		_mark_done(st, ["north_portcullis"])
	if int(st.siege_stage) >= 2:
		_mark_done(st, ["siege_crown"])
	if int(st.siege_stage) >= 3:
		_mark_done(st, ["siege_skull"])
	if bool(st.torin_hollowed):
		_mark_done(st, ["torin_hollows"])
	if bool(st.keep_doors_open) or bool(world.keep_doors_open):
		st.keep_doors_open = true
		world.keep_doors_open = true
		_mark_done(st, ["keep_doors"])


# Mirror director-written story_world fields onto the flat §3.9 keys every tick.
static func _sync_derived(game, st: Dictionary) -> void:
	if bool(st.sluice_lock_unpicked) or bool(st.sluice_unpicked) or bool(st.cistern_raised):
		st.sluice_lock_unpicked = true
		st.sluice_unpicked = true
	if bool(st.shortcut_open):
		st.ossuary_gate_unpicked = true
	if bool(st.lever_inserted):
		st.gearbox_unpicked = true
	if (st.broken as Array).has("court_watchwalk_bar"):
		st.watchwalk_open = true
	var world := _world(st)
	st.seraphina_mark = str(world.get("seraphina_mark", st.seraphina_mark))
	var tm := str(world.get("torin_mark", ""))
	if tm.begins_with("torin_"):
		st.torin_mark = tm.trim_prefix("torin_")
	st.torin_stage = maxi(int(st.torin_stage), int(world.get("torin_hollowing", 0)))
	if bool(world.gatehouse_arch_collapsed):
		st.outer_arch_collapsed = true
	var flags: Variant = game.get("story_flags")
	if flags is Array and (flags as Array).has("inscription_" + HESK_TITLE.to_lower().replace(" ", "_")):
		st.read_hesk_planks = true


# =============================================================================
# Build
# =============================================================================

static func build(game, st: Dictionary) -> void:
	var root: Node3D = game.level_root
	_normalize_state(st)
	var d := _director(game)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3011
	var ctx := {
		"root": root, "directed": d != null, "t": 0.0, "external_frame": -100,
		"hail_done_t": -1.0, "breach_t": -1.0, "stage_t": 0.0, "slip_warned": false,
		"collapse_wait": -1.0, "winch_hold": 0.0, "torin_line": 0, "arrival_started": false,
		"next_ambient_toll": 55.0, "rng": rng,
		"gatehouse_lights": [], "crypt_lights": [], "route_lights": [], "ram_jets": [],
	}
	root.set_meta("court_ctx", ctx)
	root.set_meta("court_state", st)
	var landmarks := L.add_far_landmarks(game, root, Vector3.ZERO)
	ctx["landmarks"] = landmarks
	_approach(game, root)
	_gatehouse(game, root, st, ctx)
	_cloister(game, root, st, ctx)
	_cistern(game, root, st, ctx)
	_watch_walk(game, root, st, ctx)
	_ossuary(game, root, st, ctx)
	_basin(game, root, st, ctx)
	_causeway(game, root, st, ctx)
	_actors(game, root, st, ctx, d)
	if d != null:
		_register_story(game, root, st, ctx, d, landmarks)
	else:
		_legacy_fallbacks(game, root, st, ctx)
	_restore_spawns(game, st, ctx)
	game._scatter_particles("ash", 110, Rect2(-30, -46, 60, 108))
	_start_driver(game, root, st, ctx)


static func _director(game) -> SD:
	if game == null or not is_instance_valid(game):
		return null
	var v: Variant = game.get("story_director")
	if v is SD and is_instance_valid(v):
		return v
	return null


# --- Z1a: Approach stair (spawn landing y 6 -> viaduct y 0) -------------------

static func _approach(game, root: Node3D) -> void:
	var m: Dictionary = game.mats
	L.slab(root, "approach_landing", Rect2(-4, 60, 8, 3.4), 6.0, m.floor, 0.8)
	L.box(root, "approach_landing_mass", Vector3(0, -4.4, 61.7), Vector3(8.6, 19.2, 3.8), m.dark)
	L.staircase(root, "approach_stair", Vector3(0, 6, 61.5), Vector3(0, 0, 48.5), 7.0, m.stone, m.iron)
	L.slab(root, "approach_stair_foot", Rect2(-4.0, 47.0, 8.0, 2.0), 0, m.floor)
	for z: float in [51.0, 54.5, 58.0]:
		var top := 6.0 * (z - 48.5) / 13.0 - 0.55
		L.box(root, "approach_pier", Vector3(0, (top - 14.0) * 0.5, z), Vector3(5.2, top + 14.0, 1.4), m.dark, false)
	for side: float in [-1.0, 1.0]:
		_invisible_wall(root, "approach_stair_guard", Vector3(side * 3.95, 3.6, 55.0), Vector3(0.3, 9.0, 13.4))
		_parapet(root, game, Vector3(side * 4.15, 6.0, 61.7), Vector3(0.5, 1.1, 3.4))
		L.cone(root, "approach_finial", Vector3(side * 4.15, 7.4, 60.2), 0.34, 0.05, 1.2, m.stone, 6)
	_parapet(root, game, Vector3(0, 6.0, 63.55), Vector3(8.8, 1.1, 0.5))
	var arch := L.archway(root, "east_road_arch", Vector3(0, 6.0, 63.1), 5.2, 3.8, 0.7, m.stone, m.brass)
	arch.rotation.z = 0.04
	SD.add_masonry_pile(root, Transform3D(Basis(), Vector3(1.6, 6.0, 62.4)), m.stone, 61, false)
	game._light(Vector3(0, 8.2, 60.6), AMBER, 0.9, 7.0)
	_chalk(root, "THE EAST ROAD", Vector3(0, 10.7, 62.7), Vector3.ZERO, 64, Color(0.82, 0.74, 0.6, 0.7))


# --- Z1b: Outer viaduct, gatehouse, Seraphina's cell --------------------------

static func _gatehouse(game, root: Node3D, st: Dictionary, ctx: Dictionary) -> void:
	var m: Dictionary = game.mats
	L.slab(root, "outer_viaduct", Rect2(-5.8, 35, 11.6, 13), 0, m.floor)
	for x: float in [-4.95, 4.95]:
		L.box(root, "viaduct_gate_pier", Vector3(x, 2.4, 47.9), Vector3(1.5, 4.8, 1.1), m.dark)
		L.cone(root, "viaduct_gate_pinnacle", Vector3(x, 5.7, 47.9), 0.8, 0.08, 1.8, m.stone, 6)
	for x: float in [-5.6, 5.6]:
		L.box(root, "viaduct_parapet", Vector3(x, 0.7, 41.5), Vector3(0.7, 1.4, 13), m.stone)
		_invisible_wall(root, "viaduct_parapet_guard", Vector3(x, 2.6, 41.5), Vector3(0.7, 2.4, 13))
		for z: float in [38, 45]:
			L.box(root, "bridge_buttress", Vector3(x, -3.0, z), Vector3(2.0, 6.0, 2.6), m.dark)
			L.box(root, "weathered_merlon", Vector3(x, 1.75, z), Vector3(1.1, 0.9, 0.9), m.stone, false)
			L.box(root, "viaduct_arch_pier", Vector3(x, 2.8, z), Vector3(0.9, 2.0, 0.85), m.dark, false)
	for z: float in [38, 45]:
		L.vaulted_rib(root, Vector3(0, 3.7, z), 11.2, 3.7, m.stone, m.brass)
		L.hanging_chain_lamp(game, root, Vector3(0, 4.35, z), 2.55, AMBER, 3.2, 9.0)
	L.slab(root, "gatehouse_floor", Rect2(-8, 29, 16, 8), 0, m.floor)
	# East wall whole; west wall split around the cell's back door to the archive stair.
	L.box(root, "gatehouse_wall_e", Vector3(8, 4, 33), Vector3(1.1, 8, 8), m.dark)
	L.box(root, "gatehouse_wall_w_n", Vector3(-8, 4, 30.3), Vector3(1.1, 8, 2.6), m.dark)
	L.box(root, "gatehouse_wall_w_s", Vector3(-8, 4, 34.9), Vector3(1.1, 8, 4.2), m.dark)
	L.box(root, "gatehouse_wall_w_lintel", Vector3(-8, 5.2, 32.2), Vector3(1.1, 5.6, 1.2), m.dark)
	for x: float in [-8, 8]:
		L.cone(root, "gatehouse_spire", Vector3(x, 11, 35.4), 2.6, 0.16, 6, m.dark, 8)
	_outer_arch(game, root, st, ctx)
	var inner := L.archway(root, "inner_arch_z30", Vector3(0, 0, 30.0), 7.6, 5.2, 1.4, m.stone, m.brass)
	ctx["inner_arch"] = inner
	L.vaulted_rib(root, Vector3(0, 4.25, 30.0), 8, 4.2, m.stone, m.brass)
	if bool(st.fractured):
		L.add_fissure(root, Vector3(0, 5.75, 30.8), 0.0, Vector2(5.0, 1.1), VIOLET)
	L.focus_light(root, Vector3(-3.5, 4.1, 33.2), Vector3(-4.13, 1.1, 32.1), AMBER, 4.0, 28.0)
	L.box(root, "gatehouse_wing_wall_east", Vector3(6.05, 2.6, 30.05), Vector3(3.5, 5.2, 0.9), m.dark)
	var wicket_door := L.box(root, "wicket_door_leaf", Vector3(3.45, 1.15, 37.15), Vector3(0.1, 2.3, 1.1), m.timber, false)
	wicket_door.rotation.y = 1.1
	_cell(game, root, st, ctx)
	game._torch(Vector3(-6.4, 2.7, 32))
	(ctx.gatehouse_lights as Array).append(game.torches.back())
	game._torch(Vector3(5.3, 2.7, 33.8))
	(ctx.gatehouse_lights as Array).append(game.torches.back())
	for l: Variant in ctx.gatehouse_lights:
		(l as Node).add_to_group("story_torch_gatehouse")
	# The interior bar the guard begs at; the fracture sequence lifts it.
	var bar := L.box(root, "gatehouse_bar", Vector3(0, 1.85, 30.05), Vector3(6.65, 3.7, 0.27), m.iron, true) as StaticBody3D
	for x: float in [-2.8, 0, 2.8]:
		L.box(bar, "bar_reinforcement", Vector3(x, 0, 0.18), Vector3(0.13, 3.75, 0.15), m.brass, false)
	bar.set_meta("interact_hint", "GATEHOUSE BAR — RAISED FROM THE CELL WINCH")
	ctx["bar"] = bar
	if bool(st.gatehouse_open):
		bar.position.y += 4.5
		bar.collision_layer = 0
	if bool(st.outer_arch_collapsed):
		_guard_remains(game, root, ctx, false)


static func _outer_arch(game, root: Node3D, st: Dictionary, ctx: Dictionary) -> void:
	var m: Dictionary = game.mats
	for x: float in [-3.8, 3.8]:
		L.box(root, "outer_arch_pier", Vector3(x, 2.6, 36.0), Vector3(1.1, 5.2, 1.4), m.stone)
	# Fracture assembly: 8 voussoirs + keystone + spandrel + rib (visual only).
	var arch := Node3D.new()
	arch.name = "gatehouse_outer_arch"
	root.add_child(arch)
	for i in 8:
		var side := -1.0 if i < 4 else 1.0
		var a := (float(i % 4) + 0.5) / 4.0
		var pos := Vector3(side * lerpf(3.45, 0.62, a), 5.2 + 1.75 * sin(a * PI * 0.5), 36.0)
		var v := L.box(arch, "outer_voussoir", pos, Vector3(1.0, 0.72, 1.5), m.stone, false)
		v.rotation.z = -side * a * 0.95
	L.box(arch, "outer_spandrel", Vector3(0, 7.75, 36.0), Vector3(9.0, 1.3, 1.3), m.stone, false)
	L.box(arch, "outer_keystone", Vector3(0, 7.15, 36.0), Vector3(0.95, 1.25, 1.7), m.brass, false)
	L.vaulted_rib(arch, Vector3(0, 4.25, 36.0), 8, 4.2, m.stone, m.brass)
	ctx["outer_arch"] = arch
	# Settled rubble wall that seals the viaduct (Rect2(-5.8, 36.2, 11.6, 2.2), h 4.2).
	var rubble := StaticBody3D.new()
	rubble.name = "gatehouse_outer_rubble"
	rubble.collision_layer = L.LAYER_WORLD
	rubble.collision_mask = 0
	rubble.position = Vector3(0, 0, 37.3)
	root.add_child(rubble)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(11.6, 4.2, 2.2)
	cs.shape = bs
	cs.position.y = 2.1
	rubble.add_child(cs)
	for i in 3:
		var pile := SD.add_masonry_pile(rubble, Transform3D(Basis(), Vector3(-3.7 + 3.7 * float(i), 0, 0)), m.stone, 360 + i, false)
		pile.scale = Vector3(1.3, 1.9, 0.85)
	var rrng := RandomNumberGenerator.new()
	rrng.seed = 3636
	for i in 9:
		var blk := L.box(rubble, "rubble_block", Vector3(rrng.randf_range(-5.0, 5.0), rrng.randf_range(0.6, 3.6), rrng.randf_range(-0.6, 0.6)),
			Vector3(rrng.randf_range(0.9, 1.8), rrng.randf_range(0.6, 1.2), rrng.randf_range(0.8, 1.6)), m.stone, false)
		blk.rotation = Vector3(rrng.randf_range(-0.5, 0.5), rrng.randf_range(-0.8, 0.8), rrng.randf_range(-0.6, 0.6))
	var key := L.box(rubble, "rubble_keystone", Vector3(0.7, 1.1, -0.5), Vector3(0.95, 1.25, 1.5), m.brass, false)
	key.rotation = Vector3(0.5, 0.3, 0.9)
	rubble.set_meta("look_center", Vector3(0, 2.1, 0))
	ctx["outer_rubble"] = rubble
	if bool(st.outer_arch_collapsed):
		L.set_assembly_active(arch, false, false)
	else:
		L.set_assembly_active(rubble, false, false)


static func _cell(game, root: Node3D, st: Dictionary, ctx: Dictionary) -> void:
	var m: Dictionary = game.mats
	L.box(root, "observation_cell_south", Vector3(-6, 2, 34.5), Vector3(4, 4, 0.5), m.dark)
	L.box(root, "observation_cell_north", Vector3(-6, 2, 29.8), Vector3(4, 4, 0.5), m.dark)
	L.box(root, "observation_cell_roof", Vector3(-6.05, 4.1, 32.15), Vector3(4.2, 0.2, 4.9), m.dark, false)
	for i in 9:
		if i >= 1 and i <= 3:
			continue
		L.box(root, "observation_grate", Vector3(-4.15, 1.85, 30.05 + i * 0.52), Vector3(0.17, 3.7, 0.13), m.iron)
	L.box(root, "grate_top_rail", Vector3(-4.15, 3.75, 32.13), Vector3(0.2, 0.16, 4.3), m.iron, false)
	# Hinged grate wicket (bars 1-3); Seraphina unlocks it in the aftermath.
	var hinge := Node3D.new()
	hinge.name = "cell_grate_wicket_hinge"
	hinge.position = Vector3(-4.15, 0, 30.3)
	root.add_child(hinge)
	var wicket := StaticBody3D.new()
	wicket.name = "cell_grate_wicket"
	wicket.collision_layer = L.LAYER_WORLD
	wicket.collision_mask = 0
	hinge.add_child(wicket)
	for j in 3:
		L.box(wicket, "wicket_bar", Vector3(0, 1.75, 0.27 + j * 0.52), Vector3(0.17, 3.5, 0.13), m.iron, false)
	for y: float in [0.5, 3.0]:
		L.box(wicket, "wicket_brace", Vector3(0, y, 0.8), Vector3(0.12, 0.12, 1.45), m.brass, false)
	L.box(wicket, "wicket_lock", Vector3(0.12, 1.3, 1.42), Vector3(0.14, 0.3, 0.2), m.brass, false)
	var wcs := CollisionShape3D.new()
	var wbox := BoxShape3D.new()
	wbox.size = Vector3(0.2, 3.5, 1.45)
	wcs.shape = wbox
	wcs.position = Vector3(0, 1.75, 0.8)
	wicket.add_child(wcs)
	ctx["cell_wicket"] = hinge
	if bool(st.coldopen_done):
		hinge.rotation.y = -1.45
		wicket.set_meta("interact_hint", "CELL GRATE — UNLOCKED")
	else:
		wicket.set_meta("interact_hint", "CELL GRATE — LOCKED FROM WITHIN")
	# Back door to the archive stair (left ajar once she has gone).
	var door_hinge := Node3D.new()
	door_hinge.name = "cell_back_door_hinge"
	door_hinge.position = Vector3(-7.5, 0, 31.6)
	root.add_child(door_hinge)
	var door := L.box(door_hinge, "cell_back_door", Vector3(0, 1.2, 0.6), Vector3(0.12, 2.4, 1.2), m.timber)
	L.box(door, "door_strap", Vector3(0.07, 0.5, 0), Vector3(0.03, 0.1, 1.15), m.iron, false)
	L.box(door, "door_strap", Vector3(0.07, -0.6, 0), Vector3(0.03, 0.1, 1.15), m.iron, false)
	ctx["cell_door"] = door_hinge
	if bool(st.coldopen_done):
		door_hinge.rotation.y = -0.08
	L.slab(root, "archive_stair_landing", Rect2(-10.2, 31.4, 1.7, 1.6), 0, m.dark)
	L.box(root, "archive_stair_back", Vector3(-10.4, 2.0, 32.2), Vector3(0.4, 4.0, 2.0), m.dark)
	L.box(root, "archive_stair_side_n", Vector3(-9.35, 2.0, 31.25), Vector3(2.1, 4.0, 0.3), m.dark)
	L.box(root, "archive_stair_side_s", Vector3(-9.35, 2.0, 33.15), Vector3(2.1, 4.0, 0.3), m.dark)
	L.box(root, "archive_stair_roof", Vector3(-9.35, 4.1, 32.2), Vector3(2.2, 0.2, 2.2), m.dark, false)
	for k in 4:
		L.box(root, "archive_step", Vector3(-9.0 - 0.3 * k, 0.18 + 0.36 * k, 32.2), Vector3(0.45, 0.36, 1.2), m.stone, false)
	game._light(Vector3(-9.4, 2.4, 32.2), Color("6fa9b8"), 0.6, 3.2)
	# Seraphina's desk: inkwell, cold lamp, three ledgers, the writ.
	L.box(root, "cell_desk", Vector3(-6.8, 0.42, 33.75), Vector3(1.4, 0.84, 0.66), m.timber)
	for i in 3:
		var ledger := L.box(root, "cell_ledger", Vector3(-7.25 + 0.05 * i, 0.9 + 0.09 * i, 33.8), Vector3(0.36, 0.08, 0.48), m.blood if i == 1 else m.dark, false)
		ledger.rotation.y = 0.15 * i
	L.cylinder(root, "cell_inkwell", Vector3(-6.35, 0.9, 33.95), 0.06, 0.1, m.iron, false, 8)
	L.cylinder(root, "cell_cold_lamp", Vector3(-6.15, 1.0, 33.65), 0.11, 0.3, m.brass, false, 8)
	var writ := L.box(root, "cell_writ", Vector3(-6.7, 0.85, 33.6), Vector3(0.3, 0.01, 0.42), m.clay, false)
	writ.rotation.y = -0.3
	L.cylinder(root, "cell_stool", Vector3(-6.8, 0.25, 32.9), 0.22, 0.5, m.timber, false, 8)
	_plaque(game, Vector3(-6.95, 0, 33.1), "THE EMERGENCY WRIT", WRIT_TEXT, true)
	SD.add_echo_wisp(game, Transform3D(Basis(), Vector3(-6.6, 0, 33.8)), "echo_seraphina_cell", {
		"speaker": "ARCHIVIST SERAPHINA — ECHO", "speaker_id": "echo", "title": "SERAPHINA'S CELL",
		"line": "Entry, night thirty-seven. Sent the writ east. He'll come for the bell. He'll stay for the Gate. He never leaves a lock half-open.",
		"color": Color("70d7df"), "radius": 1.3,
	})


# Ware's lantern + blood trail beneath the arch rubble (live: rolling body).
static func _guard_remains(game, root: Node3D, ctx: Dictionary, live: bool) -> void:
	if ctx.has("guard_remains"):
		return
	ctx["guard_remains"] = true
	SD.add_blood_trail(root, PackedVector3Array([Vector3(1.6, 0.0, 36.1), Vector3(1.45, 0.0, 35.7), Vector3(1.25, 0.0, 35.3), Vector3(1.05, 0.0, 34.9)]),
		PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP]), 3011)
	if live:
		var body := RigidBody3D.new()
		body.name = "guard_lantern"
		body.collision_layer = L.LAYER_DEBRIS
		body.collision_mask = L.LAYER_WORLD
		body.mass = 1.2
		body.angular_damp = 1.2
		body.position = Vector3(1.2, 0.6, 35.6)
		root.add_child(body)
		var cs := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.2
		cs.shape = sphere
		body.add_child(cs)
		SD.add_broken_lantern(body, Transform3D(Basis(), Vector3(0, -0.16, 0)), game.mats, "")
		_chalk(body, "W.W.", Vector3(0, 0.05, 0.17), Vector3.ZERO, 22, Color(0.95, 0.8, 0.5, 0.9))
		body.apply_central_impulse(Vector3(0, 0, -1.5))
		body.apply_torque_impulse(Vector3(0.05, 0, 0.12))
	else:
		var lantern := SD.add_broken_lantern(root, Transform3D(Basis(), Vector3(0.9, 0.0, 34.3)), game.mats, "")
		_chalk(lantern, "W.W.", Vector3(0, 0.12, 0.18), Vector3(-0.4, 0, 0), 22, Color(0.95, 0.8, 0.5, 0.9))


# --- Z2: South Cloister & Fallen Camp ---------------------------------------------

static func _cloister(game, root: Node3D, st: Dictionary, ctx: Dictionary) -> void:
	var m: Dictionary = game.mats
	L.slab(root, "south_cloister_floor", Rect2(-12, 16, 21, 14), 0, m.floor)
	L.slab(root, "ossuary_shortcut_landing", Rect2(9, 16, 10, 5), 0, m.floor)
	L.box(root, "cloister_west", Vector3(-12, 4.25, 23), Vector3(1, 8.5, 14), m.dark)
	L.box(root, "cloister_east", Vector3(9.3, 4.25, 24.8), Vector3(1, 8.5, 10.4), m.dark)
	L.box(root, "cloister_south_w", Vector3(-8.5, 3.0, 29.8), Vector3(7, 6, 1), m.stone)
	L.box(root, "cloister_south_e", Vector3(7, 3.0, 29.8), Vector3(5, 6, 1), m.stone)
	L.box(root, "cloister_roof", Vector3(-1.5, 10.25, 23.5), Vector3(22, 0.8, 13), m.dark, false)
	var broken := _is_done(st, "cloister_breach")
	for z: float in [19, 23, 27.5]:
		L.vaulted_rib(root, Vector3(-1, 5.1, z), 17, 4.8, m.stone, m.brass)
		L.hanging_chain_lamp(game, root, Vector3(-1, 5.2, z), 4.2, AMBER, 3.8, 11.5)
		for x: float in [-9.5, 7.5]:
			L.cylinder(root, "cloister_clustered_pier", Vector3(x, 2.55, z), 0.57, 5.1, m.stone, true, 10)
			L.cylinder(root, "cloister_pier_capital", Vector3(x, 5.05, z), 0.78, 0.45, m.brass, false, 10)
		game._stained_glass(Vector3(-11.4, 5.4, z), true)
		var window := root.get_child(root.get_child_count() - 1) as Node3D
		ctx["window_%d" % int(z)] = window
		if broken:
			window.visible = false
		# Inner sill the Hollowed drop onto when the glass goes.
		L.box(root, "breach_sill", Vector3(-11.0, 2.85, z), Vector3(1.0, 0.3, 1.6), m.stone)
		Visuals.spawn_godray(root, Vector3(-7.1, 3.7, z), Vector3(0, 0, 54), 2.25, 10.5, Color(0.78, 0.85, 0.94, 0.24))
	L.add_alchemical_font(game, Vector3(-5.8, 0, 23.5))
	L.add_checkpoint_zone(game, Vector3(0, 1.3, 25), Vector3(9, 2.8, 3.2), "court_cloister", "South Cloister")
	# Torin's camp: pallet, bedroll, helmet, bowl, whetstone.
	L.box(root, "camp_pallet", Vector3(6.5, 0.1, 26.3), Vector3(2.0, 0.2, 3.2), m.timber, false)
	var bedroll := L.cylinder(root, "camp_bedroll", Vector3(6.6, 0.32, 27.4), 0.22, 1.6, m.clay, false, 10)
	bedroll.rotation.z = PI * 0.5
	var helmet := _sphere(root, "camp_helmet", Vector3(5.4, 0.14, 26.9), 0.2, m.iron)
	helmet.scale = Vector3(1, 0.7, 1.1)
	L.cylinder(root, "camp_bowl", Vector3(5.2, 0.05, 25.6), 0.16, 0.1, m.clay, false, 10)
	L.box(root, "camp_whetstone", Vector3(5.6, 0.04, 24.9), Vector3(0.26, 0.07, 0.1), m.stone, false)
	game._torch(Vector3(6.8, 2.25, 25.8))
	game._pickup(Vector3(5.8, 0.55, 27.0), "flask", "court_camp_flask")
	L.add_explosive_cask(game, Vector3(-4.5, 0, 17.75), "court_cask_cloister")
	_urn(game, Vector3(-8.8, 0, 21.0), "court_cloister_urn_w", "mana")
	_urn(game, Vector3(7.65, 0, 20.8), "court_cloister_urn_e", "flask")


# --- Z4: West Cistern ("The Quay of Bundles") ----------------------------------

static func _cistern(game, root: Node3D, st: Dictionary, ctx: Dictionary) -> void:
	var m: Dictionary = game.mats
	L.slab(root, "cistern_bed", Rect2(-30, -14, 20, 32), -0.8, m.stone)
	L.slab(root, "cistern_entry_quay", Rect2(-13, -8, 4, 20), 0, m.floor)
	L.staircase(root, "cistern_entry_steps", Vector3(-12.8, 0, 4), Vector3(-16.2, -0.8, 4), 3.6, m.stone, m.iron)
	L.slab(root, "sluice_causeway", Rect2(-27, 8, 15, 4), 0, m.floor)
	L.iron_grate_floor(root, Vector3(-21.3, 0, 10), Vector2(2.8, 1.5), m.iron)
	for x: float in [-30, -10]:
		for z: float in [-10, 13.4]:
			L.box(root, "cistern_side_wall", Vector3(x, 3.3, z), Vector3(1, 8.2, 8.2 if x == -10 else 9.2), m.dark)
	L.box(root, "cistern_outer_wall", Vector3(-30, 3.3, 1.7), Vector3(1, 8.2, 16), m.dark)
	# North end wall with the doorway from the West Parapet vault into the Watch Walk.
	L.box(root, "cistern_end_wall_n_w", Vector3(-28, 3.3, -14), Vector3(4, 8.2, 1), m.dark)
	L.box(root, "cistern_end_wall_n_e", Vector3(-17, 3.3, -14), Vector3(14, 8.2, 1), m.dark)
	L.box(root, "watchwalk_doorway_sill", Vector3(-25, 0.81, -14), Vector3(2, 3.22, 1), m.dark)
	L.box(root, "watchwalk_doorway_lintel", Vector3(-25, 6.1, -14), Vector3(2, 2.6, 1), m.dark)
	# South end wall with the archive window (Seraphina) and the drain grate opening.
	L.box(root, "cistern_end_wall_s_w", Vector3(-25.55, 3.3, 18), Vector3(8.9, 8.2, 1), m.dark)
	L.box(root, "cistern_end_wall_s_e", Vector3(-15.2, 3.3, 18), Vector3(7.4, 8.2, 1), m.dark)
	L.box(root, "archive_window_sill", Vector3(-20, 1.7, 18), Vector3(2.2, 5.0, 1), m.dark)
	L.box(root, "archive_window_head", Vector3(-20, 6.6, 18), Vector3(2.2, 1.6, 1), m.dark)
	L.box(root, "drain_opening_head", Vector3(-10.75, 4.9, 18), Vector3(1.5, 5.0, 1), m.dark)
	for i in 5:
		L.box(root, "archive_window_bar", Vector3(-20.9 + 0.45 * i, 5.0, 17.6), Vector3(0.07, 1.6, 0.07), m.iron, false)
	L.box(root, "archive_window_rail", Vector3(-20, 5.0, 17.6), Vector3(2.2, 0.07, 0.07), m.iron, false)
	L.slab(root, "archive_alcove_floor", Rect2(-22, 18.4, 4, 2.2), 4.0, m.dark, 0.4)
	L.box(root, "archive_alcove_back", Vector3(-20, 5.7, 20.8), Vector3(4.4, 3.4, 0.4), m.dark)
	L.box(root, "archive_alcove_side_w", Vector3(-22.2, 5.7, 19.6), Vector3(0.4, 3.4, 2.4), m.dark)
	L.box(root, "archive_alcove_side_e", Vector3(-17.8, 5.7, 19.6), Vector3(0.4, 3.4, 2.4), m.dark)
	L.box(root, "archive_alcove_roof", Vector3(-20, 7.5, 19.6), Vector3(4.4, 0.3, 2.6), m.dark, false)
	var lantern: OmniLight3D = game._light(Vector3(-20, 5.4, 18.7), Color("70d7df"), 0.0, 8.0)
	lantern.set_meta("rest_energy", 2.4)
	ctx["cistern_lantern"] = lantern
	for z: float in [-9, 0, 11]:
		L.vaulted_rib(root, Vector3(-20, 4.6, z), 19, 6.1, m.stone, m.brass)
		game._torch(Vector3(-28.8, 2.2, z))
	L.hanging_chain_lamp(game, root, Vector3(-23.75, 3.7, 11), 5.6, AMBER, 4.4, 11.0)
	L.hanging_chain_lamp(game, root, Vector3(-17.8, 4.15, 0), 5.65, CISTERN_LIGHT, 3.3, 10.0)
	L.focus_light(root, Vector3(-19.6, 5.0, 1.4), Vector3(-17.8, 0.95, -1.2), CISTERN_LIGHT, 4.2, 23.0)
	L.add_wet_zone(game, Vector3(-20.7, -0.5, 2), Vector2(8.7, 15.5))
	var water_y := 1.45 if bool(st.cistern_raised) else -0.53
	var water := L.box(root, "cistern_water", Vector3(-20.7, water_y, 2), Vector3(17.4, 0.1, 31), m.water, false)
	water.set_meta("raised_y", 1.45)
	water.set_meta("lowered_y", -0.53)
	game.cistern_water_node = water
	ctx["water"] = water
	# Sluice lever chained shut with Caelen's padlock (Unpick, lock_id "sluice_lock").
	var sluice := L.lever(root, "cistern_sluice_lever", Vector3(-24, 0, 10), m.dark, m.brass,
		"SLUICE CHAIN — PADLOCK WITH YOUR MASTER'S MARK — UNPICK [HOLD E]")
	sluice.set_meta("raised_y", 1.45)
	sluice.set_meta("unpick", true)
	sluice.set_meta("lock_id", "sluice_lock")
	sluice.set_meta("unpicked_hint", "CISTERN SLUICE — PULL [E] TO FLOAT THE RAFTS")
	game.cistern_sluice_lever = sluice
	ctx["sluice"] = sluice
	var padlock := Node3D.new()
	padlock.name = "sluice_padlock"
	sluice.add_child(padlock)
	for i in 5:
		var link := L.cylinder(padlock, "sluice_chain_link", Vector3(0.0, 0.35 + i * 0.16, 0.38), 0.06, 0.04, m.iron, false, 8)
		link.rotation.x = PI * 0.5 if i % 2 == 0 else 0.0
	L.box(padlock, "padlock_body", Vector3(0.0, 0.25, 0.42), Vector3(0.22, 0.2, 0.08), m.brass, false)
	_chalk(padlock, "C", Vector3(0, 0.25, 0.47), Vector3.ZERO, 20, Color(0.2, 0.15, 0.1, 1))
	padlock.visible = not bool(st.sluice_lock_unpicked) and not bool(st.cistern_raised)
	ctx["padlock"] = padlock
	_quay_of_bundles(game, root)
	_shrine(game, root)
	L.slab(root, "sluice_boarding_pier", Rect2(-27, 4.6, 4.3, 4.2), 0.92, m.stone)
	L.staircase(root, "sluice_boarding_steps", Vector3(-25, 0, 11.45), Vector3(-25, 0.92, 8.95), 2.2, m.stone, m.iron)
	var first := true
	for z: float in [2.0, -2.65]:
		var raft := PhysicsSandbox.create_buoyant_raft(root, Vector3(-25, water_y, z), Vector3(3.4, 0.35, 4.0), m.timber, m.iron)
		raft.axis_lock_linear_x = true
		raft.axis_lock_linear_z = true
		raft.axis_lock_angular_y = true
		game.buoyant_rafts.append(raft)
		if first:
			first = false
			ctx["hesk_raft"] = raft
			_chalk(raft, "HESK — 4 — WRITTEN", Vector3(0.2, 0.19, 0.4), Vector3(-PI * 0.5, 0.15, 0), 40, Color(0.92, 0.9, 0.82, 0.85))
			var plank_node := _plaque(game, raft.global_position + Vector3(0, -0.6, 0), HESK_TITLE, HESK_TEXT, true)
			ctx["hesk_inscription"] = plank_node
	# West Parapet vault, the King's Edict mural and the Heart of Vaelor.
	L.slab(root, "west_parapet", Rect2(-29.5, -13.5, 7.7, 8.8), 2.42, m.stone)
	L.box(root, "parapet_vault_wall_w", Vector3(-28.9, 3.9, -10.2), Vector3(0.6, 3, 5.3), m.dark)
	L.box(root, "parapet_vault_wall_e", Vector3(-22.5, 3.9, -10.2), Vector3(0.6, 3, 5.3), m.dark)
	L.box(root, "parapet_vault_face_w", Vector3(-28, 3.9, -8.1), Vector3(2.4, 3, 0.65), m.dark)
	L.box(root, "parapet_vault_face_e", Vector3(-23.4, 3.9, -8.1), Vector3(2.4, 3, 0.65), m.dark)
	L.add_rotten_barricade(game, Vector3(-25.7, 3.62, -8.1), "court_secret_bar_1", Vector3(2.6, 2.4, 0.45), true)
	L.focus_light(root, Vector3(-28.25, 5.55, -6.15), Vector3(-25.7, 3.62, -8.1), AMBER, 2.2, 22.0)
	game._pickup(Vector3(-25.7, 3.15, -11.7), "relic_heart", "relic_heart_vaelor")
	var mural_art: Texture2D = load("res://art/vaelor_mural.png")
	L.add_wall_mural(game, root, "kings_edict", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-28.58, 3.85, -10.4)), Vector2(2.2, 1.6), mural_art, null, {
		"title": "THE KING'S EDICT", "writing": EDICT_TEXT, "interact_hint": "KING VAELOR'S EDICT — READ [E]",
		"light_color": Color("ffd3a0"), "light_energy": 1.1,
	})
	# Drain grate (West Loop return): winched from the cistern side only.
	L.staircase(root, "drain_steps", Vector3(-10.75, -0.8, 13.6), Vector3(-10.75, 0.0, 16.0), 1.4, m.stone, m.iron)
	var grate := L.box(root, "drain_grate", Vector3(-10.75, 1.2, 18.0), Vector3(1.5, 2.4, 0.3), m.iron) as StaticBody3D
	(grate.get_child(0) as MeshInstance3D).visible = false
	for i in 5:
		L.box(grate, "drain_grate_bar", Vector3(-0.6 + 0.3 * i, 0, 0), Vector3(0.08, 2.4, 0.08), m.iron, false)
	for y: float in [-0.9, 0.9]:
		L.box(grate, "drain_grate_rail", Vector3(0, y, 0), Vector3(1.5, 0.1, 0.1), m.iron, false)
	grate.set_meta("interact_hint", "DRAIN GRATE — WINCHED FROM THE CISTERN SIDE")
	ctx["drain_grate"] = grate
	if bool(st.drain_grate_open):
		grate.position.y += 2.8
		grate.collision_layer = 0
	var winch := L.lever(root, "drain_grate_winch", Vector3(-12.6, -0.8, 14.8), m.dark, m.brass, "DRAIN GRATE WINCH — TURN [HOLD E]")
	ctx["winch"] = winch
	_plaque(game, Vector3(-16.1, -0.05, 0.9), "SHRINE OF THE DROWNED MOTHER", SHRINE_TEXT)
	L.add_checkpoint_zone(game, Vector3(-11, 1.3, -1.0), Vector3(3, 2.8, 4), "court_cistern", "West Cistern")
	SD.add_echo_wisp(game, Transform3D(Basis(), Vector3(-11.0, 0, 3.0)), "echo_quay_mother", {
		"speaker": "A MOTHER ON THE QUAY — ECHO", "speaker_id": "echo", "title": "THE QUAY OF BUNDLES",
		"line": "Hesk. Four of us. The clerk said there'd be room, if we were written down.",
		"color": ECHO_COLOR, "radius": 2.6,
	})
	game._enemy(Vector3(-16.2, -0.8, 7), false, "court_west_1", false, "shrieker")
	game._enemy(Vector3(-21.1, -0.8, -5.9), false, "court_west_2", false, "shrieker")
	game._enemy(Vector3(-22.8, -0.8, 1.5), true, "court_cistern_exec", false, "executioner")
	L.add_explosive_cask(game, Vector3(-15, 0, 10.4), "court_cask_west")
	L.add_explosive_cask(game, Vector3(-21, -0.8, 3.6), "court_cask_cistern_bed")
	_urn(game, Vector3(-20.9, -0.8, 5.7), "court_cistern_urn_s", "mana")
	_urn(game, Vector3(-21.2, -0.8, -3.4), "court_cistern_urn_n", "flask")


# T1: fourteen bundles, a birdcage, a doll, three pairs of shoes, row paint, tallies. No bodies.
static func _quay_of_bundles(game, root: Node3D) -> void:
	var m: Dictionary = game.mats
	SD.add_supply_scatter(root, Transform3D(Basis(Vector3.UP, 0.3), Vector3(-11.3, 0, -6.6)), m, 707, 6)
	SD.add_supply_scatter(root, Transform3D(Basis(Vector3.UP, -0.2), Vector3(-11.9, 0, 7.3)), m, 808, 4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	for i in 4:
		var sack := _sphere(root, "quay_bundle", Vector3(rng.randf_range(-12.6, -11.6), 0.2, rng.randf_range(-3.0, 1.0)), 0.26, m.clay)
		sack.scale = Vector3(1.0, 0.75, 1.2)
	var cage := Node3D.new()
	cage.name = "quay_birdcage"
	cage.position = Vector3(-12.2, 0, -1.6)
	root.add_child(cage)
	L.cylinder(cage, "cage_base", Vector3(0, 0.03, 0), 0.22, 0.06, m.brass, false, 10)
	for i in 8:
		var a := TAU * float(i) / 8.0
		L.box(cage, "cage_wire", Vector3(cos(a) * 0.2, 0.25, sin(a) * 0.2), Vector3(0.015, 0.45, 0.015), m.brass, false)
	var cage_door := L.box(cage, "cage_door_open", Vector3(0.28, 0.22, 0.08), Vector3(0.01, 0.2, 0.16), m.brass, false)
	cage_door.rotation.y = 1.2
	var doll := Node3D.new()
	doll.name = "quay_rag_doll"
	doll.position = Vector3(-12.6, 0.04, 0.6)
	doll.rotation.y = 0.7
	root.add_child(doll)
	L.box(doll, "doll_body", Vector3(0, 0, 0), Vector3(0.14, 0.06, 0.22), m.blood, false)
	_sphere(doll, "doll_head", Vector3(0, 0.0, -0.16), 0.06, m.clay)
	# Three pairs of shoes at the water's edge, smallest nearest the water.
	for i in 3:
		var s := 1.0 - 0.22 * float(i)
		for side: float in [-1.0, 1.0]:
			L.box(root, "quay_shoe", Vector3(-12.55 - 0.12 * i + side * 0.07 * s, 0.04 * s, 2.6 + 0.6 * i), Vector3(0.09 * s, 0.08 * s, 0.24 * s), m.dark, false)
	for i in 3:
		_chalk(root, "ROW %d" % (7 + i), Vector3(-11.3, 0.02, -4.2 + 3.2 * i), Vector3(-PI * 0.5, PI * 0.5, 0), 56)
	var tally := ""
	for g in 24:
		tally += "|||| " if g % 8 != 7 else "||||\n"
	_chalk(root, tally, Vector3(-9.52, 1.5, -2.8), Vector3(0, -PI * 0.5, 0), 28, Color(0.85, 0.83, 0.76, 0.6))


static func _shrine(game, root: Node3D) -> void:
	var m: Dictionary = game.mats
	L.slab(root, "arbalest_altar_island", Rect2(-20, -3.9, 4.6, 5.5), -0.05, m.dark)
	L.staircase(root, "arbalest_altar_steps", Vector3(-17.8, -0.8, 4.1), Vector3(-17.8, -0.05, 1.7), 2.8, m.stone, m.iron)
	L.box(root, "arbalest_altar", Vector3(-17.8, 0.28, -1.2), Vector3(2.4, 0.66, 1.75), m.stone)
	var mother := Node3D.new()
	mother.name = "shrine_drowned_mother"
	mother.position = Vector3(-17.8, -0.05, -2.45)
	root.add_child(mother)
	L.cone(mother, "mother_robe", Vector3(0, 0.75, 0), 0.95, 0.45, 1.5, m.stone, 12)
	var torso := L.box(mother, "mother_torso", Vector3(0, 1.75, 0.12), Vector3(0.66, 0.8, 0.42), m.stone, false)
	torso.rotation.x = 0.38
	var head := _sphere(mother, "mother_head", Vector3(0, 2.3, 0.42), 0.21, m.stone)
	head.scale = Vector3(1, 1.15, 1)
	var hood := L.cone(mother, "mother_hood", Vector3(0, 2.38, 0.34), 0.3, 0.06, 0.62, m.stone, 10)
	hood.rotation.x = 0.5
	for side: float in [-1.0, 1.0]:
		var arm := L.box(mother, "mother_arm", Vector3(side * 0.36, 1.45, 0.55), Vector3(0.16, 0.16, 0.8), m.stone, false)
		arm.rotation = Vector3(0.6, -side * 0.25, 0)
		L.box(mother, "mother_tear", Vector3(side * 0.08, 2.24, 0.62), Vector3(0.025, 0.14, 0.02), m.mana, false)
	for i in 6:
		var a := PI * (0.15 + 0.7 * float(i) / 5.0)
		var p := Vector3(-17.8 + cos(a) * 1.55, -0.05, -1.2 + sin(a) * 1.1)
		L.cylinder(root, "shrine_candle", p + Vector3(0, 0.12, 0), 0.045, 0.24, m.clay, false, 6)
		_sphere(root, "shrine_candle_flame", p + Vector3(0, 0.28, 0), 0.035, m.ember)
	game._light(Vector3(-17.8, 2, -1.2), Color("63da93"), 2.1, 7)
	game._light(Vector3(-17.8, 0.5, 0.1), Color("ffb05a"), 0.9, 3.5)
	if not game.has_arbalest:
		game._pickup(Vector3(-17.8, 0.95, -1.2), "arbalest", "court_arbalest")


# --- High Loop: Watch Walk behind the cistern's north wall --------------------

static func _watch_walk(game, root: Node3D, st: Dictionary, _ctx: Dictionary) -> void:
	var m: Dictionary = game.mats
	L.slab(root, "watch_walk", Rect2(-27, -17.6, 17.4, 3.1), 2.42, m.floor, 0.5)
	var slits: Array[float] = [-22.0, -17.0, -12.0]
	var edges: Array[float] = [-27.0]
	for x: float in slits:
		edges.append(x - 0.15)
		edges.append(x + 0.15)
	edges.append(-9.6)
	for i in range(0, edges.size(), 2):
		var a := edges[i]
		var b := edges[i + 1]
		L.box(root, "watch_walk_north_wall", Vector3((a + b) * 0.5, 4.2, -17.9), Vector3(b - a, 3.6, 0.6), m.dark)
	for x: float in slits:
		L.box(root, "arrow_slit_sill", Vector3(x, 2.92, -17.9), Vector3(0.3, 1.0, 0.6), m.dark)
		L.box(root, "arrow_slit_head", Vector3(x, 5.4, -17.9), Vector3(0.3, 1.2, 0.6), m.dark)
		game._light(Vector3(x, 4.1, -17.4), CRYPT_LIGHT, 0.5, 3.0)
	L.box(root, "watch_walk_west", Vector3(-27.3, 4.2, -16.05), Vector3(0.6, 3.6, 3.7), m.dark)
	L.box(root, "watch_walk_roof", Vector3(-18.3, 6.15, -16.0), Vector3(17.6, 0.3, 4.4), m.dark, false)
	# T2 "The Watch Post": empty racks, a stool, a cold brazier, the tally that ends in "3,011?".
	for i in 2:
		var rack := L.box(root, "crossbow_rack", Vector3(-24.6 + 1.3 * i, 3.4, -17.45), Vector3(1.1, 1.9, 0.18), m.timber, false)
		for k in 3:
			L.box(rack, "rack_peg", Vector3(-0.35 + 0.35 * k, 0.4, 0.12), Vector3(0.05, 0.05, 0.2), m.iron, false)
	L.cylinder(root, "watch_stool", Vector3(-20.2, 2.67, -15.4), 0.2, 0.5, m.timber, false, 8)
	L.cylinder(root, "cold_brazier", Vector3(-19.2, 2.82, -16.0), 0.36, 0.8, m.iron, false, 10)
	L.cylinder(root, "brazier_ash", Vector3(-19.2, 3.24, -16.0), 0.3, 0.05, m.ash, false, 10)
	var tally := ""
	for g in 30:
		tally += "|||| " if g % 10 != 9 else "||||\n"
	tally += "... 3,011?"
	_chalk(root, tally, Vector3(-15.0, 3.9, -17.58), Vector3.ZERO, 26, Color(0.85, 0.83, 0.76, 0.65))
	_plaque(game, Vector3(-25.6, 2.42, -15.2), "WATCH WALK ORDERS", WATCH_ORDERS_TEXT)
	game._light(Vector3(-20.0, 4.6, -16.0), AMBER, 1.3, 6.5)
	game._light(Vector3(-13.0, 4.6, -16.0), AMBER, 1.0, 6.0)
	game._enemy(Vector3(-18, 2.42, -16.3), false, "court_watchwalk_aco", false, "acolyte")
	# Smash the bar to drop 2.42 m into the Court beside the gearbox.
	L.add_rotten_barricade(game, Vector3(-11.6, 3.62, -16.05), "court_watchwalk_bar", Vector3(0.45, 2.4, 3.1), false)
	if (st.broken as Array).has("court_watchwalk_bar"):
		st.watchwalk_open = true


# --- Z5: East Ossuary ("Watchmen's Rest") ----------------------------------------

static func _ossuary(game, root: Node3D, st: Dictionary, ctx: Dictionary) -> void:
	var m: Dictionary = game.mats
	L.slab(root, "ossuary_upper_path", Rect2(9, -6, 9, 8), 0, m.floor)
	L.slab(root, "ossuary_crypt_floor", Rect2(16, -18, 14, 34), -0.7, m.floor)
	L.slab(root, "ossuary_shortcut_quay", Rect2(9, 15.7, 21, 4.1), 0, m.floor)
	L.staircase(root, "ossuary_descent", Vector3(17.5, 0, -2), Vector3(21.5, -0.7, -2), 3.7, m.stone, m.iron)
	L.staircase(root, "ossuary_return_steps", Vector3(21.6, -0.7, 11.6), Vector3(21.6, 0, 15.82), 3.6, m.stone, m.iron)
	L.box(root, "ossuary_west_cutoff", Vector3(15.8, 2.7, 8.7), Vector3(0.9, 6.8, 13.5), m.dark)
	L.box(root, "ossuary_west_north", Vector3(15.8, 2.7, -12), Vector3(0.9, 6.8, 12), m.dark)
	L.box(root, "ossuary_east_wall", Vector3(30, 2.7, 1), Vector3(1.1, 6.8, 38), m.dark)
	L.box(root, "ossuary_end_wall", Vector3(22.9, 2.7, 19.8), Vector3(15, 6.8, 0.9), m.dark)
	# North end wall with the jagged breach framing the Keep's bell through bones (SL-4).
	L.box(root, "ossuary_end_wall_n_w", Vector3(18.2, 2.7, -18), Vector3(5.6, 6.8, 0.9), m.dark)
	L.box(root, "ossuary_end_wall_n_e", Vector3(27.7, 2.7, -18), Vector3(5.4, 6.8, 0.9), m.dark)
	L.box(root, "ossuary_breach_sill", Vector3(23, 0.05, -18), Vector3(4, 1.5, 0.9), m.dark)
	L.box(root, "ossuary_breach_head", Vector3(23, 4.65, -18), Vector3(4, 2.9, 0.9), m.dark)
	_invisible_wall(root, "ossuary_breach_guard", Vector3(23, 2.0, -18), Vector3(4, 2.4, 0.9))
	var bone: Material = game._material(Color("c8b99c"))
	var brng := RandomNumberGenerator.new()
	brng.seed = 418
	for i in 10:
		var tooth := L.box(root, "breach_jag", Vector3(brng.randf_range(21.0, 25.0), 0.8 if i < 5 else 3.2, -18.0),
			Vector3(brng.randf_range(0.3, 0.7), brng.randf_range(0.3, 0.6), 0.95), m.dark, false)
		tooth.rotation.z = brng.randf_range(-0.8, 0.8)
	for i in 9:
		_sphere(root, "breach_skull", Vector3(21.3 + 0.42 * i, 0.95, -17.7 + brng.randf_range(-0.1, 0.1)), 0.15, bone)
	L.box(root, "ossuary_roof", Vector3(23, 6.1, 0.5), Vector3(14.6, 0.7, 37), m.dark, false)
	for pos: Vector3 in [Vector3(20.1, 3.55, -2), Vector3(26.5, 3.9, -6.1), Vector3(23, 3.65, -13.1), Vector3(19, 3.65, 8.7)]:
		var lamp := L.hanging_chain_lamp(game, root, pos, 5.75 - pos.y - 0.4, CRYPT_LIGHT, 1.55, 7.8)
		for n: Node in lamp.find_children("*", "OmniLight3D", true, false):
			(ctx.route_lights as Array).append(n)
			n.add_to_group("story_torch_crypt_route")
	for z: float in [-15.5, -8.2, -1.5, 3.3, 13.5]:
		L.ossuary_niche(root, Vector3(29.42, 1.03, z), -PI * 0.5, m.stone, bone)
	for z: float in [-15.1, -10.1, 8.0]:
		L.ossuary_niche(root, Vector3(16.28, 0.98, z), PI * 0.5, m.stone, bone)
	L.box(root, "ossuary_north_partition", Vector3(20, 2.3, -6), Vector3(8, 6, 0.7), m.dark)
	L.box(root, "ossuary_south_partition", Vector3(26, 2.3, 5.5), Vector3(8, 6, 0.7), m.dark)
	L.archway(root, "ossuary_north_arch", Vector3(26.5, -0.7, -6), 4.6, 3.5, 1.15, m.stone, m.brass)
	L.archway(root, "ossuary_south_arch", Vector3(18.4, -0.7, 5.5), 3.9, 3.5, 1.15, m.stone, m.brass)
	# Ossuary Gate (existing shortcut_door logic) — Caelen's lock, unpicked from the east.
	var shortcut := L.box(root, "shortcut_door", Vector3(9, 0, 17.85), Vector3(0.5, 3.7, 3.9), m.iron, true) as StaticBody3D
	shortcut.set_meta("interact_hint", "OSSUARY GATE — YOUR MASTER'S MARK — UNPICK [HOLD E]")
	shortcut.set_meta("unpick", not bool(st.shortcut_open))
	shortcut.set_meta("lock_id", "ossuary_gate")
	var shape := shortcut.get_child(1) as CollisionShape3D
	shape.position.y = 1.85
	var mesh := shortcut.get_child(0) as MeshInstance3D
	mesh.visible = false
	for i in 6:
		L.box(shortcut, "shortcut_bar", Vector3(0, 1.85, -1.65 + i * 0.66), Vector3(0.22, 3.7, 0.16), m.iron, false)
	for y: float in [0.38, 2.8]:
		L.box(shortcut, "shortcut_brace", Vector3(0, y, 0), Vector3(0.25, 0.17, 3.9), m.brass, false)
	if bool(st.shortcut_open):
		shortcut.position.y = 4.6
		shortcut.collision_layer = 0
	game.shortcut_door = shortcut
	ctx["shortcut"] = shortcut
	L.box(root, "shortcut_north_wall", Vector3(12.2, 2.0, 15.7), Vector3(6.8, 4, 0.65), m.dark)
	L.box(root, "shortcut_south_wall", Vector3(14.3, 2.0, 20), Vector3(10, 4, 0.65), m.dark)
	_watchmens_rest(game, root, st, ctx)
	for z: float in [-15.5, -8.2, -1.5, 7.5, 13.5]:
		game._torch(Vector3(28.9, 2.0, z), "east_crypt")
		(ctx.crypt_lights as Array).append(game.torches.back())
		(game.torches.back() as Node).add_to_group("story_torch_east_crypt")
		L.box(root, "carved_sarcophagus", Vector3(28.65, -0.18, z + 0.6), Vector3(1.6, 1.0, 2.5), m.stone)
	L.box(root, "reliquary_wall", Vector3(27.8, 1.3, 8.9), Vector3(4.5, 4, 0.65), m.dark)
	L.box(root, "reliquary_side", Vector3(25.4, 1.3, 12.9), Vector3(0.65, 4, 7.4), m.dark)
	L.add_rotten_barricade(game, Vector3(27.8, 0.5, 16.7), "court_secret_bar_2", Vector3(4.1, 2.4, 0.45), true)
	L.focus_light(root, Vector3(29, 2.7, 18.35), Vector3(27.8, 0.8, 16.7), CRYPT_LIGHT, 1.55, 24.0)
	game._pickup(Vector3(27.8, -0.05, 13.8), "mana", "court_secret_mana_2")
	game._pickup(Vector3(27.8, -0.05, 11.5), "flask", "court_secret_flask_2")
	for pos: Vector3 in [Vector3(21.5, -0.7, -11), Vector3(25, -0.7, 2.8), Vector3(18.7, -0.7, 8.1)]:
		_urn(game, pos, "court_crypt_urn_%d" % int(pos.z), "mana")
	# Keeper Avun is the Stalker.
	game._enemy(Vector3(25.5, -0.7, -10), true, "court_stalker", false, "stalker")
	game._enemy(Vector3(22.5, -0.7, 2.0), false, "court_east_1", false, "shrieker")
	game._enemy(Vector3(20.7, -0.7, 10.1), false, "court_east_aco", false, "acolyte")
	_plaque(game, Vector3(12.5, 0, -4.8), "KEEPER AVUN", AVUN_TEXT)
	L.add_checkpoint_zone(game, Vector3(13.5, 1.3, -2.0), Vector3(4, 2.8, 6), "court_ossuary", "East Ossuary")
	SD.add_echo_wisp(game, Transform3D(Basis(), Vector3(21.0, -0.7, -9.5)), "echo_watch_captain", {
		"speaker": "LORD MALCOR — ECHO", "speaker_id": "echo", "title": "WATCHMEN'S REST",
		"line": "Lower the portcullis. That is an order. ...No. Not an order. Mine. Lower it.",
		"color": Color("d99cbd"), "radius": 2.8,
	})


# T3: six seats on a 2.6 m ring around the crank altar; seats 2 and 5 rise.
static func _watchmens_rest(game, root: Node3D, st: Dictionary, ctx: Dictionary) -> void:
	var m: Dictionary = game.mats
	var center := Vector3(22, -0.7, -13.1)
	L.box(root, "ossuary_lever_altar", Vector3(22, -0.46, -13.1), Vector3(2.65, 0.48, 1.6), m.brass)
	var dead_lantern := SD.add_broken_lantern(root, Transform3D(Basis(), Vector3(22.85, -0.22, -12.85)), m, "")
	var glow: Variant = dead_lantern.get_meta("glow")
	if glow is OmniLight3D:
		(glow as OmniLight3D).visible = false
	if not bool(st.has_lever):
		game._pickup(Vector3(22, 0.32, -13.1), "iron_lever", "court_iron_lever")
		L.focus_light(root, Vector3(23.8, 3.7, -11.65), Vector3(22, 0.32, -13.1), AMBER, 2.65, 24.0)
	for i in WATCHMAN_SEATS.size():
		var seat: Vector3 = WATCHMAN_SEATS[i]
		var to_center := center - seat
		var yaw := atan2(-to_center.x, -to_center.z)
		var holder := Node3D.new()
		holder.name = "watchman_seat_%d" % (i + 1)
		holder.position = seat
		holder.rotation.y = yaw
		root.add_child(holder)
		L.cylinder(holder, "watch_stool", Vector3(0, 0.2, 0.15), 0.2, 0.4, m.timber, false, 8)
		ctx["watchman_seat_%d" % (i + 1)] = holder
		if i == CAPTAIN_SEAT:
			_chalk(holder, "M.", Vector3(0, 0.42, 0.15), Vector3(-PI * 0.5, 0, 0), 24, Color(0.85, 0.8, 0.7, 0.6))
			continue
		var corpse := SD.add_fallen_guard(holder, Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0.3, 0.15)), "seated", m)
		corpse.name = "watchman_corpse"
		var helm := _sphere(holder, "watchman_helm", Vector3(0.0, 0.12, -0.55), 0.17, m.iron)
		helm.scale = Vector3(1, 0.7, 1.1)
		holder.set_meta("corpse", corpse)
		if (i == 1 or i == 4) and bool(st.has_lever):
			corpse.visible = false
	# Halberds leaned together like an unlit campfire.
	for k in 4:
		var a := TAU * float(k) / 4.0 + 0.4
		var halberd := L.box(root, "watch_halberd", Vector3(22 + cos(a) * 0.35, 0.25, -10.9 + sin(a) * 0.35), Vector3(0.05, 1.9, 0.05), m.timber, false)
		halberd.rotation = Vector3(sin(a) * 0.32, 0, -cos(a) * 0.32)
	SD.add_blood_trail(root, PackedVector3Array([Vector3(23.4, -0.7, -16.4), Vector3(23.0, -0.7, -15.9), Vector3(22.3, -0.7, -15.4)]),
		PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP]), 1306)


# --- Z3: Court of Seals (hub) ----------------------------------------------------

static func _basin(game, root: Node3D, st: Dictionary, ctx: Dictionary) -> void:
	var m: Dictionary = game.mats
	L.slab(root, "basin_court_floor", Rect2(-10, -19.2, 20, 35.4), 0, m.floor)
	L.box(root, "basin_east_wall", Vector3(9.8, 3, 7), Vector3(1, 6, 10), m.dark)
	L.box(root, "basin_east_wall_north", Vector3(9.8, 3, -12.6), Vector3(1, 6, 12.4), m.dark)
	# West wall north: broken open above 2.42 where the Watch Walk ends (one-way drop).
	L.box(root, "basin_west_north_low", Vector3(-10, 1.21, -16), Vector3(1, 2.42, 6), m.dark)
	L.box(root, "basin_west_north_n", Vector3(-10, 4.21, -18.3), Vector3(1, 3.58, 1.4), m.dark)
	L.box(root, "basin_west_north_s", Vector3(-10, 4.21, -13.75), Vector3(1, 3.58, 1.5), m.dark)
	L.box(root, "basin_west_north_top", Vector3(-10, 5.7, -16.05), Vector3(1, 0.6, 3.1), m.dark)
	var jrng := RandomNumberGenerator.new()
	jrng.seed = 2420
	for i in 6:
		var jag := L.box(root, "walk_breach_jag", Vector3(-10.0, jrng.randf_range(2.5, 5.3), -17.6 + 3.1 * float(i % 2)), Vector3(1.05, jrng.randf_range(0.3, 0.6), jrng.randf_range(0.3, 0.6)), m.dark, false)
		jag.rotation.x = jrng.randf_range(-0.6, 0.6)
	L.box(root, "basin_shortcut_partition", Vector3(9, 2.2, 13.7), Vector3(0.9, 4.4, 4.6), m.dark)
	L.archway(root, "basin_south_arch", Vector3(0, 0, 15.7), 11.8, 6.5, 1.4, m.stone, m.brass)
	_tithe_wall(game, root)
	for x: float in [-7.2, 7.2]:
		for z: float in [-13.1, 3, 10.8]:
			L.cylinder(root, "basin_column", Vector3(x, 2.8, z), 0.74, 5.6, m.stone, true, 12)
			game._torch(Vector3(x * 0.88, 2.6, z))
	var idle_rune: Material = game._material(Color("9e6941"), true)
	var active_rune: Material = game._material(CRYPT_LIGHT, true)
	var conduits := {}
	for x: float in [-3.8, 3.8]:
		var pos := Vector3(x, 0, -5)
		var wet := x > 0.0
		var plate := L.box(root, "press_plate", pos + Vector3.UP * 0.06, Vector3(2.3, 0.12, 2.3), m.brass, false)
		var points := PackedVector3Array([Vector3(x, 0, -6.1), Vector3(x, 0, -19)])
		if wet:
			points = PackedVector3Array([Vector3(x, 0.095, -6.1), Vector3(x, 0.095, -8.1), Vector3(x, 0, -8.4), Vector3(x, 0, -19)])
		var conduit := L.add_floor_conduit(root, points, idle_rune, active_rune)
		conduits["east_plate" if wet else "west_plate"] = conduit
		var plate_state := {"node": plate, "pos": pos, "pressed": false, "wet": wet, "conduit": conduit}
		game.pressure_plates.append(plate_state)
		L.watch_puzzle(conduit, func() -> void: L.set_floor_conduit_powered(conduit, plate_state.pressed or st.gate_open))
		L.focus_light(root, Vector3(x * 1.6, 5.6, -7.2), pos, CRYPT_LIGHT if wet else AMBER, 3.8, 24.0)
	root.set_meta("floor_conduits", conduits)
	var channel_pos := Vector3(3.8, 0, -5)
	var channel := L.box(root, "rushing_water_channel", channel_pos + Vector3.UP * 0.07, Vector3(3.3, 0.12, 6.2), m.water, true, L.LAYER_TARGET)
	channel.set_meta("interact_hint", "RUSHING WATER — FREEZE WITH FROST [RMB] BEFORE WEIGHTING PLATE")
	var spray := L.add_steam_jet(channel, Vector3(0, 0.11, -2.8), Vector3(0, 0.1, 1), Color(0.64, 0.87, 1.0, 0.24))
	spray.amount = 18
	channel.set_meta("mist", spray)
	var current := {"node": channel, "pos": channel_pos, "size": Vector3(3.3, 1.5, 6.2), "push_dir": Vector3.BACK, "frozen_timer": 0.0}
	game.water_channels.append(current)
	L.watch_puzzle(channel, func() -> void: spray.emitting = current.frozen_timer <= 0.0)
	L.add_pushable_block(game, Vector3(-3.8, 0.65, -0.4), "plinth_west")
	if bool(st.cage_dropped):
		L.add_pushable_block(game, Vector3(3.8, 0.65, -9.5), "counterweight_east", Vector3(1.4, 1.2, 1.4), m.iron)
	else:
		var cage := L.box(root, "suspended_cage", Vector3(3.8, 5.6, -9.5), Vector3(1.4, 1.2, 1.4), m.iron, false)
		var rope := L.cylinder(root, "cage_rope", Vector3(3.8, 7.2, -9.5), 0.32, 2.6, m.brass, true, 8, L.LAYER_TARGET)
		rope.set_meta("shootable_rope", true)
		rope.set_meta("interact_hint", "CAGE ROPE — SHOOT WITH THE ARBALEST [2] TO DROP COUNTERWEIGHT")
		rope.set_meta("cage", cage)
		game.shootable_targets.append(rope)
		game._light(Vector3(3.8, 6.6, -9.5), Color("e5b96d"), 1.75, 6)
	# North Gallery (NPC-only ledge) and the archive door Seraphina uses during the siege.
	L.slab(root, "north_gallery", Rect2(-9, -18.4, 18, 1.4), 5.0, m.stone, 0.4)
	L.box(root, "north_gallery_rail", Vector3(0, 5.55, -17.06), Vector3(18, 1.1, 0.14), m.iron, false)
	for x: float in [-7.5, -2.5, 2.5, 7.5]:
		L.box(root, "gallery_corbel", Vector3(x, 4.35, -17.75), Vector3(0.5, 0.7, 1.2), m.stone, false)
	L.box(root, "gallery_archive_door", Vector3(-9.45, 6.2, -17.7), Vector3(0.12, 2.4, 1.1), m.timber, false)
	game._light(Vector3(-8.6, 6.6, -17.6), Color("70d7df"), 0.5, 3.5)
	# Hydraulic ram housing beside the gearbox (fed from the cistern).
	L.cylinder(root, "hydraulic_ram", Vector3(-7.8, 1.3, -17.6), 0.55, 2.6, m.brass, true, 12)
	for y: float in [0.4, 1.3, 2.2]:
		L.cylinder(root, "ram_band", Vector3(-7.8, y, -17.6), 0.6, 0.12, m.iron, false, 12)
	var ram_target := Marker3D.new()
	ram_target.name = "ram_housing"
	ram_target.position = Vector3(-7.8, 2.0, -17.6)
	root.add_child(ram_target)
	ctx["ram_housing"] = ram_target
	for off: Vector3 in [Vector3(0.0, 2.7, 0.0), Vector3(0.6, 0.5, 0.3)]:
		var jet := L.add_steam_jet(root, Vector3(-7.8, 0, -17.6) + off, Vector3.UP)
		jet.emitting = false
		(ctx.ram_jets as Array).append(jet)
	_plaque(game, Vector3(-8.6, 0, -13.2), "PORTCULLIS HYDRAULIC", HYDRAULIC_TEXT)
	SD.add_echo_wisp(game, Transform3D(Basis(), Vector3(0, 0, -16.0)), "echo_portcullis_child", {
		"speaker": "A CHILD — ECHO", "speaker_id": "echo", "title": "THE GOUGED BARS",
		"line": "Mama, why are they shutting the gate? Mama?", "color": ECHO_COLOR, "radius": 2.6, "pitch": 1.7,
	})
	game._enemy(Vector3(0, 0, 10.6), false, "court_entry_shr", false, "shrieker")
	game._enemy(Vector3(-2, 0, 2.5), false, "court_shrieker_1", false, "shrieker")
	game._enemy(Vector3(5, 0, -12.6), true, "court_north_exec", false, "executioner")
	game._enemy(Vector3(-6.8, 0, -9.5), false, "court_basin_aco", false, "acolyte")
	game._pickup(Vector3(4.8, 0.5, 12.6), "mana", "court_blue_1")


# T4: nine swollen notices, one tar scrawl, child-height handprints.
static func _tithe_wall(game, root: Node3D) -> void:
	var m: Dictionary = game.mats
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color("b9ad8f")
	paper.roughness = 0.95
	var hand := StandardMaterial3D.new()
	hand.albedo_color = Color("5a0f0b")
	hand.roughness = 0.9
	for side: float in [-1.0, 1.0]:
		L.box(root, "tithe_notice_wall", Vector3(side * 8.0, 2.5, 15.75), Vector3(4.2, 5.0, 0.6), m.dark)
		for i in 9:
			if (side < 0.0) != (i < 5):
				continue
			var col := i % 5 if side < 0.0 else (i - 5)
			var notice := L.box(root, "tithe_notice", Vector3(side * (6.6 + 0.72 * col), 2.2 + 0.9 * float(i % 2), 15.43), Vector3(0.58, 0.8, 0.02), paper, false)
			notice.rotation.z = 0.06 * float((i * 7) % 5 - 2)
		for k in 3:
			var handprint := L.box(root, "child_handprint", Vector3(side * (7.0 + 0.5 * k), 0.85 + 0.08 * k, 15.43), Vector3(0.11, 0.13, 0.01), hand, false)
			handprint.rotation.z = 0.3 * float(k - 1)
	_chalk(root, "THERE ARE NO RAFTS", Vector3(-7.6, 2.9, 15.41), Vector3(0, PI, 0.08), 96, Color(0.04, 0.03, 0.03, 0.95))
	_chalk(root, "THERE ARE NO RAFTS", Vector3(7.6, 2.6, 15.41), Vector3(0, PI, -0.05), 96, Color(0.04, 0.03, 0.03, 0.95))
	_plaque(game, Vector3(-8.0, 0, 14.6), "THE TITHE NOTICE", TITHE_TEXT, true)


# --- Z6: North Portcullis, Bell Causeway, Keep facade & vestibule --------------

static func _causeway(game, root: Node3D, st: Dictionary, ctx: Dictionary) -> void:
	var m: Dictionary = game.mats
	L.slab(root, "bell_causeway", Rect2(-5.6, -42.0, 11.2, 23.4), 0, m.floor)
	L.slab(root, "keep_vestibule_floor", Rect2(-4.0, -50.0, 8.0, 8.2), 0, m.floor)
	L.box(root, "portcullis_wall_w", Vector3(-7.7, 4, -19), Vector3(5.8, 8, 1.25), m.dark)
	L.box(root, "portcullis_wall_e", Vector3(7.7, 4, -19), Vector3(5.8, 8, 1.25), m.dark)
	L.box(root, "portcullis_lintel", Vector3(0, 6.2, -19), Vector3(10.2, 2.8, 1.4), m.dark)
	# Parapets 1.2 m with one rubble gap per side, filled to 1.6 m (no falls).
	for side: float in [-1.0, 1.0]:
		var x := side * 5.45
		var gap_z := -27.0 if side < 0.0 else -33.0
		var segs: Array = [[-19.6, gap_z + 1.0], [gap_z - 1.0, -42.0]]
		for seg: Array in segs:
			var a: float = seg[0]
			var b: float = seg[1]
			L.box(root, "causeway_parapet", Vector3(x, 0.6, (a + b) * 0.5), Vector3(0.8, 1.2, absf(a - b)), m.stone)
		L.box(root, "causeway_rubble_gap", Vector3(x, 0.8, gap_z), Vector3(1.0, 1.6, 2.0), m.stone)
		var gap_pile := SD.add_masonry_pile(root, Transform3D(Basis(), Vector3(x, 0.0, gap_z)), m.stone, 520 + int(side), false)
		gap_pile.scale = Vector3(0.5, 1.2, 0.8)
		_invisible_wall(root, "causeway_guard", Vector3(x, 2.4, -30.8), Vector3(0.8, 4.0, 22.6))
		L.gothic_buttress(root, Vector3(x * 1.45, 0, -18.45), 8.25, 3.3, m.stone, m.dark)
		L.gothic_buttress(root, Vector3(x, -8.0, -30.0), 7.0, 2.3, m.stone, m.dark)
		for z: float in [-26.0, -36.0]:
			L.cylinder(root, "causeway_lamp_post", Vector3(x, 1.9, z), 0.1, 1.4, m.iron, false, 8)
			game._light(Vector3(x * 0.92, 2.8, z), AMBER, 1.4, 6.0)
			_sphere(root, "causeway_lamp_glass", Vector3(x, 2.75, z), 0.14, m.ember)
	L.box(root, "causeway_underpier", Vector3(0, -7.2, -30.8), Vector3(10.6, 14.0, 3.0), m.dark, false)
	_plaque(game, Vector3(4.6, 0, -30), "THE BELL CAUSEWAY", CAUSEWAY_TEXT)
	L.add_checkpoint_zone(game, Vector3(0, 1.3, -22), Vector3(10, 2.8, 2), "court_causeway", "Bell Causeway")
	_keep_facade(game, root, st, ctx)
	# Portcullis and gearbox (existing systems, re-fictioned).
	var shaft_source := Vector3(-5.2, 8.4, -18.1)
	var shaft_target := Vector3(-0.65, 0.4, -13.6)
	L.box(root, "portcullis_coping", Vector3(-5.2, 8.16, -18.95), Vector3(1.7, 0.55, 1.6), m.stone, false)
	var mist := FogVolume.new()
	mist.name = "portcullis_mist"
	mist.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	mist.size = Vector3(5.2, 10.8, 5.2)
	mist.position = shaft_source.lerp(shaft_target, 0.54)
	mist.quaternion = Quaternion(Vector3.UP, shaft_target.direction_to(shaft_source))
	var mist_material := FogMaterial.new()
	mist_material.density = 0.048
	mist_material.albedo = Color("8497ae")
	mist.material = mist_material
	root.add_child(mist)
	L.focus_light(root, shaft_source, shaft_target, CRYPT_LIGHT, 7.05, 28.0, 4.2)
	L.focus_light(root, Vector3(-8.1, 4.7, -16.55), Vector3(-5.8, 0.95, -16.9), AMBER, 4.4, 27.0)
	game.switch_node = L.lever(root, "north_gearbox", Vector3(-5.8, 0, -16.9), m.dark, m.brass,
		"NORTH GEARBOX — THE CRANK IS MISSING (EAST OSSUARY)")
	game.switch_node.set_meta("lock_id", "gearbox")
	game.switch_node.get_meta("lever_arm").visible = bool(st.lever_inserted)
	ctx["gearbox"] = game.switch_node
	game._build_gate()
	var portcullis: StaticBody3D = game.gate
	ctx["gate"] = portcullis
	for child in portcullis.get_children():
		if child is CollisionShape3D:
			var collider := child as CollisionShape3D
			var shape := collider.shape as BoxShape3D
			shape.size.y += 0.4
			collider.position.y -= 0.2
	for i in range(-4, 5):
		L.box(portcullis, "portcullis_tooth", Vector3(i * 1.05, -0.19, 0), Vector3(0.18, 0.43, 0.28), m.iron, false)
	# T5 "The Gouged Bars": fingernail scoring on the south (Court) face, grooved sill, small shoes.
	var scratch: Material = game._material(Color("d6d0c2"))
	var grng := RandomNumberGenerator.new()
	grng.seed = 4019
	for i in range(-4, 5):
		for k in 4:
			var g := L.box(portcullis, "bar_gouge", Vector3(i * 1.05 + grng.randf_range(-0.05, 0.05), grng.randf_range(0.2, 1.6), 0.15), Vector3(0.03, grng.randf_range(0.15, 0.4), 0.01), scratch, false)
			g.rotation.z = grng.randf_range(-0.35, 0.35)
	for k in 12:
		L.box(root, "sill_groove", Vector3(grng.randf_range(-4.4, 4.4), 0.005, -18.55 + grng.randf_range(0.0, 0.3)), Vector3(0.025, 0.01, grng.randf_range(0.2, 0.5)), m.dark, false)
	for k in 3:
		for s2: float in [-1.0, 1.0]:
			L.box(root, "small_shoe", Vector3(-2.2 + 2.1 * k + s2 * 0.06, 0.03, -17.9 + 0.2 * k), Vector3(0.07, 0.06, 0.17), m.dark, false)
	if ctx.directed and not bool(st.gate_open):
		portcullis.position.y = float(st.portcullis_height)
		portcullis.collision_layer = 0 if float(st.portcullis_height) >= 4.9 else L.LAYER_WORLD
	# Arrivals and fallbacks (registered with the director in _register_story()).
	ctx["arrival_court_from_tower"] = _marker(root, "court_from_tower", Vector3(0, 0.1, -30.0), PI)
	ctx["arrival_court_causeway_safe"] = _marker(root, "court_causeway_safe", Vector3(0, 0.1, -27.0), PI)
	ctx["arrival_court_start"] = _marker(root, "court_start", Vector3(0, 6.1, 61.0), 0.0)
	ctx["wave_origin"] = _marker(root, "court_north_wave_origin", Vector3(0, 4.0, -19.0), 0.0)
	ctx["front_origin"] = _marker(root, "causeway_front_origin", Vector3(0, 1.0, -44.0), 0.0)


static func _keep_facade(game, root: Node3D, st: Dictionary, ctx: Dictionary) -> void:
	var m: Dictionary = game.mats
	L.box(root, "keep_facade_w", Vector3(-7.5, 11.0, -44.0), Vector3(9.0, 22.0, 4.0), m.dark)
	L.box(root, "keep_facade_e", Vector3(7.5, 11.0, -44.0), Vector3(9.0, 22.0, 4.0), m.dark)
	L.box(root, "keep_facade_lintel", Vector3(0, 15.0, -44.0), Vector3(6.0, 14.0, 4.0), m.dark)
	for side: float in [-1.0, 1.0]:
		var haunch := L.box(root, "keep_door_haunch", Vector3(side * 2.2, 7.45, -42.6), Vector3(2.0, 0.9, 1.2), m.stone, false)
		haunch.rotation.z = side * 0.42
		L.box(root, "keep_door_jamb", Vector3(side * 3.25, 3.6, -41.85), Vector3(0.5, 7.2, 0.5), m.stone, false)
		L.box(root, "keep_tower", Vector3(side * 12.6, 12.0, -44.0), Vector3(1.8, 24.0, 4.8), m.dark)
		L.cone(root, "keep_tower_spire", Vector3(side * 12.6, 27.5, -44.0), 1.3, 0.06, 7.0, m.dark, 8)
		var gable := L.box(root, "keep_gable", Vector3(side * 4.9, 24.4, -44.0), Vector3(10.6, 1.2, 3.8), m.dark, false)
		gable.rotation.z = -side * 0.5
		for y: float in [5.0, 12.0]:
			L.box(root, "keep_statue_niche", Vector3(side * 7.5, y + 1.3, -41.9), Vector3(1.3, 2.8, 0.3), m.stone, false)
			L.cone(root, "keep_saint", Vector3(side * 7.5, y + 0.95, -41.6), 0.42, 0.18, 1.9, m.stone, 8)
	var rose := L.cylinder(root, "keep_rose_window", Vector3(0, 14.2, -41.9), 2.1, 0.2, m.brass, false, 24)
	rose.rotation.x = PI * 0.5
	var glass: Material = game._material(Color("a678ff"), true)
	var pane := L.cylinder(rose, "keep_rose_glass", Vector3(0, 0.06, 0), 1.8, 0.1, glass, false, 24)
	pane.name = "keep_rose_glass"
	_chalk(root, "V A E L O R", Vector3(0, 9.0, -41.85), Vector3.ZERO, 120, Color(0.7, 0.62, 0.48, 0.8))
	# Vestibule: dark, ceiling 7 m, matched on the Tower side at Ch II z 33.
	for side: float in [-1.0, 1.0]:
		L.box(root, "keep_vestibule_wall", Vector3(side * 4.3, 3.5, -48.0), Vector3(0.6, 7.0, 4.2), m.dark)
	L.box(root, "keep_vestibule_back", Vector3(0, 3.5, -50.3), Vector3(9.2, 7.0, 0.6), m.dark)
	L.box(root, "keep_vestibule_ceiling", Vector3(0, 7.2, -47.0), Vector3(9.2, 0.4, 7.0), m.dark)
	var spill := OmniLight3D.new()
	spill.name = "keep_violet_spill"
	spill.light_color = Color("a678ff")
	spill.light_energy = 3.0 if bool(st.keep_doors_open) else 0.45
	spill.omni_range = 9.0
	spill.light_volumetric_fog_energy = 0.6
	spill.position = Vector3(0, 3.0, -47.0)
	root.add_child(spill)
	ctx["keep_spill"] = spill
	# Two 3 x 7 m bronze leaves hinged at (±3, 0, -42), starting 20° ajar.
	var doors := Node3D.new()
	doors.name = "keep_doors"
	root.add_child(doors)
	doors.set_meta("look_center", Vector3(0, 3.5, -42.2))
	ctx["keep_doors"] = doors
	var angle := KEEP_DOOR_OPEN if bool(st.keep_doors_open) or not ctx.directed else KEEP_DOOR_AJAR
	for side: float in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.name = "keep_door_l" if side < 0.0 else "keep_door_r"
		pivot.position = Vector3(side * 3.0, 0, -42.15)
		pivot.rotation.y = -side * deg_to_rad(angle)
		doors.add_child(pivot)
		var leaf := L.box(pivot, "keep_door_leaf", Vector3(-side * 1.5, 3.5, 0), Vector3(3.0, 7.0, 0.25), m.brass)
		for y: float in [1.2, 3.5, 5.8]:
			L.box(leaf, "keep_door_strap", Vector3(0, y - 3.5, 0.14), Vector3(2.9, 0.16, 0.04), m.iron, false)
		var ring := L.cylinder(leaf, "keep_door_ring", Vector3(-side * 1.1, -0.3, 0.18), 0.16, 0.04, m.iron, false, 12)
		ring.rotation.x = PI * 0.5
		ctx["keep_door_" + ("l" if side < 0.0 else "r")] = pivot


static func _marker(root: Node3D, marker_name: String, pos: Vector3, yaw: float) -> Marker3D:
	var mk := Marker3D.new()
	mk.name = marker_name
	mk.position = pos
	mk.rotation.y = yaw
	root.add_child(mk)
	return mk


# =============================================================================
# Actors (positions restored from durable state)
# =============================================================================

static func _actors(game, _root: Node3D, st: Dictionary, ctx: Dictionary, d: SD) -> void:
	var world := _world(st)
	var directed := d != null
	if directed:
		for id: String in MARKS:
			var spec: Array = MARKS[id]
			d.register_mark(id, spec[0], float(spec[1]))
	# Brother Torin.
	var mark := "torin_wicket"
	if bool(st.torin_hollowed) or (directed and (int(st.siege_stage) > 0 or bool(st.has_lever))):
		mark = "torin_gearbox"
	elif bool(st.coldopen_done) or not directed:
		mark = "torin_camp"
	var tspec: Array = MARKS[mark]
	var torin := _make_npc(game, "torin", "torin", "Brother Torin", [_torin_line(st)], tspec[0], float(tspec[1]), TORIN_COLOR)
	ctx["torin_entry"] = torin
	world.torin_mark = mark
	_apply_hollowing(torin, int(st.torin_stage))
	var rig: Node3D = torin.rig
	if bool(st.torin_hollowed) or mark == "torin_camp":
		rig.set_meta("gesture", "sit")
	elif mark == "torin_gearbox" and int(st.siege_stage) > 0:
		rig.set_meta("gesture", "crank")
	if directed:
		d.register_actor("torin", torin.node, rig, {})
	# Archivist Seraphina in the gatehouse cell.
	if not bool(st.coldopen_done) or not directed:
		var smark := "seraphina_winch" if str(world.seraphina_mark) == "seraphina_winch" else "seraphina_grate"
		var lines: Array = ["Listen to the Lull, Caelen. Count it with me."]
		if not directed:
			lines = [
				"Caelen. Entry: the exile returns. Three days after the writ.",
				"The Lull is ringing flat. Your lock is failing, and the bell is listening for names.",
				"The arbalest is on the cistern shrine. The gearbox crank is in the ossuary. Go.",
			]
		var sspec: Array = MARKS[smark]
		var sera := _make_npc(game, "seraphina", "seraphina_gatehouse", "Archivist Seraphina", lines, sspec[0], float(sspec[1]), Color("70d7df"))
		if directed:
			d.register_actor("seraphina", sera.node, sera.rig, {})
	if not directed:
		return
	# W. Ware, the fleeing Bell-Watch guard (hidden until he runs).
	if not bool(st.fractured):
		var gspec: Array = MARKS["guard_start"]
		var guard := _make_npc(game, "bellwatch_guard", "ware_guard", "Bell-Watch Guard", ["Open the bar! It's taking names!"], gspec[0], float(gspec[1]), GUARD_COLOR)
		(guard.node as Node3D).visible = false
		ctx["guard"] = guard.node
		d.register_actor("bellwatch_guard", guard.node, guard.rig, {})
	# Seraphina at the archive window over the cistern.
	if not bool(world.get("seraphina_cistern_left", false)):
		var cspec: Array = MARKS["seraphina_cistern"]
		var cist := _make_npc(game, "seraphina", "seraphina_cistern", "Archivist Seraphina", ["Ride the rafts to the west parapet, Caelen."], cspec[0], float(cspec[1]), Color("70d7df"))
		(cist.node as Node3D).visible = bool(st.coldopen_done)
		d.register_actor("seraphina_cistern", cist.node, cist.rig, {})
		var lantern: OmniLight3D = ctx.cistern_lantern
		lantern.light_energy = 2.4 if bool(st.coldopen_done) else 0.0
	# Seraphina on the North Gallery (appears for the siege).
	if not bool(st.torin_hollowed):
		var sieging := int(st.siege_stage) > 0
		var gal_spec: Array = MARKS["seraphina_gallery" if sieging else "seraphina_gallery_door"]
		var gal := _make_npc(game, "seraphina", "seraphina_gallery", "Archivist Seraphina", ["Keep them off Torin."], gal_spec[0], PI, Color("70d7df"))
		(gal.node as Node3D).visible = sieging
		d.register_actor("seraphina_gallery", gal.node, gal.rig, {})


static func _make_npc(game, kind: String, npc_id: String, speaker: String, lines: Array, pos: Vector3, yaw: float, accent: Color) -> Dictionary:
	game._npc(pos, kind, npc_id, speaker, lines, yaw)
	var entry: Dictionary = game.npc_nodes.back()
	entry["accent"] = accent
	var holder: Node3D = entry.node
	for c: Node in holder.get_children():
		if c is OmniLight3D:
			(c as OmniLight3D).light_color = accent
	return entry


static func _apply_hollowing(entry: Dictionary, stage: int) -> void:
	var rig: Variant = entry.get("rig")
	if rig is Node3D and is_instance_valid(rig):
		(rig as Node3D).set_meta("hollowing_stage", stage)
		Meshes3D.set_npc_hollowing(rig, stage)
	var holder: Node3D = entry.node
	for c: Node in holder.get_children():
		if c is OmniLight3D:
			(c as OmniLight3D).light_energy = lerpf(1.8, 0.3, float(stage) / 4.0)


static func _torin_line(st: Dictionary) -> String:
	if bool(st.torin_hollowed):
		return TORIN_HOLLOW_LINES[0]
	if bool(st.has_lever) or int(st.siege_stage) > 0:
		return "I'm here. At the— the gearbox. I said I'd remember."
	if bool(st.coldopen_done):
		return "Crank's in the ossuary. Arbalest's on the shrine. I'll remember. I will."
	return "In, quick-like. She's waiting at the grate."


static func _remove_npc(game, holder: Node3D) -> void:
	var npcs: Array = game.npc_nodes
	for i in range(npcs.size() - 1, -1, -1):
		if (npcs[i] as Dictionary).get("node") == holder:
			npcs.remove_at(i)
	if is_instance_valid(holder):
		holder.queue_free()


# Rebuild accepted-but-unresolved story enemies with stable IDs (dead filtered).
static func _restore_spawns(game, st: Dictionary, ctx: Dictionary) -> void:
	if bool(st.has_lever) or bool(st.ambush_done):
		for id: String in AMBUSH_IDS:
			_spawn(game, st, id)
	if not ctx.directed:
		game._enemy(Vector3(-7.5, 0, 19.2), false, "court_cloister_shr_2", false, "shrieker")
		return
	if bool(st.fractured):
		for id: String in COLDOPEN_IDS:
			_spawn(game, st, id)
	if _is_done(st, "cloister_breach"):
		for id: String in CLOISTER_IDS:
			_spawn(game, st, id)
	if bool(st.cistern_raised):
		for id: String in RISEN_IDS:
			_spawn(game, st, id)
	if int(st.siege_stage) > 0 and not bool(st.gate_open):
		for s in range(1, int(st.siege_stage) + 1):
			for id: String in WAVE_IDS[s]:
				_spawn(game, st, id)


# Without a StoryDirector: the bar opens on approach and the Keep threshold loads the Tower.
static func _legacy_fallbacks(game, root: Node3D, st: Dictionary, ctx: Dictionary) -> void:
	var bar: StaticBody3D = ctx.bar
	if not bool(st.gatehouse_open):
		var approach := L.add_trigger_volume(game, Vector3(-3.05, 1.4, 32.4), Vector3(2.2, 2.8, 2.8), "gatehouse_meeting")
		approach.body_entered.connect(func(body: Node3D) -> void:
			if body != game.player or st.gatehouse_open:
				return
			st.gatehouse_open = true
			var opening := bar.create_tween()
			opening.tween_interval(1.25)
			opening.tween_property(bar, "position:y", 6.35, 0.8)
			opening.tween_callback(func() -> void: bar.collision_layer = 0)
		)
	var threshold := _area(root, "keep_threshold_legacy", Vector3(0, 1.5, -45.0), Vector3(7.0, 3.0, 2.0))
	threshold.monitoring = true
	threshold.body_entered.connect(func(body: Node3D) -> void:
		if body == game.player and bool(st.gate_open):
			game.call_deferred("_load_chapter", "ch2_tower", true)
	)


# =============================================================================
# StoryDirector registration
# =============================================================================

static func _register_story(game, root: Node3D, st: Dictionary, ctx: Dictionary, d: SD, landmarks: Node3D) -> void:
	var bell: Variant = landmarks.get_meta("bell") if landmarks.has_meta("bell") else null
	if bell is Node3D:
		d.register_target("bell_far", bell)
	var cb_holder := {}
	cb_holder["cb"] = func(mode: String, _pos: Vector3) -> void: _on_bell_tolled(landmarks, mode)
	d.bell_tolled.connect(cb_holder.cb)
	root.tree_exiting.connect(func() -> void: _disconnect_toll(d, cb_holder.cb))
	for pair: Array in [
		["gatehouse_bar", ctx.bar], ["inner_arch_z30", ctx.inner_arch], ["gatehouse_outer_arch", ctx.outer_arch],
		["gatehouse_outer_rubble", ctx.outer_rubble], ["court_north_wave_origin", ctx.wave_origin],
		["causeway_front_origin", ctx.front_origin], ["cistern_sluice_lever", ctx.sluice], ["hesk_raft", ctx.hesk_raft],
		["ram_housing", ctx.ram_housing], ["north_gearbox", ctx.gearbox], ["keep_doors", ctx.keep_doors],
		["portcullis", ctx.gate], ["drain_grate", ctx.drain_grate],
	]:
		if pair[1] is Node3D:
			d.register_target(str(pair[0]), pair[1])
	for z: int in [19, 23, 27]:
		d.register_target("cloister_breach_window_%d" % z, ctx["window_%d" % z])
	for i in WATCHMAN_SEATS.size():
		d.register_target("watchman_seat_%d" % (i + 1), ctx["watchman_seat_%d" % (i + 1)])
	for l: Variant in ctx.gatehouse_lights:
		d.register_light_group("gatehouse", l)
	for l: Variant in ctx.crypt_lights:
		d.register_light_group("east_crypt", l)
	for l: Variant in ctx.route_lights:
		d.register_light_group("crypt_route", l)
	for id: String in ["court_from_tower", "court_causeway_safe", "court_start"]:
		d.register_arrival(id, ctx["arrival_" + id])
	_register_commits(game, st, ctx, d)
	_register_sequences(st, ctx, d)
	# Story volumes (§6.3).
	_story_volume(root, d, "torin_hail", Vector3(0, 1.5, 47.0), Vector3(11.6, 4, 2), "torin_hail")
	_story_volume(root, d, "gatehouse_meeting", Vector3(0, 1.4, 33.6), Vector3(7.6, 2.8, 3.6), "gatehouse_meeting")
	_story_volume(root, d, "cloister_breach_line", Vector3(-1.5, 1.5, 20.5), Vector3(20, 3, 1), "cloister_breach")
	_story_volume(root, d, "cistern_arrival", Vector3(-11, 1.5, 2), Vector3(3, 3, 18), "cistern_arrival")
	_story_volume(root, d, "court_causeway_toll", Vector3(0, 1.5, -24), Vector3(11, 4, 2), "viaduct_toll")
	_story_volume(root, d, "keep_doors", Vector3(0, 1.5, -38), Vector3(11, 4, 2), "keep_doors")
	# Physical exit into the Keep (no portal).
	var zone := L.add_transition_zone(root, Transform3D(Basis(), Vector3(0, 1.5, -44.0)), Vector3(7.6, 3.0, 3.0), "court_to_tower")
	var aperture: Marker3D = zone.get_meta("aperture")
	var route_open := func() -> bool: return bool(st.get("gate_open", false))
	d.register_transition(zone, aperture, {
		"id": "court_to_tower", "destination": "ch2_tower", "arrival_id": "tower_from_court",
		"label": "THE BELL KEEP", "kind": "arch", "direction_local": Vector3.FORWARD,
		"safe_return_id": "court_causeway_safe",
		"is_open": route_open,
	})


static func _on_bell_tolled(landmarks: Node3D, mode: String) -> void:
	if not is_instance_valid(landmarks):
		return
	var color: Color = SD.TOLL_COLORS.get(mode, SD.TOLL_COLORS.lull)
	L.pulse_landmark_bell(landmarks, color, 7.0 if mode == "inverted" else 3.5, 1.6)


static func _disconnect_toll(d: SD, cb: Callable) -> void:
	if is_instance_valid(d) and d.bell_tolled.is_connected(cb):
		d.bell_tolled.disconnect(cb)


static func _area(root: Node3D, area_name: String, center: Vector3, size: Vector3) -> Area3D:
	var area := Area3D.new()
	area.name = area_name
	area.position = center
	area.collision_layer = 0
	area.collision_mask = L.LAYER_PLAYER
	area.monitorable = false
	area.monitoring = false
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	area.add_child(cs)
	root.add_child(area)
	return area


static func _story_volume(root: Node3D, d: SD, trigger_id: String, center: Vector3, size: Vector3, seq: String) -> void:
	d.register_story_volume(_area(root, "story_" + trigger_id, center, size), trigger_id, SEQ + seq)


static func _register_commits(game, st: Dictionary, ctx: Dictionary, d: SD) -> void:
	d.register_commit("court_objective", func(text: Variant) -> void: _set_objective(game, str(text)))
	d.register_commit("court_checkpoint", func(p: Variant) -> void: _checkpoint(game, p))
	d.register_commit("court_spawn", func(ids: Variant) -> void: _spawn_list(game, st, ids))
	d.register_commit("court_fracture_begin", func() -> void: _on_fracture_begin(game, st, ctx))
	d.register_commit("court_guard_run", func() -> void: _on_guard_run(ctx))
	d.register_commit("court_bar_raised", func() -> void: _on_bar_raised(game, st, ctx))
	d.register_commit("court_try_outer_collapse", func() -> void: ctx.collapse_wait = 0.0)
	d.register_commit("court_guard_buried", func() -> void: _on_guard_buried(game, st, ctx))
	d.register_commit("court_coldopen_breach", func() -> void: ctx.breach_t = float(ctx.t))
	d.register_commit("court_unlock_wicket", func() -> void: _on_unlock_wicket(game, ctx))
	d.register_commit("court_cell_door", func(angle: Variant) -> void: _swing(ctx.cell_door, float(angle), 0.9))
	d.register_commit("court_coldopen_done", func() -> void: _on_coldopen_done(game, st, ctx, d))
	d.register_commit("court_torin_mark", func(mark: Variant) -> void: st.torin_mark = str(mark))
	d.register_commit("court_breach_window", func(z: Variant) -> void: _on_breach_window(game, ctx, int(z)))
	d.register_commit("court_cistern_lantern", func(mode: Variant) -> void: _cistern_lantern(ctx, str(mode)))
	d.register_commit("court_risen", func() -> void: _on_risen(game, st))
	d.register_commit("court_cistern_left", func() -> void: _on_cistern_left(st, ctx))
	d.register_commit("court_blackout_begin", func() -> void: _on_blackout_begin(game, st))
	d.register_commit("court_watchmen_rise", func() -> void: _on_watchmen_rise(game, st, ctx))
	d.register_commit("court_siege_ratchet", func() -> void: _on_siege_ratchet(game, st, ctx, d))
	d.register_commit("court_siege_stage", func(stage: Variant) -> void: _siege_stage(game, st, ctx, int(stage)))
	d.register_commit("court_crank_release", func() -> void: _on_crank_release(game, ctx))
	d.register_commit("court_torin_hollowed", func() -> void: _on_torin_hollowed(game, st, ctx))
	d.register_commit("court_keep_doors", func() -> void: _on_keep_doors(st, ctx))


# --- beat helpers -------------------------------------------------------------

static func _b(id: String, at: float, op: String, target: String = "", args: Dictionary = {}) -> Dictionary:
	return {"id": id, "at": at, "op": op, "target": target, "args": args}


# Actor beats are optional: an actor that has already left never invalidates a sequence.
static func _a(id: String, at: float, op: String, target: String, args: Dictionary = {}) -> Dictionary:
	return {"id": id, "at": at, "op": op, "target": target, "args": args, "optional": true}


static func _say(line_id: String, at: float, speaker: String, line: String, duration: float, target: String = "", extra: Dictionary = {}) -> Dictionary:
	var args := {"speaker": speaker, "line": line, "duration": duration, "id": line_id}
	match speaker:
		"torin":
			args["color"] = TORIN_COLOR
		"guard":
			args["color"] = GUARD_COLOR
		"hollow_choir":
			args["color"] = CHOIR_COLOR
	args.merge(extra, true)
	return {"id": line_id.replace(".", "_"), "at": at, "op": "voice", "target": target, "args": args}


static func _bark(id: String, at: float, line: String, origin: Variant, target: String = "") -> Dictionary:
	var args := {"speaker": "whisper", "line": line}
	if origin is Vector3:
		args["origin"] = origin
	return {"id": id, "at": at, "op": "bark", "target": target, "args": args}


static func _commit(id: String, at: float, action: String, payload: Variant = null) -> Dictionary:
	var args := {"action": action}
	if payload != null:
		args["payload"] = payload
	return _b(id, at, "commit", "", args)


static func _journal(at: float, journal_id: String, title: String, body: String) -> Dictionary:
	return _b("journal", at, "commit", "", {"journal": {"id": journal_id, "title": title, "body": body}})


static func _toll(id: String, at: float, mode: String, extra: Dictionary = {}) -> Dictionary:
	var args := {"mode": mode, "max_dist": BELL_RANGE}
	args.merge(extra, true)
	return _b(id, at, "bell_toll", "bell_far", args)


static func _seq(d: SD, id: String, beats: Array, extra: Dictionary = {}) -> void:
	var spec := {"id": SEQ + id, "once": true, "beats": beats}
	spec.merge(extra, true)
	d.register_sequence(spec)


static func _register_sequences(st: Dictionary, ctx: Dictionary, d: SD) -> void:
	var cistern_present := func() -> bool: return not bool(_world(st).get("seraphina_cistern_left", false))
	var not_fractured := func() -> bool: return not bool(st.fractured)
	var after_coldopen := func() -> bool: return bool(st.coldopen_done)
	var gate_is_open := func() -> bool: return bool(st.gate_open)
	var torin_awake := func() -> bool: return not bool(st.torin_hollowed)
	var cistern_ready := func() -> bool: return bool(st.coldopen_done) and d.get_actor("seraphina_cistern") != null and not bool(_world(st).get("seraphina_cistern_left", false))
	var fracture_reconcile := func() -> void: _reconcile_fracture(st, ctx)
	var hollow_reconcile := func() -> void: _on_torin_hollowed_state(st)
	# ---- Cold open: "The Night the Bell Cracked" -----------------------------
	_seq(d, "coldopen_arrival", [
		_b("lull_loop", 0.0, "chain", "", {"sequence": SEQ + "lull_loop"}),
		_journal(0.5, "story_ch1_arrival", "THE NIGHT THE BELL CRACKED",
			"A lantern swings at the end of the rain-dark viaduct. Above the gatehouse roofs the Great Bell hangs in its yoke, ringing the Lull."),
		_a("lantern", 3.0, "gesture", "torin", {"name": "lantern_wave", "hold": true}),
		_a("lantern_face", 3.0, "look_at", "torin", {"at": "$player", "duration": 1.0}),
	])
	d.register_sequence({"id": SEQ + "lull_loop", "once": false, "beats": [
		_toll("lull_toll", 0.0, "lull", {"period": 8.0, "loop_id": "court_lull", "shake": false}),
	]})
	_seq(d, "torin_hail", [
		_a("look", 0.0, "look_at", "torin", {"at": "$player", "duration": 1.2}),
		_a("raise", 0.1, "gesture", "torin", {"name": "lantern_raise", "duration": 1.4}),
		_say("c1.tor.01", 0.2, "torin", "Hold there! Lantern up— show your face!", 2.6, "torin"),
		_say("c1.tor.02", 2.9, "torin", "...Guild coat. Ward-iron at the belt.", 2.8, "torin"),
		_say("c1.tor.03", 5.8, "torin", "You're him. The lock-smith. Gods, she said you'd come.", 3.4, "torin"),
		_say("c1.tor.04", 9.3, "torin", "Brother Torin, Bell-Watch. What's left of it. In, quick-like.", 3.6, "torin"),
		_a("limp_to_grate", 9.6, "walk_to", "torin", {"mark": "torin_grate", "speed": "limp"}),
		_a("glance_back", 11.4, "look_at", "torin", {"at": "$player", "duration": 0.7}),
		_say("c1.tor.05", 13.0, "torin", "She barred herself in the cell-house three nights back. Says the bell's ringing flat.", 4.4, "torin"),
		_commit("torin_mark", 13.0, "court_torin_mark", "grate"),
	], {"when": not_fractured})
	_seq(d, "gatehouse_meeting", [
		_b("lull_rephase", 0.0, "stop_loop", "", {"loop_id": "court_lull"}),
		_a("face", 0.0, "look_at", "seraphina", {"at": "$player", "duration": 1.0}),
		_a("torin_to_bar", 0.2, "walk_to", "torin", {"mark": "torin_bar", "speed": "limp"}),
		_say("c1.ser.01", 0.6, "seraphina", "Caelen.", 1.6, "seraphina"),
		_say("c1.ser.02", 2.4, "seraphina", "Entry: the exile returns. Three days after the writ.", 3.2, "seraphina"),
		_say("c1.ser.03", 5.8, "seraphina", "Don't. I know what you'd say.", 2.4, "seraphina"),
		_say("c1.ser.04", 8.4, "seraphina", "Listen to the Lull. Count it with me.", 2.8, "seraphina"),
		_toll("lull_counted", 11.6, "lull", {"period": 8.0, "loop_id": "court_lull", "shake": false}),
		_say("c1.ser.05", 11.7, "seraphina", "One...", 1.4, "seraphina"),
		_say("c1.ser.06", 19.6, "seraphina", "Two...", 1.4, "seraphina"),
		_b("third_comes_early", 22.7, "chain", "", {"sequence": SEQ + "gatehouse_fracture"}),
		_journal(1.0, "story_ch1_meeting", "THE ARCHIVIST BEHIND THE GRATE",
			"Seraphina Vant, Keeper of the Register, barred in the gatehouse cell. \"Entry: the exile returns. Three days after the writ.\""),
	], {"when": not_fractured})
	_seq(d, "gatehouse_fracture", [
		_b("lull_stop", 0.0, "stop_loop", "", {"loop_id": "court_lull"}),
		_toll("crack_toll", 0.0, "inverted", {"shake_amount": 0.06}),
		_b("crack_2d", 0.02, "foley", "", {"sound": "bell_crack", "2d": true, "vol_db": -10.0}),
		_commit("fracture_state", 0.05, "court_fracture_begin"),
		_b("wave", 0.35, "resonance", "court_north_wave_origin", {"radius": 60.0, "speed": 40.0, "strength": 0.10, "color": "b07cff"}),
		_b("gutter", 1.55, "torch_group", "", {"group": "gatehouse", "scale": 0.15, "duration": 1.2, "flicker": 0.45}),
		{"id": "fissure", "at": 1.55, "op": "fissure", "target": "inner_arch_z30", "optional": true,
			"args": {"offset": Vector3(0, 2.55, 0.8), "size": Vector2(5.0, 1.1), "color": "bba1ff", "branches": 5, "grow_time": 0.8}},
		_b("dust", 1.6, "dust", "", {"pos": Vector3(0, 5.0, 30.9), "dir": Vector3.DOWN, "kind": "stone"}),
		_a("torin_clutch", 1.6, "gesture", "torin", {"name": "clutch_head", "duration": 1.2}),
		_b("torin_motes", 1.6, "hollowing_motes", "", {"actor": "torin", "duration": 1.5, "target_dir": "bell_far"}),
		_a("torin_stage_1", 1.62, "set_hollowing", "torin", {"stage": 1}),
		_say("c1.ser.07", 1.9, "seraphina", "That's not the Lull.", 1.8, "seraphina"),
		_a("ser_step_back", 1.9, "walk_to", "seraphina", {"mark": "seraphina_step_back", "speed": "walk"}),
		_say("c1.tor.06", 3.8, "torin", "Oh— what's my mother's... I had it. I had it just now.", 3.2, "torin"),
		_a("torin_kneel", 3.1, "gesture", "torin", {"name": "kneel", "hold": true}),
		_commit("guard_show", 6.0, "court_guard_run"),
		_a("guard_run", 6.0, "walk_to", "bellwatch_guard", {"mark": "guard_bar", "speed": 5.2}),
		_say("c1.ser.08", 7.1, "seraphina", "That was the Tithe toll. Inverted. It's calling the upper city.", 3.4, "seraphina"),
		_b("guard_bangs_1", 7.9, "foley", "", {"sound": "hit", "pos": Vector3(0.8, 1.4, 29.9), "pitch": 0.7}),
		_commit("chasers", 8.0, "court_spawn", COLDOPEN_IDS),
		_b("guard_bangs_2", 9.1, "foley", "", {"sound": "hit", "pos": Vector3(0.8, 1.4, 29.9), "pitch": 0.62}),
		_bark("third_bell", 9.5, "—third bell—", Vector3(0, 1.6, 21.0)),
		_say("c1.grd.01", 10.6, "guard", "Open the bar! It's taking names— it's TAKING—", 2.6, "bellwatch_guard"),
		_say("c1.ser.09", 13.3, "seraphina", "If I lift it, they follow him in.", 2.4, "seraphina"),
		_a("ser_to_winch", 13.3, "walk_to", "seraphina", {"mark": "seraphina_winch", "speed": "walk"}),
		_a("torin_reach", 15.6, "gesture", "torin", {"name": "beckon", "duration": 1.0}),
		_say("c1.tor.07", 15.8, "torin", "Archivist—!", 1.2, "torin"),
		_say("c1.ser.10", 17.1, "seraphina", "...Damn the record.", 1.8, "seraphina"),
		_a("ser_winch", 17.2, "gesture", "seraphina", {"name": "winch", "duration": 1.4}),
		{"id": "lift_bar", "at": 18.6, "op": "move_body", "target": "gatehouse_bar", "optional": true,
			"args": {"offset": Vector3(0, 4.5, 0), "duration": 0.8, "cue": "lift", "disable_collision": true, "commit": "court_bar_raised"}},
		_a("guard_flee", 19.4, "walk_to", "bellwatch_guard", {"route": [Vector3(1.6, 0, 33.0)], "mark": "guard_fall", "speed": 5.2}),
		_toll("second_toll", 20.6, "inverted", {"pitch": 0.9}),
		_b("second_wave", 20.62, "resonance", "court_north_wave_origin", {"radius": 60.0, "speed": 40.0, "strength": 0.12, "color": "b07cff"}),
		_commit("outer_arch_collapse", 20.7, "court_try_outer_collapse"),
		_say("c1.tor.08", 21.2, "torin", "No— no, lad, no...", 2.2, "torin"),
		_commit("breach", 21.8, "court_coldopen_breach"),
		_journal(22.0, "story_ch1_fracture", "THE FRACTURE",
			"On the third count the bell screamed. The toll came inverted, a violet wave tore through the Court, and Brother Torin could not remember his mother's name."),
	], {"reconcile": fracture_reconcile, "deadline": 6.0})
	_seq(d, "outer_arch_collapse", [
		{"id": "rockfall", "at": 0.0, "op": "rockfall", "target": "gatehouse_outer_arch", "optional": true,
			"args": {"settled": "gatehouse_outer_rubble", "count": 14, "state_key": "gatehouse_arch_collapsed", "shake": 0.1}},
		_b("rubble", 0.0, "foley", "", {"sound": "rubble", "pos": Vector3(1.6, 1.0, 36.8)}),
		_a("guard_buried", 0.1, "vanish", "bellwatch_guard", {"fx": false, "sound": ""}),
		_commit("remains", 0.1, "court_guard_buried"),
	])
	_seq(d, "gatehouse_aftermath", [
		_b("relight", 0.0, "torch_group", "", {"group": "gatehouse", "scale": 1.0, "duration": 2.5, "flicker": 0.2}),
		_a("ser_to_wicket", 0.0, "walk_to", "seraphina", {"mark": "seraphina_wicket", "speed": "walk"}),
		_a("ser_unlock", 0.8, "gesture", "seraphina", {"name": "unlock", "duration": 1.0}),
		_say("c1.ser.11", 0.8, "seraphina", "Torin. Up. Take him to the camp.", 2.8, "seraphina"),
		_commit("wicket_open", 1.6, "court_unlock_wicket"),
		_say("c1.ser.12", 3.7, "seraphina", "Caelen— the court seals. The sluice. The portcullis gearbox.", 4.0, "seraphina"),
		_a("ser_long_look", 7.6, "look_at", "seraphina", {"at": "$player", "duration": 1.6, "rate": 2.5}),
		_say("c1.ser.13", 7.8, "seraphina", "Every lock between here and that tower has your mark on it.", 4.0, "seraphina"),
		_say("c1.ser.14", 11.9, "seraphina", "I'm taking the archive stair. Don't die before I can ask you why.", 4.8, "seraphina"),
		_commit("door_open", 12.3, "court_cell_door", -1.4),
		_a("ser_leave", 12.4, "walk_to", "seraphina", {"mark": "seraphina_exit", "speed": "walk"}),
		_a("ser_gone", 15.0, "vanish", "seraphina", {"fx": false, "sound": ""}),
		_commit("door_ajar", 15.2, "court_cell_door", -0.08),
		_a("torin_stand", 13.0, "gesture", "torin", {"name": "stand", "duration": 0.8}),
		_a("torin_to_camp", 13.6, "walk_to", "torin", {"route": [Vector3(0.8, 0, 30.0), Vector3(2.0, 0, 27.0)], "mark": "torin_camp", "speed": "limp"}),
		_commit("coldopen_done", 13.6, "court_coldopen_done"),
		_commit("objective", 13.7, "court_objective", "FOLLOW TORIN TO THE CLOISTER CAMP"),
		_commit("checkpoint", 14.0, "court_checkpoint", ["court_gatehouse", "Gatehouse"]),
		_a("torin_glance", 17.0, "look_at", "torin", {"at": "$player", "duration": 0.6}),
		_a("torin_sit", 20.4, "gesture", "torin", {"name": "sit", "hold": true}),
	], {"deadline": 12.0})
	# ---- Z2 Cloister -------------------------------------------------------
	_seq(d, "torin_camp", [
		_a("look", 0.0, "look_at", "torin", {"at": "$player", "duration": 1.0}),
		_a("stage_2", 0.1, "set_hollowing", "torin", {"stage": 2}),
		_say("c1.tor.09", 0.4, "torin", "Sit a moment? No. Guild men never do.", 3.0, "torin"),
		_a("point_north", 3.5, "gesture", "torin", {"name": "beckon", "duration": 1.2}),
		_say("c1.tor.10", 3.5, "torin", "Portcullis is the only road to the Keep. Gearbox wants its— the thing. The crank.", 5.0, "torin"),
		_say("c1.tor.11", 8.6, "torin", "Captain hid the crank in the ossuary. After the third bell. So nobody could... so nobody.", 5.4, "torin"),
		_say("c1.tor.12", 14.1, "torin", "And the seal-plates want weight. There's an arbalest on the cistern shrine. If the water hasn't— if they haven't...", 6.0, "torin"),
		_say("c1.tor.13", 20.2, "torin", "I'll be at the gearbox when you've the crank. I'll be there. I'll remember.", 4.6, "torin"),
		_commit("objective", 24.8, "court_objective", "FIND THE GEARBOX CRANK (OSSUARY) & THE ARBALEST (CISTERN)"),
		_journal(24.8, "story_ch1_camp", "THE FALLEN CAMP",
			"Torin is losing his nouns. The crank for the portcullis gearbox is hidden in the east ossuary; the arbalest lies on the cistern shrine."),
		_b("breach_follows", 27.3, "chain", "", {"sequence": SEQ + "cloister_breach"}),
	], {"when": after_coldopen})
	_seq(d, "cloister_breach", [
		{"id": "look_window", "at": 0.0, "op": "await_look", "target": "cloister_breach_window_19", "optional": true, "args": {"cone_deg": 60.0, "timeout": 2.0, "timeout_cue": "glass_burst"}},
		_b("glass_19", 0.05, "foley", "cloister_breach_window_19", {"sound": "glass_burst"}),
		_commit("window_19", 0.06, "court_breach_window", 19),
		_commit("drop_1", 0.1, "court_spawn", ["court_cloister_shr_1"]),
		_say("c1.tor.14", 0.3, "torin", "Window! West window!", 1.6, "torin"),
		_b("glass_23", 0.85, "foley", "cloister_breach_window_23", {"sound": "glass_burst", "pitch": 1.08}),
		_commit("window_23", 0.86, "court_breach_window", 23),
		_commit("drop_2", 0.9, "court_spawn", ["court_cloister_shr_2"]),
		_bark("rafts_coming", 1.2, "—the rafts are coming—", Vector3(-10.6, 3.6, 23.0)),
		_b("glass_27", 1.65, "foley", "cloister_breach_window_27", {"sound": "glass_burst", "pitch": 0.94}),
		_commit("window_27", 1.66, "court_breach_window", 27),
		_commit("drop_3", 1.7, "court_spawn", ["court_cloister_shr_3"]),
	], {"when": after_coldopen})
	_seq(d, "torin_rhyme", [
		_a("look", 0.0, "look_at", "torin", {"at": "$player", "duration": 0.8, "rate": 3.0}),
		_say("c1.tor.15", 0.2, "torin", "Moon that saw it... crown that... how does it go? My sister used to skip to it.", 5.0, "torin"),
	])
	# ---- Z4 West Cistern -----------------------------------------------------
	_seq(d, "cistern_arrival", [
		{"id": "look_window", "at": 0.0, "op": "await_look", "target": "seraphina_cistern", "optional": true, "args": {"cone_deg": 45.0, "timeout": 6.0}},
		_commit("lantern", 0.05, "court_cistern_lantern", "pulse"),
		_say("c1.ser.15", 0.1, "seraphina", "Caelen. Up here— the archive window.", 2.8, "seraphina_cistern", {"when": cistern_present}),
		_say("c1.ser.16", 3.0, "seraphina", "This is where they waited. The Crown promised rafts at the third bell.", 4.6, "seraphina_cistern", {"when": cistern_present}),
		_say("c1.ser.17", 7.7, "seraphina", "Nobody floated them. Nobody was ever going to.", 3.6, "seraphina_cistern", {"when": cistern_present}),
		_bark("water_whisper", 11.6, "—is it the third bell?—", Vector3(-21.0, 0.0, 3.0)),
		_journal(8.0, "story_ch1_quay", "THE QUAY OF BUNDLES",
			"Bundles, a birdcage, three pairs of shoes at the water's edge. The Crown promised rafts at the Third Bell. Nobody floated them."),
	], {"when": cistern_ready})
	_seq(d, "hesk_planks", [
		_say("c1.ser.21", 0.0, "seraphina", "Don't read the planks.", 1.8, "seraphina_cistern", {"when": cistern_present}),
	])
	_seq(d, "cistern_sluice", [
		_b("wheel", 0.0, "foley", "cistern_sluice_lever", {"sound": "lever"}),
		_b("surge", 0.2, "foley", "cistern_sluice_lever", {"sound": "flood_rush"}),
		_b("surge_dust", 0.25, "dust", "", {"pos": Vector3(-24.0, 0.3, 11.0), "dir": Vector3.DOWN, "kind": "splash"}),
		_b("surge_shake", 0.3, "shake", "", {"amount": 0.05, "pos": Vector3(-24.0, 0.3, 11.0)}),
		_commit("risen", 2.5, "court_risen"),
		_say("c1.ser.18", 3.2, "seraphina", "Forty nights late.", 1.8, "seraphina_cistern", {"when": cistern_present}),
		_say("c1.ser.19", 5.2, "seraphina", "They'd have liked to see them float.", 2.8, "seraphina_cistern", {"when": cistern_present}),
		_journal(3.0, "story_ch1_sluice", "FORTY NIGHTS LATE",
			"You floated the evacuation rafts the Crown promised. The people who waited for them rose out of the water as it climbed."),
	])
	_seq(d, "cistern_high_water", [
		_commit("lantern_lift", 0.0, "court_cistern_lantern", "lift"),
		_say("c1.ser.20", 0.3, "seraphina", "Ride them to the west parapet. The King left something up there he'd rather no one read.", 5.6, "seraphina_cistern", {"when": cistern_present}),
	])
	_seq(d, "seraphina_leaves_cistern", [
		_a("turn_away", 0.0, "walk_to", "seraphina_cistern", {"mark": "seraphina_cistern_exit", "speed": "walk", "state_key": "seraphina_cistern_mark"}),
		_commit("lantern_dark", 1.6, "court_cistern_lantern", "dark"),
		_a("gone", 2.0, "vanish", "seraphina_cistern", {"fx": false, "sound": ""}),
		_commit("left", 2.05, "court_cistern_left"),
	])
	# ---- Z5 East Ossuary -----------------------------------------------------
	_seq(d, "watchmen_whisper", [
		_bark("close_gate", 0.0, "—close the gate, lads—", null, "watchman_seat_2"),
	])
	_seq(d, "ossuary_blackout", [
		_commit("suppress_legacy", 0.0, "court_blackout_begin"),
		_b("snuff", 0.0, "torch_group", "", {"group": "east_crypt", "scale": 0.0, "duration": 0.08}),
		_b("wayfinding", 0.0, "torch_group", "", {"group": "crypt_route", "scale": 0.55, "duration": 0.3}),
		_bark("whisper", 0.3, "—none leave the court—", null, "watchman_seat_2"),
		_b("stinger_2", 0.7, "foley", "watchman_seat_2", {"sound": "hollow_rise"}),
		_b("stinger_5", 0.78, "foley", "watchman_seat_5", {"sound": "hollow_rise", "pitch": 0.9}),
		_b("stinger_avun", 0.85, "foley", "", {"sound": "stalker", "pos": Vector3(25.5, 0.6, -10.0), "vol_db": -9.0}),
		_commit("rise", 1.2, "court_watchmen_rise"),
		_commit("reinforcements", 2.0, "court_spawn", ["court_ambush_exec"]),
		_bark("back_on_quay", 2.05, "—back on the quay—", Vector3(26.5, 0.9, -5.0)),
		_b("relight", 2.15, "torch_group", "", {"group": "east_crypt", "scale": 0.6, "duration": 3.0, "flicker": 0.5}),
		_journal(2.2, "story_ch1_watchmen", "WATCHMEN'S REST",
			"Six of the Bell-Watch sat down together around a lantern while the bell rang. The crank that would have opened the portcullis was hidden among them. Two of them stood up."),
	])
	_seq(d, "torin_relocates", [
		_a("stand", 0.0, "gesture", "torin", {"name": "stand", "duration": 0.8}),
		_a("cross_zone", 0.8, "walk_to", "torin", {"route": [Vector3(0, 0, 17), Vector3(0, 0, 0)], "mark": "torin_gearbox", "speed": 1.3}),
		_commit("mark", 0.8, "court_torin_mark", "gearbox"),
	], {"deadline": 50.0, "when": torin_awake})
	# ---- Z3/Z6 The three-toll siege -------------------------------------------
	_seq(d, "north_portcullis", [
		_commit("ratchet", 0.0, "court_siege_ratchet"),
		_b("ram_hiss", 0.0, "foley", "ram_housing", {"sound": "steam_ram"}),
		_b("gears", 0.05, "foley", "north_gearbox", {"sound": "gear_grind"}),
		_a("torin_hurry", 0.0, "walk_to", "torin", {"mark": "torin_gearbox", "speed": 2.4}),
		_a("torin_crank", 0.4, "gesture", "torin", {"name": "crank", "hold": true}),
		_say("c1.tor.16", 0.5, "torin", "Got her. Come on, you old— turn—", 2.6, "torin"),
		_a("ser_arrives", 0.6, "walk_to", "seraphina_gallery", {"mark": "seraphina_gallery", "speed": "walk", "state_key": "seraphina_gallery_mark"}),
		_toll("toll_moon", 3.0, "inverted", {"motes": ["torin"], "motes_dir": "bell_far"}),
		_b("wave_moon", 3.02, "resonance", "court_north_wave_origin", {"radius": 40.0, "speed": 30.0, "strength": 0.1, "color": "b07cff"}),
		_a("torin_stage_3", 3.05, "set_hollowing", "torin", {"stage": 3}),
		_commit("stage_1", 3.1, "court_siege_stage", 1),
		_say("c1.ser.22", 3.3, "seraphina", "They'll hear the gears. All of them. Keep them off Torin.", 3.8, "seraphina_gallery"),
		_say("c1.tor.17", 7.2, "torin", "Moon that saw it...", 2.2, "torin"),
		_bark("third_bell", 7.6, "—third bell—", Vector3(0, 1.6, 15.0)),
		_journal(3.2, "story_ch1_siege", "THE PORTCULLIS",
			"The portcullis was lowered to keep the Lower Ward in. Its bars are gouged on the inside. Torin is cranking it open, and the bell is taking him with every toll."),
	])
	_seq(d, "siege_crown", [
		_toll("toll_crown", 0.0, "inverted", {"motes": ["torin"], "motes_dir": "bell_far"}),
		_b("wave_crown", 0.02, "resonance", "court_north_wave_origin", {"radius": 40.0, "speed": 30.0, "strength": 0.11, "color": "b07cff"}),
		_commit("stage_2", 0.1, "court_siege_stage", 2),
		_b("ice_break", 0.15, "foley", "", {"sound": "frost", "pos": Vector3(3.8, 0.4, -5.0), "pitch": 0.7}),
		_b("ice_dust", 0.16, "dust", "", {"pos": Vector3(3.8, 0.2, -5.0), "dir": Vector3.UP, "kind": "frost"}),
		_say("c1.tor.18", 0.8, "torin", "Crown that willed it...", 2.2, "torin"),
		_say("c1.ser.23", 3.1, "seraphina", "The east plate— the ice is gone! Freeze it!", 3.0, "seraphina_gallery"),
	])
	_seq(d, "siege_skull", [
		_toll("toll_skull", 0.0, "inverted", {"motes": ["torin"], "motes_dir": "bell_far"}),
		_b("wave_skull", 0.02, "resonance", "court_north_wave_origin", {"radius": 40.0, "speed": 30.0, "strength": 0.12, "color": "b07cff"}),
		_commit("stage_3", 0.1, "court_siege_stage", 3),
		_say("c1.tor.19", 0.8, "torin", "Skull that... that...", 2.2, "torin"),
		_say("c1.ser.24", 3.1, "seraphina", "Executioner, east door! Pull its shield, Caelen— grasp it!", 3.6, "seraphina_gallery"),
	])
	_seq(d, "torin_hollows", [
		_a("release", 0.0, "gesture", "torin", {"name": "release_crank", "duration": 0.8}),
		_commit("crank_spins", 0.0, "court_crank_release"),
		_say("c1.tor.20", 0.2, "torin", "There. There, Master. Road's open.", 3.0, "torin"),
		_a("stand", 0.9, "gesture", "torin", {"name": "stand", "duration": 1.0}),
		_a("puzzled", 3.6, "look_at", "torin", {"at": "$player", "duration": 1.5, "rate": 2.0}),
		_say("c1.tor.21", 3.6, "torin", "Sorry— who did you say you were?", 3.0, "torin", {"priority": 2}),
		_a("sit", 7.0, "gesture", "torin", {"name": "sit", "hold": true}),
		_b("final_motes", 7.0, "hollowing_motes", "", {"actor": "torin", "duration": 3.0, "target_dir": "bell_far"}),
		_a("stage_4", 7.05, "set_hollowing", "torin", {"stage": 4}),
		_commit("hollowed", 7.1, "court_torin_hollowed"),
		_say("c1.ser.25", 8.0, "seraphina", "...Go, Caelen. I'll see to him.", 2.6, "seraphina_gallery"),
		_say("c1.ser.26", 11.0, "seraphina", "I'll write him down.", 2.0, "seraphina_gallery"),
		_say("c1.ser.27", 13.6, "seraphina", "Malcor's at the bell. He'll have heard you coming for a mile.", 4.0, "seraphina_gallery"),
		_a("ser_leaves", 15.0, "walk_to", "seraphina_gallery", {"mark": "seraphina_gallery_door", "speed": "walk", "state_key": "seraphina_gallery_mark"}),
		_commit("objective", 15.0, "court_objective", "CROSS THE BELL CAUSEWAY"),
		_a("ser_gone", 19.2, "vanish", "seraphina_gallery", {"fx": false, "sound": ""}),
		_journal(4.0, "story_ch1_torin", "BROTHER TORIN, BELL-WATCH",
			"\"There. There, Master. Road's open.\" Then, kindly, to a stranger: \"Sorry— who did you say you were?\" Seraphina said she would write him down."),
	], {"reconcile": hollow_reconcile, "deadline": 6.0})
	# ---- Z6 Bell Causeway & the Keep doors ------------------------------------
	_seq(d, "viaduct_toll", [
		_b("wind", 0.5, "foley", "", {"sound": "wind_gust", "2d": true, "vol_db": -8.0}),
		_toll("causeway_toll", 2.0, "inverted", {}),
		_b("dust_front", 2.02, "resonance", "causeway_front_origin", {"radius": 30.0, "speed": 14.0, "strength": 0.08, "color": "c8a7fe"}),
		{"id": "look_bell", "at": 2.1, "op": "await_look", "target": "bell_far", "optional": true, "args": {"cone_deg": 30.0, "timeout": 4.0}},
		_b("ribbon_city_a", 2.15, "name_stream", "", {"from": Vector3(60, 10, -40), "to": "bell_far", "duration": 6.0, "color": "c8a7fe"}),
		_b("ribbon_city_b", 2.4, "name_stream", "", {"from": Vector3(78, 15, -62), "to": "bell_far", "duration": 6.0, "color": "b9a8ff"}),
		_b("ribbon_city_c", 2.7, "name_stream", "", {"from": Vector3(52, 7, -24), "to": "bell_far", "duration": 6.0, "color": "d8c8ff"}),
		_say("c1.cho.01", 4.5, "hollow_choir", "…key-maker…", 2.2, "", {"origin": Vector3(0, -8, -30), "italic": true}),
		_say("c1.cho.02", 7.0, "hollow_choir", "…moon… crown… skull…", 3.0, "", {"origin": Vector3(0, -8, -30), "italic": true}),
		_journal(7.5, "story_ch1_causeway", "THE CITY BEING TAKEN",
			"From the Bell Causeway: violet ribbons of name-ash rising from the lights of the upper city and streaming into the cracked bell."),
	])
	_seq(d, "keep_doors", [
		_b("groan", 0.0, "foley", "keep_doors", {"sound": "door_groan"}),
		_commit("swing", 0.0, "court_keep_doors"),
		_b("wind_at_back", 0.3, "wind_force", "", {"dir": Vector3(0, 0, -1), "accel": 1.2, "duration": 3.0}),
	], {"when": gate_is_open})
	d.register_sequence({"id": SEQ + "ambient_toll", "once": false, "beats": [
		_toll("ambient", 0.0, "inverted", {"motes": ["torin"], "motes_dir": "bell_far", "shake_amount": 0.03}),
	]})


# --- commit implementations ---------------------------------------------------

static func _set_objective(game, text: String) -> void:
	var labels: Variant = game.get("labels")
	if labels is Dictionary and (labels as Dictionary).has("goal") and is_instance_valid(labels.goal):
		(labels.goal as Label).text = "OBJECTIVE: " + text


static func _checkpoint(game, p: Variant) -> void:
	if p is Array and (p as Array).size() >= 2 and game.has_method("_on_checkpoint_reached"):
		game._on_checkpoint_reached(str(p[0]), str(p[1]))


static func _spawn_list(game, st: Dictionary, ids: Variant) -> void:
	if ids is Array:
		for id: Variant in ids:
			_spawn(game, st, str(id))


static func _on_fracture_begin(game, st: Dictionary, ctx: Dictionary) -> void:
	st.fractured = true
	st.torin_stage = maxi(int(st.torin_stage), 1)
	ctx.next_ambient_toll = float(ctx.t) + 60.0
	_set_objective(game, "SURVIVE THE BREACH")


static func _on_guard_run(ctx: Dictionary) -> void:
	var g: Variant = ctx.get("guard")
	if g is Node3D and is_instance_valid(g):
		(g as Node3D).visible = true


static func _on_bar_raised(game, st: Dictionary, ctx: Dictionary) -> void:
	st.gatehouse_open = true
	var bar: Variant = ctx.get("bar")
	if bar is StaticBody3D and is_instance_valid(bar):
		(bar as StaticBody3D).collision_layer = 0
	game._sound_at("lever", Vector3(-6.4, 1.5, 30.6), 0.8)


static func _on_guard_buried(game, st: Dictionary, ctx: Dictionary) -> void:
	st.outer_arch_collapsed = true
	_world(st).gatehouse_arch_collapsed = true
	_guard_remains(game, ctx.root, ctx, true)


static func _on_unlock_wicket(game, ctx: Dictionary) -> void:
	var hinge: Node3D = ctx.cell_wicket
	_swing(hinge, -1.45, 1.2)
	game._sound_at("lever", hinge.global_position + Vector3(0, 1.3, 0.8), 1.3)
	for c: Node in hinge.get_children():
		c.set_meta("interact_hint", "CELL GRATE — UNLOCKED")


static func _swing(node: Variant, angle: float, duration: float) -> void:
	if not node is Node3D or not is_instance_valid(node):
		return
	var n := node as Node3D
	if not n.is_inside_tree():
		n.rotation.y = angle
		return
	n.create_tween().tween_property(n, "rotation:y", angle, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


static func _on_coldopen_done(game, st: Dictionary, ctx: Dictionary, d: SD) -> void:
	st.coldopen_done = true
	st.torin_mark = "camp"
	_world(st).seraphina_mark = "archive"
	var cist := d.get_actor("seraphina_cistern")
	if cist != null:
		cist.visible = true
		_cistern_lantern(ctx, "on")
	_set_objective(game, "FOLLOW TORIN TO THE CLOISTER CAMP")


static func _reconcile_fracture(st: Dictionary, _ctx: Dictionary) -> void:
	st.fractured = true
	st.gatehouse_open = true
	st.coldopen_done = true
	st.torin_stage = maxi(int(st.torin_stage), 1)


static func _on_breach_window(game, ctx: Dictionary, z: int) -> void:
	var window: Variant = ctx.get("window_%d" % z)
	if not window is Node3D or not is_instance_valid(window):
		return
	var w := window as Node3D
	w.visible = false
	var pos := w.global_position
	Visuals.spawn_dust_burst(ctx.root, pos, Vector3.RIGHT, "dust", 1900 + z)
	Visuals.spawn_impact_light(ctx.root, pos, Color(0.78, 0.85, 0.94), 2.4, 8.0, 0.35)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77 + z
	var glass: Material = game._material(Color(0.66, 0.74, 0.92, 0.7), true)
	for i in 5:
		game._debris_piece(pos + Vector3(0.3, rng.randf_range(-0.6, 0.6), rng.randf_range(-0.5, 0.5)),
			Vector3(rng.randf_range(0.08, 0.2), rng.randf_range(0.1, 0.3), 0.02), glass,
			Vector3(rng.randf_range(1.0, 3.0), rng.randf_range(-0.5, 1.5), rng.randf_range(-1.0, 1.0)))


static func _cistern_lantern(ctx: Dictionary, mode: String) -> void:
	var l: Variant = ctx.get("cistern_lantern")
	if not l is OmniLight3D or not is_instance_valid(l):
		return
	var light := l as OmniLight3D
	var rest := float(light.get_meta("rest_energy", 2.4))
	if not light.is_inside_tree():
		light.light_energy = 0.0 if mode == "dark" else rest
		return
	var tw := light.create_tween()
	match mode:
		"pulse":
			tw.tween_property(light, "light_energy", rest * 2.4, 0.15)
			tw.tween_property(light, "light_energy", rest, 0.9)
		"lift":
			tw.tween_property(light, "position:y", light.position.y + 0.5, 0.8)
			tw.parallel().tween_property(light, "light_energy", rest * 1.4, 0.8)
		"dark":
			tw.tween_property(light, "light_energy", 0.0, 1.2)
		_:
			tw.tween_property(light, "light_energy", rest, 0.6)


static func _on_risen(game, st: Dictionary) -> void:
	for id: String in RISEN_IDS:
		_spawn(game, st, id, true)


static func _on_cistern_left(st: Dictionary, ctx: Dictionary) -> void:
	_world(st).seraphina_cistern_left = true
	_cistern_lantern(ctx, "dark")


static func _on_blackout_begin(game, st: Dictionary) -> void:
	# The director owns the ambush timing; retire main.gd's legacy 2 s spawn.
	game.set("ambush_pending", false)
	game.set("ambush_dark_timer", 0.0)
	st.ambush_done = true


static func _on_watchmen_rise(game, st: Dictionary, ctx: Dictionary) -> void:
	for seat: int in [2, 5]:
		var holder: Variant = ctx.get("watchman_seat_%d" % seat)
		if holder is Node3D and is_instance_valid(holder) and (holder as Node3D).has_meta("corpse"):
			var corpse: Variant = (holder as Node3D).get_meta("corpse")
			if corpse is Node3D and is_instance_valid(corpse):
				(corpse as Node3D).visible = false
	_spawn(game, st, "court_ambush_shr1")
	_spawn(game, st, "court_ambush_shr2")


static func _on_siege_ratchet(game, st: Dictionary, ctx: Dictionary, d: SD) -> void:
	st.gearbox_unpicked = true
	ctx.stage_t = float(ctx.t)
	for jet: Variant in ctx.ram_jets:
		if jet is GPUParticles3D and is_instance_valid(jet):
			(jet as GPUParticles3D).emitting = true
	game._pickup(Vector3(-4.6, 0.5, -15.9), "flask", "court_siege_flask")
	L.add_explosive_cask(game, Vector3(6.5, 0, -12), "court_cask_siege")
	var gal := d.get_actor("seraphina_gallery")
	if gal != null:
		gal.visible = true
	_set_objective(game, "HOLD THE COURT — KEEP THEM OFF TORIN AT THE GEARBOX")


static func _siege_stage(game, st: Dictionary, ctx: Dictionary, stage: int) -> void:
	st.siege_stage = clampi(maxi(int(st.siege_stage), stage), 0, 3)
	ctx.stage_t = float(ctx.t)
	ctx.slip_warned = false
	for id: Variant in WAVE_IDS.get(stage, []):
		_spawn(game, st, str(id))
	if stage == 2:
		# E18: the Crown toll shatters the frost holding the east counterweight.
		for ch: Dictionary in game.water_channels:
			ch.frozen_timer = 0.0
			var node: Variant = ch.get("node")
			if node is Node3D and is_instance_valid(node) and (node as Node).get_child_count() > 0:
				var mi := (node as Node).get_child(0) as MeshInstance3D
				if mi != null:
					mi.material_override = game.mats.water
		_msg(game, "EAST SEAL SLIPPING — FREEZE THE CURRENT [RMB]", 3.2)


static func _on_crank_release(game, ctx: Dictionary) -> void:
	var gb: Variant = ctx.get("gearbox")
	if gb is Node3D and is_instance_valid(gb) and (gb as Node3D).has_meta("lever_arm"):
		var arm: Node3D = (gb as Node3D).get_meta("lever_arm")
		arm.create_tween().tween_property(arm, "rotation:x", arm.rotation.x + TAU * 2.0, 1.4).set_ease(Tween.EASE_OUT)
	game._sound_at("lever", Vector3(-5.8, 1.2, -16.9), 0.7)


static func _on_torin_hollowed_state(st: Dictionary) -> void:
	st.torin_hollowed = true
	st.torin_stage = 4
	_world(st).torin_mark = "torin_gearbox"


static func _on_torin_hollowed(game, st: Dictionary, ctx: Dictionary) -> void:
	_on_torin_hollowed_state(st)
	var entry: Dictionary = ctx.torin_entry
	entry["lines"] = [TORIN_HOLLOW_LINES[0]]
	entry["spoken"] = false
	ctx.torin_line = 0
	var holder: Variant = entry.get("node")
	if holder is Node3D and is_instance_valid(holder):
		for c: Node in (holder as Node3D).get_children():
			if c is OmniLight3D:
				(c as OmniLight3D).create_tween().tween_property(c, "light_energy", 0.3, 2.0)
	_set_objective(game, "CROSS THE BELL CAUSEWAY")


static func _on_keep_doors(st: Dictionary, ctx: Dictionary) -> void:
	st.keep_doors_open = true
	_world(st).keep_doors_open = true
	_swing(ctx.get("keep_door_l"), deg_to_rad(KEEP_DOOR_OPEN), 2.0)
	_swing(ctx.get("keep_door_r"), -deg_to_rad(KEEP_DOOR_OPEN), 2.0)
	var spill: Variant = ctx.get("keep_spill")
	if spill is OmniLight3D and is_instance_valid(spill) and (spill as Node).is_inside_tree():
		(spill as OmniLight3D).create_tween().tween_property(spill, "light_energy", 3.0, 2.0)


static func _open_portcullis(game, st: Dictionary, ctx: Dictionary) -> void:
	st.gate_open = true
	st.siege_stage = 3
	st.portcullis_height = 5.2
	game.set("gate_open", true)
	var gate: Variant = ctx.get("gate")
	if gate is StaticBody3D and is_instance_valid(gate):
		(gate as StaticBody3D).position.y = 5.2
		(gate as StaticBody3D).collision_layer = 0
	game._sound_at("lever", Vector3(0, 4.0, -19.0), 0.6)
	for jet: Variant in ctx.ram_jets:
		if jet is GPUParticles3D and is_instance_valid(jet):
			(jet as GPUParticles3D).emitting = false


# =============================================================================
# Live driver (main.gd calls step(); a Timer covers a missing bridge)
# =============================================================================

## Per-physics-frame chapter update; call from main.gd `_update_puzzles()` in ch1.
static func step(game, delta: float) -> void:
	var root: Variant = game.get("level_root")
	if not root is Node3D or not is_instance_valid(root) or not (root as Node3D).has_meta("court_ctx"):
		return
	var ctx: Dictionary = (root as Node3D).get_meta("court_ctx")
	var st: Dictionary = (root as Node3D).get_meta("court_state")
	ctx.external_frame = Engine.get_physics_frames()
	_tick(game, st, ctx, delta)


## Live sync of chapter visuals with state (hints, padlock, gate, actors).
static func sync_visual_state(game, st: Dictionary) -> void:
	var root: Variant = game.get("level_root")
	if root is Node3D and is_instance_valid(root) and (root as Node3D).has_meta("court_ctx"):
		var ctx: Dictionary = (root as Node3D).get_meta("court_ctx")
		_sync_derived(game, st)
		_update_lock_hints(game, st, ctx)


static func _start_driver(game, root: Node3D, st: Dictionary, ctx: Dictionary) -> void:
	var timer := Timer.new()
	timer.name = "court_story_driver"
	timer.wait_time = 0.05
	timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
	timer.autostart = true
	timer.timeout.connect(func() -> void: _driver_timeout(game, st, ctx))
	root.add_child(timer)


static func _driver_timeout(game, st: Dictionary, ctx: Dictionary) -> void:
	if Engine.get_physics_frames() - int(ctx.external_frame) < 6:
		return
	_tick(game, st, ctx, 0.05)


static func _tick(game, st: Dictionary, ctx: Dictionary, delta: float) -> void:
	if game == null or not is_instance_valid(game):
		return
	var root: Variant = ctx.get("root")
	if not root is Node3D or not is_instance_valid(root) or not (root as Node3D).is_inside_tree():
		return
	ctx.t = float(ctx.t) + delta
	_sync_derived(game, st)
	_update_lock_hints(game, st, ctx)
	_follow_hesk(ctx)
	_tick_winch(game, st, ctx, delta)
	_tick_npcs(game, st, ctx)
	var d := _director(game)
	if d == null:
		return
	_tick_story(game, st, ctx, d, delta)
	_tick_siege(game, st, ctx, d, delta)


static func _started(d: SD, seq: String) -> bool:
	return d.is_sequence_running(SEQ + seq) or d.is_sequence_completed(SEQ + seq)


static func _tick_story(game, st: Dictionary, ctx: Dictionary, d: SD, delta: float) -> void:
	var p := _player(game)
	if p == null:
		return
	var pp := p.global_position
	var world := _world(st)
	var torin := d.get_actor("torin")
	var torin_mark := str(world.get("torin_mark", ""))
	# --- cold open pacing & fallbacks
	if not bool(ctx.arrival_started):
		ctx.arrival_started = true
		if not bool(st.fractured):
			if not d.is_sequence_completed(SEQ + "coldopen_arrival"):
				d.start_sequence(SEQ + "coldopen_arrival")
			else:
				d.start_sequence(SEQ + "lull_loop")
	if not bool(st.fractured):
		if float(ctx.t) > 20.0 and not _started(d, "torin_hail"):
			d.start_sequence(SEQ + "torin_hail")
		if d.is_sequence_completed(SEQ + "torin_hail") and float(ctx.hail_done_t) < 0.0:
			ctx.hail_done_t = float(ctx.t)
		if float(ctx.hail_done_t) >= 0.0 and float(ctx.t) - float(ctx.hail_done_t) > 35.0 and not _started(d, "gatehouse_meeting"):
			d.start_sequence(SEQ + "gatehouse_meeting")
	if float(ctx.collapse_wait) >= 0.0:
		ctx.collapse_wait = float(ctx.collapse_wait) + delta
		if pp.z < 35.6:
			ctx.collapse_wait = -1.0
			d.start_sequence(SEQ + "outer_arch_collapse")
		elif float(ctx.collapse_wait) > 20.0:
			# Precondition never met: skip the collapse, the guard is gone offscreen.
			ctx.collapse_wait = -1.0
			var guard := d.get_actor("bellwatch_guard")
			if guard != null:
				_remove_npc(game, guard)
			st.outer_arch_collapsed = false
	if not bool(st.coldopen_done) and float(ctx.breach_t) >= 0.0 and not _started(d, "gatehouse_aftermath"):
		if _wave_clear(game, COLDOPEN_IDS) or float(ctx.t) - float(ctx.breach_t) > 40.0:
			d.start_sequence(SEQ + "gatehouse_aftermath")
	# --- cloister
	if bool(st.coldopen_done) and torin != null:
		var dist := pp.distance_to(torin.global_position)
		if torin_mark == "torin_camp" and not _started(d, "torin_camp") and dist < 4.0 \
				and _has_los(game, p, torin.global_position + Vector3.UP * 1.2):
			d.start_sequence(SEQ + "torin_camp")
		if d.is_sequence_completed(SEQ + "cloister_breach") and not _started(d, "torin_rhyme") \
				and not d.is_sequence_running(SEQ + "torin_camp") and torin_mark == "torin_camp" and dist < 6.0:
			d.start_sequence(SEQ + "torin_rhyme")
	# --- cistern
	var cistern_here := not bool(world.get("seraphina_cistern_left", false)) and d.get_actor("seraphina_cistern") != null
	var raft: Variant = ctx.get("hesk_raft")
	if cistern_here and d.is_sequence_completed(SEQ + "cistern_arrival") and not _started(d, "hesk_planks") \
			and raft is Node3D and is_instance_valid(raft) and pp.distance_to((raft as Node3D).global_position) < 3.0:
		d.start_sequence(SEQ + "hesk_planks")
	if bool(st.cistern_raised) and not _started(d, "cistern_sluice"):
		d.start_sequence(SEQ + "cistern_sluice")
	var water: Variant = ctx.get("water")
	if _started(d, "cistern_sluice") and not _started(d, "cistern_high_water") and water is Node3D \
			and is_instance_valid(water) and (water as Node3D).position.y >= 1.4:
		d.start_sequence(SEQ + "cistern_high_water")
	if cistern_here and d.is_sequence_completed(SEQ + "cistern_high_water") and not _started(d, "seraphina_leaves_cistern") \
			and pp.y > 2.0 and pp.x < -21.5 and pp.z < -4.5:
		d.start_sequence(SEQ + "seraphina_leaves_cistern")
	# --- ossuary
	if bool(st.has_lever) and not _started(d, "ossuary_blackout"):
		game.set("ambush_pending", false)
		d.start_sequence(SEQ + "ossuary_blackout")
		if not bool(st.torin_hollowed) and not _started(d, "torin_relocates"):
			d.start_sequence(SEQ + "torin_relocates")
	var seat2: Variant = ctx.get("watchman_seat_2")
	if not bool(st.has_lever) and not _started(d, "watchmen_whisper") and seat2 is Node3D \
			and pp.distance_to((seat2 as Node3D).global_position) < 5.0:
		d.start_sequence(SEQ + "watchmen_whisper")
	# --- court
	if bool(st.has_lever) and not bool(st.basin_checkpoint_done) and pp.x > -10.0 and pp.x < 10.0 and pp.z > -19.0 and pp.z < 15.0 and pp.y < 1.5:
		st.basin_checkpoint_done = true
		_checkpoint(game, ["court_basin", "Court of Seals"])
	if bool(st.gate_open) and not _started(d, "torin_hollows") and not bool(st.torin_hollowed):
		d.start_sequence(SEQ + "torin_hollows")
	# --- ambient inverted tolls after the fracture, outside scripted ones
	if bool(st.fractured) and float(ctx.t) >= float(ctx.next_ambient_toll):
		var rng: RandomNumberGenerator = ctx.rng
		ctx.next_ambient_toll = float(ctx.t) + rng.randf_range(45.0, 70.0)
		var busy := false
		for s: String in ["gatehouse_fracture", "north_portcullis", "siege_crown", "siege_skull", "torin_hollows", "viaduct_toll"]:
			if d.is_sequence_running(SEQ + s):
				busy = true
		if not busy and d.get_last_bell_toll_age() > 12.0:
			d.start_sequence(SEQ + "ambient_toll")


static func _tick_siege(game, st: Dictionary, ctx: Dictionary, d: SD, delta: float) -> void:
	if bool(st.gate_open):
		return
	var stage := int(st.siege_stage)
	var both := _plates_pressed(game) >= 2
	if stage <= 0:
		if bool(st.lever_inserted) and both and bool(st.cistern_raised) and not _started(d, "north_portcullis"):
			d.start_sequence(SEQ + "north_portcullis")
		return
	var target: float = SIEGE_HEIGHTS[clampi(stage, 0, 3)]
	var h := float(st.portcullis_height)
	if both:
		if h < target:
			h = move_toward(h, target, SIEGE_RISE_SPEED * delta)
		ctx.slip_warned = false
	elif h < target - 0.01 and not bool(ctx.slip_warned):
		# The pawl clacks: the gate holds and never drops.
		ctx.slip_warned = true
		game._sound_at("hit", Vector3(0, 2.0, -19.0), 0.55)
		_msg(game, "SEAL-PLATE UNWEIGHTED — THE PAWL HOLDS. WEIGHT BOTH PLATES", 2.6)
	st.portcullis_height = h
	_apply_gate(ctx, h)
	var since := float(ctx.t) - float(ctx.stage_t)
	if stage < 3:
		var next := "siege_crown" if stage == 1 else "siege_skull"
		if since >= 12.0 and (since >= 30.0 or _wave_clear(game, WAVE_IDS[stage])) and not _started(d, next):
			d.start_sequence(SEQ + next)
	elif h >= 5.15 and (since >= 45.0 or _wave_clear(game, WAVE_IDS[3])):
		_open_portcullis(game, st, ctx)
		d.start_sequence(SEQ + "torin_hollows")


static func _apply_gate(ctx: Dictionary, h: float) -> void:
	var gate: Variant = ctx.get("gate")
	if not gate is StaticBody3D or not is_instance_valid(gate):
		return
	var g := gate as StaticBody3D
	var external := Engine.get_physics_frames() - int(ctx.external_frame) < 6
	if external or not g.is_inside_tree() or absf(g.position.y - h) > 0.4:
		g.position.y = h
	else:
		g.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).tween_property(g, "position:y", h, 0.05)
	g.collision_layer = 0 if h >= 4.9 else L.LAYER_WORLD


static func _update_lock_hints(game, st: Dictionary, ctx: Dictionary) -> void:
	var sluice: Variant = ctx.get("sluice")
	if sluice is Node3D and is_instance_valid(sluice):
		var picked := bool(st.sluice_lock_unpicked)
		var hint := "CISTERN SLUICE — OPEN"
		if not bool(st.cistern_raised):
			hint = "CISTERN SLUICE — PULL [E] TO FLOAT THE RAFTS" if picked else "SLUICE CHAIN — PADLOCK WITH YOUR MASTER'S MARK — UNPICK [HOLD E]"
		_set_hint(sluice, hint, not picked and not bool(st.cistern_raised), "sluice_lock")
		var padlock: Variant = ctx.get("padlock")
		if padlock is Node3D and is_instance_valid(padlock):
			(padlock as Node3D).visible = not picked and not bool(st.cistern_raised)
	var gb: Variant = ctx.get("gearbox")
	if gb is Node3D and is_instance_valid(gb):
		var hint := "NORTH GEARBOX — CRANK SEATED"
		var unpick := false
		if not bool(st.lever_inserted):
			if not bool(st.has_lever):
				hint = "NORTH GEARBOX — THE CRANK IS MISSING (EAST OSSUARY)"
			elif not bool(st.gearbox_unpicked):
				hint = "GEARBOX CRANK SEAT — YOUR MASTER'S MARK — UNPICK [HOLD E]"
				unpick = true
			else:
				hint = "NORTH GEARBOX — SEAT THE CRANK [E]"
		elif not bool(st.cistern_raised):
			hint = "HYDRAULIC RAM DRY — RAISE THE CISTERN SLUICE"
		elif not bool(st.gate_open) and _plates_pressed(game) < 2:
			hint = "SEAL-PLATES UNWEIGHTED — WEIGHT BOTH PLATES"
		_set_hint(gb, hint, unpick, "gearbox")
	var sc: Variant = ctx.get("shortcut")
	if sc is Node3D and is_instance_valid(sc) and not bool(st.shortcut_open):
		var picked_gate := bool(st.ossuary_gate_unpicked)
		_set_hint(sc, "OSSUARY GATE — UNBAR FROM THE EAST [E]" if picked_gate else "OSSUARY GATE — YOUR MASTER'S MARK — UNPICK [HOLD E]", not picked_gate, "ossuary_gate")


static func _set_hint(node: Node, hint: String, unpick: bool, lock_id: String) -> void:
	if str(node.get_meta("interact_hint", "")) == hint and bool(node.get_meta("unpick", false)) == unpick:
		return
	for n: Node in [node] + node.get_children():
		if n == node or n is CollisionObject3D:
			n.set_meta("interact_hint", hint)
			n.set_meta("unpick", unpick)
			n.set_meta("lock_id", lock_id)


static func _follow_hesk(ctx: Dictionary) -> void:
	var raft: Variant = ctx.get("hesk_raft")
	var node: Variant = ctx.get("hesk_inscription")
	if raft is Node3D and is_instance_valid(raft) and node is Node3D and is_instance_valid(node) and (raft as Node3D).is_inside_tree():
		(node as Node3D).position = (raft as Node3D).global_position + Vector3(0, -0.6, 0)


static func _tick_winch(game, st: Dictionary, ctx: Dictionary, delta: float) -> void:
	if bool(st.drain_grate_open):
		return
	var winch: Variant = ctx.get("winch")
	var p := _player(game)
	if p == null or not winch is Node3D or not is_instance_valid(winch):
		return
	var wp := (winch as Node3D).global_position
	var flat := Vector2(p.global_position.x - wp.x, p.global_position.z - wp.z).length()
	if flat < 2.4 and p.global_position.z < 17.4 and Input.is_key_pressed(KEY_E):
		ctx.winch_hold = float(ctx.winch_hold) + delta
		if float(ctx.winch_hold) >= 0.6:
			st.drain_grate_open = true
			var grate: StaticBody3D = ctx.drain_grate
			grate.collision_layer = 0
			grate.create_tween().tween_property(grate, "position:y", grate.position.y + 2.8, 1.6).set_trans(Tween.TRANS_SINE)
			game._sound_at("gear_grind", grate.global_position, 0.8)
			game._sound_at("lever", wp + Vector3.UP, 1.0)
			_msg(game, "DRAIN GRATE RAISED — THE CLOISTER", 2.2)
	else:
		ctx.winch_hold = 0.0


static func _tick_npcs(game, st: Dictionary, ctx: Dictionary) -> void:
	var entry: Variant = ctx.get("torin_entry")
	if not entry is Dictionary:
		return
	var e := entry as Dictionary
	var holder: Variant = e.get("node")
	if not holder is Node3D or not is_instance_valid(holder):
		return
	# Hollowed Torin cycles his last small talk; he never progresses anything.
	if bool(st.torin_hollowed):
		if bool(e.get("spoken", false)):
			ctx.torin_line = int(ctx.torin_line) + 1
			e["spoken"] = false
		e["lines"] = [TORIN_HOLLOW_LINES[int(ctx.torin_line) % TORIN_HOLLOW_LINES.size()]]
	else:
		e["lines"] = [_torin_line(st)]
	# While Torin waits at the gearbox, [E] there belongs to the crank seat.
	var npcs: Array = game.npc_nodes
	var at_gearbox := str(_world(st).get("torin_mark", "")) == "torin_gearbox" and (holder as Node3D).global_position.distance_to(Vector3(-5.0, 0, -15.8)) < 1.5
	var should_listen := not (at_gearbox and not bool(st.lever_inserted))
	var listed := npcs.has(e)
	if should_listen and not listed:
		npcs.append(e)
	elif not should_listen and listed:
		npcs.erase(e)


# =============================================================================
# Small helpers
# =============================================================================

static func _player(game) -> Node3D:
	var p: Variant = game.get("player")
	if p is Node3D and is_instance_valid(p) and (p as Node3D).is_inside_tree():
		return p
	return null


static func _has_los(game, p: Node3D, to: Vector3) -> bool:
	var root: Node3D = game.level_root
	var world3d := root.get_world_3d()
	if world3d == null:
		return true
	var from := p.global_position + Vector3.UP * 1.6
	var query := PhysicsRayQueryParameters3D.create(from, to, L.LAYER_WORLD)
	if p is CollisionObject3D:
		query.exclude = [(p as CollisionObject3D).get_rid()]
	var hit := world3d.direct_space_state.intersect_ray(query)
	return hit.is_empty() or (hit.position as Vector3).distance_to(to) < 0.8


static func _plates_pressed(game) -> int:
	var n := 0
	for plate: Dictionary in game.pressure_plates:
		if bool(plate.get("pressed", false)):
			n += 1
	return n


static func _alive(game, id: String) -> bool:
	for e: Variant in game.enemies:
		if e is Node and is_instance_valid(e) and str((e as Node).get_meta("id", "")) == id:
			return true
	return false


static func _wave_clear(game, ids: Array) -> bool:
	for id: Variant in ids:
		if _alive(game, str(id)):
			return false
	return true


static func _spawn(game, st: Dictionary, id: String, emerge: bool = false) -> CharacterBody3D:
	if not SPAWNS.has(id) or (st.dead as Array).has(id) or _alive(game, id):
		return null
	var spec: Array = SPAWNS[id]
	var pos: Vector3 = spec[0]
	var before: int = game.enemies.size()
	game._enemy(pos, bool(spec[1]), id, false, str(spec[2]))
	if game.enemies.size() <= before:
		return null
	var e: CharacterBody3D = game.enemies.back()
	if emerge and is_instance_valid(e):
		e.set_meta("emerge_target_y", pos.y)
		e.set_meta("emerge_start_y", pos.y - 1.6)
		e.set_meta("emerge_timer", 1.2)
		e.set_meta("emerge_fx", "splash")
		e.position.y = pos.y - 1.6
		game._sound_at("splash", pos + Vector3.UP, 0.8)
	return e


static func _msg(game, text: String, secs: float) -> void:
	if game.has_method("_message"):
		game._message(text, secs)


static func _urn(game, pos: Vector3, id: String, loot: String) -> void:
	var before: int = game.breakables.size()
	game._pot(pos, id, loot)
	if game.breakables.size() > before:
		(game.breakables.back() as Node).set_meta("interact_hint", "FUNERARY URN — GRASP [G] AND HURL TO MAKE NOISE")


# In-world plaque. `flat` hides the stele for papers/walls/raft planks.
static func _plaque(game, pos: Vector3, title: String, writing: String, flat: bool = false) -> Node3D:
	game._inscription(pos, title, writing)
	var entry: Dictionary = game.inscriptions.back()
	var holder: Node3D = entry.node
	if flat:
		for c: Node in holder.get_children():
			if c is Node3D:
				(c as Node3D).visible = false
	return holder


static func _invisible_wall(root: Node3D, wall_name: String, pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = wall_name
	body.position = pos
	body.collision_layer = L.LAYER_WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	body.add_child(cs)
	root.add_child(body)


# Low visible parapet with a taller invisible guard (no falls into the drowned ward).
static func _parapet(root: Node3D, game, base: Vector3, size: Vector3) -> void:
	L.box(root, "low_parapet", base + Vector3(0, size.y * 0.5, 0), size, game.mats.stone)
	_invisible_wall(root, "low_parapet_guard", base + Vector3(0, size.y + 1.2, 0), Vector3(size.x, 2.4, size.z))


static func _sphere(parent: Node3D, node_name: String, pos: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _chalk(parent: Node3D, text: String, pos: Vector3, rot: Vector3, font_size: int = 48, color: Color = Color(0.9, 0.88, 0.8, 0.85)) -> Label3D:
	var label := Label3D.new()
	label.name = "chalk_" + text.left(12).validate_node_name()
	label.text = text
	label.font_size = font_size
	label.pixel_size = 0.006
	label.modulate = color
	label.outline_size = 0
	label.double_sided = true
	label.shaded = true
	label.position = pos
	label.rotation = rot
	parent.add_child(label)
	return label
