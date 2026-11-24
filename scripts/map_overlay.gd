extends Control

var game
var captions := [
	"THE SUNKEN COURT   •   GATEHOUSE / WEST CISTERN / EAST CATACOMBS / PORTCULLIS",
	"THE BELL TOWER   •   NAVE / CLOCKWORK / PENDULUM / CHOIR / BELFRY SANCTUM",
	"THE KILN OF ASH   •   AQUEDUCT / SMELTERY / CRUCIBLE & GREAT GATE"
]

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

func _draw() -> void:
	if game == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.025, 0.027, 1.0), true)
	draw_rect(Rect2(Vector2(4, 4), size - Vector2(8, 8)), Color("8b7864"), false, 3)
	draw_string(ThemeDB.fallback_font, Vector2(35, 43), captions[game.stage], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("e2c49a"))
	draw_string(ThemeDB.fallback_font, Vector2(35, size.y - 27), "TAB CLOSE   •   GOLD: OBJECTIVE   •   VIOLET: PORTAL/WARD   •   CYAN: YOU", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("a9aca1"))
	var map_rect := Rect2(Vector2(155, 68), Vector2(650, 405))
	draw_rect(map_rect, Color("142028"), true)
	draw_rect(map_rect, Color("70827c"), false, 2)
	var bounds := Rect2(Vector2(-24.5, -31.5), Vector2(49, 66.5)) if game.stage == 0 else Rect2(Vector2(-32.5, -52.5), Vector2(65, 77)) if game.stage == 1 else Rect2(Vector2(-29.5, -23), Vector2(59, 48))
	var left := _point(Vector3(bounds.position.x, 0, bounds.position.y), bounds, map_rect)
	var right := _point(Vector3(bounds.end.x, 0, bounds.end.y), bounds, map_rect)
	draw_rect(Rect2(left, right - left), Color("314044"), true)
	draw_rect(Rect2(left, right - left), Color("929a8d"), false, 4)
	for x in range(-30, 31, 6):
		if x > bounds.position.x and x < bounds.end.x:
			draw_line(_point(Vector3(x, 0, bounds.position.y), bounds, map_rect), _point(Vector3(x, 0, bounds.end.y), bounds, map_rect), Color(0.6, 0.7, 0.65, 0.12), 1)
	for z in range(-50, 35, 6):
		if z > bounds.position.y and z < bounds.end.y:
			draw_line(_point(Vector3(bounds.position.x, 0, z), bounds, map_rect), _point(Vector3(bounds.end.x, 0, z), bounds, map_rect), Color(0.6, 0.7, 0.65, 0.12), 1)
	if game.stage == 0:
		_mark(Vector3(-16.5, 0, -1.0), bounds, map_rect, Color("8ace8a"), 8)
		_mark(Vector3(17.5, 0, -2.0), bounds, map_rect, Color("e5b96d"), 8)
		_mark(Vector3(-5.2, 0, -17.8), bounds, map_rect, Color("e5b96d"), 7)
		_mark(Vector3(-3.8, 0, -5.0), bounds, map_rect, Color("70d7df"), 6)
		_mark(Vector3(3.8, 0, -5.0), bounds, map_rect, Color("70d7df"), 6)
		_mark(Vector3(0, 0, -28.0), bounds, map_rect, Color("b763cf"), 10)
		draw_line(_point(Vector3(-4.8, 0, -19), bounds, map_rect), _point(Vector3(4.8, 0, -19), bounds, map_rect), Color("be9b70") if not game.gate_open else Color("6e8476"), 5)
	elif game.stage == 1:
		_mark(Vector3(0, 0, -38.0), bounds, map_rect, Color("e5b96d"), 11)
		for ward in game.wards:
			if is_instance_valid(ward):
				_mark(ward.position, bounds, map_rect, Color("b763cf"), 7)
		_mark(Vector3(20.0, 0, -7.8), bounds, map_rect, Color("f28a44"), 7)
		_mark(Vector3(0, 0, 21.5), bounds, map_rect, Color("b763cf"), 8)
	else:
		_mark(Vector3(-22.5, 0, -13.5), bounds, map_rect, Color("70d7df"), 9)
		_mark(Vector3(18.9, 0, -10.5), bounds, map_rect, Color("f28a44"), 9)
		_mark(Vector3(0, 0, -5.0), bounds, map_rect, Color("e5b96d"), 9)
		_mark(Vector3(0, 0, -21.5), bounds, map_rect, Color("b763cf"), 11)
	var player_pos := _point(game.player.position, bounds, map_rect)
	draw_circle(player_pos, 8, Color("5ce4e2"))
	var heading := Vector2(-sin(game.player.rotation.y), -cos(game.player.rotation.y))
	draw_line(player_pos, player_pos + heading * 20, Color("a9fcfb"), 3)

func _point(world_pos: Vector3, bounds: Rect2, area: Rect2) -> Vector2:
	var x := (world_pos.x - bounds.position.x) / bounds.size.x
	var z := (world_pos.z - bounds.position.y) / bounds.size.y
	return area.position + Vector2(x * area.size.x, z * area.size.y)

func _mark(world_pos: Vector3, bounds: Rect2, area: Rect2, color: Color, radius: float) -> void:
	var p := _point(world_pos, bounds, area)
	draw_circle(p, radius, color)
	draw_circle(p, radius + 2, Color("132026"), false, 2)
