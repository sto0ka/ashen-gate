class_name ChapterRegistry
extends RefCounted

const Court = preload("res://scripts/chapters/chapter_1_court.gd")
const Tower = preload("res://scripts/chapters/chapter_2_tower.gd")
const Kiln = preload("res://scripts/chapters/chapter_3_kiln.gd")

const CHAPTERS := {
	"ch1_court": {
		"id": "ch1_court", "index": 0, "chapter_num": "CHAPTER I",
		"title": "THE SUNKEN COURT", "subtitle": "Kingdom of Vaelor — Forty Nights After the Fracture",
		"acoustics": "crypt", "map_bounds": Rect2(-32, -35, 64, 83),
		"map_caption": "Gatehouse • West Cistern • East Ossuary • North Portcullis",
		"default_spawn": Vector3(0, 0.1, 42), "next_chapter": "ch2_tower", "script": Court,
	},
	"ch2_tower": {
		"id": "ch2_tower", "index": 1, "chapter_num": "CHAPTER II",
		"title": "THE BELL TOWER", "subtitle": "Three Resonant Wards Bind Lord Malcor",
		"acoustics": "cathedral", "map_bounds": Rect2(-35, -57, 70, 85),
		"map_caption": "Clockwork Gallery • Pendulum Foundry • Choir Loft • Belfry Sanctum",
		"default_spawn": Vector3(0, 0.1, 24), "next_chapter": "ch3_kiln", "script": Tower,
	},
	"ch3_kiln": {
		"id": "ch3_kiln", "index": 2, "chapter_num": "CHAPTER III",
		"title": "THE KILN OF ASH", "subtitle": "Where Vaelor Forged the Great Gate",
		"acoustics": "furnace", "map_bounds": Rect2(-33, -43, 66, 70),
		"map_caption": "Frozen Aqueduct • Crucible Hall • Deep Smeltery • Great Ashen Gate",
		"default_spawn": Vector3(0, 0.1, 24), "next_chapter": "", "script": Kiln,
	},
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
	return state

static func build(game, chapter_id: String) -> void:
	if not CHAPTERS.has(chapter_id):
		push_error("Unknown chapter '%s'" % chapter_id)
		return
	var states: Dictionary = game.level_states
	var index: int = CHAPTERS[chapter_id].index
	var state_key: Variant = index if states.has(index) and not states.has(chapter_id) else chapter_id
	var state: Dictionary = states.get(state_key, {})
	state.merge(default_state(chapter_id))
	states[state_key] = state
	game.level_root.set_meta("chapter_id", chapter_id)
	var chapter: GDScript = CHAPTERS[chapter_id].script
	chapter.build(game, state)
