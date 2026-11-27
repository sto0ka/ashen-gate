class_name Audio3D
extends Node

## Ashen Gate audio director.
##
## * Legacy API: setup / tick / set_room_acoustics / set_combat_intensity / play_2d / play_at / stop_all.
## * Per-chapter music: each chapter owns a phase-aligned ambient + combat stem pair played through one
##   AudioStreamSynchronized deck. Decks crossfade with cosine/sine gains; combat fades in 0.7 s / out 1.4 s.
## * Story foley + speaker chimes are deterministic synth one-shots rendered on WorkerThreadPool after
##   setup (boot stays fast); any cue requested before its job is done is completed on demand.

const SAMPLE_RATE := 24000
const MUSIC_RATE := 22050
const GRAIN_RATE := 16000
const AMBIENT_DB := -17.0
const COMBAT_DB := -15.0
const DUCK_DB := -3.0
const SPEAKER_2D_DB := -14.0
const SPEAKER_3D_DB := -8.0
const GRAIN_DB := -24.0
const COMBAT_FADE_IN := 0.7
const COMBAT_FADE_OUT := 1.4
const MAX_POSITIONAL := 24
const MAX_2D := 16
const MAX_DECKS := 2
const GRAIN_SYLLABLES := 16
const ONESHOT_PEAK := 0.86
const STEM_PEAK := 0.74
const SILENT_DB := -80.0
const LEGACY_DECK := "legacy"

const WAV_NAMES := [
	"axe", "hit", "cast", "lever", "pickup", "ambient", "frost",
	"maul", "portal", "bell", "repulse", "step", "jump", "land",
]
const SYNTH_LENGTHS := {
	"parry": 0.62, "voltaic": 0.28, "stalker": 0.46, "splash": 0.72,
	"lift": 1.20, "alarm": 1.85, "combat_pulse": 6.40,
}
## Story foley and speaker chimes (ACT I script §6.6), lengths in seconds at SAMPLE_RATE.
const STORY_LENGTHS := {
	"bell_crack": 2.60, "resonance_wave": 1.80, "collapse": 2.40, "rubble": 1.40,
	"glass_burst": 0.90, "door_groan": 2.00, "door_slam": 0.80, "wind_gust": 3.00,
	"thunder_far": 3.50, "chain_strain": 1.20, "chain_snap": 0.60, "timber_groan": 1.60,
	"impact_deep": 2.40, "gear_grind": 1.00, "hollow_rise": 1.10, "steam_ram": 1.50,
	"quench_hiss": 2.20, "key_turn": 0.50, "iron_release": 1.60, "gate_grind": 4.00,
	"slag_surge": 2.00, "choir_whisper": 2.80, "flood_rush": 2.20, "underwater_bell": 2.60,
	"cue_seraphina": 0.55, "cue_guard": 0.40, "cue_malcor": 1.20, "cue_choir": 0.90,
	"cue_ilse": 0.85, "vo_chime_echo": 0.60, "vo_chime_king": 2.00,
}
const ALIASES := {
	"vo_chime_seraphina": "cue_seraphina",
	"cue_torin": "cue_guard", "vo_chime_torin": "cue_guard", "vo_chime_guard": "cue_guard",
	"vo_chime_malcor": "cue_malcor",
	"vo_choir_breath": "cue_choir", "vo_chime_choir": "cue_choir", "cue_hollow_choir": "cue_choir",
	"vo_chime_ilse": "cue_ilse",
	"cue_echo": "vo_chime_echo", "cue_king": "vo_chime_king",
}
## Speaker profiles: chime stream + formant voice-grain recipe (§2 / §6.6).
const SPEAKERS := {
	"seraphina": {"chime": "cue_seraphina", "f0": 215.0, "f1": 820.0, "f2": 1650.0, "rate": 6.5, "voices": 1},
	"guard": {"chime": "cue_guard", "f0": 118.0, "f1": 600.0, "f2": 1150.0, "rate": 5.2, "voices": 1},
	"malcor": {"chime": "cue_malcor", "f0": 92.0, "f1": 420.0, "f2": 900.0, "rate": 3.5, "voices": 1},
	"choir": {"chime": "cue_choir", "f0": 164.0, "f1": 520.0, "f2": 1040.0, "rate": 3.0, "voices": 6},
	"ilse": {"chime": "cue_ilse", "f0": 290.0, "f1": 900.0, "f2": 2050.0, "rate": 6.0, "voices": 1},
	"echo": {"chime": "vo_chime_echo", "f0": 170.0, "f1": 700.0, "f2": 1400.0, "rate": 5.0, "voices": 2},
	"king": {"chime": "vo_chime_king", "f0": 61.0, "f1": 330.0, "f2": 720.0, "rate": 2.6, "voices": 3},
}
const SPEAKER_ALIASES := {
	"torin": "guard", "brother_torin": "guard", "wounded_guard": "guard", "watchman": "guard",
	"hollow_choir": "choir", "the_choir": "choir",
	"lord_malcor": "malcor", "archivist": "seraphina", "seraphina_vant": "seraphina",
	"the_king": "king", "hollow_king": "king", "echoes": "echo",
}
const TUBE_CHANNELS := {"tube": true, "speaking_tube": true, "pipe": true, "horn": true}
const MUTE_GRAIN_CHANNELS := {"none": true, "silent": true, "chime": true, "chime_only": true}
## Cues that duck music briefly and win positional voice stealing.
const MAJOR_CUES := {
	"bell_crack": true, "resonance_wave": true, "collapse": true, "impact_deep": true,
	"chain_snap": true, "iron_release": true, "gate_grind": true, "slag_surge": true,
	"flood_rush": true, "thunder_far": true, "door_slam": true, "alarm": true,
	"vo_chime_king": true, "bell": true,
}
## Chapter music profiles: 4 bars of 4/4, loop length = 16 beats.
const CHAPTERS := {
	"ch1_court": {"acoustics": "crypt", "bpm": 75.0, "trim_db": 0.0},
	"ch2_tower": {"acoustics": "cathedral", "bpm": 96.0, "trim_db": -0.5},
	"ch3_kiln": {"acoustics": "furnace", "bpm": 100.0, "trim_db": -0.5},
}
const REVERB_BUS := {"cathedral": &"Cathedral", "crypt": &"Crypt", "furnace": &"Furnace"}

enum JobKind { LEGACY, STORY, STEM, GRAIN }


class SynthJob extends RefCounted:
	var key := ""
	var kind := 0
	var arg := ""
	var variant := ""
	var duration := 0.0
	var rate := 24000
	var loop := false
	var cancelled := false
	var started := false
	var pcm := PackedByteArray()
	var task_id := -1


class MusicDeck extends RefCounted:
	var id := ""
	var player: AudioStreamPlayer
	var sync: AudioStreamSynchronized
	var p := 0.0
	var target := 1.0
	var fade := 0.6
	var trim_db := 0.0
	var ambient_floor := 0.45


var _streams: Dictionary = {}
var _jobs: Dictionary = {}
var _retired_jobs: Array[SynthJob] = []
var _started := false
var _legacy_pending := false
var _voices: Dictionary = {}
var _positional: Array[int] = []
var _flat: Array[int] = []
var _priority: Dictionary = {}
var _decks: Array[MusicDeck] = []
var _chapter_id := ""
var _pending_chapter := ""
var _crossfade := 0.6
var _combat_target := 0.0
var _combat_mix := 0.0
var _duck_timer := 0.0
var _duck_depth := DUCK_DB
var _duck_db := 0.0
var _room := "cathedral"


# --------------------------------------------------------------------------------------------
# Public API
# --------------------------------------------------------------------------------------------

func setup(parent: Node) -> void:
	if get_parent() == null and parent != self:
		parent.add_child(self)
	if _started:
		return
	_started = true

	_configure_reverb(&"Cathedral", 0.86, 0.35, 0.33, 31.0)
	_configure_reverb(&"Crypt", 0.58, 0.69, 0.24, 12.0)
	_configure_reverb(&"Furnace", 0.72, 0.48, 0.19, 19.0)
	for sname: String in WAV_NAMES:
		var path := "res://audio/%s.wav" % sname
		if not _streams.has(sname) and ResourceLoader.exists(path):
			_streams[sname] = load(path)
	# Legacy synths render on the worker pool first; the legacy ambient/combat loop starts as soon as
	# combat_pulse is ready (unless a chapter took over), so setup itself stays in the low milliseconds.
	for sname: String in SYNTH_LENGTHS:
		_queue_job(sname, sname == "combat_pulse")
	_combat_target = 0.0
	_combat_mix = 0.0
	_legacy_pending = _chapter_id == ""
	warm_up(false)
	_try_start_legacy()
	_try_start_pending()


func tick(delta: float) -> void:
	_poll_jobs()
	_try_start_legacy()
	_try_start_pending()
	var dt := maxf(delta, 0.0)
	var rate := 1.0 / COMBAT_FADE_IN if _combat_target > _combat_mix else 1.0 / COMBAT_FADE_OUT
	_combat_mix = move_toward(_combat_mix, _combat_target, dt * rate)
	_duck_timer = maxf(_duck_timer - dt, 0.0)
	var duck_target := _duck_depth if _duck_timer > 0.0 else 0.0
	var duck_speed := absf(DUCK_DB) / (0.12 if duck_target < _duck_db else 0.65)
	_duck_db = move_toward(_duck_db, duck_target, dt * duck_speed)
	for deck: MusicDeck in _decks.duplicate():
		if deck.fade <= 0.0:
			deck.p = deck.target
		else:
			deck.p = move_toward(deck.p, deck.target, dt / deck.fade)
		if deck.p <= 0.0 and deck.target <= 0.0:
			_free_deck(deck)
		else:
			_apply_deck_gain(deck)


func set_room_acoustics(zone_type: String) -> void:
	_room = zone_type.to_lower()


func set_combat_intensity(in_combat: bool) -> void:
	_combat_target = 1.0 if in_combat else 0.0


## Switch chapter music. Same chapter only updates acoustics (music keeps playing).
func set_chapter(chapter_id: String, acoustics: String = "", crossfade_seconds: float = 0.60) -> void:
	var id := chapter_id.to_lower()
	var changed := id != _chapter_id
	if acoustics != "":
		set_room_acoustics(acoustics)
	elif changed and CHAPTERS.has(id):
		set_room_acoustics(str(CHAPTERS[id].get("acoustics", _room)))
	if not changed or not CHAPTERS.has(id):
		return
	_chapter_id = id
	_legacy_pending = false
	_crossfade = maxf(crossfade_seconds, 0.0)
	for stem: String in ["ambient", "combat"]:
		_prioritize_job(_stem_key(id, stem))
	_pending_chapter = id
	_try_start_pending()


func get_chapter() -> String:
	return _chapter_id


func is_chapter_ready(chapter_id: String) -> bool:
	var id := chapter_id.to_lower()
	return _streams.has(_stem_key(id, "ambient")) and _streams.has(_stem_key(id, "combat"))


## Briefly lower music (default -3 dB) for urgent callouts and major story impacts.
func duck_music(duration: float = 1.2, depth_db: float = DUCK_DB) -> void:
	if duration <= 0.0:
		return
	_duck_depth = minf(_duck_depth, depth_db) if _duck_timer > 0.0 else minf(depth_db, 0.0)
	_duck_timer = maxf(_duck_timer, duration)


