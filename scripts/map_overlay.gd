extends Control

const Saves = preload("res://scripts/save_system.gd")
const REGISTRY_PATH := "res://scripts/chapters/chapter_registry.gd"
const DEFAULT_BOUNDS := Rect2(-32, -32, 64, 64)
const PORTAL := Color("c68ae3")
const WARD := Color("c68ae3")
const FONT := Color("73ded6")
const NPC := Color("dca3c6")
const BOSS := Color("ef876f")
const OBJECTIVE := Color("ffd47f")
const PLAYER := Color("78eef1")

var game: Object
var _chapters: Dictionary
var _checked_registry := false

func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()

func _draw() -> void:
	if not is_instance_valid(game) or size.x < 100 or size.y < 150:
		return
	var chapter_id := _chapter_id()
	var chapter := _chapter_metadata(chapter_id)
	var bounds := _map_bounds(chapter)
	var state := _chapter_state(chapter_id)
	var area := _map_area(bounds)

	draw_rect(Rect2(Vector2.ZERO, size), Color("111619"))
	draw_rect(Rect2(Vector2(4, 4), size - Vector2(8, 8)), Color("8b7864"), false, 2)
	_print(str(chapter.get("title", "AUTOMAP")), Vector2(26, 31), size.x - 260, 22, Color("efd2aa"))
	var secrets := "SECRETS DISCOVERED  %d" % _secret_count(state)
	_print(secrets, Vector2(size.x - 230, 29), 208, 15, OBJECTIVE)
	var caption: Variant = chapter.get("map_caption", game.get("map_caption"))
	if caption is String:
		_print(caption, Vector2(26, 54), size.x - 52, 16, Color("c2beb3"))

	_draw_grid(bounds, area)
	_draw_markers(bounds, area, chapter_id, state)
	_print("TAB CLOSE   •   CYAN YOU   •   GOLD OBJECTIVE   •   VIOLET PORTAL / WARD   •   TEAL FONT   •   ROSE NPC   •   RED BOSS",
		Vector2(26, size.y - 22), size.x - 52, 14, Color("c2beb3"))

func _chapter_id() -> String:
	var current: Variant = game.get("chapter_id")
	if (current is String or current is StringName) and not str(current).is_empty():
		return str(current)
	var stage: Variant = game.get("stage")
	return Saves.chapter_id_for_stage(stage) if stage is int else ""

func _chapter_metadata(chapter_id: String) -> Dictionary:
	if not _checked_registry:
		_checked_registry = true
		if ResourceLoader.exists(REGISTRY_PATH):
			var registry := load(REGISTRY_PATH) as Script
			if registry != null and registry.can_instantiate():
				_chapters = registry.get_script_constant_map().get("CHAPTERS", {})
	return _chapters.get(chapter_id, {})

func _map_bounds(chapter: Dictionary) -> Rect2:
	var registry_bounds: Variant = chapter.get("map_bounds")
	if _valid_bounds(registry_bounds):
		return registry_bounds
	var game_bounds: Variant = game.get("map_bounds")
	if _valid_bounds(game_bounds):
		return game_bounds
	return DEFAULT_BOUNDS

func _valid_bounds(bounds: Variant) -> bool:
	return bounds is Rect2 and bounds.position.is_finite() and bounds.size.is_finite() and bounds.has_area()

func _chapter_state(chapter_id: String) -> Dictionary:
	var states: Variant = game.get("level_states")
	if states is Dictionary:
		var state: Variant = states.get(chapter_id, states.get(game.get("stage")))
		if state is Dictionary:
			return state
	return {}

func _secret_count(state: Dictionary) -> int:
	var discovered: Variant = state.get("secrets_discovered", game.get("secrets_discovered"))
	if discovered is int or discovered is float:
		return maxi(0, int(discovered))
	if discovered is Array or discovered is Dictionary:
		return discovered.size()
	var count := 0
	var broken: Variant = state.get("broken")
	if broken is Array:
		for id: Variant in broken:
			if str(id).contains("_secret_"):
				count += 1
	return count

