class_name EnemyAI
extends RefCounted

const ElementalComponent = preload("res://scripts/elemental.gd")
const Meshes3D = preload("res://scripts/meshes_3d.gd")
const PhysicsSandbox = preload("res://scripts/physics_sandbox.gd")
const CombatSystems = preload("res://scripts/combat_systems.gd")
const Visuals = preload("res://scripts/visuals.gd")

const GRAVITY := 18.0
const LAYER_WORLD := CombatSystems.LAYER_WORLD
const SEPARATION_RADIUS := 2.2
const BELFRY_ENTRANCE_Z := -30.5
const BELFRY_FLOOR_Y := 9.65
const WARDEN_FLIGHT_Y := 11.6
const WARDEN_PHASE_TWO_AEGIS := 120.0

const WARDEN_GROUNDED_ATTACKS := ["melee", "tolling_wave", "sonic_volley", "dread_summon"]
const WARDEN_AIRBORNE_ATTACKS := ["boss_triple", "tolling_wave"]
const COLOSSUS_ATTACKS := ["tolling_wave", "boss_triple", "melee"]
const COLOSSUS_WHISPERS := ["—HESK—", "—third bell—", "—room on the raft—", "—WARE—"]
const BLOOD := Color("bd2820")
const CINDER := Color("ff7828")
const VIOLET := Color("bd69f3")


static func update_all(game, delta: float) -> void:
	var player: CharacterBody3D = game.player
	if not is_instance_valid(player) or delta <= 0.0:
		return
	var elapsed: float = game.elapsed
	for enemy: CharacterBody3D in game.enemies.duplicate():
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			_update_enemy(game, enemy, player, delta, elapsed)
	update_npcs(game, delta)


static func update_npcs(game, _delta: float) -> void:
	var elapsed: float = game.elapsed
	var narrative: Node = game.get("narrative")
	var speaker := ""
	if is_instance_valid(narrative) and is_instance_valid(narrative.sub_speaker_lbl) and narrative.sub_speaker_lbl.is_visible_in_tree():
		speaker = narrative.sub_speaker_lbl.text
	for npc: Dictionary in game.npc_nodes:
		var rig: Node3D = npc.get("rig")
		if not is_instance_valid(rig):
			continue
		var speed := float(rig.get_meta("npc_speed", npc.get("speed", rig.get_meta("walk_speed", 0.0))))
		var gesture := str(rig.get_meta("npc_gesture", npc.get("gesture", rig.get_meta("gesture", ""))))
		var speaking := not speaker.is_empty() and speaker == str(npc.get("speaker", "")).to_upper()
		# The story director can animate a walking rig before this update.
		var stepped := bool(rig.get_meta("step_triggered", false))
		Meshes3D.animate_npc_rig(rig, elapsed, speaking, speed, gesture)
		if stepped or rig.get_meta("step_triggered", false):
			rig.set_meta("step_triggered", false)
			var holder: Node3D = npc.get("node", rig.get_parent())
			if speed > 0.05 and is_instance_valid(holder):
				game._sound_at("step", holder.global_position, 1.05)


