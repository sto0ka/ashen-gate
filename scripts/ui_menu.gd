class_name PauseMenu
extends ColorRect

signal resume_requested
signal load_checkpoint_requested
signal restart_chapter_requested
signal settings_changed(settings: Dictionary)
signal quit_requested

const Saves = preload("res://scripts/save_system.gd")
const INK := Color("d5cabc")
const GOLD := Color("e8c186")
const MUTED := Color("a9a096")

@export var handle_escape := true

var _settings: Dictionary
var _heading_font: FontFile
var _resume: Button
var _load_checkpoint: Button
var _sensitivity: HSlider
var _sensitivity_value: Label
var _difficulty: OptionButton
var _graphics: Dictionary[String, CheckBox] = {}
var _owns_pause := false
var _previous_pause := false
var _previous_mouse_mode: Input.MouseMode

func _init() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	color = Color(0.012, 0.009, 0.015, 0.79)

func setup(title_font: FontFile, initial_settings: Dictionary) -> void:
	_settings = Saves.normalize_settings(initial_settings)
	if _resume == null:
		_heading_font = title_font
		_build_menu()
	_sync_controls()

func open_menu(current_settings: Dictionary) -> void:
	if _resume == null:
		setup(null, current_settings)
	else:
		_settings = Saves.normalize_settings(current_settings)
		_sync_controls()
	_load_checkpoint.disabled = not Saves.has_checkpoint()
	if is_inside_tree() and not _owns_pause:
		_previous_pause = get_tree().paused
		_previous_mouse_mode = Input.mouse_mode
		_owns_pause = true
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show()
	if is_inside_tree():
		_resume.grab_focus()

func close_menu() -> void:
	hide()
	if _owns_pause:
		_owns_pause = false
		get_tree().paused = _previous_pause
		Input.mouse_mode = _previous_mouse_mode

func _exit_tree() -> void:
	if _owns_pause:
		close_menu()

func _input(event: InputEvent) -> void:
	if not handle_escape or _resume == null:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if visible:
			_resume_game()
		else:
			open_menu(_settings)

func _resume_game() -> void:
	close_menu()
	resume_requested.emit()

func _build_menu() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	margin.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _panel_style(Color("161218"), Color("8a694a"), 28.0))
	card.custom_minimum_size.x = 880
	center.add_child(card)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	card.add_child(body)
	var heading := _label("Paused", 37, GOLD, _heading_font)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(heading)
	var rule := HSeparator.new()
	var rule_style := StyleBoxLine.new()
	rule_style.color = Color("70523c")
	rule.add_theme_stylebox_override("separator", rule_style)
	body.add_child(rule)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	body.add_child(columns)
	var actions := VBoxContainer.new()
	actions.custom_minimum_size.x = 238
	actions.add_theme_constant_override("separation", 12)
	columns.add_child(actions)
	_resume = _action_button(actions, "Resume Game", _resume_game, true)
	_load_checkpoint = _action_button(actions, "Load Last Checkpoint", func() -> void: load_checkpoint_requested.emit())
	_action_button(actions, "Restart Chapter", func() -> void: restart_chapter_requested.emit())
	_action_button(actions, "Quit Game", func() -> void: quit_requested.emit())

	var options := VBoxContainer.new()
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.add_theme_constant_override("separation", 12)
	columns.add_child(options)
	options.add_child(_label("Settings", 24, GOLD, _heading_font))

	var sensitivity_row := _settings_row(options, "Mouse Sensitivity")
	_sensitivity = HSlider.new()
	_sensitivity.min_value = 0.4
	_sensitivity.max_value = 2.4
	_sensitivity.step = 0.01
	_sensitivity.custom_minimum_size.x = 150
	_sensitivity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sensitivity.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sensitivity_row.add_child(_sensitivity)
	_sensitivity_value = _label("", 16, GOLD)
	_sensitivity_value.custom_minimum_size.x = 45
	_sensitivity_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sensitivity_row.add_child(_sensitivity_value)
	_sensitivity.value_changed.connect(_on_sensitivity_changed)

	var difficulty_row := _settings_row(options, "Difficulty")
	_difficulty = OptionButton.new()
	_difficulty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_difficulty.tooltip_text = "Enemy damage: Story ×0.65, Cinder-Breaker ×1.0, Torment ×1.45"
	for difficulty: String in Saves.DIFFICULTIES:
		_difficulty.add_item(difficulty)
	_difficulty.item_selected.connect(_on_difficulty_selected)
	difficulty_row.add_child(_difficulty)

	options.add_child(_label("Vulkan Graphics", 19, GOLD, _heading_font))
	var graphics_grid := GridContainer.new()
	graphics_grid.columns = 2
	graphics_grid.add_theme_constant_override("h_separation", 18)
	options.add_child(graphics_grid)
	_add_graphics_checkbox(graphics_grid, "volumetric_fog", "Volumetric Fog")
	_add_graphics_checkbox(graphics_grid, "ssr", "SSR Reflections")
	_add_graphics_checkbox(graphics_grid, "ssao", "SSAO")
	_add_graphics_checkbox(graphics_grid, "msaa", "4× MSAA")

	var reference := PanelContainer.new()
	reference.add_theme_stylebox_override("panel", _panel_style(Color("1c171b"), Color("493629"), 14.0))
	body.add_child(reference)
	var controls := VBoxContainer.new()
	controls.add_theme_constant_override("separation", 6)
	reference.add_child(controls)
	controls.add_child(_label("Controls", 19, GOLD, _heading_font))
	controls.add_child(_label("WASD Move    •    Shift Run    •    C Dash    •    Space Jump    •    1–4 Weapons", 15, INK))
	controls.add_child(_label("LMB Attack    •    RMB Frost    •    MMB / X Parry    •    Q Repulse    •    G Grasp / Hurl", 15, INK))
	controls.add_child(_label("E Use    •    F Heal    •    Tab Map    •    J Journal    •    F5 Save / F9 Load", 15, INK))

