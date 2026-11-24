class_name LevelBuilder
extends RefCounted

const LAYER_WORLD := 1
const LAYER_ENEMY := 2
const LAYER_PUSHABLE := 4
const LAYER_TARGET := 8
const LAYER_DEBRIS := 16

static func box(parent: Node3D, node_name: String, pos: Vector3, size: Vector3, mat: Material, solid: bool = true, layer: int = LAYER_WORLD) -> Node3D:
	var root: Node3D = StaticBody3D.new() if solid else Node3D.new()
	root.name = node_name
	root.position = pos
	if solid:
		root.collision_layer = layer
		root.collision_mask = 0
	parent.add_child(root)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = mat
	root.add_child(visual)
	if solid:
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		root.add_child(collider)
	return root

static func cylinder(parent: Node3D, node_name: String, pos: Vector3, radius: float, height: float, mat: Material, solid: bool = false, sides: int = 10, layer: int = LAYER_WORLD) -> Node3D:
	var root: Node3D = StaticBody3D.new() if solid else Node3D.new()
	root.name = node_name
	root.position = pos
	if solid:
		root.collision_layer = layer
		root.collision_mask = 0
	parent.add_child(root)
	var visual := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	visual.mesh = mesh
	visual.material_override = mat
	root.add_child(visual)
	if solid:
		var collider := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		collider.shape = shape
		root.add_child(collider)
	return root

static func cone(parent: Node3D, node_name: String, pos: Vector3, bottom: float, top: float, height: float, mat: Material, sides: int = 6) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	root.position = pos
	parent.add_child(root)
	var visual := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = sides
	visual.mesh = mesh
	visual.material_override = mat
	root.add_child(visual)
	return root

# Gothic stone archway with side piers, angled lintel, and brass keystone
static func archway(parent: Node3D, node_name: String, pos: Vector3, width: float, height: float, depth: float, stone_mat: Material, trim_mat: Material, rotate_y: float = 0.0) -> Node3D:
	var holder := Node3D.new()
	holder.name = node_name
	holder.position = pos
	holder.rotation.y = rotate_y
	parent.add_child(holder)
	var half_w := width * 0.5
	box(holder, "pier_l", Vector3(-half_w, height * 0.5, 0), Vector3(1.1, height, depth), stone_mat, true)
	box(holder, "pier_r", Vector3(half_w, height * 0.5, 0), Vector3(1.1, height, depth), stone_mat, true)
	box(holder, "lintel", Vector3(0, height + 0.55, 0), Vector3(width + 1.4, 1.15, depth + 0.25), stone_mat, false)
	box(holder, "keystone", Vector3(0, height + 0.45, 0), Vector3(0.95, 1.35, depth + 0.45), trim_mat, false)
	return holder

# Smooth, guarded stone staircase (visible steps + butter-smooth invisible collision ramp + banisters!)
static func staircase(parent: Node3D, node_name: String, start_pos: Vector3, end_pos: Vector3, width: float, step_mat: Material, rail_mat: Material) -> Node3D:
	var holder := Node3D.new()
	holder.name = node_name
	parent.add_child(holder)
	var delta := end_pos - start_pos
	var horiz := Vector2(delta.x, delta.z).length()
	var length := delta.length()
	var mid := (start_pos + end_pos) * 0.5 - Vector3(0, 0.25, 0)
	var yaw := atan2(delta.x, delta.z)
	var slope := -atan2(delta.y, maxf(0.01, horiz))

	# Smooth walk collision ramp
	var ramp_body := StaticBody3D.new()
	ramp_body.name = node_name + "_walk"
	ramp_body.position = mid
	ramp_body.rotation = Vector3(slope, yaw, 0)
	ramp_body.collision_layer = LAYER_WORLD
	ramp_body.collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, 0.5, length + 0.5)
	col.shape = shape
	ramp_body.add_child(col)
	holder.add_child(ramp_body)

	# Visual stone steps
	var steps := maxi(6, int(absf(delta.y) * 3.5))
	for i in steps:
		var t := (float(i) + 0.5) / float(steps)
		var sp := start_pos.lerp(end_pos, t)
		var step_depth := (horiz / float(steps)) + 0.12
		var step_h := (absf(delta.y) / float(steps)) + 0.35
		var s := box(holder, "step_%d" % i, sp - Vector3(0, step_h * 0.5, 0), Vector3(width, step_h, step_depth), step_mat, false)
		s.rotation.y = yaw

	# Guardrails on both sides so player can never slip off!
	var right_vec := Vector3(cos(yaw), 0, -sin(yaw))
	for side in [-1.0, 1.0]:
		var rail := StaticBody3D.new()
		rail.position = mid + right_vec * (side * (width * 0.5 + 0.2)) + Vector3(0, 0.85, 0)
		rail.rotation = Vector3(slope, yaw, 0)
		rail.collision_layer = LAYER_WORLD
		rail.collision_mask = 0
		var rvis := MeshInstance3D.new()
		var rmesh := BoxMesh.new()
		rmesh.size = Vector3(0.32, 1.25, length + 0.4)
		rvis.mesh = rmesh
		rvis.material_override = rail_mat
		rail.add_child(rvis)
		var rcol := CollisionShape3D.new()
		var rshape := BoxShape3D.new()
		rshape.size = Vector3(0.32, 1.25, length + 0.4)
		rcol.shape = rshape
		rail.add_child(rcol)
		holder.add_child(rail)
	return holder

static func add_trigger_volume(game, pos: Vector3, size: Vector3, trigger_id: String, objective_text: String = "", journal_id: String = "", journal_title: String = "", journal_body: String = "", short_msg: String = "", sound_name: String = "") -> Area3D:
	var area := Area3D.new()
	area.name = "trigger_" + trigger_id
	area.position = pos
	area.collision_layer = 0
	area.collision_mask = 32
	area.monitoring = true
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	area.add_child(col)
	game.level_root.add_child(area)
	area.body_entered.connect(func(body: Node3D) -> void:
		if body == game.player:
			game._on_trigger_entered(trigger_id, objective_text, journal_id, journal_title, journal_body, short_msg, sound_name)
	)
	return area

static func add_pushable_block(game, pos: Vector3, block_id: String, size: Vector3 = Vector3(1.4, 1.2, 1.4), color_mat: Material = null) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.name = "weighted_block_" + block_id
	body.position = pos
	body.mass = 4.5
	body.linear_damp = 2.6
	body.angular_damp = 4.0
	body.axis_lock_angular_x = true
	body.axis_lock_angular_z = true
	body.collision_layer = LAYER_PUSHABLE
	body.collision_mask = LAYER_WORLD | LAYER_ENEMY | LAYER_PUSHABLE | 32
	if game.stone_physics_mat != null:
		body.physics_material_override = game.stone_physics_mat
	game.level_root.add_child(body)
	var vis := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	vis.mesh = mesh
	vis.material_override = color_mat if color_mat else game.mats.dark
	body.add_child(vis)
	var band := MeshInstance3D.new()
	var bmesh := BoxMesh.new()
	bmesh.size = Vector3(size.x + 0.06, 0.16, size.z + 0.06)
	band.mesh = bmesh
	band.material_override = game.mats.brass
	body.add_child(band)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	body.set_meta("pushable_block", true)
	body.set_meta("id", block_id)
	game.pushable_blocks.append(body)
	return body

static func add_alchemical_font(game, pos: Vector3) -> void:
	var holder := Node3D.new()
	holder.name = "alchemical_font"
	holder.position = pos
	game.level_root.add_child(holder)
	cylinder(holder, "font_base", Vector3(0, 0.55, 0), 0.72, 1.1, game.mats.stone, true, 10)
	cylinder(holder, "font_basin", Vector3(0, 1.15, 0), 0.88, 0.25, game.mats.brass, false, 12)
	cylinder(holder, "font_liquid", Vector3(0, 1.24, 0), 0.72, 0.12, game.mats.mana, false, 12)
	game._light(pos + Vector3(0, 1.65, 0), Color("4cdce8"), 2.4, 6.5)
	game.fonts.append(holder)