func _map_area(bounds: Rect2) -> Rect2:
	var available := Rect2(Vector2(26, 68), size - Vector2(52, 120))
	var ratio := minf(available.size.x / bounds.size.x, available.size.y / bounds.size.y)
	var map_size := bounds.size * ratio
	return Rect2(available.get_center() - map_size * 0.5, map_size)

func _draw_grid(bounds: Rect2, area: Rect2) -> void:
	draw_rect(area, Color("233139"))
	var grid := Color(0.65, 0.76, 0.71, 0.16)
	var step := maxf(6.0, maxf(bounds.size.x, bounds.size.y) / 20.0)
	var x := ceilf(bounds.position.x / step) * step
	while x < bounds.end.x:
		draw_line(_point(Vector3(x, 0, bounds.position.y), bounds, area), _point(Vector3(x, 0, bounds.end.y), bounds, area), grid)
		x += step
	var z := ceilf(bounds.position.y / step) * step
	while z < bounds.end.y:
		draw_line(_point(Vector3(bounds.position.x, 0, z), bounds, area), _point(Vector3(bounds.end.x, 0, z), bounds, area), grid)
		z += step
	draw_rect(area, Color("667875"), false, 2)

func _draw_markers(bounds: Rect2, area: Rect2, chapter_id: String, state: Dictionary) -> void:
	for entry: Variant in _entries(game.get("portal_nodes")):
		if entry is Dictionary and not entry.get("active", true):
			continue
		_mark(_position(entry), bounds, area, PORTAL, "portal")
	var ward_entries := _entries(game.get("wards"))
	for entry: Variant in ward_entries:
		_mark(_position(entry), bounds, area, WARD, "ward")
	for entry: Variant in _entries(game.get("fonts")):
		_mark(_position(entry), bounds, area, FONT, "font")
	var boss: Variant = game.get("boss")
	for entry: Variant in _entries(game.get("bosses")):
		_mark(_position(entry), bounds, area, BOSS, "boss")
	_mark(_position(boss), bounds, area, BOSS, "boss")

	var npcs: Variant = game.get("npc_nodes")
	if npcs == null:
		npcs = game.get("npcs")
	for entry: Variant in _entries(npcs):
		var label := str(entry.get("label", entry.get("name", entry.get("speaker", "")))) if entry is Dictionary else ""
		_mark(_position(entry), bounds, area, NPC, "npc", label)
	if npcs == null:
		var level_root: Node3D = game.get("level_root") as Node3D
		if is_instance_valid(level_root):
			for node: Node in level_root.get_children():
				var name_lower := String(node.name).to_lower()
				if name_lower.begins_with("memory_echo_echo_seraphina"):
					_mark(_position(node), bounds, area, NPC, "npc", "Seraphina")
				elif name_lower.begins_with("memory_echo_echo_malcor"):
					_mark(_position(node), bounds, area, NPC, "npc", "Malcor")

	var objective: Variant = game.get("objective_target")
	if game.has_method("get_objective_target"):
		objective = game.call("get_objective_target")
	if objective == null:
		objective = _legacy_objective(chapter_id, state, ward_entries, boss)
	_mark(_position(objective), bounds, area, OBJECTIVE, "objective")

	var player: Node3D = game.get("player") as Node3D
	if is_instance_valid(player):
		var forward := -player.global_transform.basis.z
		var heading := Vector2(forward.x, forward.z).normalized()
		var center := _point(player.global_position, bounds, area).clamp(area.position, area.end)
		draw_circle(center, 7, Color("111619"))
		draw_circle(center, 5, PLAYER, true, -1.0, true)
		var tip := center + heading * 20
		var wing := heading.orthogonal() * 4.5
		draw_line(center, tip, PLAYER, 2, true)
		draw_polyline(PackedVector2Array([tip - heading * 7 + wing, tip, tip - heading * 7 - wing]), PLAYER, 2, true)

