class_name LevelBuilder
extends RefCounted

const LAYER_WORLD := 1
const LAYER_ENEMY := 2
const LAYER_PUSHABLE := 4
const LAYER_TARGET := 8
const LAYER_DEBRIS := 16
const LAYER_PLAYER := 32

const BELFRY_WARDS := {
	"ward_1": {"color": Color("82e6ff"), "label": "I  ·  WEST GALLERY"},
	"ward_2": {"color": Color("ffc385"), "label": "II  ·  EAST FOUNDRY"},
	"ward_3": {"color": Color("bba1ff"), "label": "III  ·  CHOIR CHIMES"},
}

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
	area.collision_mask = LAYER_PLAYER
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
	body.collision_mask = LAYER_WORLD | LAYER_ENEMY | LAYER_PUSHABLE | LAYER_PLAYER
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
	body.set_meta("interact_hint", "WEIGHTED PLINTH — PUSH OR GRASP [G]")
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
	if chapter_state(game).get("broken", []).has(bar_id):
		return
	var bar := RigidBody3D.new()
	bar.name = "rotten_barricade_" + bar_id
	bar.position = pos
	bar.freeze = true
	bar.collision_layer = LAYER_PUSHABLE
	bar.collision_mask = LAYER_WORLD | LAYER_PLAYER
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
	bar.set_meta("interact_hint", "ROTTEN BARRICADE — SMASH [1/2/3]")
	bar.set_meta("secret", is_secret)
	bar.set_meta("id", bar_id)
	bar.set_meta("loot", "flask" if is_secret else "green")
	game.breakables.append(bar)

# Half-Life 2 style Explosive Alchemical Cask — grab & hurl with G or shoot to detonate!
static func add_explosive_cask(game, pos: Vector3, cask_id: String) -> void:
	if chapter_state(game).get("broken", []).has(cask_id):
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
	cask.collision_mask = LAYER_WORLD | LAYER_ENEMY | LAYER_PUSHABLE | LAYER_PLAYER
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
	cask.set_meta("interact_hint", "ALCHEMICAL CASK — GRASP [G] OR SHOOT TO DETONATE")
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
	area.collision_mask = LAYER_PLAYER
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

# The two circular arcs meet at a pointed crown. Each chord carries a brass rib
# and overlaps its neighbor slightly to keep the masonry continuous.
static func vaulted_rib(parent: Node3D, pos: Vector3, span_x: float, height: float, mat: Material, trim_mat: Material) -> Node3D:
	var rib := Node3D.new()
	rib.name = "vaulted_rib"
	rib.position = pos
	parent.add_child(rib)
	var half_span := span_x * 0.5
	var arc_angle := 1.15
	var arc_width := 1.0 - cos(arc_angle)
	var arc_height := sin(arc_angle)
	var thickness := clampf(span_x * 0.038, 0.32, 0.85)
	for side: float in [-1.0, 1.0]:
		var previous := Vector3(side * half_span, 0.0, 0.0)
		for i in range(1, 9):
			var theta := arc_angle * float(i) / 8.0
			var x := side * half_span * (1.0 - (1.0 - cos(theta)) / arc_width)
			var point := Vector3(x, height * sin(theta) / arc_height, 0.0)
			var chord := point - previous
			var segment := box(rib, "rib_stone", (previous + point) * 0.5, Vector3(chord.length() + thickness * 0.4, thickness, thickness * 1.45), mat, false)
			segment.rotation.z = atan2(chord.y, chord.x)
			box(segment, "rib_molding", Vector3(0.0, -side * thickness * 0.5, 0.0), Vector3(chord.length() + thickness * 0.2, thickness * 0.24, thickness), trim_mat, false)
			previous = point
	var boss := box(rib, "vault_boss", Vector3(0.0, height - thickness * 0.2, 0.0), Vector3.ONE * thickness * 1.4, trim_mat, false)
	boss.rotation.z = PI * 0.25
	return rib

# Decorative chains share one mesh. Neighboring links turn through a quarter circle.
static func hanging_chain(parent: Node3D, top: Vector3, bottom: Vector3, radius: float, iron_mat: Material) -> void:
	var span := bottom - top
	var length := span.length()
	if is_zero_approx(length):
		return
	var ring := TorusMesh.new()
	ring.inner_radius = radius * 0.61
	ring.outer_radius = radius
	ring.rings = 10
	ring.ring_segments = 6
	var count := maxi(1, ceili(length / (radius * 2.2)))
	var links := MultiMesh.new()
	links.transform_format = MultiMesh.TRANSFORM_3D
	links.mesh = ring
	links.instance_count = count
	for i in count:
		var rotation := Basis.from_euler(Vector3(PI * 0.5, (i % 2) * PI * 0.5, 0))
		var offset := Vector3.DOWN * length * (float(i) + 0.5) / float(count)
		links.set_instance_transform(i, Transform3D(rotation * Basis.from_scale(Vector3(1, 1, 1.5)), offset))
	var chain := MultiMeshInstance3D.new()
	chain.name = "hanging_iron_chain"
	chain.multimesh = links
	chain.material_override = iron_mat
	chain.position = top
	chain.quaternion = Quaternion(Vector3.DOWN, span.normalized())
	parent.add_child(chain)

# The position marks the glowing core; chain_len reaches up to the support.
static func hanging_chain_lamp(game, parent: Node3D, pos: Vector3, chain_len: float, light_color: Color, energy: float, reach: float) -> Node3D:
	var lamp := Node3D.new()
	lamp.name = "chain_lantern"
	lamp.position = pos
	parent.add_child(lamp)
	hanging_chain(lamp, Vector3.UP * (0.4 + chain_len), Vector3.UP * 0.4, 0.09, game.mats.iron)
	cylinder(lamp, "ceiling_anchor", Vector3.UP * (0.4 + chain_len), 0.18, 0.12, game.mats.iron, false, 8)
	cone(lamp, "bronze_hood", Vector3.UP * 0.27, 0.37, 0.1, 0.26, game.mats.brass, 8)
	cone(lamp, "bronze_bowl", Vector3.DOWN * 0.27, 0.21, 0.36, 0.19, game.mats.brass, 8)
	var glow: StandardMaterial3D = game._material(light_color, true)
	cone(lamp, "glowing_coals", Vector3.DOWN * 0.07, 0.25, 0.16, 0.32, glow, 8)
	for i in 8:
		var angle := TAU * float(i) / 8.0
		var bar := box(lamp, "cage_bar", Vector3(cos(angle), 0, sin(angle)) * 0.32, Vector3(0.045, 0.42, 0.055), game.mats.iron, false)
		bar.rotation.y = -angle
	var light := OmniLight3D.new()
	light.position = Vector3.DOWN * 0.22
	light.light_color = light_color
	light.light_energy = energy
	light.omni_range = reach
	light.light_volumetric_fog_energy = 0.26
	lamp.add_child(light)
	return lamp

static func focus_light(parent: Node3D, pos: Vector3, target: Vector3, color: Color, energy: float, angle: float, fog_energy: float = 0.2) -> SpotLight3D:
	var light := SpotLight3D.new()
	light.position = pos
	light.quaternion = Quaternion(Vector3.FORWARD, pos.direction_to(target))
	light.light_color = color
	light.light_energy = energy
	light.spot_angle = angle
	light.spot_range = pos.distance_to(target) + 4.0
	light.light_volumetric_fog_energy = fog_energy
	parent.add_child(light)
	return light

# The foot projects toward local +Z and the raking brace ties back into the wall.
static func gothic_buttress(parent: Node3D, pos: Vector3, height: float, depth: float, stone_mat: Material, trim_mat: Material) -> Node3D:
	var buttress := Node3D.new()
	buttress.name = "flying_buttress"
	buttress.position = pos
	parent.add_child(buttress)
	var width := height * 0.21
	var foot := depth * 0.62
	box(buttress, "plinth", Vector3(0, height * 0.045, foot), Vector3(width * 1.35, height * 0.09, depth * 0.77), stone_mat, false)
	var bevel := cone(buttress, "plinth_bevel", Vector3(0, height * 0.115, foot), 0.96, 0.74, height * 0.05, trim_mat, 4)
	bevel.rotation.y = PI * 0.25
	bevel.scale = Vector3(width, 1, depth * 0.57)
	box(buttress, "lower_pier", Vector3(0, height * 0.29, foot), Vector3(width, height * 0.40, depth * 0.46), stone_mat, false)
	box(buttress, "upper_pier", Vector3(0, height * 0.54, foot), Vector3(width * 0.76, height * 0.30, depth * 0.34), stone_mat, false)
	box(buttress, "pier_cornice", Vector3(0, height * 0.61, foot), Vector3(width * 0.94, height * 0.035, depth * 0.43), trim_mat, false)
	var start := Vector3(0, height * 0.95, 0)
	var end := Vector3(0, height * 0.59, foot)
	var slope := end - start
	var brace := box(buttress, "raking_brace", (start + end) * 0.5, Vector3(width * 0.72, height * 0.095, slope.length()), stone_mat, false)
	brace.rotation.x = atan2(-slope.y, slope.z)
	box(brace, "brace_molding", Vector3(0, -height * 0.057, 0), Vector3(width * 0.88, height * 0.021, slope.length()), trim_mat, false)
	var cap := cone(buttress, "pier_cap", Vector3(0, height * 0.72, foot), 0.69, 0.38, height * 0.095, stone_mat, 4)
	cap.rotation.y = PI * 0.25
	cap.scale = Vector3(width, 1, depth * 0.43)
	return buttress

