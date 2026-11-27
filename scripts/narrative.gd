class_name NarrativeSystem
extends Node

## Subtitle director. A single line occupies the subtitle lane at a time.
## Story lines are selected by priority (FIFO within a priority), barks never
## queue and never delay story lines, and every line reports its lifecycle via
## signals so gameplay never has to poll widget text.

enum Priority { BACKGROUND = 0, DIALOGUE = 1, URGENT = 2 }
enum Interrupt { QUEUE = 0, RESUME_LOWER = 1, DROP_LOWER = 2 }

signal line_started(line_id: String)
signal line_finished(line_id: String, interrupted: bool)
signal dialogue_finished(group_id: String, cancelled: bool)
signal speaker_cue(cue_id: String, world_origin: Variant, channel: String, syllable_count: int)

const MAX_QUEUE := 32
const MAX_PENDING_BARKS := 4
const DEFAULT_COLOR := Color("70d7df")
const TUBE_SUFFIX := " — SPEAKING-TUBE"
const ECHO_SUFFIX := " — ECHO"
const ACT_BANNER_TIME := 11.0

const SPEAKER_PROFILES := {
	"seraphina": {"label": "ARCHIVIST SERAPHINA", "color": "70d7df", "cue": "cue_seraphina", "italic": false},
	"torin": {"label": "BROTHER TORIN", "color": "b6a18b", "cue": "cue_torin", "italic": false},
	"guard": {"label": "BELL-WATCH GUARD", "color": "b6a18b", "cue": "cue_guard", "italic": false},
	"malcor": {"label": "LORD MALCOR", "color": "c7986a", "cue": "cue_malcor", "italic": false},
	"hollow_choir": {"label": "THE HOLLOW CHOIR", "color": "c8a7fe", "cue": "cue_choir", "italic": true, "body": "e4d8ff"},
	"whisper": {"label": "— WHISPER —", "color": "8e84b8", "cue": "cue_choir", "italic": true, "body": "d6cfee"},
	"ilse": {"label": "ILSE", "color": "9fe0f5", "cue": "cue_ilse", "italic": false},
	"king": {"label": "A VOICE BEYOND THE GATE", "color": "f2dfa6", "cue": "cue_king", "italic": false},
	"echo": {"label": "ECHO", "color": "8ce8f5", "cue": "cue_echo", "italic": false},
}

# Display-name keywords used to adapt legacy say()/play_sequence() callers.
const LEGACY_SPEAKER_KEYS := [
	["SERAPHINA", "seraphina"], ["MALCOR", "malcor"], ["TORIN", "torin"],
	["CHOIR", "hollow_choir"], ["WHISPER", "whisper"], ["ILSE", "ilse"],
	["VOICE BEYOND", "king"], ["ECHO", "echo"], ["GUARD", "guard"],
]

var chapter_panel: Control
var chapter_num_lbl: Label
var chapter_title_lbl: Label
var chapter_sub_lbl: Label
var _chapter_rule: ColorRect

var sub_panel: ColorRect
var sub_speaker_lbl: Label
var sub_text_lbl: Label
var sub_accent: ColorRect

var _hud: Control
var _style_label: Label
var _checkpoint_label: Label
var _style_tween: Tween
var _checkpoint_tween: Tween

var _act_panel: Control
var _act_labels: Array[Label] = []
var _act_timer := 0.0

# Pending story lines. Entries keep the legacy "speaker"/"line"/"duration"/"color"
# keys so existing gameplay code that inspects the queue keeps working.
var queue: Array[Dictionary] = []
var current_timer: float = 0.0
var chapter_timer: float = 0.0

var _active: Dictionary = {}
var _suspended: Array[Dictionary] = []
var _pending_barks: Array[Dictionary] = []
var _bark_cooldowns: Dictionary = {}
var _live_ids: Dictionary = {}
var _groups: Dictionary = {}
var _serial := 0
var _anon_counter := 0
var _clock := 0.0
var _last_speaker_id := ""
## True when the line that just emitted speaker_cue changed the speaker.
var last_cue_speaker_changed := false
var _started_this_tick := false
var _hud_masked := false
var _body_font: Font
var _italic_font: FontVariation
var _base_body_color := Color("e8e2d5")


