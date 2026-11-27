class_name CombatSystems
extends RefCounted

const VisualsScript = preload("res://scripts/visuals.gd")
const ElementalScript = preload("res://scripts/elemental.gd")
const Meshes3D = preload("res://scripts/meshes_3d.gd")

const LAYER_WORLD := 1
const LAYER_ENEMY := 2
const LAYER_PUSHABLE := 4
const LAYER_TARGET := 8
const LAYER_DEBRIS := 16
const LAYER_PLAYER := 32
const ARC_MASK := LAYER_WORLD | LAYER_ENEMY | LAYER_PUSHABLE | LAYER_TARGET
const ARC_CHAIN_RANGE := 6.5
const WATER_CHAIN_RANGE := 9.5
const SHIELD_HP := 100.0
const AEGIS_HP := 150.0
const AEGIS_BLEED_THROUGH := 0.35
const AEGIS_EXPOSED_MULTIPLIER := 1.75
const HEAVY_CLEAVE_MULTIPLIER := 1.45
const COLOSSUS_OVERDRIVE_HP := 320


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
	if target != null:
		if target in game.wards or target.get_meta("ward", false):
			game._shatter_ward(target)
			result.hit_type = "ward"
			return result
		if target in game.shootable_targets:
			game._hit_shootable_target(target, "voltaic")
			result.hit_type = "target"
			return result
		if target == game.get("tower_pendulum") or target.get_meta("pendulum", false):
			game._hit_tower_pendulum()
			result.hit_type = "pendulum"
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
	var source_transform := enemy.global_transform.translated_local(Vector3(-0.45, 1.1, -0.7))
	if is_instance_valid(shield_node):
		source_transform = shield_node.global_transform
	var size := Vector3(0.60, 1.29, 0.18) * source_transform.basis.get_scale().abs()
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	shield.add_child(collision)

	if is_instance_valid(shield_node) and (shield_node is GeometryInstance3D or shield_node.get_child_count() > 0):
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
	shield.add_collision_exception_with(enemy)
	var pushables: Variant = game.get("pushable_blocks")
	if pushables is Array:
		pushables.append(shield)
	enemy.set_meta("has_shield", false)
	enemy.set_meta("shield_hp", 0.0)
	if is_instance_valid(shield_node):
		shield_node.hide()
	_stagger(enemy, 1.4)
	return shield


static func shatter_or_rip_shield(game, enemy: CharacterBody3D, electrified: bool = false) -> bool:
	var broke := damage_executioner_shield(game, enemy, SHIELD_HP)
	if broke and electrified:
		var impact := _enemy_arc_anchor(enemy)
		if game.has_method("_spell_impact"):
			game._spell_impact(impact, Color("6bf0ff"))
		if game.has_method("_sound_at"):
			game._sound_at("voltaic", impact, 1.25)
	return broke


static func damage_executioner_shield(game, enemy: CharacterBody3D, amount: float, launch_impulse: Vector3 = Vector3.ZERO) -> bool:
	if not is_instance_valid(enemy) or not enemy.get_meta("has_shield", false) or amount <= 0.0:
		return false
	var remaining := maxf(0.0, float(enemy.get_meta("shield_hp", SHIELD_HP)) - amount)
	enemy.set_meta("shield_hp", remaining)
	var rig := enemy.get_meta("rig", null) as Node3D if enemy.has_meta("rig") else null
	var meshes: Script = Meshes3D
	if is_instance_valid(rig) and meshes.has_method("set_shield_damage"):
		meshes.call("set_shield_damage", rig, 1.0 - remaining / SHIELD_HP)
	if remaining > 0.0:
		return false
	var shield := try_yank_shield(game, enemy)
	if shield == null:
		return false
	var player := game.get("player") as Node3D
	if launch_impulse.is_zero_approx():
		var away := -enemy.global_transform.basis.z
		if is_instance_valid(player):
			var offset := enemy.global_position - player.global_position
			offset.y = 0.0
			if not offset.is_zero_approx():
				away = offset.normalized()
		launch_impulse = away * 42.0 + Vector3.UP * 15.0
	shield.apply_impulse(launch_impulse, Vector3.UP * 0.35)
	_stagger(enemy, 1.8)
	return true