# Build the recess in front of the wall with deep jambs and a dark inset face.
static func ossuary_niche(parent: Node3D, pos: Vector3, rot_y: float, dark_mat: Material, bone_mat: Material) -> Node3D:
	var niche := Node3D.new()
	niche.name = "ossuary_niche"
	niche.position = pos
	niche.rotation.y = rot_y
	parent.add_child(niche)
	var recess := StandardMaterial3D.new()
	recess.albedo_color = Color("17171b")
	recess.roughness = 1.0
	box(niche, "recess", Vector3(0, 0.76, 0.02), Vector3(1.26, 1.52, 0.08), recess, false)
	box(niche, "sill", Vector3(0, 0.09, 0.23), Vector3(1.72, 0.18, 0.58), dark_mat, false)
	for side: float in [-1, 1]:
		box(niche, "jamb", Vector3(side * 0.71, 0.69, 0.2), Vector3(0.23, 1.38, 0.4), dark_mat, false)
		box(niche, "impost", Vector3(side * 0.7, 1.36, 0.22), Vector3(0.32, 0.13, 0.48), dark_mat, false)
	vaulted_rib(niche, Vector3(0, 1.38, 0.21), 1.44, 0.67, dark_mat, dark_mat)
	cone(niche, "urn_foot", Vector3(-0.31, 0.22, 0.25), 0.13, 0.12, 0.08, dark_mat, 8)
	cone(niche, "funerary_urn", Vector3(-0.31, 0.41, 0.25), 0.13, 0.23, 0.32, bone_mat, 10)
	cone(niche, "urn_shoulder", Vector3(-0.31, 0.62, 0.25), 0.23, 0.1, 0.12, bone_mat, 10)
	cylinder(niche, "urn_lid", Vector3(-0.31, 0.71, 0.25), 0.13, 0.065, dark_mat, false, 10)
	var skull := MeshInstance3D.new()
	var cranium := SphereMesh.new()
	cranium.radius = 0.18
	cranium.height = 0.33
	cranium.radial_segments = 10
	cranium.rings = 5
	skull.mesh = cranium
	skull.material_override = bone_mat
	skull.position = Vector3(0.28, 0.38, 0.25)
	niche.add_child(skull)
	box(niche, "skull_jaw", Vector3(0.28, 0.23, 0.34), Vector3(0.21, 0.1, 0.16), bone_mat, false)
	for x: float in [0.21, 0.35]:
		box(niche, "eye_socket", Vector3(x, 0.385, 0.407), Vector3(0.078, 0.065, 0.036), recess, false)
	return niche

# A shallow iron lattice overlays an existing walkable surface.
static func iron_grate_floor(parent: Node3D, pos: Vector3, size: Vector2, iron_mat: Material) -> Node3D:
	var grate := Node3D.new()
	grate.name = "iron_floor_grate"
	grate.position = pos
	parent.add_child(grate)
	for side: float in [-1, 1]:
		box(grate, "side_frame", Vector3(side * size.x * 0.5, 0.033, 0), Vector3(0.14, 0.063, size.y + 0.14), iron_mat, false)
		box(grate, "end_frame", Vector3(0, 0.033, side * size.y * 0.5), Vector3(size.x, 0.063, 0.14), iron_mat, false)
	var slats := maxi(2, ceili(size.x / 0.24))
	for i in range(1, slats):
		var x := size.x * (float(i) / float(slats) - 0.5)
		box(grate, "grate_slat", Vector3(x, 0.021, 0), Vector3(0.059, 0.04, size.y), iron_mat, false)
	for z: float in [-0.25, 0.25]:
		box(grate, "cross_tie", Vector3(0, 0.027, z * size.y), Vector3(size.x, 0.048, 0.08), iron_mat, false)
	return grate

static func add_voltaic_conduit(game, pos: Vector3, conduit_id: String, target_label: String) -> StaticBody3D:
	var conduit := cylinder(game.level_root, conduit_id, pos, 0.55, 1.55, game.mats.copper, true, 12, LAYER_TARGET) as StaticBody3D
	conduit.set_meta("voltaic_conduit", true)
	conduit.set_meta("interact_hint", "VOLTAIC CONDUIT — ZAP WITH FORK [4]")
	conduit.set_meta("id", conduit_id)
	conduit.set_meta("target_label", target_label)
	for i in range(-2, 3):
		cylinder(conduit, "coil_turn", Vector3(0.0, i * 0.22, 0.0), 0.62, 0.095, game.mats.brass, false, 16)
	for y: float in [-0.8, 0.8]:
		cylinder(conduit, "charged_terminal", Vector3(0.0, y, 0.0), 0.28, 0.24, game.mats.mana, false, 12)
	game._light(pos, Color("54dae8"), 1.6, 5.5)
	game.voltaic_conduits.append(conduit)
	game.shootable_targets.append(conduit)
	return conduit

static func add_checkpoint_zone(game, pos: Vector3, size: Vector3, checkpoint_id: String, label: String) -> Area3D:
	var area := Area3D.new()
	area.name = "checkpoint_" + checkpoint_id
	area.position = pos
	area.collision_layer = 0
	area.collision_mask = LAYER_PLAYER
	area.monitorable = false
	area.set_meta("id", checkpoint_id)
	area.set_meta("label", label)
	var collider := CollisionShape3D.new()
	var volume := BoxShape3D.new()
	volume.size = size
	collider.shape = volume
	area.add_child(collider)
	game.level_root.add_child(area)
	game.checkpoint_triggers.append(area)
	area.body_entered.connect(func(body: Node3D) -> void:
		if body == game.player:
			game._on_checkpoint_reached(checkpoint_id, label)
	)
	return area

# Returns the live zone so runtime weather (Belfry Phase II rain) can toggle or remove it.
static func add_wet_zone(game, pos: Vector3, half_xz: Vector2) -> Dictionary:
	var zone := {"pos": pos, "half": half_xz, "active": true}
	game.wet_zones.append(zone)
	return zone

static func set_wet_zone_active(zone: Dictionary, active: bool) -> void:
	zone["active"] = active

static func remove_wet_zone(game, zone: Dictionary) -> void:
	game.wet_zones.erase(zone)

static func chapter_state(game) -> Dictionary:
	var states: Dictionary = game.level_states
	if game.level_root.has_meta("chapter_id"):
		var chapter_id: String = game.level_root.get_meta("chapter_id")
		if states.has(chapter_id):
			return states[chapter_id]
	return states[game.stage]

static func slab(parent: Node3D, node_name: String, bounds: Rect2, top: float, mat: Material, thickness: float = 0.7) -> StaticBody3D:
	return box(parent, node_name, Vector3(bounds.get_center().x, top - thickness * 0.5, bounds.get_center().y), Vector3(bounds.size.x, thickness, bounds.size.y), mat) as StaticBody3D

static func lever(parent: Node3D, node_name: String, pos: Vector3, base_mat: Material, trim_mat: Material, hint: String = "LEVER — PULL [E]") -> Node3D:
	var assembly := Node3D.new()
	assembly.name = node_name
	assembly.position = pos
	parent.add_child(assembly)
	var pedestal := box(assembly, "lever_pedestal", Vector3(0, 0.55, 0), Vector3(0.7, 1.1, 0.7), base_mat)
	var arm := box(assembly, "lever_arm", Vector3(0, 1.28, 0.14), Vector3(0.16, 0.65, 0.16), trim_mat, false)
	arm.rotation.x = 0.4
	box(arm, "handle", Vector3(0, 0.3, 0), Vector3(0.48, 0.13, 0.16), trim_mat, false)
	assembly.set_meta("lever_arm", arm)
	assembly.set_meta("interact_hint", hint)
	pedestal.set_meta("interact_hint", hint)
	return assembly

static func add_steam_jet(parent: Node3D, pos: Vector3, dir: Vector3 = Vector3.UP, color: Color = Color(0.75, 0.92, 1.0, 0.55)) -> GPUParticles3D:
	var jet := GPUParticles3D.new()
	jet.name = "steam_jet"
	jet.position = pos
	jet.amount = 32
	jet.lifetime = 1.45
	jet.preprocess = 1.45
	jet.visibility_aabb = AABB(Vector3(-10, -5, -10), Vector3(20, 15, 20))
	jet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.16, 0.65, 1.0])
	fade.colors = PackedColorArray([Color(color, 0.0), color, Color(color, color.a * 0.6), Color(color, 0.0)])
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade
	var expansion := Curve.new()
	expansion.add_point(Vector2(0.0, 0.24))
	expansion.add_point(Vector2(1.0, 1.0))
	var expansion_texture := CurveTexture.new()
	expansion_texture.curve = expansion
	var motion := ParticleProcessMaterial.new()
	motion.direction = dir.normalized()
	motion.spread = 19.0
	motion.initial_velocity_min = 2.1
	motion.initial_velocity_max = 3.8
	motion.gravity = Vector3(0, 0.85, 0)
	motion.scale_min = 0.7
	motion.scale_max = 1.4
	motion.scale_curve = expansion_texture
	motion.color_ramp = fade_texture
	jet.process_material = motion

	var falloff := Gradient.new()
	falloff.offsets = PackedFloat32Array([0.0, 0.32, 1.0])
	falloff.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.68), Color(1, 1, 1, 0)])
	var puff := GradientTexture2D.new()
	puff.gradient = falloff
	puff.width = 64
	puff.height = 64
	puff.fill = GradientTexture2D.FILL_RADIAL
	puff.fill_from = Vector2(0.5, 0.5)
	puff.fill_to = Vector2(1.0, 0.5)
	var mist := StandardMaterial3D.new()
	mist.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mist.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mist.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mist.vertex_color_use_as_albedo = true
	mist.albedo_texture = puff
	var quad := QuadMesh.new()
	quad.size = Vector2(1.7, 1.7)
	quad.material = mist
	jet.draw_pass_1 = quad
	parent.add_child(jet)
	return jet

static func add_floor_conduit(parent: Node3D, points: PackedVector3Array, unpowered_mat: Material, powered_mat: Material, width: float = 0.22) -> Node3D:
	var conduit := Node3D.new()
	conduit.name = "floor_conduit"
	parent.add_child(conduit)
	var housing := StandardMaterial3D.new()
	housing.albedo_color = Color("563b2b")
	housing.metallic = 0.64
	housing.roughness = 0.6
	var segments: Array[MeshInstance3D] = []
	for i in range(1, points.size()):
		var start := points[i - 1]
		var end := points[i]
		var delta := end - start
		var length := delta.length()
		if is_zero_approx(length):
			continue
		var casing := box(conduit, "bronze_channel", (start + end) * 0.5 + Vector3.UP * 0.025, Vector3(width, 0.048, length + width), housing, false)
		casing.quaternion = Quaternion(Vector3.BACK, delta / length)
		var inlay := box(casing, "rune_inlay", Vector3.UP * 0.026, Vector3(width * 0.54, 0.014, length + width * 0.54), unpowered_mat, false)
		segments.append(inlay.get_child(0) as MeshInstance3D)
	conduit.set_meta("segments", segments)
	conduit.set_meta("unpowered_mat", unpowered_mat)
	conduit.set_meta("powered_mat", powered_mat)
	conduit.set_meta("powered", false)
	return conduit

