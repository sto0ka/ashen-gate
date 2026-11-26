class_name CombatSystems
extends RefCounted

const VisualsScript = preload("res://scripts/visuals.gd")
const ElementalScript = preload("res://scripts/elemental.gd")

const LAYER_WORLD := 1
const LAYER_ENEMY := 2
const LAYER_PUSHABLE := 4
const LAYER_TARGET := 8
const LAYER_DEBRIS := 16
const LAYER_PLAYER := 32
const ARC_MASK := LAYER_WORLD | LAYER_ENEMY | LAYER_PUSHABLE | LAYER_TARGET
const ARC_CHAIN_RANGE := 6.5
const WATER_CHAIN_RANGE := 9.5


static func fire_voltaic_arc(game, origin: Vector3, dir: Vector3, range_m: float = 18.0) -> Dictionary:
	var result := {"hit_type": "miss", "pos": origin, "chained": 0}
	if range_m <= 0.0 or dir.is_zero_approx():
		return result
	var endpoint := origin + dir.normalized() * range_m
	var ray := PhysicsRayQueryParameters3D.create(origin, endpoint, ARC_MASK)
	var player: CollisionObject3D = game.get("player")
	if is_instance_valid(player):
		ray.exclude = [player.get_rid()]
	ray.collide_with_areas = true
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var hit := space.intersect_ray(ray)
	var target: CollisionObject3D = hit.get("collider")
	var impact: Vector3 = hit.get("position", endpoint)
	var water_bounds := _collect_water_bounds(game)
	var water_impact: Variant = _first_water_impact(water_bounds, origin, impact)
	var hit_water := _is_water_target(target)
	if water_impact is Vector3:
		# A cast from inside water still reaches its first solid target.
		# Water entered along the ray intercepts it at the surface.
		if not water_impact.is_equal_approx(origin) and not water_impact.is_equal_approx(impact):
			impact = water_impact
			target = null
			hit_water = true
		elif target == null:
			impact = water_impact
			hit_water = true

	result.pos = impact
	_draw_arc(game, origin, impact)
	if target != null and target.get_meta("voltaic_conduit", false):
		game._activate_voltaic_conduit(target)
		result.hit_type = "conduit"
		return result
	if target is RigidBody3D and target.get_meta("explosive_cask", false):
		_detonate_cask(game, target)
		result.hit_type = "cask"
		return result

	var primary := target as CharacterBody3D
	var enemies: Array = game.enemies
	var has_enemy := is_instance_valid(primary) and enemies.has(primary)
	if not has_enemy and not hit_water:
		if target != null:
			result.hit_type = "world"
		return result
	result.hit_type = "enemy" if has_enemy else "water"

	var standing_pos := player.global_position if is_instance_valid(player) else origin
	var wet_cast := hit_water or _in_water(water_bounds, standing_pos)
	if has_enemy:
		wet_cast = wet_cast or _in_water(water_bounds, primary.global_position)
	var chain_range := WATER_CHAIN_RANGE if wet_cast else ARC_CHAIN_RANGE
	var struck: Array[CharacterBody3D] = []
	if not has_enemy:
		primary = _nearest_enemy(enemies, struck, impact, chain_range)
		if primary == null:
			return result
		_draw_arc(game, impact, _enemy_arc_anchor(primary))
	var arc_start := _enemy_arc_anchor(primary)
	struck.append(primary)
	_shock_enemy(game, primary, water_bounds)

	for _jump in range(2):
		var next := _nearest_enemy(enemies, struck, arc_start, chain_range)
		if next == null:
			break
		var next_anchor := _enemy_arc_anchor(next)
		_draw_arc(game, arc_start, next_anchor)
		_shock_enemy(game, next, water_bounds)
		struck.append(next)
		arc_start = next_anchor
		result.chained += 1
	return result


static func try_yank_shield(game, enemy: CharacterBody3D) -> RigidBody3D:
	if not is_instance_valid(enemy) or not enemy.get_meta("has_shield", false):
		return null
	var rig: Variant = enemy.get_meta("rig", {})
	var shield_node: Node3D
	if rig is Node3D and rig.has_meta("shield_node"):
		shield_node = rig.get_meta("shield_node")
	elif rig is Dictionary:
		shield_node = rig.get("shield_node")
	if not is_instance_valid(shield_node):
		return null
	var parent: Node3D = game.get("level_root")
	if not is_instance_valid(parent):
		parent = enemy.get_parent() as Node3D
	if parent == null:
		return null

	var shield := RigidBody3D.new()
	shield.name = "YankedTowerShield"
	shield.mass = 4.0
	shield.linear_damp = 0.65
	shield.angular_damp = 1.1
	shield.continuous_cd = true
	shield.collision_layer = LAYER_PUSHABLE
	shield.collision_mask = LAYER_WORLD | LAYER_ENEMY | LAYER_PUSHABLE | LAYER_PLAYER
	shield.set_meta("yanked_shield", true)
	var source_transform := shield_node.global_transform
	var size := Vector3(0.60, 1.29, 0.18) * source_transform.basis.get_scale().abs()
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	shield.add_child(collision)

	if shield_node is GeometryInstance3D or shield_node.get_child_count() > 0:
		var visual := shield_node.duplicate(0) as Node3D
		visual.transform = Transform3D(Basis.from_scale(source_transform.basis.get_scale()), Vector3.ZERO)
		visual.show()
		shield.add_child(visual)
	else:
		var iron := StandardMaterial3D.new()
		iron.albedo_color = Color("343839")
		iron.metallic = 0.85
		iron.roughness = 0.48
		var mesh := BoxMesh.new()
		mesh.size = size
		var visual := MeshInstance3D.new()
		visual.mesh = mesh
		visual.material_override = iron
		shield.add_child(visual)

	parent.add_child(shield)
	shield.global_transform = source_transform.orthonormalized()
	var pushables: Variant = game.get("pushable_blocks")
	if pushables is Array:
		pushables.append(shield)
	enemy.set_meta("has_shield", false)
	shield_node.hide()
	_stagger(enemy, 1.4)
	return shield