## Queue every chapter stem, story cue and voice grain for background synthesis.
## blocking = true waits for all of them (tests / loading screens).
func warm_up(blocking: bool = false) -> void:
	for id: String in CHAPTERS:
		_queue_job(_stem_key(id, "ambient"))
		_queue_job(_stem_key(id, "combat"))
	for sname: String in STORY_LENGTHS:
		_queue_job(sname)
	for speaker: String in SPEAKERS:
		_queue_job("vo_grain_" + speaker)
		_queue_job("vo_grain_%s_tube" % speaker)
	if blocking:
		for key: String in _jobs.keys():
			_complete_job(key)


func get_supported_cues() -> PackedStringArray:
	var names := PackedStringArray()
	for sname: String in WAV_NAMES:
		names.append(sname)
	for sname: String in SYNTH_LENGTHS:
		names.append(sname)
	for sname: String in STORY_LENGTHS:
		names.append(sname)
	for sname: String in ALIASES:
		names.append(sname)
	for speaker: String in SPEAKERS:
		names.append("vo_grain_" + speaker)
		names.append("vo_grain_%s_tube" % speaker)
	return names


func get_voice_count() -> int:
	return _voices.size()


func get_positional_count() -> int:
	return _positional.size()


func get_pending_job_count() -> int:
	return _jobs.size()


func get_music_deck_count() -> int:
	return _decks.size()


func play_2d(sname: String, pitch: float = 1.0, vol_db: float = -6.0) -> void:
	_spawn_2d(sname, pitch, vol_db, MAJOR_CUES.has(_resolve(sname)))


func play_at(parent: Node3D, sname: String, pos: Vector3, pitch: float = 1.0, max_dist: float = 30.0, vol_db: float = -6.0) -> void:
	_spawn_positional(parent, sname, pos, pitch, max_dist, vol_db, MAJOR_CUES.has(_resolve(sname)))


## Speaker chime (+ optional formant voice grain) for a subtitle line. Spatial when world_origin is a
## Vector3 and parent is valid, otherwise a quiet 2D accessibility cue. channel "tube" routes the grain
## through a speaking-tube comb/band filter; "none"/"chime" disables the grain.
func play_speaker_cue(cue_id: String, parent: Node3D = null, world_origin: Variant = null, channel: String = "", syllable_count: int = 8) -> void:
	var speaker := _speaker_key(cue_id)
	var profile: Dictionary = SPEAKERS.get(speaker, {})
	var chime := str(profile.get("chime", ""))
	if chime == "":
		chime = _resolve(cue_id) if _is_known(_resolve(cue_id)) else "vo_chime_echo"
	var ch := channel.to_lower()
	var spatial := world_origin is Vector3 and is_instance_valid(parent) and parent.is_inside_tree()
	var origin: Vector3 = world_origin if world_origin is Vector3 else Vector3.ZERO
	if spatial:
		_spawn_positional(parent, chime, origin, 1.0, 42.0, SPEAKER_3D_DB, true)
	else:
		_spawn_2d(chime, 1.0, SPEAKER_2D_DB, true)

	var syllables := clampi(syllable_count, 0, GRAIN_SYLLABLES)
	var speech_seconds := 0.0
	if not profile.is_empty() and syllables > 0 and not MUTE_GRAIN_CHANNELS.has(ch) and (spatial or ch != ""):
		var syl_rate: float = profile.get("rate", 5.0)
		var key := "vo_grain_%s%s" % [speaker, "_tube" if TUBE_CHANNELS.has(ch) else ""]
		speech_seconds = (float(syllables) - 0.15) / syl_rate
		var voice: Node
		if spatial:
			voice = _spawn_positional(parent, key, origin, 1.0, 26.0, GRAIN_DB + 4.0, true)
		else:
			voice = _spawn_2d(key, 1.0, GRAIN_DB, true)
		if voice != null:
			_schedule_stop(voice, speech_seconds)
	var duck_seconds := clampf(0.9 + speech_seconds * 0.5, 0.9, 2.6)
	if speaker == "king":
		duck_seconds = maxf(duck_seconds, 2.0)
	duck_music(duck_seconds)


func stop_all() -> void:
	_cancel_jobs()
	for voice: Node in _voices.values():
		if is_instance_valid(voice):
			voice.call("stop")
			voice.queue_free()
	_voices.clear()
	_positional.clear()
	_flat.clear()
	_priority.clear()
	for deck: MusicDeck in _decks.duplicate():
		_free_deck(deck)
	_decks.clear()
	_chapter_id = ""
	_pending_chapter = ""
	_started = false
	_legacy_pending = false
	_duck_timer = 0.0
	_duck_db = 0.0
	_duck_depth = DUCK_DB


func _exit_tree() -> void:
	stop_all()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_cancel_jobs()


# --------------------------------------------------------------------------------------------
# Voices
# --------------------------------------------------------------------------------------------

func _spawn_2d(sname: String, pitch: float, vol_db: float, priority: bool) -> Node:
	if not is_inside_tree():
		return null
	var stream := _ensure_stream(sname)
	if stream == null:
		return null
	if not _admit(_flat, MAX_2D, priority):
		return null
	var voice := AudioStreamPlayer.new()
	voice.stream = stream
	voice.pitch_scale = maxf(pitch, 0.01)
	voice.volume_db = vol_db
	add_child(voice)
	_track_voice(voice, stream.get_length() / voice.pitch_scale)
	_register(voice, _flat, priority)
	voice.finished.connect(voice.queue_free)
	voice.play()
	if MAJOR_CUES.has(_resolve(sname)):
		duck_music(1.2)
	return voice


func _spawn_positional(parent: Node3D, sname: String, pos: Vector3, pitch: float, max_dist: float, vol_db: float, priority: bool) -> Node:
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return null
	var stream := _ensure_stream(sname)
	if stream == null:
		return null
	if not _admit(_positional, MAX_POSITIONAL, priority):
		return null
	var voice := AudioStreamPlayer3D.new()
	voice.stream = stream
	voice.pitch_scale = maxf(pitch, 0.01)
	voice.max_distance = maxf(max_dist, 0.01)
	voice.volume_db = vol_db
	var bus: StringName = REVERB_BUS.get(_room, &"Master")
	if AudioServer.get_bus_index(bus) >= 0:
		voice.bus = bus
	parent.add_child(voice)
	voice.global_position = pos
	voice.top_level = true
	_track_voice(voice, stream.get_length() / voice.pitch_scale)
	_register(voice, _positional, priority)
	voice.finished.connect(voice.queue_free)
	voice.play()
	if MAJOR_CUES.has(_resolve(sname)):
		duck_music(1.2)
	return voice


## Voice cap: steal the oldest non-priority voice; priority voices may steal the oldest of any kind.
func _admit(order: Array[int], cap: int, priority: bool) -> bool:
	for i in range(order.size() - 1, -1, -1):
		if not is_instance_valid(_voices.get(order[i])):
			_forget(order[i])
	if order.size() < cap:
		return true
	for id: int in order:
		if not bool(_priority.get(id, false)):
			_kill_voice(id)
			return true
	if priority and not order.is_empty():
		_kill_voice(order[0])
		return true
	return false


func _register(voice: Node, order: Array[int], priority: bool) -> void:
	var id := voice.get_instance_id()
	order.append(id)
	_priority[id] = priority


func _kill_voice(id: int) -> void:
	var voice: Node = _voices.get(id)
	_forget(id)
	if is_instance_valid(voice):
		voice.call("stop")
		voice.queue_free()


func _forget(id: int) -> void:
	_voices.erase(id)
	_priority.erase(id)
	_positional.erase(id)
	_flat.erase(id)


func _on_voice_exited(id: int) -> void:
	_forget(id)


func _track_voice(voice: Node, duration: float) -> void:
	var id := voice.get_instance_id()
	_voices[id] = voice
	voice.tree_exited.connect(_on_voice_exited.bind(id), CONNECT_ONE_SHOT)
	var timer := Timer.new()
	timer.one_shot = true
	timer.ignore_time_scale = true
	voice.add_child(timer)
	timer.timeout.connect(voice.queue_free)
	timer.start(maxf(duration, 0.1) + 0.75)


## Voice grains are rendered with silent gaps between syllables, so a timed stop never clicks.
func _schedule_stop(voice: Node, seconds: float) -> void:
	var timer := Timer.new()
	timer.one_shot = true
	timer.ignore_time_scale = true
	voice.add_child(timer)
	timer.timeout.connect(func() -> void:
		voice.call("stop")
		voice.queue_free()
	)
	timer.start(maxf(seconds, 0.05))


# --------------------------------------------------------------------------------------------
# Music decks
# --------------------------------------------------------------------------------------------

func _try_start_legacy() -> void:
	if not _legacy_pending or not is_inside_tree():
		return
	if _chapter_id != "" or not _decks.is_empty():
		_legacy_pending = false
		return
	if not _streams.has("combat_pulse"):
		return
	_legacy_pending = false
	var legacy := _create_deck(LEGACY_DECK)
	if legacy != null:
		legacy.fade = 0.35


func _try_start_pending() -> void:
	if _pending_chapter == "" or not is_inside_tree() or not is_chapter_ready(_pending_chapter):
		return
	var id := _pending_chapter
	_pending_chapter = ""
	_switch_deck(id, _crossfade)


func _switch_deck(id: String, fade: float) -> void:
	var incoming: MusicDeck = null
	for deck: MusicDeck in _decks:
		if deck.id == id:
			incoming = deck
	if incoming == null:
		while _decks.size() >= MAX_DECKS:
			var quietest: MusicDeck = _decks[0]
			for deck: MusicDeck in _decks:
				if deck.p < quietest.p:
					quietest = deck
			_free_deck(quietest)
		incoming = _create_deck(id)
		if incoming == null:
			return
	for deck: MusicDeck in _decks:
		deck.target = 1.0 if deck == incoming else 0.0
		deck.fade = fade
		_apply_deck_gain(deck)


func _create_deck(id: String) -> MusicDeck:
	var ambient: AudioStream
	var combat: AudioStream
	var deck := MusicDeck.new()
	deck.id = id
	if id == LEGACY_DECK:
		ambient = _loop_copy(_streams.get("ambient"))
		combat = _loop_copy(_streams.get("combat_pulse"))
		deck.ambient_floor = 0.22
	else:
		ambient = _streams.get(_stem_key(id, "ambient"))
		combat = _streams.get(_stem_key(id, "combat"))
		deck.trim_db = float(CHAPTERS.get(id, {}).get("trim_db", 0.0))
	if ambient == null and combat == null:
		return null
	deck.sync = AudioStreamSynchronized.new()
	deck.sync.stream_count = 2
	deck.sync.set_sync_stream(0, ambient)
	deck.sync.set_sync_stream(1, combat)
	deck.player = AudioStreamPlayer.new()
	deck.player.name = "Music_%s" % id
	deck.player.stream = deck.sync
	deck.p = 0.0
	deck.target = 1.0
	_apply_deck_gain(deck)
	add_child(deck.player)
	if is_inside_tree():
		deck.player.play()
	_decks.append(deck)
	return deck


func _apply_deck_gain(deck: MusicDeck) -> void:
	if deck.sync != null:
		deck.sync.set_sync_stream_volume(0, AMBIENT_DB + linear_to_db(lerpf(1.0, deck.ambient_floor, _combat_mix)))
		deck.sync.set_sync_stream_volume(1, COMBAT_DB + linear_to_db(maxf(_combat_mix, 0.0001)))
	if is_instance_valid(deck.player):
		var amp := sin(clampf(deck.p, 0.0, 1.0) * PI * 0.5)
		deck.player.volume_db = maxf(linear_to_db(maxf(amp, 0.0001)), SILENT_DB) + deck.trim_db + _duck_db