static func set_floor_conduit_powered(conduit: Node3D, powered: bool) -> void:
	if conduit.get_meta("powered") == powered:
		return
	conduit.set_meta("powered", powered)
	var material: Material = conduit.get_meta("powered_mat" if powered else "unpowered_mat")
	for segment: MeshInstance3D in conduit.get_meta("segments"):
		segment.material_override = material

# Follow the gameplay state while the owning level node is in the scene tree.
static func watch_puzzle(parent: Node3D, refresh: Callable) -> void:
	refresh.call()
	var indicator := Timer.new()
	indicator.name = "puzzle_indicator"
	indicator.wait_time = 0.05
	indicator.process_callback = Timer.TIMER_PROCESS_PHYSICS
	indicator.autostart = true
	indicator.timeout.connect(refresh)
	parent.add_child(indicator)

static func add_belfry_ward_seal(game, parent: Node3D, pos: Vector3, width: float = 7.4, height: float = 5.6) -> StaticBody3D:
	var barrier := StandardMaterial3D.new()
	barrier.albedo_color = Color(0.36, 0.12, 0.66, 0.31)
	barrier.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	barrier.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var seal := box(parent, "belfry_ward_seal", pos, Vector3(width, height, 0.22), barrier) as StaticBody3D
	seal.get_child(0).position.y = height * 0.5
	seal.get_child(1).position.y = height * 0.5
	seal.get_child(0).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	seal.set_meta("belfry_seal", true)
	seal.set_meta("interact_hint", "BELFRY SEALED — SHATTER THE 3 TOWER WARDS")
	var violet: StandardMaterial3D = game._material(Color("a878e4"), true)
	violet.emission_energy_multiplier = 0.48
	for y: float in [height * 0.02, height * 0.98]:
		box(seal, "seal_border", Vector3(0, y, 0.14), Vector3(width, 0.045, 0.035), violet, false)
	for i in range(3):
		var sigil_arc := vaulted_rib(seal, Vector3(0, height * (0.15 + i * 0.16), 0.14), width * 0.83, height * 0.31, violet, violet)
		sigil_arc.scale = Vector3(1.0, 1.0, 0.16)
	var title := Label3D.new()
	title.text = "BELFRY SEALED"
	title.position = Vector3(0, height * 0.82, 0.34)
	title.font_size = 56
	title.pixel_size = 0.007
	title.modulate = Color("efd8ff")
	seal.add_child(title)

	var sigils := {}
	for id: String in BELFRY_WARDS:
		var ward: Dictionary = BELFRY_WARDS[id]
		var chain := Node3D.new()
		chain.name = id + "_seal_chain"
		chain.position = Vector3(width * (float(sigils.size()) - 1.0) * 0.28, height * 0.43, 0.25)
		seal.add_child(chain)
		var glow: StandardMaterial3D = game._material(ward.color, true)
		glow.emission_energy_multiplier = 1.05
		hanging_chain(chain, Vector3.UP * height * 0.39, Vector3.DOWN * height * 0.37, 0.115, glow)
		var rune := box(chain, "ward_sigil", Vector3(0, 0, 0.055), Vector3(0.46, 0.46, 0.08), glow, false)
		rune.rotation.z = PI * 0.25
		var label := Label3D.new()
		label.text = ward.label
		var plaque := box(chain, "ward_route_plaque", Vector3(0, -0.68, 0.15), Vector3(1.95, 0.29, 0.06), game.mats.dark, false)
		label.position.z = 0.043
		label.font_size = 36
		label.pixel_size = 0.005
		label.modulate = ward.color
		plaque.add_child(label)
		sigils[id] = chain
	seal.set_meta("sigil_nodes", sigils)

	var st := chapter_state(game)
	var broken: Array = st.wards
	for id: String in sigils:
		sigils[id].visible = not broken.has(id)
	if broken.has("ward_1") and broken.has("ward_2") and broken.has("ward_3"):
		seal.collision_layer = 0
		seal.hide()
		return seal

	watch_puzzle(seal, func() -> void:
		if seal.collision_layer == 0:
			return
		var intact := 0
		for id: String in sigils:
			var sigil: Node3D = sigils[id]
			if not st.wards.has(id):
				intact += 1
			elif sigil.visible and not sigil.has_meta("shattering"):
				sigil.set_meta("shattering", true)
				var shatter := sigil.create_tween().set_parallel()
				shatter.tween_property(sigil, "scale:y", 0.03, 0.19)
				shatter.tween_property(sigil, "rotation:z", 0.45, 0.19)
				shatter.chain().tween_callback(sigil.hide)
		if intact == 0:
			seal.collision_layer = 0
			var collapse := seal.create_tween()
			collapse.tween_property(seal, "scale:y", 0.025, 0.24)
			collapse.tween_callback(seal.hide)
	)
	return seal

# Keep the original entry points available while main.gd migrates to the registry.
static func build_sunken_court(game) -> void:
	var registry: GDScript = load("res://scripts/chapters/chapter_registry.gd")
	registry.build(game, "ch1_court")

static func build_bell_tower(game) -> void:
	var registry: GDScript = load("res://scripts/chapters/chapter_registry.gd")
	registry.build(game, "ch2_tower")

static func build_kiln_of_ash(game) -> void:
	var registry: GDScript = load("res://scripts/chapters/chapter_registry.gd")
	registry.build(game, "ch3_kiln")

# ---------------------------------------------------------------------------
# Act I story construction toolkit: physical routes, murals, set-pieces and
# the shared far-landmark skyline. Every helper builds under the given parent
# and returns a handle StoryDirector can drive later.
# ---------------------------------------------------------------------------

const STORY_BODY_LIMIT := 24
const DEBRIS_LIFETIME := 5.0
const CHANDELIER_DEADLINE := 3.5

static var _mural_normals := {}
static var _story_bodies: Array = []

# Player-only route sensor. StoryDirector owns crossing direction and travel.
static func add_transition_zone(parent: Node3D, zone_transform: Transform3D, size: Vector3, route_id: String) -> Area3D:
	var area := Area3D.new()
	area.name = "transition_" + route_id
	area.transform = zone_transform
	area.collision_layer = 0
	area.collision_mask = LAYER_PLAYER
	area.monitorable = false
	area.monitoring = true
	area.set_meta("route_id", route_id)
	area.set_meta("size", size)
	var collider := CollisionShape3D.new()
	var volume := BoxShape3D.new()
	volume.size = size
	collider.shape = volume
	area.add_child(collider)
	var aperture := Marker3D.new()
	aperture.name = "aperture"
	area.add_child(aperture)
	area.set_meta("aperture", aperture)
	parent.add_child(area)
	return area

# Framed art faces local +Z with the wall surface at z = 0.
static func add_wall_mural(game, parent: Node3D, mural_id: String, pose: Transform3D, size: Vector2, art: Texture2D, normal: Texture2D = null, inspect: Dictionary = {}) -> Node3D:
	var mural := Node3D.new()
	mural.name = "mural_" + mural_id
	mural.transform = pose
	parent.add_child(mural)
	var stone := _game_mat(game, "dark", Color("4d5557"))
	var brass := _game_mat(game, "brass", Color("b98a4e"))
	var w := size.x
	var h := size.y
	var rail := clampf(minf(w, h) * 0.09, 0.16, 0.42)
	box(mural, "mural_backing", Vector3(0, 0, 0.05), Vector3(w + rail * 2.4, h + rail * 2.4, 0.1), stone, false)
	for side: float in [-1.0, 1.0]:
		box(mural, "frame_jamb", Vector3(side * (w * 0.5 + rail * 0.5), 0, 0.13), Vector3(rail, h + rail * 2.0, 0.16), stone, false)
		box(mural, "frame_rail", Vector3(0, side * (h * 0.5 + rail * 0.5), 0.13), Vector3(w + rail * 2.0, rail, 0.16), stone, false)
		box(mural, "brass_fillet_v", Vector3(side * (w * 0.5 + 0.025), 0, 0.165), Vector3(0.05, h + 0.05, 0.1), brass, false)
		box(mural, "brass_fillet_h", Vector3(0, side * (h * 0.5 + 0.025), 0.165), Vector3(w + 0.1, 0.05, 0.1), brass, false)
		for top: float in [-1.0, 1.0]:
			var boss := box(mural, "corner_boss", Vector3(side * (w * 0.5 + rail * 0.5), top * (h * 0.5 + rail * 0.5), 0.23), Vector3.ONE * rail * 0.62, brass, false)
			boss.rotation.z = PI * 0.25
	box(mural, "frame_sill", Vector3(0, -(h * 0.5 + rail * 1.15), 0.2), Vector3(w + rail * 2.8, rail * 0.55, 0.3), stone, false)
	var crown_h := clampf(w * 0.28, 0.35, 1.6)
	var crown := vaulted_rib(mural, Vector3(0, h * 0.5 + rail, 0.13), w + rail * 2.0, crown_h, stone, brass)
	crown.scale.z = 0.4
	cone(mural, "brass_finial", Vector3(0, h * 0.5 + rail + crown_h + 0.2, 0.13), 0.09, 0.0, 0.36, brass, 6)

	var art_mat := StandardMaterial3D.new()
	art_mat.roughness = 0.82
	art_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if art != null:
		art_mat.albedo_texture = art
		var relief: Texture2D = normal if normal != null else _mural_normal(art)
		if relief != null:
			art_mat.normal_enabled = true
			art_mat.normal_texture = relief
			art_mat.normal_scale = 1.0
		art_mat.emission_enabled = true
		art_mat.emission_texture = art
		art_mat.emission = Color("ffd9a8").lerp(Color("b68cff"), 0.3)
		art_mat.emission_energy_multiplier = float(inspect.get("glow", 0.16))
	else:
		art_mat.albedo_color = Color("2a2524")
	var canvas := MeshInstance3D.new()
	canvas.name = "mural_canvas"
	var quad := QuadMesh.new()
	quad.size = size
	canvas.mesh = quad
	canvas.material_override = art_mat
	canvas.position = Vector3(0, 0, 0.115)
	canvas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mural.add_child(canvas)

	var lamp_pos := Vector3(0, h * 0.5 + rail * 2.0 + 0.5, 1.4 + h * 0.3)
	var aim := Vector3(0, -h * 0.08, 0.12)
	var spread := clampf(rad_to_deg(atan(maxf(w, h) * 0.62 / lamp_pos.distance_to(aim))) + 6.0, 18.0, 60.0)
	var light := focus_light(mural, lamp_pos, aim, inspect.get("light_color", Color("ffd3a0")), float(inspect.get("light_energy", 1.2)), spread, 0.06)
	light.name = "mural_focus_light"
	mural.set_meta("mural_id", mural_id)
	mural.set_meta("art_material", art_mat)
	mural.set_meta("focus_light", light)

	if inspect.has("title") and inspect.has("writing"):
		var title := str(inspect.title)
		var hint := str(inspect.get("interact_hint", "%s — INSPECT [E]" % title.to_upper()))
		var hitbox := StaticBody3D.new()
		hitbox.name = "mural_inspect_hitbox"
		hitbox.collision_layer = LAYER_TARGET
		hitbox.collision_mask = 0
		hitbox.position = Vector3(0, 0, 0.16)
		var collider := CollisionShape3D.new()
		var plate := BoxShape3D.new()
		plate.size = Vector3(w, h, 0.05)
		collider.shape = plate
		hitbox.add_child(collider)
		hitbox.set_meta("interact_hint", hint)
		hitbox.set_meta("inscription_id", mural_id)
		hitbox.set_meta("mural_id", mural_id)
		mural.add_child(hitbox)
		mural.set_meta("hitbox", hitbox)
		_register_mural_inscription(game, parent, mural, mural_id, title, str(inspect.writing), hint, h, inspect)
	return mural

