extends Node

@export var debug_enabled: bool = true

#@export var combo_step_delay_long: float = 1.0# ============================================================

# ============================================================
# Global Big Attack Cooldown
# 雷射 / 魚群 / 潮汐 / 特殊彈幕共用節奏
# ============================================================

@export var big_attack_global_cooldown: float = 3.0

# ============================================================
# Individual Cooldowns
# ============================================================

@export var laser_cooldown: float = 11.0
@export var fish_summon_cooldown: float = 10.0
@export var burst_cooldown: float = 5.0
@export var tide_cooldown: float = 12.0
@export var special_bullet_cooldown: float = 7.0

# 潮汐後，其他大招延後一點，避免連續壓死玩家。
@export var tide_big_attack_delay_after_use: float = 3.0

# ============================================================
# Phase 1 Weights
# ============================================================

@export var phase1_toxic_weight: float = 55.0
@export var phase1_burst_weight: float = 30.0
@export var phase1_fish_weight: float = 15.0

# ============================================================
# Phase 2 Weights
# ============================================================

@export var phase2_toxic_weight: float = 35.0
@export var phase2_burst_weight: float = 25.0
@export var phase2_fish_weight: float = 15.0
@export var phase2_laser_weight: float = 10.0
@export var phase2_tide_weight: float = 8.0
@export var phase2_special_weight: float = 15.0

# ============================================================
# Phase 3 With Tentacles
# 有觸手時限制雷射 / 潮汐，避免太亂
# ============================================================

@export var phase3_tentacles_toxic_weight: float = 40.0
@export var phase3_tentacles_burst_weight: float = 25.0
@export var phase3_tentacles_fish_weight: float = 15.0
@export var phase3_tentacles_special_weight: float = 12.0

# ============================================================
# Phase 3 No Tentacles
# 觸手清完後高壓攻擊池
# ============================================================

@export var phase3_toxic_weight: float = 25.0
@export var phase3_burst_weight: float = 20.0
@export var phase3_fish_weight: float = 10.0
@export var phase3_laser_weight: float = 12.0
@export var phase3_tide_weight: float = 10.0
@export var phase3_special_weight: float = 30.0

# ============================================================
# Combo Weights
# ============================================================

# Phase 1 Combo：只用基礎招，但會變成連續壓力。
@export var phase1_combo_toxic_burst_weight: float = 60.0
@export var phase1_combo_fish_toxic_weight: float = 40.0

# Phase 2 Combo：開始用大招組合。
@export var phase2_combo_laser_fish_weight: float = 30.0
@export var phase2_combo_tide_toxic_weight: float = 30.0
@export var phase2_combo_special_burst_weight: float = 40.0

# Phase 3 有觸手：限制雷射/潮汐，但保留特殊壓力。
@export var phase3_tentacles_combo_special_toxic_weight: float = 55.0
@export var phase3_tentacles_combo_fish_burst_weight: float = 45.0

# Phase 3 無觸手：高壓連招。
@export var phase3_combo_special_burst_weight: float = 35.0
@export var phase3_combo_laser_special_weight: float = 30.0
@export var phase3_combo_tide_special_weight: float = 35.0

# ============================================================
# Internal State
# ============================================================

var boss: Node = null

var _attack_timer: float = 0.0
var _is_attacking: bool = false

var _laser_next_allowed_time: float = 0.0
var _fish_next_allowed_time: float = 0.0
var _burst_next_allowed_time: float = 0.0
var _tide_next_allowed_time: float = 0.0
var _special_bullet_next_allowed_time: float = 0.0
var _big_attack_next_allowed_time: float = 0.0
var _combo_next_allowed_time: float = 0.0


# ============================================================
# Setup
# ============================================================

func setup(boss_ref: Node) -> void:
	boss = boss_ref
	_roll_attack_timer()

	if debug_enabled:
		print("Boss2AttackDirector setup complete")


func _roll_attack_timer() -> void:
	_attack_timer = randf_range(attack_interval_min, attack_interval_max)

	if debug_enabled:
		print("AttackDirector next attack timer = ", _attack_timer)


# ============================================================
# Main Process
# Boss2.gd 每幀呼叫
# ============================================================

