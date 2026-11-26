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
	return data if _is_valid_save(data) else {}

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