static func _register_mural_inscription(game, parent: Node3D, mural: Node3D, mural_id: String, title: String, writing: String, hint: String, h: float, inspect: Dictionary) -> void:
	if game == null:
		return
	var entries: Variant = game.get("inscriptions")
	if not entries is Array:
		return
	var level_root := game.get("level_root") as Node3D
	var anchor_parent: Node3D = level_root if is_instance_valid(level_root) else parent
	var mural_xf := _transform_in(mural, anchor_parent)
	var offset: Vector3 = inspect.get("anchor_offset", Vector3(0, -(h * 0.5 + 1.0), 1.3))
	# Legacy proximity prompts read node.position in level-root space.
	var anchor := Marker3D.new()
	anchor.name = "inspect_anchor_" + mural_id
	anchor.position = mural_xf * offset
	anchor_parent.add_child(anchor)
	for i in range(entries.size() - 1, -1, -1):
		var old: Variant = entries[i]
		if old is Dictionary and old.get("id") == mural_id:
			entries.remove_at(i)
	entries.append({
		"id": mural_id, "kind": "mural", "node": anchor, "mural": mural, "hitbox": mural.get_meta("hitbox"),
		"title": title, "writing": writing, "interact_hint": hint, "story_id": "inscription_" + mural_id,
		"position": mural_xf.origin,
	})

static func _mural_normal(art: Texture2D) -> Texture2D:
	var key: Variant = art.resource_path if not art.resource_path.is_empty() else art.get_instance_id()
	if not _mural_normals.has(key):
		_mural_normals[key] = Visuals.make_normal_map(art, 1.5)
	return _mural_normals[key]

# E5. A jagged emissive masonry seam on a wall facing local +Z. "segments" is in
# growth order with matching "growth" reveal times (0..1) for StoryDirector.
static func add_fissure(parent: Node3D, pos: Vector3, rot_y: float = 0.0, size: Vector2 = Vector2(2.4, 2.2), color: Color = Color("c57eff")) -> Node3D:
	var fissure := Node3D.new()
	fissure.name = "fissure_%d" % parent.get_child_count()
	fissure.position = pos
	fissure.rotation.y = rot_y
	parent.add_child(fissure)
	fissure.add_to_group("story_fissures")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(roundi(pos.x * 10.0), roundi(pos.y * 10.0), roundi(pos.z * 10.0)))
	var glow := StandardMaterial3D.new()
	glow.albedo_color = color.darkened(0.6)
	glow.emission_enabled = true
	glow.emission = color
	glow.emission_energy_multiplier = 2.6
	glow.roughness = 0.4
	var scar := StandardMaterial3D.new()
	scar.albedo_color = Color("141216")
	scar.roughness = 1.0
	var unit := BoxMesh.new()
	unit.size = Vector3.ONE
	var segments: Array[MeshInstance3D] = []
	var growth: Array[float] = []
	var half := size * 0.5
	var steps := 7
	var trunk: Array[Vector2] = [Vector2(rng.randf_range(-0.1, 0.1) * size.x, half.y)]
	for i in range(1, steps + 1):
		trunk.append(Vector2(rng.randf_range(-0.16, 0.16) * size.x, half.y - size.y * float(i) / float(steps)))
	for i in range(1, trunk.size()):
		var t := float(i) / float(steps)
		_fissure_segment(fissure, unit, glow, scar, trunk[i - 1], trunk[i], lerpf(0.085, 0.04, t), segments, growth, t * 0.6)
		if i >= trunk.size() - 1 or rng.randf() > 0.72:
			continue
		var dir := -1.0 if rng.randf() < 0.5 else 1.0
		var point := trunk[i]
		for j in 2 + rng.randi() % 2:
			var next := point + Vector2(dir * rng.randf_range(0.1, 0.2) * size.x, rng.randf_range(-0.12, 0.03) * size.y)
			next = next.clamp(-half, half)
			_fissure_segment(fissure, unit, glow, scar, point, next, lerpf(0.05, 0.026, float(j) / 3.0), segments, growth, t * 0.6 + 0.12 * float(j + 1))
			point = next
	var light := OmniLight3D.new()
	light.name = "fissure_glow"
	light.position = Vector3(0, 0, 0.45)
	light.light_color = color
	light.light_energy = 0.8
	light.omni_range = maxf(size.x, size.y) * 1.3
	light.light_volumetric_fog_energy = 0.3
	fissure.add_child(light)
	fissure.set_meta("segments", segments)
	fissure.set_meta("growth", growth)
	fissure.set_meta("material", glow)
	fissure.set_meta("color", color)
	fissure.set_meta("size", size)
	fissure.set_meta("light", light)
	return fissure

static func _fissure_segment(holder: Node3D, unit: Mesh, glow: Material, scar: Material, a: Vector2, b: Vector2, width: float, segments: Array[MeshInstance3D], growth: Array[float], reveal: float) -> void:
	var delta := b - a
	var length := delta.length()
	if length < 0.01:
		return
	var mid := (a + b) * 0.5
	var angle := atan2(delta.y, delta.x)
	var lip := MeshInstance3D.new()
	lip.name = "fissure_lip"
	lip.mesh = unit
	lip.material_override = scar
	lip.position = Vector3(mid.x, mid.y, 0.012)
	lip.rotation.z = angle
	lip.scale = Vector3(length + width, width * 2.2, 0.024)
	lip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(lip)
	var seam := MeshInstance3D.new()
	seam.name = "fissure_seam"
	seam.mesh = unit
	seam.material_override = glow
	seam.position = Vector3(mid.x, mid.y, 0.03)
	seam.rotation.z = angle
	seam.scale = Vector3(length + width * 0.5, width, 0.03)
	seam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(seam)
	segments.append(seam)
	growth.append(clampf(reveal, 0.0, 1.0))

# E14. Wall-mounted brass horn; the mouth faces local +Z.
static func add_speaking_tube(parent: Node3D, tube_id: String, pos: Vector3, rot_y: float, brass_mat: Material, iron_mat: Material) -> Node3D:
	var tube := Node3D.new()
	tube.name = "speaking_tube_" + tube_id
	tube.position = pos
	tube.rotation.y = rot_y
	parent.add_child(tube)
	tube.add_to_group("speaking_tubes")
	box(tube, "tube_wall_plate", Vector3(0, 0.35, 0.04), Vector3(0.62, 1.1, 0.08), iron_mat, false)
	for x: float in [-0.23, 0.23]:
		for y: float in [-0.1, 0.8]:
			var rivet := cylinder(tube, "plate_rivet", Vector3(x, y, 0.09), 0.035, 0.04, brass_mat, false, 6)
			rivet.rotation.x = PI * 0.5
	cylinder(tube, "tube_stem", Vector3(0, 1.0, 0.16), 0.075, 1.9, brass_mat, false, 10)
	for y: float in [0.4, 1.05, 1.7]:
		cylinder(tube, "stem_band", Vector3(0, y, 0.16), 0.095, 0.06, iron_mat, false, 10)
		box(tube, "stem_clamp", Vector3(0, y, 0.08), Vector3(0.06, 0.05, 0.16), iron_mat, false)
	var elbow := MeshInstance3D.new()
	elbow.name = "tube_elbow"
	var joint := SphereMesh.new()
	joint.radius = 0.1
	joint.height = 0.2
	joint.radial_segments = 10
	joint.rings = 5
	elbow.mesh = joint
	elbow.material_override = brass_mat
	elbow.position = Vector3(0, 0, 0.16)
	tube.add_child(elbow)
	var horn := cone(tube, "tube_horn", Vector3(0, 0, 0.42), 0.08, 0.34, 0.56, brass_mat, 14)
	horn.rotation.x = PI * 0.5
	var horn_mesh := (horn.get_child(0) as MeshInstance3D).mesh as CylinderMesh
	horn_mesh.cap_top = false
	var rim := MeshInstance3D.new()
	rim.name = "horn_rim"
	var lip := TorusMesh.new()
	lip.inner_radius = 0.31
	lip.outer_radius = 0.37
	lip.rings = 16
	lip.ring_segments = 6
	rim.mesh = lip
	rim.material_override = brass_mat
	rim.position = Vector3(0, 0, 0.7)
	rim.rotation.x = PI * 0.5
	tube.add_child(rim)
	var throat := StandardMaterial3D.new()
	throat.albedo_color = Color("120d09")
	throat.emission_enabled = true
	throat.emission = Color("ffb867")
	throat.emission_energy_multiplier = 0.05
	var disc := cylinder(tube, "horn_throat", Vector3(0, 0, 0.5), 0.24, 0.02, throat, false, 14)
	disc.rotation.x = PI * 0.5
	var light := OmniLight3D.new()
	light.name = "mouth_light"
	light.position = Vector3(0, 0, 0.82)
	light.light_color = Color("ffcf8a")
	light.light_energy = 0.15
	light.omni_range = 2.6
	light.light_volumetric_fog_energy = 0.1
	tube.add_child(light)
	var voice := Marker3D.new()
	voice.name = "voice_origin"
	voice.position = Vector3(0, 0, 0.75)
	tube.add_child(voice)
	tube.set_meta("tube_id", tube_id)
	tube.set_meta("mouth_light", light)
	tube.set_meta("mouth_glow_mat", throat)
	tube.set_meta("voice_origin", voice)
	tube.set_meta("rest_energy", 0.15)
	tube.set_meta("speak_energy", 2.2)
	tube.set_meta("speaking", false)
	return tube

