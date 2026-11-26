class_name LevelBuilder
extends RefCounted

const LAYER_WORLD := 1
const LAYER_ENEMY := 2
const LAYER_PUSHABLE := 4
const LAYER_TARGET := 8
const LAYER_DEBRIS := 16
const LAYER_PLAYER := 32

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

static func add_wet_zone(game, pos: Vector3, half_xz: Vector2) -> void:
	game.wet_zones.append({"pos": pos, "half": half_xz})

static func chapter_state(game) -> Dictionary:
	var states: Dictionary = game.level_states
	if game.level_root.has_meta("chapter_id"):
		var chapter_id: String = game.level_root.get_meta("chapter_id")
		if states.has(chapter_id):
			return states[chapter_id]
	return states[game.stage]

static func slab(parent: Node3D, node_name: String, bounds: Rect2, top: float, mat: Material, thickness: float = 0.7) -> StaticBody3D:
	return box(parent, node_name, Vector3(bounds.get_center().x, top - thickness * 0.5, bounds.get_center().y), Vector3(bounds.size.x, thickness, bounds.size.y), mat) as StaticBody3D

static func lever(parent: Node3D, node_name: String, pos: Vector3, base_mat: Material, trim_mat: Material) -> Node3D:
	var assembly := Node3D.new()
	assembly.name = node_name
	assembly.position = pos
	parent.add_child(assembly)
	box(assembly, "lever_pedestal", Vector3(0, 0.55, 0), Vector3(0.7, 1.1, 0.7), base_mat)
	var arm := box(assembly, "lever_arm", Vector3(0, 1.28, 0.14), Vector3(0.16, 0.65, 0.16), trim_mat, false)
	arm.rotation.x = 0.4
	box(arm, "handle", Vector3(0, 0.3, 0), Vector3(0.48, 0.13, 0.16), trim_mat, false)
	assembly.set_meta("lever_arm", arm)
	return assembly

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