func _free_deck(deck: MusicDeck) -> void:
	_decks.erase(deck)
	if is_instance_valid(deck.player):
		deck.player.stop()
		deck.player.stream = null
		deck.player.queue_free()
	deck.player = null
	if deck.sync != null:
		for i in 2:
			deck.sync.set_sync_stream(i, null)
	deck.sync = null


func _loop_copy(source: AudioStream) -> AudioStream:
	var wav := source as AudioStreamWAV
	if wav == null:
		return source
	var stream := wav.duplicate() as AudioStreamWAV
	stream.loop_begin = 0
	stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	return stream


func _start_loop(sname: String, vol_db: float) -> AudioStreamPlayer:
	var stream := _loop_copy(_streams.get(sname))
	if stream == null:
		return null
	var voice := AudioStreamPlayer.new()
	voice.stream = stream
	voice.volume_db = vol_db
	add_child(voice)
	voice.play()
	return voice


static func _stem_key(chapter_id: String, stem: String) -> String:
	return "music_%s_%s" % [chapter_id, stem]


static func loop_seconds(chapter_id: String) -> float:
	return 16.0 * 60.0 / float(CHAPTERS.get(chapter_id, {}).get("bpm", 96.0))


# --------------------------------------------------------------------------------------------
# Stream cache + background synthesis
# --------------------------------------------------------------------------------------------

func _resolve(sname: String) -> String:
	return str(ALIASES.get(sname, sname))


func _is_known(key: String) -> bool:
	return _streams.has(key) or STORY_LENGTHS.has(key) or SYNTH_LENGTHS.has(key)


func _speaker_key(cue_id: String) -> String:
	var key := cue_id.to_lower().strip_edges()
	for prefix: String in ["vo_chime_", "vo_grain_", "vo_", "cue_"]:
		if key.begins_with(prefix):
			key = key.substr(prefix.length())
			break
	if key == "choir_breath":
		key = "choir"
	return str(SPEAKER_ALIASES.get(key, key))


func _ensure_stream(sname: String) -> AudioStream:
	var key := _resolve(sname)
	if _streams.has(key):
		return _streams[key]
	if _jobs.has(key):
		_complete_job(key)
	if not _streams.has(key):
		var job := _make_job(key)
		if job == null:
			return null
		_run_job(job)
		_finalize(job)
	return _streams.get(key)


func _make_job(key: String) -> SynthJob:
	var job := SynthJob.new()
	job.key = key
	if SYNTH_LENGTHS.has(key):
		job.kind = JobKind.LEGACY
		job.duration = SYNTH_LENGTHS[key]
	elif STORY_LENGTHS.has(key):
		job.kind = JobKind.STORY
		job.duration = STORY_LENGTHS[key]
	elif key.begins_with("vo_grain_"):
		var speaker := key.trim_prefix("vo_grain_")
		job.variant = "tube" if speaker.ends_with("_tube") else ""
		speaker = speaker.trim_suffix("_tube")
		if not SPEAKERS.has(speaker):
			return null
		job.kind = JobKind.GRAIN
		job.arg = speaker
		job.rate = GRAIN_RATE
		job.duration = float(GRAIN_SYLLABLES) / float(SPEAKERS[speaker].get("rate", 5.0)) + 0.08
	elif key.begins_with("music_"):
		for id: String in CHAPTERS:
			for stem: String in ["ambient", "combat"]:
				if key == _stem_key(id, stem):
					job.kind = JobKind.STEM
					job.arg = id
					job.variant = stem
					job.rate = MUSIC_RATE
					job.duration = loop_seconds(id)
					job.loop = true
		if job.kind != JobKind.STEM:
			return null
	else:
		return null
	return job


func _queue_job(key: String, high_priority: bool = false) -> void:
	if _streams.has(key) or _jobs.has(key):
		return
	var job := _make_job(key)
	if job == null:
		return
	job.task_id = WorkerThreadPool.add_task(_run_job.bind(job), high_priority, "Audio3D " + key)
	_jobs[key] = job


## Re-queue a not-yet-started background job at high priority (e.g. the stems of the chapter that is
## loading right now). The superseded task is retired, skipped by its worker, and reaped in tick.
func _prioritize_job(key: String) -> void:
	var job: SynthJob = _jobs.get(key)
	if job != null and not job.started:
		job.cancelled = true
		_retired_jobs.append(job)
		_jobs.erase(key)
	_queue_job(key, true)


func _complete_job(key: String) -> void:
	var job: SynthJob = _jobs.get(key)
	if job == null:
		return
	_jobs.erase(key)
	WorkerThreadPool.wait_for_task_completion(job.task_id)
	if not job.cancelled and not job.pcm.is_empty():
		_finalize(job)


func _poll_jobs() -> void:
	for i in range(_retired_jobs.size() - 1, -1, -1):
		if WorkerThreadPool.is_task_completed(_retired_jobs[i].task_id):
			WorkerThreadPool.wait_for_task_completion(_retired_jobs[i].task_id)
			_retired_jobs.remove_at(i)
	if _jobs.is_empty():
		return
	for key: String in _jobs.keys():
		var job: SynthJob = _jobs[key]
		if WorkerThreadPool.is_task_completed(job.task_id):
			_complete_job(key)


func _cancel_jobs() -> void:
	for job: SynthJob in _jobs.values():
		job.cancelled = true
	for job: SynthJob in _jobs.values():
		WorkerThreadPool.wait_for_task_completion(job.task_id)
	for job: SynthJob in _retired_jobs:
		WorkerThreadPool.wait_for_task_completion(job.task_id)
	_jobs.clear()
	_retired_jobs.clear()


func _finalize(job: SynthJob) -> void:
	if job.pcm.is_empty():
		return
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = job.rate
	stream.stereo = false
	stream.data = job.pcm
	if job.loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = job.pcm.size() / 2
	else:
		stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	_streams[job.key] = stream
	job.pcm = PackedByteArray()


## Thread entry point. Pure function of the job description: no scene-tree access.
static func _run_job(job: SynthJob) -> void:
	job.started = true
	if job.cancelled:
		return
	var buf: PackedFloat32Array
	match job.kind:
		JobKind.LEGACY:
			buf = _render_legacy(job.key, job.duration)
		JobKind.STORY:
			buf = _render_story(job.key, job.duration, job.rate)
			_finish_oneshot(buf, job.rate)
		JobKind.GRAIN:
			buf = _render_grain(job.arg, job.variant == "tube", job.rate, job.duration)
			_finish_oneshot(buf, job.rate)
		JobKind.STEM:
			buf = _render_stem(job.arg, job.variant, job.rate, job.duration, job)
			_normalize(buf, STEM_PEAK)
	if job.cancelled:
		return
	job.pcm = _encode(buf)


func _synthesize(sname: String, duration: float) -> AudioStreamWAV:
	var job := SynthJob.new()
	job.key = sname
	job.kind = JobKind.LEGACY
	job.duration = duration
	_run_job(job)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = job.pcm
	return stream


func _configure_reverb(bus: StringName, room_size: float, damping: float, wet: float, predelay: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		var bus_count := AudioServer.get_bus_count()
		AudioServer.add_bus()
		if AudioServer.get_bus_count() <= bus_count:
			return
		AudioServer.set_bus_name(bus_count, bus)
		index = AudioServer.get_bus_index(bus)
	if index <= 0:
		return
	for effect_index in AudioServer.get_bus_effect_count(index):
		if AudioServer.get_bus_effect(index, effect_index) is AudioEffectReverb:
			return
	var reverb := AudioEffectReverb.new()
	reverb.room_size = room_size
	reverb.damping = damping
	reverb.wet = wet
	reverb.dry = 1.0
	reverb.predelay_msec = predelay
	AudioServer.add_bus_effect(index, reverb)


# --------------------------------------------------------------------------------------------
# DSP helpers (static, thread-safe). Packed arrays are passed by reference.
# --------------------------------------------------------------------------------------------

static func _encode(buf: PackedFloat32Array) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, roundi(clampf(buf[i], -1.0, 1.0) * 32767.0))
	return bytes


static func _normalize(buf: PackedFloat32Array, peak: float) -> void:
	var top := 0.0
	for v in buf:
		top = maxf(top, absf(v))
	if top < 0.000001:
		return
	var gain := peak / top
	for i in buf.size():
		buf[i] *= gain


static func _finish_oneshot(buf: PackedFloat32Array, rate: int) -> void:
	_normalize(buf, ONESHOT_PEAK)
	var n := buf.size()
	var fade_in := mini(maxi(1, roundi(0.002 * rate)), n)
	var fade_out := mini(maxi(1, roundi(0.04 * rate)), n)
	for i in fade_in:
		buf[i] *= float(i) / fade_in
	for i in fade_out:
		buf[n - 1 - i] *= float(i) / fade_out


static func _snap(freq: float, loop_len: float) -> float:
	return maxf(1.0, roundf(freq * loop_len)) / loop_len


static func _coef(fc: float, rate: float) -> float:
	return 1.0 - exp(-TAU * fc / rate)


static func _svf_f(fc: float, rate: float) -> float:
	return 2.0 * sin(PI * minf(fc, rate * 0.16) / rate)


static func _smooth(x: float) -> float:
	var c := clampf(x, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)


static func _new_buf(frames: int) -> PackedFloat32Array:
	var buf := PackedFloat32Array()
	buf.resize(maxi(frames, 1))
	buf.fill(0.0)
	return buf


## Exponentially decaying sine added at `start`; wrap=true folds the tail into the loop head.
static func _add_tone(buf: PackedFloat32Array, rate: float, start: float, freq: float, decay: float, gain: float, length: float, wrap: bool = false) -> void:
	var n := buf.size()
	var s := roundi(start * rate)
	if wrap:
		s = posmod(s, n)
	elif s >= n:
		return
	var count := mini(roundi(length * rate), n)
	var w := TAU * freq / rate
	var k := exp(-decay / rate)
	var env := gain
	var floor_env := absf(gain) * 0.00002
	var atk := maxi(1, roundi(0.0015 * rate))
	var rel := maxi(1, roundi(0.012 * rate))
	for j in count:
		var idx := s + j
		if idx >= n:
			if not wrap:
				return
			idx -= n
		var shape := 1.0
		if j < atk:
			shape = float(j) / atk
		elif j > count - rel:
			shape = float(count - j) / rel
		buf[idx] += env * shape * sin(w * j)
		env *= k
		if absf(env) < floor_env:
			return


## Inharmonic struck partial set (bell / anvil / glass). Higher partials decay faster.
static func _add_bell(buf: PackedFloat32Array, rate: float, start: float, f0: float, ratios: PackedFloat32Array, amps: PackedFloat32Array, base_decay: float, gain: float, length: float, wrap: bool = false) -> void:
	for p in ratios.size():
		var f := f0 * ratios[p]
		if f >= rate * 0.45:
			continue
		_add_tone(buf, rate, start, f, base_decay * (1.0 + 0.55 * p), gain * amps[p], length, wrap)


