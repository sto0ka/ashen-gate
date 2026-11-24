class_name NarrativeSystem
extends Node

var chapter_panel: Control
var chapter_num_lbl: Label
var chapter_title_lbl: Label
var chapter_sub_lbl: Label

var sub_panel: ColorRect
var sub_speaker_lbl: Label
var sub_text_lbl: Label

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

	var accent := ColorRect.new()
	accent.name = "accent"
	accent.color = Color("5be0e8")
	accent.position = Vector2(0, 0)
	accent.size = Vector2(4, 72)
	sub_panel.add_child(accent)

	sub_speaker_lbl = _make_label(sub_panel, "", Vector2(18, 6), Vector2(764, 24), 14, Color("70d7df"), title_font)
	sub_speaker_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	sub_text_lbl = _make_label(sub_panel, "", Vector2(18, 28), Vector2(764, 40), 17, Color("e8e2d5"), null)
	sub_text_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	sub_text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

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
	chapter_timer = 4.6

func say(speaker: String, line: String, duration: float = 4.8, speaker_color: Color = Color("70d7df")) -> void:
	queue.append({"speaker": speaker, "line": line, "duration": duration, "color": speaker_color})
	if current_timer <= 0.0:
		_pop_next()

func clear_dialogue() -> void:
	queue.clear()
	current_timer = 0.0
	if sub_panel:
		sub_panel.visible = false

func _pop_next() -> void:
	if queue.is_empty():
		sub_panel.visible = false
		return
	var item: Dictionary = queue.pop_front()
	sub_speaker_lbl.text = item.speaker
	sub_speaker_lbl.add_theme_color_override("font_color", item.color)
	sub_panel.get_node("accent").color = item.color
	sub_text_lbl.text = item.line
	sub_panel.visible = true
	current_timer = item.duration

func tick(delta: float) -> void:
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

	if current_timer > 0.0:
		current_timer -= delta
		if current_timer <= 0.0:
			_pop_next()