func process_attack(delta: float) -> void:
	if boss == null or not is_instance_valid(boss):
		return

	if _is_attacking:
		return

	if _boss_is_dead():
		return

	if _boss_is_phase_transitioning():
		return

	if _boss_is_weak():
		return

	_attack_timer -= delta

	if _attack_timer <= 0.0:
		_is_attacking = true

		if debug_enabled:
			print("AttackDirector timer triggered. phase = ", _get_phase())

		if _should_execute_combo():
			await _choose_and_execute_combo()
		else:
			await _choose_and_execute_attack()

		if boss == null or not is_instance_valid(boss):
			return

		if _boss_is_dead():
			return

		_roll_attack_timer()
		_is_attacking = false

		if debug_enabled:
			print("AttackDirector attack finished. next timer = ", _attack_timer)


# ============================================================
# Combo Decision
# ============================================================

func _should_execute_combo() -> bool:
	if not combo_enabled:
		return false

	if _get_now_seconds() < _combo_next_allowed_time:
		return false

	var phase: int = _get_phase()
	var chance: float = phase1_combo_chance

	if phase == 2:
		chance = phase2_combo_chance
	elif phase >= 3:
		chance = phase3_combo_chance

	return randf() < chance


func _register_combo_cooldown() -> void:
	_combo_next_allowed_time = _get_now_seconds() + combo_cooldown

	if debug_enabled:
		print("Combo cooldown started: ", combo_cooldown)


# ============================================================
# Combo Selection
# ============================================================

func _choose_and_execute_combo() -> void:
	var combo_name: String = _roll_combo_name()

	if combo_name.is_empty():
		await _choose_and_execute_attack()
		return

	_register_combo_cooldown()

	if debug_enabled:
		print("AttackDirector executing combo = ", combo_name, " phase = ", _get_phase())

	if combo_name == "toxic_burst":
		await _combo_toxic_burst()
		return

	if combo_name == "fish_toxic":
		await _combo_fish_toxic()
		return

	if combo_name == "laser_fish":
		await _combo_laser_fish()
		return

	if combo_name == "tide_toxic":
		await _combo_tide_toxic()
		return

	if combo_name == "special_burst":
		await _combo_special_burst()
		return

	if combo_name == "special_toxic":
		await _combo_special_toxic()
		return

	if combo_name == "fish_burst":
		await _combo_fish_burst()
		return

	if combo_name == "laser_special":
		await _combo_laser_special()
		return

	if combo_name == "tide_special":
		await _combo_tide_special()
		return

	await _choose_and_execute_attack()


func _roll_combo_name() -> String:
	var phase: int = _get_phase()
	var entries: Array[Dictionary] = []

	if phase <= 1:
		entries.append({
			"name": "toxic_burst",
			"weight": phase1_combo_toxic_burst_weight
		})
		entries.append({
			"name": "fish_toxic",
			"weight": phase1_combo_fish_toxic_weight
		})
		return _roll_from_entries(entries)

	if phase == 2:
		entries.append({
			"name": "laser_fish",
			"weight": phase2_combo_laser_fish_weight
		})
		entries.append({
			"name": "tide_toxic",
			"weight": phase2_combo_tide_toxic_weight
		})
		entries.append({
			"name": "special_burst",
			"weight": phase2_combo_special_burst_weight
		})
		return _roll_from_entries(entries)

	if _boss_has_active_tentacles():
		entries.append({
			"name": "special_toxic",
			"weight": phase3_tentacles_combo_special_toxic_weight
		})
		entries.append({
			"name": "fish_burst",
			"weight": phase3_tentacles_combo_fish_burst_weight
		})
		return _roll_from_entries(entries)

	entries.append({
		"name": "special_burst",
		"weight": phase3_combo_special_burst_weight
	})
	entries.append({
		"name": "laser_special",
		"weight": phase3_combo_laser_special_weight
	})
	entries.append({
		"name": "tide_special",
		"weight": phase3_combo_tide_special_weight
	})

	return _roll_from_entries(entries)


# ============================================================
# Combo Implementations
# ============================================================

func _combo_toxic_burst() -> void:
	await _force_toxic()
	await _wait_combo(combo_step_delay_medium)
	await _force_burst()


