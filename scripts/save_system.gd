class_name SaveSystem
extends RefCounted

const CHECKPOINT_PATH := "user://ashen_gate_checkpoint.json"
const QUICKSAVE_PATH := "user://ashen_gate_save.json"
const SETTINGS_PATH := "user://ashen_gate_settings.json"
const SCHEMA_VERSION := 2
const CHAPTER_IDS := ["ch1_court", "ch2_tower", "ch3_kiln"]
const DIFFICULTIES := ["Story", "Cinder-Breaker", "Torment"]
const DEFAULT_SETTINGS := {
	"mouse_sens": 1.0,
	"difficulty": "Cinder-Breaker",
	"volumetric_fog": true,
	"ssr": true,
	"ssao": true,
	"msaa": true,
}

const WEAPON_AND_KEY_FIELDS := ["has_arbalest", "has_thurible", "has_voltaic", "has_ashen_key"]
const STAT_DEFAULTS := {
	"hp": 100,
	"max_hp": 100,
	"mana": 75,
	"max_mana": 100,
	"green_mana": 45,
	"damage_mult": 1.0,
	"mana_regen_rate": 0.0,
	"flasks": 2,
	"mode": 0,
}

static func normalize_settings(settings: Dictionary) -> Dictionary:
	var result := DEFAULT_SETTINGS.duplicate()
	var sensitivity: Variant = settings.get("mouse_sens")
	if _is_number(sensitivity):
		result.mouse_sens = clampf(float(sensitivity), 0.4, 2.4)
	var difficulty: Variant = settings.get("difficulty")
	if difficulty is String and difficulty in DIFFICULTIES:
		result.difficulty = difficulty
	for key: String in ["volumetric_fog", "ssr", "ssao", "msaa"]:
		var enabled: Variant = settings.get(key)
		if enabled is bool:
			result[key] = enabled
	return result

static func save_settings(settings: Dictionary) -> void:
	_write_json(SETTINGS_PATH, normalize_settings(settings))

static func load_settings() -> Dictionary:
	return normalize_settings(_read_json(SETTINGS_PATH))

static func difficulty_damage_multiplier(diff: String) -> float:
	match diff:
		"Story":
			return 0.65
		"Torment":
			return 1.45
		_:
			return 1.0

static func chapter_id_for_stage(stage: int) -> String:
	if stage >= 0 and stage < CHAPTER_IDS.size():
		return CHAPTER_IDS[stage]
	return ""

static func serialize_game(game: Object) -> Dictionary:
	if not is_instance_valid(game):
		return {}
	var player: Node3D = game.get("player") as Node3D
	if not is_instance_valid(player):
		return {}

	var chapter: Variant = game.get("chapter_id")
	if chapter == null or str(chapter).is_empty():
		var stage: Variant = game.get("stage")
		chapter = chapter_id_for_stage(int(stage)) if stage is int else ""
	var states: Dictionary = {}
	var game_states: Variant = game.get("level_states")
	if game_states is Dictionary:
		for key: Variant in game_states:
			var chapter_key := chapter_id_for_stage(key) if key is int else str(key)
			var state: Variant = game_states[key]
			if not chapter_key.is_empty() and state is Dictionary:
				states[chapter_key] = state.duplicate(true)

	var pos := player.position
	var data := {
		"schema_version": SCHEMA_VERSION,
		"chapter_id": str(chapter),
		"level_states": states,
		"pos": [pos.x, pos.y, pos.z],
		"yaw": player.rotation.y,
		"pitch": _number_or(game.get("pitch"), 0.0),
	}
	for key: String in WEAPON_AND_KEY_FIELDS:
		data[key] = game.get(key) == true
	for key: String in STAT_DEFAULTS:
		data[key] = _number_or(game.get(key), STAT_DEFAULTS[key])
	for key: String in ["story_flags", "journal_entries"]:
		var entries: Variant = game.get(key)
		data[key] = entries.duplicate(true) if entries is Array else []
	for key: String in ["seen_echoes", "triggered_volumes"]:
		var flags: Variant = game.get(key)
		data[key] = flags.duplicate(true) if flags is Dictionary else {}
	return data