func _settings_row(parent: VBoxContainer, caption: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var label := _label(caption, 16, INK)
	label.custom_minimum_size.x = 154
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	return row

func _add_graphics_checkbox(parent: GridContainer, key: String, caption: String) -> void:
	var checkbox := CheckBox.new()
	checkbox.text = caption
	checkbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	checkbox.add_theme_color_override("font_color", INK)
	checkbox.toggled.connect(_on_graphics_toggled.bind(key))
	parent.add_child(checkbox)
	_graphics[key] = checkbox

func _action_button(parent: VBoxContainer, caption: String, action: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 44
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", GOLD if primary else INK)
	button.add_theme_color_override("font_disabled_color", MUTED.darkened(0.28))
	button.add_theme_stylebox_override("normal", _panel_style(Color("35251d") if primary else Color("241d22"), Color("8a694a"), 7.0))
	button.add_theme_stylebox_override("hover", _panel_style(Color("463127"), GOLD, 7.0))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("231814"), GOLD, 7.0))
	button.add_theme_stylebox_override("disabled", _panel_style(Color("1c171b"), Color("403438"), 7.0))
	var focus := _panel_style(Color.TRANSPARENT, GOLD, 7.0)
	button.add_theme_stylebox_override("focus", focus)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _label(caption: String, font_size: int, tint: Color, font: FontFile = null) -> Label:
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	if font != null:
		label.add_theme_font_override("font", font)
	return label

func _panel_style(fill: Color, border: Color, padding: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, padding)
	return style

func _sync_controls() -> void:
	_sensitivity.set_value_no_signal(_settings.mouse_sens)
	_sensitivity_value.text = "%.2f×" % _sensitivity.value
	_difficulty.select(Saves.DIFFICULTIES.find(_settings.difficulty))
	for key: String in _graphics:
		_graphics[key].set_pressed_no_signal(_settings[key])

func _on_sensitivity_changed(value: float) -> void:
	_settings.mouse_sens = value
	_sensitivity_value.text = "%.2f×" % value
	settings_changed.emit(_settings.duplicate())

func _on_difficulty_selected(index: int) -> void:
	_settings.difficulty = Saves.DIFFICULTIES[index]
	settings_changed.emit(_settings.duplicate())

func _on_graphics_toggled(enabled: bool, key: String) -> void:
	_settings[key] = enabled
	settings_changed.emit(_settings.duplicate())