# HP damage and the exposure multiplier are resolved by the attack's caller.
static func damage_warden_aegis(game, warden: CharacterBody3D, amount: float, source_label: String = "") -> Dictionary:
	var result := {"absorbed": false, "broken": false, "remaining": 0.0}
	if not is_instance_valid(warden):
		return result
	var current := float(warden.get_meta("aegis_hp", 0.0))
	result.remaining = current
	if current <= 0.0 or amount <= 0.0:
		return result

	var remaining := maxf(0.0, current - amount)
	var broken := remaining == 0.0
	warden.set_meta("aegis_hp", remaining)
	result = {"absorbed": true, "broken": broken, "remaining": remaining}
	if broken:
		_stagger(warden, 4.0)
		warden.set_meta("aegis_exposed_timer", 6.5)
	var color := Color("f8d480") if broken else Color("d99cfa")
	var impact := warden.global_position + Vector3.UP * 2.2
	if game.has_method("_sound_at"):
		game._sound_at("bell", impact, 0.68 if broken else 1.45)
	if game.has_method("_spell_impact"):
		game._spell_impact(impact, color)
	var rig := warden.get_meta("rig", null) as Node3D if warden.has_meta("rig") else null
	var meshes: Script = Meshes3D
	if is_instance_valid(rig) and meshes.has_method("set_warden_aegis"):
		meshes.call("set_warden_aegis", rig, remaining / float(warden.get_meta("aegis_max_hp", AEGIS_HP)), game.wards.size())
	var narrative: Object = game.get("narrative")
	if broken:
		if game.has_method("_shockwave"):
			game._shockwave(warden.global_position + Vector3.UP * 0.15, color, 9.0)
		if is_instance_valid(narrative):
			# Let the hit's parry, reflection, or explosion feedback finish first.
			narrative.call_deferred("show_style_banner", "RESONANT AEGIS SHATTERED! (EXPOSED)", color)
	elif not source_label.is_empty() and is_instance_valid(narrative):
		narrative.call("show_style_banner", source_label, color)
	return result


static func find_grasp_target(game, origin: Vector3, dir: Vector3, max_range: float = 11.0) -> Object:
	if dir.is_zero_approx() or max_range <= 0.0:
		return null
	var forward := dir.normalized()
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var hit := _aim_ray(game, space, origin, origin + forward * max_range)
	var direct: Node3D = hit.get("collider")
	if _can_grasp(game, direct):
		return direct

	var best: Node3D
	var best_score := INF
	var candidates: Array = []
	candidates.append_array(game.enemies)
	candidates.append_array(game.breakables)
	candidates.append_array(game.pushable_blocks)
	for candidate: Node3D in candidates:
		if not _can_grasp(game, candidate):
			continue
		var point := _aim_anchor(candidate, origin.y)
		var offset := point - origin
		var along := offset.dot(forward)
		if along <= 0.0 or offset.length_squared() > max_range * max_range:
			continue
		var miss := (offset - forward * along).length()
		if miss > minf(1.15, 0.35 + along * 0.10):
			continue
		var score := miss + along * 0.045
		if score < best_score and _aim_visible(space, origin, point, candidate):
			best = candidate
			best_score = score
	return best