static func write_save(game: Object, is_checkpoint: bool = false) -> bool:
	var data := serialize_game(game)
	if not _is_valid_save(data):
		return false
	return _write_json(CHECKPOINT_PATH if is_checkpoint else QUICKSAVE_PATH, data)

static func read_save(is_checkpoint: bool = false) -> Dictionary:
	var data := _read_json(CHECKPOINT_PATH if is_checkpoint else QUICKSAVE_PATH)
	if not data.has("schema_version") and data.has("stage"):
		data = _upgrade_legacy_save(data)
	var states: Variant = data.get("level_states")
	if states is Dictionary:
		var flags: Variant = data.get("story_flags")
		data["level_states"] = normalize_level_states(states, flags if flags is Array else [])
	return data if _is_valid_save(data) else {}

# Merge every saved chapter over ChapterRegistry.default_state(), repair types,
# rebuild story_world and apply pre-story-world migrations. Unknown fields are
# preserved. Non-dictionary entries stay as-is so validation still rejects them.
static func normalize_level_states(raw_states: Dictionary, story_flags: Array = []) -> Dictionary:
	var result := {}
	for key: Variant in raw_states:
		var raw: Variant = raw_states[key]
		var chapter_id := _chapter_key(key)
		if chapter_id.is_empty() or not raw is Dictionary or not ChapterRegistry.CHAPTERS.has(chapter_id):
			result[chapter_id if not chapter_id.is_empty() else key] = raw.duplicate(true) if raw is Dictionary or raw is Array else raw
			continue
		var raw_state: Dictionary = raw
		var state := ChapterRegistry.default_state(chapter_id)
		for field: Variant in raw_state:
			if field == "story_world":
				continue
			var value: Variant = raw_state[field]
			state[field] = _coerce(value, state[field]) if state.has(field) else _copy(value)
		var raw_world: Dictionary = raw_state.story_world if raw_state.get("story_world") is Dictionary else {}
		var world: Dictionary = state.story_world
		for field: Variant in raw_world:
			if field == "completed_sequences":
				continue
			var value: Variant = raw_world[field]
			world[field] = _coerce(value, world[field]) if world.has(field) else _copy(value)
		world["completed_sequences"] = _clean_sequences(raw_world.get("completed_sequences"))
		_migrate_chapter_state(chapter_id, state, world, raw_world, story_flags)
		result[chapter_id] = state
	return result

static func _migrate_chapter_state(chapter_id: String, state: Dictionary, world: Dictionary, raw_world: Dictionary, story_flags: Array) -> void:
	match chapter_id:
		"ch1_court":
			if _is_true(state.get("gate_open")):
				state["siege_stage"] = maxi(3, int(_number_or(state.get("siege_stage"), 0)))
				state["torin_hollowed"] = true
			if _is_true(state.get("gatehouse_open")) and str(raw_world.get("seraphina_mark", "")).is_empty():
				world["seraphina_mark"] = "gatehouse_winch"
		"ch2_tower":
			if _is_true(state.get("boss_dead")):
				state["bell_fallen"] = true
				world["belfry_shaft_open"] = true
			elif _is_true(world.get("belfry_shaft_open")):
				world["belfry_shaft_open"] = false
			if not raw_world.has("malcor_departed"):
				var wards: Variant = state.get("wards")
				var shattered := {}
				if wards is Array:
					for ward: Variant in wards:
						shattered[str(ward)] = true
				if story_flags.has("npc_malcor_choir") or shattered.size() >= 3:
					world["malcor_departed"] = true
		"ch3_kiln":
			if _is_true(state.get("great_gate_open")):
				state["gate_turns"] = 3
				state["act_complete"] = true
			if _is_true(state.get("gauntlet_triggered")) and str(raw_world.get("seraphina_mark", "")).is_empty():
				world["seraphina_mark"] = "kiln_safe_gantry"

static func _chapter_key(key: Variant) -> String:
	if key is int:
		return chapter_id_for_stage(key)
	var text := str(key)
	if text.is_valid_int():
		return chapter_id_for_stage(text.to_int())
	return text