static func _update_enemy(game, enemy: CharacterBody3D, player: CharacterBody3D, delta: float, elapsed: float) -> void:
	var kind: String = enemy.get_meta("kind", "shrieker")
	var rig: Node3D = enemy.get_meta("rig") if enemy.has_meta("rig") else null
	var warning: Node3D = enemy.get_meta("warning") if enemy.has_meta("warning") else null
	var dormant := bool(enemy.get_meta("dormant", false))
	var emerge_timer := float(enemy.get_meta("emerge_timer", 0.0))
	if dormant or emerge_timer > 0.0:
		if is_instance_valid(warning):
			warning.visible = false
		enemy.set_meta("rush_timer", 0.0)
		enemy.set_meta("windup", 0.0)
		enemy.set_meta("pending", "")
		if dormant:
			enemy.velocity = Vector3.UP * minf(enemy.velocity.y, 0.0)
			_move(enemy, Vector3.ZERO, delta, false, 16.0)
		else:
			_update_emergence(game, enemy, emerge_timer, delta)
		if is_instance_valid(rig):
			Meshes3D.animate_enemy_rig(rig, elapsed, 0.0, 0.0, false, false)
		return

	var elemental: ElementalComponent = enemy.get_meta("elemental") if enemy.has_meta("elemental") else null
	if is_instance_valid(elemental) and elemental.tick(delta).burn_tick:
		game._damage_enemy(enemy, int(10.0 * game.damage_mult), false)
		if not is_instance_valid(enemy) or not game.enemies.has(enemy):
			return

	var frozen := is_instance_valid(elemental) and elemental.is_solid_frozen()
	var slow := elemental.slow_multiplier() if is_instance_valid(elemental) else 1.0
	var hit_flash := _tick_timer(enemy, "hit_flash", delta * 6.0)
	var stagger := _tick_timer(enemy, "stagger", delta)
	_tick_timer(enemy, "guard", delta)
	_tick_timer(enemy, "aegis_exposed_timer", delta)
	if is_instance_valid(rig):
		var frost := 1.0 if frozen else (0.55 if is_instance_valid(elemental) and elemental.is_frozen() else 0.0)
		var burn := 1.0 if is_instance_valid(elemental) and elemental.is_burning() else 0.0
		Meshes3D.set_rig_status(rig, hit_flash, frost, burn)

	if not enemy.has_meta("home_pos"):
		enemy.set_meta("home_pos", enemy.global_position)
		enemy.set_meta("strafe_sign", 1.0 if enemy.get_instance_id() % 2 == 0 else -1.0)
	var home: Vector3 = enemy.get_meta("home_pos")
	var offset := player.global_position - enemy.global_position
	var distance := _flat(offset).length()
	var active: bool = distance < 28.0 and (enemy.get_meta("boss", false) or absf(offset.y) < 5.0)
	var airborne := false
	if kind == "stalker":
		active = true
	elif kind == "warden":
		active = active and _warden_active(game, player.global_position)
		if active:
			airborne = _update_warden_phase(game, enemy)
		else:
			# Keep a Warden that has already ascended aloft when the player retreats.
			airborne = enemy.get_meta("aegis_phase_two", false)
	elif kind == "colossus":
		_update_colossus_overdrive(game, enemy, rig, elapsed)

	var windup_progress := 0.0
	var parry_glint := 0.0
	var pending: String = enemy.get_meta("pending", "")
	if is_instance_valid(warning):
		warning.visible = false

	if frozen or not active:
		enemy.set_meta("rush_timer", 0.0)
		_move(enemy, Vector3.ZERO, delta, airborne, 16.0)
	elif stagger > 0.0:
		enemy.set_meta("rush_timer", 0.0)
		if _move_staggered(game, enemy, delta, airborne):
			return
	elif float(enemy.get_meta("rush_timer", 0.0)) > 0.0:
		_update_rush(game, enemy, player, delta)
	elif float(enemy.get_meta("windup", 0.0)) > 0.0:
		if is_instance_valid(warning):
			warning.visible = true
		if pending != "lunge" and pending != "shield_charge":
			_face(enemy, offset, delta)
		var windup := _tick_timer(enemy, "windup", delta * slow)
		windup_progress = 1.0 - windup / float(enemy.get_meta("windup_max", 0.5))
		var parry_window := 0.26 if kind == "executioner" and pending == "melee" else 0.28
		if pending in ["melee", "lunge", "shield_charge"] and windup <= parry_window:
			parry_glint = 0.72 + 0.28 * cos(windup * TAU / parry_window)
		_move(enemy, Vector3.ZERO, delta, airborne, 14.0)
		if windup <= 0.0:
			enemy.set_meta("pending", "")
			if is_instance_valid(warning):
				warning.visible = false
			_release_attack(game, enemy, player, rig, kind, pending, airborne)
	else:
		_update_tactics(game, enemy, player, home, rig, kind, delta, elapsed, slow, airborne)
		enemy.set_meta("wall_slammed", false)

	if is_instance_valid(rig):
		_animate(game, enemy, player, rig, elapsed, windup_progress, frozen, stagger > 0.0, parry_glint)


