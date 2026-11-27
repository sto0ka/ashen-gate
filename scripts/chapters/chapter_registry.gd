class_name ChapterRegistry
extends RefCounted

const Court = preload("res://scripts/chapters/chapter_1_court.gd")
const Tower = preload("res://scripts/chapters/chapter_2_tower.gd")
const Kiln = preload("res://scripts/chapters/chapter_3_kiln.gd")

const CHAPTERS := {
	"ch1_court": {
		"id": "ch1_court", "index": 0, "chapter_num": "CHAPTER I",
		"title": "THE SUNKEN COURT", "subtitle": "The Night the Bell Cracked",
		"acoustics": "crypt", "music_profile": "ch1_court", "map_bounds": Rect2(-32, -50, 64, 113),
		"landmark_offset": Vector3.ZERO,
		"map_caption": "Gatehouse • West Cistern • East Ossuary • North Portcullis",
		"default_spawn": Vector3(0, 6.1, 61.0), "next_chapter": "ch2_tower", "script": Court,
	},
	"ch2_tower": {
		"id": "ch2_tower", "index": 1, "chapter_num": "CHAPTER II",
		"title": "THE BELL TOWER", "subtitle": "The Three Tolls of Malcor",
		"acoustics": "cathedral", "music_profile": "ch2_tower", "map_bounds": Rect2(-35, -57, 70, 93),
		"landmark_offset": Vector3(0, 0, 77),
		"map_caption": "Clockwork Gallery • Pendulum Foundry • Choir Loft • Belfry Sanctum",
		"default_spawn": Vector3(0, 0.1, 33.0), "next_chapter": "ch3_kiln", "script": Tower,
	},
	"ch3_kiln": {
		"id": "ch3_kiln", "index": 2, "chapter_num": "CHAPTER III",
		"title": "THE KILN OF ASH", "subtitle": "Where Names Become Iron",
		"acoustics": "furnace", "music_profile": "ch3_kiln", "map_bounds": Rect2(-33, -43, 66, 70),
		"landmark_offset": Vector3(0, 60, 143.6),
		"map_caption": "Frozen Aqueduct • Crucible Hall • Deep Smeltery • Great Ashen Gate",
		"default_spawn": Vector3(0, 6.1, 24.6), "next_chapter": "", "script": Kiln,
	},
}

# Schema v2 nested story state (ENGINE_STORY_SYSTEMS_PLAN §5). Every chapter
# also carries "completed_sequences": {sequence_id: true}.
const STORY_WORLD_DEFAULTS := {
	"ch1_court": {"gatehouse_arch_collapsed": false, "seraphina_mark": "gatehouse_grate"},
	"ch2_tower": {"nave_chandelier_fallen": false, "malcor_departed": false, "belfry_shaft_open": false},
	"ch3_kiln": {"seraphina_mark": "kiln_observation"},
}

static func get_chapter_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(CHAPTERS.keys())
	return ids

func _init() -> void:
	for chapter_id in get_chapter_ids():
		set_meta(StringName(chapter_id), get_chapter_meta(chapter_id))

# RefCounted inherits Object.get_meta(). Instances expose chapter metadata
# through that API. This accessor also supports static, typed lookup.

static func get_chapter_meta(chapter_id: String) -> Dictionary:
	var meta: Dictionary = CHAPTERS.get(chapter_id, {}).duplicate()
	meta.erase("script")
	return meta

static func default_state(chapter_id: String) -> Dictionary:
	if not CHAPTERS.has(chapter_id):
		return {}
	var state := {"dead": [], "taken": [], "broken": [], "checkpoint_id": ""}
	var chapter: GDScript = CHAPTERS[chapter_id].script
	state.merge(chapter.default_state())
	var world := default_story_world(chapter_id)
	var chapter_world: Variant = state.get("story_world")
	if chapter_world is Dictionary:
		world.merge(chapter_world.duplicate(true), true)
		if not world.get("completed_sequences") is Dictionary:
			world["completed_sequences"] = {}
	state["story_world"] = world
	return state

static func default_story_world(chapter_id: String) -> Dictionary:
	var world := {"completed_sequences": {}}
	var authored: Dictionary = STORY_WORLD_DEFAULTS.get(chapter_id, {})
	world.merge(authored.duplicate(true), true)
	return world

# Fill missing keys in place (existing values win) and repair story_world.
static func ensure_state_defaults(chapter_id: String, state: Dictionary) -> Dictionary:
	var defaults := default_state(chapter_id)
	var world: Variant = state.get("story_world")
	state.merge(defaults)
	if world is Dictionary:
		world.merge(defaults.get("story_world", {}))
		if not world.get("completed_sequences") is Dictionary:
			world["completed_sequences"] = {}
	elif defaults.has("story_world"):
		state["story_world"] = defaults.story_world
	return state

static func build(game, chapter_id: String) -> void:
	if not CHAPTERS.has(chapter_id):
		push_error("Unknown chapter '%s'" % chapter_id)
		return
	var states: Dictionary = game.level_states
	var index: int = CHAPTERS[chapter_id].index
	var state_key: Variant = index if states.has(index) and not states.has(chapter_id) else chapter_id
	var state: Dictionary = states.get(state_key, {})
	ensure_state_defaults(chapter_id, state)
	states[state_key] = state
	game.level_root.set_meta("chapter_id", chapter_id)
	var chapter: GDScript = CHAPTERS[chapter_id].script
	chapter.build(game, state)