static func set_speaking_tube_active(tube: Node3D, speaking: bool) -> void:
	if not is_instance_valid(tube) or not tube.has_meta("mouth_light"):
		return
	tube.set_meta("speaking", speaking)
	var light := tube.get_meta("mouth_light") as OmniLight3D
	var glow := tube.get_meta("mouth_glow_mat") as StandardMaterial3D
	var rest: float = tube.get_meta("rest_energy", 0.15)
	var peak: float = tube.get_meta("speak_energy", 2.2)
	var old: Variant = tube.get_meta("pulse_tween") if tube.has_meta("pulse_tween") else null
	if old is Tween and old.is_valid():
		old.kill()
	if not tube.is_inside_tree():
		light.light_energy = peak if speaking else rest
		return
	var tween := tube.create_tween()
	if speaking:
		tween.set_loops()
		tween.tween_property(light, "light_energy", peak, 0.14)
		tween.parallel().tween_property(glow, "emission_energy_multiplier", 1.6, 0.14)
		tween.tween_property(light, "light_energy", peak * 0.45, 0.22)
		tween.parallel().tween_property(glow, "emission_energy_multiplier", 0.6, 0.22)
	else:
		tween.tween_property(light, "light_energy", rest, 0.3)
		tween.parallel().tween_property(glow, "emission_energy_multiplier", 0.05, 0.3)
	tube.set_meta("pulse_tween", tween)

# E25. Distant skyline authored in Chapter I coordinates and shifted by the
# chapter frame offset: Ch II (0, 0, 77), Ch III (0, 60, 143.6). Inside the Keep
# (Ch II) the Keep mass is omitted; underground (Ch III) only the stacks and
# Upper City glow remain. `include` overrides keep/bell/stacks/city/drowned.
static func add_far_landmarks(game, parent: Node3D, frame_offset: Vector3 = Vector3.ZERO, include: Dictionary = {}) -> Node3D:
	var root := Node3D.new()
	root.name = "far_landmarks"
	root.position = frame_offset
	parent.add_child(root)
	var underground := frame_offset.y > 30.0
	var inside_keep := not underground and frame_offset.z > 38.0
	var want := {"keep": not underground and not inside_keep, "bell": not underground, "stacks": true, "city": true, "drowned": not underground}
	want.merge(include, true)
	var iron := _game_mat(game, "iron", Color("4a535b"))
	var brass := _game_mat(game, "brass", Color("b98a4e"))
	root.set_meta("frame_offset", frame_offset)
	if want.keep:
		_landmark_keep(root, brass)
	if want.bell:
		_landmark_bell(root, iron, brass)
	if want.stacks:
		_landmark_stacks(root, iron, -62.0 if underground else -30.0)
	if want.city:
		_landmark_city(root)
	if want.drowned:
		_landmark_drowned_ward(root, _game_mat(game, "timber", Color("5a4636")))
	_no_shadows(root)
	return root

static func _landmark_keep(root: Node3D, brass: Material) -> void:
	var keep := Node3D.new()
	keep.name = "bell_keep"
	root.add_child(keep)
	root.set_meta("keep", keep)
	var mass := _flat_mat(Color("1b1c23"), 0.95)
	var slate := _flat_mat(Color("15161c"), 0.8)
	box(keep, "keep_nave", Vector3(0, -1.5, -76.5), Vector3(32, 25, 59), mass, false)
	_gable_prism(keep, "keep_nave_roof", Vector3(0, 11, -76.5), 16.0, 5.0, 59.6, slate)
	box(keep, "keep_belfry_block", Vector3(0, -2.25, -117), Vector3(32, 23.5, 22), mass, false)
	for z: float in [-106.4, -127.6]:
		box(keep, "belfry_parapet", Vector3(0, 10.25, z), Vector3(32, 1.5, 0.8), mass, false)
	for x: float in [-15.6, 15.6]:
		box(keep, "belfry_parapet", Vector3(x, 10.25, -117), Vector3(0.8, 1.5, 22), mass, false)
		for z: float in [-106.4, -127.6]:
			cylinder(keep, "pinnacle_pier", Vector3(x, 12.5, z), 0.9, 3.0, mass, false, 8)
			cone(keep, "pinnacle_spire", Vector3(x, 17.5, z), 0.95, 0.04, 7.0, slate, 8)
	for side: float in [-1.0, 1.0]:
		for z: float in [-55.0, -68.0, -84.0, -97.0]:
			var buttress := gothic_buttress(keep, Vector3(side * 16.0, -11.0, z), 22.0, 6.0, mass, slate)
			buttress.rotation.y = side * PI * 0.5
	var violet := _glow_flat(Color("a678ff"), 2.8)
	var cyan := _glow_flat(Color("6fe6f2"), 2.4)
	var windows := [[-1.0, -62.0, violet], [-1.0, -90.0, cyan], [1.0, -62.0, cyan], [1.0, -90.0, violet]]
	for spec: Array in windows:
		var lancet := box(keep, "clerestory_window", Vector3(spec[0] * 16.06, 7.2, spec[1]), Vector3(0.1, 4.2, 1.5), spec[2], false)
		var arch := box(lancet, "lancet_point", Vector3(0, 2.1, 0), Vector3(0.1, 1.06, 1.06), spec[2], false)
		arch.rotation.x = PI * 0.25
	var oculus := cylinder(keep, "facade_oculus", Vector3(0, 13.2, -46.95), 1.6, 0.12, brass, false, 16)
	oculus.rotation.x = PI * 0.5
	var glass := cylinder(oculus, "oculus_glass", Vector3(0, 0.04, 0), 1.3, 0.12, slate, false, 16)
	glass.name = "oculus_glass"
	root.set_meta("keep_window_materials", [violet, cyan])

static func _landmark_bell(root: Node3D, iron: Material, brass: Material) -> void:
	for z: float in [-118.6, -121.4]:
		vaulted_rib(root, Vector3(0, 11, z), 28.0, 21.0, iron, brass)
	box(root, "yoke_headstock", Vector3(0, 31.4, -120), Vector3(1.4, 1.1, 3.8), iron, false)
	hanging_chain(root, Vector3(0, 30.9, -120), Vector3(0, 24.4, -120), 0.24, iron)
	var bell := Node3D.new()
	bell.name = "great_bell"
	bell.position = Vector3(0, 22, -120)
	root.add_child(bell)
	var bronze := StandardMaterial3D.new()
	bronze.albedo_color = Color("6f5430")
	bronze.metallic = 0.85
	bronze.roughness = 0.4
	cone(bell, "bell_lip", Vector3(0, -1.9, 0), 2.8, 2.55, 0.6, bronze, 28)
	cone(bell, "bell_waist", Vector3(0, 0.1, 0), 2.55, 1.45, 3.4, bronze, 28)
	cone(bell, "bell_shoulder", Vector3(0, 2.0, 0), 1.45, 0.9, 0.4, bronze, 24)
	var crown := MeshInstance3D.new()
	crown.name = "bell_canons"
	var loop := TorusMesh.new()
	loop.inner_radius = 0.32
	loop.outer_radius = 0.52
	crown.mesh = loop
	crown.material_override = iron
	crown.position = Vector3(0, 2.45, 0)
	crown.rotation.x = PI * 0.5
	bell.add_child(crown)
	cylinder(bell, "clapper_rod", Vector3(0, -0.6, 0), 0.12, 2.6, iron, false, 8)
	cylinder(bell, "clapper_ball", Vector3(0, -1.95, 0), 0.38, 0.5, iron, false, 10)
	var crack_mat := StandardMaterial3D.new()
	crack_mat.albedo_color = Color("2b1640")
	crack_mat.emission_enabled = true
	crack_mat.emission = Color("b47cff")
	crack_mat.emission_energy_multiplier = 1.6
	crack_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var strip := MeshInstance3D.new()
	strip.name = "bell_crack_strip"
	strip.mesh = _bell_crack_mesh(3011)
	strip.material_override = crack_mat
	bell.add_child(strip)
	var light := OmniLight3D.new()
	light.name = "bell_crack_light"
	light.position = Vector3(0, 0, 3.6)
	light.light_color = Color("b47cff")
	light.light_energy = 1.2
	light.omni_range = 9.0
	light.light_volumetric_fog_energy = 0.5
	bell.add_child(light)
	root.set_meta("bell", bell)
	root.set_meta("bell_crack_strip", strip)
	root.set_meta("bell_crack_material", crack_mat)
	root.set_meta("bell_crack_rest_energy", 1.6)
	root.set_meta("bell_light", light)

# Profile of the bell's outer surface; local y is measured from the bell centre.
static func _bell_radius(y: float) -> float:
	if y < -1.6:
		return lerpf(2.8, 2.55, (y + 2.2) / 0.6)
	return lerpf(2.55, 1.45, clampf((y + 1.6) / 3.4, 0.0, 1.0))

