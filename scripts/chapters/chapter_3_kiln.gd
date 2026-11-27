extends RefCounted

## CHAPTER III — THE KILN OF ASH ("Where Names Become Iron").
##
## Layout (−Z is north): the Foundry Rim at y 6 overlooks the Crucible Hall
## (y 0), the West Frozen Aqueduct, the East Deep Smeltery, the Gate Forecourt
## and the Great Ashen Gate at z −38, with the Hollow Beyond vista behind it.
## There are no portals: the player arrives at the bottom of the Belfry drop
## throat (arrival `kiln_from_tower`) and returns by the Archive Service Stair
## (route `kiln_to_tower`).
##
## Story performance runs through StoryDirector when `game.story_director`
## exists. Durable world state is applied by idempotent helpers that also run
## without a director, so the legacy main.gd puzzle paths keep working.
## Public entry points for main.gd: default_state(), build(), sync_visual_state(),
## spawn_meltdown_encounter(), pull_hoist_lever() and turn_great_gate().

const L = preload("res://scripts/level_builder.gd")
const SD = preload("res://scripts/story_director.gd")
const Visuals = preload("res://scripts/visuals.gd")

const CHAPTER_ID := "ch3_kiln"
const RIM_Y := 6.0
const ARRIVAL_ID := "kiln_from_tower"
const ARRIVAL_POS := Vector3(0, 6.1, 24.6)
const SAFE_RETURN_ID := "kiln_archive_return"
const ROUTE_TO_TOWER := "kiln_to_tower"
const TOWER_ARRIVAL_ID := "tower_from_kiln"
const GATE_APPROACH := Vector3(0, 1.5, -36.4)
const LOCK_PLATE := Vector3(0, 1.5, -37.4)
const COLOSSUS_SPAWN := Vector3(0, 0.0, -31.6)
const COLOSSUS_ID := "colossus"
const COLOSSUS_HP := 640
const COLOSSUS_NAME := "THE LADLE — CRUCIBLE COLOSSUS"
const KEY_PICKUP := Vector3(0, 1.2, -5)
const KEY_COOL_TIME := 22.0
const GATE_TURN_GAP := 2.5
const BELL_POS := Vector3(2.2, -0.3, 10.0)
const BELL_PERIOD := 14.0
const BELL_PERIOD_MELTDOWN := 6.0
const FURNACE_LIGHT := Color("ffa05a")
const AQUEDUCT_LIGHT := Color("73e9ff")
const SOUL_LIGHT := Color("d9c8ff")
const GOLD_LIGHT := Color("f2dfa6")

const SEQ_ARRIVAL := "ch3_kiln/arrival"
const SEQ_BELL := "ch3_kiln/bell_loop"
const SEQ_BELL_FAST := "ch3_kiln/bell_loop_meltdown"
const SEQ_RIM := "ch3_kiln/rim_meeting"
const SEQ_VESSELS := "ch3_kiln/the_vessels"
const SEQ_TORIN := "ch3_kiln/torin_vessel"
const SEQ_BRIEF := "ch3_kiln/rim_brief"
const SEQ_TUBE_AQ := "ch3_kiln/tube_aqueduct"
const SEQ_TUBE_SMELT := "ch3_kiln/tube_smeltery"
const SEQ_ILSE := "ch3_kiln/ilse_sings"
const SEQ_TITHE := "ch3_kiln/tithe_roll_warning"
const SEQ_SURGE := "ch3_kiln/aqueduct_surge"
const SEQ_DAM := "ch3_kiln/dam_break"
const SEQ_DESCEND := "ch3_kiln/seraphina_descends"
const SEQ_TEMPER := "ch3_kiln/key_tempering"
const SEQ_MELTDOWN := "ch3_kiln/meltdown"
const SEQ_OVERDRIVE := "ch3_kiln/colossus_overdrive"
const SEQ_FALLS := "ch3_kiln/colossus_falls"
const SEQ_TO_GATE := "ch3_kiln/seraphina_to_gate"
const SEQ_CHOIR := "ch3_kiln/hollow_choir"
const SEQ_TURN_MOON := "ch3_kiln/gate_turn_moon"
const SEQ_TURN_CROWN := "ch3_kiln/gate_turn_crown"
const SEQ_UNSEAL := "ch3_kiln/great_gate_unseals"
const SEQ_AFTERWORD := "ch3_kiln/edge_afterword"
const INTEL_IDS: Array[String] = ["c3.ser.32", "c3.ser.33", "c3.ser.34", "c3.ser.35", "c3.ser.36"]

# Actor marks and Seraphina's cross-zone waypoints (chapter-local).
const MARKS := {
	"S1_rim": {"pos": Vector3(-3.2, 6.0, 15.1), "yaw": 0.0},
	"S2_hall": {"pos": Vector3(-5.4, 0.0, -1.5), "yaw": PI * 0.5},
	"S3_gallery": {"pos": Vector3(-11.6, 5.5, -26.0), "yaw": -PI * 0.5},
	"S4_gate": {"pos": Vector3(-8.6, 0.0, -32.6), "yaw": -1.1},
	"S5_edge": {"pos": Vector3(0.0, 0.0, -41.0), "yaw": 0.0},
	"trough_west": {"pos": Vector3(-2.6, 0.0, -5.0), "yaw": -PI * 0.5},
	"fresh_rack": {"pos": Vector3(-8.5, 6.0, 21.5), "yaw": 0.0},
	"malcor_helm": {"pos": Vector3(0.9, 6.05, 23.2), "yaw": 0.0},
	"rim_w_exit": {"pos": Vector3(-10.2, 6.0, 24.9), "yaw": 0.0},
	"w_stair_top": {"pos": Vector3(-15.0, 6.0, 24.6), "yaw": 0.0},
	"w_stair_foot": {"pos": Vector3(-15.0, 0.0, 12.4), "yaw": 0.0},
	"aq_bridge_approach": {"pos": Vector3(-13.2, 0.0, 4.0), "yaw": 0.0},
	"bridge4_w": {"pos": Vector3(-12.3, 0.29, 4.0), "yaw": 0.0},
	"bridge4_e": {"pos": Vector3(-7.7, 0.29, 4.0), "yaw": 0.0},
	"hall_w_4": {"pos": Vector3(-5.6, 0.0, 3.0), "yaw": 0.0},
	"hall_w_mid": {"pos": Vector3(-4.6, 0.0, -14.0), "yaw": 0.0},
	"arch_w": {"pos": Vector3(-5.0, 0.0, -21.6), "yaw": 0.0},
	"ladder_foot": {"pos": Vector3(-11.7, 0.0, -22.5), "yaw": 0.0},
	"ladder_top": {"pos": Vector3(-11.7, 5.5, -22.5), "yaw": 0.0},
	"forecourt_w": {"pos": Vector3(-8.4, 0.0, -28.0), "yaw": 0.0},
	"gate_mouth": {"pos": Vector3(-1.5, 0.0, -36.6), "yaw": 0.0},
}
const SERAPHINA_STANDS: Array[String] = ["S1_rim", "S2_hall", "S3_gallery", "S4_gate", "S5_edge", "trough_west"]

# Hall vessel racks: [target id, x, z centre, columns, rotation, labelled names].
const HALL_RACKS := [
	["rack_w0", -6.6, 9.3, 10, PI * 0.5, ["HESK, MARA", "HESK, TOMAS", "HESK, ANNA", "HESK — INFANT, UNNAMED"]],
	["rack_w1", -6.6, -1.0, 9, PI * 0.5, ["DORREL, NET-MENDER", "OSK OF THE QUAY", "BRENNA SALT", "VANT, I. — POUR INCOMPLETE"]],
	["rack_w2", -6.6, -5.8, 8, PI * 0.5, ["AVUN, OSSUARY KEEPER", "MAEVE CORDWAIN", "ELSBET PELL"]],
	["rack_w3", -6.6, -15.3, 10, PI * 0.5, ["THE LANTERN-WIFE", "JORY TALLOW", "NINE-YEAR TAM"]],
	["rack_e0", 6.6, 9.3, 10, -PI * 0.5, ["CALLUM WARE", "ISOLDE BRINE", "OLD MOTHER FENN"]],
	["rack_e1", 6.6, -1.0, 9, -PI * 0.5, ["ROWAN HASK", "TAMSIN WARE", "LUCE OF THE STEPS"]],
	["rack_e2", 6.6, -5.8, 8, -PI * 0.5, ["GARRET ORME", "WILLA KEEL"]],
	["rack_e3", 6.6, -15.3, 10, -PI * 0.5, ["SIMEON DRAKE", "HOB THE CISTERN-MAN", "AGATHE MOSS"]],
]
const RACK_ROWS := 7
const FRESH_NAMES: Array[String] = ["TORIN, BELL-WATCH", "WENDEL WARE, BELL-WATCH", "AGNA OF THE STEPS"]
const LADLE_BARKS: Array[String] = ["—HESK—", "—third bell—", "—room on the raft—", "—WARE—", "—write us down—"]

# Subtitle lines: id -> [speaker profile, text, duration].
const LINES := {
	"c3.ser.01": ["seraphina", "You fell. Of course you fell. Guild men never take stairs.", 3.6],
	"c3.ser.02": ["seraphina", "Malcor?", 1.2],
	"c3.ser.03": ["seraphina", "...Then he's with the bell.", 2.4],
	"c3.ser.04": ["seraphina", "Come to the rail. I want you to see it before I say anything.", 3.6],
	"c3.cho.01": ["hollow_choir", "…we were waiting on the quay…", 3.0],
	"c3.cho.02": ["hollow_choir", "…write us down… write us down…", 3.2],
	"c3.ser.05": ["seraphina", "Iron that remembers. The only thing the Hollow can't eat through. Orrun found it. The King paid for it.", 5.6],
	"c3.ser.06": ["seraphina", "Every vessel is a name. Every name is someone from the lower ward.", 3.8],
	"c3.ser.07": ["seraphina", "Three thousand and eleven. The Gate is made of them.", 3.4],
	"c3.ser.08": ["seraphina", "And now the bell's down here with them. Still calling. Listen— it's pouring new ones.", 4.8],
	"c3.ser.09": ["seraphina", "...Torin.", 1.4],
	"c3.ser.10": ["seraphina", "I said I'd write him down. I didn't mean— the bell did it for me.", 4.0],
	"c3.ser.11": ["seraphina", "The Gate won't open without the Ashen Key. The last piece of your commission. They never poured it.", 5.0],
	"c3.ser.12": ["seraphina", "The hoist needs the quench trough full and the slag sluice running. Aqueduct west. Smeltery east.", 5.0],
	"c3.ser.13": ["seraphina", "I'll watch from up here. I can see the whole floor. ...I'm not going down among them.", 4.6],
	"c3.ser.14": ["seraphina", "...Caelen? Who's— who is that singing?", 3.4],
	"c3.ser.15": ["seraphina", "Caelen... is there a ledger on the lectern by the valve?", 3.4],
	"c3.ser.16": ["seraphina", "Leave it. Please. Just turn the valve.", 2.8],
	"c3.ser.17": ["seraphina", "That cart's full of ash from the bell chute. That's... them. What's left before the iron.", 4.4],
	"c3.ser.18": ["seraphina", "Send it. They won't mind. They don't remember minding.", 3.6],
	"c3.ser.19": ["seraphina", "The Quench. Orrun's men cooled the vessels here. ...It's frozen. It shouldn't be frozen.", 4.6],
	"c3.ils.01": ["ilse", "Sera...? Is that you on the stair?", 3.0],
	"c3.ils.02": ["ilse", "It's cold. The others are singing. I only remember half the song.", 4.0],
	"c3.ser.20": ["seraphina", "I wrote them.", 1.8],
	"c3.ser.21": ["seraphina", "The King asked for a census of the lower ward. I knew what a census was for.", 4.4],
	"c3.ser.22": ["seraphina", "Three thousand and eleven names, in a fair hand, by lamplight.", 3.8],
	"c3.ser.23": ["seraphina", "My sister was the first page. I struck her. The count had to hold, so I wrote four more.", 5.0],
	"c3.ser.24a": ["seraphina", "You read it. Then you know their name.", 2.8],
	"c3.ser.24b": ["seraphina", "A family by the cistern. Hesk. Their name was Hesk.", 3.2],
	"c3.ser.24c": ["seraphina", "You saw it chalked on the raft. I asked you not to read it.", 3.4],
	"c3.ser.25": ["seraphina", "Ilse went down to warn them anyway. The bell didn't call her. So they brought her here. By hand.", 5.2],
	"c3.ser.26a": ["seraphina", "That was her, in the aqueduct. Singing half a song.", 3.2],
	"c3.ser.26b": ["seraphina", "She's still in there, Caelen. Half of her.", 2.8],
	"c3.ser.27": ["seraphina", "Malcor wanted it shut forever. I want it open. Let them out. Let her out.", 4.4],
	"c3.ser.28": ["seraphina", "You can hate me on the other side. Take the key.", 3.2],
	"c3.ser.30": ["seraphina", "The crucible's overflowing— it's waking the Ladle! Forecourt, before the slag takes the hall!", 4.6],
	"c3.ser.31": ["seraphina", "That's Orrun's Ladle! Made from the overflow— named iron, no single name!", 4.4],
	"c3.ser.32": ["seraphina", "Frost won't bite named iron! Fork it— the iron carries the current!", 4.0],
	"c3.ser.33": ["seraphina", "Above it— the cauldron chain! Shoot it now!", 2.8],
	"c3.ser.34": ["seraphina", "When the bell tolls, it tolls! Jump the ring!", 2.6],
	"c3.ser.35": ["seraphina", "Yes— feed it the cask!", 1.8],
	"c3.ser.36": ["seraphina", "Flask by the west pillar— take it!", 2.4],
	"c3.ser.37": ["seraphina", "Its chest is open— the names are coming loose! Strike the white!", 3.6],
	"c3.cho.05": ["hollow_choir", "…key-maker… key-maker… key-maker…", 3.6],
	"c3.ser.38": ["seraphina", "It's over.", 1.4],
	"c3.ser.39": ["seraphina", "...No. It's waiting for you.", 2.4],
	"c3.cho.06": ["hollow_choir", "…key-maker… open the gate… give us back our names…", 3.8],
	"c3.cho.07": ["hollow_choir", "…moon that saw it…", 2.4],
	"c3.cho.08": ["hollow_choir", "…crown that willed it…", 2.4],
	"c3.ser.40": ["seraphina", "...The King's name. In the keystone. He's in there with them.", 3.8],
	"c3.cho.09": ["hollow_choir", "…skull that paid it…", 2.4],
	"c3.ils.03": ["ilse", "Sera? You came down.", 2.6],
	"c3.ser.41": ["seraphina", "Ilse...?", 1.6],
	"c3.vae.01": ["king", "Lock-smith.", 2.0],
	"c3.vae.02": ["king", "You came back to finish your work. Good.", 3.4],
	"c3.vae.03": ["king", "Come home, Caelen. The Choir needs its key.", 3.8],
	"c3.ser.42": ["seraphina", "She answered me. Did you hear? She answered.", 3.2],
	"c3.ser.43": ["seraphina", "Go on, then. I'll be right behind you. I promise.", 3.4],
}

const TITHE_ROLL_TEXT := "THE TITHE ROLL OF THE LOWER WARD — compiled for the Crown by S. Vant, Archivist of the Register. Three thousand and eleven entries, in a fair hand.\nEntry 1: VANT, ILSE — struck through. Beside it, the same hand: Replaced — HESK, Mara · HESK, Tomas · HESK, Anna · HESK, infant (unnamed).\nBelow, in another hand: Witness brought down after the Third Bell: VANT, ILSE. Hand-pour, by order. — O."


static func default_state() -> Dictionary:
	return {
		"trough_flooded": false, "aqueduct_powered": false, "dam_broken": false,
		"key_forged": false, "gauntlet_triggered": false, "dropped_cauldrons": [],
		"colossus_dead": false, "colossus_hp": COLOSSUS_HP, "great_gate_open": false,
		"rim_met": false, "vessels_seen": false, "ilse_heard": false, "read_tithe_roll": false,
		"smelt_awake": false, "key_tempered_at": 0.0, "gate_turns": 0, "act_complete": false,
		"story_world": {"seraphina_mark": "S1_rim", "completed_sequences": {}},
	}


static func build(game, st: Dictionary) -> void:
	var root: Node3D = game.level_root
	_normalize_state(st)
	var sd: Object = _bind_director(game, root, st)
	_kiln_mats(game, root)
	_foundry_rim(game, root, st)
	_archive_stair(game, root, sd)
	_crucible_hall(game, root, st)
	_aqueduct(game, root, st)
	_smeltery(game, root, st)
	_foundry_conduits(game, root, st)
	_forecourt(game, root)
	_great_gate(game, root, st)
	_hollow_beyond(game, root, st)
	_seraphina(game, root, st, sd)
	L.add_far_landmarks(game, root, Vector3(0, 60.0, 143.6), {"keep": false, "bell": false})
	if st.gauntlet_triggered:
		spawn_meltdown_encounter(game, true)
	game._scatter_particles("ember", 105, Rect2(-32, -41, 64, 67))
	if sd != null:
		_register_story(game, root, st, sd)
	elif not st.great_gate_open:
		L.add_trigger_volume(game, Vector3(0, 1.45, -35), Vector3(7.6, 3.2, 3.1), "hollow_choir", "", "hollow_choir", "THE HOLLOW CHOIR", "The voices behind the iron speak in unison: “…key-maker… open the gate… give us back our names…”", "The Hollow Choir speaks from beyond the Gate.")
	sync_visual_state(game, st)
	_install_driver(game, root, st)
	if sd != null:
		_finish_director(game, root, st, sd)


# =============================================================================
# State
# =============================================================================

static func _normalize_state(st: Dictionary) -> void:
	var defaults := default_state()
	for k: String in defaults.keys():
		if not st.has(k):
			st[k] = defaults[k]
	if not st.story_world is Dictionary:
		st.story_world = {"seraphina_mark": "S1_rim", "completed_sequences": {}}
	if not (st.story_world as Dictionary).get("completed_sequences") is Dictionary:
		st.story_world["completed_sequences"] = {}
	if bool(st.great_gate_open):
		st.gate_turns = 3
	if int(st.gate_turns) >= 3 and not bool(st.great_gate_open):
		st.great_gate_open = true
	if bool(st.dam_broken):
		st.smelt_awake = true
	st.story_world["seraphina_mark"] = _resolve_seraphina_mark(st)


static func _resolve_seraphina_mark(st: Dictionary) -> String:
	var world: Dictionary = st.get("story_world", {})
	var mark := str(world.get("seraphina_mark", "S1_rim"))
	match mark:
		"kiln_observation":
			mark = "S1_rim"
		"kiln_safe_gantry":
			mark = "S3_gallery"
	if not SERAPHINA_STANDS.has(mark):
		mark = "S1_rim"
	if bool(st.get("act_complete", false)):
		return "S5_edge"
	if bool(st.get("colossus_dead", false)):
		return mark if mark == "S5_edge" else "S4_gate"
	if bool(st.get("gauntlet_triggered", false)):
		return "S3_gallery"
	if bool(st.get("trough_flooded", false)) and bool(st.get("dam_broken", false)):
		return mark if mark in ["S2_hall", "trough_west"] else "S2_hall"
	return "S1_rim"


## Restore every durable visual from state. Idempotent; safe after a reload.
static func sync_visual_state(game, st: Dictionary) -> void:
	var root: Node3D = game.level_root
	if not is_instance_valid(root):
		return
	_normalize_state(st)
	if is_instance_valid(game.trough_water):
		game.trough_water.visible = bool(st.trough_flooded)
	if is_instance_valid(game.key_mold):
		game.key_mold.visible = not bool(st.key_forged)
	_apply_meltwater(root, bool(st.trough_flooded))
	if bool(st.dam_broken) and is_instance_valid(game.slag_dam):
		game.slag_dam.visible = false
		game.slag_dam.collision_layer = 0
	if bool(st.colossus_dead):
		_apply_colossus_fallen(game, root, st, false)
	_apply_gate_turn_visuals(root, int(st.gate_turns))
	_show_vista(root, bool(st.great_gate_open))
	if bool(st.great_gate_open):
		for door: Variant in [game.great_gate_left, game.great_gate_right]:
			if is_instance_valid(door) and door is StaticBody3D:
				(door as StaticBody3D).collision_layer = 0
		if is_instance_valid(game.great_gate_left):
			game.great_gate_left.position.x = -8.5
		if is_instance_valid(game.great_gate_right):
			game.great_gate_right.position.x = 8.5
	if bool(st.act_complete):
		_vessels_dark(root)
	var holder: Variant = _meta(root, "seraphina_holder")
	if is_instance_valid(holder) and holder is Node3D:
		var m: Dictionary = MARKS[str(st.story_world.seraphina_mark)]
		(holder as Node3D).position = m.pos
		(holder as Node3D).rotation.y = float(m.yaw)
	_update_lock_hint(game, root, st)


# =============================================================================
# Director binding
# =============================================================================

static func _sd(game) -> Object:
	if game == null or not is_instance_valid(game):
		return null
	var d: Variant = game.get("story_director")
	if d == null and (game as Object).has_meta("story_director"):
		d = (game as Object).get_meta("story_director")
	if is_instance_valid(d) and d is Object and (d as Object).has_method("register_sequence"):
		return d
	return null


## The director, but only while it still owns this level build.
static func _sd_live(game, root: Node3D) -> Object:
	var sd: Object = _sd(game)
	if sd == null or not is_instance_valid(root) or not bool(root.get_meta("sd_bound", false)):
		return null
	if int(sd.call("get_generation")) != int(root.get_meta("sd_gen", -1)):
		return null
	return sd


static func _bind_director(game, root: Node3D, st: Dictionary) -> Object:
	var sd: Object = _sd(game)
	if sd == null:
		return null
	if str(sd.call("get_chapter")) != CHAPTER_ID or sd.get("_level") != root:
		sd.call("begin_chapter", CHAPTER_ID, root, st)
	root.set_meta("sd_bound", true)
	root.set_meta("sd_gen", int(sd.call("get_generation")))
	return sd