## Pitch-swept sine (drum, thump, clunk).
static func _add_thump(buf: PackedFloat32Array, rate: float, start: float, f_hi: float, f_lo: float, sweep: float, decay: float, gain: float, length: float, wrap: bool = false) -> void:
	var n := buf.size()
	var s := roundi(start * rate)
	if wrap:
		s = posmod(s, n)
	elif s >= n:
		return
	var count := mini(roundi(length * rate), n)
	var k := exp(-decay / rate)
	var ks := exp(-sweep / rate)
	var es := 1.0
	var env := gain
	var phase := 0.0
	var atk := maxi(1, roundi(0.001 * rate))
	var rel := maxi(1, roundi(0.015 * rate))
	for j in count:
		var idx := s + j
		if idx >= n:
			if not wrap:
				return
			idx -= n
		var shape := 1.0
		if j < atk:
			shape = float(j) / atk
		elif j > count - rel:
			shape = float(count - j) / rel
		buf[idx] += env * shape * sin(phase)
		phase += TAU * (f_lo + (f_hi - f_lo) * es) / rate
		es *= ks
		env *= k


## Decaying noise burst through one-pole low-pass (lp_hz) and high-pass (hp_hz); RMS-compensated.
static func _add_noise(buf: PackedFloat32Array, rate: float, start: float, length: float, decay: float, gain: float, lp_hz: float, hp_hz: float, rng: RandomNumberGenerator, wrap: bool = false) -> void:
	var n := buf.size()
	var s := roundi(start * rate)
	if wrap:
		s = posmod(s, n)
	elif s >= n:
		return
	var count := mini(roundi(length * rate), n)
	var a_lp := _coef(lp_hz, rate) if lp_hz > 0.0 else 1.0
	var a_hp := _coef(hp_hz, rate) if hp_hz > 0.0 else 0.0
	var comp := minf(sqrt((2.0 - a_lp) / a_lp), 14.0)
	var k := exp(-decay / rate)
	var env := gain * comp
	var lp := 0.0
	var hp := 0.0
	var atk := maxi(1, roundi(0.0008 * rate))
	var rel := maxi(1, roundi(0.01 * rate))
	for j in count:
		var idx := s + j
		if idx >= n:
			if not wrap:
				return
			idx -= n
		lp += (rng.randf_range(-1.0, 1.0) - lp) * a_lp
		var y := lp
		if a_hp > 0.0:
			hp += (y - hp) * a_hp
			y -= hp
		var shape := 1.0
		if j < atk:
			shape = float(j) / atk
		elif j > count - rel:
			shape = float(count - j) / rel
		buf[idx] += env * shape * y
		env *= k


## Decaying band-passed noise (state-variable filter, damping q); RMS-compensated.
static func _add_band(buf: PackedFloat32Array, rate: float, start: float, length: float, decay: float, gain: float, fc: float, q: float, rng: RandomNumberGenerator, wrap: bool = false) -> void:
	var n := buf.size()
	var s := roundi(start * rate)
	if wrap:
		s = posmod(s, n)
	elif s >= n:
		return
	var count := mini(roundi(length * rate), n)
	var f := _svf_f(fc, rate)
	var comp := minf(sqrt(q * rate / (2.0 * maxf(fc, 20.0))), 20.0) * q
	var k := exp(-decay / rate)
	var env := gain * comp
	var lo := 0.0
	var ba := 0.0
	var atk := maxi(1, roundi(0.0008 * rate))
	var rel := maxi(1, roundi(0.01 * rate))
	for j in count:
		var idx := s + j
		if idx >= n:
			if not wrap:
				return
			idx -= n
		lo += f * ba
		var hi := rng.randf_range(-1.0, 1.0) - lo - q * ba
		ba += f * hi
		var shape := 1.0
		if j < atk:
			shape = float(j) / atk
		elif j > count - rel:
			shape = float(count - j) / rel
		buf[idx] += env * shape * ba
		env *= k


## Upward "blub" bubble: sine whose pitch rises while it decays.
static func _add_blub(buf: PackedFloat32Array, rate: float, start: float, f_lo: float, f_hi: float, gain: float, wrap: bool = false) -> void:
	_add_thump(buf, rate, start, f_lo, f_hi, 40.0, 26.0, gain, 0.16, wrap)


## Feedback comb filter in place.
static func _comb(buf: PackedFloat32Array, delay: int, feedback: float) -> void:
	for i in range(delay, buf.size()):
		buf[i] += feedback * buf[i - delay]


static func _aborted(job: SynthJob) -> bool:
	return job != null and job.cancelled