static func evaluate_parry(game, attacker: CharacterBody3D, _incoming_damage: int) -> bool:
	if game.parry_active_timer <= 0.0:
		return false
	game.parry_active_timer = 0.0
	if is_instance_valid(attacker):
		_stagger(attacker, 1.8)
	game.parry_window = 2.2
	game.mana = mini(game.max_mana, game.mana + 25)
	var audio: Node = game.get("audio_3d")
	if is_instance_valid(audio):
		audio.call("play_2d", "parry")
	game.hitstop_time = maxf(game.hitstop_time, 0.05)
	game.flash = 1.0
	game.flash_color = Color("ffd36a")
	game._message("PERFECT PARRY! (+25 BLUE MANA)")
	return true


static func _collect_water_bounds(game: Node) -> Array[AABB]:
	var bounds: Array[AABB] = []
	for property: String in ["wet_zones", "water_zones", "water_channels"]:
		var zones: Variant = game.get(property)
		if not zones is Array:
			continue
		for zone: Variant in zones:
			if zone is AABB:
				bounds.append(zone)
			elif zone is Dictionary and zone.get("active", true) and not zone.get("frozen", false) and float(zone.get("frozen_timer", 0.0)) <= 0.0:
				if zone.get("bounds") is AABB:
					bounds.append(zone.bounds)
				elif zone.get("pos") is Vector3 and zone.get("size") is Vector3:
					var size: Vector3 = zone.size
					bounds.append(AABB(zone.pos - size * 0.5, size))
				elif zone.get("pos") is Vector3 and zone.get("half") is Vector2:
					var half: Vector2 = zone.half
					var extent := Vector3(half.x, 0.5, half.y)
					bounds.append(AABB(zone.pos - extent, extent * 2.0))
	return bounds


static func _first_water_impact(bounds: Array[AABB], origin: Vector3, endpoint: Vector3) -> Variant:
	var closest: Variant = null
	var best_distance := INF
	for zone: AABB in bounds:
		var intersection: Variant = origin if zone.has_point(origin) else zone.intersects_segment(origin, endpoint)
		if intersection is Vector3:
			var distance := origin.distance_squared_to(intersection)
			if distance < best_distance:
				closest = intersection
				best_distance = distance
	return closest


static func _in_water(bounds: Array[AABB], pos: Vector3) -> bool:
	for zone: AABB in bounds:
		if zone.has_point(pos):
			return true
	return false


static func _is_water_target(target: CollisionObject3D) -> bool:
	return is_instance_valid(target) and (target.get_meta("water_zone", false) or target.get_meta("water_spout", false)) and float(target.get_meta("frozen_timer", 0.0)) <= 0.0


static func _nearest_enemy(enemies: Array, struck: Array[CharacterBody3D], origin: Vector3, reach: float) -> CharacterBody3D:
	var nearest: CharacterBody3D
	var distance_limit := reach * reach
	for enemy: CharacterBody3D in enemies:
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or struck.has(enemy):
			continue
		var distance := origin.distance_squared_to(_enemy_arc_anchor(enemy))
		if distance <= distance_limit:
			nearest = enemy
			distance_limit = distance
	return nearest


static func _enemy_arc_anchor(enemy: CharacterBody3D) -> Vector3:
	return enemy.global_position + Vector3.UP


static func _shock_enemy(game, enemy: CharacterBody3D, water_bounds: Array[AABB]) -> void:
	var elemental: ElementalScript = enemy.get_meta("elemental") if enemy.has_meta("elemental") else null
	var kind: String = enemy.get_meta("kind", "")
	var wet: bool = enemy.get_meta("wet", false) or float(enemy.get_meta("wet_timer", 0.0)) > 0.0 or _in_water(water_bounds, enemy.global_position)
	var overloaded := wet or (is_instance_valid(elemental) and elemental.is_frozen()) or kind == "ash_sentinel" or kind == "colossus"
	var damage := int(34.0 * float(game.damage_mult))
	if overloaded:
		damage += 60
	game._damage_enemy(enemy, damage)
	if overloaded and is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
		_stagger(enemy, 1.4)


static func _detonate_cask(game, cask: RigidBody3D) -> void:
	if cask.is_queued_for_deletion():
		return
	var breakables: Variant = game.get("breakables")
	if game.has_method("_smash_pot") and (not breakables is Array or breakables.has(cask)):
		game._smash_pot(cask)
	elif game.has_method("_detonate_cask"):
		var pos := cask.global_position
		cask.collision_layer = 0
		cask.queue_free()
		game._detonate_cask(pos)


static func _draw_arc(game: Node3D, from: Vector3, to: Vector3) -> void:
	var visuals: Script = VisualsScript
	# The headless renderer exposes no shader uniforms for the arc's fade tween.
	if DisplayServer.get_name() == "headless" or not visuals.has_method("spawn_lightning_arc"):
		return
	var root: Node3D = game.get("level_root")
	if not is_instance_valid(root):
		root = game
	visuals.call("spawn_lightning_arc", root, root.to_local(from), root.to_local(to))


static func _stagger(enemy: CharacterBody3D, duration: float) -> void:
	enemy.set_meta("stagger", maxf(float(enemy.get_meta("stagger", 0.0)), duration))
	enemy.set_meta("windup", 0.0)
	enemy.set_meta("pending", "")