func setup(hud: Control, title_font: FontFile) -> void:
	_hud = hud
	# Half-Life style non-blocking Chapter Title Card
	chapter_panel = Control.new()
	chapter_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chapter_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chapter_panel.modulate.a = 0.0
	hud.add_child(chapter_panel)

	_chapter_rule = ColorRect.new()
	_chapter_rule.color = Color("c9a26b")
	_chapter_rule.position = Vector2(380, 222)
	_chapter_rule.size = Vector2(520, 2)
	_chapter_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chapter_panel.add_child(_chapter_rule)

	chapter_num_lbl = _make_label(chapter_panel, "", Vector2(240, 175), Vector2(800, 36), 19, Color("c9a26b"), title_font)
	chapter_title_lbl = _make_label(chapter_panel, "", Vector2(200, 232), Vector2(880, 56), 40, Color("f0dfc0"), title_font)
	chapter_sub_lbl = _make_label(chapter_panel, "", Vector2(240, 290), Vector2(800, 34), 17, Color("9eb2bd"), title_font)

	# Diegetic Real-Time Subtitle Bar (bottom-center above HUD bar)
	sub_panel = ColorRect.new()
	sub_panel.color = Color(0.015, 0.02, 0.028, 0.82)
	sub_panel.position = Vector2(240, 536)
	sub_panel.size = Vector2(800, 72)
	sub_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub_panel.visible = false
	hud.add_child(sub_panel)

	sub_accent = ColorRect.new()
	sub_accent.color = Color("5be0e8")
	sub_accent.position = Vector2(0, 0)
	sub_accent.size = Vector2(4, 72)
	sub_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub_panel.add_child(sub_accent)

	sub_speaker_lbl = _make_label(sub_panel, "", Vector2(18, 6), Vector2(764, 24), 14, Color("70d7df"), title_font)
	sub_speaker_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	sub_text_lbl = _make_label(sub_panel, "", Vector2(18, 28), Vector2(764, 40), 17, _base_body_color, null)
	sub_text_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	sub_text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_style_label = _make_label(hud, "", Vector2.ZERO, Vector2(360, 52), 21, Color("ffd875"), title_font)
	_style_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_KEEP_SIZE)
	_style_label.offset_top = -18
	_style_label.offset_bottom = 34
	_style_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_style_label.hide()

	_checkpoint_label = _make_label(hud, "", Vector2.ZERO, Vector2(360, 36), 15, Color("e9d2af"), title_font)
	_checkpoint_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_KEEP_SIZE)
	_checkpoint_label.offset_left = 22
	_checkpoint_label.offset_right = 382
	_checkpoint_label.offset_top = 56
	_checkpoint_label.offset_bottom = 92
	_checkpoint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_checkpoint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_checkpoint_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_checkpoint_label.add_theme_stylebox_override("normal", _callout_style(Color("ac8963"), 5))
	_checkpoint_label.hide()

	# Live Act I ending card in the title lane. Purely decorative: never takes input.
	_act_panel = Control.new()
	_act_panel.name = "act_complete_banner"
	_act_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_act_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_act_panel.modulate.a = 0.0
	_act_panel.visible = false
	hud.add_child(_act_panel)
	_act_labels.clear()
	_act_labels.append(_make_label(_act_panel, "END OF ACT I", Vector2(240, 150), Vector2(800, 34), 18, Color("c9a26b"), title_font))
	_act_labels.append(_make_label(_act_panel, "CHAPTER IV", Vector2(240, 196), Vector2(800, 30), 16, Color("9eb2bd"), title_font))
	_act_labels.append(_make_label(_act_panel, "THE HOLLOW BEYOND", Vector2(200, 228), Vector2(880, 56), 40, Color("e4d8ff"), title_font))
	_act_labels.append(_make_label(_act_panel, "To be continued", Vector2(240, 290), Vector2(800, 30), 16, Color("c8a7fe"), title_font))

	_body_font = sub_text_lbl.get_theme_font("font")
	if _body_font == null:
		_body_font = ThemeDB.fallback_font
	if _body_font != null:
		_italic_font = FontVariation.new()
		_italic_font.base_font = _body_font
		_italic_font.variation_transform = Transform2D(Vector2(1.0, 0.0), Vector2(0.24, 1.0), Vector2.ZERO)

	if not hud.resized.is_connected(_layout):
		hud.resized.connect(_layout)
	_layout()