static func _update_emergence(game, enemy: CharacterBody3D, time_left: float, delta: float) -> void:
	if not enemy.has_meta("emerge_total_time"):
		enemy.set_meta("emerge_total_time", time_left)
		if not enemy.has_meta("emerge_start_y"):
			enemy.set_meta("emerge_start_y", enemy.global_position.y)
	var duration := float(enemy.get_meta("emerge_total_time"))
	var remaining := _tick_timer(enemy, "emerge_timer", delta)
	var start_y := float(enemy.get_meta("emerge_start_y"))
	var target_y := float(enemy.get_meta("emerge_target_y", start_y))
	var pos := enemy.global_position
	pos.y = lerpf(start_y, target_y, smoothstep(0.0, 1.0, 1.0 - remaining / duration))
	enemy.velocity = Vector3.ZERO
	enemy.global_position = pos
	if _tick_timer(enemy, "emerge_fx_timer", delta) <= 0.0:
		enemy.set_meta("emerge_fx_timer", 0.24)
		pos.y = target_y + 0.05
		var fx := str(enemy.get_meta("emerge_fx", "splash"))
		var seed_value := enemy.get_instance_id() + roundi(1000.0 * remaining)
		var burst := Visuals.spawn_dust_burst(game.level_root, pos, Vector3.UP, fx, seed_value)
		if fx == "splash" and is_instance_valid(burst) and burst.get_meta("burst_kind", "") == "dust":
			# Give the generic burst water motion and color when there is no splash preset.
			var material := burst.process_material as ParticleProcessMaterial
			material.color = Color(0.56, 0.81, 0.9, 0.8)
			material.gravity = Vector3.DOWN * 9.8
			material.initial_velocity_min = 2.4
			material.initial_velocity_max = 5.2
			material.damping_min = 0.3
			material.damping_max = 0.5
	if remaining <= 0.0:
		enemy.remove_meta("emerge_total_time")
		enemy.remove_meta("emerge_fx_timer")


static func _update_colossus_overdrive(game, enemy: CharacterBody3D, rig: Node3D, elapsed: float) -> void:
	var low_hp := int(enemy.get_meta("hp", 640)) <= CombatSystems.COLOSSUS_OVERDRIVE_HP
	if low_hp and not enemy.get_meta("colossus_overdrive_visual", false):
		enemy.set_meta("colossus_overdrive_visual", true)
		Meshes3D.set_colossus_overdrive(rig, true)
	if (low_hp or game.boss_phase > 0) and elapsed >= float(enemy.get_meta("colossus_whisper_at", 0.0)):
		var narrative: Node = game.get("narrative")
		if is_instance_valid(narrative) and narrative.has_method("submit_bark"):
			var index := int(enemy.get_meta("colossus_whisper_index", 0))
			enemy.set_meta("colossus_whisper_at", elapsed + 4.5)
			if narrative.submit_bark("hollow_choir", "— WHISPER —", COLOSSUS_WHISPERS[index], enemy.global_position, 1.5, 4.0):
				enemy.set_meta("colossus_whisper_index", (index + 1) % COLOSSUS_WHISPERS.size())


static func _warden_active(game, player_pos: Vector3) -> bool:
	var at_belfry: bool = player_pos.y >= 8.5 and game.triggered_volumes.has("belfry_sanctum")
	return game.wards.is_empty() and (player_pos.z < BELFRY_ENTRANCE_Z or at_belfry)


static func _update_warden_phase(game, warden: CharacterBody3D) -> bool:
	if not warden.has_meta("aegis_hp"):
		warden.set_meta("aegis_hp", CombatSystems.AEGIS_HP)
	if not warden.has_meta("aegis_max_hp"):
		warden.set_meta("aegis_max_hp", CombatSystems.AEGIS_HP)
	if not warden.get_meta("aegis_phase_two", false) and int(warden.get_meta("hp", 520)) <= 260:
		warden.set_meta("aegis_phase_two", true)
		warden.set_meta("aegis_hp", WARDEN_PHASE_TWO_AEGIS)
		warden.set_meta("aegis_max_hp", WARDEN_PHASE_TWO_AEGIS)
		warden.set_meta("attack_sequence", 0)
		warden.set_meta("pending", "")
		warden.set_meta("windup", 0.0)
		warden.set_meta("attack", 0.6)
		game.boss_phase = 1
		var director: Node = game.get("story_director")
		if is_instance_valid(director) and director.has_sequence("ch2_tower/warden_phase_two"):
			director.start_sequence("ch2_tower/warden_phase_two")
		else:
			game._sound_at("bell", warden.global_position, 0.8)
			game.narrative.show_style_banner("PHASE II — REFLECT HIS TOLLS", Color("d99cbd"))
	return warden.get_meta("aegis_phase_two", false)


