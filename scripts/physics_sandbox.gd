class_name PhysicsSandbox
extends RefCounted

const LAYER_WORLD := 1
const LAYER_ENEMY := 2
const LAYER_PUSHABLE := 4
const LAYER_TARGET := 8
const LAYER_DEBRIS := 16
const LAYER_PLAYER := 32
const SOLID_MASK := LAYER_WORLD | LAYER_ENEMY | LAYER_PUSHABLE | LAYER_PLAYER


static func create_hinged_pendulum(parent: Node3D, pivot_pos: Vector3, arm_length: float, bob_mat: Material, chain_mat: Material) -> Dictionary:
	var anchor := StaticBody3D.new()
	anchor.name = "PendulumAnchor"
	anchor.collision_layer = 0
	anchor.collision_mask = 0
	_place(parent, anchor, pivot_pos)

	var bob := RigidBody3D.new()
	bob.name = "BellClapper"
	bob.mass = 6.0
	bob.linear_damp = 0.45
	bob.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	bob.axis_lock_linear_z = true
	bob.axis_lock_angular_x = true
	bob.axis_lock_angular_y = true
	bob.collision_layer = LAYER_PUSHABLE
	bob.collision_mask = SOLID_MASK

	var sphere := SphereMesh.new()
	sphere.radius = 0.35
	sphere.height = 0.7
	var clapper := MeshInstance3D.new()
	clapper.mesh = sphere
	clapper.material_override = bob_mat
	bob.add_child(clapper)
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = sphere.radius
	var collision := CollisionShape3D.new()
	collision.shape = sphere_shape
	bob.add_child(collision)
	_add_shaft(bob, Vector3.UP * arm_length * 0.5, arm_length, 0.055, chain_mat)
	_place(parent, bob, pivot_pos - Vector3.UP * arm_length)

	var joint := PinJoint3D.new()
	joint.name = "PendulumPivot"
	_place(parent, joint, pivot_pos)
	joint.node_a = joint.get_path_to(anchor)
	joint.node_b = joint.get_path_to(bob)
	return {"anchor": anchor, "bob": bob, "joint": joint, "hits": 0, "broken": false}


static func apply_pendulum_impulse(pendulum: Dictionary, impulse_vec: Vector3) -> int:
	var hits: int = pendulum.get("hits", 0)
	var bob: RigidBody3D = pendulum.get("bob")
	if is_instance_valid(bob):
		bob.apply_central_impulse(impulse_vec)
		hits += 1
		pendulum["hits"] = hits
	return hits


static func create_buoyant_raft(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, iron_mat: Material) -> RigidBody3D:
	var raft := RigidBody3D.new()
	raft.name = "TimberRaft"
	raft.collision_layer = LAYER_WORLD | LAYER_PUSHABLE
	# The character's floor query sees the deck through LAYER_WORLD.
	# Keep the raft solver from pushing back against that kinematic floor snap.
	raft.collision_mask = LAYER_WORLD | LAYER_ENEMY | LAYER_PUSHABLE
	raft.mass = 8.0
	raft.linear_damp = 2.5
	raft.angular_damp = 5.0
	raft.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	raft.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	raft.axis_lock_angular_x = true
	raft.axis_lock_angular_z = true
	raft.can_sleep = false
	raft.set_meta("buoyancy_draft", maxf(0.18, size.y * 0.5 - 0.15))
	raft.set_meta("buoyancy_phase", 0.0)
	_add_box_collision(raft, Vector3.ZERO, size)
	var plank_width := size.x / 5.0
	for i in range(-2, 3):
		_add_box(raft, Vector3(i * plank_width, 0.0, 0.0), Vector3(plank_width * 0.98, size.y, size.z), mat)
	for offset: float in [-0.34, 0.34]:
		var strap_pos := Vector3(0.0, size.y * 0.5, size.z * offset)
		_add_box(raft, strap_pos, Vector3(size.x, 0.035, size.z * 0.07), iron_mat)
	_place(parent, raft, pos)
	return raft


static func update_buoyancy(rafts: Array, water_y: float, delta: float) -> void:
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	for raft: RigidBody3D in rafts:
		if not is_instance_valid(raft) or raft.freeze:
			continue
		var phase := fposmod(float(raft.get_meta("buoyancy_phase", 0.0)) + delta * 1.8, TAU)
		raft.set_meta("buoyancy_phase", phase)
		var draft: float = raft.get_meta("buoyancy_draft", 0.18)
		# The virtual keel displaces enough water to carry the raft at its design draft.
		var waterline := water_y + 0.15 + sin(phase) * 0.018
		var submerged := clampf(waterline - raft.global_position.y + draft, 0.0, draft * 3.0)
		if submerged <= 0.0:
			continue
		var lift_force := raft.mass * gravity * raft.gravity_scale * submerged / draft
		var damping := raft.mass * 4.0 * raft.linear_velocity.y * minf(1.0, submerged / draft)
		raft.apply_central_force(Vector3.UP * maxf(0.0, lift_force - damping))