static func add_rotten_barricade(game, pos: Vector3, bar_id: String, size: Vector3 = Vector3(2.8, 2.4, 0.45), is_secret: bool = false) -> void:
	if game.level_states[game.stage].broken.has(bar_id):
		return
	var bar := RigidBody3D.new()
	bar.name = "rotten_barricade_" + bar_id
	bar.position = pos
	bar.freeze = true
	bar.collision_layer = LAYER_PUSHABLE
	bar.collision_mask = LAYER_WORLD | 32
	game.level_root.add_child(bar)
	var vis := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	vis.mesh = mesh
	vis.material_override = game.mats.timber
	bar.add_child(vis)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	bar.add_child(col)
	bar.set_meta("breakable", true)
	bar.set_meta("barricade", true)
	bar.set_meta("secret", is_secret)
	bar.set_meta("id", bar_id)
	bar.set_meta("loot", "flask" if is_secret else "green")
	game.breakables.append(bar)

# Half-Life 2 style Explosive Alchemical Cask — grab & hurl with G or shoot to detonate!
static func add_explosive_cask(game, pos: Vector3, cask_id: String) -> void:
	if game.level_states[game.stage].broken.has(cask_id):
		return
	var cask := RigidBody3D.new()
	cask.name = "alchemical_cask_" + cask_id
	cask.position = pos + Vector3(0, 0.55, 0)
	cask.mass = 2.2
	cask.linear_damp = 1.4
	cask.angular_damp = 1.6
	cask.contact_monitor = true
	cask.max_contacts_reported = 4
	cask.collision_layer = LAYER_PUSHABLE
	cask.collision_mask = LAYER_WORLD | LAYER_ENEMY | LAYER_PUSHABLE | 32
	if game.stone_physics_mat != null:
		cask.physics_material_override = game.stone_physics_mat
	game.level_root.add_child(cask)
	cylinder(cask, "cask_body", Vector3.ZERO, 0.42, 1.05, game.mats.blood, false, 12)
	cylinder(cask, "cask_band_top", Vector3(0, 0.34, 0), 0.45, 0.12, game.mats.iron, false, 12)
	cylinder(cask, "cask_band_bot", Vector3(0, -0.34, 0), 0.45, 0.12, game.mats.iron, false, 12)
	cylinder(cask, "cask_core", Vector3(0, 0.0, 0), 0.44, 0.24, game.mats.cinder, false, 12)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.44
	shape.height = 1.05
	col.shape = shape
	cask.add_child(col)
	cask.set_meta("breakable", true)
	cask.set_meta("explosive_cask", true)
	cask.set_meta("id", cask_id)
	cask.set_meta("loot", "none")
	game.breakables.append(cask)

# Crystallized Memory Echo — plays non-blocking real-time story transmission on approach
static func add_memory_echo(game, pos: Vector3, echo_id: String, speaker: String, title: String, line: String, col_hex: String = "70d7df") -> void:
	var holder := Node3D.new()
	holder.name = "memory_echo_" + echo_id
	holder.position = pos
	game.level_root.add_child(holder)
	var shard := cylinder(holder, "echo_crystal", Vector3(0, 1.15, 0), 0.24, 1.1, game.mats.mana, false, 6)
	shard.rotation.z = 0.18
	game._light(pos + Vector3(0, 1.2, 0), Color(col_hex), 1.8, 5.5)
	var area := Area3D.new()
	area.position = Vector3(0, 1.0, 0)
	area.collision_layer = 0
	area.collision_mask = 32
	area.monitoring = true
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 3.6
	col.shape = shape
	area.add_child(col)
	holder.add_child(area)
	area.body_entered.connect(func(body: Node3D) -> void:
		if body == game.player:
			game._on_memory_echo(echo_id, speaker, title, line, Color(col_hex))
	)