static func _periodic_noise(frames: int, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var noise := PackedFloat32Array()
	noise.resize(frames)
	for i in frames:
		noise[i] = rng.randf_range(-1.0, 1.0)
	return noise


# --------------------------------------------------------------------------------------------
# Legacy synth cues (unchanged sound)
# --------------------------------------------------------------------------------------------

static func _render_legacy(sname: String, duration: float) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = sname.hash()
	var frames := roundi(duration * SAMPLE_RATE)
	var buf := _new_buf(frames)
	var low_noise := 0.0
	for frame in frames:
		var time := float(frame) / SAMPLE_RATE
		var noise := rng.randf_range(-1.0, 1.0)
		low_noise = lerpf(low_noise, noise, 0.18)
		var sample := _sample(sname, time, noise, low_noise)
		if sname != "combat_pulse":
			sample *= minf(1.0, time / 0.002) * minf(1.0, (duration - time) / 0.04)
		buf[frame] = sample
	return buf


static func _sample(sname: String, time: float, noise: float, low_noise: float) -> float:
	match sname:
		"parry":
			var ring := 0.38 * sin(TAU * 742.0 * time) + 0.22 * sin(TAU * 1399.0 * time)
			var shimmer := 0.19 * sin(TAU * 2131.0 * time) + 0.11 * sin(TAU * 3067.0 * time)
			return ring * exp(-7.5 * time) + (shimmer + 0.28 * noise) * exp(-48.0 * time)
		"voltaic":
			var crackle := 0.35 + 0.65 * pow(maxf(0.0, sin(TAU * 43.0 * time)), 3.0)
			var pitch_sweep := 240.0 * time + 3.8 * (1.0 - exp(-64.0 * time))
			return (0.6 * noise * crackle + 0.36 * sin(TAU * pitch_sweep)) * exp(-17.0 * time)
		"stalker":
			var click := sin(TAU * 580.0 * time) * exp(-42.0 * fposmod(time, 0.083))
			var rasp := 0.52 * (noise - low_noise) * (1.0 - exp(-44.0 * time))
			return (0.27 * click + rasp) * exp(-7.0 * time)
		"splash":
			var wash := 0.58 * low_noise + 0.16 * noise
			var plunge := sin(TAU * (33.0 * time + 1.6 * (1.0 - exp(-38.0 * time))))
			var bubbles := sin(TAU * 194.0 * time) * pow(maxf(0.0, sin(TAU * 19.0 * time)), 5.0)
			return wash * exp(-5.8 * time) + 0.37 * plunge * exp(-19.0 * time) + 0.13 * bubbles * exp(-5.0 * time)
		"lift":
			var link_age := fposmod(time, 0.109)
			var chain := 0.20 * sin(TAU * 1693.0 * link_age) + 0.17 * noise
			var rumble := 0.28 * sin(TAU * 38.0 * time) + 0.16 * low_noise
			return (chain * exp(-37.0 * link_age) + rumble) * sin(PI * time / 1.20)
		"alarm":
			var swell := (1.0 - exp(-25.0 * time)) * exp(-1.35 * time)
			var phase := TAU * 92.0 * time + 0.30 * sin(TAU * 5.0 * time)
			var horn := 0.56 * sin(phase) + 0.19 * sin(2.0 * phase) + 0.13 * sin(3.0 * phase)
			return swell * (horn + 0.09 * sin(TAU * 247.0 * time))
		"combat_pulse":
			var beat := floori(time / 0.4)
			var beat_age := time - beat * 0.4
			var pitch_hz := 41.25 if beat < 8 else 36.71
			var bass := 0.32 * sin(TAU * pitch_hz * beat_age) * exp(-19.0 * beat_age)
			var kick := 0.38 * sin(TAU * (49.0 * beat_age + 1.8 * (1.0 - exp(-44.0 * beat_age)))) * exp(-24.0 * beat_age)
			var accent := 0.13 * low_noise * exp(-35.0 * beat_age)
			var weight := 1.0 if beat % 4 == 0 or beat % 4 == 3 else 0.54
			return weight * (bass + kick + accent) * minf(1.0, beat_age / 0.004) * minf(1.0, (0.4 - beat_age) / 0.012)
	return 0.0


# --------------------------------------------------------------------------------------------
# Story foley + speaker chimes (§6.6)
# --------------------------------------------------------------------------------------------

const BELL_RATIOS := [1.0, 2.4, 3.9, 5.4]
const BRONZE_RATIOS := [0.5, 1.0, 1.19, 1.5, 2.0, 2.52, 2.66, 3.17]
const BRONZE_AMPS := [0.55, 0.42, 0.34, 0.22, 0.30, 0.13, 0.10, 0.07]
const ANVIL_RATIOS := [1.0, 2.76, 5.40, 8.93]
const ANVIL_AMPS := [0.62, 0.40, 0.24, 0.12]
const GLASS_RATIOS := [1.0, 2.76, 5.40]
const GLASS_AMPS := [0.55, 0.22, 0.09]


static func _render_story(sname: String, duration: float, rate_i: int) -> PackedFloat32Array:
	var r := float(rate_i)
	var n := roundi(duration * r)
	var buf := _new_buf(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = ("story/" + sname).hash()
	match sname:
		"bell_crack":
			var f0 := 233.08
			var drop := 1.0 - pow(2.0, -40.0 / 1200.0)
			var ratios := PackedFloat32Array(BELL_RATIOS)
			var amps := PackedFloat32Array([0.55, 0.32, 0.2, 0.12])
			var fb := _svf_f(2200.0, r)
			var lo := 0.0
			var ba := 0.0
			for i in n:
				var t := i / r
				var pt := t - drop * (t * t / 0.8 if t < 0.4 else t - 0.2)
				var bell := 0.0
				for p in 4:
					bell += amps[p] * sin(TAU * f0 * ratios[p] * pt) * exp(-(0.3 + 0.55 * p) * t)
				var crack := 0.2 * sin(TAU * f0 * 2.4 * 1.013 * pt) * exp(-1.4 * t)
				lo += fb * ba
				var hi := rng.randf_range(-1.0, 1.0) - lo - 0.22 * ba
				ba += fb * hi
				var burst := 0.32 * ba * exp(-26.0 * t)
				var glass := 0.16 * sin(TAU * 3100.0 * t) * exp(-3.0 * t) + 0.06 * sin(TAU * 4870.0 * t) * exp(-6.0 * t)
				buf[i] = (bell + crack + burst + glass) * exp(-1.1 * t)
		"resonance_wave":
			var lo := 0.0
			for i in n:
				var t := i / r
				var sub := sin(TAU * (18.0 * t + 24.0 * (1.0 - exp(-1.6 * t)) / 1.6))
				var swell := (1.0 - exp(-7.0 * t)) * exp(-1.3 * t)
				var shimmer := 0.5 * (sin(TAU * 880.0 * t) + sin(TAU * 890.0 * t)) * sin(PI * minf(t / duration, 1.0))
				var ring := (0.3 * sin(TAU * 233.0 * t) + 0.2 * sin(TAU * 547.0 * t + 0.4) + 0.12 * sin(TAU * 913.0 * t)) * exp(-2.6 * t)
				lo += (rng.randf_range(-1.0, 1.0) - lo) * 0.02
				buf[i] = swell * (0.9 * sub + 0.12 * shimmer + 0.6 * lo) + 0.4 * ring
		"collapse":
			var lo := 0.0
			var lo2 := 0.0
			var a_r := _coef(90.0, r)
			for i in n:
				var t := i / r
				var x := rng.randf_range(-1.0, 1.0)
				lo += (x - lo) * a_r
				lo2 += (lo - lo2) * a_r
				var fracture := 0.5 * (x - lo) * exp(-10.0 * t)
				var rumble := 7.0 * lo2 * (1.0 - exp(-9.0 * t)) * exp(-1.4 * t)
				buf[i] = fracture + rumble
			for e in 10:
				var at := 0.04 + rng.randf_range(0.0, 1.45) * (0.4 + 0.6 * float(e) / 10.0)
				var g := rng.randf_range(0.35, 0.8) * (1.0 - 0.05 * e)
				_add_noise(buf, r, at, 0.3, 16.0, 0.45 * g, rng.randf_range(600.0, 1900.0), 120.0, rng)
				_add_thump(buf, r, at, rng.randf_range(80.0, 130.0), 38.0, 30.0, 12.0, 0.6 * g, 0.4)
		"rubble":
			for e in 6:
				var at := rng.randf_range(0.0, 0.9)
				_add_noise(buf, r, at, 0.45, 9.0, rng.randf_range(0.5, 0.9), 300.0, 30.0, rng)
				_add_thump(buf, r, at, 95.0, 45.0, 25.0, 14.0, 0.3, 0.3)
			for e in 12:
				_add_noise(buf, r, rng.randf_range(0.02, 1.1), 0.05, 70.0, rng.randf_range(0.08, 0.2), 2400.0, 500.0, rng)
		"glass_burst":
			var lo := 0.0
			var a3 := _coef(3000.0, r)
			for i in n:
				var t := i / r
				var x := rng.randf_range(-1.0, 1.0)
				lo += (x - lo) * a3
				buf[i] = 0.7 * (x - lo) * exp(-14.0 * t)
			for e in 8:
				_add_bell(buf, r, rng.randf_range(0.02, 0.5), rng.randf_range(2000.0, 6000.0) / 2.0, PackedFloat32Array([2.0, 2.76 * 1.4]), PackedFloat32Array([1.0, 0.35]), rng.randf_range(9.0, 14.0), rng.randf_range(0.12, 0.25), 0.4)
		"door_groan":
			var lo := 0.0
			var lo2 := 0.0
			var ph := 0.0
			var fb := _svf_f(900.0, r)
			var blo := 0.0
			var bba := 0.0
			for i in n:
				var t := i / r
				var u := t / duration
				var f := lerpf(60.0, 48.0, u) * (1.0 + 0.02 * sin(TAU * 2.3 * t))
				ph = fposmod(ph + f / r, 1.0)
				var saw := 2.0 * ph - 1.0
				var a := _coef(320.0 + 260.0 * sin(PI * u), r)
				lo += (saw - lo) * a
				lo2 += (lo - lo2) * a
				var stick := pow(absf(sin(TAU * 7.0 * t + 1.3 * sin(TAU * 1.1 * t))), 3.0)
				blo += fb * bba
				var hi := rng.randf_range(-1.0, 1.0) - blo - 0.5 * bba
				bba += fb * hi
				var env := pow(sin(PI * u), 0.6)
				buf[i] = env * (0.8 * lo2 + 0.25 * bba * stick)
		"door_slam":
			_add_thump(buf, r, 0.0, 95.0, 44.0, 22.0, 9.0, 0.9, 0.8)
			_add_band(buf, r, 0.0, 0.12, 32.0, 0.55, 700.0, 0.6, rng)
			_add_tone(buf, r, 0.0, 212.0, 24.0, 0.35, 0.3)
			_add_noise(buf, r, 0.0, 0.05, 60.0, 0.3, 4000.0, 300.0, rng)
			_add_band(buf, r, 0.07, 0.15, 30.0, 0.18, 1100.0, 0.5, rng)
			_add_tone(buf, r, 0.07, 340.0, 30.0, 0.1, 0.2)
		"wind_gust":
			var lo := 0.0
			var ba := 0.0
			var lo_b := 0.0
			var ba_b := 0.0
			for i in n:
				var t := i / r
				var u := t / duration
				var fc := 300.0 + 600.0 * _smooth(u / 0.45) if u < 0.45 else 900.0 - 500.0 * _smooth((u - 0.45) / 0.55)
				var f := _svf_f(fc, r)
				var f2 := _svf_f(fc * 1.9, r)
				var x := rng.randf_range(-1.0, 1.0)
				lo += f * ba
				var hi := x - lo - 0.35 * ba
				ba += f * hi
				lo_b += f2 * ba_b
				var hi_b := x - lo_b - 0.12 * ba_b
				ba_b += f2 * hi_b
				var env := pow(sin(PI * u), 1.2) * (0.8 + 0.2 * sin(TAU * 3.1 * t + 2.0 * sin(TAU * 0.7 * t)))
				buf[i] = env * (ba + 0.18 * ba_b)
		"thunder_far":
			var l1 := 0.0
			var l2 := 0.0
			var l3 := 0.0
			var a := _coef(200.0, r)
			for i in n:
				var t := i / r
				var x := rng.randf_range(-1.0, 1.0)
				l1 += (x - l1) * a
				l2 += (l1 - l2) * a
				l3 += (l2 - l3) * a
				var env := (1.0 - exp(-2.6 * t)) * exp(-0.85 * t)
				env *= 0.55 + 0.25 * sin(TAU * 1.3 * t + 0.6) + 0.2 * sin(TAU * 0.47 * t + 2.0)
				buf[i] = 9.0 * l3 * env
			_add_noise(buf, r, 0.12, 0.6, 7.0, 0.35, 600.0, 60.0, rng)
			_add_noise(buf, r, 0.9, 0.9, 4.0, 0.25, 260.0, 30.0, rng)
		"chain_strain":
			var at := 0.0
			var gap := 0.12
			while at < duration - 0.06:
				var g := 0.35 + 0.5 * at / duration
				_add_tone(buf, r, at, 1700.0 * rng.randf_range(0.95, 1.08), 60.0, g * 0.5, 0.06)
				_add_tone(buf, r, at, 2900.0 * rng.randf_range(0.95, 1.05), 90.0, g * 0.2, 0.04)
				_add_noise(buf, r, at, 0.02, 160.0, g * 0.25, 7000.0, 1500.0, rng)
				at += gap
				gap = maxf(0.034, gap * 0.9)
			for i in n:
				var t := i / r
				var creak := sin(TAU * 110.0 * t + 0.8 * sin(TAU * 6.0 * t))
				buf[i] += 0.12 * creak * pow(t / duration, 1.5)
		"chain_snap":
			_add_bell(buf, r, 0.0, 2300.0, PackedFloat32Array([1.0, 1.61, 2.22]), PackedFloat32Array([0.7, 0.45, 0.3]), 8.0, 0.8, 0.6)
			_add_noise(buf, r, 0.0, 0.08, 60.0, 0.6, 9000.0, 1200.0, rng)
			for e in 7:
				var at := 0.05 + 0.06 * e + rng.randf_range(0.0, 0.03)
				var g := 0.35 * (1.0 - 0.1 * e)
				_add_tone(buf, r, at, rng.randf_range(1400.0, 2600.0), 70.0, g, 0.08)
				_add_noise(buf, r, at, 0.015, 200.0, g * 0.4, 6000.0, 1000.0, rng)
			_add_thump(buf, r, 0.36, 110.0, 60.0, 30.0, 18.0, 0.3, 0.2)
		"timber_groan":
			var lo := 0.0
			var a := _coef(900.0, r)
			for i in n:
				var t := i / r
				var u := t / duration
				var phase := TAU * 80.0 * t + 2.4 * sin(TAU * 3.0 * t)
				var tone := sin(phase) + 0.5 * sin(2.0 * phase + 0.3) + 0.3 * sin(3.0 * phase)
				var stick := 0.5 + 0.5 * pow(absf(sin(TAU * 11.0 * t + sin(TAU * 1.7 * t))), 4.0)
				var drive := tanh(1.8 * tone * stick) + 0.15 * rng.randf_range(-1.0, 1.0) * stick
				lo += (drive - lo) * a
				buf[i] = lo * pow(sin(PI * u), 0.7)
		"impact_deep":
			_add_thump(buf, r, 0.0, 58.0, 30.0, 6.0, 2.2, 1.0, 2.4)
			_add_noise(buf, r, 0.0, 2.4, 2.0, 0.35, 380.0, 25.0, rng)
			_add_noise(buf, r, 0.0, 0.1, 40.0, 0.4, 2500.0, 200.0, rng)
			_add_bell(buf, r, 0.0, 98.0, PackedFloat32Array([1.0, 2.4, 3.9]), PackedFloat32Array([0.5, 0.3, 0.18]), 1.4, 0.35, 2.4)
		"gear_grind":
			var lo := 0.0
			var a := _coef(600.0, r)
			var lo_g := 0.0
			for i in n:
				var t := i / r
				var jitter := 1.0 + 0.04 * sin(TAU * 4.3 * t) + 0.02 * sin(TAU * 13.0 * t)
				var sq := signf(sin(TAU * 24.0 * jitter * t))
				lo += (sq - lo) * a
				var teeth := pow(maxf(0.0, sin(TAU * 192.0 * jitter * t)), 6.0)
				var x := rng.randf_range(-1.0, 1.0)
				lo_g += (x - lo_g) * 0.35
				var env := (1.0 - exp(-20.0 * t)) * (1.0 - 0.3 * t)
				buf[i] = env * (0.55 * lo + 0.5 * (x - lo_g) * (0.3 + teeth))
		"hollow_rise":
			var lo := 0.0
			var ba := 0.0
			var lo2 := 0.0
			var ba2 := 0.0
			var f1 := _svf_f(700.0, r)
			var f2 := _svf_f(1400.0, r)
			for i in n:
				var t := i / r
				var u := t / duration
				var x := rng.randf_range(-1.0, 1.0)
				var scrape := 0.35 * x * pow(absf(sin(TAU * 2.6 * t)), 2.0) * (1.0 - u)
				lo += f1 * ba
				var hi := x - lo - 0.5 * ba
				ba += f1 * hi
				lo2 += f2 * ba2
				var hi2 := x - lo2 - 0.6 * ba2
				ba2 += f2 * hi2
				var breath := (ba + 0.6 * ba2) * pow(u, 2.2)
				buf[i] = scrape + 0.45 * breath
			_comb(buf, roundi(r / 1200.0), 0.82)
		"steam_ram":
			var lo := 0.0
			var a := _coef(1500.0, r)
			for i in n:
				var t := i / r
				var x := rng.randf_range(-1.0, 1.0)
				lo += (x - lo) * a
				var pressure := (1.0 - exp(-30.0 * t)) * (0.6 + 0.4 * exp(-2.0 * t)) * (0.85 + 0.15 * sin(TAU * 9.0 * t))
				pressure *= 1.0 - _smooth((t - 1.0) / 0.45)
				buf[i] = 0.55 * (x - lo) * pressure
			_add_thump(buf, r, 0.0, 80.0, 40.0, 20.0, 8.0, 0.8, 0.6)
			_add_bell(buf, r, 1.15, 310.0, PackedFloat32Array([1.0, 2.76]), PackedFloat32Array([0.5, 0.3]), 14.0, 0.4, 0.3)
			_add_thump(buf, r, 1.15, 120.0, 55.0, 30.0, 14.0, 0.5, 0.3)
		"quench_hiss":
			var lo := 0.0
			var a := _coef(3500.0, r)
			for i in n:
				var t := i / r
				var x := rng.randf_range(-1.0, 1.0)
				lo += (x - lo) * a
				var hiss := (x - lo) * minf(1.0, t / 0.005) * exp(-1.6 * t)
				var bubbles := sin(TAU * (194.0 + 60.0 * sin(TAU * 0.8 * t)) * t) * pow(maxf(0.0, sin(TAU * 19.0 * t)), 5.0)
				buf[i] = 0.6 * hiss + 0.12 * bubbles * exp(-1.2 * t)
			for e in 18:
				_add_noise(buf, r, rng.randf_range(0.0, 1.6), 0.02, 150.0, rng.randf_range(0.08, 0.2), 9000.0, 2000.0, rng)
		"key_turn":
			for e in 3:
				var at := 0.04 + 0.09 * e
				_add_tone(buf, r, at, rng.randf_range(2400.0, 3100.0), 90.0, 0.45, 0.06)
				_add_noise(buf, r, at, 0.02, 180.0, 0.4, 8000.0, 1500.0, rng)
			_add_thump(buf, r, 0.33, 130.0, 60.0, 30.0, 20.0, 0.8, 0.17)
			_add_bell(buf, r, 0.33, 410.0, PackedFloat32Array([1.0, 2.39, 3.7]), PackedFloat32Array([0.4, 0.22, 0.1]), 16.0, 0.6, 0.17)
		"iron_release":
			_add_thump(buf, r, 0.0, 72.0, 40.0, 14.0, 5.0, 1.0, 1.0)
			_add_bell(buf, r, 0.0, 180.0, PackedFloat32Array([1.0, 2.4, 3.9, 5.63]), PackedFloat32Array([0.45, 0.3, 0.18, 0.1]), 2.2, 0.55, 1.6)
			_add_noise(buf, r, 0.0, 0.12, 30.0, 0.45, 1500.0, 80.0, rng)
		"gate_grind":
			var lo := 0.0
			var lo2 := 0.0
			var ph := 0.0
			var a := _coef(300.0, r)
			var fb := _svf_f(500.0, r)
			var blo := 0.0
			var bba := 0.0
			var judder := 1.0
			var judder_target := 1.0
			var next_step := 0.0
			for i in n:
				var t := i / r
				if t >= next_step:
					next_step = t + rng.randf_range(0.08, 0.25)
					judder_target = rng.randf_range(0.35, 1.0)
				judder += (judder_target - judder) * 0.004
				ph = fposmod(ph + 35.0 * (0.92 + 0.08 * judder) / r, 1.0)
				lo += ((2.0 * ph - 1.0) - lo) * a
				lo2 += (lo - lo2) * a
				blo += fb * bba
				var hi := rng.randf_range(-1.0, 1.0) - blo - 0.45 * bba
				bba += fb * hi
				var env := (1.0 - exp(-4.0 * t)) * (1.0 - _smooth((t - 3.3) / 0.7))
				buf[i] = env * judder * (0.9 * lo2 + 0.3 * bba)
			for e in 3:
				var at := 0.6 + 1.05 * e + rng.randf_range(-0.1, 0.1)
				_add_thump(buf, r, at, 85.0, 40.0, 20.0, 10.0, 0.6, 0.5)
				_add_noise(buf, r, at, 0.1, 30.0, 0.3, 1200.0, 100.0, rng)
		"slag_surge":
			var l1 := 0.0
			var l2 := 0.0
			var a := _coef(250.0, r)
			for i in n:
				var t := i / r
				l1 += (rng.randf_range(-1.0, 1.0) - l1) * a
				l2 += (l1 - l2) * a
				var env := (1.0 - exp(-3.5 * t)) * exp(-0.9 * t) * (0.8 + 0.2 * sin(TAU * 2.2 * t))
				buf[i] = 6.0 * l2 * env
			for e in 12:
				_add_blub(buf, r, rng.randf_range(0.05, 1.7), rng.randf_range(60.0, 110.0), rng.randf_range(160.0, 280.0), rng.randf_range(0.25, 0.5))
		"choir_whisper":
			var lo := 0.0
			var ba := 0.0
			var fb := _svf_f(1200.0, r)
			var detune := PackedFloat32Array([1.0, 1.0046, 0.9958, 1.4983, 1.5031, 2.0])
			var amps := PackedFloat32Array([0.32, 0.28, 0.28, 0.2, 0.18, 0.1])
			for i in n:
				var t := i / r
				var u := t / duration
				var voices := 0.0
				for v in 6:
					var ph := TAU * 220.0 * detune[v] * t + 0.4 * sin(TAU * (4.6 + 0.3 * v) * t)
					voices += amps[v] * (sin(ph) + 0.35 * sin(2.0 * ph) + 0.12 * sin(3.0 * ph))
				lo += fb * ba
				var hi := rng.randf_range(-1.0, 1.0) - lo - 0.7 * ba
				ba += fb * hi
				var env := pow(sin(PI * u), 1.5)
				buf[i] = env * (0.55 * voices + 0.5 * ba * (0.7 + 0.3 * sin(TAU * 1.7 * t)))
		"flood_rush":
			var lo := 0.0
			var lo_s := 0.0
			var hp := 0.0
			var a := _coef(2500.0, r)
			var a_s := _coef(120.0, r)
			var a_h := _coef(200.0, r)
			for i in n:
				var t := i / r
				var x := rng.randf_range(-1.0, 1.0)
				lo += (x - lo) * a
				hp += (lo - hp) * a_h
				lo_s += (x - lo_s) * a_s
				var env := (1.0 - exp(-3.0 * t)) * (1.0 - _smooth((t - 1.4) / 0.8))
				var surge := 0.6 + 0.4 * sin(TAU * 1.1 * t - 1.2)
				buf[i] = env * (0.5 * (lo - hp) + 5.0 * lo_s * surge)
			for e in 14:
				_add_tone(buf, r, rng.randf_range(0.2, 1.8), rng.randf_range(500.0, 1400.0), 40.0, rng.randf_range(0.05, 0.12), 0.1)
		"underwater_bell":
			var l1 := 0.0
			var l2 := 0.0
			var a := _coef(400.0, r)
			var ratios := PackedFloat32Array(BELL_RATIOS)
			var amps := PackedFloat32Array([0.6, 0.35, 0.22, 0.14])
			for i in n:
				var t := i / r
				var wob := 0.004 * sin(TAU * 0.9 * t)
				var bell := 0.0
				for p in 4:
					bell += amps[p] * sin(TAU * 196.0 * ratios[p] * (t + wob)) * exp(-(0.9 + 0.6 * p) * t)
				l1 += (bell - l1) * a
				l2 += (l1 - l2) * a
				buf[i] = l2
			for e in 6:
				_add_blub(buf, r, rng.randf_range(0.1, 2.0), rng.randf_range(300.0, 500.0), rng.randf_range(700.0, 1100.0), 0.05)
		"cue_seraphina":
			_add_bell(buf, r, 0.0, 880.0, PackedFloat32Array(GLASS_RATIOS), PackedFloat32Array(GLASS_AMPS), 7.0, 0.9, 0.55)
			_add_tone(buf, r, 0.0, 1764.0, 9.0, 0.16, 0.55)
			for e in 4:
				_add_band(buf, r, 0.04 + 0.03 * e, 0.035, 50.0, 0.12, 5000.0, 0.5, rng)
		"cue_guard":
			for e in 14:
				_add_band(buf, r, rng.randf_range(0.0, 0.25), 0.03, 120.0, rng.randf_range(0.15, 0.3), rng.randf_range(3000.0, 6000.0), 0.35, rng)
			var lo := 0.0
			var a := _coef(800.0, r)
			for i in n:
				var t := i / r
				var tone := sin(TAU * 98.0 * t) + 0.45 * sin(TAU * 196.0 * t) + 0.2 * sin(TAU * 294.0 * t)
				lo += (rng.randf_range(-1.0, 1.0) - lo) * a
				var creak := 0.15 * sin(TAU * 150.0 * t + 1.5 * sin(TAU * 9.0 * t)) * exp(-14.0 * maxf(t - 0.12, 0.0)) * minf(1.0, t / 0.12)
				buf[i] += (0.35 * tone + 0.6 * lo) * exp(-9.0 * t) * minf(1.0, t / 0.01) + creak
		"cue_malcor":
			_add_bell(buf, r, 0.0, 87.31, PackedFloat32Array([1.0, 2.0, 2.39, 3.0, 4.07, 5.33]), PackedFloat32Array([0.7, 0.45, 0.36, 0.22, 0.18, 0.1]), 1.6, 0.8, 1.2)
			_add_tone(buf, r, 0.0, 87.31 * 1.19 * 2.0, 2.2, 0.14, 1.2)
			_add_tone(buf, r, 0.0, 87.31 * 2.0 + 0.7, 1.8, 0.12, 1.2)
			var lo := 0.0
			var ba := 0.0
			var fb := _svf_f(600.0, r)
			for i in n:
				var t := i / r
				lo += fb * ba
				var hi := rng.randf_range(-1.0, 1.0) - lo - 0.8 * ba
				ba += fb * hi
				buf[i] += 0.18 * ba * pow(sin(PI * clampf((t - 0.3) / 0.85, 0.0, 1.0)), 2.0)
		"cue_choir":
			var lo := 0.0
			var ba := 0.0
			var fb := _svf_f(1800.0, r)
			var freqs := PackedFloat32Array([329.63, 349.23, 329.63 * 1.007])
			for i in n:
				var t := i / r
				var u := t / duration
				var cluster := 0.0
				for v in 3:
					var ph := TAU * freqs[v] * t
					cluster += sin(ph) + 0.3 * sin(2.0 * ph) + 0.1 * sin(3.0 * ph)
				lo += fb * ba
				var hi := rng.randf_range(-1.0, 1.0) - lo - 0.6 * ba
				ba += fb * hi
				var env := pow(u, 2.5) * minf(1.0, (duration - t) / 0.07)
				buf[i] = env * (0.3 * cluster + 0.4 * ba)
		"cue_ilse":
			for i in n:
				var t := i / r
				var first := t < 0.4
				var f := 1318.51 if first else 987.77
				var nt := t if first else t - 0.4
				var vib := 1.0 + 0.004 * sin(TAU * 5.5 * t) * minf(1.0, nt / 0.15)
				var ph := TAU * f * vib * nt
				var env := minf(1.0, nt / 0.04) * exp(-(5.0 if first else 3.6) * nt)
				if first:
					env *= minf(1.0, (0.4 - t) / 0.03)
				buf[i] = env * (0.5 * sin(ph) + 0.12 * sin(2.0 * ph) + 0.05 * sin(3.0 * ph))
			_add_tone(buf, r, 0.0, 2637.0, 10.0, 0.06, 0.4)
			_add_tone(buf, r, 0.4, 1975.5, 8.0, 0.06, 0.45)
		"vo_chime_echo":
			var shimmer := PackedFloat32Array([1046.5, 1568.0, 2093.0 * 1.003, 2637.0])
			var lo := 0.0
			var ba := 0.0
			for i in n:
				var t := i / r
				var tone := 0.0
				for p in 4:
					tone += sin(TAU * shimmer[p] * t + p) * (0.6 + 0.4 * sin(TAU * (7.0 + 2.3 * p) * t)) / (1.0 + p)
				var fc := 900.0 + 2400.0 * t / duration
				var f := _svf_f(fc, r)
				lo += f * ba
				var hi := rng.randf_range(-1.0, 1.0) - lo - 0.5 * ba
				ba += f * hi
				buf[i] = 0.45 * tone * minf(1.0, t / 0.01) * exp(-4.5 * t) + 0.12 * ba * sin(PI * t / duration)
		"vo_chime_king":
			var roots := PackedFloat32Array([65.41, 77.78, 98.0])
			var ratios := PackedFloat32Array(BRONZE_RATIOS)
			var amps := PackedFloat32Array(BRONZE_AMPS)
			for root in roots:
				_add_bell(buf, r, 0.0, root, ratios, amps, 0.7, 0.45, 1.7)
			_add_thump(buf, r, 0.0, 50.0, 32.7, 4.0, 0.9, 0.9, 1.7)
			_add_noise(buf, r, 0.0, 0.2, 18.0, 0.3, 1800.0, 80.0, rng)
			var cut := roundi(1.6 * r)
			var ramp := maxi(1, roundi(0.003 * r))
			for i in range(maxi(cut - ramp, 0), n):
				buf[i] *= clampf(float(cut - i) / ramp, 0.0, 1.0)
	return buf


## Formant voice grain: one syllable per 1/rate seconds, each occupying 70% of its slot so timed stops
## always land in silence. tube = 6 ms comb + 300-3000 Hz band (speaking tubes).
static func _render_grain(speaker: String, tube: bool, rate_i: int, duration: float) -> PackedFloat32Array:
	var profile: Dictionary = SPEAKERS.get(speaker, {})
	var r := float(rate_i)
	var n := roundi(duration * r)
	var buf := _new_buf(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = ("grain/" + speaker).hash()
	var f0: float = profile.get("f0", 150.0)
	var form1: float = profile.get("f1", 600.0)
	var form2: float = profile.get("f2", 1200.0)
	var syl_rate: float = profile.get("rate", 5.0)
	var voices: int = profile.get("voices", 1)
	var shift := PackedFloat32Array()
	var level := PackedFloat32Array()
	var bend := PackedFloat32Array()
	for k in GRAIN_SYLLABLES + 1:
		shift.append(rng.randf_range(0.84, 1.16))
		level.append(rng.randf_range(0.6, 1.0))
		bend.append(rng.randf_range(0.94, 1.06))
	var phases := PackedFloat32Array()
	phases.resize(voices)
	phases.fill(0.0)
	var lo1 := 0.0
	var ba1 := 0.0
	var lo2 := 0.0
	var ba2 := 0.0
	for i in n:
		var t := i / r
		var pos := t * syl_rate
		var k := mini(floori(pos), GRAIN_SYLLABLES)
		var u := pos - k
		var env := 0.0
		if u < 0.7 and k < GRAIN_SYLLABLES:
			env = pow(sin(PI * u / 0.7), 1.5) * level[k]
		var pitch := f0 * bend[k] * (1.0 + 0.06 * sin(PI * minf(u / 0.7, 1.0)))
		var src := 0.0
		for v in voices:
			var detune := 1.0 + 0.011 * (v - (voices - 1) * 0.5)
			phases[v] = fposmod(phases[v] + pitch * detune / r, 1.0)
			src += 2.0 * phases[v] - 1.0
		src = src / voices + 0.45 * rng.randf_range(-1.0, 1.0)
		var f1 := _svf_f(form1 * shift[k], r)
		var f2 := _svf_f(form2 * shift[k], r)
		lo1 += f1 * ba1
		var hi1 := src - lo1 - 0.22 * ba1
		ba1 += f1 * hi1
		lo2 += f2 * ba2
		var hi2 := src - lo2 - 0.28 * ba2
		ba2 += f2 * hi2
		buf[i] = env * (ba1 + 0.6 * ba2)
	if tube:
		var lp := 0.0
		var hp := 0.0
		var a_lp := _coef(3000.0, r)
		var a_hp := _coef(300.0, r)
		for i in n:
			lp += (buf[i] - lp) * a_lp
			hp += (lp - hp) * a_hp
			buf[i] = lp - hp
		_comb(buf, roundi(0.006 * r), 0.45)
	return buf


# --------------------------------------------------------------------------------------------
# Chapter music stems: seamless loops. Continuous layers use loop-periodic frequencies and periodic
# noise with filter warm-up; percussion events wrap their tails into the loop head.
# --------------------------------------------------------------------------------------------

static func _render_stem(chapter: String, stem: String, rate_i: int, loop_len: float, job: SynthJob = null) -> PackedFloat32Array:
	var r := float(rate_i)
	var n := roundi(loop_len * r)
	var buf := _new_buf(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = ("stem/%s/%s" % [chapter, stem]).hash()
	var noise := _periodic_noise(n, rng)
	var bar := loop_len / 4.0
	match chapter + "/" + stem:
		"ch1_court/ambient":
			_court_ambient(buf, noise, r, loop_len, bar, rng, job)
		"ch1_court/combat":
			_court_combat(buf, noise, r, loop_len, bar, rng, job)
		"ch2_tower/ambient":
			_tower_ambient(buf, noise, r, loop_len, bar, rng, job)
		"ch2_tower/combat":
			_tower_combat(buf, noise, r, loop_len, bar, rng, job)
		"ch3_kiln/ambient":
			_kiln_ambient(buf, noise, r, loop_len, bar, rng, job)
		"ch3_kiln/combat":
			_kiln_combat(buf, noise, r, loop_len, bar, rng, job)
	return buf


## Ch I: crypt drone (D), filtered wind, solemn organ fifths (D/A, D/A, Bb/F, A/E), hollow stone
## resonance, a muffled distant toll and water drips.
static func _court_ambient(buf: PackedFloat32Array, noise: PackedFloat32Array, r: float, L: float, bar: float, rng: RandomNumberGenerator, job: SynthJob) -> void:
	var n := buf.size()
	var d1 := _snap(73.42, L)
	var d2 := _snap(73.70, L)
	var d3 := _snap(36.71, L)
	var chords := [
		PackedFloat32Array([_snap(146.83, L), _snap(220.0, L)]),
		PackedFloat32Array([_snap(146.83, L), _snap(220.0, L)]),
		PackedFloat32Array([_snap(116.54, L), _snap(174.61, L)]),
		PackedFloat32Array([_snap(110.0, L), _snap(164.81, L)]),
	]
	var w1 := TAU / L
	var a_org := _coef(1100.0, r)
	var a_rum := _coef(160.0, r)
	var f_res1 := _svf_f(196.0, r)
	var f_res2 := _svf_f(293.66, r)
	var org := 0.0
	var rum := 0.0
	var wl := 0.0
	var wb := 0.0
	var r1l := 0.0
	var r1b := 0.0
	var r2l := 0.0
	var r2b := 0.0
	var warm := mini(n, roundi(2.0 * r))
	for i in range(-warm, n):
		if (i & 8191) == 0 and _aborted(job):
			return
		var t := float(i) / r
		var x := noise[posmod(i, n)]
		var drone := (sin(TAU * d1 * t) + 0.35 * sin(TAU * 2.0 * d1 * t) + 0.8 * sin(TAU * d2 * t) + 0.5 * sin(TAU * d3 * t)) * (0.75 + 0.25 * sin(w1 * t))
		var b := posmod(floori(t / bar), 4)
		var u := t - floorf(t / bar) * bar
		var cur: PackedFloat32Array = chords[b]
		var prev: PackedFloat32Array = chords[posmod(b - 1, 4)]
		var xf := _smooth(u / 0.9)
		var organ := 0.0
		for v in 2:
			var pc := TAU * cur[v] * t
			var pp := TAU * prev[v] * t
			organ += xf * (sin(pc) + 0.45 * sin(2.0 * pc) + 0.22 * sin(3.0 * pc) + 0.1 * sin(4.0 * pc))
			organ += (1.0 - xf) * (sin(pp) + 0.45 * sin(2.0 * pp) + 0.22 * sin(3.0 * pp) + 0.1 * sin(4.0 * pp))
		organ *= 0.6 + 0.4 * sin(PI * u / bar)
		org += (organ - org) * a_org
		var fc := 430.0 + 250.0 * sin(2.0 * w1 * t) + 110.0 * sin(5.0 * w1 * t + 1.3)
		var fw := _svf_f(fc, r)
		wl += fw * wb
		var wh := x - wl - 0.4 * wb
		wb += fw * wh
		var gust := 0.45 + 0.35 * sin(3.0 * w1 * t + 0.7) + 0.2 * sin(7.0 * w1 * t)
		rum += (x - rum) * a_rum
		r1l += f_res1 * r1b
		var r1h := x - r1l - 0.03 * r1b
		r1b += f_res1 * r1h
		r2l += f_res2 * r2b
		var r2h := x - r2l - 0.04 * r2b
		r2b += f_res2 * r2h
		if i >= 0:
			buf[i] = 0.22 * drone + 0.13 * org + 0.22 * wb * gust + 0.6 * rum + 0.012 * (r1b + 0.7 * r2b) * (0.6 + 0.4 * sin(w1 * t + 2.0))
	_add_bell(buf, r, 2.0 * bar, 73.42, PackedFloat32Array([1.0, 2.0, 2.4, 3.0, 4.0]), PackedFloat32Array([0.5, 0.3, 0.25, 0.12, 0.06]), 0.45, 0.22, L * 0.6, true)
	for e in 6:
		_add_tone(buf, r, rng.randf_range(0.0, L), rng.randf_range(1200.0, 2200.0), 38.0, 0.03, 0.2, true)


## Ch I combat: low skin-drum war rhythm with a fill on bar 4, dark sub-bass pulse following the chords.
static func _court_combat(buf: PackedFloat32Array, _noise: PackedFloat32Array, r: float, L: float, bar: float, rng: RandomNumberGenerator, job: SynthJob) -> void:
	var n := buf.size()
	var sixteenth := bar / 16.0
	var beat := bar / 4.0
	var roots := PackedFloat32Array([_snap(36.71, L), _snap(36.71, L), _snap(29.14, L), _snap(27.5, L)])
	for i in n:
		if (i & 8191) == 0 and _aborted(job):
			return
		var t := float(i) / r
		var b := posmod(floori(t / bar), 4)
		var u := t - floorf(t / bar) * bar
		var age := fposmod(t, beat)
		var xf := _smooth(u / 0.08)
		var sub := xf * sin(TAU * roots[b] * t) + (1.0 - xf) * sin(TAU * roots[posmod(b - 1, 4)] * t)
		buf[i] = 0.28 * sub * (0.3 + 0.7 * exp(-4.0 * age))
	var pattern := {0: 1.0, 3: 0.55, 6: 0.7, 8: 0.9, 10: 0.45, 11: 0.6, 14: 0.75}
	for b in 4:
		if _aborted(job):
			return
		var hits: Dictionary = pattern.duplicate()
		if b == 3:
			hits[12] = 0.5
			hits[13] = 0.62
			hits[15] = 0.85
		for s: int in hits:
			var v: float = hits[s] * rng.randf_range(0.92, 1.05)
			var at := b * bar + s * sixteenth
			_add_thump(buf, r, at, 140.0, 62.0, 30.0, 9.0, 0.7 * v, 0.7, true)
			_add_noise(buf, r, at, 0.06, 45.0, 0.22 * v, 1800.0, 200.0, rng, true)
		for s: int in [4, 12]:
			_add_thump(buf, r, b * bar + s * sixteenth, 185.0, 96.0, 28.0, 12.0, 0.4, 0.4, true)
		for k in 8:
			_add_noise(buf, r, b * bar + (k * 2 + 1) * sixteenth, 0.04, 70.0, 0.05, 0.0, 4000.0, rng, true)
		_add_tone(buf, r, b * bar, roots[b] * 2.0, 3.0, 0.3, 0.9, true)
		_add_tone(buf, r, b * bar + 2.0 * beat, roots[b] * 2.0, 3.0, 0.22, 0.9, true)


## Ch II: inharmonic bronze cathedral overtones with breathing amplitudes and slow beating twins,
## dark wind decay, distant bell strikes and rain ticks on stained glass.
static func _tower_ambient(buf: PackedFloat32Array, noise: PackedFloat32Array, r: float, L: float, bar: float, rng: RandomNumberGenerator, job: SynthJob) -> void:
	var n := buf.size()
	var base := 130.81
	var ratios := PackedFloat32Array(BRONZE_RATIOS)
	var amps := PackedFloat32Array(BRONZE_AMPS)
	var freqs := PackedFloat32Array()
	var twins := PackedFloat32Array()
	for p in ratios.size():
		freqs.append(_snap(base * ratios[p], L))
		twins.append(_snap(base * ratios[p], L) + float(1 + p % 3) / L)
	var w1 := TAU / L
	var a_w := _coef(300.0, r)
	var wl := 0.0
	var bl := 0.0
	var bb := 0.0
	var warm := mini(n, roundi(2.0 * r))
	for i in range(-warm, n):
		if (i & 8191) == 0 and _aborted(job):
			return
		var t := float(i) / r
		var x := noise[posmod(i, n)]
		var bronze := 0.0
		for p in freqs.size():
			var breathe := 0.55 + 0.45 * sin(float(1 + p % 4) * w1 * t + 0.9 * p)
			bronze += amps[p] * breathe * (sin(TAU * freqs[p] * t) + 0.7 * sin(TAU * twins[p] * t + 1.1))
		wl += (x - wl) * a_w
		var fc := 380.0 + 190.0 * sin(2.0 * w1 * t + 0.4)
		var fw := _svf_f(fc, r)
		bl += fw * bb
		var bh := x - bl - 0.5 * bb
		bb += fw * bh
		var swell := 0.5 + 0.3 * sin(w1 * t) + 0.2 * sin(3.0 * w1 * t + 1.7)
		if i >= 0:
			buf[i] = 0.07 * bronze + (1.4 * wl + 0.15 * bb) * swell
	_add_bell(buf, r, 0.0, base, ratios, amps, 0.4, 0.3, L * 0.7, true)
	_add_bell(buf, r, 2.0 * bar + 0.3, 196.0, ratios, amps, 0.6, 0.16, L * 0.5, true)
	for e in 40:
		_add_noise(buf, r, rng.randf_range(0.0, L), 0.012, 300.0, rng.randf_range(0.01, 0.025), 0.0, 3500.0, rng, true)


## Ch II combat: tense muted eighth-note pulse (C, C, Ab, G), timpani on 1 and 3, bronze bell accents
## on every bar turn, faint low string pad.
static func _tower_combat(buf: PackedFloat32Array, _noise: PackedFloat32Array, r: float, L: float, bar: float, rng: RandomNumberGenerator, job: SynthJob) -> void:
	var n := buf.size()
	var eighth := bar / 8.0
	var roots := PackedFloat32Array([65.41, 65.41, 51.91, 49.0])
	var pad_roots := PackedFloat32Array([_snap(130.81, L), _snap(130.81, L), _snap(103.83, L), _snap(98.0, L)])
	var a_pad := _coef(700.0, r)
	var pad := 0.0
	var warm := mini(n, roundi(0.5 * r))
	for i in range(-warm, n):
		if (i & 8191) == 0 and _aborted(job):
			return
		var t := float(i) / r
		var b := posmod(floori(t / bar), 4)
		var u := t - floorf(t / bar) * bar
		var xf := _smooth(u / 0.3)
		var pc := TAU * pad_roots[b] * t
		var pp := TAU * pad_roots[posmod(b - 1, 4)] * t
		var s := xf * (sin(pc) + 0.5 * sin(2.0 * pc) + 0.33 * sin(3.0 * pc)) + (1.0 - xf) * (sin(pp) + 0.5 * sin(2.0 * pp) + 0.33 * sin(3.0 * pp))
		pad += (s - pad) * a_pad
		if i >= 0:
			buf[i] = 0.05 * pad
	var accents := PackedFloat32Array([1.0, 0.5, 0.7, 0.5, 0.9, 0.5, 0.7, 0.62])
	var bell_ratios := PackedFloat32Array(BRONZE_RATIOS.slice(1, 7))
	var bell_amps := PackedFloat32Array(BRONZE_AMPS.slice(1, 7))
	for b in 4:
		if _aborted(job):
			return
		for e in 8:
			var at := b * bar + e * eighth
			var v := accents[e] * rng.randf_range(0.94, 1.04)
			var f := roots[b] * (2.0 if e % 4 == 3 else 1.0)
			_add_tone(buf, r, at, f, 14.0, 0.5 * v, 0.3, true)
			_add_tone(buf, r, at, f * 2.0, 20.0, 0.25 * v, 0.25, true)
			_add_tone(buf, r, at, f * 3.0, 26.0, 0.12 * v, 0.2, true)
			_add_noise(buf, r, at, 0.03, 80.0, 0.05 * v, 0.0, 5000.0, rng, true)
		_add_thump(buf, r, b * bar, 110.0, 65.0, 20.0, 5.0, 0.55, 0.8, true)
		_add_thump(buf, r, b * bar + 4.0 * eighth, 105.0, 63.0, 20.0, 5.5, 0.35, 0.7, true)
		var bell_gain := 0.42 if b == 0 else 0.3
		_add_bell(buf, r, b * bar, 261.63 if b != 2 else 207.65, bell_ratios, bell_amps, 1.3, bell_gain, 2.2, true)
	_add_bell(buf, r, 0.0, 130.81, bell_ratios, bell_amps, 0.8, 0.3, 3.0, true)


## Ch III: deep filtered furnace roar breathing with periodic bellows, A/E furnace hum, crackle and
## slag bubbling.
static func _kiln_ambient(buf: PackedFloat32Array, noise: PackedFloat32Array, r: float, L: float, bar: float, rng: RandomNumberGenerator, job: SynthJob) -> void:
	var n := buf.size()
	var w_bellows := TAU * 4.0 / L
	var w1 := TAU / L
	var h1 := _snap(55.0, L)
	var h2 := _snap(82.41, L)
	var h3 := _snap(110.3, L)
	var a1 := _coef(140.0, r)
	var l1 := 0.0
	var l2 := 0.0
	var f_b := _svf_f(320.0, r)
	var bl := 0.0
	var bb := 0.0
	var f_w := _svf_f(620.0, r)
	var wl := 0.0
	var wb := 0.0
	var warm := mini(n, roundi(2.0 * r))
	for i in range(-warm, n):
		if (i & 8191) == 0 and _aborted(job):
			return
		var t := float(i) / r
		var x := noise[posmod(i, n)]
		var breath := 0.5 + 0.5 * sin(w_bellows * t - PI * 0.5)
		breath = breath * breath
		l1 += (x - l1) * a1
		l2 += (l1 - l2) * a1
		bl += f_b * bb
		var bh := x - bl - 0.6 * bb
		bb += f_b * bh
		wl += f_w * wb
		var wh := x - wl - 0.8 * wb
		wb += f_w * wh
		var hum := (sin(TAU * h1 * t) + 0.5 * sin(TAU * h2 * t) + 0.25 * sin(TAU * h3 * t)) * (0.8 + 0.2 * sin(w1 * t))
		if i >= 0:
			buf[i] = (2.6 * l2 + 0.12 * bb) * (0.55 + 0.6 * breath) + 0.1 * wb * breath * breath * breath + 0.12 * hum
	for e in 30:
		_add_noise(buf, r, rng.randf_range(0.0, L), 0.015, 150.0, rng.randf_range(0.04, 0.1), 3000.0, 600.0, rng, true)
	for e in 10:
		_add_thump(buf, r, rng.randf_range(0.0, L), rng.randf_range(65.0, 90.0), rng.randf_range(160.0, 220.0), 40.0, 24.0, 0.09, 0.16, true)
	_add_bell(buf, r, 0.45 * L, 130.0, PackedFloat32Array([1.0, 2.39, 3.9]), PackedFloat32Array([0.5, 0.3, 0.15]), 1.5, 0.05, 2.5, true)


## Ch III combat: syncopated iron-anvil strikes, kick with "and of 2", heavy furnace bass (A, A, F, G),
## iron clank on beat 4.
static func _kiln_combat(buf: PackedFloat32Array, _noise: PackedFloat32Array, r: float, L: float, bar: float, rng: RandomNumberGenerator, job: SynthJob) -> void:
	var sixteenth := bar / 16.0
	var roots := PackedFloat32Array([55.0, 55.0, 43.65, 49.0])
	var anvil_r := PackedFloat32Array(ANVIL_RATIOS)
	var anvil_a := PackedFloat32Array(ANVIL_AMPS)
	var pattern := {0: 1.0, 3: 0.7, 6: 0.85, 10: 0.75, 11: 0.5, 14: 0.9}
	var fill := {0: 1.0, 3: 0.7, 6: 0.85, 8: 0.6, 10: 0.75, 12: 0.55, 13: 0.65, 14: 0.8, 15: 0.9}
	for b in 4:
		if _aborted(job):
			return
		var hits: Dictionary = fill if b == 3 else pattern
		var alt := 0
		for s: int in hits:
			var v: float = hits[s] * rng.randf_range(0.92, 1.05)
			var at := b * bar + s * sixteenth
			_add_bell(buf, r, at, 620.0 if alt % 2 == 0 else 587.0, anvil_r, anvil_a, 9.0, 0.36 * v, 0.9, true)
			_add_noise(buf, r, at, 0.02, 200.0, 0.25 * v, 0.0, 2000.0, rng, true)
			alt += 1
		for s: int in [0, 7, 8]:
			_add_thump(buf, r, b * bar + s * sixteenth, 120.0, 45.0, 35.0, 7.0, 0.75, 0.5, true)
		for s: int in [0, 7, 8, 14]:
			var at := b * bar + s * sixteenth
			for h in 4:
				_add_tone(buf, r, at, roots[b] * (h + 1), 5.0 + 2.0 * h, 0.32 / (h + 1), 0.6, true)
		_add_band(buf, r, b * bar + 12.0 * sixteenth, 0.25, 25.0, 0.2, 900.0, 0.3, rng, true)
		_add_tone(buf, r, b * bar + 12.0 * sixteenth, 330.0, 18.0, 0.12, 0.25, true)