static func _bell_crack_mesh(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk: Array[Vector3] = []
	var theta := 0.0
	for i in 10:
		var y := lerpf(1.75, -2.15, float(i) / 9.0)
		theta = clampf(theta + rng.randf_range(-0.14, 0.14), -0.32, 0.32)
		trunk.append(_bell_point(y, theta))
	for i in range(1, trunk.size()):
		_crack_ribbon(surface, trunk[i - 1], trunk[i], lerpf(0.2, 0.12, float(i) / 9.0))
		if i in [3, 6]:
			var start := trunk[i]
			var side := -1.0 if i == 3 else 1.0
			var y := start.y
			var angle := atan2(start.x, start.z)
			for j in 3:
				y -= rng.randf_range(0.18, 0.34)
				angle += side * rng.randf_range(0.08, 0.15)
				var next := _bell_point(y, angle)
				_crack_ribbon(surface, start, next, 0.09)
				start = next
	return surface.commit()

static func _bell_point(y: float, theta: float) -> Vector3:
	var r := _bell_radius(y) + 0.035
	return Vector3(sin(theta) * r, y, cos(theta) * r)

static func _crack_ribbon(surface: SurfaceTool, a: Vector3, b: Vector3, width: float) -> void:
	var outward := Vector3(a.x, 0, a.z).normalized()
	var side := (b - a).cross(outward).normalized() * width * 0.5
	surface.set_normal(outward)
	for vertex: Vector3 in [a - side, a + side, b + side, a - side, b + side, b - side]:
		surface.add_vertex(vertex)

# Flash the landmark bell crack for a toll. The material returns to its rest glow.
static func pulse_landmark_bell(landmarks: Node3D, color: Color = Color("b47cff"), peak: float = 7.0, duration: float = 1.6) -> void:
	if not is_instance_valid(landmarks) or not landmarks.has_meta("bell_crack_material"):
		return
	var mat := landmarks.get_meta("bell_crack_material") as StandardMaterial3D
	var light := landmarks.get_meta("bell_light") as OmniLight3D
	var rest: float = landmarks.get_meta("bell_crack_rest_energy", 1.6)
	mat.emission = color
	light.light_color = color
	if not landmarks.is_inside_tree():
		return
	var tween := landmarks.create_tween()
	tween.tween_property(mat, "emission_energy_multiplier", peak, 0.06)
	tween.parallel().tween_property(light, "light_energy", peak * 0.6, 0.06)
	tween.tween_property(mat, "emission_energy_multiplier", rest, duration)
	tween.parallel().tween_property(light, "light_energy", 1.2, duration)

static func _landmark_stacks(root: Node3D, iron: Material, bottom: float) -> void:
	var brick := _flat_mat(Color("2a2220"), 0.92)
	var ember := _glow_flat(Color("ff7a2a"), 1.7)
	var lights: Array[OmniLight3D] = []
	var top := 18.0
	var height := top - bottom
	for x: float in [-34.0, 34.0]:
		var stack := Node3D.new()
		stack.name = "kiln_stack"
		stack.position = Vector3(x, 0, -150)
		root.add_child(stack)
		cone(stack, "stack_shaft", Vector3(0, bottom + height * 0.5, 0), 3.2, 2.3, height, brick, 14)
		var y := top - 4.0
		while y > bottom + 2.0:
			var radius := lerpf(3.2, 2.3, (y - bottom) / height) + 0.12
			cylinder(stack, "stack_band", Vector3(0, y, 0), radius, 0.45, iron, false, 14)
			y -= 8.0
		cone(stack, "stack_crown", Vector3(0, top + 0.6, 0), 2.4, 2.9, 1.2, brick, 14)
		cylinder(stack, "stack_throat_glow", Vector3(0, top + 1.0, 0), 2.25, 0.3, ember, false, 14)
		var glow := OmniLight3D.new()
		glow.name = "stack_glow"
		glow.position = Vector3(0, top + 3.0, 0)
		glow.light_color = Color("ff8a3a")
		glow.light_energy = 3.0
		glow.omni_range = 18.0
		glow.light_volumetric_fog_energy = 0.6
		stack.add_child(glow)
		lights.append(glow)
		_landmark_plume(stack, Vector3(0, top + 1.6, 0), 40, 7.0, Vector2(2.4, 4.0), 4.5, Color(0.86, 0.46, 0.22, 0.42), Color(0.2, 0.19, 0.2, 0.38), false)
		_landmark_plume(stack, Vector3(0, top + 1.2, 0), 28, 3.2, Vector2(4.0, 7.0), 0.35, Color(1.0, 0.62, 0.25, 1.0), Color(1.0, 0.3, 0.08, 0.6), true)
	root.set_meta("stack_lights", lights)
	root.set_meta("stack_glow_material", ember)

static func _landmark_plume(parent: Node3D, pos: Vector3, amount: int, lifetime: float, speed: Vector2, quad_size: float, start: Color, end: Color, additive: bool) -> GPUParticles3D:
	var plume := GPUParticles3D.new()
	plume.name = "stack_embers" if additive else "stack_smoke"
	plume.position = pos
	plume.amount = amount
	plume.lifetime = lifetime
	plume.preprocess = lifetime
	plume.fixed_fps = 20
	plume.visibility_aabb = AABB(Vector3(-30, -5, -30), Vector3(60, 70, 60))
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.15, 0.7, 1.0])
	fade.colors = PackedColorArray([Color(start, 0.0), start, end, Color(end, 0.0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	var motion := ParticleProcessMaterial.new()
	motion.direction = Vector3.UP
	motion.spread = 25.0 if additive else 12.0
	motion.initial_velocity_min = speed.x
	motion.initial_velocity_max = speed.y
	motion.gravity = Vector3(0.6, 0.4 if not additive else -0.8, 0)
	motion.scale_min = 0.6
	motion.scale_max = 1.0 if additive else 1.8
	motion.color_ramp = ramp
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	motion.emission_sphere_radius = 1.6
	plume.process_material = motion
	var falloff := Gradient.new()
	falloff.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	falloff.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.6), Color(1, 1, 1, 0)])
	var puff := GradientTexture2D.new()
	puff.gradient = falloff
	puff.width = 32
	puff.height = 32
	puff.fill = GradientTexture2D.FILL_RADIAL
	puff.fill_from = Vector2(0.5, 0.5)
	puff.fill_to = Vector2(1.0, 0.5)
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	look.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	look.vertex_color_use_as_albedo = true
	look.albedo_texture = puff
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * quad_size
	quad.material = look
	plume.draw_pass_1 = quad
	parent.add_child(plume)
	return plume

static func _landmark_city(root: Node3D) -> void:
	var city := Node3D.new()
	city.name = "upper_city"
	root.add_child(city)
	var rock := _flat_mat(Color("1d1c20"), 1.0)
	var walls := _flat_mat(Color("24232b"), 0.95)
	var roofs := _flat_mat(Color("17171d"), 0.85)
	box(city, "upper_city_cliff", Vector3(65, -4, -50), Vector3(50, 20, 64), rock, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3011
	var windows: Array[Transform3D] = []
	var west := Basis(Vector3.UP, -PI * 0.5)
	for i in 18:
		var size := Vector3(rng.randf_range(3.0, 7.0), rng.randf_range(3.0, 10.0), rng.randf_range(3.0, 7.0))
		var center := Vector3(rng.randf_range(43.0, 87.0), 6.0 + size.y * 0.5, rng.randf_range(-24.0, -76.0))
		box(city, "city_house", center, size, walls, false)
		var roof_h := rng.randf_range(1.6, 3.4)
		var roof := cone(city, "city_roof", center + Vector3(0, size.y * 0.5 + roof_h * 0.5, 0), maxf(size.x, size.z) * 0.72, 0.05, roof_h, roofs, 4)
		roof.rotation.y = PI * 0.25
		roof.scale = Vector3(size.x / maxf(size.x, size.z), 1, size.z / maxf(size.x, size.z))
		if i % 6 == 0:
			cone(city, "city_spire", center + Vector3(0, size.y * 0.5 + roof_h + 3.5, 0), 0.7, 0.04, 7.0, roofs, 6)
		var top_y := 6.0 + size.y - 0.9
		for j in 2 + rng.randi() % 4:
			var wy := rng.randf_range(6.8, maxf(6.9, top_y))
			if j % 2 == 0:
				windows.append(Transform3D(west, Vector3(center.x - size.x * 0.5 - 0.03, wy, center.z + rng.randf_range(-0.4, 0.4) * size.z)))
			else:
				windows.append(Transform3D(Basis.IDENTITY, Vector3(center.x + rng.randf_range(-0.4, 0.4) * size.x, wy, center.z + size.z * 0.5 + 0.03)))
	var lit := StandardMaterial3D.new()
	lit.albedo_color = Color("ffc37a")
	lit.emission_enabled = true
	lit.emission = Color("ffb45e")
	lit.emission_energy_multiplier = 2.6
	var pane := QuadMesh.new()
	pane.size = Vector2(0.6, 0.95)
	var lights := MultiMesh.new()
	lights.transform_format = MultiMesh.TRANSFORM_3D
	lights.mesh = pane
	lights.instance_count = windows.size()
	for i in windows.size():
		lights.set_instance_transform(i, windows[i])
	var instances := MultiMeshInstance3D.new()
	instances.name = "upper_city_windows"
	instances.multimesh = lights
	instances.material_override = lit
	city.add_child(instances)
	var glow := OmniLight3D.new()
	glow.name = "upper_city_glow"
	glow.position = Vector3(66, 14, -50)
	glow.light_color = Color("ffb46a")
	glow.light_energy = 0.7
	glow.omni_range = 24.0
	city.add_child(glow)
	root.set_meta("city_windows", instances)
	root.set_meta("city_window_material", lit)
	root.set_meta("city_light", glow)

static func _landmark_drowned_ward(root: Node3D, timber: Material) -> void:
	var ward := Node3D.new()
	ward.name = "drowned_lower_ward"
	root.add_child(ward)
	var water := StandardMaterial3D.new()
	water.albedo_color = Color("0b1a20")
	water.metallic = 0.3
	water.roughness = 0.06
	var surface := MeshInstance3D.new()
	surface.name = "drowned_water"
	var plane := PlaneMesh.new()
	plane.size = Vector2(240, 260)
	surface.mesh = plane
	surface.material_override = water
	surface.position = Vector3(0, -14, -30)
	ward.add_child(surface)
	var roofs := _flat_mat(Color("1a1b20"), 0.85)
	var walls := _flat_mat(Color("2a2a2f"), 0.95)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1406
	for i in 8:
		var side := -1.0 if i % 2 == 0 else 1.0
		var pos := Vector3(side * rng.randf_range(38.0, 70.0), -14.6, rng.randf_range(-58.0, 30.0))
		var ridge := _gable_prism(ward, "sunken_roof_ridge", pos, rng.randf_range(2.0, 3.6), rng.randf_range(1.2, 2.2), rng.randf_range(5.0, 10.0), roofs)
		ridge.rotation.y = rng.randf_range(-0.4, 0.4) + (PI * 0.5 if i % 3 == 0 else 0.0)
	var cote := Node3D.new()
	cote.name = "sunken_bell_cote"
	cote.position = Vector3(-46, -14, -34)
	cote.rotation = Vector3(0.05, 0.4, 0.12)
	ward.add_child(cote)
	box(cote, "cote_tower", Vector3(0, 0.8, 0), Vector3(3, 5.6, 3), walls, false)
	box(cote, "cote_opening", Vector3(0, 2.6, 1.52), Vector3(1.2, 1.8, 0.05), _flat_mat(Color("08080a"), 1.0), false)
	var cap := cone(cote, "cote_roof", Vector3(0, 5.1, 0), 2.3, 0.05, 3.0, roofs, 4)
	cap.rotation.y = PI * 0.25
	var raft := Node3D.new()
	raft.name = "capsized_raft"
	raft.position = Vector3(41, -13.8, -12)
	raft.rotation = Vector3(0.25, 0.6, 0.18)
	ward.add_child(raft)
	for i in 4:
		box(raft, "raft_plank", Vector3(0, 0, (float(i) - 1.5) * 0.62), Vector3(4.5, 0.24, 0.56), timber, false)
	box(raft, "raft_spar", Vector3(1.6, 0.18, 0), Vector3(0.3, 0.2, 2.8), timber, false)

static func _gable_prism(parent: Node3D, node_name: String, pos: Vector3, half_width: float, rise: float, length: float, mat: Material) -> Node3D:
	var holder := Node3D.new()
	holder.name = node_name
	holder.position = pos
	holder.scale = Vector3(half_width, rise, 1.0)
	parent.add_child(holder)
	var prism := box(holder, "gable_prism", Vector3.ZERO, Vector3(sqrt(2.0), sqrt(2.0), length), mat, false)
	prism.rotation.z = PI * 0.25
	return holder

# Fracture: hide the intact assembly, bring the settled rubble online and throw
# seeded cosmetic masonry (debris layer, world-only mask, 5 s lifetime).
static func trigger_rockfall(parent: Node3D, fracture: Node3D, settled: Node3D, seed_value: int, count: int = 12) -> Array[RigidBody3D]:
	var chunks: Array[RigidBody3D] = []
	var bounds := AABB(Vector3(-1, 0, -1), Vector3(2, 2, 2))
	var mat: Material = null
	if is_instance_valid(fracture):
		bounds = _assembly_bounds(fracture, parent)
		mat = _first_material(fracture)
		fracture.set_meta("fractured", true)
		set_assembly_active(fracture, false)
	if is_instance_valid(settled):
		set_assembly_active(settled, true)
	if mat == null:
		mat = _flat_mat(Color("6d6a66"), 0.95)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var center := bounds.get_center()
	var scale_factor := clampf(bounds.size.length() / 4.0, 0.6, 1.6)
	var grit := PhysicsMaterial.new()
	grit.friction = 0.8
	grit.bounce = 0.12
	for i in clampi(count, 0, STORY_BODY_LIMIT):
		var dims := Vector3(rng.randf_range(0.25, 0.7), rng.randf_range(0.2, 0.55), rng.randf_range(0.25, 0.65)) * scale_factor
		var chunk := RigidBody3D.new()
		chunk.name = "rockfall_chunk_%d" % i
		chunk.collision_layer = LAYER_DEBRIS
		chunk.collision_mask = LAYER_WORLD
		chunk.mass = clampf(dims.x * dims.y * dims.z * 9.0, 0.3, 4.0)
		chunk.physics_material_override = grit
		chunk.position = bounds.position + bounds.size * Vector3(rng.randf(), rng.randf_range(0.35, 1.0), rng.randf())
		chunk.rotation = Vector3(rng.randf_range(-PI, PI), rng.randf_range(-PI, PI), rng.randf_range(-PI, PI))
		var visual := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = dims
		visual.mesh = mesh
		visual.material_override = mat
		chunk.add_child(visual)
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = dims
		collider.shape = shape
		chunk.add_child(collider)
		var outward := chunk.position - center
		outward.y = 0.0
		outward = outward.normalized() if outward.length() > 0.05 else Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
		var impulse := (outward * rng.randf_range(0.6, 2.2) + Vector3(0, rng.randf_range(-0.4, 1.2), 0)).limit_length(3.0) * chunk.mass
		var torque := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).limit_length(1.2) * chunk.mass
		_track_story_body(chunk)
		parent.add_child(chunk)
		if chunk.is_inside_tree():
			chunk.apply_central_impulse(impulse)
			chunk.apply_torque_impulse(torque)
		else:
			chunk.linear_velocity = impulse / chunk.mass
			chunk.angular_velocity = torque / chunk.mass
		_add_lifetime(chunk, DEBRIS_LIFETIME, visual)
		chunks.append(chunk)
	return chunks