# ==============================================================================
# LEVEL 1 (STAGE 0): THE SUNKEN COURT (Expanded 5-Zone Hub + 2 Secrets + Story)
# ==============================================================================
static func build_sunken_court(game) -> void:
	var root: Node3D = game.level_root
	var st: Dictionary = game.level_states[0]

	# Expansive Courtyard + South Entry Gatehouse + West Flooded Cistern + East Catacombs
	box(root, "courtyard_floor", Vector3(0, -0.3, 4.0), Vector3(48, 0.6, 62), game.mats.floor)
	box(root, "south_wall", Vector3(0, 4.0, 34.5), Vector3(48, 8.0, 1.2), game.mats.stone)
	box(root, "west_wall", Vector3(-24.0, 4.0, 4.0), Vector3(1.2, 8.0, 62), game.mats.stone)
	box(root, "east_wall", Vector3(24.0, 4.0, 4.0), Vector3(1.2, 8.0, 62), game.mats.stone)
	box(root, "north_left", Vector3(-14.4, 4.0, -19.0), Vector3(19.2, 8.0, 1.2), game.mats.stone)
	box(root, "north_right", Vector3(14.4, 4.0, -19.0), Vector3(19.2, 8.0, 1.2), game.mats.stone)
	box(root, "gate_lintel", Vector3(0, 5.8, -19.0), Vector3(10.0, 2.8, 1.4), game.mats.dark)

	# --- ZONE 1: SOUTH GATEHOUSE ENTRY TUNNEL (z: 18..34) ---
	box(root, "entry_wall_w", Vector3(-6.5, 3.8, 26.0), Vector3(1.2, 7.6, 16.0), game.mats.dark)
	box(root, "entry_wall_e", Vector3(6.5, 3.8, 26.0), Vector3(1.2, 7.6, 16.0), game.mats.dark)
	box(root, "entry_roof", Vector3(0, 7.4, 26.0), Vector3(14.2, 0.8, 16.0), game.mats.dark, false)
	archway(root, "entry_arch", Vector3(0, 0, 18.2), 7.8, 5.4, 1.5, game.mats.stone, game.mats.brass)
	game._torch(Vector3(-5.2, 2.5, 29.0))
	game._torch(Vector3(5.2, 2.5, 29.0))
	game._torch(Vector3(-5.2, 2.5, 21.0))
	game._torch(Vector3(5.2, 2.5, 21.0))
	add_alchemical_font(game, Vector3(-4.2, 0, 23.5))
	game._inscription(Vector3(4.2, 0, 23.5), "THE FIRST CINDER-BREAKER", "We marched into Vaelor believing the Bell Warden was a tyrant.\nNow I hear the tolling from beneath the cistern—the Gate is pulling the living IN.\nMy Arbalest lies in the flooded West Arcade. Take it. Break the three anchors.")

	# --- ZONE 2: WEST FLOODED CISTERN & ARCADE (x: -23..-9, z: -16..16) ---
	box(root, "west_divider_n", Vector3(-9.0, 3.5, -12.5), Vector3(1.2, 7.0, 11.0), game.mats.dark)
	box(root, "west_divider_s", Vector3(-9.0, 3.5, 11.5), Vector3(1.2, 7.0, 11.0), game.mats.dark)
	archway(root, "west_arcade_arch", Vector3(-9.0, 0, 0.0), 8.2, 5.4, 1.4, game.mats.stone, game.mats.brass, PI * 0.5)
	box(root, "west_flood_water", Vector3(-16.5, 0.05, 0.0), Vector3(14.0, 0.08, 30.0), game.mats.water, false)
	box(root, "arbalest_altar", Vector3(-16.5, 0.55, -1.0), Vector3(2.8, 1.1, 2.4), game.mats.stone)
	box(root, "arbalest_altar_rim", Vector3(-16.5, 1.15, -1.0), Vector3(3.1, 0.18, 2.7), game.mats.brass, false)
	game._light(Vector3(-16.5, 2.4, -1.0), Color("53d98d"), 2.2, 8.0)
	if not game.has_arbalest:
		game._pickup(Vector3(-16.5, 1.6, -1.0), "arbalest", "court_arbalest")
	# Secret Alcove #1 behind rotten barricade in NW Cistern (houses Ashen Relic #1: Heart of Vaelor!)
	box(root, "secret_w_wall", Vector3(-16.5, 3.5, -12.5), Vector3(14.0, 7.0, 1.0), game.mats.dark)
	add_rotten_barricade(game, Vector3(-16.5, 1.2, -10.5), "court_secret_bar_1", Vector3(4.0, 2.4, 0.45), true)
	game._pickup(Vector3(-20.5, 0.5, -15.5), "flask", "court_secret_flask_1")
	game._pickup(Vector3(-17.5, 0.85, -15.5), "relic_heart", "relic_heart_vaelor")
	game._pickup(Vector3(-14.5, 0.5, -15.5), "green", "court_secret_green_1")
	game._inscription(Vector3(-17.5, 0, -16.5), "SECRET: THE KING'S EDICT", "King Vaelor ordered the Gate sealed while half the lower ward still breathed.\nWhen the Bell Warden's chime cracked, the seal inverted in vengeance.")

	# Explosive Alchemical Casks & Memory Echoes in Level 1
	add_explosive_cask(game, Vector3(-12.5, 0, 2.0), "court_cask_west")
	add_explosive_cask(game, Vector3(4.5, 0, -10.5), "court_cask_north")
	add_explosive_cask(game, Vector3(14.0, 0, 1.5), "court_cask_east")
	add_memory_echo(game, Vector3(0, 0, 20.5), "echo_seraphina_1", "SERAPHINA (RESONANT STONE)", "THE INVERTED SEAL", "Cinder-Breaker, can you hear me? The seal is pulling the living inside. Grab heavy objects with [G] or hurl alchemical casks to survive—and find the Arbalest in the West Cistern.", "70d7df")
	add_memory_echo(game, Vector3(13.5, 0, -11.5), "echo_malcor_1", "LORD MALCOR (BELL WARDEN)", "THE WARDEN'S WARNING", "You break into my ossuary like a grave-robber. Do you know what sleeps beneath the Kiln? Every toll of my bell keeps the Choir buried!", "d99cbd")

	# --- ZONE 3: EAST SUNKEN OSSUARY & CATACOMBS (x: 9..23, z: -16..16) ---
	box(root, "east_divider_n", Vector3(9.0, 3.5, -13.0), Vector3(1.2, 7.0, 10.0), game.mats.dark)
	box(root, "east_divider_m", Vector3(9.0, 3.5, 0.0), Vector3(1.2, 7.0, 12.0), game.mats.dark)
	box(root, "east_divider_s", Vector3(9.0, 3.5, 14.5), Vector3(1.2, 7.0, 7.0), game.mats.dark)
	box(root, "east_crypt_roof", Vector3(16.5, 6.8, 0.0), Vector3(14.5, 0.7, 32.0), game.mats.dark, false)
	# One-way shortcut barred door at (9.0, 0, 8.5)
	var shortcut := StaticBody3D.new()
	shortcut.name = "shortcut_door"
	shortcut.position = Vector3(9.0, 0, 8.5)
	shortcut.collision_layer = LAYER_WORLD
	shortcut.collision_mask = 0
	root.add_child(shortcut)
	for i in range(-2, 3):
		box(shortcut, "shortcut_bar", Vector3(0, 2.2, i * 0.7), Vector3(0.24, 4.4, 0.14), game.mats.iron, false)
	var scol := CollisionShape3D.new()
	var sshape := BoxShape3D.new()
	sshape.size = Vector3(0.5, 4.4, 3.6)
	scol.shape = sshape
	scol.position.y = 2.2
	shortcut.add_child(scol)
	if st.get("shortcut_open", false):
		shortcut.position.y = 4.8
		shortcut.collision_layer = 0
	game.shortcut_door = shortcut

	box(root, "east_crypt_dais", Vector3(17.5, 0.35, -2.0), Vector3(3.6, 0.7, 3.6), game.mats.dark)
	box(root, "lever_pedestal", Vector3(17.5, 1.0, -2.0), Vector3(1.3, 0.7, 1.3), game.mats.brass)
	if not st.get("has_lever", false):
		game._pickup(Vector3(17.5, 1.75, -2.0), "iron_lever", "court_iron_lever")
	for z in [-10.0, -2.0, 6.0]:
		game._torch(Vector3(22.6, 2.5, z), "east_crypt")
	add_rotten_barricade(game, Vector3(13.0, 1.2, -9.0), "court_barricade_1", Vector3(4.2, 2.4, 0.45))
	# Secret Reliquary #2 in SE Catacombs
	add_rotten_barricade(game, Vector3(17.5, 1.2, 12.0), "court_secret_bar_2", Vector3(4.0, 2.4, 0.45), true)
	game._pickup(Vector3(19.5, 0.5, 15.5), "mana", "court_secret_mana_2")
	game._pickup(Vector3(15.5, 0.5, 15.5), "flask", "court_secret_flask_2")

	# --- ZONE 4: CENTRAL SUNKEN BASIN & COUNTERWEIGHT PUZZLE ---
	archway(root, "north_arch", Vector3(0, 0, -13.5), 9.0, 6.2, 1.6, game.mats.stone, game.mats.brass)
	box(root, "tower_silhouette", Vector3(-13.0, 11.0, -22.5), Vector3(6.5, 14.0, 5.0), game.mats.dark, false)
	cone(root, "ruined_spire", Vector3(-13.0, 22.0, -22.5), 3.4, 0.2, 9.0, game.mats.dark)
	for x in [-6.8, 6.8]:
		for z in [-8.5, 4.5, 12.5]:
			cylinder(root, "column", Vector3(x, 2.8, z), 0.72, 5.6, game.mats.stone, true, 12)
			box(root, "column_foot", Vector3(x, 0.3, z), Vector3(2.1, 0.6, 2.1), game.mats.dark)
	for z in [-12.0, 0.0, 12.0]:
		game._stained_glass(Vector3(-23.2, 4.2, z), true)
		game._stained_glass(Vector3(23.2, 4.2, z), false)
	for x in [-6.0, 6.0]:
		game._torch(Vector3(x, 2.6, -17.8))
		game._torch(Vector3(x, 2.6, 8.5))

	box(root, "central_grate", Vector3(0, 0.04, -5.0), Vector3(2.8, 0.06, 2.8), game.mats.iron, false)
	var plate_w := box(root, "plate_west", Vector3(-3.8, 0.06, -5.0), Vector3(2.3, 0.12, 2.3), game.mats.brass, false)
	var plate_e := box(root, "plate_east", Vector3(3.8, 0.06, -5.0), Vector3(2.3, 0.12, 2.3), game.mats.brass, false)
	game.pressure_plates.append({"node": plate_w, "pos": Vector3(-3.8, 0.0, -5.0), "pressed": false, "wet": false})
	game.pressure_plates.append({"node": plate_e, "pos": Vector3(3.8, 0.0, -5.0), "pressed": false, "wet": true})

	var channel_node := box(root, "rushing_water_channel", Vector3(3.8, 0.08, -5.0), Vector3(3.3, 0.14, 5.8), game.mats.water, true, LAYER_TARGET)
	game.water_channels.append({"node": channel_node, "pos": Vector3(3.8, 0.0, -5.0), "size": Vector3(3.3, 1.5, 5.8), "push_dir": Vector3(0, 0, 1), "frozen_timer": 0.0})
	add_pushable_block(game, Vector3(-3.8, 0.65, -0.4), "plinth_west")

	if st.get("cage_dropped", false):
		add_pushable_block(game, Vector3(3.8, 0.65, -9.5), "counterweight_east", Vector3(1.4, 1.2, 1.4), game.mats.iron)
	else:
		var cage := Node3D.new()
		cage.name = "suspended_cage"
		cage.position = Vector3(3.8, 5.6, -9.5)
		root.add_child(cage)
		box(cage, "cage_block", Vector3.ZERO, Vector3(1.4, 1.2, 1.4), game.mats.iron, false)
		box(cage, "cage_trim", Vector3(0, 0.65, 0), Vector3(1.55, 0.18, 1.55), game.mats.brass, false)
		var rope := cylinder(root, "cage_rope", Vector3(3.8, 7.2, -9.5), 0.38, 2.6, game.mats.brass, true, 8, LAYER_TARGET)
		rope.set_meta("shootable_rope", true)
		rope.set_meta("cage", cage)
		game.shootable_targets.append(rope)
		game._light(Vector3(3.8, 6.6, -9.5), Color("e5b96d"), 2.0, 6.0)

	# --- ZONE 5: NORTH PORTCULLIS & BELL TOWER PORTAL ---
	game.switch_node = Node3D.new()
	game.switch_node.name = "gatehouse_gearbox"
	game.switch_node.position = Vector3(-5.2, 0, -17.8)
	root.add_child(game.switch_node)
	box(game.switch_node, "gearbox_housing", Vector3(0, 1.2, 0), Vector3(1.0, 1.8, 0.7), game.mats.dark, true)
	box(game.switch_node, "gearbox_plate", Vector3(0, 1.45, 0.38), Vector3(0.7, 0.8, 0.12), game.mats.brass, false)
	var lever_arm := box(game.switch_node, "lever_arm", Vector3(0, 1.6, 0.65), Vector3(0.16, 0.75, 0.16), game.mats.iron, false)
	lever_arm.visible = st.get("lever_inserted", false)
	game.switch_node.set_meta("lever_arm", lever_arm)

	game._build_gate()
	box(root, "exit_floor", Vector3(0, -0.3, -25.0), Vector3(11, 0.6, 13), game.mats.dark)
	box(root, "exit_left", Vector3(-5.6, 3.4, -25.0), Vector3(0.9, 6.8, 13), game.mats.stone)
	box(root, "exit_right", Vector3(5.6, 3.4, -25.0), Vector3(0.9, 6.8, 13), game.mats.stone)
	box(root, "exit_end", Vector3(0, 3.4, -31.0), Vector3(12, 6.8, 0.9), game.mats.stone)
	game._portal(Vector3(0, 0, -28.0), "tower", "ENTER THE BELL TOWER")
	game._inscription(Vector3(0, 0, 8.0), "THE COURT SEALS", "Insert the Iron Lever in the north gearbox, then weight both basin plates.\nShoot the counterweight rope with the Arbalest, and freeze the rushing channel with Frost (RMB).")

	# Enemies across all 5 zones
	game._enemy(Vector3(0, 0, 12.0), false, "court_entry_shr", false, "shrieker")
	game._enemy(Vector3(0, 0, 2.0), false, "court_shrieker_1", false, "shrieker")
	game._enemy(Vector3(-14.0, 0, 6.0), false, "court_west_1", false, "shrieker")
	game._enemy(Vector3(-18.0, 0, -5.0), false, "court_west_2", false, "shrieker")
	game._enemy(Vector3(-13.5, 0, -1.2), true, "court_west_exec", false, "executioner")
	game._enemy(Vector3(5.0, 0, -12.0), true, "court_north_exec", false, "executioner")
	game._enemy(Vector3(14.0, 0, -5.0), false, "court_east_1", false, "shrieker")
	game._enemy(Vector3(19.5, 0, 3.0), false, "court_east_aco", false, "acolyte")

	game._pickup(Vector3(4.5, 0.5, 11.5), "mana", "court_blue_1")
	game._pickup(Vector3(-14.5, 0.5, 9.0), "green", "court_green_1")
	game._pickup(Vector3(19.0, 0.5, 6.5), "flask", "court_flask_1")
	game._pickup(Vector3(-5.0, 0.5, -14.5), "mana", "court_blue_2")
	game._pot(Vector3(-6.2, 0, 9.0), "court_pot_1", "flask")
	game._pot(Vector3(6.2, 0, -2.0), "court_pot_2", "green")
	game._pot(Vector3(15.2, 0, -6.0), "court_pot_3", "mana")

	add_trigger_volume(game, Vector3(0, 1.5, 16.0), Vector3(9.0, 3.5, 4.0), "court_vista", "", "court_vista", "THE BELL WARDEN'S TAUNT", "A booming, metallic voice echoes from the northern spire: 'Another Cinder-Breaker? The Gate does not fear your axe—it hungers for your memory.'", "VOICE FROM THE SPIRE: 'THE GATE HUNGERS FOR YOUR MEMORY...'", "bell")
	add_trigger_volume(game, Vector3(-14.0, 1.5, 2.0), Vector3(8.0, 3.0, 8.0), "west_arcade", "", "west_arcade", "THE FLOODED ARCADE", "Water pools beneath the western arches. An old Briar Arbalest rests on the altar—its spectral-iron bolts sever ropes and ring distant bells.", "WEST ARCADE  •  CLAIM THE BRIAR ARBALEST")
	add_trigger_volume(game, Vector3(0, 1.5, -23.0), Vector3(8.0, 3.5, 4.0), "court_exit_bell", "", "", "", "", "A DEEP BELL TOLLS FROM THE TOWER ON THE HORIZON", "bell")

	game._scatter_particles("ash", 85, Rect2(-22, -20, 44, 52))
	var moon_sprite := Sprite3D.new()
	moon_sprite.name = "ashen_moon"
	moon_sprite.texture = load("res://art/moon.png")
	moon_sprite.pixel_size = 0.085
	moon_sprite.position = Vector3(-24, 29, -56)
	moon_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	moon_sprite.shaded = false
	root.add_child(moon_sprite)