static func _update_tactics(game, enemy: CharacterBody3D, player: CharacterBody3D, home: Vector3, rig: Node3D, kind: String, delta: float, elapsed: float, slow: float, airborne: bool) -> void:
	var offset := player.global_position - enemy.global_position
	var distance := _flat(offset).length()
	var toward := _flat(offset).normalized()
	var side := toward.cross(Vector3.UP)
	var strafe := _strafe_sign(enemy, delta)
	var attack_ready := _tick_timer(enemy, "attack", delta * slow) <= 0.0
	var desired := Vector3.ZERO
	var facing := offset
	var attack := ""

	match kind:
		"shrieker":
			desired = toward * (3.7 if distance > 1.9 else 0.0) + side * strafe * 1.45
			if distance <= 2.5:
				attack = "melee"
			elif distance >= 3.5 and distance <= 6.5:
				attack = "lunge"
		"executioner":
			desired = toward * (2.45 if distance > 2.35 else 0.0)
			if distance < 2.9:
				attack = "melee"
			elif enemy.get_meta("has_shield", false) and distance >= 4.5 and distance <= 9.5:
				attack = "shield_charge"
		"acolyte":
			if _tick_timer(enemy, "blink_cooldown", delta) <= 0.0 and distance < 4.8 and _try_blink(game, enemy, side, strafe):
				enemy.set_meta("blink_cooldown", 4.5)
				enemy.set_meta("attack", 0.35)
				return
			desired = side * strafe * 1.2
			if distance < 7.0:
				desired -= toward * 2.8
			elif distance > 14.0:
				desired += toward * 2.4
			if distance <= 14.0:
				attack = "cast"
		"stalker":
			var noise := PhysicsSandbox.get_nearest_noise(game.noise_events, enemy.global_position, 24.0)
			var senses_player := distance <= 5.5 and absf(offset.y) < 2.0
			if not noise.is_empty():
				_hear_noise(game, enemy, rig, noise)
				facing = noise.pos - enemy.global_position
				if _flat(facing).length() > 1.1:
					desired = _flat(facing).normalized() * 6.2
			elif not senses_player:
				var pace := Vector3(sin(elapsed * 0.75), 0.0, cos(elapsed * 0.75)) * 2.5
				facing = home + pace - enemy.global_position
				desired = _flat(facing).normalized() * 1.35
			if senses_player and (noise.is_empty() or distance <= 2.5):
				facing = offset
				desired = toward * (4.8 if distance > 1.7 else 0.0)
			if distance < 2.7:
				attack = "melee"
		"ash_sentinel":
			desired = toward * (2.1 if distance > 2.55 else 0.0)
			if distance < 3.4:
				attack = "cinder_nova" if int(enemy.get_meta("attack_sequence", 0)) % 2 == 0 else "melee"
			elif distance >= 5.5 and distance <= 14.0:
				attack = "cinder_lob"
		"warden":
			if airborne:
				var orbit := Vector3(sin(elapsed * 0.72) * 5.0, 0.0, cos(elapsed * 0.72) * 4.0)
				desired = (_flat(home + orbit - enemy.global_position) * 1.8).limit_length(4.4)
			else:
				desired = toward * (2.55 if distance > 3.4 else 0.0) + side * strafe * 0.7
			if attack_ready:
				var sequence := WARDEN_AIRBORNE_ATTACKS if airborne else WARDEN_GROUNDED_ATTACKS
				attack = _next_boss_attack(game, enemy, player, sequence, distance)
		"colossus":
			desired = toward * (2.2 if distance > 3.5 else 0.0)
			if attack_ready:
				attack = _next_boss_attack(game, enemy, player, COLOSSUS_ATTACKS, distance)
		_:
			desired = toward * (3.4 if distance > 1.85 else 0.0)
			if distance < 2.5:
				attack = "melee"

	_face(enemy, facing, delta)
	if attack_ready and not attack.is_empty() and _can_attack(game, enemy, player, attack):
		_begin_attack(enemy, kind, attack, toward)
		desired = Vector3.ZERO
	else:
		desired += _separation(game.enemies, enemy)
		if not desired.is_zero_approx():
			desired = _steer(enemy, desired, strafe)
	_move(enemy, desired * slow, delta, airborne)