# Show or hide an authored assembly and move its physics bodies on or off their
# layers (deferred, so this is safe inside physics callbacks).
static func set_assembly_active(node: Node3D, active: bool, deferred: bool = true) -> void:
	if not is_instance_valid(node):
		return
	node.visible = active
	_set_assembly_collision(node, active, deferred)

static func _set_assembly_collision(node: Node, enabled: bool, deferred: bool) -> void:
	if node is PhysicsBody3D:
		var body := node as PhysicsBody3D
		if not body.has_meta("active_layer"):
			body.set_meta("active_layer", body.collision_layer if body.collision_layer != 0 else LAYER_WORLD)
		var layer: int = body.get_meta("active_layer") if enabled else 0
		if deferred:
			body.set_deferred("collision_layer", layer)
		else:
			body.collision_layer = layer
	elif node is CollisionShape3D and node.get_parent() is PhysicsBody3D:
		if deferred:
			node.set_deferred("disabled", not enabled)
		else:
			(node as CollisionShape3D).disabled = not enabled
	if node is Area3D:
		return
	for child: Node in node.get_children():
		_set_assembly_collision(child, enabled, deferred)

# Release the suspended chandelier as one rigid body. The first world contact
# (or the deadline) emits "chandelier_impact" and, unless the director sets
# meta "auto_settle" false, swaps in the authored "wreck".
static func drop_chandelier(parent: Node3D, suspended: Node3D, wreck: Node3D, seed_value: int) -> RigidBody3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var start := Transform3D.IDENTITY
	var radius := 1.8
	if is_instance_valid(suspended):
		start = _transform_in(suspended, parent)
		radius = float(suspended.get_meta("ring_radius", 1.8))
		set_assembly_active(suspended, false)
	if is_instance_valid(wreck):
		set_assembly_active(wreck, false)
	var body := RigidBody3D.new()
	body.name = "falling_chandelier"
	body.transform = Transform3D(start.basis.orthonormalized(), start.origin)
	body.mass = 22.0
	body.continuous_cd = true
	body.contact_monitor = true
	body.max_contacts_reported = 4
	body.collision_layer = LAYER_DEBRIS
	body.collision_mask = LAYER_WORLD
	body.angular_damp = 0.6
	_build_chandelier_visual(body, radius)
	var collider := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius + 0.1
	shape.height = 0.6
	collider.shape = shape
	body.add_child(collider)
	if is_instance_valid(wreck):
		body.set_meta("wreck", wreck)
	if is_instance_valid(suspended):
		body.set_meta("suspended", suspended)
	body.set_meta("seed", seed_value)
	body.set_meta("auto_settle", true)
	body.set_meta("impacted", false)
	body.set_meta("settled", false)
	body.add_user_signal("chandelier_impact", [{"name": "point", "type": TYPE_VECTOR3}])
	body.angular_velocity = Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.4, 0.4), rng.randf_range(-0.6, 0.6))
	body.linear_velocity = Vector3(rng.randf_range(-0.3, 0.3), -0.5, rng.randf_range(-0.3, 0.3))
	parent.add_child(body)
	body.body_entered.connect(func(other: Node) -> void:
		if other is CollisionObject3D and (other.collision_layer & LAYER_WORLD) == 0:
			return
		_chandelier_impact(body)
	)
	var deadline := Timer.new()
	deadline.name = "impact_deadline"
	deadline.one_shot = true
	deadline.wait_time = CHANDELIER_DEADLINE
	deadline.autostart = true
	deadline.process_callback = Timer.TIMER_PROCESS_PHYSICS
	deadline.timeout.connect(func() -> void: _chandelier_impact(body))
	body.add_child(deadline)
	return body

static func _chandelier_impact(body: RigidBody3D) -> void:
	if not is_instance_valid(body) or body.get_meta("impacted", false):
		return
	body.set_meta("impacted", true)
	var point := body.global_position if body.is_inside_tree() else body.position
	body.set_meta("impact_point", point)
	body.emit_signal("chandelier_impact", point)
	if body.get_meta("auto_settle", true):
		settle_chandelier.call_deferred(body)

# Replace the falling prop with its settled wreck. Returns the wreck (or null).
static func settle_chandelier(body: RigidBody3D) -> Node3D:
	if not is_instance_valid(body) or body.get_meta("settled", false):
		return null
	body.set_meta("settled", true)
	var wreck: Node3D = body.get_meta("wreck") if body.has_meta("wreck") else null
	if is_instance_valid(wreck):
		set_assembly_active(wreck, true)
	body.queue_free()
	return wreck

static func _build_chandelier_visual(body: Node3D, radius: float) -> void:
	var iron := _flat_mat(Color("2f3237"), 0.55)
	iron.metallic = 0.75
	var brass := _flat_mat(Color("a57b45"), 0.42)
	brass.metallic = 0.85
	var wax := _flat_mat(Color("d8ccb4"), 0.9)
	var flame := _glow_flat(Color("ffb35c"), 3.2)
	for spec: Array in [[radius, 0.12, iron], [radius * 0.55, 0.07, brass]]:
		var ring := MeshInstance3D.new()
		ring.name = "chandelier_ring"
		var torus := TorusMesh.new()
		torus.outer_radius = spec[0]
		torus.inner_radius = spec[0] - spec[1] * 2.0
		torus.rings = 24
		torus.ring_segments = 6
		ring.mesh = torus
		ring.material_override = spec[2]
		body.add_child(ring)
	cylinder(body, "chandelier_hub", Vector3(0, 0.05, 0), 0.18, 0.5, iron, false, 8)
	for i in 4:
		var angle := TAU * float(i) / 4.0
		var spoke := box(body, "chandelier_spoke", Vector3(cos(angle), 0, sin(angle)) * radius * 0.5, Vector3(radius, 0.06, 0.06), iron, false)
		spoke.rotation.y = -angle
		hanging_chain(body, Vector3(0, 1.4, 0), Vector3(cos(angle + PI * 0.25), 0, sin(angle + PI * 0.25)) * radius, 0.06, iron)
	for i in 12:
		var angle := TAU * float(i) / 12.0
		var spot := Vector3(cos(angle), 0, sin(angle)) * radius
		cylinder(body, "candle_cup", spot + Vector3(0, 0.08, 0), 0.07, 0.08, brass, false, 8)
		cylinder(body, "candle", spot + Vector3(0, 0.22, 0), 0.04, 0.22, wax, false, 6)
		cone(body, "candle_flame", spot + Vector3(0, 0.4, 0), 0.035, 0.0, 0.12, flame, 6)
	var light := OmniLight3D.new()
	light.name = "chandelier_light"
	light.position = Vector3(0, 0.4, 0)
	light.light_color = Color("ffb35c")
	light.light_energy = 1.6
	light.omni_range = 7.0
	body.add_child(light)
	body.set_meta("light", light)

