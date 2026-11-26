class_name NarrativeSystem
extends Node

var chapter_panel: Control
var chapter_num_lbl: Label
var chapter_title_lbl: Label
var chapter_sub_lbl: Label

var sub_panel: ColorRect
var sub_speaker_lbl: Label
var sub_text_lbl: Label
var sub_accent: ColorRect

var _style_label: Label
var _checkpoint_label: Label
var _style_tween: Tween
var _checkpoint_tween: Tween

var queue: Array[Dictionary] = []
var current_timer: float = 0.0
var chapter_timer: float = 0.0

func setup(hud: Control, title_font: FontFile) -> void:
	# Half-Life style non-blocking Chapter Title Card
	chapter_panel = Control.new()
	chapter_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chapter_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chapter_panel.modulate.a = 0.0
	hud.add_child(chapter_panel)

	var line := ColorRect.new()
	line.color = Color("c9a26b")
	line.position = Vector2(380, 222)
	line.size = Vector2(520, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chapter_panel.add_child(line)

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
	sub_text_lbl = _make_label(sub_panel, "", Vector2(18, 28), Vector2(764, 40), 17, Color("e8e2d5"), null)
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
	_checkpoint_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_KEEP_SIZE)
	_checkpoint_label.offset_left = 22
	_checkpoint_label.offset_right = 382
	_checkpoint_label.offset_top = -136
	_checkpoint_label.offset_bottom = -100
	_checkpoint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_checkpoint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_checkpoint_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_checkpoint_label.add_theme_stylebox_override("normal", _callout_style(Color("ac8963"), 5))
	_checkpoint_label.hide()

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

func show_chapter(chapter_num: String, title: String, subtitle: String) -> void:
	chapter_num_lbl.text = chapter_num
	chapter_title_lbl.text = title
	chapter_sub_lbl.text = subtitle
	chapter_panel.modulate.a = 0.0
	chapter_timer = 4.6

func say(speaker: String, line: String, duration: float = 4.8, speaker_color: Color = Color("70d7df")) -> void:
	queue.append({"speaker": speaker, "line": line, "duration": maxf(0.1, duration), "color": speaker_color})
	if sub_panel != null and current_timer <= 0.0:
		_pop_next()

func play_sequence(lines: Array) -> void:
	for entry: Variant in lines:
		if not entry is Dictionary or str(entry.get("line", "")).is_empty():
			continue
		var duration: Variant = entry.get("duration", 4.8)
		var speaker_color: Variant = entry.get("color", Color("70d7df"))
		if speaker_color is String:
			speaker_color = Color.from_string(speaker_color, Color("70d7df"))
		say(
			str(entry.get("speaker", "")),
			str(entry.line),
			float(duration) if (duration is float or duration is int) and is_finite(float(duration)) else 4.8,
			speaker_color if speaker_color is Color else Color("70d7df")
		)

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
	queue.clear()
	current_timer = 0.0
	if sub_panel:
		sub_panel.visible = false

func _pop_next() -> void:
	if queue.is_empty():
		current_timer = 0.0
		sub_panel.visible = false
		return
	var item: Dictionary = queue.pop_front()
	sub_speaker_lbl.text = item.speaker
	sub_speaker_lbl.add_theme_color_override("font_color", item.color)
	sub_accent.color = item.color
	sub_text_lbl.text = item.line
	sub_panel.visible = true
	current_timer = item.duration

func tick(delta: float) -> void:
	if chapter_panel == null:
		return
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

	if current_timer <= 0.0 and not queue.is_empty():
		_pop_next()
	while current_timer > 0.0 and delta >= current_timer:
		delta -= current_timer
		_pop_next()
	current_timer = maxf(0.0, current_timer - delta)