static func _next_boss_attack(game, enemy: CharacterBody3D, player: CharacterBody3D, sequence: Array, distance: float) -> String:
	var index := int(enemy.get_meta("attack_sequence", 0)) % sequence.size()
	for i in sequence.size():
		var slot := (index + i) % sequence.size()
		var attack: String = sequence[slot]
		if attack == "melee" and distance > 4.4:
			continue
		if attack == "dread_summon" and _summon_count(game.enemies) >= 2:
			continue
		if attack == "tolling_wave" and distance > 15.0:
			continue
		if _can_attack(game, enemy, player, attack):
			enemy.set_meta("attack_sequence", (slot + 1) % sequence.size())
			return attack
	return ""


static func _can_attack(game, enemy: CharacterBody3D, player: CharacterBody3D, attack: String) -> bool:
	match attack:
		"tolling_wave":
			if enemy.get_meta("kind", "") == "colossus":
				var director: Node = game.get("story_director")
				if is_instance_valid(director) and director.has_method("get_last_bell_toll_age"):
					var last_age: float = director.get_last_bell_toll_age()
					return last_age >= 90.0 or last_age <= 0.65
			return true
		"dread_summon", "cinder_nova":
			return true
		"cast", "cinder_lob", "sonic_volley", "boss_triple":
			var launch_height := 2.2 if enemy.get_meta("boss", false) else 1.65
			return _clear_to_player(game, enemy, player, launch_height)
		_:
			return absf(player.global_position.y - enemy.global_position.y) <= 1.35 and _clear_to_player(game, enemy, player, 1.05)


static func _begin_attack(enemy: CharacterBody3D, kind: String, attack: String, direction: Vector3) -> void:
	var duration := 0.55
	match attack:
		"lunge":
			duration = 0.45
		"shield_charge", "tolling_wave":
			duration = 0.65
		"cinder_nova":
			duration = 0.7
		"melee":
			match kind:
				"executioner": duration = 0.60
				"stalker": duration = 0.26
				"shrieker": duration = 0.32
				"colossus": duration = 0.72
	enemy.set_meta("pending", attack)
	enemy.set_meta("windup", duration)
	enemy.set_meta("windup_max", duration)
	if kind == "ash_sentinel":
		enemy.set_meta("attack_sequence", int(enemy.get_meta("attack_sequence", 0)) + 1)
	if attack in ["lunge", "shield_charge"]:
		enemy.set_meta("rush_direction", direction)
		enemy.look_at(enemy.global_position + direction, Vector3.UP)


