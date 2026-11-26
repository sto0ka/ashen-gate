class_name Audio3D
extends Node

const SAMPLE_RATE := 24000
const AMBIENT_DB := -17.0
const COMBAT_DB := -15.0
const WAV_NAMES := [
	"axe", "hit", "cast", "lever", "pickup", "ambient", "frost",
	"maul", "portal", "bell", "repulse", "step", "jump", "land",
]
const SYNTH_LENGTHS := {
	"parry": 0.62, "voltaic": 0.28, "stalker": 0.46, "splash": 0.72,
	"lift": 1.20, "alarm": 1.85, "combat_pulse": 6.40,
}
const REVERB_BUS := {"cathedral": &"Cathedral", "crypt": &"Crypt", "furnace": &"Furnace"}

var _streams: Dictionary = {}
var _voices: Dictionary = {}
var _ambient: AudioStreamPlayer
var _combat: AudioStreamPlayer
var _combat_target := 0.0
var _combat_mix := 0.0
var _room := "cathedral"


func setup(parent: Node) -> void:
	if get_parent() == null and parent != self:
		parent.add_child(self)
	if is_instance_valid(_ambient):
		return

	_configure_reverb(&"Cathedral", 0.86, 0.35, 0.33, 31.0)
	_configure_reverb(&"Crypt", 0.58, 0.69, 0.24, 12.0)
	_configure_reverb(&"Furnace", 0.72, 0.48, 0.19, 19.0)
	for sname: String in WAV_NAMES:
		var path := "res://audio/%s.wav" % sname
		if ResourceLoader.exists(path):
			_streams[sname] = load(path)
	for sname: String in SYNTH_LENGTHS:
		_streams[sname] = _synthesize(sname, SYNTH_LENGTHS[sname])

	_combat_target = 0.0
	_combat_mix = 0.0
	_ambient = _start_loop("ambient", AMBIENT_DB)
	_combat = _start_loop("combat_pulse", linear_to_db(0.0001))


func tick(delta: float) -> void:
	if not is_instance_valid(_ambient) or not is_instance_valid(_combat):
		return
	_combat_mix = move_toward(_combat_mix, _combat_target, maxf(delta, 0.0) * 0.7)
	_ambient.volume_db = AMBIENT_DB + linear_to_db(lerpf(1.0, 0.22, _combat_mix))
	_combat.volume_db = COMBAT_DB + linear_to_db(maxf(_combat_mix, 0.0001))


func set_room_acoustics(zone_type: String) -> void:
	_room = zone_type.to_lower()


func set_combat_intensity(in_combat: bool) -> void:
	_combat_target = 1.0 if in_combat else 0.0


func play_2d(sname: String, pitch: float = 1.0, vol_db: float = -6.0) -> void:
	var stream: AudioStream = _streams.get(sname)
	if stream == null or not is_inside_tree():
		return
	var voice := AudioStreamPlayer.new()
	voice.stream = stream
	voice.pitch_scale = maxf(pitch, 0.01)
	voice.volume_db = vol_db
	add_child(voice)
	_track_voice(voice, stream.get_length() / voice.pitch_scale)
	voice.finished.connect(voice.queue_free)
	voice.play()


func play_at(parent: Node3D, sname: String, pos: Vector3, pitch: float = 1.0, max_dist: float = 30.0) -> void:
	var stream: AudioStream = _streams.get(sname)
	if stream == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var voice := AudioStreamPlayer3D.new()
	voice.stream = stream
	voice.pitch_scale = maxf(pitch, 0.01)
	voice.max_distance = maxf(max_dist, 0.01)
	voice.volume_db = -6.0
	var bus: StringName = REVERB_BUS.get(_room, &"Master")
	if AudioServer.get_bus_index(bus) >= 0:
		voice.bus = bus
	parent.add_child(voice)
	voice.global_position = pos
	voice.top_level = true
	_track_voice(voice, stream.get_length() / voice.pitch_scale)
	voice.finished.connect(voice.queue_free)
	voice.play()


func stop_all() -> void:
	for voice: Node in _voices.values():
		if is_instance_valid(voice):
			voice.call("stop")
			voice.queue_free()
	_voices.clear()
	if is_instance_valid(_ambient):
		_ambient.stop()
		_ambient.queue_free()
		_ambient = null
	if is_instance_valid(_combat):
		_combat.stop()
		_combat.queue_free()
		_combat = null


func _exit_tree() -> void:
	stop_all()


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


func _start_loop(sname: String, vol_db: float) -> AudioStreamPlayer:
	var source: AudioStreamWAV = _streams.get(sname)
	if source == null:
		return null
	var stream := source.duplicate() as AudioStreamWAV
	stream.loop_begin = 0
	stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	var voice := AudioStreamPlayer.new()
	voice.stream = stream
	voice.volume_db = vol_db
	add_child(voice)
	voice.play()
	return voice


func _track_voice(voice: Node, duration: float) -> void:
	var id := voice.get_instance_id()
	_voices[id] = voice
	voice.tree_exited.connect(func() -> void: _voices.erase(id), CONNECT_ONE_SHOT)
	var timer := Timer.new()
	timer.one_shot = true
	timer.ignore_time_scale = true
	voice.add_child(timer)
	timer.timeout.connect(voice.queue_free)
	timer.start(maxf(duration, 0.1) + 0.75)


func _synthesize(sname: String, duration: float) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = sname.hash()
	var frames := roundi(duration * SAMPLE_RATE)
	var samples := PackedByteArray()
	samples.resize(frames * 2)
	var low_noise := 0.0
	for frame in frames:
		var time := float(frame) / SAMPLE_RATE
		var noise := rng.randf_range(-1.0, 1.0)
		low_noise = lerpf(low_noise, noise, 0.18)
		var sample := _sample(sname, time, noise, low_noise)
		if sname != "combat_pulse":
			sample *= minf(1.0, time / 0.002) * minf(1.0, (duration - time) / 0.04)
		samples.encode_s16(frame * 2, roundi(clampf(sample, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = samples
	return stream


func _sample(sname: String, time: float, noise: float, low_noise: float) -> float:
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