func _combo_fish_toxic() -> void:
	if _can_use_fish_summon():
		_register_fish_cooldown()
		_call_boss_attack("_summon_fish_group")

	await _wait_combo(combo_step_delay_medium)
	await _force_toxic()


func _combo_laser_fish() -> void:
	if _can_use_laser():
		_register_laser_cooldown()
		await _call_boss_attack_async("_attack_laser")

	await _wait_combo(combo_step_delay_short)

	if _can_use_fish_summon():
		_register_fish_cooldown()
		_call_boss_attack("_summon_fish_group")
	else:
		await _force_toxic()


func _combo_tide_toxic() -> void:
	if _can_use_tide():
		_register_tide_cooldown()
		await _call_boss_attack_async("_attack_tide")

	await _wait_combo(combo_step_delay_short)
	await _force_toxic()


func _combo_special_burst() -> void:
	if _can_use_special_bullet():
		_register_special_bullet_cooldown()
		await _execute_special_bullet()

	await _wait_combo(combo_step_delay_medium)
	await _force_burst()


func _combo_special_toxic() -> void:
	if _can_use_special_bullet():
		_register_special_bullet_cooldown()
		await _execute_special_bullet()

	await _wait_combo(combo_step_delay_short)
	await _force_toxic()


func _combo_fish_burst() -> void:
	if _can_use_fish_summon():
		_register_fish_cooldown()
		_call_boss_attack("_summon_fish_group")

	await _wait_combo(combo_step_delay_medium)
	await _force_burst()


func _combo_laser_special() -> void:
	if _can_use_laser():
		_register_laser_cooldown()
		await _call_boss_attack_async("_attack_laser")

	await _wait_combo(combo_step_delay_short)

	if _can_use_special_bullet():
		_register_special_bullet_cooldown()
		await _execute_special_bullet()
	else:
		await _force_toxic()


func _combo_tide_special() -> void:
	if _can_use_tide():
		_register_tide_cooldown()
		await _call_boss_attack_async("_attack_tide")

	await _wait_combo(combo_step_delay_short)

	if _can_use_special_bullet():
		_register_special_bullet_cooldown()
		await _execute_special_bullet()
	else:
		await _force_toxic()


func _force_toxic() -> void:
	await _call_boss_attack_async("_shoot_boss_toxic_barrage")


func _force_burst() -> void:
	if _can_use_burst():
		_register_burst_cooldown()
		await _call_boss_attack_async("_shoot_burst_bullet")
	else:
		await _force_toxic()


func _wait_combo(seconds: float) -> void:
	if seconds <= 0.0:
		return

	if boss == null or not is_instance_valid(boss):
		return

	var tree := get_tree()

	if tree == null:
		return

	await tree.create_timer(seconds).timeout


# ============================================================
# Normal Attack Selection
# ============================================================

func _choose_and_execute_attack() -> void:
	var attempts: int = 0

	while attempts < attack_reroll_max_attempts:
		attempts += 1

		var attack_name: String = _roll_attack_name()

		if debug_enabled:
			print("AttackDirector rolled attack = ", attack_name, " phase = ", _get_phase(), " attempt = ", attempts)

		if attack_name == "laser":
			if _can_use_laser():
				_register_laser_cooldown()
				await _call_boss_attack_async("_attack_laser")
				return

			continue

		if attack_name == "fish":
			if _can_use_fish_summon():
				_register_fish_cooldown()
				_call_boss_attack("_summon_fish_group")
				return

			continue

		if attack_name == "burst":
			if _can_use_burst():
				_register_burst_cooldown()
				await _call_boss_attack_async("_shoot_burst_bullet")
				return

			continue

		if attack_name == "tide":
			if _can_use_tide():
				_register_tide_cooldown()
				await _call_boss_attack_async("_attack_tide")
				return

			continue

		if attack_name == "special_bullet":
			if _can_use_special_bullet():
				_register_special_bullet_cooldown()
				await _execute_special_bullet()
				return

			continue

		if attack_name == "toxic":
			await _call_boss_attack_async("_shoot_boss_toxic_barrage")
			return

	await _call_boss_attack_async("_shoot_boss_toxic_barrage")