static func _release_attack(game, enemy: CharacterBody3D, player: CharacterBody3D, rig: Node3D, kind: String, attack: String, airborne: bool) -> void:
	var recovery := 1.4
	match kind:
		"stalker": recovery = 0.54
		"shrieker": recovery = 0.9
		"acolyte": recovery = 1.9
		"executioner": recovery = 1.65
		"warden": recovery = 1.7 if airborne else 2.05
		"colossus":
			var overdrive: bool = game.boss_phase > 0 or int(enemy.get_meta("hp", 640)) <= CombatSystems.COLOSSUS_OVERDRIVE_HP
			recovery = 1.55 if overdrive else 2.05
	enemy.set_meta("attack", recovery)

	match attack:
		"lunge", "shield_charge":
			_slash(rig, BLOOD if attack == "lunge" else Color("ffc888"))
			enemy.set_meta("rush_timer", 0.48 if attack == "lunge" else 0.68)
			enemy.set_meta("rush_kind", attack)
			game._sound_at("axe" if attack == "lunge" else "maul", enemy.global_position)
		"melee":
			var reach := 4.4 if enemy.get_meta("boss", false) else (3.4 if kind == "ash_sentinel" else 2.9)
			_slash(rig, CINDER if kind in ["ash_sentinel", "colossus"] else BLOOD)
			if _flat(player.global_position - enemy.global_position).length() <= reach and _can_attack(game, enemy, player, attack):
				var damage := 12
				match kind:
					"stalker": damage = 17
					"executioner": damage = 20
					"ash_sentinel", "warden": damage = 24
					"colossus": damage = 28
				game._hurt(damage, enemy.global_position, BLOOD, enemy)
		"cast":
			if _can_attack(game, enemy, player, attack):
				game._enemy_cast(enemy, false)
		"sonic_volley":
			if _can_attack(game, enemy, player, attack):
				_cast_volley(game, enemy, [0.0, 0.19], "curse")
		"boss_triple":
			if _can_attack(game, enemy, player, attack):
				if kind == "colossus":
					_cast_volley(game, enemy, [-0.23, 0.0, 0.23], "cinder")
				else:
					game._enemy_cast_triple(enemy)
		"cinder_lob":
			if _can_attack(game, enemy, player, attack):
				_cast_volley(game, enemy, [0.0], "cinder")
		"tolling_wave", "cinder_nova":
			var floor_y := BELFRY_FLOOR_Y if kind == "warden" else enemy.global_position.y + 0.11
			game._spawn_tolling_wave(enemy.global_position, floor_y)
			if attack == "cinder_nova":
				game.active_shockwaves.back().max_radius = 6.0
				game._spell_impact(enemy.global_position + Vector3.UP * 0.25, CINDER)
		"dread_summon":
			_summon_shriekers(game, enemy)


static func _update_rush(game, enemy: CharacterBody3D, player: CharacterBody3D, delta: float) -> void:
	var attack: String = enemy.get_meta("rush_kind", "lunge")
	var direction: Vector3 = enemy.get_meta("rush_direction", Vector3.ZERO)
	var speed := 11.2 if attack == "lunge" else 13.2
	var time_left := _tick_timer(enemy, "rush_timer", delta)
	_move(enemy, direction * speed, delta, false, 85.0)
	var offset := player.global_position - enemy.global_position
	var in_front := _flat(offset).normalized().dot(direction) > 0.2
	if in_front and _flat(offset).length() <= 2.0 and _can_attack(game, enemy, player, attack):
		enemy.set_meta("rush_timer", 0.0)
		game._hurt(16 if attack == "lunge" else 24, enemy.global_position, BLOOD, enemy)
	elif time_left <= 0.0 or enemy.is_on_wall():
		enemy.set_meta("rush_timer", 0.0)
		if attack == "shield_charge":
			enemy.set_meta("stagger", 0.6)
			enemy.velocity.x *= 0.15
			enemy.velocity.z *= 0.15


static func _move_staggered(game, enemy: CharacterBody3D, delta: float, airborne: bool) -> bool:
	var pre_speed := _flat(enemy.velocity).length()
	_move(enemy, Vector3.ZERO, delta, airborne, 12.0)
	if pre_speed > 7.5 and enemy.is_on_wall() and not enemy.get_meta("wall_slammed", false):
		enemy.set_meta("wall_slammed", true)
		game._spell_impact(enemy.global_position + Vector3.UP, Color("d6c6a4"))
		game.camera_shake = maxf(game.camera_shake, 0.12)
		game.narrative.show_style_banner("WALL SLAM! +28", Color("f0d297"))
		game._damage_enemy(enemy, int(28.0 * game.damage_mult), false)
		return not is_instance_valid(enemy) or not game.enemies.has(enemy)
	return false


static func _move(enemy: CharacterBody3D, desired: Vector3, delta: float, airborne: bool, acceleration: float = 12.0) -> void:
	var horizontal := _flat(enemy.velocity).move_toward(desired, delta * acceleration)
	enemy.velocity.x = horizontal.x
	enemy.velocity.z = horizontal.z
	if airborne:
		enemy.velocity.y = clampf((WARDEN_FLIGHT_Y - enemy.global_position.y) * 3.0, -4.0, 4.0)
	elif not enemy.is_on_floor():
		enemy.velocity.y -= GRAVITY * delta
	elif enemy.velocity.y < 0.0:
		enemy.velocity.y = 0.0
	enemy.move_and_slide()