static func create_moving_lift(parent: Node3D, start_pos: Vector3, end_pos: Vector3, size: Vector3, floor_mat: Material, rail_mat: Material) -> Dictionary:
	var body := AnimatableBody3D.new()
	body.name = "CounterweightLift"
	body.sync_to_physics = true
	body.collision_layer = LAYER_WORLD
	body.collision_mask = SOLID_MASK
	_add_box(body, Vector3.ZERO, size, floor_mat, true)

	var floor_y := size.y * 0.5
	var rail_y := floor_y + 1.0
	var rail_width := 0.09
	var x_edge := size.x * 0.5 - rail_width * 0.5
	var z_edge := size.z * 0.5 - rail_width * 0.5
	for x in [-x_edge, x_edge]:
		_add_box(body, Vector3(x, rail_y, 0.0), Vector3(rail_width, rail_width, size.z), rail_mat, true)
		_add_box(body, Vector3(x, rail_y - 0.45, 0.0), Vector3(rail_width, rail_width, size.z), rail_mat, true)
		for z in [-z_edge, z_edge]:
			_add_box(body, Vector3(x, floor_y + 0.5, z), Vector3(0.12, 1.0, 0.12), rail_mat, true)
		_add_chain(body, Vector3(x, rail_y, z_edge), rail_mat)
		var sheave := _add_shaft(body, Vector3(x, rail_y + 1.8, z_edge), 0.15, 0.22, rail_mat)
		sheave.rotation.z = PI * 0.5
	_add_box(body, Vector3(0.0, rail_y, z_edge), Vector3(size.x, rail_width, rail_width), rail_mat, true)
	_add_box(body, Vector3(0.0, rail_y - 0.45, z_edge), Vector3(size.x, rail_width, rail_width), rail_mat, true)
	_place(parent, body, start_pos)
	return {
		"body": body, "start": start_pos, "end": end_pos, "progress": 0.0,
		"active": false, "jammed": false, "jam_point": 0.52, "completed": false,
	}


static func step_moving_lift(lift: Dictionary, delta: float, speed: float = 0.14) -> String:
	var body: AnimatableBody3D = lift.get("body")
	if not is_instance_valid(body) or not lift.active or lift.jammed or lift.completed:
		return ""
	var previous: float = lift.progress
	var progress := clampf(previous + maxf(delta, 0.0) * maxf(speed, 0.0), 0.0, 1.0)
	var jam_point: float = lift.jam_point
	var event := ""
	if previous < jam_point and progress >= jam_point:
		progress = jam_point
		lift.jammed = true
		event = "jammed"
	elif progress >= 1.0:
		lift.completed = true
		lift.active = false
		event = "arrived"
	lift.progress = progress
	var start: Vector3 = lift.start
	body.global_position = start.lerp(lift.end, progress)
	return event


static func emit_noise(noise_events: Array, pos: Vector3, radius: float, strength: float = 1.0) -> void:
	noise_events.append({"pos": pos, "radius": radius, "strength": strength, "ttl": 3.5})


static func tick_noises(noise_events: Array, delta: float) -> void:
	for i in range(noise_events.size() - 1, -1, -1):
		var noise: Dictionary = noise_events[i]
		noise.ttl -= delta
		if noise.ttl <= 0.0:
			noise_events.remove_at(i)


static func get_nearest_noise(noise_events: Array, listener_pos: Vector3, hearing_range: float = 24.0) -> Dictionary:
	var nearest: Dictionary = {}
	var best_score := -INF
	for noise: Dictionary in noise_events:
		var reach := minf(hearing_range, noise.radius)
		var pos: Vector3 = noise.pos
		var distance := listener_pos.distance_to(pos)
		if reach <= 0.0 or distance > reach or noise.ttl <= 0.0 or noise.strength <= 0.0:
			continue
		var score := float(noise.strength) / (1.0 + distance)
		if score > best_score:
			nearest = noise
			best_score = score
	return nearest


static func _place(parent: Node3D, body: Node3D, pos: Vector3) -> void:
	body.position = parent.to_local(pos) if parent.is_inside_tree() else pos
	parent.add_child(body)


static func _add_box(parent: Node3D, pos: Vector3, size: Vector3, material: Material, solid: bool = false) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	visual.position = pos
	parent.add_child(visual)
	if solid:
		_add_box_collision(parent, pos, size)


static func _add_box_collision(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = pos
	parent.add_child(collision)


static func _add_chain(parent: Node3D, base: Vector3, material: Material) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.046
	mesh.outer_radius = 0.070
	mesh.rings = 12
	mesh.ring_segments = 6
	for i in 17:
		var link := MeshInstance3D.new()
		link.mesh = mesh
		link.material_override = material
		link.position = base + Vector3.UP * (0.05 + i * 0.104)
		link.rotation.x = PI * 0.5
		link.rotation.y = float(i % 2) * PI * 0.5
		parent.add_child(link)


static func _add_shaft(parent: Node3D, pos: Vector3, height: float, radius: float, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.height = height
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.radial_segments = 10
	var shaft := MeshInstance3D.new()
	shaft.mesh = mesh
	shaft.material_override = material
	shaft.position = pos
	parent.add_child(shaft)
	return shaft