func _legacy_objective(chapter_id: String, state: Dictionary, wards: Array, boss: Variant) -> Variant:
	match chapter_id:
		"ch1_court":
			if game.get("gate_open") == true:
				return _portal_to("ch2_tower", "tower")
			if game.get("has_arbalest") != true:
				return _pickup_of_kind("arbalest")
			if not state.get("has_lever", false):
				return _pickup_of_kind("iron_lever")
			if not state.get("lever_inserted", false):
				return game.get("switch_node")
			for plate: Variant in _entries(game.get("pressure_plates")):
				if plate is Dictionary and not plate.get("pressed", false):
					return plate
		"ch2_tower":
			if state.get("boss_dead", false):
				return _portal_to("ch3_kiln", "kiln")
			for ward: Variant in wards:
				if _position(ward) != null:
					return ward
			return boss
		"ch3_kiln":
			if state.get("great_gate_open", false):
				return null
			if game.get("has_ashen_key") == true:
				var left: Variant = _position(game.get("great_gate_left"))
				var right: Variant = _position(game.get("great_gate_right"))
				if left is Vector3 and right is Vector3:
					return (left + right) * 0.5
				return Vector3(0, 0, -21.5)
			if not state.get("trough_flooded", false):
				return game.get("aqueduct_valve")
			if not state.get("dam_broken", false):
				return game.get("ore_cart")
			return _pickup_of_kind("ashen_key") if state.get("key_forged", false) else game.get("hoist_lever")
	return null

func _portal_to(destination: String, legacy_destination: String) -> Variant:
	for entry: Variant in _entries(game.get("portal_nodes")):
		if entry is Dictionary and entry.get("destination") in [destination, legacy_destination]:
			return entry
	return null

func _pickup_of_kind(kind: String) -> Variant:
	for entry: Variant in _entries(game.get("pickups")):
		if entry is Dictionary and entry.get("kind") == kind:
			return entry
	return null

func _entries(entries: Variant) -> Array:
	if entries is Array:
		return entries
	if entries is Dictionary:
		return entries.values()
	return []

func _position(entry: Variant) -> Variant:
	var target: Variant = entry
	if entry is Dictionary:
		target = entry.get("node", entry.get("position", entry.get("pos")))
	if target is Vector3 and target.is_finite():
		return target
	if typeof(target) == TYPE_OBJECT and is_instance_valid(target) and target is Node3D and target.is_inside_tree():
		if not target.is_queued_for_deletion() and target.is_visible_in_tree():
			return target.global_position
	return null

func _point(world_pos: Vector3, bounds: Rect2, area: Rect2) -> Vector2:
	return area.position + (Vector2(world_pos.x, world_pos.z) - bounds.position) / bounds.size * area.size

func _mark(world_pos: Variant, bounds: Rect2, area: Rect2, tint: Color, kind: String, label: String = "") -> void:
	if not world_pos is Vector3 or not bounds.has_point(Vector2(world_pos.x, world_pos.z)):
		return
	var point := _point(world_pos, bounds, area)
	match kind:
		"portal":
			draw_circle(point, 8, tint, false, 2, true)
			draw_circle(point, 3, tint)
		"ward":
			_diamond(point, 6, tint)
		"font":
			draw_line(point - Vector2(5, 0), point + Vector2(5, 0), tint, 3, true)
			draw_line(point - Vector2(0, 5), point + Vector2(0, 5), tint, 3, true)
		"boss":
			_diamond(point, 9, tint)
		"objective":
			draw_circle(point, 12, tint, false, 2, true)
			draw_circle(point, 2, tint)
		"npc":
			draw_circle(point, 5, tint, true, -1.0, true)
			if not label.is_empty():
				_print(label, point + Vector2(10, 4), 104, 13, tint)

func _diamond(point: Vector2, radius: float, tint: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		point + Vector2(0, -radius), point + Vector2(radius, 0),
		point + Vector2(0, radius), point + Vector2(-radius, 0),
	]), tint)

func _print(caption: String, point: Vector2, width: float, font_size: int, tint: Color) -> void:
	draw_string(ThemeDB.fallback_font, point, caption, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, tint)