static func melee_cleave_sweep(game, origin: Vector3, dir: Vector3, reach: float = 3.7, combo_step: int = 0) -> Dictionary:
	var enemies: Array[CharacterBody3D] = []
	var breakables: Array[RigidBody3D] = []
	var wards: Array[StaticBody3D] = []
	var targets: Array[Node3D] = []
	var result := {"enemies": enemies, "breakables": breakables, "wards": wards, "targets": targets,
		"pendulum": false, "hit_world": false, "hit_pos": origin}
	if dir.is_zero_approx() or reach <= 0.0:
		return result

	var forward := dir.normalized()
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var hit := _aim_ray(game, space, origin, origin + forward * reach)
	var direct: Node3D = hit.get("collider")
	result.hit_pos = hit.get("position", origin + forward * reach)
	if is_instance_valid(direct):
		result.hit_world = not _record_cleave_hit(game, direct, result)

	var candidates: Array = []
	candidates.append_array(game.enemies)
	candidates.append_array(game.breakables)
	candidates.append_array(game.wards)
	candidates.append_array(game.shootable_targets)
	var pendulum: Node3D = game.get("tower_pendulum")
	if is_instance_valid(pendulum):
		candidates.append(pendulum)
	var assisted_hits: Array[Dictionary] = []
	for candidate: Node3D in candidates:
		if not is_instance_valid(candidate) or candidate == direct or candidate.is_queued_for_deletion():
			continue
		var point := _aim_anchor(candidate, origin.y)
		var offset := point - origin
		if offset.length_squared() <= reach * reach and offset.normalized().dot(forward) >= 0.72 and _aim_visible(space, origin, point, candidate):
			assisted_hits.append({"node": candidate, "point": point, "distance": offset.length_squared()})
	assisted_hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.distance < b.distance)
	var has_contact: bool = not hit.is_empty() and not result.hit_world
	for candidate: Dictionary in assisted_hits:
		if candidate.node is CharacterBody3D and combo_step != 2 and not enemies.is_empty():
			continue
		if _record_cleave_hit(game, candidate.node, result) and not has_contact:
			result.hit_pos = candidate.point
			has_contact = true
	return result


static func is_colossus_chest_weakpoint(enemy: CharacterBody3D, hit_pos: Vector3) -> bool:
	if not is_instance_valid(enemy) or enemy.get_meta("kind", "") != "colossus":
		return false
	if int(enemy.get_meta("hp", 640)) > COLOSSUS_OVERDRIVE_HP:
		return false

	var half_height := 2.3
	var radius := 1.25
	var point := enemy.to_local(hit_pos) - Vector3.UP * half_height
	for child in enemy.get_children():
		if child is CollisionShape3D and not child.disabled and child.shape is CapsuleShape3D:
			var capsule: CapsuleShape3D = child.shape
			half_height = _shape_half_height(capsule)
			radius = capsule.radius
			point = child.to_local(hit_pos)
			break

	# Enemies face local -Z. The top 45% begins 10% of a half-height above the center.
	if point.z >= 0.0 or point.y < half_height * 0.1:
		return false
	var cap_offset := maxf(0.0, point.y - (half_height - radius))
	var surface_radius := radius + 0.05
	return Vector3(point.x, cap_offset, point.z).length_squared() <= surface_radius * surface_radius


static func is_weakpoint_hit(enemy: CharacterBody3D, hit_pos: Vector3) -> bool:
	if not is_instance_valid(enemy):
		return false
	if is_colossus_chest_weakpoint(enemy, hit_pos):
		# The arbalest impact path uses this result for its critical damage multiplier.
		VisualsScript.spawn_glyph_drift(enemy.get_parent() as Node3D, hit_pos, 8, 0.65)
		return true
	for child in enemy.get_children():
		if child is CollisionShape3D and not child.disabled and child.shape != null:
			var half_height := _shape_half_height(child.shape)
			var y: float = child.to_local(hit_pos).y
			return y >= half_height * 0.36 and y <= half_height + 0.05
	# Legacy enemies use a 2 m standing capsule at their feet.
	var local_y := enemy.to_local(hit_pos).y
	return local_y >= 1.36 and local_y <= 2.05