func _roll_attack_name() -> String:
	var phase: int = _get_phase()
	var entries: Array[Dictionary] = []

	if phase <= 1:
		entries.append({"name": "toxic", "weight": phase1_toxic_weight})
		entries.append({"name": "burst", "weight": phase1_burst_weight})
		entries.append({"name": "fish", "weight": phase1_fish_weight})
		return _roll_from_entries(entries)

	if phase == 2:
		entries.append({"name": "toxic", "weight": phase2_toxic_weight})
		entries.append({"name": "burst", "weight": phase2_burst_weight})
		entries.append({"name": "fish", "weight": phase2_fish_weight})
		entries.append({"name": "laser", "weight": phase2_laser_weight})
		entries.append({"name": "tide", "weight": phase2_tide_weight})
		entries.append({"name": "special_bullet", "weight": phase2_special_weight})
		return _roll_from_entries(entries)

	if _boss_has_active_tentacles():
		entries.append({"name": "toxic", "weight": phase3_tentacles_toxic_weight})
		entries.append({"name": "burst", "weight": phase3_tentacles_burst_weight})
		entries.append({"name": "fish", "weight": phase3_tentacles_fish_weight})
		entries.append({"name": "special_bullet", "weight": phase3_tentacles_special_weight})
		return _roll_from_entries(entries)

	entries.append({"name": "toxic", "weight": phase3_toxic_weight})
	entries.append({"name": "burst", "weight": phase3_burst_weight})
	entries.append({"name": "fish", "weight": phase3_fish_weight})
	entries.append({"name": "laser", "weight": phase3_laser_weight})
	entries.append({"name": "tide", "weight": phase3_tide_weight})
	entries.append({"name": "special_bullet", "weight": phase3_special_weight})

	return _roll_from_entries(entries)


func _roll_from_entries(entries: Array[Dictionary]) -> String:
	var total_weight: float = 0.0

	for entry in entries:
		total_weight += float(entry["weight"])

	if total_weight <= 0.0:
		return "toxic"

	var roll: float = randf() * total_weight
	var current: float = 0.0

	for entry in entries:
		current += float(entry["weight"])

		if roll <= current:
			return String(entry["name"])

	return "toxic"


# ============================================================
# Cooldowns
# ============================================================

func _get_now_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


func _can_use_big_attack() -> bool:
	return _get_now_seconds() >= _big_attack_next_allowed_time


func _register_big_attack_cooldown() -> void:
	_big_attack_next_allowed_time = _get_now_seconds() + big_attack_global_cooldown

	if debug_enabled:
		print("Big attack global cooldown started: ", big_attack_global_cooldown)


func _can_use_laser() -> bool:
	if not _can_use_big_attack():
		return false

	if _get_phase() >= 3 and _boss_has_active_tentacles():
		return false

	return _get_now_seconds() >= _laser_next_allowed_time


func _register_laser_cooldown() -> void:
	_laser_next_allowed_time = _get_now_seconds() + laser_cooldown
	_register_big_attack_cooldown()

	if debug_enabled:
		print("Laser cooldown started: ", laser_cooldown)


func _can_use_fish_summon() -> bool:
	if not _can_use_big_attack():
		return false

	return _get_now_seconds() >= _fish_next_allowed_time


func _register_fish_cooldown() -> void:
	_fish_next_allowed_time = _get_now_seconds() + fish_summon_cooldown
	_register_big_attack_cooldown()

	if debug_enabled:
		print("Fish cooldown started: ", fish_summon_cooldown)


func _can_use_burst() -> bool:
	return _get_now_seconds() >= _burst_next_allowed_time


func _register_burst_cooldown() -> void:
	_burst_next_allowed_time = _get_now_seconds() + burst_cooldown

	if debug_enabled:
		print("Burst cooldown started: ", burst_cooldown)


func _can_use_tide() -> bool:
	if _get_phase() <= 1:
		return false

	if not _can_use_big_attack():
		return false

	if _get_phase() >= 3 and _boss_has_active_tentacles():
		return false

	return _get_now_seconds() >= _tide_next_allowed_time