# Gothic foundry rack of Name-Vessels, front facing local +Z. One MultiMesh
# draws every vessel; "vessel_mat" drives all their glow bands in unison.
static func add_name_vessel_rack(parent: Node3D, pos: Vector3, rot_y: float, rows: int, cols: int, iron_mat: Material, soul_mat: Material, label_names: PackedStringArray = PackedStringArray()) -> Node3D:
	rows = maxi(1, rows)
	cols = maxi(1, cols)
	var rack := Node3D.new()
	rack.name = "name_vessel_rack"
	rack.position = pos
	rack.rotation.y = rot_y
	parent.add_child(rack)
	var iron: Material = iron_mat if iron_mat != null else _flat_mat(Color("3a3f45"), 0.6)
	var pitch_x := 0.46
	var pitch_y := 0.6
	var width := float(cols) * pitch_x + 0.5
	var height := float(rows) * pitch_y + 0.5
	box(rack, "rack_back", Vector3(0, height * 0.5, -0.24), Vector3(width, height, 0.08), iron, false)
	var bays := maxi(1, ceili(float(cols) / 6.0))
	for b in bays + 1:
		var x := -width * 0.5 + 0.07 + (width - 0.14) * float(b) / float(bays)
		box(rack, "rack_upright", Vector3(x, height * 0.5 + 0.15, 0), Vector3(0.14, height + 0.3, 0.52), iron, false)
		cone(rack, "upright_finial", Vector3(x, height + 0.55, 0), 0.09, 0.0, 0.5, iron, 4)
	for b in bays:
		var bay_w := (width - 0.14) / float(bays)
		vaulted_rib(rack, Vector3(-width * 0.5 + 0.07 + bay_w * (float(b) + 0.5), height + 0.3, 0), bay_w, minf(0.9, bay_w * 0.3), iron, iron)
	for r in rows + 1:
		box(rack, "rack_shelf", Vector3(0, 0.22 + float(r) * pitch_y, 0), Vector3(width, 0.06, 0.5), iron, false)
	var blocker := StaticBody3D.new()
	blocker.name = "rack_collider"
	blocker.collision_layer = LAYER_WORLD
	blocker.collision_mask = 0
	blocker.position = Vector3(0, height * 0.5, -0.02)
	var collider := CollisionShape3D.new()
	var bounds := BoxShape3D.new()
	bounds.size = Vector3(width, height, 0.56)
	collider.shape = bounds
	blocker.add_child(collider)
	rack.add_child(blocker)

	var vessel_mat: Material = _glow_flat(Color("d9c8ff"), 1.4)
	if soul_mat != null:
		vessel_mat = soul_mat.duplicate() as Material
	var soul_std := vessel_mat as StandardMaterial3D
	var vessels := MultiMesh.new()
	vessels.transform_format = MultiMesh.TRANSFORM_3D
	vessels.mesh = _name_vessel_mesh(iron, vessel_mat)
	vessels.instance_count = rows * cols
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(roundi(pos.x * 10.0), roundi(pos.y * 10.0), roundi(pos.z * 10.0)))
	for r in rows:
		for c in cols:
			var spot := _vessel_spot(r, c, width, pitch_x, pitch_y)
			vessels.set_instance_transform(r * cols + c, Transform3D(Basis(Vector3.UP, rng.randf_range(-PI, PI)), spot))
	var instances := MultiMeshInstance3D.new()
	instances.name = "name_vessels"
	instances.multimesh = vessels
	rack.add_child(instances)

	var labels := {}
	var featured_row := mini(rows - 1, 1)
	for i in label_names.size():
		var c := clampi(int((float(i % cols) + 0.5) * float(cols) / float(mini(label_names.size(), cols))), 0, cols - 1)
		var r := (featured_row + i / cols) % rows
		var label := Label3D.new()
		label.name = "vessel_name_" + label_names[i].to_lower()
		label.text = label_names[i]
		label.font_size = 32
		label.pixel_size = 0.0032
		label.outline_size = 6
		label.modulate = Color("efe3ff")
		label.outline_modulate = Color("1a1022")
		label.shaded = false
		label.position = _vessel_spot(r, c, width, pitch_x, pitch_y) + Vector3(0, -0.05, 0.19)
		rack.add_child(label)
		labels[label_names[i]] = label
	var glow := OmniLight3D.new()
	glow.name = "rack_glow"
	glow.position = Vector3(0, height * 0.5, 1.0)
	glow.light_color = soul_std.emission if soul_std != null and soul_std.emission_enabled else Color("c9b6ff")
	glow.light_energy = 0.7
	glow.omni_range = maxf(width, height) * 0.8 + 2.0
	rack.add_child(glow)
	rack.set_meta("vessel_mat", vessel_mat)
	rack.set_meta("vessel_rest_energy", soul_std.emission_energy_multiplier if soul_std != null else 1.0)
	rack.set_meta("multimesh", vessels)
	rack.set_meta("vessels", instances)
	rack.set_meta("vessel_count", rows * cols)
	rack.set_meta("labels", labels)
	rack.set_meta("rack_light", glow)
	rack.set_meta("rows", rows)
	rack.set_meta("cols", cols)
	return rack

static func _vessel_spot(r: int, c: int, width: float, pitch_x: float, pitch_y: float) -> Vector3:
	return Vector3(-width * 0.5 + 0.25 + (float(c) + 0.5) * pitch_x, 0.25 + float(r) * pitch_y + 0.21, 0.02)

static func _name_vessel_mesh(iron: Material, glow: Material) -> ArrayMesh:
	var body := CylinderMesh.new()
	body.top_radius = 0.12
	body.bottom_radius = 0.15
	body.height = 0.42
	body.radial_segments = 10
	body.rings = 1
	var band := CylinderMesh.new()
	band.top_radius = 0.145
	band.bottom_radius = 0.152
	band.height = 0.07
	band.radial_segments = 10
	band.rings = 1
	var lid := CylinderMesh.new()
	lid.top_radius = 0.06
	lid.bottom_radius = 0.11
	lid.height = 0.06
	lid.radial_segments = 8
	lid.rings = 1
	var mesh := ArrayMesh.new()
	_add_offset_surface(mesh, body, Vector3.ZERO, iron)
	_add_offset_surface(mesh, band, Vector3(0, -0.05, 0), glow)
	_add_offset_surface(mesh, lid, Vector3(0, 0.24, 0), iron)
	return mesh

static func _add_offset_surface(mesh: ArrayMesh, primitive: PrimitiveMesh, offset: Vector3, mat: Material) -> void:
	var arrays := primitive.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		verts[i] += offset
	arrays[Mesh.ARRAY_VERTEX] = verts
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(mesh.get_surface_count() - 1, mat)

# --- shared internals -------------------------------------------------------

static func _game_mat(game, key: String, fallback: Color) -> Material:
	if game != null:
		var mats: Variant = game.get("mats")
		if mats is Dictionary and mats.get(key) is Material:
			return mats[key]
	return _flat_mat(fallback, 0.85)

static func _flat_mat(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat

static func _glow_flat(color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.darkened(0.45)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	mat.roughness = 0.6
	return mat

static func _no_shadows(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child: Node in node.get_children():
		_no_shadows(child)

# Transform of node expressed in ancestor's space, with or without a scene tree.
static func _transform_in(node: Node3D, ancestor: Node) -> Transform3D:
	if node.is_inside_tree() and ancestor is Node3D and ancestor.is_inside_tree():
		return (ancestor as Node3D).global_transform.affine_inverse() * node.global_transform
	var xf := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != ancestor:
		if current is Node3D:
			xf = (current as Node3D).transform * xf
		current = current.get_parent()
	return xf

static func _assembly_bounds(node: Node3D, space: Node3D) -> AABB:
	var result := AABB()
	var found := false
	var pending: Array[Node] = [node]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		pending.append_array(current.get_children())
		if current is MeshInstance3D and (current as MeshInstance3D).mesh != null:
			var visual := current as MeshInstance3D
			var piece := _transform_in(visual, space) * visual.get_aabb()
			result = result.merge(piece) if found else piece
			found = true
	if not found:
		result = AABB(_transform_in(node, space).origin - Vector3.ONE, Vector3.ONE * 2.0)
	return result

static func _first_material(node: Node) -> Material:
	if node is MeshInstance3D:
		var visual := node as MeshInstance3D
		if visual.material_override != null:
			return visual.material_override
		if visual.mesh != null and visual.mesh.get_surface_count() > 0 and visual.mesh.surface_get_material(0) != null:
			return visual.mesh.surface_get_material(0)
	for child: Node in node.get_children():
		var found := _first_material(child)
		if found != null:
			return found
	return null

static func _track_story_body(body: RigidBody3D) -> void:
	_story_bodies = _story_bodies.filter(func(other: Variant) -> bool: return is_instance_valid(other) and not (other as Node).is_queued_for_deletion())
	while _story_bodies.size() >= STORY_BODY_LIMIT:
		var oldest: Node = _story_bodies.pop_front()
		oldest.queue_free()
	_story_bodies.append(body)

static func _add_lifetime(body: Node3D, seconds: float, fade_target: Node3D) -> void:
	var timer := Timer.new()
	timer.name = "debris_lifetime"
	timer.one_shot = true
	timer.wait_time = maxf(0.05, seconds - 0.4)
	timer.autostart = true
	timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(body):
			return
		var shrink := body.create_tween()
		shrink.tween_property(fade_target, "scale", Vector3.ONE * 0.05, 0.4)
		shrink.tween_callback(body.queue_free)
	)
	body.add_child(timer)