static func evaluate_parry(game, attacker: CharacterBody3D, _incoming_damage: int) -> bool:
	if game.parry_active_timer <= 0.0:
		return false
	game.parry_active_timer = 0.0
	if is_instance_valid(attacker):
		_stagger(attacker, 1.8)
		match attacker.get_meta("kind", ""):
			"warden":
				if game.wards.is_empty():
					damage_warden_aegis(game, attacker, 80.0)
			"executioner":
				damage_executioner_shield(game, attacker, 60.0)
	game.parry_window = 2.4
	game.mana = mini(game.max_mana, game.mana + 25)
	var audio: Node = game.get("audio_3d")
	if is_instance_valid(audio):
		audio.call("play_2d", "parry")
	game.hitstop_time = maxf(game.hitstop_time, 0.05)
	game.flash = 1.0
	game.flash_color = Color("ffd36a")
	game._message("PERFECT PARRY! (+25 BLUE MANA)")
	return true


static func _can_grasp(game, target: Node3D) -> bool:
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		return false
	if target is CharacterBody3D:
		return game.enemies.has(target) and target.get_meta("has_shield", false)
	return target is RigidBody3D and not target.freeze and not target.get_meta("ore_cart", false) and not target.get_meta("pendulum", false)


static func _aim_ray(game, space: PhysicsDirectSpaceState3D, origin: Vector3, endpoint: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(origin, endpoint, ARC_MASK)
	query.collide_with_areas = true
	var player: CollisionObject3D = game.get("player")
	if is_instance_valid(player):
		query.exclude = [player.get_rid()]
	return space.intersect_ray(query)


static func _aim_visible(space: PhysicsDirectSpaceState3D, origin: Vector3, point: Vector3, candidate: Node3D) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(origin, point, LAYER_WORLD)
	ray.hit_from_inside = true
	var hit := space.intersect_ray(ray)
	return hit.is_empty() or hit.collider == candidate


static func _aim_anchor(target: Node3D, aim_y: float) -> Vector3:
	for child in target.get_children():
		if child is CollisionShape3D and not child.disabled and child.shape != null:
			var point: Vector3 = child.global_position
			var half_height: float = _shape_half_height(child.shape) * child.global_basis.y.length() * 0.78
			point.y = clampf(aim_y, point.y - half_height, point.y + half_height)
			return point
	return target.global_position


static func _shape_half_height(shape: Shape3D) -> float:
	if shape is CapsuleShape3D or shape is CylinderShape3D:
		return shape.height * 0.5
	if shape is SphereShape3D:
		return shape.radius
	if shape is BoxShape3D:
		return shape.size.y * 0.5
	return shape.get_debug_mesh().get_aabb().size.y * 0.5


static func _record_cleave_hit(game, candidate: Node3D, result: Dictionary) -> bool:
	if candidate.is_queued_for_deletion():
		return false
	if candidate == game.get("tower_pendulum") or candidate.get_meta("pendulum", false):
		result.pendulum = true
	elif candidate is CharacterBody3D and game.enemies.has(candidate):
		result.enemies.append(candidate)
	elif candidate is RigidBody3D and game.breakables.has(candidate):
		result.breakables.append(candidate)
	elif candidate is StaticBody3D and (game.wards.has(candidate) or candidate.get_meta("ward", false)):
		result.wards.append(candidate)
	elif game.shootable_targets.has(candidate):
		result.targets.append(candidate)
	else:
		return false
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
	if enemy.get_meta("has_shield", false):
		shatter_or_rip_shield(game, enemy, true)
	if kind == "warden" and game.wards.is_empty():
		var health_multiplier := AEGIS_EXPOSED_MULTIPLIER if float(enemy.get_meta("aegis_exposed_timer", 0.0)) > 0.0 else 1.0
		if float(enemy.get_meta("aegis_hp", 0.0)) > 0.0:
			damage_warden_aegis(game, enemy, 50.0, "VOLTAIC OVERLOAD")
			health_multiplier *= AEGIS_BLEED_THROUGH
		damage = maxi(1, roundi(damage * health_multiplier))
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
	enemy.set_meta("rush_timer", 0.0)
