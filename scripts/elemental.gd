class_name ElementalComponent
extends Node

var frozen_time: float = 0.0
var solid_frozen: bool = false
var burning_time: float = 0.0
var burn_tick_timer: float = 0.0
var frost_immune: bool = false

func is_frozen() -> bool:
	return frozen_time > 0.0

func is_solid_frozen() -> bool:
	return frozen_time > 0.0 and solid_frozen and not frost_immune

func is_burning() -> bool:
	return burning_time > 0.0

func slow_multiplier() -> float:
	if frost_immune:
		return 1.0
	if is_solid_frozen():
		return 0.0
	if is_frozen():
		return 0.5
	return 1.0

func apply_frost(duration: float, low_hp_freeze: bool = false) -> Dictionary:
	var result := {"thermal_shock": false}
	if burning_time > 0.0:
		result.thermal_shock = true
		burning_time = 0.0
		frozen_time = 0.0
		solid_frozen = false
		return result
	var already_chilled := frozen_time > 0.0
	frozen_time = maxf(frozen_time, duration)
	if not frost_immune and (low_hp_freeze or already_chilled):
		solid_frozen = true
	return result

func apply_burn(duration: float) -> Dictionary:
	var result := {"thermal_shock": false}
	if frozen_time > 0.0:
		result.thermal_shock = true
		frozen_time = 0.0
		solid_frozen = false
		burning_time = 0.0
		return result
	burning_time = maxf(burning_time, duration)
	burn_tick_timer = 0.5
	return result

func clear_all() -> void:
	frozen_time = 0.0
	solid_frozen = false
	burning_time = 0.0
	burn_tick_timer = 0.0

func tick(delta: float) -> Dictionary:
	var events := {"burn_tick": false, "thawed": false, "extinguished": false}
	if frozen_time > 0.0:
		frozen_time = maxf(0.0, frozen_time - delta)
		if frozen_time <= 0.0:
			solid_frozen = false
			events.thawed = true
	if burning_time > 0.0:
		burning_time = maxf(0.0, burning_time - delta)
		burn_tick_timer -= delta
		if burn_tick_timer <= 0.0:
			burn_tick_timer = 0.55
			events.burn_tick = true
		if burning_time <= 0.0:
			events.extinguished = true
	return events

func status_tint() -> Color:
	if is_solid_frozen():
		return Color("78f3ff")
	if is_frozen():
		return Color("a8e4f5") if not frost_immune else Color("c7e0eb")
	if is_burning():
		return Color("ff9352")
	return Color.WHITE