# ==============================================================================
# LEVEL 2 (STAGE 1): THE BELL TOWER — FULL ARCHITECTURAL REDESIGN!
# 5 Connected Chambers, Wide Guarded Stone Staircases, Zero Unfair Falls,
# Dedicated Belfry Sanctum Boss Arena!
# ==============================================================================
static func build_bell_tower(game) -> void:
	var root: Node3D = game.level_root
	var st: Dictionary = game.level_states[1]

	# --- CHAMBER 1: LOWER NAVE & ENTRY VESTIBULE (y = 0, x: -16..16, z: -8..24) ---
	box(root, "nave_floor", Vector3(0, -0.35, 8.0), Vector3(32, 0.7, 32), game.mats.stone)
	box(root, "nave_south", Vector3(0, 4.5, 24.0), Vector3(32, 9.0, 1.2), game.mats.dark)
	box(root, "nave_west_s", Vector3(-16.0, 4.5, 17.5), Vector3(1.2, 9.0, 13.0), game.mats.dark)
	box(root, "nave_east_s", Vector3(16.0, 4.5, 17.5), Vector3(1.2, 9.0, 13.0), game.mats.dark)
	box(root, "nave_ceiling", Vector3(0, 11.5, 8.0), Vector3(32, 0.8, 32), game.mats.dark, false)
	for x in [-9.0, 9.0]:
		for z in [16.0, 6.0, -2.0]:
			cylinder(root, "nave_col", Vector3(x, 5.5, z), 0.85, 11.0, game.mats.stone, true, 12)
			game._torch(Vector3(x * 0.85, 2.8, z))
	# Colossal bronze bells hanging high in the Nave ceiling (pure spectacle, solid floor below!)
	for pos in [Vector3(-4.0, 8.2, 6.0), Vector3(4.0, 8.2, 6.0), Vector3(0, 9.0, 1.0)]:
		game._hanging_bell(pos)
		cylinder(root, "nave_bell_chain", pos + Vector3(0, 2.5, 0), 0.14, 5.0, game.mats.iron, false, 6)
	add_alchemical_font(game, Vector3(-6.5, 0, 19.5))
	game._portal(Vector3(0, 0, 21.5), "courtyard", "RETURN TO THE SUNKEN COURT")
	game._inscription(Vector3(6.5, 0, 19.5), "THE WARDEN'S OATH", "Three resonant wards sustain the Warden's barrier:\n• WEST: Clockwork Gallery (Freeze the steam pipe)\n• EAST: Pendulum Foundry (Repulse the hanging clapper twice)\n• NORTH CHOIR: Harmonic Chimes (Shoot Crescent → Crown → Skull)")

	# --- CHAMBER 2: WEST WING — CLOCKWORK GALLERY & WARD 1 (y = 0, x: -32..-16, z: -10..12) ---
	archway(root, "west_wing_arch", Vector3(-16.0, 0, 2.0), 8.0, 5.5, 1.4, game.mats.stone, game.mats.brass, PI * 0.5)
	box(root, "clockwork_floor", Vector3(-24.0, -0.35, 1.0), Vector3(16.0, 0.7, 22.0), game.mats.stone)
	box(root, "clockwork_w", Vector3(-32.0, 4.0, 1.0), Vector3(1.2, 8.0, 22.0), game.mats.dark)
	box(root, "clockwork_n", Vector3(-24.0, 4.0, -10.0), Vector3(16.0, 8.0, 1.2), game.mats.dark)
	box(root, "clockwork_s", Vector3(-24.0, 4.0, 12.0), Vector3(16.0, 8.0, 1.2), game.mats.dark)
	box(root, "clockwork_roof", Vector3(-24.0, 8.0, 1.0), Vector3(16.0, 0.7, 22.0), game.mats.dark, false)
	game._torch(Vector3(-22.0, 2.6, 8.0))
	game._torch(Vector3(-22.0, 2.6, -6.0))
	game._stained_glass(Vector3(-31.2, 4.2, 1.0), true)

	if not st.wards.has("ward_1"):
		game._ward(Vector3(-29.2, 0.0, 1.0), "ward_1")
		if not st.get("gear_frozen", false):
			var gear := cylinder(root, "rotating_cogwheel", Vector3(-26.4, 2.0, 1.0), 2.1, 0.5, game.mats.iron, true, 12, LAYER_WORLD)
			gear.rotation.z = PI * 0.5
			game.tower_gear = gear
			var pipe := cylinder(root, "leaking_steam_pipe", Vector3(-24.5, 1.6, -2.2), 0.42, 2.8, game.mats.copper, true, 10, LAYER_TARGET)
			pipe.set_meta("steam_pipe", true)
			game.shootable_targets.append(pipe)
			game._light(Vector3(-24.5, 2.0, -2.2), Color("9ee9f5"), 2.0, 6.0)
	game._inscription(Vector3(-21.0, 0, 5.5), "WARD I — THE GEAR JAM", "A rotating cogwheel guards the first Ward.\nHit the copper steam pipe with Frost (RMB) to freeze the gears solid.")
	# Secret Gear-Vault behind rotten barricade in SW Clockwork Gallery (houses Ashen Relic #2: Siphon Signet!)
	add_rotten_barricade(game, Vector3(-28.5, 1.2, 8.5), "tower_secret_bar_1", Vector3(3.6, 2.4, 0.45), true)
	game._pickup(Vector3(-29.5, 0.5, 10.5), "flask", "tower_secret_flask_1")
	game._pickup(Vector3(-28.0, 0.85, 10.5), "relic_siphon", "relic_siphon_signet")
	game._pickup(Vector3(-26.5, 0.5, 10.5), "mana", "tower_secret_mana_1")

	# Explosive Alchemical Casks & Memory Echoes in Level 2
	add_explosive_cask(game, Vector3(-4.5, 0, 6.0), "tower_cask_nave")
	add_explosive_cask(game, Vector3(4.5, 3.5, -14.5), "tower_cask_choir")
	add_explosive_cask(game, Vector3(-7.0, 7.0, -35.0), "tower_cask_arena_w")
	add_explosive_cask(game, Vector3(7.0, 7.0, -35.0), "tower_cask_arena_e")
	add_memory_echo(game, Vector3(0, 0, 12.5), "echo_seraphina_2", "SERAPHINA (RESONANT STONE)", "THE THREE ANCHORS", "The Bell Tower is a giant resonator. Silence the three Wards in the West Clockwork Gallery, East Pendulum Foundry, and North Choir before stepping into the Belfry Sanctum.", "70d7df")
	add_memory_echo(game, Vector3(0, 3.5, -18.5), "echo_malcor_2", "LORD MALCOR (BELL WARDEN)", "BEFORE THE SANCTUM", "King Vaelor gave me the bell and fled. Forty nights I have stood here as my flesh turned to ash—if you silence me, you must descend into the Kiln and finish what I could not!", "d99cbd")

	# --- CHAMBER 3: EAST WING — PENDULUM FOUNDRY & WARD 2 (y = 0 -> y = 3.5, x: 16..32, z: -10..12) ---
	archway(root, "east_wing_arch", Vector3(16.0, 0, 2.0), 8.0, 5.5, 1.4, game.mats.stone, game.mats.brass, PI * 0.5)
	box(root, "foundry_floor_low", Vector3(24.0, -0.35, 6.0), Vector3(16.0, 0.7, 12.0), game.mats.stone)
	box(root, "foundry_balcony", Vector3(24.0, 3.15, -4.5), Vector3(16.0, 0.7, 11.0), game.mats.timber)
	staircase(root, "east_foundry_stairs", Vector3(20.0, 0.0, 6.5), Vector3(20.0, 3.5, 0.5), 4.2, game.mats.stone, game.mats.iron)
	box(root, "foundry_e", Vector3(32.0, 5.0, 1.0), Vector3(1.2, 10.0, 22.0), game.mats.dark)
	box(root, "foundry_n", Vector3(24.0, 5.0, -10.0), Vector3(16.0, 10.0, 1.2), game.mats.dark)
	box(root, "foundry_s", Vector3(24.0, 5.0, 12.0), Vector3(16.0, 10.0, 1.2), game.mats.dark)
	box(root, "foundry_roof", Vector3(24.0, 9.8, 1.0), Vector3(16.0, 0.7, 22.0), game.mats.dark, false)
	game._torch(Vector3(22.0, 6.0, -7.5))
	game._torch(Vector3(30.5, 6.0, -2.0))
	game._stained_glass(Vector3(31.2, 5.5, 2.0), false)

	# Weapon 3 Unlock: Cinder Thurible Reliquary on East Balcony!
	box(root, "reliquary_altar", Vector3(20.0, 4.0, -7.8), Vector3(2.6, 1.0, 2.0), game.mats.dark)
	box(root, "reliquary_rim", Vector3(20.0, 4.55, -7.8), Vector3(2.9, 0.16, 2.3), game.mats.brass, false)
	game._light(Vector3(20.0, 5.6, -7.8), Color("ff8030"), 2.2, 6.5)
	if not game.has_thurible:
		game._pickup(Vector3(20.0, 5.0, -7.8), "thurible", "tower_thurible")

	if not st.wards.has("ward_2"):
		game._ward(Vector3(29.8, 3.5, -4.5), "ward_2")
		var cracked := box(root, "cracked_brick_wall", Vector3(27.8, 5.0, -4.5), Vector3(0.65, 3.0, 3.8), game.mats.clay, true, LAYER_WORLD) as StaticBody3D
		game.tower_cracked_wall = cracked
		var clapper := RigidBody3D.new()
		clapper.name = "pendulum_clapper"
		clapper.position = Vector3(24.8, 5.1, -4.5)
		clapper.freeze = true
		clapper.collision_layer = LAYER_PUSHABLE
		clapper.collision_mask = 0
		root.add_child(clapper)
		cylinder(clapper, "clapper_body", Vector3.ZERO, 0.58, 1.65, game.mats.brass, false, 12)
		cylinder(clapper, "clapper_chain", Vector3(0, 2.0, 0), 0.12, 2.8, game.mats.iron, false, 6)
		var ccol := CollisionShape3D.new()
		var cshape := CylinderShape3D.new()
		cshape.radius = 0.7
		cshape.height = 1.9
		ccol.shape = cshape
		clapper.add_child(ccol)
		clapper.set_meta("pendulum", true)
		clapper.set_meta("hits", 0)
		clapper.set_meta("base_pos", Vector3(24.8, 5.1, -4.5))
		game.tower_pendulum = clapper
		game._light(Vector3(24.8, 5.6, -4.5), Color("f2b955"), 2.0, 6.0)
	game._inscription(Vector3(24.5, 3.5, -1.0), "WARD II — THE PENDULUM", "Strike the hanging bronze bell clapper twice with Repulse (Q)\nto smash through the cracked wall and shatter the second Ward.")

	# --- CHAMBER 4: NORTH CHOIR LOFT & HARMONIC GALLERY (y = 3.5, x: -16..16, z: -24..-8) ---
	box(root, "choir_floor", Vector3(0, 3.15, -16.0), Vector3(32, 0.7, 16.0), game.mats.stone)
	box(root, "choir_w", Vector3(-16.0, 7.5, -16.0), Vector3(1.2, 9.0, 16.0), game.mats.dark)
	box(root, "choir_e", Vector3(16.0, 7.5, -16.0), Vector3(1.2, 9.0, 16.0), game.mats.dark)
	# Twin wide guarded grand staircases from Lower Nave up to Choir Loft!
	staircase(root, "choir_stairs_w", Vector3(-11.0, 0.0, -2.0), Vector3(-11.0, 3.5, -9.0), 4.4, game.mats.stone, game.mats.iron)
	staircase(root, "choir_stairs_e", Vector3(11.0, 0.0, -2.0), Vector3(11.0, 3.5, -9.0), 4.4, game.mats.stone, game.mats.iron)
	game._torch(Vector3(-12.5, 6.0, -16.0))
	game._torch(Vector3(12.5, 6.0, -16.0))

	# Ward 3 (Harmonic Chimes) on Choir West Balcony Alcove
	if not st.wards.has("ward_3"):
		game._ward(Vector3(-13.8, 3.5, -16.0), "ward_3")
		var shutter := box(root, "ward3_shutter", Vector3(-12.0, 5.1, -16.0), Vector3(0.5, 3.2, 4.0), game.mats.iron, true, LAYER_WORLD) as StaticBody3D
		game.ward3_shutter = shutter
		var bell_specs := [
			{"pos": Vector3(-9.8, 6.0, -19.0), "idx": 0, "name": "CRESCENT", "mat": game.mats.mana, "pitch": 0.78},
			{"pos": Vector3(-9.8, 6.4, -16.0), "idx": 1, "name": "CROWN", "mat": game.mats.brass, "pitch": 1.0},
			{"pos": Vector3(-9.8, 6.8, -13.0), "idx": 2, "name": "SKULL", "mat": game.mats.portal, "pitch": 1.28}
		]
		for spec in bell_specs:
			var hbell := cylinder(root, "harmonic_bell_" + str(spec.idx), spec.pos, 0.54, 0.9, spec.mat, true, 12, LAYER_TARGET)
			hbell.set_meta("harmonic_bell", true)
			hbell.set_meta("bell_idx", spec.idx)
			hbell.set_meta("bell_name", spec.name)
			hbell.set_meta("bell_pitch", spec.pitch)
			game.shootable_targets.append(hbell)
	game._inscription(Vector3(-7.0, 3.5, -12.5), "WARD III — HARMONIC CHIMES", "Shoot the three hanging bells with the Arbalest from lowest to highest:\n1. CRESCENT (Cyan)   →   2. CROWN (Gold)   →   3. SKULL (Violet)")

	# --- CHAMBER 5: THE BELFRY SANCTUM — BELL WARDEN BOSS ARENA (y = 7.0, x: -17..17, z: -52..-24) ---
	staircase(root, "sanctum_grand_stairs", Vector3(0, 3.5, -19.5), Vector3(0, 7.0, -26.5), 5.6, game.mats.stone, game.mats.brass)
	archway(root, "sanctum_arch", Vector3(0, 7.0, -26.5), 8.0, 6.2, 1.6, game.mats.stone, game.mats.brass)
	# Four slabs around central trapdoor at (0, 7.0, -38.0)
	box(root, "sanctum_south", Vector3(0, 6.65, -29.5), Vector3(34, 0.7, 11.0), game.mats.stone)
	box(root, "sanctum_north", Vector3(0, 6.65, -46.5), Vector3(34, 0.7, 11.0), game.mats.stone)
	box(root, "sanctum_west", Vector3(-10.5, 6.65, -38.0), Vector3(13.0, 0.7, 6.4), game.mats.stone)
	box(root, "sanctum_east", Vector3(10.5, 6.65, -38.0), Vector3(13.0, 0.7, 6.4), game.mats.stone)
	# Sanctum outer parapets (open dusk sky overhead!)
	box(root, "sanctum_wall_n", Vector3(0, 10.5, -52.0), Vector3(34, 7.5, 1.2), game.mats.dark)
	box(root, "sanctum_wall_w", Vector3(-17.0, 10.5, -38.0), Vector3(1.2, 7.5, 28.0), game.mats.dark)
	box(root, "sanctum_wall_e", Vector3(17.0, 10.5, -38.0), Vector3(1.2, 7.5, 28.0), game.mats.dark)
	box(root, "sanctum_wall_sw", Vector3(-10.5, 10.5, -24.5), Vector3(13.0, 7.5, 1.2), game.mats.dark)
	box(root, "sanctum_wall_se", Vector3(10.5, 10.5, -24.5), Vector3(13.0, 7.5, 1.2), game.mats.dark)
	# 4 Tactical Cover Pillars in the Boss Arena
	for px in [-8.5, 8.5]:
		for pz in [-32.0, -44.0]:
			cylinder(root, "arena_pillar", Vector3(px, 10.2, pz), 1.05, 6.5, game.mats.stone, true, 12)
			game._torch(Vector3(px * 0.86, 9.2, pz))
	game._rune_circle(Vector3(0, 7.0, -38.0), 5.8)

	var floorboards := box(root, "belfry_floorboards", Vector3(0, 6.65, -38.0), Vector3(7.6, 0.7, 6.4), game.mats.timber, true, LAYER_WORLD) as StaticBody3D
	game.belfry_floorboards = floorboards
	if st.boss_dead:
		floorboards.visible = false
		floorboards.collision_layer = 0
		game._portal(Vector3(0, 7.0, -38.0), "kiln", "DESCEND TO THE KILN OF ASH")

	# Boss & Enemies (Boss stays dormant until player enters the Sanctum!)
	if not st.boss_dead:
		game._enemy(Vector3(0, 7.1, -38.0), true, "warden", true, "warden")
	game._enemy(Vector3(-6.0, 0.1, 8.0), false, "tower_nave_1", false, "shrieker")
	game._enemy(Vector3(6.0, 0.1, 4.0), false, "tower_nave_2", false, "shrieker")
	game._enemy(Vector3(-22.0, 0.1, 2.0), true, "tower_west_exec", false, "executioner")
	game._enemy(Vector3(24.0, 0.1, 6.0), false, "tower_east_shr", false, "shrieker")
	game._enemy(Vector3(23.0, 3.6, -4.0), false, "tower_east_aco", false, "acolyte")
	game._enemy(Vector3(6.0, 3.6, -15.0), false, "tower_choir_aco", false, "acolyte")
	game._enemy(Vector3(0.0, 3.6, -14.0), true, "tower_choir_exec", false, "executioner")

	# Pickups & Urns
	game._pickup(Vector3(10.0, 0.5, 16.0), "mana", "tower_blue_1")
	game._pickup(Vector3(-19.0, 0.5, -5.0), "green", "tower_green_1")
	game._pickup(Vector3(28.0, 4.0, -1.0), "flask", "tower_flask_1")
	game._pickup(Vector3(-12.0, 7.5, -30.0), "mana", "tower_blue_2")
	game._pickup(Vector3(12.0, 7.5, -30.0), "green", "tower_green_2")
	game._pickup(Vector3(0.0, 7.5, -48.5), "flask", "tower_arena_flask")
	game._pot(Vector3(-11.0, 0.0, 12.0), "tower_pot_1", "green")
	game._pot(Vector3(12.0, 3.5, -18.0), "tower_pot_2", "flask")
	game._pot(Vector3(11.0, 7.0, -45.0), "tower_pot_3", "mana")

	add_trigger_volume(game, Vector3(0, 8.5, -28.0), Vector3(12.0, 4.0, 4.0), "belfry_sanctum", "", "belfry_sanctum", "THE BELFRY SANCTUM", "The Bell Warden rises above the cracked boards, his wrought-iron bell rack groaning in the wind. 'Silence my wards if you dare—you will only wake what sleeps in the Kiln below!'", "THE BELL WARDEN AWAKENS! BREAK ALL 3 WARDS TO SHATTER HIS SHIELD!", "bell")
	game._scatter_particles("ember", 75, Rect2(-24, -48, 48, 68))