static func _separation(enemies: Array, enemy: CharacterBody3D) -> Vector3:
	var force := Vector3.ZERO
	for neighbor: CharacterBody3D in enemies:
		if not is_instance_valid(neighbor) or neighbor == enemy or neighbor.is_queued_for_deletion():
			continue
		var delta := enemy.global_position - neighbor.global_position
		if absf(delta.y) > 1.5:
			continue
		var distance := _flat(delta).length()
		if distance < SEPARATION_RADIUS:
			force += _flat(delta).normalized() * (1.0 - distance / SEPARATION_RADIUS) * 2.4
	return force.limit_length(1.7)


static func _steer(enemy: CharacterBody3D, desired: Vector3, side: float) -> Vector3:
	var from := enemy.global_position + Vector3.UP * 0.85
	var direction := desired.normalized()
	if not _ray_blocked(enemy, from, from + direction * 1.3):
		return desired
	for sign_value: float in [side, -side]:
		var around := direction.rotated(Vector3.UP, sign_value * 1.05)
		if not _ray_blocked(enemy, from, from + around * 1.3):
			return around * desired.length()
	return direction.rotated(Vector3.UP, side * PI * 0.5) * desired.length() * 0.65


static func _try_blink(game, enemy: CharacterBody3D, side: Vector3, preferred: float) -> bool:
	var start := enemy.global_position
	for sign_value: float in [preferred, -preferred]:
		var travel := side * sign_value * 4.5
		if travel.is_zero_approx() or enemy.test_move(enemy.global_transform, travel):
			continue
		var landing := start + travel
		var query := PhysicsRayQueryParameters3D.create(landing + Vector3.UP * 0.55, landing - Vector3.UP * 0.65, LAYER_WORLD)
		var floor_hit := enemy.get_world_3d().direct_space_state.intersect_ray(query)
		if floor_hit.is_empty() or floor_hit.normal.y < 0.7:
			continue
		Visuals.spawn_impact_light(game.level_root, start + Vector3.UP, VIOLET, 2.2, 4.0, 0.22)
		enemy.global_position = floor_hit.position + Vector3.UP * 0.035
		enemy.velocity = Vector3.ZERO
		game._spell_impact(enemy.global_position + Vector3.UP, VIOLET)
		game._sound_at("cast", enemy.global_position, 1.5)
		return true
	return false


static func _hear_noise(game, enemy: CharacterBody3D, rig: Node3D, noise: Dictionary) -> void:
	var heard: Dictionary = enemy.get_meta("heard_noise", {})
	if is_same(heard, noise):
		return
	enemy.set_meta("heard_noise", noise)
	var meshes: Script = Meshes3D
	if is_instance_valid(rig) and meshes.has_method("trigger_sonar_pulse"):
		meshes.call("trigger_sonar_pulse", rig)
	game._sound_at("stalker", enemy.global_position)


static func _cast_volley(game, enemy: CharacterBody3D, angles: Array, spell: String) -> void:
	var origin := enemy.global_position + Vector3.UP * (2.2 if enemy.get_meta("boss", false) else 1.65)
	var target: Vector3 = game.camera.global_position
	for angle: float in angles:
		var direction := (target - origin).normalized().rotated(Vector3.UP, angle)
		var orb: Node3D = game._spell_orb(origin, spell, angles.size() > 1)
		game.enemy_bolts.append({"node": orb, "source": enemy, "direction": direction,
			"life": 4.0, "speed": 11.0, "damage": 18, "homing": false})
	game._sound_at("cast", enemy.global_position, 0.76)


static func _summon_count(enemies: Array) -> int:
	var count := 0
	for ally: CharacterBody3D in enemies:
		if is_instance_valid(ally) and not ally.is_queued_for_deletion() and str(ally.get_meta("id", "")).begins_with("warden_shr_"):
			count += 1
	return count