func _register_tide_cooldown() -> void:
	var now: float = _get_now_seconds()

	_tide_next_allowed_time = now + tide_cooldown

	_burst_next_allowed_time = max(
		_burst_next_allowed_time,
		now + tide_big_attack_delay_after_use
	)

	_fish_next_allowed_time = max(
		_fish_next_allowed_time,
		now + tide_big_attack_delay_after_use
	)

	_laser_next_allowed_time = max(
		_laser_next_allowed_time,
		now + tide_big_attack_delay_after_use
	)

	_special_bullet_next_allowed_time = max(
		_special_bullet_next_allowed_time,
		now + tide_big_attack_delay_after_use
	)

	_register_big_attack_cooldown()

	if debug_enabled:
		print("Tide cooldown started: ", tide_cooldown)
		print("Delayed big attacks after tide by: ", tide_big_attack_delay_after_use)


func _can_use_special_bullet() -> bool:
	if _get_phase() <= 1:
		return false

	if not _can_use_big_attack():
		return false

	return _get_now_seconds() >= _special_bullet_next_allowed_time


func _register_special_bullet_cooldown() -> void:
	_special_bullet_next_allowed_time = _get_now_seconds() + special_bullet_cooldown
	_register_big_attack_cooldown()

	if debug_enabled:
		print("Special bullet cooldown started: ", special_bullet_cooldown)


# ============================================================
# Special Bullet
# ============================================================

func _execute_special_bullet() -> void:
	if boss == null or not is_instance_valid(boss):
		return

	var special_node: Node = null

	if boss.has_method("get_special_bullet_patterns"):
		special_node = boss.get_special_bullet_patterns()
	else:
		special_node = boss.get_node_or_null("Boss2SpecialBulletPatterns")

	if special_node == null:
		if debug_enabled:
			print("Special bullet node not found")
		return

	if special_node.has_method("execute_random_pattern"):
		await special_node.execute_random_pattern()


# ============================================================
# Boss Call Helpers
# ============================================================

func _call_boss_attack(method_name: String) -> void:
	if boss == null or not is_instance_valid(boss):
		return

	if boss.has_method(method_name):
		boss.call(method_name)
	else:
		if debug_enabled:
			print("Boss missing method: ", method_name)


func _call_boss_attack_async(method_name: String) -> void:
	if boss == null or not is_instance_valid(boss):
		return

	if boss.has_method(method_name):
		await boss.call(method_name)
	else:
		if debug_enabled:
			print("Boss missing async method: ", method_name)


# ============================================================
# Boss State Helpers
# ============================================================

func _get_phase() -> int:
	if boss == null or not is_instance_valid(boss):
		return 1

	if boss.has_method("get_current_phase"):
		return int(boss.get_current_phase())

	if boss.has_method("get_hp_ratio"):
		var hp_ratio: float = boss.get_hp_ratio()

		if hp_ratio > 0.75:
			return 1

		if hp_ratio > 0.5:
			return 2

		return 3

	return 1


func _boss_has_active_tentacles() -> bool:
	if boss == null or not is_instance_valid(boss):
		return false

	if boss.has_method("has_active_tentacles"):
		return bool(boss.has_active_tentacles())

	return false


func _boss_is_weak() -> bool:
	if boss == null or not is_instance_valid(boss):
		return false

	if boss.has_method("is_weak"):
		return bool(boss.is_weak())

	return false


func _boss_is_dead() -> bool:
	if boss == null or not is_instance_valid(boss):
		return true

	if "hp" in boss:
		if int(boss.get("hp")) <= 0:
			return true

	if "_is_dead" in boss:
		return bool(boss.get("_is_dead"))

	return false


func _boss_is_phase_transitioning() -> bool:
	if boss == null or not is_instance_valid(boss):
		return false

	if "_is_phase_transitioning" in boss:
		return bool(boss.get("_is_phase_transitioning"))

	return false
# Attack Interval
# ============================================================

@export var attack_interval_min: float = 2.2
@export var attack_interval_max: float = 3.2
@export var attack_reroll_max_attempts: int = 8

# ============================================================
# Combo Settings
# ============================================================

@export var combo_enabled: bool = true

# Combo 整體機率。越高越常出連招。
@export var phase1_combo_chance: float = 0.12
@export var phase2_combo_chance: float = 0.25
@export var phase3_combo_chance: float = 0.35

# Combo 自己的冷卻，避免連續 combo 太頻繁。
@export var combo_cooldown: float = 7.0

# Combo 內部招式之間的間隔。
@export var combo_step_delay_short: float = 0.45
@export var combo_step_delay_medium: float = 0.75