# ==============================================================================
# LEVEL 3 (STAGE 2): THE KILN OF ASH (Expanded 5-Wing Subterranean Foundry)
# ==============================================================================
static func build_kiln_of_ash(game) -> void:
	var root: Node3D = game.level_root
	var st: Dictionary = game.level_states[2]

	# Main Crucible Hall + South Landing
	box(root, "kiln_center_floor", Vector3(0, -0.35, 1.0), Vector3(16.0, 0.7, 46.0), game.mats.basalt)
	box(root, "kiln_south_wall", Vector3(0, 5.0, 24.0), Vector3(58.0, 11.0, 1.2), game.mats.basalt)
	box(root, "kiln_north_wall_l", Vector3(-18.5, 5.0, -21.5), Vector3(24.0, 11.0, 1.2), game.mats.basalt)
	box(root, "kiln_north_wall_r", Vector3(18.5, 5.0, -21.5), Vector3(24.0, 11.0, 1.2), game.mats.basalt)
	box(root, "kiln_west_wall", Vector3(-29.0, 5.0, 1.0), Vector3(1.2, 11.0, 46.0), game.mats.basalt)
	box(root, "kiln_east_wall", Vector3(29.0, 5.0, 1.0), Vector3(1.2, 11.0, 46.0), game.mats.basalt)

	# Boiling Molten Slag Channels flanking the Crucible Hall
	for sx in [-9.6, 9.6]:
		box(root, "slag_channel", Vector3(sx, -0.25, -2.0), Vector3(3.4, 0.3, 40.0), game.mats.slag, false)
		game._light(Vector3(sx, 1.4, -2.0), Color("ff5c24"), 2.8, 12.0)
		game._light(Vector3(sx, 1.4, 10.0), Color("ff5c24"), 2.4, 10.0)
		game.slag_zones.append({"pos": Vector3(sx, 0.0, -2.0), "half": Vector2(1.7, 19.5)})
	for bz in [4.0, -10.0]:
		box(root, "west_bridge", Vector3(-9.6, -0.05, bz), Vector3(4.6, 0.35, 3.8), game.mats.iron)
		box(root, "east_bridge", Vector3(9.6, -0.05, bz), Vector3(4.6, 0.35, 3.8), game.mats.iron)
		archway(root, "bridge_arch_w_%d" % int(bz), Vector3(-11.4, 0, bz), 4.4, 4.4, 1.0, game.mats.basalt, game.mats.brass, PI * 0.5)
		archway(root, "bridge_arch_e_%d" % int(bz), Vector3(11.4, 0, bz), 4.4, 4.4, 1.0, game.mats.basalt, game.mats.brass, PI * 0.5)

	# --- WEST WING: THE FROZEN AQUEDUCT ---
	box(root, "aqueduct_floor", Vector3(-20.0, -0.35, 1.0), Vector3(17.5, 0.7, 42.0), game.mats.stone)
	box(root, "aqueduct_pool", Vector3(-20.0, 0.04, -3.0), Vector3(14.0, 0.08, 20.0), game.mats.water, false)
	box(root, "valve_platform", Vector3(-22.5, 2.0, -13.5), Vector3(7.5, 4.0, 6.0), game.mats.dark)
	box(root, "aqueduct_rafter", Vector3(-15.5, 4.0, -13.5), Vector3(4.5, 0.5, 4.5), game.mats.timber)
	# Secret Cistern Cache behind barricade (houses Ashen Relic #3: Cinder-Breaker's Oath!)
	add_rotten_barricade(game, Vector3(-24.0, 1.2, 12.0), "kiln_secret_bar_1", Vector3(4.2, 2.4, 0.45), true)
	game._pickup(Vector3(-25.5, 0.5, 16.5), "flask", "kiln_secret_flask_1")
	game._pickup(Vector3(-23.8, 0.85, 16.5), "relic_oath", "relic_cinder_oath")
	game._pickup(Vector3(-22.0, 0.5, 16.5), "green", "kiln_secret_green_1")

	# Explosive Alchemical Casks & Memory Echoes in Level 3
	add_explosive_cask(game, Vector3(-3.5, 0, 5.5), "kiln_cask_center_w")
	add_explosive_cask(game, Vector3(3.5, 0, -11.0), "kiln_cask_center_e")
	add_explosive_cask(game, Vector3(16.0, 0, -2.5), "kiln_cask_smeltery")
	add_memory_echo(game, Vector3(0, 0, 14.5), "echo_seraphina_3", "SERAPHINA (RESONANT STONE)", "THE TRUTH OF THE KILN", "Malcor was telling the truth... The kingdom didn't just bury the dead here. They smelted their memories into basalt to forge the Great Gate. Cool the mold, claim the Ashen Key, and break the cycle!", "70d7df")
	add_memory_echo(game, Vector3(0, 0, -16.5), "echo_choir_1", "THE HOLLOW CHOIR", "BEYOND THE GREAT GATE", "A chorus of a thousand quiet voices hums behind the iron doors: 'Open the Gate, Cinder-Breaker. Give us back our names.'", "f0c27b")

	var spout_positions := [
		Vector3(-15.5, 1.0, 2.5),
		Vector3(-18.8, 2.1, -2.5),
		Vector3(-21.5, 3.1, -7.8)
	]
	for idx in spout_positions.size():
		var spos: Vector3 = spout_positions[idx]
		var spout := box(root, "water_spout_" + str(idx), spos, Vector3(2.6, 0.5, 2.6), game.mats.water, true, LAYER_TARGET) as StaticBody3D
		var stream := cylinder(root, "water_stream_" + str(idx), spos + Vector3(0, 1.8, 0), 0.30, 3.6, game.mats.water, false, 10)
		spout.set_meta("water_spout", true)
		spout.set_meta("stream", stream)
		spout.set_meta("frozen_timer", 0.0)
		game.water_spouts.append(spout)
		game.shootable_targets.append(spout)
		game._light(spos + Vector3(0, 0.9, 0), Color("53c5e8"), 1.6, 5.5)

	var valve := Node3D.new()
	valve.name = "aqueduct_valve"
	valve.position = Vector3(-22.5, 4.0, -13.5)
	root.add_child(valve)
	cylinder(valve, "valve_post", Vector3(0, 0.7, 0), 0.25, 1.4, game.mats.iron, true, 10)
	var wheel := cylinder(valve, "valve_wheel", Vector3(0, 1.45, 0), 0.74, 0.16, game.mats.brass, false, 12)
	valve.set_meta("wheel", wheel)
	game.aqueduct_valve = valve
	game._inscription(Vector3(-13.5, 0.0, 7.0), "NORTH AQUEDUCT", "Freeze the three cascading water spouts with Frost (RMB)\nto form stepping stones up to the Aqueduct Valve.")

	# --- EAST WING: THE DEEP SMELTERY ---
	box(root, "smeltery_floor", Vector3(20.0, -0.35, 1.0), Vector3(17.5, 0.7, 42.0), game.mats.basalt)
	box(root, "rail_left", Vector3(18.0, 0.08, -2.0), Vector3(0.16, 0.14, 21.0), game.mats.iron, false)
	box(root, "rail_right", Vector3(19.8, 0.08, -2.0), Vector3(0.16, 0.14, 21.0), game.mats.iron, false)
	var cart := RigidBody3D.new()
	cart.name = "heavy_ore_cart"
	cart.position = Vector3(18.9, 0.85, -9.5 if st.get("dam_broken", false) else 5.5)
	cart.mass = 5.5
	cart.linear_damp = 1.6
	cart.axis_lock_linear_x = true
	cart.axis_lock_angular_x = true
	cart.axis_lock_angular_y = true
	cart.axis_lock_angular_z = true
	cart.collision_layer = LAYER_PUSHABLE
	cart.collision_mask = LAYER_WORLD | LAYER_ENEMY | LAYER_PUSHABLE | 32
	root.add_child(cart)
	box(cart, "cart_body", Vector3.ZERO, Vector3(1.95, 1.15, 2.35), game.mats.iron, false)
	box(cart, "cart_ore", Vector3(0, 0.55, 0), Vector3(1.65, 0.4, 1.95), game.mats.cinder, false)
	var cart_col := CollisionShape3D.new()
	var cart_shape := BoxShape3D.new()
	cart_shape.size = Vector3(1.95, 1.2, 2.35)
	cart_col.shape = cart_shape
	cart.add_child(cart_col)
	cart.set_meta("ore_cart", true)
	game.ore_cart = cart
	game.pushable_blocks.append(cart)

	var dam := box(root, "slag_dam", Vector3(18.9, 1.2, -10.5), Vector3(3.8, 2.4, 1.2), game.mats.cinder, true, LAYER_WORLD) as StaticBody3D
	game.slag_dam = dam
	if st.get("dam_broken", false):
		dam.visible = false
		dam.collision_layer = 0
	game._inscription(Vector3(13.5, 0.0, 7.0), "SOUTH SMELTERY", "Shove the heavy ore-cart down the rails with Repulse (Q)\nto smash the slag dam and power the Crucible hoist.")

	# --- CENTRAL CRUCIBLE HALL: Key Mold, Cooling Trough, Hoist, Cauldrons, Great Gate ---
	box(root, "trough_frame", Vector3(0, 0.35, -5.0), Vector3(3.8, 0.7, 3.0), game.mats.dark)
	var trough_water := box(root, "trough_water", Vector3(0, 0.62, -5.0), Vector3(3.2, 0.2, 2.4), game.mats.water, false)
	trough_water.visible = st.get("trough_flooded", false)
	game.trough_water = trough_water

	var mold := Node3D.new()
	mold.name = "key_mold"
	mold.position = Vector3(0, 2.4, -5.0)
	root.add_child(mold)
	box(mold, "mold_body", Vector3.ZERO, Vector3(1.2, 0.65, 0.8), game.mats.cinder, false)
	cylinder(mold, "mold_chain", Vector3(0, 2.5, 0), 0.1, 4.6, game.mats.iron, false, 6)
	mold.visible = not st.get("key_forged", false)
	game.key_mold = mold
	if st.get("key_forged", false) and not game.has_ashen_key:
		game._pickup(Vector3(0, 1.2, -5.0), "ashen_key", "kiln_ashen_key")

	var hoist := Node3D.new()
	hoist.name = "chain_hoist_lever"
	hoist.position = Vector3(3.4, 0, -5.0)
	root.add_child(hoist)
	box(hoist, "hoist_base", Vector3(0, 1.1, 0), Vector3(0.7, 1.6, 0.7), game.mats.dark, true)
	box(hoist, "hoist_arm", Vector3(0, 1.65, 0.45), Vector3(0.14, 0.75, 0.14), game.mats.brass, false)
	game.hoist_lever = hoist

	for cidx in 2:
		var cpos := Vector3(-4.0, 6.4, 2.0) if cidx == 0 else Vector3(4.0, 6.4, -12.0)
		var cid := "cauldron_%d" % cidx
		if st.get("dropped_cauldrons", []).has(cid):
			continue
		var cauldron := Node3D.new()
		cauldron.name = cid
		cauldron.position = cpos
		root.add_child(cauldron)
		cylinder(cauldron, "cauldron_pot", Vector3.ZERO, 1.2, 1.3, game.mats.iron, false, 12)
		cylinder(cauldron, "cauldron_slag", Vector3(0, 0.55, 0), 1.0, 0.2, game.mats.slag, false, 12)
		var chain := cylinder(root, "cauldron_chain_" + cid, cpos + Vector3(0, 1.6, 0), 0.38, 2.4, game.mats.brass, true, 8, LAYER_TARGET)
		chain.set_meta("cauldron_chain", true)
		chain.set_meta("cauldron", cauldron)
		chain.set_meta("id", cid)
		game.shootable_targets.append(chain)
		game._light(cpos + Vector3(0, 0.8, 0), Color("ff7832"), 2.2, 7.0)

	# Great Ashen Gate (twin iron doors on North wall at z = -21.5)
	var great_l := box(root, "great_gate_left", Vector3(-3.3, 4.0, -21.5), Vector3(6.6, 8.0, 1.0), game.mats.iron, true, LAYER_WORLD) as StaticBody3D
	var great_r := box(root, "great_gate_right", Vector3(3.3, 4.0, -21.5), Vector3(6.6, 8.0, 1.0), game.mats.iron, true, LAYER_WORLD) as StaticBody3D
	box(great_l, "gate_trim_l", Vector3(0, 0, 0.55), Vector3(5.8, 0.45, 0.16), game.mats.brass, false)
	box(great_r, "gate_trim_r", Vector3(0, 0, 0.55), Vector3(5.8, 0.45, 0.16), game.mats.brass, false)
	game.great_gate_left = great_l
	game.great_gate_right = great_r
	box(root, "horizon_glow", Vector3(0, 4.5, -26.0), Vector3(18.0, 10.0, 0.4), game.mats.portal, false)
	game._light(Vector3(0, 3.8, -22.5), Color("d5a8ff"), 3.6, 14.0)

	add_alchemical_font(game, Vector3(-5.0, 0, 17.5))
	game._inscription(Vector3(5.0, 0, 17.5), "THE KILN OF ASH", "Vaelor's furnace forged the Great Gate—and burned the memories of its dead into basalt.\nAsh Sentinels cannot be slowed by Frost, but Thermal Shock (Frost + Thurible) or a falling Slag Cauldron will shatter them.")
	game._portal(Vector3(0, 0, 21.5), "tower", "RETURN TO THE BELL TOWER")

	for x in [-6.8, 6.8]:
		for z in [-15.0, -2.0, 11.0, 18.0]:
			game._torch(Vector3(x, 2.6, z))

	# Initial Level 3 Enemies
	game._enemy(Vector3(0, 0.1, 2.5), true, "kiln_ash_1", false, "ash_sentinel")
	game._enemy(Vector3(18.9, 0.1, -3.5), true, "kiln_smelt_ash", false, "ash_sentinel")
	game._enemy(Vector3(16.0, 0.1, 2.0), false, "kiln_smelt_shr", false, "shrieker")
	game._enemy(Vector3(-15.5, 4.3, -13.5), false, "kiln_aq_aco_1", false, "acolyte")
	game._enemy(Vector3(-21.0, 0.1, 4.0), false, "kiln_aq_shr", false, "shrieker")

	game._pickup(Vector3(4.5, 0.5, 13.0), "mana", "kiln_blue_1")
	game._pickup(Vector3(-4.5, 0.5, -14.5), "green", "kiln_green_1")
	game._pickup(Vector3(22.0, 0.5, 10.0), "flask", "kiln_flask_1")
	game._pickup(Vector3(-22.5, 4.5, -11.0), "mana", "kiln_blue_2")
	game._pot(Vector3(-5.5, 0, 6.0), "kiln_pot_1", "flask")
	game._pot(Vector3(5.5, 0, -10.0), "kiln_pot_2", "green")
	game._pot(Vector3(14.5, 0, -13.0), "kiln_pot_3", "mana")

	add_trigger_volume(game, Vector3(0, 1.5, 11.0), Vector3(12, 3.5, 5), "kiln_entry", "", "kiln_entry", "THE KILN OF ASH", "Beneath the tower lies the furnace that tempered the Gate's iron. Divert the underground river in the Aqueduct, smash the slag dam in the Smeltery, then cool the crucible to claim the Ashen Key.", "THE KILN OF ASH  •  RESTORE THE COOLING SLUICES")
	game._scatter_particles("ember", 95, Rect2(-26, -20, 52, 42))