func _make_label(parent: Control, txt: String, pos: Vector2, sz: Vector2, fsize: int, col: Color, font: FontFile) -> Label:
	var l := Label.new()
	l.text = txt
	l.position = pos
	l.size = sz
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", fsize)
	if font != null:
		l.add_theme_font_override("font", font)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.92))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


# --- Layout -----------------------------------------------------------------

func _viewport_size() -> Vector2:
	if _hud != null and is_instance_valid(_hud) and _hud.size.x > 8.0 and _hud.size.y > 8.0:
		return _hud.size
	if _hud != null and is_instance_valid(_hud) and _hud.is_inside_tree():
		return _hud.get_viewport_rect().size
	return Vector2(1280, 720)


func _layout() -> void:
	if sub_panel == null:
		return
	var vp := _viewport_size()
	var lane_w := clampf(vp.x - 96.0, 360.0, 800.0)
	var lane_x := floorf((vp.x - lane_w) * 0.5)
	# Title lane sits in the upper-middle band, above the reticle.
	var title_top := clampf(vp.y * 0.243, 96.0, 220.0)
	chapter_num_lbl.position = Vector2(lane_x, title_top)
	chapter_num_lbl.size = Vector2(lane_w, 36)
	_chapter_rule.size = Vector2(minf(520.0, lane_w * 0.65), 2)
	_chapter_rule.position = Vector2(floorf((vp.x - _chapter_rule.size.x) * 0.5), title_top + 47.0)
	chapter_title_lbl.position = Vector2(floorf((vp.x - (lane_w + 80.0)) * 0.5), title_top + 57.0)
	chapter_title_lbl.size = Vector2(lane_w + 80.0, 56)
	chapter_sub_lbl.position = Vector2(lane_x, title_top + 115.0)
	chapter_sub_lbl.size = Vector2(lane_w, 34)
	var act_offsets := [-25.0, 21.0, 53.0, 115.0]
	for i in _act_labels.size():
		var lbl := _act_labels[i]
		var w := lane_w + (80.0 if i == 2 else 0.0)
		lbl.size = Vector2(w, lbl.size.y)
		lbl.position = Vector2(floorf((vp.x - w) * 0.5), title_top + float(act_offsets[i]))
	# Subtitle lane: central lower band directly above the vitals strip.
	sub_panel.size.x = lane_w
	sub_speaker_lbl.size.x = lane_w - 36.0
	sub_text_lbl.size.x = lane_w - 36.0
	_fit_subtitle_height()


func _fit_subtitle_height() -> void:
	if sub_panel == null:
		return
	var vp := _viewport_size()
	var lines := 1
	if not sub_text_lbl.text.is_empty():
		lines = clampi(sub_text_lbl.get_line_count(), 1, 3)
	var height := maxf(72.0, 30.0 + float(lines) * 22.0 + 8.0)
	sub_text_lbl.size.y = height - 32.0
	sub_accent.size.y = height
	sub_panel.size.y = height
	var bottom := vp.y - 112.0 if vp.y >= 600.0 else vp.y * 0.845
	sub_panel.position = Vector2(floorf((vp.x - sub_panel.size.x) * 0.5), bottom - height)


# --- Legacy-compatible presentation entry points ----------------------------

func show_chapter(chapter_num: String, title: String, subtitle: String) -> void:
	chapter_num_lbl.text = chapter_num
	chapter_title_lbl.text = title
	chapter_sub_lbl.text = subtitle
	chapter_panel.modulate.a = 0.0
	chapter_timer = 4.6