# Keep a saved value only when it matches the default's JSON type.
static func _coerce(value: Variant, fallback: Variant) -> Variant:
	if fallback is bool:
		return value if value is bool else fallback
	if fallback is int:
		if not _is_number(value):
			return fallback
		return int(value) if float(value) == floorf(float(value)) else float(value)
	if fallback is float:
		return float(value) if _is_number(value) else fallback
	if fallback is String or fallback is StringName:
		return str(value) if value is String or value is StringName else fallback
	if fallback is Array:
		return value.duplicate(true) if value is Array else fallback
	if fallback is Dictionary:
		return value.duplicate(true) if value is Dictionary else fallback
	return _copy(value)

static func _is_true(value: Variant) -> bool:
	return value is bool and value

static func _copy(value: Variant) -> Variant:
	if value is Array or value is Dictionary:
		return value.duplicate(true)
	return value

static func _clean_sequences(value: Variant) -> Dictionary:
	var sequences := {}
	if value is Dictionary:
		for id: Variant in value:
			if _is_true(value[id]) and not str(id).is_empty():
				sequences[str(id)] = true
	return sequences

static func has_checkpoint() -> bool:
	return not read_save(true).is_empty()

static func _upgrade_legacy_save(legacy: Dictionary) -> Dictionary:
	var stage: Variant = legacy.get("stage")
	if not _is_number(stage) or float(stage) != floorf(float(stage)):
		return {}
	if stage < 0 or stage >= CHAPTER_IDS.size():
		return {}
	var active_stage := int(stage)
	var states: Dictionary = {}
	for i in CHAPTER_IDS.size():
		var state: Variant = legacy.get("s%d" % i)
		if state is Dictionary:
			states[CHAPTER_IDS[i]] = state
	var data := {
		"schema_version": SCHEMA_VERSION,
		"chapter_id": CHAPTER_IDS[active_stage],
		"level_states": states,
		"has_arbalest": legacy.get("arbalest", false),
		"has_thurible": legacy.get("thurible", false),
		"has_voltaic": false,
		"has_ashen_key": legacy.get("ashen_key", false),
		"pos": legacy.get("pos"),
		"yaw": legacy.get("yaw", 0.0),
		"pitch": legacy.get("pitch", 0.0),
		"story_flags": legacy.get("story_flags", []),
		"journal_entries": legacy.get("journal_entries", []),
		"seen_echoes": {},
		"triggered_volumes": {},
	}
	for key: String in STAT_DEFAULTS:
		data[key] = legacy.get("green" if key == "green_mana" else key, STAT_DEFAULTS[key])
	return data

static func _is_valid_save(data: Dictionary) -> bool:
	var version: Variant = data.get("schema_version")
	if not _is_number(version) or float(version) != SCHEMA_VERSION:
		return false
	var chapter: Variant = data.get("chapter_id")
	var states: Variant = data.get("level_states")
	if not chapter is String or chapter.is_empty() or not states is Dictionary or not states.has(chapter):
		return false
	for key: Variant in states:
		if not key is String or key.is_empty() or not states[key] is Dictionary:
			return false
	var pos: Variant = data.get("pos")
	if not pos is Array or pos.size() != 3:
		return false
	for component: Variant in pos:
		if not _is_number(component):
			return false
	for key: String in WEAPON_AND_KEY_FIELDS:
		if not data.get(key) is bool:
			return false
	for key: String in STAT_DEFAULTS:
		if not _is_number(data.get(key)):
			return false
	var story_flags: Variant = data.get("story_flags")
	var journal_entries: Variant = data.get("journal_entries")
	if not story_flags is Array or not journal_entries is Array:
		return false
	for flag: Variant in story_flags:
		if not flag is String:
			return false
	for entry: Variant in journal_entries:
		if not entry is Dictionary:
			return false
	return (
		_is_number(data.get("yaw"))
		and _is_number(data.get("pitch"))
		and data.get("seen_echoes") is Dictionary
		and data.get("triggered_volumes") is Dictionary
	)

static func _number_or(value: Variant, fallback: Variant) -> Variant:
	return value if _is_number(value) else fallback

static func _is_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {}
	var data: Variant = parser.data
	return data if data is Dictionary else {}

static func _write_json(path: String, data: Dictionary) -> bool:
	var temp_path := path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	var stored := file.store_string(JSON.stringify(data))
	file.close()
	if stored and DirAccess.rename_absolute(temp_path, path) == OK:
		return true
	DirAccess.remove_absolute(temp_path)
	return false