static func _summon_shriekers(game, warden: CharacterBody3D) -> void:
	var count := _summon_count(game.enemies)
	if count >= 2:
		return
	var serial := int(warden.get_meta("summon_serial", 0))
	var home: Vector3 = (game.level_root as Node3D).to_local(warden.get_meta("home_pos"))
	game._sound_at("bell", warden.global_position)
	while count < 2:
		var side := -1.0 if serial % 2 == 0 else 1.0
		var pos := home + Vector3(side * 5.0, 0.15, -0.8)
		var id := "warden_shr_%d_%d" % [int(game.elapsed * 1000.0), serial]
		game._enemy(pos, false, id, false, "shrieker")
		count += 1
		serial += 1
	warden.set_meta("summon_serial", serial)


static func _animate(game, enemy: CharacterBody3D, player: CharacterBody3D, rig: Node3D, elapsed: float, progress: float, frozen: bool, staggered: bool, glint: float) -> void:
	var movement := _flat(enemy.velocity)
	var speed := movement.length()
	Meshes3D.animate_enemy_rig(rig, elapsed, speed, progress, frozen, staggered, movement, glint)

	var meshes: Script = Meshes3D
	var nearby := enemy.global_position.distance_squared_to(player.global_position) < 14.0 * 14.0
	if enemy.get_meta("kind", "") == "warden" and meshes.has_method("set_warden_aegis"):
		var ratio := float(enemy.get_meta("aegis_hp", 0.0)) / float(enemy.get_meta("aegis_max_hp", CombatSystems.AEGIS_HP))
		meshes.call("set_warden_aegis", rig, ratio, game.wards.size())
	elif not enemy.get_meta("boss", false) and meshes.has_method("update_enemy_bars"):
		var health := float(enemy.get_meta("hp", 1)) / maxf(1.0, float(enemy.get_meta("max_hp", 1)))
		var shield := float(enemy.get_meta("shield_hp", CombatSystems.SHIELD_HP)) / CombatSystems.SHIELD_HP if enemy.get_meta("has_shield", false) else 0.0
		meshes.call("update_enemy_bars", rig, clampf(health, 0.0, 1.0), shield, nearby and (health < 1.0 or shield > 0.0))
	if rig.get_meta("step_triggered", false):
		rig.set_meta("step_triggered", false)
		if nearby and enemy.is_on_floor() and not frozen and not staggered:
			var pitch := lerpf(0.72, 1.2, clampf(speed / 5.0, 0.0, 1.0))
			game._sound_at("step", enemy.global_position, pitch)
			game._spell_trail(enemy.global_position + Vector3.UP * 0.07, Color(0.69, 0.58, 0.43, 0.32), 0.012)


static func _slash(rig: Node3D, color: Color) -> void:
	var meshes: Script = Meshes3D
	if is_instance_valid(rig) and meshes.has_method("trigger_slash_arc"):
		meshes.call("trigger_slash_arc", rig, color)


static func _clear_to_player(game, enemy: CharacterBody3D, player: CharacterBody3D, height: float) -> bool:
	var camera: Camera3D = game.camera
	var target := camera.global_position if is_instance_valid(camera) else player.global_position + Vector3.UP
	return not _ray_blocked(enemy, enemy.global_position + Vector3.UP * height, target)


static func _ray_blocked(enemy: CharacterBody3D, from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, LAYER_WORLD)
	return not enemy.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


static func _tick_timer(enemy: CharacterBody3D, key: StringName, delta: float) -> float:
	var timer := maxf(0.0, float(enemy.get_meta(key, 0.0)) - delta)
	enemy.set_meta(key, timer)
	return timer


static func _strafe_sign(enemy: CharacterBody3D, delta: float) -> float:
	var sign_value: float = enemy.get_meta("strafe_sign", 1.0)
	if _tick_timer(enemy, "strafe_time", delta) <= 0.0:
		sign_value = -sign_value
		enemy.set_meta("strafe_sign", sign_value)
		enemy.set_meta("strafe_time", 1.3 + float(enemy.get_instance_id() % 11) * 0.07)
	return sign_value


static func _face(enemy: CharacterBody3D, direction: Vector3, delta: float) -> void:
	if _flat(direction).length_squared() > 0.0064:
		var yaw := atan2(-direction.x, -direction.z)
		enemy.rotation.y = lerp_angle(enemy.rotation.y, yaw, minf(1.0, delta * 9.0))


static func _flat(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z)