static func _finish_director(game, root: Node3D, st: Dictionary, sd: Object) -> void:
	for l: OmniLight3D in game.torches:
		if is_instance_valid(l):
			sd.call("register_light_group", "kiln_all", l)
	for rack: Node3D in _racks(root):
		var light: Variant = _meta(rack, "rack_light")
		if light is Light3D:
			sd.call("register_light_group", "kiln_all", light)
	sd.call("finish_chapter_build")
	root.set_meta("sd_gen", int(sd.call("get_generation")))
	if not bool(st.act_complete):
		var meltdown_live: bool = bool(st.gauntlet_triggered) and not bool(st.colossus_dead)
		sd.call("start_sequence", SEQ_BELL_FAST if meltdown_live else SEQ_BELL)
	sd.call("start_sequence", SEQ_ARRIVAL)


static func _target(sd: Object, id: String, node: Node3D) -> void:
	if sd != null and node != null:
		sd.call("register_target", id, node)


# =============================================================================
# Materials
# =============================================================================

static func _glow(color: Color, energy: float, albedo: Color = Color(0, 0, 0, 0)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo if albedo.a > 0.0 else color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.roughness = 0.42
	return m


static func _translucent(color: Color, alpha: float, emission: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.12
	m.metallic_specular = 0.8
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = energy
	return m


static func _kiln_mats(game, root: Node3D) -> Dictionary:
	if root.has_meta("kiln_mats"):
		return root.get_meta("kiln_mats")
	var mats := {
		"soul": _glow(Color("cdb8ff"), 1.6, Color("e9e0ff")),
		"soul_channel": _glow(Color("c9b2ff"), 2.2, Color("d8ccff")),
		"hot_vessel": _glow(Color("ff6a20"), 3.0, Color("ff8a3a")),
		"name_ash": _glow(Color("b9a2ff"), 0.45, Color("2c2628")),
		"ash_stream": _translucent(Color("9a9296"), 0.55, Color("b9a2ff"), 0.6),
		"ice_shell": _translucent(Color("bdf4ff"), 0.42, Color("7fd8ff"), 0.35),
		"rime": _translucent(Color("dff7ff"), 0.28, Color("9fe6ff"), 0.12),
		"bell_bronze": _bronze(),
		"bell_crack": _glow(Color("b47cff"), 3.2),
		"gold": _glow(GOLD_LIGHT, 0.4, Color("8a6a2a")),
		"crown_crack": _glow(Color("ffd36a"), 4.0),
		"black_water": _black_water(),
		"lantern": _glow(Color("ffcf8a"), 3.0),
		"helm": _bronze(),
		"ledger": _glow(Color("efe6d2"), 0.15, Color("e6dcc4")),
		"invisible": _translucent(Color.WHITE, 0.0, Color.WHITE, 0.0),
	}
	mats.ledger.roughness = 0.95
	root.set_meta("kiln_mats", mats)
	return mats


static func _bronze() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("8a5a32")
	m.metallic = 0.85
	m.roughness = 0.38
	return m


static func _black_water() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("05070c")
	m.metallic = 0.6
	m.roughness = 0.05
	m.emission_enabled = true
	m.emission = Color("1c1830")
	m.emission_energy_multiplier = 0.4
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func _meta(obj: Variant, key: String) -> Variant:
	if not is_instance_valid(obj) or not (obj as Object).has_meta(key):
		return null
	return (obj as Object).get_meta(key)


static func _km(root: Node3D, key: String) -> Material:
	var mats: Dictionary = root.get_meta("kiln_mats", {})
	return mats.get(key) as Material


# =============================================================================
# Small construction helpers
# =============================================================================

static func _beam(parent: Node3D, node_name: String, a: Vector3, b: Vector3, radius: float, mat: Material, sides: int = 10) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = maxf(a.distance_to(b), 0.01)
	cyl.radial_segments = sides
	mi.mesh = cyl
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	var dir := (b - a).normalized() if a.distance_to(b) > 0.001 else Vector3.UP
	var ref := Vector3.FORWARD if absf(dir.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var x := ref.cross(dir).normalized()
	mi.transform = Transform3D(Basis(x, dir, x.cross(dir)), (a + b) * 0.5)
	return mi


static func _label(parent: Node3D, node_name: String, text: String, pos: Vector3, size: int, pixel: float, color: Color, yaw: float = 0.0) -> Label3D:
	var lbl := Label3D.new()
	lbl.name = node_name
	lbl.text = text
	lbl.position = pos
	lbl.rotation.y = yaw
	lbl.font_size = size
	lbl.pixel_size = pixel
	lbl.modulate = color
	lbl.outline_size = 6
	lbl.outline_modulate = Color("120c14")
	lbl.shaded = false
	parent.add_child(lbl)
	return lbl


static func _omni(parent: Node3D, pos: Vector3, color: Color, energy: float, reach: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	parent.add_child(light)
	return light


static func _hide_mesh(node: Node3D) -> void:
	for c: Node in node.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).visible = false


static func _hitbox(parent: Node3D, node_name: String, pos: Vector3, size: Vector3, hint: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	body.collision_layer = L.LAYER_TARGET
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	body.set_meta("interact_hint", hint)
	parent.add_child(body)
	return body


## An [E]-readable world object routed through main.gd's inscription bridge.
## `anchor_pos` is the floor point the player stands near (level-root space).
static func _inspectable(game, root: Node3D, node_id: String, anchor_pos: Vector3, title: String, writing: String, hint: String = "", on_read: Callable = Callable()) -> Marker3D:
	var anchor := Marker3D.new()
	anchor.name = "inspect_" + node_id
	anchor.position = anchor_pos
	root.add_child(anchor)
	var entry := {"id": node_id, "kind": "kiln_inspect", "node": anchor, "title": title, "writing": writing,
		"interact_hint": hint if not hint.is_empty() else "%s — INSPECT [E]" % title}
	if on_read.is_valid():
		entry["on_read"] = on_read
	game.inscriptions.append(entry)
	return anchor


static func _story_area(root: Node3D, node_name: String, pos: Vector3, size: Vector3, radius: float = 0.0) -> Area3D:
	var area := Area3D.new()
	area.name = node_name
	area.position = pos
	area.collision_layer = 0
	area.collision_mask = L.LAYER_PLAYER
	area.monitorable = false
	area.monitoring = false
	var cs := CollisionShape3D.new()
	if radius > 0.0:
		var sphere := SphereShape3D.new()
		sphere.radius = radius
		cs.shape = sphere
	else:
		var box := BoxShape3D.new()
		box.size = size
		cs.shape = box
	area.add_child(cs)
	root.add_child(area)
	return area


static func _marker(root: Node3D, node_name: String, pos: Vector3, yaw: float = 0.0) -> Marker3D:
	var m := Marker3D.new()
	m.name = node_name
	m.position = pos
	m.rotation.y = yaw
	root.add_child(m)
	return m


## Spawn through main.gd's _enemy() and return the body. A dormant enemy is a
## statue: it stays in the world (solid, unhurt) but out of game.enemies, so
## neither AI nor damage touch it until _wake_smeltery() returns it.
static func _spawn_enemy(game, pos: Vector3, armored: bool, enemy_id: String, kind: String, dormant: bool = false, is_boss: bool = false) -> CharacterBody3D:
	var before: int = game.enemies.size()
	game._enemy(pos, armored, enemy_id, is_boss, kind)
	if game.enemies.size() <= before:
		return null
	var e: CharacterBody3D = game.enemies.back()
	if str(e.get_meta("id", "")) != enemy_id:
		return null
	if dormant:
		e.set_meta("dormant", true)
		game.enemies.erase(e)
		var root: Node3D = game.level_root
		var dorm: Dictionary = root.get_meta("kiln_dormant", {})
		dorm[enemy_id] = e
		root.set_meta("kiln_dormant", dorm)
	return e


static func _checkpoint(game, checkpoint_id: String, label: String) -> void:
	if game.has_method("_on_checkpoint_reached"):
		game._on_checkpoint_reached(checkpoint_id, label)


static func _line_dict(line_id: String) -> Dictionary:
	var spec: Array = LINES[line_id]
	return {"id": line_id, "group_id": "ch3_kiln/legacy", "speaker_id": str(spec[0]), "line": str(spec[1]), "duration": float(spec[2])}


## Fallback subtitles when no StoryDirector is present.
static func _say_ids(game, ids: Array) -> void:
	var narrative: Variant = game.get("narrative")
	if not narrative is Object or not is_instance_valid(narrative):
		return
	for line_id: Variant in ids:
		var d := _line_dict(str(line_id))
		if (narrative as Object).has_method("submit_line"):
			(narrative as Object).call("submit_line", d)
		else:
			(narrative as Object).call("say", str(d.speaker_id).to_upper(), str(d.line), float(d.duration), Color("70d7df"))


static func _banner(game, text: String, color: Color) -> void:
	var narrative: Variant = game.get("narrative")
	if narrative is Object and is_instance_valid(narrative) and (narrative as Object).has_method("show_style_banner"):
		(narrative as Object).call("show_style_banner", text, color)


## Timer-driven fallback timeline: [[seconds, Callable], ...]. Each step checks
## the level is still mounted.
static func _run_timeline(game, root: Node3D, steps: Array) -> void:
	var tree: SceneTree = root.get_tree()
	if tree == null:
		return
	for step: Array in steps:
		var cb: Callable = step[1]
		var guarded := func() -> void:
			if is_instance_valid(root) and root.is_inside_tree() and root == game.level_root:
				cb.call()
		if float(step[0]) <= 0.0:
			guarded.call()
		else:
			tree.create_timer(float(step[0]), false).timeout.connect(guarded)


# =============================================================================
# Z1 — Foundry Rim (y 6), drop throat, undercroft, rim stairs
# =============================================================================

static func _foundry_rim(game, root: Node3D, st: Dictionary) -> void:
	var sd: Object = _sd(game) if bool(root.get_meta("sd_bound", false)) else null
	var basalt: Material = game.mats.basalt
	var iron: Material = game.mats.iron
	var brass: Material = game.mats.brass
	# Undercroft at y 0 (the old observation deck) opens north into the hall.
	L.slab(root, "rim_undercroft_floor", Rect2(-11.5, 13.8, 23, 13.2), 0, basalt)
	L.slab(root, "foundry_rim", Rect2(-11.5, 13.8, 23, 13.2), RIM_Y, basalt, 0.6)
	L.box(root, "rim_fascia", Vector3(0, 5.25, 14.05), Vector3(23, 0.9, 0.5), basalt, false)
	for x: float in [-8.0, -2.9, 2.9, 8.0]:
		L.cylinder(root, "rim_pier", Vector3(x, 2.65, 14.35), 0.55, 5.3, basalt, true, 12)
		L.cylinder(root, "rim_pier_capital", Vector3(x, 5.25, 14.35), 0.78, 0.4, brass, false, 12)
	game._light(Vector3(-4, 3.6, 21), FURNACE_LIGHT, 1.6, 9.0)
	game._light(Vector3(5, 3.6, 21), FURNACE_LIGHT, 1.3, 9.0)
	# South wall (full width so it also closes both stair towers).
	L.box(root, "rim_south_wall_low", Vector3(0, 3.0, 27.0), Vector3(35.2, 6.0, 1.0), basalt)
	L.box(root, "rim_south_wall_w", Vector3(-6.0, 10.0, 27.0), Vector3(23.2, 8.0, 1.0), basalt)
	L.box(root, "rim_south_wall_e", Vector3(13.4, 10.0, 27.0), Vector3(8.4, 8.0, 1.0), basalt)
	L.box(root, "archive_door_lintel", Vector3(7.4, 12.0, 27.0), Vector3(3.6, 4.0, 1.0), basalt)
	for side: float in [-1.0, 1.0]:
		var x := 11.4 * side
		L.box(root, "rim_side_wall_low", Vector3(x, 3.0, 20.4), Vector3(1.0, 6.0, 13.2), basalt)
		L.box(root, "rim_side_wall_high", Vector3(x, 10.0, 18.55), Vector3(1.0, 8.0, 9.5), basalt)
		L.box(root, "rim_stair_door_lintel", Vector3(x, 12.0, 24.95), Vector3(1.0, 4.0, 3.3), basalt)
		L.box(root, "rim_side_wall_corner", Vector3(x, 10.0, 26.8), Vector3(1.0, 8.0, 0.4), basalt)
		L.archway(root, "rim_stair_door", Vector3(x, RIM_Y, 24.95), 3.3, 3.6, 1.0, basalt, brass, PI * 0.5)
		# Stair tower: landing outside the rim wall, then a guarded flight north
		# through the wing's end wall down to the wing floor.
		var cx := 15.0 * side
		L.slab(root, "rim_stair_landing", Rect2(minf(11.4 * side, 17.6 * side), 22.9, 6.2, 4.1), RIM_Y, basalt)
		L.box(root, "rim_stair_tower_wall", Vector3(17.6 * side, 7.0, 22.7), Vector3(0.8, 14.0, 9.4), basalt)
		var stair_name := "west_rim_stair" if side < 0.0 else "east_gantry_stair"
		var step_mat: Material = game.mats.stone if side < 0.0 else iron
		L.staircase(root, stair_name, Vector3(cx, RIM_Y, 23.0), Vector3(cx, 0.0, 12.6), 4.0, step_mat, iron)
		# Solid soffit under the flight so nothing can wedge beneath it.
		var soffit := L.box(root, stair_name + "_soffit", Vector3(cx, 1.3, 18.65), Vector3(4.0, 3.0, 10.0), basalt)
		soffit.rotation.x = -atan2(6.0, 10.4)
		L.slab(root, "rim_stair_tower_floor", Rect2(minf(11.4 * side, 17.6 * side), 18.0, 6.2, 9.0), 0.0, basalt)
		L.hanging_chain_lamp(game, root, Vector3(cx, 8.6, 24.8), 2.2, FURNACE_LIGHT if side > 0.0 else AQUEDUCT_LIGHT, 3.2, 10.0)
		game._light(Vector3(cx, 3.4, 16.0), FURNACE_LIGHT if side > 0.0 else AQUEDUCT_LIGHT, 1.8, 9.0)
	# Rim rail at z 14.4: intact west, the Pour Stair opening, the bent section the
	# Bell tore through (x 2.3…6, still guarded), intact east.
	L.box(root, "rim_rail_w", Vector3(-6.85, RIM_Y + 0.75, 14.4), Vector3(9.1, 1.5, 0.55), iron)
	L.box(root, "rim_rail_e", Vector3(8.7, RIM_Y + 0.75, 14.4), Vector3(5.4, 1.5, 0.55), iron)
	var bent_a := L.box(root, "rim_rail_bent", Vector3(3.2, RIM_Y + 0.45, 14.45), Vector3(1.8, 0.9, 0.4), iron)
	bent_a.rotation.z = 0.25
	var bent_b := L.box(root, "rim_rail_bent", Vector3(5.2, RIM_Y + 0.35, 14.6), Vector3(1.6, 0.7, 0.4), iron)
	bent_b.rotation.z = -0.3
	_hide_mesh(L.box(root, "rim_breach_guard", Vector3(4.15, RIM_Y + 0.8, 14.5), Vector3(3.8, 1.6, 0.3), iron))
	# The Pour Stair: upper flight only; the Bell crushed the rest.
	L.staircase(root, "pour_stair_upper", Vector3(0, RIM_Y, 14.0), Vector3(0, 3.6, 11.4), 4.0, basalt, iron)
	var block := L.box(root, "pour_stair_bell_rubble", Vector3(0, 4.6, 11.0), Vector3(4.6, 3.0, 0.9), basalt)
	block.rotation.z = 0.12
	for i in 3:
		SD.add_masonry_pile(root, Transform3D(Basis(Vector3.UP, 0.6 * i), Vector3(-1.2 + 1.2 * i, 3.4, 11.6)), basalt, 310 + i, false)
	for z: float in [15.5, 20.5]:
		L.vaulted_rib(root, Vector3(0, RIM_Y + 6.85, z), 22, 5.7, basalt, brass)
	for p: Vector3 in [Vector3(-6.5, 11.2, 18.0), Vector3(6.5, 11.2, 18.0)]:
		L.hanging_chain_lamp(game, root, p, 1.6, FURNACE_LIGHT, 4.4, 12.0)
	for x: float in [-10.0, 10.0]:
		game._torch(Vector3(x, RIM_Y + 2.8, 17.0))
	L.focus_light(root, Vector3(-6.0, RIM_Y + 5.4, 16.6), Vector3(-3.2, RIM_Y + 1.2, 15.1), FURNACE_LIGHT, 3.4, 26.0)
	_drop_throat(game, root, sd)
	_fresh_rack(game, root, sd)
	_malcor_helm(game, root, sd)
	_ash_footprints(game, root)
	L.add_alchemical_font(game, Vector3(6.0, RIM_Y, 19.5))
	L.add_checkpoint_zone(game, Vector3(0, RIM_Y + 1.5, 20.6), Vector3(9, 3, 3.8), "kiln_landing", "Foundry Rim")
	var arrival := _marker(root, "arrival_" + ARRIVAL_ID, ARRIVAL_POS, 0.0)
	var safe := _marker(root, "arrival_" + SAFE_RETURN_ID, Vector3(7.4, 6.1, 23.4), 0.0)
	if sd != null:
		sd.call("register_arrival", ARRIVAL_ID, arrival)
		sd.call("register_arrival", SAFE_RETURN_ID, safe)
		_target(sd, "crucible_hall_center", _marker(root, "crucible_hall_center", Vector3(0, 2.0, -8.0)))
		_target(sd, "rim_rail", _marker(root, "rim_rail_center", Vector3(0, 7.0, 14.6)))


static func _drop_throat(game, root: Node3D, sd: Object) -> void:
	var basalt: Material = game.mats.basalt
	for x: float in [-2.75, 2.75]:
		L.box(root, "drop_throat_wall", Vector3(x, 11.0, 25.5), Vector3(0.5, 10.0, 3.4), basalt)
	L.box(root, "drop_throat_header", Vector3(0, 13.0, 23.95), Vector3(6.0, 5.0, 0.5), basalt)
	L.box(root, "drop_throat_back", Vector3(0, 15.0, 26.7), Vector3(6.0, 2.0, 0.6), basalt)
	# Broken iron grate at y 12, two bars torn downward.
	for i in 6:
		var bar := L.box(root, "throat_grate_bar", Vector3(-2.1 + 0.84 * i, 12.0, 25.4), Vector3(0.12, 0.12, 3.0), game.mats.iron, false)
		if i == 2 or i == 3:
			bar.rotation.x = 0.9 if i == 2 else -0.7
			bar.position.y -= 1.0
	L.box(root, "throat_grate_frame", Vector3(0, 12.0, 25.4), Vector3(5.0, 0.18, 0.2), game.mats.iron, false)
	# Ash heap: visual mound only (soft landing; no lip to snag the capsule).
	var heap := MeshInstance3D.new()
	heap.name = "ash_heap"
	var dome := SphereMesh.new()
	dome.radius = 1.0
	dome.height = 1.0
	dome.is_hemisphere = true
	heap.mesh = dome
	heap.material_override = game.mats.ash
	heap.position = Vector3(0, RIM_Y - 0.02, 25.4)
	heap.scale = Vector3(2.3, 0.32, 1.4)
	root.add_child(heap)
	var falling := L.add_steam_jet(root, Vector3(0, 11.4, 25.4), Vector3(0, -1, 0), Color(0.55, 0.52, 0.56, 0.35))
	falling.amount = 14
	falling.scale = Vector3.ONE * 0.55
	L.focus_light(root, Vector3(0, 11.6, 24.6), Vector3(0, RIM_Y, 25.0), Color("cbb9ff"), 2.4, 28.0, 0.5)
	_target(sd, "drop_throat", heap)


static func _fresh_rack(game, root: Node3D, sd: Object) -> void:
	var names := PackedStringArray(FRESH_NAMES)
	var rack := L.add_name_vessel_rack(root, Vector3(-8.5, RIM_Y, 21.5), PI * 0.5, 2, 4, game.mats.iron, _km(root, "hot_vessel"), names)
	rack.name = "fresh_pour_rack"
	_setup_rack(rack, "fresh_rack")
	var labels: Dictionary = rack.get_meta("labels")
	for lbl: Variant in labels.values():
		(lbl as Label3D).modulate = Color("ffd2a6")
	_target(sd, "fresh_rack", rack)
	var torin: Variant = labels.get(FRESH_NAMES[0], null)
	if torin is Label3D:
		_target(sd, "torin_vessel", torin)
	# Auto-pour chute from the throat and the fourth, still-filling mold.
	_beam(root, "auto_pour_chute", Vector3(-2.9, 10.6, 25.0), Vector3(-8.0, 7.4, 23.4), 0.22, game.mats.iron)
	_beam(root, "auto_pour_trickle", Vector3(-8.0, 7.3, 23.4), Vector3(-8.0, 6.35, 23.4), 0.05, _km(root, "hot_vessel"))
	var mold := L.box(root, "filling_mold", Vector3(-8.0, RIM_Y + 0.22, 23.4), Vector3(0.62, 0.44, 0.5), game.mats.cinder, false)
	var letters := _label(mold, "arriving_name", "· · ·", Vector3(0.33, 0.05, 0), 28, 0.004, Color("ffcfa0"), PI * 0.5)
	root.set_meta("filling_label", letters)
	_omni(root, Vector3(-8.0, RIM_Y + 0.9, 22.6), Color("ff8a3a"), 1.6, 4.5)
	_hitbox(root, "torin_vessel_hitbox", Vector3(-8.2, RIM_Y + 1.0, 21.5), Vector3(0.6, 0.8, 2.4), "NAME-VESSEL — \"TORIN, BELL-WATCH\" — STILL WARM")
	_hitbox(root, "filling_mold_hitbox", Vector3(-8.0, RIM_Y + 0.25, 23.4), Vector3(0.7, 0.5, 0.6), "AN UNFINISHED VESSEL — THE NAME IS STILL ARRIVING")
	_inspectable(game, root, "fresh_pour", Vector3(-7.0, RIM_Y, 22.2), "THE FRESH POUR",
		"Three vessels still glow orange: TORIN, BELL-WATCH · WENDEL WARE, BELL-WATCH · AGNA OF THE STEPS. A fourth mold is filling as you watch. The letters have not finished arriving.",
		"NAME-VESSEL — \"TORIN, BELL-WATCH\" — STILL WARM")


static func _malcor_helm(game, root: Node3D, sd: Object) -> void:
	var m: Dictionary = MARKS.malcor_helm
	var helm := Node3D.new()
	helm.name = "malcor_fallen_helm"
	helm.position = m.pos
	helm.rotation = Vector3(0.35, 0.8, 0.6)
	root.add_child(helm)
	var dome := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.34
	sphere.height = 0.5
	sphere.is_hemisphere = true
	dome.mesh = sphere
	dome.material_override = _km(root, "helm")
	dome.position.y = 0.05
	helm.add_child(dome)
	L.box(helm, "helm_crest", Vector3(0, 0.34, 0), Vector3(0.06, 0.18, 0.6), game.mats.brass, false)
	L.box(helm, "helm_visor_slit", Vector3(0, 0.16, -0.31), Vector3(0.32, 0.04, 0.04), game.mats.dark, false)
	L.box(helm, "helm_bell_charm", Vector3(0.24, 0.1, 0.2), Vector3(0.09, 0.12, 0.09), game.mats.brass, false)
	_omni(helm, Vector3(0, 0.5, 0), Color("d99cbd"), 0.6, 2.6)
	_hitbox(root, "malcor_helm_hitbox", m.pos + Vector3(0, 0.25, 0), Vector3(0.8, 0.6, 0.8), "LORD MALCOR'S HELM — STILL HUMMING")
	_inspectable(game, root, "malcor_helm", m.pos + Vector3(0, 0, 0.6), "LORD MALCOR'S HELM",
		"His bronze helm lies in the ash where it fell ahead of him. Pressed to the ear, it still hums one low note: the Lull, forty nights deep.",
		"LORD MALCOR'S HELM — STILL HUMMING")
	_target(sd, "malcor_helm", helm)


static func _ash_footprints(game, root: Node3D) -> void:
	var a := Vector3(7.4, RIM_Y + 0.005, 25.6)
	var b := Vector3(-3.0, RIM_Y + 0.005, 15.4)
	var steps := 14
	for i in steps:
		var t := (float(i) + 0.5) / float(steps)
		var p := a.lerp(b, t) + Vector3(0.14 if i % 2 == 0 else -0.14, 0, 0)
		var print_box := L.box(root, "seraphina_ash_footprint", p, Vector3(0.12, 0.01, 0.26), game.mats.ash, false)
		print_box.rotation.y = atan2(-(b - a).x, -(b - a).z)


static func _archive_stair(game, root: Node3D, sd: Object) -> void:
	var basalt: Material = game.mats.basalt
	L.slab(root, "archive_stair_sill", Rect2(5.6, 26.4, 3.6, 1.6), RIM_Y, basalt)
	for x: float in [5.4, 9.4]:
		L.box(root, "archive_recess_wall", Vector3(x, 9.5, 30.0), Vector3(0.4, 7.0, 6.0), basalt)
	L.box(root, "archive_recess_back", Vector3(7.4, 9.5, 33.2), Vector3(4.4, 7.0, 0.4), basalt)
	L.box(root, "archive_recess_roof", Vector3(7.4, 12.6, 30.0), Vector3(4.4, 0.4, 6.4), basalt, false)
	L.staircase(root, "archive_service_stair", Vector3(7.4, RIM_Y, 28.0), Vector3(7.4, 7.8, 31.0), 2.8, game.mats.stone, game.mats.iron)
	L.slab(root, "archive_stair_landing", Rect2(5.6, 30.9, 3.6, 2.1), 7.8, basalt)
	L.slab(root, "archive_stair_undercroft", Rect2(5.6, 27.5, 3.6, 3.4), RIM_Y - 0.25, basalt, 0.5)
	L.archway(root, "archive_service_arch", Vector3(7.4, RIM_Y, 26.45), 3.2, 3.8, 0.5, basalt, game.mats.brass)
	L.hanging_chain_lamp(game, root, Vector3(7.4, 11.2, 30.2), 1.0, Color("ffd9a8"), 2.4, 7.0)
	game._light(Vector3(7.4, 9.6, 32.4), Color("9fb7ff"), 0.9, 4.0)
	var zone := L.add_transition_zone(root, Transform3D(Basis.IDENTITY, Vector3(7.4, 9.1, 31.9)), Vector3(3.0, 3.0, 1.6), ROUTE_TO_TOWER)
	var aperture: Marker3D = zone.get_meta("aperture")
	if sd != null:
		sd.call("register_transition", zone, aperture, {
			"id": ROUTE_TO_TOWER, "destination": "ch2_tower", "arrival_id": TOWER_ARRIVAL_ID,
			"label": "ARCHIVE SERVICE STAIR — TO THE BELL TOWER", "kind": "arch",
			"direction_local": Vector3.BACK, "safe_return_id": SAFE_RETURN_ID,
		})


# =============================================================================
# Z2 / Z5 — Crucible Hall, vessel racks, embedded Bell, trough & key hoist
# =============================================================================

static func _crucible_hall(game, root: Node3D, st: Dictionary) -> void:
	var sd: Object = _sd(game) if bool(root.get_meta("sd_bound", false)) else null
	L.slab(root, "crucible_procession", Rect2(-8.1, -20.8, 16.2, 34.8), 0, game.mats.basalt)
	var rising := Node3D.new()
	rising.name = "rising_slag"
	rising.position.y = -0.14 if st.gauntlet_triggered and not st.colossus_dead else -1.8
	rising.set_meta("lowered_y", -1.8)
	rising.set_meta("raised_y", -1.8 if st.colossus_dead else -0.14)
	root.add_child(rising)
	game.rising_slag_node = rising
	for x: float in [-10, 10]:
		L.slab(root, "slag_river_bed", Rect2(x - 2, -20.8, 4, 34.8), -0.74, game.mats.basalt)
		L.box(root, "slag_river", Vector3(x, -0.58, -3.4), Vector3(3.65, 0.11, 34.8), game.mats.slag, false)
		L.box(rising, "rising_slag_river", Vector3(x, 0, -3.4), Vector3(3.75, 0.14, 34.8), game.mats.slag, false)
		game.slag_zones.append({"pos": Vector3(x, 0, -3.4), "half": Vector2(1.9, 17.35)})
		for z: float in [-14, -3, 10]:
			game._light(Vector3(x, 1.25, z), Color("ff642a"), 2.6, 10.5)
		for z: float in [-10, 4]:
			L.slab(root, "slag_bridge", Rect2(x - 2.55, z - 1.86, 5.1, 3.72), 0.29, game.mats.iron, 0.28)
			L.archway(root, "slag_bridge_mouth", Vector3(x * 1.165, 0.25, z), 4.6, 4.45, 0.9, game.mats.basalt, game.mats.brass, PI * 0.5)
	for z: float in [9, -2, -14]:
		L.vaulted_rib(root, Vector3(0, 6.65, z), 15.3, 5.2, game.mats.basalt, game.mats.iron)
		_gantry(game, root, Vector3(0, 7.05, z), 15.3, 2.3)
		for x: float in [-7.65, 7.65]:
			L.cylinder(root, "crucible_pier", Vector3(x, 3.2, z), 0.48, 6.4, game.mats.basalt, true, 12)
			L.box(root, "gantry_bearing", Vector3(x, 6.75, z), Vector3(1.14, 0.76, 0.98), game.mats.iron, false)
			game._torch(Vector3(x * 0.96, 5.5, z))
	for z: float in [9, -14]:
		L.hanging_chain_lamp(game, root, Vector3(0, 4.95, z), 1.55, FURNACE_LIGHT, 4.75, 11.5)
	for x: float in [-4.0, 4.0]:
		L.box(root, "longitudinal_hoist_rail", Vector3(x, 9.37, -2.5), Vector3(0.37, 0.44, 23.7), game.mats.iron, false)
		L.hanging_chain(root, Vector3(x, 9.18, -5), Vector3(x, 8.43, -5), 0.13, game.mats.iron)
	L.box(root, "west_cauldron_trolley", Vector3(-4, 9.19, 2), Vector3(0.75, 0.38, 0.86), game.mats.brass, false)
	L.box(root, "east_cauldron_trolley", Vector3(4, 9.19, -12), Vector3(0.75, 0.38, 0.86), game.mats.brass, false)
	_vessel_racks(game, root, sd)
	_soul_channels(game, root)
	_embedded_bell(game, root, sd)
	# Z5 — quench trough, crucible spout, key mold and chain hoist.
	L.box(root, "cooling_trough_frame", Vector3(0, 0.32, -5), Vector3(3.8, 0.64, 2.8), game.mats.dark)
	var water := L.box(root, "trough_water", Vector3(0, 0.66, -5), Vector3(3.35, 0.12, 2.35), game.mats.water, false)
	water.visible = st.trough_flooded
	game.trough_water = water
	var mold := L.box(root, "key_mold", Vector3(0, 2.4, -5), Vector3(1.2, 0.65, 0.8), game.mats.cinder, false)
	L.cylinder(mold, "mold_chain", Vector3(0, 2.85, 0), 0.105, 5.7, game.mats.iron, false, 8)
	var tag := L.box(mold, "mold_tag", Vector3(0.0, -0.05, 0.43), Vector3(0.56, 0.3, 0.03), game.mats.brass, false)
	_label(tag, "mold_tag_text", "DO NOT POUR — C.", Vector3(0, 0, 0.02), 26, 0.0035, Color("2a1a10"))
	L.box(root, "hoist_crossbeam", Vector3(0, 8.15, -5), Vector3(12.5, 0.55, 0.92), game.mats.iron, false)
	mold.visible = not st.key_forged
	game.key_mold = mold
	var spout := L.cone(root, "crucible_spout", Vector3(0, 8.0, -5), 0.22, 0.6, 0.7, game.mats.iron, 10)
	L.box(root, "crucible_belly", Vector3(0, 8.7, -5), Vector3(1.6, 0.9, 1.4), game.mats.iron, false)
	L.box(root, "crucible_glow", Vector3(0, 7.66, -5), Vector3(0.3, 0.04, 0.3), game.mats.cinder, false)
	var spout_mark := _marker(root, "key_spout", Vector3(0, 7.7, -5))
	_target(sd, "key_spout", spout_mark)
	_target(sd, "key_mold", mold)
	_target(sd, "trough", _marker(root, "trough_center", Vector3(0, 0.8, -5)))
	if st.key_forged and not game.has_ashen_key:
		game._pickup(KEY_PICKUP, "ashen_key", "kiln_ashen_key")
		_tag_key_pickup(game, false)
	game.hoist_lever = L.lever(root, "chain_hoist_lever", Vector3(3.55, 0, -5), game.mats.dark, game.mats.brass,
		"CHAIN HOIST — FLOOD THE TROUGH AND BREAK THE SLAG DAM FIRST")
	_inspectable(game, root, "ashen_key_mold", Vector3(-1.3, 0, -6.9), "THE ASHEN KEY",
		"Pattern & mold: Master C., Guild of Wards. DO NOT POUR.\nThe tag is in your own hand.",
		"THE ASHEN KEY — MOLD TAG")
	L.focus_light(root, Vector3(5.65, 6.8, -3.5), Vector3(3.55, 0.95, -5), FURNACE_LIGHT, 5.6, 24.0)
	L.focus_light(root, Vector3(-3.8, 6.2, -6.55), Vector3(0, 0.66, -5), AQUEDUCT_LIGHT, 4.25, 22.0)
	_add_slag_cauldron(game, root, st, Vector3(-4.0, 6.4, 2.0), "cauldron_0")
	_add_slag_cauldron(game, root, st, Vector3(4.0, 6.4, -12.0), "cauldron_1")
	L.add_explosive_cask(game, Vector3(-4.3, 0, 5.5), "kiln_cask_center_w")
	L.add_explosive_cask(game, Vector3(4.5, 0, -11), "kiln_cask_center_e")
	game._enemy(Vector3(-3.8, 0, 2), true, "kiln_ash_1", false, "ash_sentinel")
	game._enemy(Vector3(4.0, 0, -15.2), true, "kiln_crucible_exec", false, "executioner")
	game._pickup(Vector3(4.7, 0.55, 12.8), "mana", "kiln_blue_1")
	game._pickup(Vector3(-4.7, 0.55, -15.1), "green", "kiln_green_1")


static func _vessel_racks(game, root: Node3D, sd: Object) -> void:
	var racks: Array = root.get_meta("kiln_racks", [])
	for spec: Array in HALL_RACKS:
		var rack := L.add_name_vessel_rack(root, Vector3(float(spec[1]), 0.0, float(spec[2])), float(spec[4]), RACK_ROWS, int(spec[3]),
			game.mats.iron, _km(root, "soul"), PackedStringArray(spec[5]))
		rack.name = str(spec[0])
		_setup_rack(rack, str(spec[0]))
		racks.append(rack)
		_target(sd, str(spec[0]), rack)
	root.set_meta("kiln_racks", racks)


static func _setup_rack(rack: Node3D, rack_id: String) -> void:
	rack.set_meta("rack_id", rack_id)
	rack.set_meta("vessel_level", 1.0)
	rack.set_meta("look_center", Vector3(0, 2.0, 0.2))
	rack.set_meta("pulse", func(strength: float, duration: float) -> void: _pulse_rack(rack, strength, duration))
	if rack_id == "fresh_rack":
		var root := rack.get_parent() as Node3D
		if root != null:
			var racks: Array = root.get_meta("kiln_racks", [])
			racks.append(rack)
			root.set_meta("kiln_racks", racks)


static func _racks(root: Node3D) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for r: Variant in root.get_meta("kiln_racks", []):
		if is_instance_valid(r) and r is Node3D:
			out.append(r)
	return out


static func _set_rack_level(rack: Node3D, level: float) -> void:
	rack.set_meta("vessel_level", level)
	var mat := _meta(rack, "vessel_mat") as StandardMaterial3D
	var rest := float(rack.get_meta("vessel_rest_energy", 1.4))
	if mat != null:
		mat.emission_energy_multiplier = rest * level
	var light := _meta(rack, "rack_light") as Light3D
	if light != null:
		light.light_energy = 0.7 * level
	for lbl: Variant in (rack.get_meta("labels", {}) as Dictionary).values():
		if lbl is Label3D:
			(lbl as Label3D).modulate.a = lerpf(0.25, 1.0, level)


static func _pulse_rack(rack: Node3D, strength: float, duration: float) -> void:
	if not is_instance_valid(rack) or not rack.is_inside_tree():
		return
	var mat := _meta(rack, "vessel_mat") as StandardMaterial3D
	var level := float(rack.get_meta("vessel_level", 1.0))
	if mat == null or level <= 0.01:
		return
	var rest := float(rack.get_meta("vessel_rest_energy", 1.4)) * level
	var tw := rack.create_tween()
	tw.tween_property(mat, "emission_energy_multiplier", rest + strength * level, 0.08)
	tw.tween_property(mat, "emission_energy_multiplier", rest, maxf(duration, 0.1))
	var light := _meta(rack, "rack_light") as Light3D
	if light != null:
		var lt := rack.create_tween()
		lt.tween_property(light, "light_energy", 0.7 * level + strength, 0.08)
		lt.tween_property(light, "light_energy", 0.7 * level, maxf(duration, 0.1))


static func _soul_channels(_game, root: Node3D) -> void:
	var mat := _km(root, "soul_channel")
	var conduits: Array = []
	for side: float in [-1.0, 1.0]:
		var pts := PackedVector3Array([
			Vector3(5.6 * side, 0.0, 12.0), Vector3(5.6 * side, 0.0, -24.0),
			Vector3(2.0 * side, 0.0, -33.4), Vector3(0.6 * side, 0.0, -37.3),
		])
		var conduit := L.add_floor_conduit(root, pts, mat, mat, 0.34)
		L.set_floor_conduit_powered(conduit, true)
		conduits.append(conduit)
	root.set_meta("soul_channels", conduits)


static func _embedded_bell(game, root: Node3D, sd: Object) -> void:
	var bell := StaticBody3D.new()
	bell.name = "embedded_great_bell"
	bell.position = BELL_POS
	bell.rotation = Vector3(0.18, 0.6, 0.36)
	bell.collision_layer = L.LAYER_WORLD
	bell.collision_mask = 0
	root.add_child(bell)
	var waist := MeshInstance3D.new()
	waist.name = "bell_waist"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.4
	cyl.bottom_radius = 2.8
	cyl.height = 4.4
	cyl.radial_segments = 28
	waist.mesh = cyl
	waist.material_override = _km(root, "bell_bronze")
	waist.position.y = 2.2
	bell.add_child(waist)
	var lip := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 2.6
	torus.outer_radius = 3.0
	torus.rings = 32
	lip.mesh = torus
	lip.material_override = _km(root, "bell_bronze")
	lip.position.y = 0.2
	bell.add_child(lip)
	var crown := MeshInstance3D.new()
	var dome := SphereMesh.new()
	dome.radius = 1.42
	dome.height = 1.2
	dome.is_hemisphere = true
	crown.mesh = dome
	crown.material_override = _km(root, "bell_bronze")
	crown.position.y = 4.38
	bell.add_child(crown)
	L.box(bell, "bell_canon", Vector3(0, 5.1, 0), Vector3(0.5, 0.7, 0.5), game.mats.iron, false)
	var crack := Node3D.new()
	crack.name = "bell_crack"
	bell.add_child(crack)
	var crack_mat := _km(root, "bell_crack")
	var pts: Array[Vector3] = [Vector3(0.2, 4.6, 1.3), Vector3(-0.3, 3.5, 1.65), Vector3(0.25, 2.4, 2.05), Vector3(-0.2, 1.3, 2.45), Vector3(0.3, 0.3, 2.8)]
	for i in range(1, pts.size()):
		_beam(crack, "bell_crack_seam", pts[i - 1], pts[i], 0.05, crack_mat, 6)
	_beam(crack, "bell_crack_branch", pts[2], Vector3(1.1, 1.6, 2.2), 0.035, crack_mat, 6)
	_omni(bell, Vector3(0, 2.4, 3.2), Color("b47cff"), 1.6, 7.0)
	var shape := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = 2.55
	cs.height = 4.4
	shape.shape = cs
	shape.position.y = 2.2
	bell.add_child(shape)
	for i in 5:
		var a := TAU * float(i) / 5.0
		SD.add_masonry_pile(root, Transform3D(Basis(Vector3.UP, a), BELL_POS + Vector3(cos(a) * 3.3, 0.3, sin(a) * 3.3)), game.mats.basalt, 330 + i, false)
	_target(sd, "bell_embedded", bell)
	_target(sd, "bell_crack", crack)
	root.set_meta("bell_crack", crack)
	_inspectable(game, root, "great_bell_embedded", Vector3(-1.6, 0, 13.0), "THE GREAT BELL OF VAELOR",
		"It came down the shaft with Malcor and buried its lip in the Kiln floor. The crack glows. Every so often it tolls on its own, and the racks answer.",
		"THE GREAT BELL — CRACKED, STILL TOLLING")


# =============================================================================
# Z3 — West Frozen Aqueduct
# =============================================================================

static func _aqueduct(game, root: Node3D, st: Dictionary) -> void:
	var sd: Object = _sd(game) if bool(root.get_meta("sd_bound", false)) else null
	L.slab(root, "aqueduct_floor", Rect2(-32, -18, 20.15, 36), 0, game.mats.stone)
	L.box(root, "aqueduct_outer_wall", Vector3(-32, 4.75, 0), Vector3(1, 9.5, 36), game.mats.basalt)
	L.box(root, "aqueduct_end_wall", Vector3(-22, 4.75, -18), Vector3(20, 9.5, 1), game.mats.basalt)
	L.box(root, "aqueduct_end_wall_s", Vector3(-24.65, 4.75, 18), Vector3(14.7, 9.5, 1), game.mats.basalt)
	var pool := Vector3(-22.1, 0.04, -2.2)
	L.box(root, "aqueduct_pool", pool, Vector3(16.4, 0.08, 22.8), game.mats.water, false)
	L.add_wet_zone(game, pool, Vector2(8.2, 11.4))
	L.slab(root, "valve_platform", Rect2(-28, -13, 8.5, 9.45), 3.02, game.mats.dark)
	for z: float in [-11.8, -3.7, 7.6]:
		L.vaulted_rib(root, Vector3(-22, 5.85, z), 18, 5.05, game.mats.stone, game.mats.brass)
	L.hanging_chain_lamp(game, root, Vector3(-22, 5.25, 7.6), 4.95, AQUEDUCT_LIGHT, 4.3, 11.5)
	L.iron_grate_floor(root, Vector3(-19.05, 0.08, 9.5), Vector2(2.8, 1.9), game.mats.iron)
	L.box(root, "aqueduct_outlet_header", Vector3(-25.03, 6.92, 2.6), Vector3(0.46, 0.46, 7.1), game.mats.iron, false)
	_frost_rime(game, root)
	var spouts: Array[Vector3] = [Vector3(-24.15, 0.47, 5.7), Vector3(-24.15, 1.23, 2.6), Vector3(-24.15, 1.99, -0.5)]
	for i in spouts.size():
		var pos := spouts[i]
		var spout := L.box(root, "water_spout_%d" % i, pos, Vector3(2.45, 0.5, 2.72), game.mats.water, true, L.LAYER_TARGET) as StaticBody3D
		var stream := L.cylinder(root, "water_stream_%d" % i, pos + Vector3(-0.88, 2.3, 0), 0.23, 4.6, game.mats.water, false, 10)
		spout.set_meta("water_spout", true)
		spout.set_meta("stream", stream)
		spout.set_meta("frozen_timer", 0.0)
		spout.set_meta("interact_hint", "WATER SPOUT — FREEZE WITH FROST [RMB] TO CLIMB")
		var mist := L.add_steam_jet(spout, Vector3(-0.62, 0.18, 0), Vector3(0.7, 0.6, 0.15), Color(0.75, 0.92, 1.0, 0.39))
		spout.set_meta("mist", mist)
		L.watch_puzzle(spout, func() -> void:
			var frozen: bool = float(spout.get_meta("frozen_timer")) > 0.0
			mist.emitting = not frozen
			spout.set_meta("interact_hint", "FROZEN FALL — CLIMB BEFORE IT THAWS" if frozen else "WATER SPOUT — FREEZE WITH FROST [RMB] TO CLIMB")
		)
		game.water_spouts.append(spout)
		game.shootable_targets.append(spout)
		game._light(pos + Vector3.UP * 0.85, Color("53c5e8"), 1.4, 5.5)
		var outlet := pos + Vector3(-0.88, 4.58, 0)
		var feed_height := 6.92 - outlet.y
		L.cylinder(root, "outlet_feed", outlet + Vector3.UP * (feed_height * 0.5), 0.2, feed_height, game.mats.iron, false, 10)
		L.cylinder(root, "outlet_flange", outlet, 0.35, 0.24, game.mats.brass, false, 10)
		L.focus_light(root, pos + Vector3(2.4, 4.65, 1.2), pos, AQUEDUCT_LIGHT, 3.75, 22.0, 0.8)
	var valve := Node3D.new()
	valve.name = "aqueduct_valve"
	valve.position = Vector3(-24.15, 3.02, -7.6)
	root.add_child(valve)
	L.cylinder(valve, "valve_post", Vector3(0, 0.65, 0), 0.25, 1.3, game.mats.iron, true, 10)
	var wheel := L.cylinder(valve, "valve_wheel", Vector3(0, 1.42, 0), 0.72, 0.16, game.mats.brass, false, 12)
	valve.set_meta("wheel", wheel)
	valve.set_meta("interact_hint", "AQUEDUCT VALVE — TURN [E] TO FLOOD THE QUENCH TROUGH")
	valve.get_node("valve_post").set_meta("interact_hint", valve.get_meta("interact_hint"))
	game.aqueduct_valve = valve
	_target(sd, "aqueduct_valve", valve)
	var pump := L.add_voltaic_conduit(game, Vector3(-19.05, 1.25, 7.25), "conduit_aqueduct", "Aqueduct Pump")
	pump.set_meta("powered", st.aqueduct_powered)
	pump.set_meta("interact_hint", "AQUEDUCT PUMP — STRIKE WITH THE FORK [4]")
	L.focus_light(root, Vector3(-16.75, 5.65, 7.9), pump.position, AQUEDUCT_LIGHT, 6.0, 23.0, 1.5)
	L.focus_light(root, Vector3(-26.2, 8.05, -9.75), valve.position + Vector3.UP * 1.35, AQUEDUCT_LIGHT, 4.9, 23.0, 0.62)
	game._inscription(Vector3(-21, 0, 8.4), "THE AQUEDUCT OF THE QUENCH", "\"Cold water makes a name hold its shape.\" — Kiln-Master Orrun")
	L.box(root, "secret_cistern_west_wall", Vector3(-30.25, 2.1, 14.5), Vector3(1, 4.2, 6.8), game.mats.dark)
	L.box(root, "secret_cistern_east_wall", Vector3(-24.7, 2.1, 14.5), Vector3(1, 4.2, 6.8), game.mats.dark)
	L.add_rotten_barricade(game, Vector3(-27.48, 1.2, 11.4), "kiln_secret_bar_1", Vector3(4.85, 2.4, 0.45), true)
	L.focus_light(root, Vector3(-28.7, 4.75, 9.6), Vector3(-27.48, 1.2, 11.4), AQUEDUCT_LIGHT, 2.15, 21.0)
	game._pickup(Vector3(-27.5, 0.85, 16.2), "relic_oath", "relic_cinder_oath")
	game._pickup(Vector3(-26.2, 0.55, 15.1), "flask", "kiln_secret_flask_1")
	game._inscription(Vector3(-29.0, 0, 13.4), "QUENCH-MASTERS' OATH", "An iron ring stamped WE WILL NOT POUR. Heavier than it looks.")
	_quench_masters(game, root, sd)
	_ilse_vessel(game, root, sd)
	_tithe_lectern(game, root, st, sd)
	var tube_aq := L.add_speaking_tube(root, "tube_aq", Vector3(-17.75, 0.0, 11.4), PI * 0.5, game.mats.brass, game.mats.iron)
	L.box(root, "tube_aq_post", Vector3(-17.95, 1.2, 11.4), Vector3(0.3, 2.4, 0.5), game.mats.basalt)
	var tube_valve := L.add_speaking_tube(root, "tube_valve", Vector3(-24.0, 3.02, -12.75), 0.0, game.mats.brass, game.mats.iron)
	L.box(root, "tube_valve_post", Vector3(-24.0, 4.2, -12.95), Vector3(0.5, 2.4, 0.3), game.mats.basalt)
	if sd != null:
		sd.call("register_tube", "tube_aq", tube_aq)
		sd.call("register_tube", "tube_valve", tube_valve)
	L.add_checkpoint_zone(game, Vector3(-15, 1.5, 10.2), Vector3(4, 3, 1.6), "kiln_aqueduct", "Frozen Aqueduct")
	game._enemy(Vector3(-17.1, 0, 1.6), false, "kiln_aq_shr", false, "shrieker")
	game._enemy(Vector3(-15.7, 0, -7.3), false, "kiln_aq_walkway_shr_n", false, "shrieker")
	game._enemy(Vector3(-14.6, 0, 6.1), false, "kiln_aq_walkway_shr_s", false, "shrieker")
	game._enemy(Vector3(-21.8, 3.02, -10.6), false, "kiln_aq_aco_1", false, "acolyte")
	game._pickup(Vector3(-25.7, 0.55, 8.65), "mana", "kiln_aq_spout_mana")


static func _frost_rime(_game, root: Node3D) -> void:
	var rime := _km(root, "rime")
	L.box(root, "frost_rime_outer", Vector3(-31.47, 4.0, 0), Vector3(0.04, 7.5, 34), rime, false)
	L.box(root, "frost_rime_north", Vector3(-22, 4.0, -17.47), Vector3(19, 7.5, 0.04), rime, false)
	var ice := _km(root, "ice_shell")
	for i in 9:
		var z := -0.8 + 0.85 * float(i)
		var h := 0.35 + 0.25 * float((i * 7) % 3)
		L.cone(root, "outlet_icicle", Vector3(-25.03, 6.69 - h * 0.5, z), 0.01, 0.09, h, ice, 5)


static func _quench_masters(game, root: Node3D, sd: Object) -> void:
	var holder := Node3D.new()
	holder.name = "tableau_quench_masters_refusal"
	root.add_child(holder)
	var ice := _km(root, "ice_shell")
	var zs: Array[float] = [9.0, 6.0, 3.0, 0.0]
	var drips: Array = []
	for i in zs.size():
		var base := Vector3(-27.5, 0.0, zs[i])
		# Stand the rig upright: the lying pose's legs (+Z) point down.
		var pose := Transform3D(Basis(Vector3.RIGHT, PI * 0.5).rotated(Vector3.UP, PI * 0.5), base + Vector3(0, 1.45, 0))
		SD.add_fallen_guard(holder, pose, "frozen_worker", game.mats)
		L.box(holder, "quench_master_ice", base + Vector3(0, 1.0, 0), Vector3(0.95, 2.05, 0.8), ice)
		L.box(holder, "quench_apron", base + Vector3(0.36, 0.95, 0), Vector3(0.06, 0.9, 0.5), game.mats.timber, false)
		L.cylinder(holder, "frozen_rake", base + Vector3(-0.9, 1.3, 0.3), 0.04, 2.6, game.mats.iron, false, 6)
		L.box(holder, "frozen_rake_head", base + Vector3(-0.9, 2.55, 0.3), Vector3(0.08, 0.1, 0.6), game.mats.iron, false)
		if i > 0:
			L.box(holder, "linked_hands", base + Vector3(0, 1.05, 1.5), Vector3(0.12, 0.12, 2.2), ice, false)
		var drip := L.add_steam_jet(holder, base + Vector3(0, 2.1, 0), Vector3(0, -1, 0), Color(0.75, 0.93, 1.0, 0.3))
		drip.amount = 8
		drip.scale = Vector3.ONE * 0.3
		drip.emitting = false
		drips.append(drip)
	var frost_valve := L.cylinder(holder, "frost_valve_wheel", Vector3(-27.5, 1.25, -1.3), 0.42, 0.1, ice, false, 12)
	frost_valve.rotation.x = PI * 0.5
	L.cylinder(holder, "frost_valve_post", Vector3(-27.5, 0.6, -1.3), 0.1, 1.2, game.mats.iron, false, 8)
	holder.set_meta("drips", drips)
	root.set_meta("quench_masters", holder)
	L.focus_light(root, Vector3(-25.0, 5.6, 4.5), Vector3(-27.5, 1.0, 4.5), Color("9fe6ff"), 3.0, 30.0, 0.5)
	SD.add_echo_wisp(game, Transform3D(Basis.IDENTITY, Vector3(-26.0, 0, 4.5)), "echo_quenchmaster", {
		"speaker": "QUENCH-MASTER — ECHO", "speaker_id": "echo", "color": "9fd8ff", "radius": 2.6,
		"title": "THE QUENCH-MASTERS' REFUSAL",
		"line": "Freeze it. Freeze the falls. They'll not pour the girl whole while there's breath in us.",
	})
	_target(sd, "quench_masters", holder)


static func _apply_meltwater(root: Node3D, on: bool) -> void:
	var holder: Variant = _meta(root, "quench_masters")
	if not is_instance_valid(holder) or not holder is Node3D:
		return
	for d: Variant in (holder as Node3D).get_meta("drips", []):
		if is_instance_valid(d) and d is GPUParticles3D:
			(d as GPUParticles3D).emitting = on


static func _ilse_vessel(game, root: Node3D, sd: Object) -> void:
	var pos := Vector3(-18.6, 0.06, -6.0)
	var vessel := Node3D.new()
	vessel.name = "ilse_vessel"
	vessel.position = pos
	vessel.rotation = Vector3(0, 0.4, PI * 0.5)
	root.add_child(vessel)
	L.cylinder(vessel, "vessel_iron_half", Vector3(0, -0.18, 0), 0.22, 0.42, game.mats.iron, false, 12)
	var glass := L.cylinder(vessel, "vessel_unpoured_half", Vector3(0, 0.2, 0), 0.22, 0.36, _translucent(Color("e6d5ff"), 0.45, Color("e6d5ff"), 0.9), false, 12)
	glass.rotation.y = 0.2
	var figure := MeshInstance3D.new()
	figure.name = "curled_figure_glow"
	var s := SphereMesh.new()
	s.radius = 0.09
	s.height = 0.22
	figure.mesh = s
	figure.material_override = _glow(Color("efe2ff"), 3.0)
	figure.position = Vector3(0, 0.2, 0)
	vessel.add_child(figure)
	L.box(root, "ilse_ice_bed", pos + Vector3(0, 0.03, 0), Vector3(1.6, 0.08, 1.1), _km(root, "ice_shell"), false)
	_label(root, "ilse_vessel_stamp", "VANT, ILSE — WITNESS — HAND-POUR", pos + Vector3(0.0, 0.42, 0.42), 26, 0.0034, Color("efe3ff"))
	_omni(root, pos + Vector3(0, 0.6, 0), Color("e6d5ff"), 1.4, 4.0)
	_hitbox(root, "ilse_vessel_hitbox", pos + Vector3(0, 0.2, 0), Vector3(0.9, 0.5, 0.6), "A VESSEL, HALF-POURED — \"VANT, ILSE — WITNESS\"")
	_inspectable(game, root, "ilse_vessel", pos + Vector3(1.0, -0.06, 0.6), "A VESSEL, HALF-POURED",
		"Stamped VANT, ILSE — WITNESS — HAND-POUR. Half of it is iron. The other half is still glass, and something curled inside it is still glowing.",
		"A VESSEL, HALF-POURED — \"VANT, ILSE — WITNESS\"")
	_target(sd, "ilse_vessel", vessel)


static func _tithe_lectern(game, root: Node3D, st: Dictionary, sd: Object) -> void:
	var pos := Vector3(-26.6, 3.02, -11.6)
	L.box(root, "tithe_lectern_post", pos + Vector3(0, 0.55, 0), Vector3(0.3, 1.1, 0.3), game.mats.timber)
	var desk := L.box(root, "tithe_lectern_desk", pos + Vector3(0, 1.15, 0), Vector3(0.9, 0.08, 0.6), game.mats.timber, false)
	desk.rotation.x = -0.35
	for x: float in [-0.21, 0.21]:
		var page := L.box(desk, "tithe_roll_page", Vector3(x, 0.05, 0), Vector3(0.4, 0.02, 0.52), _km(root, "ledger"), false)
		page.rotation.z = 0.06 if x < 0 else -0.06
	L.focus_light(root, pos + Vector3(0.6, 3.2, 1.4), pos + Vector3(0, 1.15, 0), Color("cfe9ff"), 2.6, 18.0, 0.3)
	_hitbox(root, "tithe_roll_hitbox", pos + Vector3(0, 1.2, 0), Vector3(1.0, 0.5, 0.8), "THE TITHE ROLL — READ [E]")
	var on_read := func() -> void:
		_mark_tithe_read(game, st)
	_inspectable(game, root, "tithe_roll", pos + Vector3(0.9, 0, 0.9), "THE TITHE ROLL", TITHE_ROLL_TEXT, "THE TITHE ROLL — READ [E]", on_read)
	_target(sd, "tithe_lectern", desk)


static func _mark_tithe_read(game, st: Dictionary) -> void:
	if bool(st.get("read_tithe_roll", false)):
		return
	st.read_tithe_roll = true
	if game.has_method("_story_event"):
		game._story_event("kiln_tithe_roll", "THE TITHE ROLL", "Seraphina's fair hand. Entry 1: VANT, ILSE — struck. Replaced by four Hesks. Below, Orrun's hand: the witness Ilse, hand-poured, by order.", "")


# =============================================================================
# Z4 — East Deep Smeltery
# =============================================================================

static func _smeltery(game, root: Node3D, st: Dictionary) -> void:
	var sd: Object = _sd(game) if bool(root.get_meta("sd_bound", false)) else null
	L.slab(root, "smeltery_rail_bed", Rect2(11.85, -18.5, 11.15, 36.5), 0, game.mats.basalt)
	L.slab(root, "smeltery_magma_bed", Rect2(23, -18.5, 9, 36.5), -0.65, game.mats.basalt)
	L.box(root, "smeltery_magma", Vector3(27.5, -0.49, -0.25), Vector3(9, 0.14, 36.5), game.mats.slag, false)
	game.slag_zones.append({"pos": Vector3(27.5, 0, 0), "half": Vector2(4.5, 18.25)})
	L.box(game.rising_slag_node, "smeltery_slag_rise", Vector3(27.5, 0, 0), Vector3(9, 0.14, 36), game.mats.slag, false)
	L.box(root, "smeltery_outer_wall", Vector3(32, 4.75, -0.25), Vector3(1, 9.5, 36.5), game.mats.basalt)
	L.box(root, "smeltery_end_wall", Vector3(22, 4.75, -18.5), Vector3(20, 9.5, 1.0), game.mats.basalt)
	L.box(root, "smeltery_end_wall_s", Vector3(24.65, 4.75, 18), Vector3(14.7, 9.5, 1.0), game.mats.basalt)
	L.slab(root, "smeltery_outer_catwalk", Rect2(28, -14.4, 3.6, 27.8), 0.45, game.mats.iron)
	for z: float in [-12.8, -4.7, 10.7]:
		_gantry(game, root, Vector3(23.45, 6.75, z), 16.1, 1.9)
		L.box(root, "smeltery_gantry_upright", Vector3(15.4, 3.4, z), Vector3(0.54, 6.8, 0.65), game.mats.iron, false)
		L.box(root, "smeltery_gantry_shoe", Vector3(15.4, 0.12, z), Vector3(0.92, 0.24, 0.96), game.mats.brass, false)
		L.hanging_chain_lamp(game, root, Vector3(26, 5.2, z), 1.1, FURNACE_LIGHT, 3.8, 11.0)
		_magma_vent(game, root, Vector3(31.46, 1.6, z))
	for z: float in [-10, 4, 13]:
		L.slab(root, "smeltery_crosswalk", Rect2(22.6, z - 1.55, 7.4, 3.1), 0.45, game.mats.iron)
		var deck_grate := L.iron_grate_floor(root, Vector3(26.35, 0.45, z), Vector2(2.42, 5.2), game.mats.iron)
		deck_grate.rotation.y = PI * 0.5
		game._light(Vector3(25, 1.3, z), Color("ff672e"), 2.2, 9)
	for x: float in [17.98, 19.82]:
		L.box(root, "ore_rail", Vector3(x, 0.06, -2.2), Vector3(0.12, 0.12, 20.7), game.mats.iron, false)
	var cart := RigidBody3D.new()
	cart.name = "heavy_ore_cart"
	cart.position = Vector3(18.9, 0.67, -9.4 if st.dam_broken else 5.5)
	cart.mass = 5.5
	cart.linear_damp = 0.12
	cart.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	var wheel_material := PhysicsMaterial.new()
	wheel_material.friction = 0.035
	wheel_material.rough = true
	cart.physics_material_override = wheel_material
	cart.axis_lock_linear_x = true
	cart.axis_lock_angular_x = true
	cart.axis_lock_angular_y = true
	cart.axis_lock_angular_z = true
	cart.collision_layer = L.LAYER_PUSHABLE
	cart.collision_mask = L.LAYER_WORLD | L.LAYER_ENEMY | L.LAYER_PUSHABLE | L.LAYER_PLAYER
	cart.continuous_cd = true
	cart.set_meta("ore_cart", true)
	cart.set_meta("impact_damage_owner", CHAPTER_ID)
	cart.set_meta("interact_hint", "ORE CART — FULL OF NAME-ASH — REPULSE [Q] DOWN THE RAILS INTO THE SLAG DAM")
	L.box(cart, "cart_body", Vector3.ZERO, Vector3(1.98, 1.16, 2.35), game.mats.iron, false)
	L.box(cart, "cart_ore", Vector3(0, 0.58, 0), Vector3(1.65, 0.35, 1.95), _km(root, "name_ash"), false)
	var glyphs := "AERNMSTHIOLW"
	for i in 8:
		var g := _label(cart, "name_ash_glyph", glyphs[i % glyphs.length()], Vector3(-0.6 + 0.17 * i, 0.78, -0.7 + 0.2 * float((i * 5) % 7)), 40, 0.005, Color(0.85, 0.78, 1.0, 0.7))
		g.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.98, 1.16, 2.35)
	collider.shape = shape
	cart.add_child(collider)
	root.add_child(cart)
	game.ore_cart = cart
	game.pushable_blocks.append(cart)
	var dam := L.box(root, "slag_dam", Vector3(18.9, 1.35, -10.55), Vector3(4.0, 2.7, 1.25), game.mats.cinder) as StaticBody3D
	dam.set_meta("interact_hint", "SLAG DAM — RAM IT WITH THE ORE CART")
	game.slag_dam = dam
	_target(sd, "slag_dam", dam)
	L.focus_light(root, Vector3(19.9, 6.45, -6.8), dam.position, FURNACE_LIGHT, 5.1, 25.0, 0.55)
	if st.dam_broken:
		dam.visible = false
		dam.collision_layer = 0
	L.box(root, "cart_rail_north_stop", Vector3(18.9, 0.72, -16.4), Vector3(3.2, 1.44, 0.9), game.mats.dark)
	L.box(root, "cart_rail_south_stop", Vector3(18.9, 0.5, 8.5), Vector3(3.2, 1, 0.88), game.mats.dark)
	_ash_chute(game, root)
	_ladle_crew(game, root)
	for p: Vector3 in [Vector3(21.8, 0, -4.7), Vector3(31.3, 0.45, 8.0)]:
		_sentinel_alcove(game, root, p, p.x > 30.0)
	var tube := L.add_speaking_tube(root, "tube_smelt", Vector3(17.75, 0.0, 11.4), -PI * 0.5, game.mats.brass, game.mats.iron)
	L.box(root, "tube_smelt_post", Vector3(17.95, 1.2, 11.4), Vector3(0.3, 2.4, 0.5), game.mats.basalt)
	if sd != null:
		sd.call("register_tube", "tube_smelt", tube)
	L.add_checkpoint_zone(game, Vector3(15, 1.5, 10.2), Vector3(4, 3, 1.6), "kiln_smeltery", "Deep Smeltery")
	L.add_explosive_cask(game, Vector3(16.1, 0, -2.5), "kiln_cask_smeltery")
	var dormant: bool = not bool(st.dam_broken)
	_spawn_enemy(game, Vector3(21.8, 0, -3.5), true, "kiln_smelt_ash", "ash_sentinel", dormant)
	_spawn_enemy(game, Vector3(29.9, 0.45, 8.5), true, "kiln_smelt_ash_east", "ash_sentinel", dormant)
	_spawn_enemy(game, Vector3(21.1, 0, -13), false, "kiln_smelt_stalker", "stalker", dormant)
	game._enemy(Vector3(18.9, 0, -2.0), false, "kiln_smelt_rail_shr", false, "shrieker")
	game._pot(Vector3(15.2, 0, -12.8), "kiln_pot_3", "mana")
	game._pickup(Vector3(22.1, 0.55, 10.7), "flask", "kiln_flask_1")


static func _ash_chute(game, root: Node3D) -> void:
	var top := Vector3(18.9, 9.5, 7.2)
	L.cylinder(root, "ash_chute_pipe", top + Vector3(0, 1.2, 0), 0.4, 2.4, game.mats.iron, false, 12)
	L.cone(root, "ash_chute_funnel", top + Vector3(0, -0.5, 0), 0.3, 1.1, 1.2, game.mats.iron, 12)
	_beam(root, "ash_chute_stream", top + Vector3(0, -1.1, 0), Vector3(18.9, 1.5, 5.8), 0.16, _km(root, "ash_stream"))
	var fall := L.add_steam_jet(root, top + Vector3(0, -1.2, 0), Vector3(0, -1, -0.15), Color(0.62, 0.58, 0.66, 0.4))
	fall.amount = 18
	fall.scale = Vector3.ONE * 0.45
	_omni(root, Vector3(18.9, 3.0, 6.4), Color("b9a2ff"), 1.4, 6.0)


static func _ladle_crew(game, root: Node3D) -> void:
	var holder := Node3D.new()
	holder.name = "tableau_ladle_crew"
	root.add_child(holder)
	var post_top := Vector3(12.5, 2.3, 3.0)
	L.cylinder(holder, "crew_rail_post", Vector3(12.5, 1.2, 3.0), 0.16, 2.4, game.mats.iron, true, 8)
	for i in 5:
		var z := 0.0 + 1.5 * float(i)
		var pose := Transform3D(Basis(Vector3.UP, PI * 0.5 + 0.18 * float(i - 2)), Vector3(13.4, 0.0, z))
		SD.add_fallen_guard(holder, pose, "collared_skeleton", game.mats)
		L.hanging_chain(holder, post_top, Vector3(13.2, 0.18, z), 0.05, game.mats.iron)
		var ladle := L.cylinder(holder, "crew_ladle_haft", Vector3(14.4, 0.06, z + 0.45), 0.035, 1.6, game.mats.iron, false, 6)
		ladle.rotation.z = PI * 0.5
		L.cylinder(holder, "crew_ladle_bowl", Vector3(15.2, 0.1, z + 0.45), 0.16, 0.12, game.mats.iron, false, 10)
	game._inscription(Vector3(12.6, 0, 7.4), "SMELTERY ROTA", "Night of the Third Bell — all hands to the ladle. Collared hands to be released at dawn. — O.")
	L.focus_light(root, Vector3(14.0, 5.0, 3.0), Vector3(13.4, 0.2, 3.0), FURNACE_LIGHT, 2.6, 34.0, 0.3)


static func _sentinel_alcove(game, root: Node3D, pos: Vector3, east: bool) -> void:
	var back := L.box(root, "sentinel_alcove_back", pos + Vector3(0, 2.2, 0), Vector3(0.4, 4.4, 2.4) if east else Vector3(2.4, 4.4, 0.4), game.mats.basalt, false)
	back.set_meta("interact_hint", "A SENTINEL ALCOVE — THE STATUE IS WARM")
	L.box(root, "sentinel_alcove_hood", pos + Vector3(0, 4.55, 0), Vector3(0.9, 0.4, 2.8) if east else Vector3(2.8, 0.4, 0.9), game.mats.brass, false)
	L.cylinder(root, "sentinel_alcove_plinth", pos + Vector3(-0.6 if east else 0.0, 0.1, 0.0 if east else 1.1), 0.9, 0.2, game.mats.basalt, false, 10)


## Return the dormant smeltery guards to play. Idempotent.
static func _wake_smeltery(game, root: Node3D, st: Dictionary, fx: bool) -> void:
	st.smelt_awake = true
	var dorm: Dictionary = root.get_meta("kiln_dormant", {})
	var i := 0
	for id: Variant in dorm.keys():
		var e: Variant = dorm[id]
		if not is_instance_valid(e) or not e is CharacterBody3D:
			continue
		var body := e as CharacterBody3D
		body.set_meta("dormant", false)
		if not game.enemies.has(body) and not st.dead.has(str(id)):
			game.enemies.append(body)
		if fx:
			Visuals.spawn_glyph_drift(root, body.global_position + Vector3.UP * 1.6, 10, 2.4, Color("e5dcff"))
			var narrative: Variant = game.get("narrative")
			if narrative is Object and is_instance_valid(narrative) and (narrative as Object).has_method("submit_bark") and i < 2:
				(narrative as Object).call("submit_bark", "whisper", "", "—pour—" if i == 0 else "—hold the shape—", body.global_position + Vector3.UP * 2.0, 1.5, 0.0)
		i += 1
	dorm.clear()


# =============================================================================
# Conduits (unchanged routes)
# =============================================================================

static func _foundry_conduits(game, root: Node3D, st: Dictionary) -> void:
	var bronze: Material = game._material(Color("9e6941"), true)
	var cyan: Material = game._material(AQUEDUCT_LIGHT, true)
	var amber: Material = game._material(FURNACE_LIGHT, true)
	var pump_route := PackedVector3Array([
		Vector3(-19.05, 0.08, 7.25), Vector3(-21.6, 0.08, 7.25), Vector3(-21.6, 0.08, -3.47),
		Vector3(-21.6, 3.02, -3.47), Vector3(-21.6, 3.02, -7.6), Vector3(-24.15, 3.02, -7.6),
	])
	var trough_route := PackedVector3Array([
		Vector3(-24.15, 3.02, -7.6), Vector3(-24.15, 3.02, -10.65), Vector3(-19.43, 3.02, -10.65),
		Vector3(-19.43, 0.08, -10.65), Vector3(-12.65, 0.08, -10.65), Vector3(-12.5, 0.29, -10.65),
		Vector3(-7.45, 0.29, -10.65), Vector3(-7.3, 0, -10.65), Vector3(-2.2, 0, -10.65),
		Vector3(-2.2, 0, -5), Vector3(-1.87, 0, -5),
	])
	var hoist_route := PackedVector3Array([
		Vector3(18.9, 0, -10.55), Vector3(12.65, 0, -10.55), Vector3(12.5, 0.29, -10.55),
		Vector3(7.45, 0.29, -10.55), Vector3(7.3, 0, -10.55), Vector3(3.55, 0, -10.55), Vector3(3.55, 0, -5),
	])
	var pump := L.add_floor_conduit(root, pump_route, bronze, cyan, 0.26)
	var trough := L.add_floor_conduit(root, trough_route, bronze, cyan, 0.26)
	var hoist := L.add_floor_conduit(root, hoist_route, bronze, amber, 0.26)
	root.set_meta("floor_conduits", {"aqueduct_pump": pump, "cooling_trough": trough, "slag_hoist": hoist})
	L.watch_puzzle(root, func() -> void:
		L.set_floor_conduit_powered(pump, st.aqueduct_powered)
		L.set_floor_conduit_powered(trough, st.trough_flooded)
		L.set_floor_conduit_powered(hoist, st.dam_broken)
	)


# =============================================================================
# Z6 — Gate Forecourt, S3 gallery, Ladle pit
# =============================================================================

static func _forecourt(game, root: Node3D) -> void:
	var sd: Object = _sd(game) if bool(root.get_meta("sd_bound", false)) else null
	L.slab(root, "gate_forecourt", Rect2(-13, -38.6, 26, 18.1), 0, game.mats.basalt)
	for x: float in [-12.8, 12.8]:
		L.box(root, "forecourt_side_wall", Vector3(x, 4.7, -29.4), Vector3(1.1, 9.4, 18.4), game.mats.basalt)
		L.box(root, "forecourt_south_wall", Vector3(x * 0.76, 4.7, -20.55), Vector3(6.7, 9.4, 0.9), game.mats.basalt)
		for z: float in [-25.5, -33.9]:
			L.cylinder(root, "forecourt_pillar", Vector3(x * 0.55, 3.05, z), 0.85, 6.1, game.mats.basalt, true, 12)
			game._torch(Vector3(x * 0.64, 2.9, z))
		_monumental_brazier(game, root, Vector3(signf(x) * 9.0, 0, -27.1))
	L.archway(root, "forecourt_entry_arch", Vector3(0, 0, -21.1), 13.1, 7.1, 1.55, game.mats.basalt, game.mats.brass)
	L.vaulted_rib(root, Vector3(0, 6.3, -28.1), 25.4, 8.5, game.mats.basalt, game.mats.brass)
	_gantry(game, root, Vector3(0, 9.18, -28.75), 24.6, 1.8)
	L.box(root, "forecourt_hoist_trolley", Vector3(0, 9.16, -28.75), Vector3(1.15, 0.52, 0.82), game.mats.brass, false)
	game._rune_circle(Vector3(0, 0, -30.8), 6.0)
	# The Ladle's slag pit.
	L.cylinder(root, "ladle_pit_slag", COLOSSUS_SPAWN + Vector3(0, 0.03, 0), 2.4, 0.05, game.mats.slag, false, 24)
	for i in 10:
		var a := TAU * float(i) / 10.0
		var stone := L.box(root, "ladle_pit_lip", COLOSSUS_SPAWN + Vector3(cos(a) * 2.6, 0.12, sin(a) * 2.6), Vector3(0.9, 0.24, 0.5), game.mats.basalt, false)
		stone.rotation.y = -a
	_omni(root, COLOSSUS_SPAWN + Vector3(0, 0.6, 0), Color("ff5c1a"), 2.0, 6.0)
	_target(sd, "ladle_pit", _marker(root, "ladle_pit", COLOSSUS_SPAWN))
	# S3 upper gallery (NPC-only) and the ladder that takes Seraphina there.
	L.slab(root, "forecourt_upper_gallery", Rect2(-12.25, -30, 1.45, 8), 5.5, game.mats.basalt, 0.35)
	L.box(root, "gallery_rail", Vector3(-10.85, 6.0, -26.0), Vector3(0.12, 1.0, 8.0), game.mats.iron, false)
	for z: float in [-29.4, -26.0, -22.6]:
		L.box(root, "gallery_corbel", Vector3(-11.6, 4.95, z), Vector3(1.3, 0.8, 0.4), game.mats.basalt, false)
	for z: float in [-22.2, -22.8]:
		L.box(root, "npc_ladder_rail", Vector3(-12.05, 2.75, z), Vector3(0.08, 5.5, 0.08), game.mats.timber, false)
	for i in 14:
		L.box(root, "npc_ladder_rung", Vector3(-12.05, 0.3 + 0.38 * float(i), -22.5), Vector3(0.06, 0.06, 0.6), game.mats.timber, false)
	game._light(Vector3(-11.6, 7.0, -26.0), Color("70d7df"), 1.2, 5.0)
	var vaelor: Texture2D = load("res://art/vaelor_mural.png") as Texture2D
	L.add_wall_mural(game, root, "vaelor_at_the_kiln", Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(12.2, 4.4, -29.4)), Vector2(6.0, 4.5), vaelor, null, {
		"title": "KING VAELOR AT THE KILN",
		"writing": "The King in a foundry apron, ladle raised, blessing a river of light. Beneath: \"HE GAVE HIS NAME FIRST, THAT OURS MIGHT FOLLOW.\" Someone has scratched out FIRST.",
		"glow": 0.12, "light_color": Color("ffd3a0"), "light_energy": 1.4, "anchor_offset": Vector3(0, -4.4, 2.2),
	})
	L.add_explosive_cask(game, Vector3(8.7, 0, -30.8), "kiln_guardian_cask")
	game._pickup(Vector3(-9.5, 0.55, -30.8), "flask", "kiln_guardian_flask")


# =============================================================================
# The Great Ashen Gate: doors, lock-plate, tympanum relief, Crown Vessel
# =============================================================================

static func _great_gate(game, root: Node3D, st: Dictionary) -> void:
	var sd: Object = _sd(game) if bool(root.get_meta("sd_bound", false)) else null
	L.slab(root, "ashen_threshold", Rect2(-7.1, -43, 14.2, 5), 0, game.mats.basalt)
	for x: float in [-9.7, 9.7]:
		L.box(root, "great_gate_jamb", Vector3(x, 5.15, -38), Vector3(6.45, 10.3, 1.9), game.mats.basalt)
		L.box(root, "threshold_side", Vector3(x * 0.731, 3, -40.5), Vector3(0.8, 6, 5.1), game.mats.basalt)
		L.gothic_buttress(root, Vector3(x * 1.21, 0, -37.05), 9.8, 2.4, game.mats.basalt, game.mats.iron)
		_monumental_brazier(game, root, Vector3(x * 1.04, 0, -34.0))
	L.focus_light(root, Vector3(0, 9.9, -33.5), Vector3(0, 2.4, -37.2), Color("f1c4ff"), 6.3, 28.0, 1.45)
	L.box(root, "great_gate_crown", Vector3(0, 9.1, -38), Vector3(14, 2.2, 1.9), game.mats.basalt)
	L.vaulted_rib(root, Vector3(0, 6.8, -36.85), 13, 5.2, game.mats.basalt, game.mats.brass)
	var left := L.box(root, "great_gate_left", Vector3(-3.3, 4, -38), Vector3(6.6, 8, 1), game.mats.iron) as StaticBody3D
	var right := L.box(root, "great_gate_right", Vector3(3.3, 4, -38), Vector3(6.6, 8, 1), game.mats.iron) as StaticBody3D
	for door: StaticBody3D in [left, right]:
		for y: float in [-2.8, 0, 2.8]:
			L.box(door, "gate_crossbrace", Vector3(0, y, 0.55), Vector3(6.3, 0.4, 0.17), game.mats.brass, false)
		for x: float in [-1.75, 0, 1.75]:
			L.box(door, "gate_rib", Vector3(x, 0, 0.6), Vector3(0.2, 8, 0.2), game.mats.dark, false)
	game.great_gate_left = left
	game.great_gate_right = right
	# Lock-plate with the Key-and-Fork mark, riding the left leaf's seam edge.
	var plate := L.box(left, "gate_lock_plate", Vector3(3.15, LOCK_PLATE.y - 4.0, 0.62), Vector3(0.9, 1.2, 0.12), game.mats.brass, false)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.24
	torus.outer_radius = 0.3
	ring.mesh = torus
	ring.material_override = game.mats.dark
	ring.rotation.x = PI * 0.5
	ring.position = Vector3(0, 0.15, 0.08)
	plate.add_child(ring)
	L.box(plate, "mark_key_shaft", Vector3(0, 0.15, 0.09), Vector3(0.05, 0.42, 0.03), game.mats.dark, false)
	L.box(plate, "mark_fork_tines", Vector3(0, 0.33, 0.09), Vector3(0.18, 0.05, 0.03), game.mats.dark, false)
	L.box(plate, "lock_keyhole", Vector3(0, -0.3, 0.08), Vector3(0.1, 0.24, 0.03), game.mats.portal, false)
	var lock_hit := _hitbox(plate, "lock_plate_hitbox", Vector3(0, 0, 0.1), Vector3(1.0, 1.3, 0.3), "THE GREAT ASHEN GATE — SEALED")
	root.set_meta("lock_plate_hitbox", lock_hit)
	_target(sd, "lock_plate", plate)
	if st.great_gate_open:
		left.position.x = -8.5
		right.position.x = 8.5
		left.collision_layer = 0
		right.collision_layer = 0
	var backstop := L.box(root, "ashen_threshold_backstop", Vector3(0, 4.7, -42.65), Vector3(14.0, 9.4, 0.55), game.mats.portal)
	_hide_mesh(backstop)
	game._light(Vector3(0, 3.65, -40.1), Color("ddc0ff"), 4.6, 12)
	_tympanum(game, root, sd)


static func _tympanum(game, root: Node3D, sd: Object) -> void:
	L.box(root, "gate_tympanum_wall", Vector3(0, 17.2, -39.35), Vector3(25.0, 14.0, 0.8), game.mats.basalt, false)
	for x: float in [-12.0, 12.0]:
		L.box(root, "tympanum_pier", Vector3(x, 17.2, -38.9), Vector3(1.2, 14.0, 1.6), game.mats.basalt, false)
	var art: Texture2D = load("res://art/choir_relief.png") as Texture2D
	var mural := L.add_wall_mural(game, root, "hollow_choir_relief", Transform3D(Basis.IDENTITY, Vector3(0, 15.6, -38.95)), Vector2(13.6, 10.2), art, null, {
		"title": "THE HOLLOW CHOIR",
		"writing": "Over the Gate the King's face is carved with its mouth open. The field around it is not ornament: it is names, three thousand and eleven of them, cut in rows too small to read from the floor.",
		"glow": 0.22, "light_color": Color("d9c6ff"), "light_energy": 2.4,
		"anchor_offset": Vector3(0, -15.6, 6.95),
	})
	root.set_meta("tympanum_mural", mural)
	_target(sd, "gate_tympanum", _marker(root, "gate_tympanum", Vector3(0, 15.6, -38.2)))
	# King Vaelor's Crown Vessel keystone.
	var key := Node3D.new()
	key.name = "crown_vessel_keystone"
	key.position = Vector3(0, 22.5, -38.15)
	root.add_child(key)
	L.box(key, "keystone_wedge", Vector3(0, 0, -0.1), Vector3(1.7, 2.3, 0.9), game.mats.basalt, false)
	var vessel := L.cylinder(key, "crown_vessel", Vector3(0, 0.05, 0.42), 0.45, 1.25, _km(root, "gold"), false, 14)
	L.cylinder(key, "crown_vessel_band", Vector3(0, 0.45, 0.42), 0.5, 0.12, game.mats.brass, false, 14)
	for i in 5:
		var a := -0.8 + 0.4 * float(i)
		var spike := L.cone(key, "crown_point", Vector3(sin(a) * 0.4, 0.95, 0.42 + cos(a) * 0.05), 0.08, 0.0, 0.42, game.mats.brass, 4)
		spike.rotation.z = -a * 0.4
	var crack := Node3D.new()
	crack.name = "crown_vessel_crack"
	crack.visible = false
	key.add_child(crack)
	_beam(crack, "crown_crack_seam", Vector3(0.1, 0.6, 0.88), Vector3(-0.15, -0.5, 0.88), 0.035, _km(root, "crown_crack"), 6)
	_beam(crack, "crown_crack_branch", Vector3(-0.02, 0.1, 0.88), Vector3(0.25, -0.3, 0.88), 0.025, _km(root, "crown_crack"), 6)
	var stamp := _label(key, "crown_vessel_stamp", "VAELOR", Vector3(0, -0.2, 0.9), 44, 0.006, GOLD_LIGHT)
	stamp.visible = false
	var crown_light := _omni(key, Vector3(0, 0, 1.4), GOLD_LIGHT, 0.0, 9.0)
	key.set_meta("crack", crack)
	key.set_meta("stamp", stamp)
	key.set_meta("light", crown_light)
	key.set_meta("vessel", vessel)
	root.set_meta("crown_vessel", key)
	_target(sd, "crown_vessel", key)


static func _apply_gate_turn_visuals(root: Node3D, turns: int) -> void:
	var level := clampf(1.0 - 0.3 * float(turns), 0.1, 1.0)
	for rack: Node3D in _racks(root):
		_set_rack_level(rack, level)
	var key: Variant = _meta(root, "crown_vessel")
	if is_instance_valid(key) and key is Node3D and turns >= 2:
		((key as Node3D).get_meta("crack") as Node3D).visible = true
		((key as Node3D).get_meta("stamp") as Label3D).visible = true
		((key as Node3D).get_meta("light") as OmniLight3D).light_energy = 3.2
	var mural: Variant = _meta(root, "tympanum_mural")
	if is_instance_valid(mural) and mural is Node3D:
		var mat := _meta((mural as Node3D), "art_material") as StandardMaterial3D
		if mat != null:
			mat.emission_energy_multiplier = 0.22 + 0.45 * float(turns)


static func _update_hoist_hint(game, root: Node3D, st: Dictionary) -> void:
	var lever: Variant = game.hoist_lever
	if not is_instance_valid(lever) or not lever is Node3D:
		return
	var hint := "CHAIN HOIST — FLOOD THE TROUGH AND BREAK THE SLAG DAM FIRST"
	if bool(st.key_forged) or root.has_meta("tempering"):
		hint = "CHAIN HOIST — THE KEY IS POURED"
	elif bool(st.trough_flooded) and bool(st.dam_broken):
		hint = "CHAIN HOIST — LOWER YOUR MOLD [E]"
	(lever as Node3D).set_meta("interact_hint", hint)
	var pedestal := (lever as Node3D).get_node_or_null("lever_pedestal")
	if pedestal != null:
		pedestal.set_meta("interact_hint", hint)


static func _update_lock_hint(game, root: Node3D, st: Dictionary) -> void:
	var hit: Variant = _meta(root, "lock_plate_hitbox")
	if not is_instance_valid(hit) or not hit is Node3D:
		return
	var hint := "THE GREAT ASHEN GATE — SEALED"
	if bool(st.get("great_gate_open", false)):
		hint = "THE GREAT ASHEN GATE — OPEN"
	elif not bool(game.has_ashen_key):
		hint = "LOCK-PLATE — YOUR MASTER'S MARK — THE KEY WAS NEVER POURED"
	elif not bool(st.get("colossus_dead", false)):
		hint = "LOCK-PLATE — THE LADLE GUARDS THE GATE"
	else:
		match int(st.get("gate_turns", 0)):
			0:
				hint = "TURN THE ASHEN KEY — MOON [E]"
			1:
				hint = "— CROWN [E]"
			_:
				hint = "— SKULL [E]"
	(hit as Node3D).set_meta("interact_hint", hint)


# =============================================================================
# The Hollow Beyond (non-colliding vista behind the Gate)
# =============================================================================

static func _hollow_beyond(game, root: Node3D, st: Dictionary) -> void:
	var sd: Object = _sd(game) if bool(root.get_meta("sd_bound", false)) else null
	var vista := Node3D.new()
	vista.name = "hollow_beyond_vista"
	root.add_child(vista)
	root.set_meta("hollow_beyond", vista)
	var basalt: Material = game.mats.basalt
	L.box(vista, "abyss_lip", Vector3(0, -0.6, -43.6), Vector3(14.2, 1.2, 1.2), basalt, false)
	for i in 7:
		var tooth := L.box(vista, "abyss_lip_broken", Vector3(-6.0 + 2.0 * float(i), -1.4 - 0.3 * float(i % 3), -44.4), Vector3(1.4, 1.6, 0.8), basalt, false)
		tooth.rotation.x = 0.2 * float(i % 2)
	L.box(vista, "sea_that_is_the_sky", Vector3(0, 24.0, -115.0), Vector3(170, 0.4, 150), _km(root, "black_water"), false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 30113011
	var lantern_mat := _km(root, "lantern")
	var stone: Material = game.mats.stone
	var lights := 0
	for i in 30:
		var x := rng.randf_range(-60.0, 60.0)
		if absf(x) < 6.0:
			x = 6.0 * signf(x + 0.01) + x
		var z := rng.randf_range(-58.0, -175.0)
		var h := rng.randf_range(7.0, 22.0)
		var w := rng.randf_range(3.0, 6.5)
		var house_top := 24.0
		L.box(vista, "inverted_house", Vector3(x, house_top - h * 0.5, z), Vector3(w, h, w * 0.8), stone if i % 3 else basalt, false)
		var rh := w * rng.randf_range(0.8, 1.6)
		var roof := L.cone(vista, "inverted_roof", Vector3(x, house_top - h - rh * 0.5, z), 0.03, w * 0.72, rh, game.mats.dark, 4)
		roof.rotation.y = PI * 0.25
		if i % 4 == 0:
			var spire_h := rng.randf_range(6.0, 12.0)
			L.cone(vista, "inverted_spire", Vector3(x, house_top - h - rh - spire_h * 0.5 + 0.4, z), 0.02, w * 0.25, spire_h, game.mats.dark, 6)
		for k in 2:
			L.box(vista, "upside_window", Vector3(x + w * 0.501 * (1.0 if k == 0 else -1.0), house_top - h * rng.randf_range(0.3, 0.8), z), Vector3(0.05, 0.9, 0.6), lantern_mat, false)
		var lantern_pos := Vector3(x + rng.randf_range(-1.0, 1.0), house_top - h - rh - rng.randf_range(0.8, 2.5), z)
		_beam(vista, "lantern_chain", lantern_pos + Vector3(0, 0.25, 0), lantern_pos + Vector3(0, rh * 0.6, 0), 0.03, game.mats.iron, 4)
		var lamp := MeshInstance3D.new()
		var orb := SphereMesh.new()
		orb.radius = 0.28
		orb.height = 0.56
		lamp.mesh = orb
		lamp.material_override = lantern_mat
		lamp.position = lantern_pos
		vista.add_child(lamp)
		if lights < 8 and i % 3 == 0:
			_omni(vista, lantern_pos, Color("ffcf8a"), 1.6, 9.0)
			lights += 1
	# The upturned Hesk raft rising toward the sea that is the sky.
	var raft := Node3D.new()
	raft.name = "hesk_raft_rising"
	raft.position = Vector3(7.0, -16.0, -82.0)
	raft.rotation = Vector3(0.1, 0.5, PI)
	vista.add_child(raft)
	for i in 6:
		L.box(raft, "raft_plank", Vector3(-1.25 + 0.5 * float(i), 0, 0), Vector3(0.44, 0.12, 3.4), game.mats.timber, false)
	L.box(raft, "raft_crossbar", Vector3(0, 0.1, 1.2), Vector3(3.2, 0.12, 0.2), game.mats.timber, false)
	L.box(raft, "raft_crossbar", Vector3(0, 0.1, -1.2), Vector3(3.2, 0.12, 0.2), game.mats.timber, false)
	var chalk := _label(raft, "raft_hesk_chalk", "HESK", Vector3(0, -0.08, 0), 64, 0.012, Color("e8e2d4"), 0.0)
	chalk.rotation.x = PI * 0.5
	_omni(raft, Vector3(0, 1.0, 0), Color("b9a8ff"), 0.8, 6.0)
	root.set_meta("hesk_raft", raft)
	# Floating stepping stones: Chapter IV's first path (no collision in Act I).
	for i in 14:
		var p := Vector3(sin(float(i) * 0.7) * 2.6, -0.5 - 0.32 * float(i), -45.6 - 3.1 * float(i))
		var s := L.box(vista, "floating_paving_stone", p, Vector3(1.7, 0.4, 1.4), basalt, false)
		s.rotation = Vector3(0.05 * float(i % 3), 0.3 * float(i), 0.04 * float(i % 2))
	var fog := FogVolume.new()
	fog.name = "hollow_beyond_fog"
	fog.size = Vector3(110, 50, 150)
	fog.position = Vector3(0, 0, -118)
	var fog_mat := FogMaterial.new()
	fog_mat.density = 0.035
	fog_mat.albedo = Color("b9a8ff")
	fog_mat.emission = Color("2a2140")
	fog_mat.edge_fade = 0.4
	fog.material = fog_mat
	vista.add_child(fog)
	_omni(vista, Vector3(0, 4.0, -50.0), Color("b9a8ff"), 2.2, 30.0)
	var bell_mark := _marker(vista, "underwater_bell", Vector3(0, -24.0, -120.0))
	var voice_mark := _marker(vista, "beyond_voice", Vector3(0, -1.5, -62.0))
	_target(sd, "underwater_bell", bell_mark)
	_target(sd, "beyond_voice", voice_mark)
	_target(sd, "hollow_beyond", vista)
	vista.visible = bool(st.great_gate_open)


static func _show_vista(root: Node3D, on: bool) -> void:
	var vista: Variant = _meta(root, "hollow_beyond")
	if not is_instance_valid(vista) or not vista is Node3D:
		return
	(vista as Node3D).visible = on
	if not on or not root.is_inside_tree() or root.has_meta("raft_rising"):
		return
	root.set_meta("raft_rising", true)
	var raft: Variant = _meta(root, "hesk_raft")
	if is_instance_valid(raft) and raft is Node3D:
		var r := raft as Node3D
		var tw := r.create_tween().set_loops()
		tw.tween_property(r, "position:y", 20.0, 140.0)
		tw.tween_property(r, "position:y", -16.0, 0.01)


# =============================================================================
# Archivist Seraphina
# =============================================================================

static func _seraphina(game, root: Node3D, st: Dictionary, sd: Object) -> void:
	var mark_id := str(st.story_world.seraphina_mark)
	var m: Dictionary = MARKS[mark_id]
	var lines: Array[String] = []
	if sd == null:
		for id: String in ["c3.ser.11", "c3.ser.12", "c3.ser.13"]:
			lines.append(str(LINES[id][1]))
	game._npc(m.pos, "seraphina", "seraphina_kiln", "Archivist Seraphina", lines, float(m.yaw))
	if game.npc_nodes.is_empty():
		return
	var entry: Dictionary = game.npc_nodes.back()
	var holder: Node3D = entry.node
	root.set_meta("seraphina_holder", holder)
	if sd == null:
		return
	# Director mode: she is an actor. The legacy NPC entry keeps animating her rig
	# and feeds the automap through a proxy, but [E] never hijacks a nearby
	# lever or the lock-plate because the proxy sits far below the floor.
	var proxy := _marker(root, "seraphina_map_proxy", holder.position + Vector3.DOWN * 60.0)
	entry.node = proxy
	entry.spoken = true
	entry["actor_holder"] = holder
	root.set_meta("seraphina_proxy", proxy)
	sd.call("register_actor", "seraphina", holder, entry.rig, {})
	for id: String in MARKS.keys():
		var mk: Dictionary = MARKS[id]
		sd.call("register_mark", id, mk.pos, float(mk.yaw))


static func _seraphina_at(_root: Node3D, mark_id: String, st: Dictionary) -> bool:
	return str((st.get("story_world", {}) as Dictionary).get("seraphina_mark", "")) == mark_id


# =============================================================================
# Story registration (StoryDirector)
# =============================================================================

static func _b(id: String, at: float, op: String, target: String = "", args: Dictionary = {}) -> Dictionary:
	return {"id": id, "at": at, "op": op, "target": target, "args": args}


static func _v(at: float, line_id: String, target: String = "", extra: Dictionary = {}) -> Dictionary:
	var spec: Array = LINES[line_id]
	var args := {"line": str(spec[1]), "speaker": str(spec[0]), "id": line_id, "duration": float(spec[2])}
	args.merge(extra, true)
	return {"id": line_id, "at": at, "op": "voice", "target": target, "args": args}


static func _commit(id: String, at: float, action: String, extra: Dictionary = {}) -> Dictionary:
	var args := {"action": action}
	args.merge(extra, true)
	return {"id": id, "at": at, "op": "commit", "args": args}


static func _rack_ids() -> Array:
	var ids: Array = ["fresh_rack"]
	for spec: Array in HALL_RACKS:
		ids.append(str(spec[0]))
	return ids


static func _hesk_planks_read(game) -> bool:
	var states: Variant = game.get("level_states")
	if states is Dictionary:
		for key: Variant in ["ch1_court", 0]:
			var s: Variant = (states as Dictionary).get(key, null)
			if s is Dictionary and bool((s as Dictionary).get("read_hesk_planks", false)):
				return true
	var flags: Variant = game.get("story_flags")
	if flags is Array:
		for f: String in ["read_hesk_planks", "inscription_hesk_planks", "inscription_the_hesk_planks", "ch1_court/hesk_planks"]:
			if (flags as Array).has(f):
				return true
	return false


static func _register_story(game, root: Node3D, st: Dictionary, sd: Object) -> void:
	var ser := "seraphina"
	var tube := {"channel": "tube"}
	var bell_args := {"mode": "local", "period": BELL_PERIOD, "loop_id": "kiln_bell", "pitch": 0.72, "pulse_vessels": _rack_ids(), "pulse_crack": "bell_crack"}
	var fast_args := bell_args.duplicate()
	fast_args.period = BELL_PERIOD_MELTDOWN
	var mark_s1 := func() -> bool: return _seraphina_at(root, "S1_rim", st)
	var rim_met := func() -> bool: return bool(st.rim_met)
	var can_descend := func() -> bool: return bool(st.trough_flooded) and bool(st.dam_broken) and _seraphina_at(root, "S1_rim", st)
	var descend_reconcile := func() -> void:
		st.story_world["seraphina_mark"] = "S2_hall"
	var wake_reconcile := func() -> void:
		_wake_smeltery(game, root, st, false)
	var can_temper := func() -> bool: return bool(st.trough_flooded) and bool(st.dam_broken) and not bool(st.key_forged)
	var temper_reconcile := func() -> void:
		_temper_reconcile(game, root, st)
	var meltdown_reconcile := func() -> void:
		st.story_world["seraphina_mark"] = "S3_gallery"
	var can_go_gate := func() -> bool: return bool(st.colossus_dead) and not bool(st.great_gate_open)
	var gate_reconcile := func() -> void:
		if not _seraphina_at(root, "S5_edge", st):
			st.story_world["seraphina_mark"] = "S4_gate"
	var unseal_reconcile := func() -> void:
		_act_complete(game, root, st, false)
	sd.call("register_mark", "ladle_fall", COLOSSUS_SPAWN + Vector3(0, 1.0, 0), 0.0)

	# --- commits -------------------------------------------------------------
	sd.call("register_commit", "kiln/checkpoint", func(p: Dictionary) -> void: _checkpoint(game, str(p.get("id", "")), str(p.get("label", ""))))
	sd.call("register_commit", "kiln/revelation", func() -> void: _revelation(game, root))
	sd.call("register_commit", "kiln/rim_objective", func() -> void:
		if not bool(st.trough_flooded) or not bool(st.dam_broken):
			game.labels.goal.text = "OBJECTIVE: FLOOD THE QUENCH TROUGH (WEST) · BREAK THE SLAG DAM (EAST)"
	)
	sd.call("register_commit", "kiln/meltwater", func() -> void: _apply_meltwater(root, true))
	sd.call("register_commit", "kiln/wake_smeltery", func() -> void: _wake_smeltery(game, root, st, true))
	sd.call("register_commit", "kiln/temper_lower", func() -> void: _temper_lower(game, root, false))
	sd.call("register_commit", "kiln/temper_quench", func() -> void: _temper_quench(game, root))
	sd.call("register_commit", "kiln/temper_hot_key", func() -> void: _spawn_hot_key(game, root, st))
	sd.call("register_commit", "kiln/temper_cooled", func() -> void: _cool_key(game, root, st))
	sd.call("register_commit", "kiln/meltdown_banner", func() -> void:
		_banner(game, "MELTDOWN — THE LADLE WAKES", Color("ff5c1a"))
		for x: float in [-5.5, 5.5]:
			if game.has_method("_spawn_fire_patch"):
				game._spawn_fire_patch(Vector3(x, 0.1, -22.6))
	)
	sd.call("register_commit", "kiln/ladle_chest", func() -> void:
		if is_instance_valid(game.boss):
			_open_ladle_chest(root, game.boss)
	)
	sd.call("register_commit", "kiln/slurry", func() -> void: _apply_colossus_fallen(game, root, st, true))
	sd.call("register_commit", "kiln/ash_reverse", func() -> void: _ash_reverse(root))
	sd.call("register_commit", "kiln/vessels_dark", func() -> void: _vessels_dark(root))
	sd.call("register_commit", "kiln/silence", func() -> void: _total_silence(game, root))
	sd.call("register_commit", "kiln/act_complete", func() -> void: _act_complete(game, root, st, true))

	# --- arrival, bell, rim meeting, the Revelation -----------------------------
	sd.call("register_sequence", {"id": SEQ_BELL, "once": false, "beats": [_b("toll", 0.0, "bell_toll", "bell_embedded", bell_args)]})
	sd.call("register_sequence", {"id": SEQ_BELL_FAST, "once": false, "beats": [_b("toll", 0.0, "bell_toll", "bell_embedded", fast_args)]})
	sd.call("register_sequence", {"id": SEQ_ARRIVAL, "once": true, "beats": [
		_b("furnace", 0.2, "foley", "", {"sound": "impact_deep", "pos": BELL_POS + Vector3(0, 2, 0), "pitch": 0.8, "max_dist": 60.0}),
		_b("ash_settle", 0.3, "dust", "", {"pos": ARRIVAL_POS + Vector3(0, 0.2, 0.6), "kind": "ash"}),
		_b("rim_fallback", 12.0, "chain", "", {"sequence": SEQ_RIM}),
	]})
	sd.call("register_sequence", {"id": SEQ_RIM, "once": true, "deadline": 30.0, "beats": [
		_b("turn", 0.0, "look_at", ser, {"at": "$player", "duration": 1.0}),
		_b("lantern", 0.0, "gesture", ser, {"name": "lantern_raise", "duration": 1.6}),
		_v(0.2, "c3.ser.01", ser), _v(3.9, "c3.ser.02", ser), _v(6.7, "c3.ser.03", ser), _v(9.2, "c3.ser.04", ser),
		_b("beckon", 9.2, "gesture", ser, {"name": "beckon", "duration": 1.4}),
		_commit("met", 9.2, "", {"state": {"rim_met": true}}),
		_b("vessels_fallback", 20.0, "chain", "", {"sequence": SEQ_VESSELS}),
	]})
	var streams: Array = []
	for id: String in ["rack_w0", "rack_w3", "rack_e0", "rack_e3"]:
		streams.append(_b("stream_" + id, 0.1, "name_stream", "", {"from": id, "to": "gate_tympanum", "duration": 3.0}))
	var vessel_beats: Array = [
		_b("look", 0.0, "await_look", "crucible_hall_center", {"cone_deg": 45.0, "timeout": 5.0}),
		_b("pulse", 0.05, "bell_toll", "bell_embedded", {"mode": "local", "pitch": 0.66, "pulse_vessels": _rack_ids(), "pulse_crack": "bell_crack"}),
		_commit("revelation", 0.05, "kiln/revelation"),
	]
	vessel_beats.append_array(streams)
	vessel_beats.append_array([
		_v(1.2, "c3.cho.01", "", {"origin": "rack_w1"}), _v(4.3, "c3.cho.02", "", {"origin": "gate_tympanum"}),
		_v(7.6, "c3.ser.05", ser), _v(13.3, "c3.ser.06", ser), _v(17.2, "c3.ser.07", ser), _v(20.7, "c3.ser.08", ser),
		_commit("seen", 7.6, "", {"state": {"vessels_seen": true}, "journal": {"id": "kiln_the_vessels", "title": "WHERE NAMES BECOME IRON",
			"body": "The racks hold name-vessels: every one a person from the lower ward. 3,011 of them. The Gate is made of them, and the fallen bell is still pouring new ones."}}),
		_b("brief", 25.6, "chain", "", {"sequence": SEQ_BRIEF}),
		_b("torin", 25.6, "chain", "", {"sequence": SEQ_TORIN}),
	])
	sd.call("register_sequence", {"id": SEQ_VESSELS, "once": true, "when": rim_met, "beats": vessel_beats})
	sd.call("register_sequence", {"id": SEQ_TORIN, "once": true, "when": mark_s1, "beats": [
		_b("look", 0.0, "await_look", "torin_vessel", {"cone_deg": 25.0, "timeout": 100000.0}),
		_v(0.05, "c3.ser.09", ser, {"when": mark_s1}), _v(1.6, "c3.ser.10", ser, {"when": mark_s1}),
	]})
	sd.call("register_sequence", {"id": SEQ_BRIEF, "once": true, "beats": [
		_b("point_w", 0.0, "gesture", ser, {"name": "point", "duration": 1.2}),
		_v(0.0, "c3.ser.11", ser), _v(5.1, "c3.ser.12", ser),
		_b("point_e", 5.1, "gesture", ser, {"name": "point", "duration": 1.2}),
		_v(10.2, "c3.ser.13", ser),
		_commit("objective", 10.2, "kiln/rim_objective"),
		_commit("checkpoint", 10.3, "kiln/checkpoint", {"payload": {"id": "kiln_landing", "label": "Foundry Rim"}}),
	]})

	# --- West: tube, Ilse, Tithe Roll, surge ----------------------------------
	sd.call("register_sequence", {"id": SEQ_TUBE_AQ, "once": true, "beats": [
		_v(0.0, "c3.ser.19", "", tube),
		_commit("checkpoint", 0.1, "kiln/checkpoint", {"payload": {"id": "kiln_aqueduct", "label": "Frozen Aqueduct"}}),
	]})
	sd.call("register_sequence", {"id": SEQ_ILSE, "once": true, "beats": [
		_v(0.0, "c3.ils.01", "", {"origin": "ilse_vessel"}), _v(3.1, "c3.ils.02", "", {"origin": "ilse_vessel"}),
		_commit("heard", 3.1, "", {"state": {"ilse_heard": true}, "journal": {"id": "kiln_ilse_sings", "title": "A VOICE IN THE ICE",
			"body": "A half-poured vessel in the frozen aqueduct, stamped VANT, ILSE — WITNESS. It sang: \"Sera...? Is that you on the stair?\""}}),
		_v(9.1, "c3.ser.14", "", tube),
	]})
	sd.call("register_sequence", {"id": SEQ_TITHE, "once": true, "beats": [_v(0.0, "c3.ser.15", "", tube), _v(3.5, "c3.ser.16", "", tube)]})
	sd.call("register_sequence", {"id": SEQ_SURGE, "once": true, "beats": [
		_b("wheel_turn", 0.0, "foley", "", {"sound": "lever", "pos": Vector3(-24.15, 4.2, -7.6)}),
		_b("trough_rush", 0.2, "foley", "", {"sound": "flood_rush", "pos": Vector3(0, 0.8, -5), "max_dist": 50.0}),
		_b("trough_mist", 0.2, "dust", "", {"pos": Vector3(0, 0.8, -5), "kind": "ash", "dir": Vector3.UP}),
		_b("high_water", 1.4, "foley", "", {"sound": "splash", "pos": Vector3(0, 0.8, -5), "pitch": 0.8}),
		_commit("meltwater", 1.4, "kiln/meltwater"),
		_b("descend", 1.6, "chain", "", {"sequence": SEQ_DESCEND}),
	]})

	# --- East: tube, dam break -------------------------------------------------
	sd.call("register_sequence", {"id": SEQ_TUBE_SMELT, "once": true, "beats": [
		_v(0.0, "c3.ser.17", "", tube), _v(4.5, "c3.ser.18", "", tube),
		_commit("checkpoint", 0.1, "kiln/checkpoint", {"payload": {"id": "kiln_smeltery", "label": "Deep Smeltery"}}),
	]})
	sd.call("register_sequence", {"id": SEQ_DAM, "once": true, "reconcile": wake_reconcile, "beats": [
		_b("dam_fracture", 0.0, "dust", "", {"pos": Vector3(18.9, 1.4, -10.4), "kind": "ash", "dir": Vector3(0, 0.6, -1)}),
		_b("rubble", 0.0, "foley", "", {"sound": "rubble", "pos": Vector3(18.9, 1.4, -10.4)}),
		_b("shake", 0.0, "shake", "", {"amount": 0.08, "pos": Vector3(18.9, 1.4, -10.4)}),
		_b("glyphs", 0.1, "glyph_drift", "", {"pos": Vector3(18.9, 2.6, -9.5), "count": 48, "duration": 20.0}),
		_b("slag_vent", 0.6, "slag_cascade", "", {"pos": Vector3(18.9, 0.6, -12.0), "sound": "slag_surge"}),
		_commit("wake", 1.2, "kiln/wake_smeltery"),
		_b("descend", 1.6, "chain", "", {"sequence": SEQ_DESCEND}),
	]})
	sd.call("register_sequence", {"id": SEQ_DESCEND, "once": true, "deadline": 70.0,
		"when": can_descend, "reconcile": descend_reconcile,
		"beats": [
			_b("walk", 0.0, "walk_to", ser, {"route": ["rim_w_exit", "w_stair_top", "w_stair_foot", "aq_bridge_approach", "bridge4_w", "bridge4_e", "hall_w_4"], "mark": "S2_hall", "speed": "stride"}),
			_b("hand_on_vessel", 52.0, "gesture", ser, {"name": "kneel", "duration": 2.0}),
		]})

	# --- Z5 tempering & confession --------------------------------------------
	var hesk := func() -> bool: return _hesk_planks_read(game)
	var temper_streams: Array = []
	for id: String in ["rack_w1", "rack_w2", "rack_e1", "rack_e2"]:
		temper_streams.append(_b("names_" + id, 2.2, "name_stream", "", {"from": id, "to": "key_spout", "duration": 2.0}))
	var temper_beats: Array = [
		_commit("lever", 0.0, "kiln/temper_lower"),
		_b("lower", 0.0, "move_body", "key_mold", {"end_pos": Vector3(0, 1.0, -5), "duration": 2.0, "cue": "lift"}),
		_b("pour", 2.2, "pour_stream", "key_spout", {"to": Vector3(0, 1.35, -5), "duration": 1.8, "sound": "slag_surge"}),
		_b("drop", 4.2, "move_body", "key_mold", {"end_pos": Vector3(0, 0.6, -5), "duration": 0.3, "ease": "in"}),
		_b("quench_hiss", 4.2, "foley", "", {"sound": "quench_hiss", "pos": Vector3(0, 0.8, -5), "max_dist": 45.0}),
		_commit("quench", 4.2, "kiln/temper_quench"),
		_commit("cooling", 4.5, "kiln/temper_hot_key"),
		_b("come_close", 5.0, "walk_to", ser, {"mark": "trough_west", "speed": "walk"}),
		_v(5.0, "c3.ser.20", ser), _v(6.9, "c3.ser.21", ser), _v(11.4, "c3.ser.22", ser), _v(15.3, "c3.ser.23", ser),
		_v(20.4, "c3.ser.24a", ser, {"flag": "read_tithe_roll"}), _v(20.45, "c3.ser.24b", ser, {"not_flag": "read_tithe_roll"}),
		_v(23.3, "c3.ser.24c", ser, {"when": hesk}),
		_v(23.35, "c3.ser.25", ser),
		_v(28.6, "c3.ser.26a", ser, {"flag": "ilse_heard"}), _v(28.65, "c3.ser.26b", ser, {"not_flag": "ilse_heard"}),
		_v(31.9, "c3.ser.27", ser), _v(36.4, "c3.ser.28", ser),
		_commit("cooled", 26.5, "kiln/temper_cooled"),
		_commit("confessed", 36.4, "", {"journal": {"id": "kiln_confession", "title": "\"I WROTE THEM\"",
			"body": "Seraphina compiled the Tithe Roll. She struck her sister Ilse from the first page and wrote in the Hesk family to keep the count. Ilse went down anyway and was hand-poured as a witness."}}),
	]
	temper_beats.append_array(temper_streams)
	sd.call("register_sequence", {"id": SEQ_TEMPER, "once": true, "deadline": 50.0,
		"when": can_temper, "reconcile": temper_reconcile,
		"beats": temper_beats})

	# --- Meltdown & the Ladle --------------------------------------------------
	sd.call("register_sequence", {"id": SEQ_MELTDOWN, "once": true, "deadline": 40.0,
		"reconcile": meltdown_reconcile,
		"beats": [
			_b("alarm", 0.0, "foley", "", {"sound": "alarm", "2d": true}),
			_b("alarm_2", 1.9, "foley", "", {"sound": "alarm", "2d": true}),
			_b("alarm_3", 3.8, "foley", "", {"sound": "alarm", "2d": true}),
			_b("bell_fast", 0.0, "bell_toll", "bell_embedded", fast_args),
			_b("overflow_w", 0.2, "slag_cascade", "", {"pos": Vector3(-5.5, 3.4, -21.1), "dir": Vector3.DOWN, "sound": "slag_surge"}),
			_b("overflow_e", 0.2, "slag_cascade", "", {"pos": Vector3(5.5, 3.4, -21.1), "dir": Vector3.DOWN, "sound": "slag_surge"}),
			_commit("guardians", 0.35, "kiln/meltdown_banner"),
			_b("run", 0.5, "walk_to", ser, {"route": ["hall_w_mid", "arch_w", "ladder_foot", "ladder_top"], "mark": "S3_gallery", "speed": "run"}),
			_v(0.5, "c3.ser.30", ser), _v(6.35, "c3.ser.31", ser),
		]})
	for id: String in INTEL_IDS:
		sd.call("register_sequence", {"id": "ch3_kiln/intel_" + id.get_slice(".", 2), "once": true, "beats": [_v(0.0, id, ser, {"priority": 2})]})
	sd.call("register_sequence", {"id": SEQ_OVERDRIVE, "once": true, "beats": [
		_b("anvil_overdrive", 0.0, "foley", "", {"sound": "impact_deep", "pos": COLOSSUS_SPAWN + Vector3(0, 2, 0)}),
		_b("shake", 0.0, "shake", "$boss", {"amount": 0.08}),
		_b("slag_burst", 0.2, "slag_cascade", "$boss", {"sound": "slag_surge"}),
		_commit("chest", 0.2, "kiln/ladle_chest"),
		_b("letters", 0.3, "glyph_drift", "$boss", {"count": 14, "duration": 3.0}),
		_v(0.6, "c3.ser.37", ser, {"priority": 2}),
	]})
	sd.call("register_sequence", {"id": SEQ_FALLS, "once": true, "deadline": 25.0, "beats": [
		_b("colossus_impact", 0.0, "foley", "", {"sound": "impact_deep", "mark": "ladle_fall", "max_dist": 60.0}),
		_b("dust", 0.0, "dust", "", {"mark": "ladle_fall", "kind": "ash"}),
		_b("shake", 0.0, "shake", "", {"amount": 0.1, "mark": "ladle_fall"}),
		_commit("slurry", 0.3, "kiln/slurry"),
		_b("slurry_stream", 0.4, "name_stream", "", {"from": "ladle_fall", "to": "gate_tympanum", "duration": 6.0, "color": "efe6ff"}),
		_b("bell_slow", 0.5, "bell_toll", "bell_embedded", bell_args),
		_v(1.0, "c3.cho.05", "", {"origin": "gate_tympanum"}),
		_v(4.8, "c3.ser.38", ser), _v(8.2, "c3.ser.39", ser),
		_commit("checkpoint", 8.2, "kiln/checkpoint", {"payload": {"id": "kiln_forecourt", "label": "Gate Forecourt"}}),
		_b("to_gate", 10.8, "chain", "", {"sequence": SEQ_TO_GATE}),
	]})
	sd.call("register_sequence", {"id": SEQ_TO_GATE, "once": true, "deadline": 40.0,
		"when": can_go_gate, "reconcile": gate_reconcile,
		"beats": [_b("walk", 0.0, "walk_to", ser, {"route": ["ladder_top", "ladder_foot", "forecourt_w"], "mark": "S4_gate", "speed": "walk"})]})
	sd.call("register_sequence", {"id": SEQ_CHOIR, "once": true, "beats": [
		_b("whisper_swell", 0.0, "foley", "", {"sound": "choir_whisper", "pos": Vector3(0, 4, -38.5), "max_dist": 40.0}),
		_b("whisper", 0.3, "bark", "", {"speaker": "whisper", "line": "—the quay—", "origin": Vector3(-3, 3, -38.5)}),
		_v(1.2, "c3.cho.06", "", {"origin": "gate_tympanum"}),
		_commit("journal", 1.2, "", {"journal": {"id": "hollow_choir", "title": "THE HOLLOW CHOIR",
			"body": "The voices behind the iron speak in unison: \"…key-maker… open the gate… give us back our names…\""}}),
	]})

	# --- The three turns -------------------------------------------------------
	var gate_streams: Array = []
	for id: String in ["rack_w0", "rack_w1", "rack_w2", "rack_w3", "rack_e0", "rack_e1", "rack_e2", "rack_e3"]:
		gate_streams.append(_b("lift_" + id, 0.1, "name_stream", "", {"from": id, "to": "gate_tympanum", "duration": 4.0}))
	var moon: Array = [
		_b("key_turn", 0.0, "foley", "", {"sound": "key_turn", "pos": LOCK_PLATE}),
		_b("iron_release", 0.35, "foley", "", {"sound": "iron_release", "pos": LOCK_PLATE}),
		_v(0.6, "c3.cho.07", "", {"origin": "gate_tympanum"}),
	]
	moon.append_array(gate_streams)
	sd.call("register_sequence", {"id": SEQ_TURN_MOON, "once": true, "beats": moon})
	sd.call("register_sequence", {"id": SEQ_TURN_CROWN, "once": true, "beats": [
		_b("key_turn", 0.0, "foley", "", {"sound": "key_turn", "pos": LOCK_PLATE}),
		_b("keystone", 0.3, "foley", "", {"sound": "iron_release", "pos": Vector3(0, 22.5, -38.0), "pitch": 1.25, "max_dist": 60.0}),
		_b("keystone_dust", 0.3, "dust", "", {"pos": Vector3(0, 22.0, -37.6), "kind": "ash", "dir": Vector3.DOWN}),
		_v(0.5, "c3.cho.08", "", {"origin": "gate_tympanum"}),
		_b("gasp", 3.0, "gesture", ser, {"name": "clutch_head", "duration": 1.5}),
		_v(3.0, "c3.ser.40", ser),
	]})
	sd.call("register_sequence", {"id": SEQ_UNSEAL, "once": true, "deadline": 40.0,
		"reconcile": unseal_reconcile,
		"beats": [
			_b("key_turn", 0.0, "foley", "", {"sound": "key_turn", "pos": LOCK_PLATE}),
			_b("gate_grind", 0.3, "foley", "", {"sound": "gate_grind", "pos": Vector3(0, 4, -38), "max_dist": 70.0}),
			_b("threshold_wind", 0.3, "wind_force", "", {"dir": Vector3(0, 0, -1), "accel": 1.5, "duration": 10.0}),
			_b("wind_gust", 0.6, "foley", "", {"sound": "wind_gust", "pos": Vector3(0, 2, -41)}),
			_commit("ash_reverse", 0.5, "kiln/ash_reverse"),
			_v(0.6, "c3.cho.09", "", {"origin": "gate_tympanum"}),
			_v(5.0, "c3.ils.03", "", {"origin": "beyond_voice"}),
			_v(7.8, "c3.ser.41", ser),
			_b("to_edge", 7.8, "walk_to", ser, {"route": ["gate_mouth"], "mark": "S5_edge", "speed": 0.9}),
			_b("lights_dim", 11.0, "torch_group", "", {"group": "kiln_all", "scale": 0.3, "duration": 1.2}),
			_v(11.0, "c3.vae.01", "", {"origin": "crown_vessel"}),
			_v(13.4, "c3.vae.02", "", {"origin": "crown_vessel"}),
			_v(17.2, "c3.vae.03", "", {"origin": "crown_vessel"}),
			_commit("vessels_dark", 21.0, "kiln/vessels_dark"),
			_b("bell_stop", 21.0, "stop_loop", "", {"loop_id": "kiln_bell"}),
			_commit("silence", 21.0, "kiln/silence"),
			_commit("act_complete", 22.5, "kiln/act_complete"),
		]})
	sd.call("register_sequence", {"id": SEQ_AFTERWORD, "once": true, "beats": [_v(0.0, "c3.ser.42", ser), _v(3.6, "c3.ser.43", ser)]})

	# --- story volumes -----------------------------------------------------------
	var s1: Vector3 = MARKS.S1_rim.pos
	sd.call("register_story_volume", _story_area(root, "story_rim_meeting", s1 + Vector3(0, 1.0, 0), Vector3.ZERO, 7.0), "rim_meeting", SEQ_RIM)
	sd.call("register_story_volume", _story_area(root, "story_rim_rail", Vector3(0, 7.5, 15.0), Vector3(20, 3, 2)), "rim_rail", SEQ_VESSELS)
	sd.call("register_story_volume", _story_area(root, "story_aq_stair_foot", Vector3(-15, 1.5, 11.6), Vector3(4, 3, 2.4)), "aq_stair_foot", SEQ_TUBE_AQ)
	sd.call("register_story_volume", _story_area(root, "story_smelt_stair_foot", Vector3(15, 1.5, 11.6), Vector3(4, 3, 2.4)), "smelt_stair_foot", SEQ_TUBE_SMELT)
	sd.call("register_story_volume", _story_area(root, "story_ilse_vessel", Vector3(-18.6, 1.0, -6.0), Vector3.ZERO, 4.5), "ilse_vessel", SEQ_ILSE)
	sd.call("register_story_volume", _story_area(root, "story_valve_deck", Vector3(-24, 4.5, -8.5), Vector3(8, 3, 9)), "valve_deck", SEQ_TITHE)
	sd.call("register_story_volume", _story_area(root, "story_hollow_choir", Vector3(0, 1.45, -35), Vector3(7.6, 3.2, 3.1)), "hollow_choir", SEQ_CHOIR)


# =============================================================================
# Set-piece effects (shared by director commits and legacy fallbacks)
# =============================================================================

static func _revelation(_game, root: Node3D) -> void:
	for rack: Node3D in _racks(root):
		_pulse_rack(rack, 3.2, 1.8)
	var mural: Variant = _meta(root, "tympanum_mural")
	if is_instance_valid(mural) and mural is Node3D and root.is_inside_tree():
		var mat := _meta((mural as Node3D), "art_material") as StandardMaterial3D
		if mat != null:
			var base := mat.emission_energy_multiplier
			var tw := root.create_tween()
			tw.tween_interval(0.9)
			tw.tween_property(mat, "emission_energy_multiplier", base + 2.8, 1.4)
			tw.tween_interval(1.0)
			tw.tween_property(mat, "emission_energy_multiplier", base, 1.6)
	Visuals.spawn_impact_light(root, Vector3(0, 0.6, -10), SOUL_LIGHT, 3.0, 30.0, 1.6)


static func _temper_lower(game, root: Node3D, animate_mold: bool) -> void:
	root.set_meta("tempering", true)
	game._sound_at("lever", Vector3(3.55, 1.0, -5))
	if is_instance_valid(game.hoist_lever):
		var arm: Variant = _meta(game.hoist_lever, "lever_arm")
		if arm is Node3D:
			(arm as Node3D).create_tween().tween_property(arm, "rotation:x", -0.5, 0.35)
	if animate_mold and is_instance_valid(game.key_mold):
		game._sound_at("lift", game.key_mold.global_position)
		game.key_mold.create_tween().tween_property(game.key_mold, "position:y", 1.0, 2.0).set_trans(Tween.TRANS_SINE)


static func _temper_pour_fallback(game, root: Node3D) -> void:
	var stream := _beam(root, "legacy_pour_stream", Vector3(0, 7.7, -5), Vector3(0, 1.35, -5), 0.12, game.mats.cinder)
	var tw := stream.create_tween()
	tw.tween_interval(1.8)
	tw.tween_callback(stream.queue_free)
	game._sound_at("slag_surge", Vector3(0, 1.4, -5))
	for id: String in ["rack_w1", "rack_e1"]:
		for rack: Node3D in _racks(root):
			if str(rack.get_meta("rack_id", "")) == id:
				Visuals.spawn_name_stream(root, rack.global_position + Vector3(0, 2.0, 0), Vector3(0, 7.7, -5), 2.0, SOUL_LIGHT)


static func _temper_quench(game, root: Node3D) -> void:
	if is_instance_valid(game.key_mold):
		game.key_mold.position.y = 0.6
	for i in 4:
		var a := TAU * float(i) / 4.0 + 0.4
		var jet := L.add_steam_jet(root, Vector3(cos(a) * 1.2, 0.8, -5 + sin(a) * 0.9), Vector3(cos(a) * 0.3, 1.0, sin(a) * 0.3), Color(0.95, 0.97, 1.0, 0.75))
		jet.amount = 40
		var tw := jet.create_tween()
		tw.tween_interval(2.6)
		tw.tween_callback(func() -> void: jet.emitting = false)
		tw.tween_interval(1.6)
		tw.tween_callback(jet.queue_free)
	if game.has_method("_shockwave"):
		game._shockwave(Vector3(0, 0.8, -5.0), Color("8ce8f5"), 4.2)
	Visuals.spawn_impact_light(root, Vector3(0, 1.4, -5), Color("e6f8ff"), 5.0, 12.0, 1.2)
	if game.get("camera_shake") is float:
		game.camera_shake = maxf(float(game.camera_shake), 0.12)


static func _key_mesh(parent: Node3D, mat: Material) -> void:
	L.box(parent, "key_shaft", Vector3(0, 0, 0), Vector3(0.1, 0.1, 0.9), mat, false)
	var bow := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.1
	torus.outer_radius = 0.17
	bow.mesh = torus
	bow.material_override = mat
	bow.rotation.x = PI * 0.5
	bow.position = Vector3(0, 0, 0.55)
	parent.add_child(bow)
	for i in 3:
		L.box(parent, "key_notch_%d" % i, Vector3(0, -0.08 - 0.04 * float(i), -0.3 + 0.12 * float(i)), Vector3(0.06, 0.1 + 0.04 * float(i), 0.08), mat, false)


static func _spawn_hot_key(game, root: Node3D, st: Dictionary) -> void:
	st.key_forged = true
	st.key_tempered_at = float(game.elapsed)
	root.set_meta("tempering", true)
	if is_instance_valid(game.key_mold):
		game.key_mold.visible = false
	if root.has_meta("hot_key"):
		return
	var hot := Node3D.new()
	hot.name = "ashen_key_tempering"
	hot.position = KEY_PICKUP
	hot.set_meta("too_hot", true)
	hot.set_meta("cool_at", float(game.elapsed) + KEY_COOL_TIME)
	root.add_child(hot)
	var mat := _glow(Color("ff3a10"), 4.0, Color("ff6a3a"))
	_key_mesh(hot, mat)
	var light := _omni(hot, Vector3(0, 0.3, 0), Color("ff5a20"), 3.0, 5.0)
	var steam := L.add_steam_jet(hot, Vector3(0, 0.25, 0), Vector3.UP, Color(0.9, 0.92, 0.95, 0.4))
	steam.amount = 12
	steam.scale = Vector3.ONE * 0.4
	_hitbox(hot, "hot_key_hitbox", Vector3.ZERO, Vector3(0.5, 0.4, 1.2), "THE ASHEN KEY — TEMPERING (TOO HOT)")
	var tw := hot.create_tween().set_parallel()
	tw.tween_property(mat, "emission", Color("5a2a1a"), KEY_COOL_TIME)
	tw.tween_property(mat, "emission_energy_multiplier", 0.5, KEY_COOL_TIME)
	tw.tween_property(mat, "albedo_color", Color("6a6a70"), KEY_COOL_TIME)
	tw.tween_property(light, "light_energy", 0.4, KEY_COOL_TIME)
	root.set_meta("hot_key", hot)
	game._objective()


static func _cool_key(game, root: Node3D, st: Dictionary) -> void:
	var hot: Variant = _meta(root, "hot_key")
	if is_instance_valid(hot) and hot is Node3D:
		(hot as Node3D).queue_free()
	root.remove_meta("hot_key")
	root.remove_meta("tempering")
	st.key_forged = true
	if not bool(game.has_ashen_key) and not st.taken.has("kiln_ashen_key") and not _key_pickup_present(game):
		game._pickup(KEY_PICKUP, "ashen_key", "kiln_ashen_key")
	_tag_key_pickup(game, false)
	_banner(game, "THE ASHEN KEY — TEMPERED", Color("ffd875"))
	_checkpoint(game, "kiln_hall", "Crucible Hall")
	game._objective()


static func _temper_reconcile(game, root: Node3D, st: Dictionary) -> void:
	st.key_forged = true
	if float(st.get("key_tempered_at", 0.0)) <= 0.0:
		st.key_tempered_at = float(game.elapsed) - KEY_COOL_TIME
	root.remove_meta("tempering")


static func _key_pickup_present(game) -> bool:
	for item: Dictionary in game.pickups:
		if str(item.get("id", "")) == "kiln_ashen_key" and is_instance_valid(item.get("node")):
			return true
	return false


static func _tag_key_pickup(game, hot: bool) -> void:
	for item: Dictionary in game.pickups:
		if str(item.get("id", "")) == "kiln_ashen_key":
			var node: Variant = item.get("node")
			if is_instance_valid(node) and node is Node3D:
				(node as Node3D).set_meta("too_hot", hot)
				(node as Node3D).set_meta("interact_hint", "THE ASHEN KEY — TEMPERING (TOO HOT)" if hot else "THE ASHEN KEY — TAKE [E]")


## Legacy main.gd forged the key instantly: still show it cooling for 22 s.
static func _legacy_hot_key(game, root: Node3D, st: Dictionary) -> void:
	if root.has_meta("hot_key"):
		return
	st.key_tempered_at = float(game.elapsed)
	_tag_key_pickup(game, true)
	root.set_meta("legacy_cool_at", float(game.elapsed) + KEY_COOL_TIME)
	for item: Dictionary in game.pickups:
		if str(item.get("id", "")) == "kiln_ashen_key" and is_instance_valid(item.get("node")):
			var light := _omni(item.node, Vector3(0, 0.3, 0), Color("ff5a20"), 3.0, 5.0)
			light.create_tween().tween_property(light, "light_energy", 0.0, KEY_COOL_TIME)
	_temper_quench(game, root)


## Pull the chain hoist. Returns "" when the tempering began, else a message for
## the player. main.gd calls this instead of forging the key instantly.
static func pull_hoist_lever(game) -> String:
	var root: Node3D = game.level_root
	var st := L.chapter_state(game)
	if bool(st.key_forged) or root.has_meta("tempering"):
		return "THE MOLD IS ALREADY POURED"
	if not bool(st.trough_flooded):
		return "COOLING TROUGH IS DRY — OPEN THE AQUEDUCT VALVE FIRST"
	if not bool(st.dam_broken):
		return "HOIST UNPOWERED — SEND THE ORE-CART THROUGH THE SLAG DAM"
	for e: CharacterBody3D in game.enemies:
		if is_instance_valid(e) and not bool(e.get_meta("boss", false)) and e.global_position.distance_to(Vector3(0, 0, -5)) < 14.0:
			return "CLEAR THE CRUCIBLE FLOOR BEFORE YOU POUR"
	var sd: Object = _sd_live(game, root)
	if sd != null and bool(sd.call("start_sequence", SEQ_TEMPER)):
		root.set_meta("tempering", true)
		return ""
	root.set_meta("tempering", true)
	_run_timeline(game, root, [
		[0.0, func() -> void: _temper_lower(game, root, true)],
		[2.2, func() -> void: _temper_pour_fallback(game, root)],
		[4.2, func() -> void: _temper_quench(game, root)],
		[4.5, func() -> void: _spawn_hot_key(game, root, st)],
		[5.0, func() -> void: _say_ids(game, ["c3.ser.20", "c3.ser.21", "c3.ser.22", "c3.ser.23", "c3.ser.24a" if bool(st.read_tithe_roll) else "c3.ser.24b", "c3.ser.25", "c3.ser.26a" if bool(st.ilse_heard) else "c3.ser.26b", "c3.ser.27", "c3.ser.28"])],
		[4.5 + KEY_COOL_TIME, func() -> void: _cool_key(game, root, st)],
	])
	return ""


static func _emerge(game, root: Node3D, ladle: CharacterBody3D) -> void:
	ladle.set_meta("emerge", {"depth": 4.0, "rise_time": 2.5, "fx": "slag"})
	ladle.set_meta("emerging", true)
	var rig: Variant = _meta(ladle, "rig")
	if rig is Node3D and root.is_inside_tree():
		var r := rig as Node3D
		var rest := r.position.y
		r.position.y = rest - 4.0
		var tw := r.create_tween()
		tw.tween_property(r, "position:y", rest, 2.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func() -> void:
			if is_instance_valid(ladle):
				ladle.set_meta("emerging", false)
		)
	Visuals.spawn_dust_burst(root, COLOSSUS_SPAWN + Vector3(0, 0.3, 0), Vector3.UP, "sparks", 3011)
	game._sound_at("slag_surge", COLOSSUS_SPAWN)


static func _open_ladle_chest(root: Node3D, ladle: Node3D) -> void:
	if not is_instance_valid(ladle) or ladle.has_meta("chest_glow"):
		return
	ladle.set_meta("chest_weakpoint", true)
	ladle.set_meta("chest_damage_mult", 1.5)
	var glow := MeshInstance3D.new()
	glow.name = "ladle_chest_names"
	var s := SphereMesh.new()
	s.radius = 0.55
	s.height = 1.1
	glow.mesh = s
	glow.material_override = _glow(Color("f4eeff"), 4.5)
	glow.position = Vector3(0, 3.1, -0.85)
	ladle.add_child(glow)
	var light := _omni(ladle, Vector3(0, 3.1, -1.4), Color("efe6ff"), 2.6, 6.0)
	ladle.set_meta("chest_glow", glow)
	ladle.set_meta("chest_light", light)


static func _apply_colossus_fallen(game, root: Node3D, st: Dictionary, live: bool) -> void:
	if is_instance_valid(game.rising_slag_node):
		game.rising_slag_node.set_meta("raised_y", -1.8)
		if not live:
			game.rising_slag_node.position.y = -1.8
	if root.has_meta("soul_slurry"):
		return
	var fall_pos: Vector3 = root.get_meta("ladle_fall_pos", COLOSSUS_SPAWN)
	var slurry := Node3D.new()
	slurry.name = "soul_slurry_flow"
	root.add_child(slurry)
	root.set_meta("soul_slurry", slurry)
	var mat := _glow(Color("e3d6ff"), 1.8, Color("f2ecff"))
	var a := Vector3(fall_pos.x, 0.03, fall_pos.z)
	var b := Vector3(0, 0.03, -37.4)
	var steps := 8
	for i in steps:
		var p := a.lerp(b, (float(i) + 0.5) / float(steps))
		var puddle := L.cylinder(slurry, "soul_slurry", p, lerpf(1.6, 0.5, float(i) / float(steps)), 0.03, mat, false, 16)
		puddle.scale = Vector3(1.0, 1.0, 1.6)
	_omni(slurry, a + Vector3(0, 0.6, 0), Color("e3d6ff"), 1.6, 6.0)
	if live and root.is_inside_tree():
		var tw := slurry.create_tween().set_loops()
		tw.tween_property(mat, "emission_energy_multiplier", 3.0, 1.2)
		tw.tween_property(mat, "emission_energy_multiplier", 1.2, 1.2)
		if not root.get_meta("sd_bound", false):
			Visuals.spawn_name_stream(root, a + Vector3(0, 0.5, 0), Vector3(0, 3, -38), 6.0, Color("efe6ff"))
			_checkpoint(game, "kiln_forecourt", "Gate Forecourt")


static func _ash_reverse(root: Node3D) -> void:
	var targets: Array[Vector3] = [Vector3(-8, 3, -24), Vector3(8, 3, -24), Vector3(-4, 4, -12), Vector3(4, 4, -12), Vector3(0, 6, -2), Vector3(0, 7, 14)]
	for p: Vector3 in targets:
		Visuals.spawn_name_stream(root, p, Vector3(0, 3.0, -44.0), 4.0, Color("bdb6c4"))
	Visuals.spawn_glyph_drift(root, Vector3(0, 3.0, -40.0), 24, 5.0, Color("e5dcff"))
	Visuals.spawn_impact_light(root, Vector3(0, 4.0, -40.0), Color("d8d2e8"), 4.0, 26.0, 4.0)


static func _vessels_dark(root: Node3D) -> void:
	for rack: Node3D in _racks(root):
		_set_rack_level(rack, 0.0)
		for lbl: Variant in (rack.get_meta("labels", {}) as Dictionary).values():
			if lbl is Label3D:
				(lbl as Label3D).modulate.a = 0.12
	var channel_mat := _km(root, "soul_channel") as StandardMaterial3D
	if channel_mat != null:
		channel_mat.emission_energy_multiplier = 0.0
	var crack_mat := _km(root, "bell_crack") as StandardMaterial3D
	if crack_mat != null:
		crack_mat.emission_energy_multiplier = 0.15


static func _total_silence(_game, root: Node3D) -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus < 0 or root.has_meta("silence_active"):
		return
	root.set_meta("silence_active", true)
	var prev := AudioServer.get_bus_volume_db(bus)
	AudioServer.set_bus_volume_db(bus, prev - 40.0)
	var tree := root.get_tree()
	if tree == null:
		AudioServer.set_bus_volume_db(bus, prev)
		return
	tree.create_timer(1.5, true).timeout.connect(func() -> void:
		AudioServer.set_bus_volume_db(bus, prev)
		if is_instance_valid(root):
			root.remove_meta("silence_active")
	)


static func _act_complete(game, root: Node3D, st: Dictionary, live: bool) -> void:
	st.gate_turns = 3
	st.great_gate_open = true
	if bool(st.act_complete):
		return
	st.act_complete = true
	st.story_world["seraphina_mark"] = "S5_edge"
	if game.has_method("_story_event"):
		game._story_event("ending", "ACT I COMPLETE — THE GREAT GATE UNSEALS",
			"Three turns of the key you were told never to pour: moon, crown, skull. The leaves opened on the Hollow Beyond, Ilse answered her sister, and a voice from the keystone called Caelen home. Chapter IV — The Hollow Beyond.", "")
	if not live:
		return
	if game.has_method("_win"):
		game._win()
		return
	var narrative: Variant = game.get("narrative")
	if narrative is Object and is_instance_valid(narrative):
		if (narrative as Object).has_method("show_act_complete_banner"):
			(narrative as Object).call("show_act_complete_banner")
		else:
			(narrative as Object).call("show_chapter", "CHAPTER IV", "THE HOLLOW BEYOND", "To be continued")
	if game.get("labels") is Dictionary and game.labels.has("goal"):
		game.labels.goal.text = "ACT I COMPLETE — [ESC] MENU"
	_checkpoint(game, "kiln_act_complete", "Act I Complete")


## Turn the Ashen Key in the lock-plate. Three separate presses (moon, crown,
## skull) at least 2.5 s apart; the player may walk away between them. Returns
## "" when a turn happened, else a message for the player.
static func turn_great_gate(game) -> String:
	var root: Node3D = game.level_root
	var st := L.chapter_state(game)
	if bool(st.great_gate_open):
		return "THE GREAT GATE STANDS OPEN"
	if not bool(game.has_ashen_key):
		return "THE GREAT GATE IS SEALED — TEMPER THE ASHEN KEY"
	if not bool(st.colossus_dead):
		return "THE LADLE STILL GUARDS THE GATE"
	var now := float(game.elapsed)
	if now - float(root.get_meta("gate_turn_at", -100.0)) < GATE_TURN_GAP:
		return "THE KEY RESISTS — LET THE IRON SETTLE"
	root.set_meta("gate_turn_at", now)
	var turn := int(st.gate_turns) + 1
	st.gate_turns = turn
	_apply_gate_turn_visuals(root, turn)
	var sd: Object = _sd_live(game, root)
	match turn:
		1:
			if sd != null:
				sd.call("start_sequence", SEQ_TURN_MOON)
			else:
				game._sound_at("lever", LOCK_PLATE)
				_say_ids(game, ["c3.cho.07"])
				for rack: Node3D in _racks(root):
					Visuals.spawn_name_stream(root, rack.global_position + Vector3(0, 2.2, 0), Vector3(0, 15.6, -38.2), 4.0, SOUL_LIGHT)
		2:
			if sd != null:
				sd.call("start_sequence", SEQ_TURN_CROWN)
			else:
				game._sound_at("lever", LOCK_PLATE)
				_say_ids(game, ["c3.cho.08", "c3.ser.40"])
		_:
			st.great_gate_open = true
			for door: Variant in [game.great_gate_left, game.great_gate_right]:
				if is_instance_valid(door) and door is StaticBody3D:
					(door as StaticBody3D).collision_layer = 0
			_show_vista(root, true)
			if sd != null:
				sd.call("start_sequence", SEQ_UNSEAL)
			else:
				game._sound_at("bell", Vector3(0, 4, -38), 0.55)
				_ash_reverse(root)
				_say_ids(game, ["c3.cho.09", "c3.ils.03", "c3.ser.41", "c3.vae.01", "c3.vae.02", "c3.vae.03"])
				var go_dark := func() -> void:
					_vessels_dark(root)
					_total_silence(game, root)
				var finish := func() -> void:
					_act_complete(game, root, st, true)
				_run_timeline(game, root, [[21.0, go_dark], [22.5, finish]])
	_update_lock_hint(game, root, st)
	game._objective()
	return ""


# =============================================================================
# Meltdown encounter (called by main.gd's _trigger_kiln_meltdown)
# =============================================================================

static func spawn_meltdown_encounter(game, from_restore: bool = false) -> void:
	var root: Node3D = game.level_root
	if root.has_meta("meltdown_spawned"):
		return
	root.set_meta("meltdown_spawned", true)
	var st := L.chapter_state(game)
	if not st.colossus_dead:
		var ladle := _spawn_enemy(game, COLOSSUS_SPAWN, true, COLOSSUS_ID, "colossus", false, true)
		if ladle != null:
			ladle.set_meta("display_name", COLOSSUS_NAME)
			if int(st.get("colossus_hp", COLOSSUS_HP)) <= COLOSSUS_HP / 2:
				_open_ladle_chest(root, ladle)
			if not from_restore:
				_emerge(game, root, ladle)
	_add_slag_cauldron(game, root, st, Vector3(0, 6.45, -28.75), "cauldron_colossus")
	game._enemy(Vector3(-6.5, 0, -27.2), true, "kiln_meltdown_ash", false, "ash_sentinel")
	game._enemy(Vector3(6.4, 0, -32.6), false, "kiln_meltdown_aco", false, "acolyte")
	if from_restore:
		return
	var sd: Object = _sd_live(game, root)
	if sd != null:
		sd.call("start_sequence", SEQ_MELTDOWN)
		sd.call("start_sequence", SEQ_BELL_FAST)
		root.set_meta("meltdown_started_at", float(game.elapsed))
	else:
		_banner(game, "MELTDOWN — THE LADLE WAKES", Color("ff5c1a"))


# =============================================================================
# Live driver: state transitions, cooling, impacts, intel, bells
# =============================================================================

static func _install_driver(game, root: Node3D, st: Dictionary) -> void:
	var driver := Node3D.new()
	driver.name = "kiln_story_driver"
	root.add_child(driver)
	var mem := {"t": float(game.elapsed), "bell_t": 0.0, "deep_bell_t": 6.0, "bark_t": -10.0, "idle": 0.0,
		"overdrive": int(st.colossus_hp) <= COLOSSUS_HP / 2, "boss_pos": COLOSSUS_SPAWN, "fill_t": 0.0}
	for key: String in ["trough_flooded", "dam_broken", "key_forged", "colossus_dead", "great_gate_open"]:
		mem[key] = bool(st.get(key, false))
	L.watch_puzzle(driver, func() -> void: _drive(game, root, st, mem))


static func _rose(mem: Dictionary, key: String, st: Dictionary) -> bool:
	var cur := bool(st.get(key, false))
	var was := bool(mem.get(key, cur))
	mem[key] = cur
	return cur and not was


static func _drive(game, root: Node3D, st: Dictionary, mem: Dictionary) -> void:
	if not is_instance_valid(root) or not root.is_inside_tree() or root != game.level_root:
		return
	var now := float(game.elapsed)
	var dt := clampf(now - float(mem.t), 0.0, 0.25)
	mem.t = now
	var sd: Object = _sd_live(game, root)
	if _rose(mem, "trough_flooded", st):
		_apply_meltwater(root, true)
		if sd != null:
			sd.call("start_sequence", SEQ_SURGE)
	if _rose(mem, "dam_broken", st):
		_wake_smeltery(game, root, st, sd == null)
		if sd != null:
			sd.call("start_sequence", SEQ_DAM)
		else:
			Visuals.spawn_glyph_drift(root, Vector3(18.9, 2.6, -9.5), 40, 20.0, Color("e5dcff"))
	if _rose(mem, "key_forged", st) and not root.has_meta("tempering") and not root.has_meta("hot_key"):
		_legacy_hot_key(game, root, st)
	if root.has_meta("legacy_cool_at") and now >= float(root.get_meta("legacy_cool_at")):
		root.remove_meta("legacy_cool_at")
		_tag_key_pickup(game, false)
	if not bool(st.read_tithe_roll) and game.story_flags.has("inscription_the_tithe_roll"):
		_mark_tithe_read(game, st)
	if not bool(st.ilse_heard) and sd == null and game.story_flags.has("inscription_a_vessel,_half-poured"):
		st.ilse_heard = true
	_cart_impacts(game)
	_drive_ladle(game, root, st, mem, sd, now)
	if _rose(mem, "colossus_dead", st):
		var fall_pos: Vector3 = root.get_meta("ladle_fall_pos", mem.boss_pos)
		root.set_meta("ladle_fall_pos", fall_pos)
		if sd != null:
			sd.call("register_mark", "ladle_fall", fall_pos + Vector3.UP, 0.0)
			sd.call("start_sequence", SEQ_FALLS)
		else:
			_apply_colossus_fallen(game, root, st, true)
	if _rose(mem, "great_gate_open", st):
		st.gate_turns = 3
		_show_vista(root, true)
		_apply_gate_turn_visuals(root, 3)
	if sd == null and not bool(st.act_complete):
		_legacy_bell(game, root, st, mem, dt)
	_deep_bell(game, root, st, mem, dt)
	var proxy: Variant = _meta(root, "seraphina_proxy")
	var holder: Variant = _meta(root, "seraphina_holder")
	if is_instance_valid(proxy) and is_instance_valid(holder) and proxy is Node3D and holder is Node3D:
		(proxy as Node3D).position = (holder as Node3D).position + Vector3.DOWN * 60.0
	_update_lock_hint(game, root, st)
	_update_hoist_hint(game, root, st)
	_animate_filling_mold(root, mem, dt)
	if sd != null and bool(st.act_complete) and is_instance_valid(holder) and holder is Node3D:
		if game.player.global_position.distance_to((holder as Node3D).global_position) < 8.0:
			mem.idle = float(mem.idle) + dt
			if float(mem.idle) >= 30.0:
				sd.call("start_sequence", SEQ_AFTERWORD)


## E23 (chapter-local): a runaway cart above 6 m/s deals 120 to each foe it hits once.
static func _cart_impacts(game) -> void:
	var cart: Variant = game.ore_cart
	if not is_instance_valid(cart) or not cart is RigidBody3D:
		return
	var body := cart as RigidBody3D
	if body.linear_velocity.length() <= 6.0:
		return
	for e: CharacterBody3D in game.enemies.duplicate():
		if not is_instance_valid(e) or bool(e.get_meta("cart_hit", false)):
			continue
		if e.global_position.distance_to(body.global_position) < 1.9:
			e.set_meta("cart_hit", true)
			e.set_meta("stagger", 0.6)
			game._damage_enemy(e, 120)
			_banner(game, "ORE-CART CRUSH!", Color("ff7832"))


static func _drive_ladle(game, root: Node3D, st: Dictionary, mem: Dictionary, sd: Object, now: float) -> void:
	var boss: Variant = game.boss
	if not is_instance_valid(boss) or not boss is CharacterBody3D or str((boss as Node).get_meta("kind", "")) != "colossus":
		return
	var ladle := boss as CharacterBody3D
	mem.boss_pos = ladle.global_position
	var hp := int(ladle.get_meta("hp", COLOSSUS_HP))
	if hp <= COLOSSUS_HP / 2 and not bool(mem.overdrive):
		mem.overdrive = true
		_open_ladle_chest(root, ladle)
		if sd != null:
			sd.call("start_sequence", SEQ_OVERDRIVE)
	if bool(mem.overdrive) and float(ladle.get_meta("hit_flash", 0.0)) > 0.4 and now - float(mem.bark_t) >= 4.0:
		mem.bark_t = now
		var narrative: Variant = game.get("narrative")
		if narrative is Object and is_instance_valid(narrative) and (narrative as Object).has_method("submit_bark"):
			var line := LADLE_BARKS[int(now * 7.0) % LADLE_BARKS.size()]
			(narrative as Object).call("submit_bark", "whisper", "", line, ladle.global_position + Vector3.UP * 3.4, 1.5, 4.0)
		Visuals.spawn_glyph_drift(root, ladle.global_position + Vector3.UP * 3.0, 6, 1.6, Color("efe6ff"))
	if sd == null or now - float(root.get_meta("meltdown_started_at", now)) < 9.0:
		return
	# Seraphina's one-shot tactical intel from the gallery.
	for bolt: Dictionary in game.bolts:
		if str(bolt.get("kind", "")) == "frost" and is_instance_valid(bolt.get("node")):
			if (bolt.node as Node3D).global_position.distance_to(ladle.global_position + Vector3.UP * 2.0) < 3.6:
				sd.call("start_sequence", "ch3_kiln/intel_32")
	var flat := Vector2(ladle.global_position.x, ladle.global_position.z - (-28.75)).length()
	if flat < 3.0 and not (st.dropped_cauldrons as Array).has("cauldron_colossus"):
		sd.call("start_sequence", "ch3_kiln/intel_33")
	if str(ladle.get_meta("pending", "")) == "tolling_wave":
		sd.call("start_sequence", "ch3_kiln/intel_34")
	var held: Variant = game.held_body
	if is_instance_valid(held) and held is Node and bool((held as Node).get_meta("explosive_cask", false)):
		sd.call("start_sequence", "ch3_kiln/intel_35")
	if int(game.hp) > 0 and int(game.hp) < 30:
		sd.call("start_sequence", "ch3_kiln/intel_36")


static func _legacy_bell(game, root: Node3D, st: Dictionary, mem: Dictionary, dt: float) -> void:
	var period := BELL_PERIOD_MELTDOWN if bool(st.gauntlet_triggered) and not bool(st.colossus_dead) else BELL_PERIOD
	mem.bell_t = float(mem.bell_t) + dt
	if float(mem.bell_t) < period:
		return
	mem.bell_t = 0.0
	game._sound_at("bell", BELL_POS + Vector3(0, 2.5, 0), 0.72)
	for rack: Node3D in _racks(root):
		_pulse_rack(rack, 1.8, 1.1)
	Visuals.spawn_impact_light(root, BELL_POS + Vector3(0, 2.5, 0), Color("ffd38a"), 2.0, 14.0, 0.6)


static func _deep_bell(game, root: Node3D, st: Dictionary, mem: Dictionary, dt: float) -> void:
	if not bool(st.great_gate_open) or root.has_meta("silence_active"):
		return
	mem.deep_bell_t = float(mem.deep_bell_t) + dt
	if float(mem.deep_bell_t) < BELL_PERIOD:
		return
	mem.deep_bell_t = 0.0
	game._sound_at("underwater_bell", Vector3(0, -24.0, -120.0), 0.9)


static func _animate_filling_mold(root: Node3D, mem: Dictionary, dt: float) -> void:
	var lbl: Variant = _meta(root, "filling_label")
	if not is_instance_valid(lbl) or not lbl is Label3D:
		return
	mem.fill_t = float(mem.fill_t) + dt
	if float(mem.fill_t) < 0.9:
		return
	mem.fill_t = 0.0
	var frames: Array[String] = ["· · ·", "M · ·", "MA· ·", "MAR· ·", "MAR·N", "· A · N", "· · · ·", "E · · ·", "EL· · ·", "· · ·"]
	var i := (int(mem.get("fill_i", 0)) + 1) % frames.size()
	mem.fill_i = i
	(lbl as Label3D).text = frames[i]


# =============================================================================
# Shared props
# =============================================================================

static func _gantry(game, root: Node3D, pos: Vector3, span: float, rise: float) -> void:
	var truss := Node3D.new()
	truss.name = "foundry_gantry"
	truss.position = pos
	root.add_child(truss)
	for y: float in [0.0, rise]:
		L.box(truss, "truss_chord", Vector3(0, y, 0), Vector3(span + 0.32, 0.27, 0.48), game.mats.iron, false)
	var bay := span * 0.25
	for i in 4:
		var x := -span * 0.5 + bay * (float(i) + 0.5)
		var dy := rise if i % 2 == 0 else -rise
		var brace := L.box(truss, "angle_iron_brace", Vector3(x, rise * 0.5, 0), Vector3(Vector2(bay, rise).length(), 0.24, 0.33), game.mats.iron, false)
		brace.rotation.z = atan2(dy, bay)
	for x: float in [-span * 0.5, span * 0.5]:
		L.box(truss, "end_stanchion", Vector3(x, rise * 0.5, 0), Vector3(0.4, rise + 0.2, 0.55), game.mats.iron, false)
		for y: float in [0, rise]:
			L.box(truss, "gusset_plate", Vector3(x, y, 0.27), Vector3(0.67, 0.4, 0.08), game.mats.brass, false)


static func _magma_vent(game, root: Node3D, pos: Vector3) -> void:
	var vent := Node3D.new()
	vent.name = "magma_wall_vent"
	vent.position = pos
	root.add_child(vent)
	L.box(vent, "vent_frame", Vector3.ZERO, Vector3(0.34, 1.48, 2.98), game.mats.iron, false)
	L.box(vent, "glowing_magma", Vector3(-0.17, 0, 0), Vector3(0.09, 0.93, 2.5), game.mats.slag, false)
	for i in 7:
		L.box(vent, "vent_louver", Vector3(-0.25, 0, (i - 3) * 0.34), Vector3(0.12, 1.08, 0.12), game.mats.iron, false)
	L.focus_light(vent, Vector3(-0.36, 0.1, 0), Vector3(-3.9, -0.9, 0), Color("ff5926"), 4.7, 38.0, 0.5)


static func _monumental_brazier(game, root: Node3D, pos: Vector3) -> void:
	var brazier := Node3D.new()
	brazier.name = "processional_brazier"
	brazier.position = pos
	root.add_child(brazier)
	L.cylinder(brazier, "basalt_plinth", Vector3.UP * 0.24, 1.1, 0.48, game.mats.basalt, false, 8)
	L.cone(brazier, "pedestal", Vector3.UP * 1.65, 0.78, 0.49, 2.45, game.mats.basalt, 8)
	L.cylinder(brazier, "capital_ring", Vector3.UP * 2.8, 0.7, 0.23, game.mats.brass, false, 8)
	L.cone(brazier, "iron_fire_bowl", Vector3.UP * 3.18, 0.53, 1.16, 0.65, game.mats.iron, 12)
	L.cylinder(brazier, "brazier_rim", Vector3.UP * 3.51, 1.19, 0.16, game.mats.brass, false, 12)
	L.cylinder(brazier, "molten_coals", Vector3.UP * 3.59, 1.02, 0.13, game.mats.slag, false, 12)
	var flame := MeshInstance3D.new()
	flame.name = "brazier_flame"
	var quad := QuadMesh.new()
	quad.size = Vector2(2.35, 2.7)
	flame.mesh = quad
	flame.material_override = game.mats.flame
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.position.y = 4.74
	brazier.add_child(flame)
	var light: OmniLight3D = game._light(pos + Vector3.UP * 4.12, FURNACE_LIGHT, 6.1, 14.0)
	light.light_volumetric_fog_energy = 0.48


static func _add_slag_cauldron(game, root: Node3D, st: Dictionary, pos: Vector3, id: String) -> void:
	if st.dropped_cauldrons.has(id):
		return
	var pot := L.cylinder(root, id, pos, 1.05, 1.22, game.mats.iron, false, 14)
	L.cylinder(pot, "slag_inside_cauldron", Vector3.UP * 0.58, 0.92, 0.15, game.mats.slag, false, 14)
	var chain := L.cylinder(root, id + "_chain", pos + Vector3.UP * 1.64, 0.33, 2.2, game.mats.brass, true, 10, L.LAYER_TARGET)
	chain.set_meta("cauldron_chain", true)
	chain.set_meta("interact_hint", "CAULDRON CHAIN — SHOOT TO DROP THE SLAG CAULDRON")
	chain.set_meta("cauldron", pot)
	chain.set_meta("id", id)
	game.shootable_targets.append(chain)
	game._light(pos + Vector3.DOWN * 0.16, Color("ff7832"), 2.1, 7)