func say(speaker: String, line: String, duration: float = 4.8, speaker_color: Color = DEFAULT_COLOR) -> void:
	submit_line({
		"speaker": speaker,
		"speaker_id": _legacy_speaker_id(speaker),
		"line": line,
		"duration": maxf(0.1, duration),
		"color": speaker_color,
		"legacy": true,
	})


func play_sequence(lines: Array, group_id: String = "") -> void:
	for entry: Variant in lines:
		if not entry is Dictionary or str(entry.get("line", "")).is_empty():
			continue
		var data: Dictionary = (entry as Dictionary).duplicate()
		if not group_id.is_empty() and not data.has("group_id"):
			data["group_id"] = group_id
		if not data.has("speaker_id"):
			data["speaker_id"] = _legacy_speaker_id(str(data.get("speaker", "")))
		if not data.has("color") and not SPEAKER_PROFILES.has(str(data.speaker_id)):
			data["color"] = DEFAULT_COLOR
		data["legacy"] = true
		submit_line(data)


func show_style_banner(text: String, color: Color = Color("ffd875")) -> void:
	if _style_label == null or not _style_label.is_inside_tree():
		return
	if _style_tween != null:
		_style_tween.kill()
	_style_label.text = text
	_style_label.add_theme_color_override("font_color", color)
	_style_label.add_theme_stylebox_override("normal", _callout_style(color, 24))
	_style_label.offset_left = -326
	_style_label.offset_right = 34
	_style_label.modulate.a = 0.0
	_style_label.show()
	_style_tween = _style_label.create_tween().set_parallel()
	_style_tween.tween_property(_style_label, "offset_left", -384.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_style_tween.tween_property(_style_label, "offset_right", -24.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_style_tween.tween_property(_style_label, "modulate:a", 1.0, 0.14)
	_style_tween.chain().tween_interval(1.05)
	_style_tween.chain().tween_property(_style_label, "modulate:a", 0.0, 0.3)
	_style_tween.tween_property(_style_label, "offset_left", -355.0, 0.3)
	_style_tween.tween_property(_style_label, "offset_right", 5.0, 0.3)
	_style_tween.chain().tween_callback(_style_label.hide)


func show_checkpoint_toast(zone_label: String) -> void:
	if _checkpoint_label == null or not _checkpoint_label.is_inside_tree():
		return
	if _checkpoint_tween != null:
		_checkpoint_tween.kill()
	_checkpoint_label.text = "CHECKPOINT — %s" % zone_label
	_checkpoint_label.modulate.a = 0.0
	_checkpoint_label.show()
	_checkpoint_tween = _checkpoint_label.create_tween()
	_checkpoint_tween.tween_property(_checkpoint_label, "modulate:a", 1.0, 0.2)
	_checkpoint_tween.tween_interval(2.2)
	_checkpoint_tween.tween_property(_checkpoint_label, "modulate:a", 0.0, 0.4)
	_checkpoint_tween.tween_callback(_checkpoint_label.hide)


## Non-modal live Act I ending card. Never touches the mouse mode or the player.
func show_act_complete_banner() -> void:
	if _act_panel == null:
		return
	_act_timer = ACT_BANNER_TIME
	_act_panel.modulate.a = 0.0
	_act_panel.visible = not _hud_masked
	chapter_timer = 0.0
	chapter_panel.modulate.a = 0.0


func is_act_banner_visible() -> bool:
	return _act_panel != null and _act_panel.visible and _act_timer > 0.0


func _callout_style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.020, 0.025, 0.95)
	style.border_color = color.darkened(0.32)
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14
	style.content_margin_right = 14
	return style


func clear_dialogue() -> void:
	clear_chapter()


# --- Structured line API ----------------------------------------------------

## Queue a structured line. Keys: id, group_id, speaker_id, speaker, line,
## duration, color, priority, interrupt, world_origin, origin_resolver, channel.
## Returns false for empty/malformed lines and duplicate live IDs.
func submit_line(line: Dictionary) -> bool:
	var item := _normalize_line(line)
	if item.is_empty():
		return false
	var line_id: String = item.id
	if _live_ids.has(line_id):
		return false
	if queue.size() >= MAX_QUEUE and not _make_room(int(item.priority)):
		return false
	_live_ids[line_id] = true
	_group_add(str(item.group_id))
	queue.append(item)
	# A bark never delays a story line: drop it as soon as story speech arrives.
	if not _active.is_empty() and bool(_active.get("bark", false)):
		_finish_active(true)
	if sub_panel == null:
		return true
	if _active.is_empty() and _suspended.is_empty() and not _hud_masked:
		_start_next()
	elif not _active.is_empty() and not _hud_masked and not _started_this_tick:
		_try_preempt()
	return true


## Non-queuing positional bark. Dropped if the lane stays busy past `ttl` or the
## speaker barked within `cooldown_s`.
func submit_bark(speaker_id: String, speaker_label: String, line: String, world_origin: Variant = null, ttl: float = 1.5, cooldown_s: float = 4.0) -> bool:
	var text := line.strip_edges()
	if text.is_empty():
		return false
	var key := speaker_id if not speaker_id.is_empty() else speaker_label
	if _bark_cooldowns.has(key) and _clock - float(_bark_cooldowns[key]) < maxf(cooldown_s, 0.0):
		return false
	var profile: Dictionary = SPEAKER_PROFILES.get(speaker_id, {})
	var label := speaker_label if not speaker_label.is_empty() else str(profile.get("label", ""))
	_anon_counter += 1
	var bark := {
		"id": "bark_%d" % _anon_counter,
		"group_id": "",
		"speaker_id": speaker_id,
		"speaker": label,
		"line": text,
		"duration": clampf(1.0 + 0.045 * float(text.length()), 1.2, 2.8),
		"color": Color(str(profile.get("color", "c9b8a0"))),
		"body_color": Color(str(profile.get("body", "e8e2d5"))),
		"italic": bool(profile.get("italic", false)),
		"priority": Priority.BACKGROUND,
		"interrupt": Interrupt.QUEUE,
		"world_origin": world_origin if world_origin is Vector3 else null,
		"channel": "bark",
		"cue": str(profile.get("cue", "")),
		"bark": true,
		"expires": _clock + maxf(ttl, 0.0),
	}
	if _lane_idle() and sub_panel != null and not _hud_masked:
		_bark_cooldowns[key] = _clock
		_begin_line(bark, false)
		return true
	if ttl <= 0.0:
		return false
	if _pending_barks.size() >= MAX_PENDING_BARKS:
		_pending_barks.pop_front()
	_bark_cooldowns[key] = _clock
	_pending_barks.append(bark)
	return true


func cancel_group(group_id: String) -> void:
	if group_id.is_empty():
		return
	var removed := false
	for i in range(queue.size() - 1, -1, -1):
		if str(queue[i].group_id) == group_id:
			var item: Dictionary = queue[i]
			queue.remove_at(i)
			_retire(item, true, false)
			removed = true
	for i in range(_suspended.size() - 1, -1, -1):
		if str(_suspended[i].group_id) == group_id:
			var item: Dictionary = _suspended[i]
			_suspended.remove_at(i)
			_retire(item, true, false)
			removed = true
	if not _active.is_empty() and str(_active.group_id) == group_id:
		_finish_active(true, false)
		removed = true
	if _groups.has(group_id):
		_groups[group_id].cancelled = true
		if int(_groups[group_id].pending) <= 0 or removed:
			_check_group(group_id)
	if _active.is_empty() and sub_panel != null:
		_hide_lane()


## Retire every line, bark and group for a chapter unload / travel / reload.
func clear_chapter() -> void:
	var groups := _groups.keys()
	for g: Variant in groups:
		if _groups.has(g):
			_groups[g].cancelled = true
	var pending := queue.duplicate()
	queue.clear()
	for item: Dictionary in pending:
		_retire(item, true, false)
	var held := _suspended.duplicate()
	_suspended.clear()
	for item: Dictionary in held:
		_retire(item, true, false)
	if not _active.is_empty():
		_finish_active(true, false)
	_pending_barks.clear()
	for g: Variant in _groups.keys():
		_check_group(str(g))
	_groups.clear()
	_live_ids.clear()
	_last_speaker_id = ""
	current_timer = 0.0
	if sub_panel != null:
		_hide_lane()
	if _style_tween != null:
		_style_tween.kill()
		_style_tween = null
	if _style_label != null:
		_style_label.hide()
	if _checkpoint_tween != null:
		_checkpoint_tween.kill()
		_checkpoint_tween = null
	if _checkpoint_label != null:
		_checkpoint_label.hide()


## Masked while map / journal / pause / travel fade cover the gameplay HUD.
## Presentation clocks pause while masked.
func set_gameplay_hud_visible(active: bool) -> void:
	_hud_masked = not active
	if sub_panel == null:
		return
	sub_panel.visible = active and not _active.is_empty()
	chapter_panel.visible = active
	if _act_panel != null:
		_act_panel.visible = active and _act_timer > 0.0


func is_gameplay_hud_visible() -> bool:
	return not _hud_masked


func is_line_active(line_id: String) -> bool:
	return not _active.is_empty() and str(_active.id) == line_id


func get_active_line() -> Dictionary:
	return _active.duplicate()


func is_group_live(group_id: String) -> bool:
	return _groups.has(group_id)


func is_busy() -> bool:
	return not _active.is_empty() or not queue.is_empty() or not _suspended.is_empty()


# --- Internals ----------------------------------------------------------------

func _legacy_speaker_id(speaker: String) -> String:
	var upper := speaker.to_upper()
	for pair: Array in LEGACY_SPEAKER_KEYS:
		if upper.contains(str(pair[0])):
			return str(pair[1])
	return ""


static func default_duration(text: String) -> float:
	return clampf(1.2 + 0.055 * float(text.length()), 2.0, 7.0)


func _normalize_line(line: Dictionary) -> Dictionary:
	var text := str(line.get("line", "")).strip_edges()
	if text.is_empty():
		return {}
	var speaker_id := str(line.get("speaker_id", "")).to_lower()
	var profile: Dictionary = SPEAKER_PROFILES.get(speaker_id, {})
	var label := str(line.get("speaker", ""))
	if label.is_empty():
		label = str(profile.get("label", ""))
	var channel := str(line.get("channel", ""))
	if channel == "tube" and not label.ends_with(TUBE_SUFFIX):
		label += TUBE_SUFFIX
	elif channel == "echo" and not label.ends_with(ECHO_SUFFIX):
		label += ECHO_SUFFIX
	var color := Color(str(profile.get("color", "70d7df")))
	var raw_color: Variant = line.get("color", null)
	if raw_color is Color:
		color = raw_color
	elif raw_color is String and not str(raw_color).is_empty():
		color = Color.from_string(str(raw_color), color)
	var duration := default_duration(text)
	var raw_duration: Variant = line.get("duration", null)
	if (raw_duration is float or raw_duration is int) and is_finite(float(raw_duration)) and float(raw_duration) > 0.0:
		duration = maxf(0.1, float(raw_duration))
	var priority := clampi(int(line.get("priority", Priority.DIALOGUE)), Priority.BACKGROUND, Priority.URGENT)
	var interrupt := clampi(int(line.get("interrupt", Interrupt.QUEUE)), Interrupt.QUEUE, Interrupt.DROP_LOWER)
	var line_id := str(line.get("id", ""))
	if line_id.is_empty():
		_anon_counter += 1
		line_id = "line_%d" % _anon_counter
	var origin: Variant = line.get("world_origin", null)
	if not origin is Vector3:
		origin = null
	var resolver: Variant = line.get("origin_resolver", null)
	_serial += 1
	var body_color := _base_body_color
	if profile.has("body"):
		body_color = Color(str(profile.body))
	return {
		"id": line_id,
		"group_id": str(line.get("group_id", "")),
		"speaker_id": speaker_id,
		"speaker": label,
		"line": text,
		"duration": duration,
		"color": color,
		"body_color": body_color,
		"italic": bool(line.get("italic", profile.get("italic", false))),
		"priority": priority,
		"interrupt": interrupt,
		"world_origin": origin,
		"origin_resolver": resolver if resolver is Callable else Callable(),
		"channel": channel,
		"cue": str(line.get("cue", profile.get("cue", ""))),
		"serial": _serial,
		"remaining": duration,
		"bark": false,
	}


func _make_room(incoming_priority: int) -> bool:
	for p in [Priority.BACKGROUND, Priority.DIALOGUE]:
		if p > incoming_priority or (p == incoming_priority and p != Priority.BACKGROUND):
			break
		for i in queue.size():
			if int(queue[i].priority) == p:
				var item: Dictionary = queue[i]
				queue.remove_at(i)
				_retire(item, true, true)
				return true
	if incoming_priority == Priority.URGENT:
		for i in queue.size():
			if int(queue[i].priority) < Priority.URGENT:
				var item: Dictionary = queue[i]
				queue.remove_at(i)
				_retire(item, true, true)
				return true
	return false


func _group_add(group_id: String) -> void:
	if group_id.is_empty():
		return
	if not _groups.has(group_id):
		_groups[group_id] = {"pending": 0, "cancelled": false}
	_groups[group_id].pending = int(_groups[group_id].pending) + 1


func _check_group(group_id: String) -> void:
	if group_id.is_empty() or not _groups.has(group_id):
		return
	if int(_groups[group_id].pending) > 0:
		return
	var cancelled := bool(_groups[group_id].cancelled)
	_groups.erase(group_id)
	dialogue_finished.emit(group_id, cancelled)


## A line leaves the system. `started` lines report line_finished.
func _retire(item: Dictionary, interrupted: bool, check_group: bool = true, started: bool = false) -> void:
	_live_ids.erase(str(item.get("id", "")))
	var group_id := str(item.get("group_id", ""))
	if started or bool(item.get("started", false)):
		line_finished.emit(str(item.id), interrupted)
	if not group_id.is_empty() and _groups.has(group_id):
		_groups[group_id].pending = int(_groups[group_id].pending) - 1
		if interrupted:
			_groups[group_id].cancelled = true
		if check_group:
			_check_group(group_id)


func _lane_idle() -> bool:
	return _active.is_empty() and queue.is_empty() and _suspended.is_empty()


func _best_queued_index() -> int:
	var best := -1
	for i in queue.size():
		if best < 0:
			best = i
			continue
		var a: Dictionary = queue[i]
		var b: Dictionary = queue[best]
		if int(a.priority) > int(b.priority) or (int(a.priority) == int(b.priority) and int(a.serial) < int(b.serial)):
			best = i
	return best


func _start_next() -> bool:
	if _started_this_tick:
		return false
	var best := _best_queued_index()
	if not _suspended.is_empty():
		var resume: Dictionary = _suspended.back()
		if best < 0 or int(queue[best].priority) <= int(resume.priority):
			_suspended.pop_back()
			_begin_line(resume, true)
			return true
	if best >= 0:
		var item: Dictionary = queue[best]
		queue.remove_at(best)
		_begin_line(item, false)
		return true
	while not _pending_barks.is_empty():
		var bark: Dictionary = _pending_barks.pop_front()
		if _clock <= float(bark.expires):
			_begin_line(bark, false)
			return true
	current_timer = 0.0
	_hide_lane()
	return false


func _try_preempt() -> void:
	if _active.is_empty():
		return
	var best := _best_queued_index()
	if best < 0:
		return
	var item: Dictionary = queue[best]
	if int(item.interrupt) == Interrupt.QUEUE or int(item.priority) <= int(_active.priority):
		return
	var lower := _active
	_active = {}
	if int(item.interrupt) == Interrupt.RESUME_LOWER:
		lower["remaining"] = current_timer
		_suspended.append(lower)
	else:
		_retire(lower, true, false, true)
		cancel_group(str(lower.group_id))
	queue.remove_at(queue.find(item))
	_begin_line(item, false)


func _begin_line(item: Dictionary, resumed: bool) -> void:
	_started_this_tick = true
	_active = item
	_active["started"] = true
	current_timer = maxf(0.05, float(item.get("remaining", item.duration)))
	sub_speaker_lbl.text = str(item.speaker)
	sub_speaker_lbl.add_theme_color_override("font_color", item.color)
	sub_accent.color = item.color
	sub_text_lbl.text = str(item.line)
	sub_text_lbl.add_theme_color_override("font_color", item.get("body_color", _base_body_color))
	if bool(item.get("italic", false)) and _italic_font != null:
		sub_text_lbl.add_theme_font_override("font", _italic_font)
		sub_panel.color = Color(0.03, 0.02, 0.05, 0.86)
	else:
		sub_text_lbl.remove_theme_font_override("font")
		sub_panel.color = Color(0.015, 0.02, 0.028, 0.82)
	sub_panel.visible = not _hud_masked
	_fit_subtitle_height()
	if resumed:
		return
	if not bool(item.get("bark", false)):
		line_started.emit(str(item.id))
	var origin: Variant = item.get("world_origin", null)
	var resolver: Variant = item.get("origin_resolver", Callable())
	if resolver is Callable and (resolver as Callable).is_valid():
		var resolved: Variant = (resolver as Callable).call()
		if resolved is Vector3:
			origin = resolved
	var speaker_id := str(item.speaker_id)
	var syllables := maxi(1, int(round(float(str(item.line).length()) / 3.0)))
	var cue := str(item.get("cue", ""))
	var channel := str(item.get("channel", ""))
	if cue.is_empty() and not speaker_id.is_empty():
		cue = "cue_" + speaker_id
	# One cue per newly visible line (never on silent resumption). Audio3D plays the
	# speaker chime plus a syllable-shaped voice grain from it. `speaker_changed`
	# lets a listener skip the chime for consecutive lines of one speaker.
	var key := speaker_id if not speaker_id.is_empty() else str(item.speaker)
	last_cue_speaker_changed = key != _last_speaker_id
	if not cue.is_empty():
		speaker_cue.emit(cue, origin, channel, syllables)
	_last_speaker_id = key


func _finish_active(interrupted: bool, check_group: bool = true) -> void:
	if _active.is_empty():
		return
	var item := _active
	_active = {}
	current_timer = 0.0
	if bool(item.get("bark", false)):
		return
	_retire(item, interrupted, check_group, true)


func _hide_lane() -> void:
	if _active.is_empty():
		sub_panel.visible = false


# Legacy name retained for any external caller.
func _pop_next() -> void:
	_finish_active(false)
	_started_this_tick = false
	_start_next()


func tick(delta: float) -> void:
	if chapter_panel == null:
		return
	if _hud_masked:
		return
	delta = maxf(delta, 0.0)
	_clock += delta
	_started_this_tick = false
	if chapter_timer > 0.0:
		chapter_timer = maxf(0.0, chapter_timer - delta)
		if chapter_timer > 3.8:
			chapter_panel.modulate.a = clampf((4.6 - chapter_timer) / 0.8, 0.0, 1.0)
		elif chapter_timer < 1.0:
			chapter_panel.modulate.a = clampf(chapter_timer, 0.0, 1.0)
		else:
			chapter_panel.modulate.a = 1.0
	else:
		chapter_panel.modulate.a = 0.0

	if _act_panel != null and _act_timer > 0.0:
		_act_timer = maxf(0.0, _act_timer - delta)
		var shown := ACT_BANNER_TIME - _act_timer
		_act_panel.visible = true
		if shown < 1.4:
			_act_panel.modulate.a = clampf(shown / 1.4, 0.0, 1.0)
		elif _act_timer < 1.6:
			_act_panel.modulate.a = clampf(_act_timer / 1.6, 0.0, 1.0)
		else:
			_act_panel.modulate.a = 1.0
		if _act_timer <= 0.0:
			_act_panel.visible = false

	for i in range(_pending_barks.size() - 1, -1, -1):
		if _clock > float(_pending_barks[i].expires):
			_pending_barks.remove_at(i)

	if not _active.is_empty():
		current_timer = maxf(0.0, current_timer - delta)
		if current_timer <= 0.0:
			_finish_active(false)
		else:
			_try_preempt()
	if _active.is_empty():
		_start_next()
