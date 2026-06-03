extends CharacterBody2D

signal died

@export var max_hp: int = 720
@export var phase1_tentacle_damage_to_boss: int = 48
@export var phase2_tentacle_damage_to_boss: int = 12
@export var phase2_direct_damage_multiplier: float = 0.35
@export var weak_duration: float = 2.5
@export var debug_enabled: bool = true

@export var toxic_bullet_scene: PackedScene
@export var boss_attack_interval_min: float = 2.4
@export var boss_attack_interval_max: float = 4.0

@export var phase1_bullet_count: int = 3
@export var phase2_bullet_count: int = 4
@export var phase3_bullet_count: int = 4

@export var phase1_spread_degrees: float = 30.0
@export var phase2_spread_degrees: float = 55.0
@export var phase3_spread_degrees: float = 70.0

@export var burst_bullet_scene: PackedScene
@export var fish_scene: PackedScene
@export var explode_fish_scene: PackedScene
@export var fish_spawn_count_min: int = 1
@export var fish_spawn_count_max: int = 3
@export var fish_spawn_radius: float = 260.0

@export var max_normal_fish: int = 2
@export var max_explode_fish: int = 2

@export var laser_warning_scene: PackedScene
@export var laser_range: float = 420.0
@export var laser_angle_degrees: float = 90.0
@export var laser_prepare_time: float = 0.8
@export var phase2_laser_damage: int = 14
@export var phase3_laser_damage: int = 18

@export var toxic_charge_time: float = 0.8
@export var burst_charge_time: float = 0.8
@export var laser_charge_time: float = 0.8

@export var normal_texture: Texture2D
@export var toxic_attack_texture: Texture2D
@export var burst_attack_texture: Texture2D
@export var laser_attack_texture: Texture2D

@export var target_visual_height: float = 220.0

@export var normal_texture_scale_multiplier: float = 1.0
@export var toxic_texture_scale_multiplier: float = 1.0
@export var burst_texture_scale_multiplier: float = 1.0
@export var laser_texture_scale_multiplier: float = 1.0

@export var normal_texture_offset: Vector2 = Vector2.ZERO
@export var toxic_texture_offset: Vector2 = Vector2.ZERO
@export var burst_texture_offset: Vector2 = Vector2.ZERO
@export var laser_texture_offset: Vector2 = Vector2.ZERO

# 攻擊權重。Phase 2/3 實際約：毒液45%、爆裂25%、魚群18%、雷射12%。
# Phase 1 不會抽雷射，所以會在毒液/爆裂/魚群之間按權重重算。
@export var toxic_attack_weight: float = 40.0
@export var burst_attack_weight: float = 25.0
@export var fish_attack_weight: float = 15.0
@export var laser_attack_weight: float = 5.0
@export var tide_attack_weight: float = 15.0
@export var special_bullet_attack_weight: float = 15.0
@export var special_bullet_cooldown: float = 8.0

# 大招冷卻：依你的要求，各自比前一版短 1 秒。
@export var laser_cooldown: float = 11.0
@export var fish_summon_cooldown: float = 10.0
@export var burst_cooldown: float = 5.0
@export var attack_reroll_max_attempts: int = 8

@onready var body_sprite: Sprite2D = get_node_or_null("BodySprite") as Sprite2D

@export var tide_cooldown: float = 12.0

@export var tide_prepare_time: float = 0.9
@export var tide_duration: float = 2.0

@export var pull_force: float = 4000
@export var push_force: float = 420.0

@export var tide_affects_bubbles: bool = true
@export var tide_recovery_time: float = 3.0
@export var tide_big_attack_delay_after_use: float = 3.0
@export var bubble_tide_force_multiplier: float = 0.55

@export var debug_space_damage_enabled: bool = true
@export var debug_space_damage_amount: int = 80
@export var debug_space_damage_cooldown: float = 0.25

@export var phase2_weak_duration: float = 2.5
@export var phase3_weak_duration: float = 8.5

@export var weak_bullet_interval: float = 0.55
@export var weak_bullet_count: int = 4
@export var weak_bullet_spread_degrees: float = 1
@onready var special_bullet_patterns: Node = get_node_or_null("Boss2SpecialBulletPatterns")
@onready var weak_attack: Node = get_node_or_null("Boss2WeakAttack")

@warning_ignore("unused_private_class_variable")
var _debug_space_damage_timer: float = 0.0
var hp: int
var _is_weak: bool = false
var _is_dead: bool = false
var _is_attacking: bool = false
var _is_phase_transitioning: bool = false

var _room_controller: Node = null
var player: Node2D = null
var _attack_timer: float = 0.0
var _current_phase: int = 1

var _laser_next_allowed_time: float = 0.0
var _fish_next_allowed_time: float = 0.0
var _burst_next_allowed_time: float = 0.0
var _tide_next_allowed_time: float = 0.0
var _special_bullet_next_allowed_time: float = 0.0


func _ready() -> void:
	hp = max_hp
	find_player()
	_roll_attack_timer()
	_show_normal_texture()

	if weak_attack != null and weak_attack.has_method("setup"):
		weak_attack.setup(self)
	else:
		if debug_enabled:
			print("Boss2WeakAttack 不存在，或沒有 setup() 方法")

	if special_bullet_patterns != null and special_bullet_patterns.has_method("setup"):
		special_bullet_patterns.setup(self)
	else:
		if debug_enabled:
			print("Boss2SpecialBulletPatterns 不存在，或沒有 setup() 方法")

	if debug_enabled:
		print("Boss2 ready, HP = ", hp)
		

func _physics_process(delta: float) -> void:
	if _debug_space_damage_timer > 0.0:
		_debug_space_damage_timer -= delta

	if debug_enabled and debug_space_damage_enabled:
		if Input.is_key_pressed(KEY_SPACE) and _debug_space_damage_timer <= 0.0:
			_debug_space_damage_timer = debug_space_damage_cooldown
			_debug_space_damage_boss()

	if _is_dead:
		return

	if hp <= 0:
		return

	if player == null or not is_instance_valid(player):
		find_player()
		return

	_check_phase_transition()

	if _is_phase_transitioning:
		return

	if _is_weak:
		return

	if _is_attacking:
		return

	_attack_timer -= delta

	if _attack_timer <= 0.0:
		_is_attacking = true

		await _choose_and_execute_attack()

		if _is_dead:
			return

		if not is_inside_tree():
			return

		_roll_attack_timer()
		_is_attacking = false


func set_room_controller(room: Node) -> void:
	_room_controller = room

	if debug_enabled:
		print("Boss2 已接收 BossRoom2 控制器")


func find_player() -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")

	if players.size() > 0:
		player = players[0] as Node2D


func _roll_attack_timer() -> void:
	_attack_timer = randf_range(boss_attack_interval_min, boss_attack_interval_max)


# ============================================================
# Texture Control
# ============================================================

func _set_boss_texture_advanced(texture: Texture2D, scale_multiplier: float, texture_offset: Vector2) -> void:
	if body_sprite == null:
		return

	if texture == null:
		return

	body_sprite.texture = texture
	body_sprite.centered = true

	var texture_size: Vector2 = texture.get_size()

	if texture_size.y <= 0.0:
		return

	var scale_value: float = target_visual_height / texture_size.y
	body_sprite.scale = Vector2(scale_value, scale_value) * scale_multiplier
	body_sprite.position = texture_offset


func _show_normal_texture() -> void:
	_set_boss_texture_advanced(
		normal_texture,
		normal_texture_scale_multiplier,
		normal_texture_offset
	)


func _show_toxic_attack_texture() -> void:
	_set_boss_texture_advanced(
		toxic_attack_texture,
		toxic_texture_scale_multiplier,
		toxic_texture_offset
	)


func _show_burst_attack_texture() -> void:
	_set_boss_texture_advanced(
		burst_attack_texture,
		burst_texture_scale_multiplier,
		burst_texture_offset
	)


func _show_laser_attack_texture() -> void:
	_set_boss_texture_advanced(
		laser_attack_texture,
		laser_texture_scale_multiplier,
		laser_texture_offset
	)


# ============================================================
# Phase
# ============================================================

func get_hp_ratio() -> float:
	if max_hp <= 0:
		return 0.0

	return float(hp) / float(max_hp)


func get_current_phase() -> int:
	var hp_ratio: float = get_hp_ratio()

	if hp_ratio > 0.75:
		return 1

	if hp_ratio > 0.5:
		return 2

	return 3


func _check_phase_transition() -> void:
	if _is_phase_transitioning:
		return

	var new_phase: int = get_current_phase()

	if new_phase == _current_phase:
		return

	_current_phase = new_phase

	if new_phase == 2:
		_start_phase2_transition()
	elif new_phase == 3:
		_start_phase3_transition()


func _start_phase2_transition() -> void:
	_is_phase_transitioning = true
	_show_normal_texture()

	if debug_enabled:
		print("Boss2 phase 2 transition")

	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(0.5, 1.0, 0.6), 0.15)
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0), 0.15)
	tween.set_loops(3)

	var wait_completed: bool = await _safe_wait(0.9)

	if not wait_completed:
		return

	if _is_dead:
		return

	modulate = Color(1.0, 1.0, 1.0)
	_is_phase_transitioning = false


func _start_phase3_transition() -> void:
	_is_phase_transitioning = true
	_show_normal_texture()

	if debug_enabled:
		print("Boss2 phase 3 transition")

	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 0.2, 0.2), 0.12)
	tween.tween_property(self, "modulate", Color(0.5, 0.0, 0.0), 0.12)
	tween.set_loops(5)

	var wait_completed: bool = await _safe_wait(1.2)

	if not wait_completed:
		return

	if _is_dead:
		return

	modulate = Color(1.0, 1.0, 1.0)

	if _room_controller != null:
		if _room_controller.has_method("get_active_tentacle_count"):
			if int(_room_controller.get_active_tentacle_count()) <= 0:
				if _room_controller.has_method("_spawn_phase3_tentacle_wave"):
					_room_controller._spawn_phase3_tentacle_wave()

	_is_phase_transitioning = false


func is_weak() -> bool:
	return _is_weak


# ============================================================
# Attack Selection
# ============================================================

func _choose_and_execute_attack() -> void:
	var attempts: int = 0

	while attempts < attack_reroll_max_attempts:
		attempts += 1

		var attack_name: String = _roll_attack_name()

		if attack_name == "laser":
			if _can_use_laser():
				_register_laser_cooldown()
				await _attack_laser()
				return

			continue

		if attack_name == "fish":
			if _can_use_fish_summon():
				_register_fish_cooldown()
				_summon_fish_group()
				return

			continue

		if attack_name == "burst":
			if _can_use_burst():
				_register_burst_cooldown()
				await _shoot_burst_bullet()
				return

			continue

		if attack_name == "tide":
			if _can_use_tide():
				_register_tide_cooldown()
				await _attack_tide()
				return

			continue

		if attack_name == "special_bullet":
			if _can_use_special_bullet():
				_register_special_bullet_cooldown()

				if special_bullet_patterns != null:
					if special_bullet_patterns.has_method("execute_random_pattern"):
						await special_bullet_patterns.execute_random_pattern()

				return

			continue

		if attack_name == "toxic":
			await _shoot_boss_toxic_barrage()
			return

	await _shoot_boss_toxic_barrage()


func _roll_attack_name() -> String:
	var hp_ratio: float = get_hp_ratio()
	var entries: Array[Dictionary] = []

	# Phase 2 / Phase 3 才加入雷射、潮汐、特殊彈幕。
	if hp_ratio <= 0.75:
		entries.append({
			"name": "laser",
			"weight": laser_attack_weight
		})

		entries.append({
			"name": "tide",
			"weight": tide_attack_weight
		})

		entries.append({
			"name": "special_bullet",
			"weight": special_bullet_attack_weight
		})

	entries.append({
		"name": "fish",
		"weight": fish_attack_weight
	})

	entries.append({
		"name": "burst",
		"weight": burst_attack_weight
	})

	entries.append({
		"name": "toxic",
		"weight": toxic_attack_weight
	})

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


func _get_now_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


func _can_use_laser() -> bool:
	return _get_now_seconds() >= _laser_next_allowed_time

func _can_use_special_bullet() -> bool:
	if get_hp_ratio() > 0.75:
		return false

	if special_bullet_patterns == null:
		return false

	return _get_now_seconds() >= _special_bullet_next_allowed_time


func _register_special_bullet_cooldown() -> void:
	_special_bullet_next_allowed_time = _get_now_seconds() + special_bullet_cooldown

	if debug_enabled:
		print("Boss2 special bullet cooldown started: ", special_bullet_cooldown)
		
func _register_laser_cooldown() -> void:
	_laser_next_allowed_time = _get_now_seconds() + laser_cooldown

	if debug_enabled:
		print("Boss2 laser cooldown started: ", laser_cooldown)


func _can_use_fish_summon() -> bool:
	return _get_now_seconds() >= _fish_next_allowed_time


func _register_fish_cooldown() -> void:
	_fish_next_allowed_time = _get_now_seconds() + fish_summon_cooldown

	if debug_enabled:
		print("Boss2 fish cooldown started: ", fish_summon_cooldown)


func _can_use_burst() -> bool:
	return _get_now_seconds() >= _burst_next_allowed_time


func _register_burst_cooldown() -> void:
	_burst_next_allowed_time = _get_now_seconds() + burst_cooldown

	if debug_enabled:
		print("Boss2 burst cooldown started: ", burst_cooldown)


# ============================================================
# Boss Attacks
# ============================================================

func _shoot_boss_toxic_barrage() -> void:
	if toxic_bullet_scene == null:
		if debug_enabled:
			print("Boss2 toxic_bullet_scene not assigned")
		return

	if player == null or not is_instance_valid(player):
		return

	_show_toxic_attack_texture()
	var wait_completed: bool = await _safe_wait(toxic_charge_time)

	if not wait_completed:
		return

	_show_normal_texture()

	if _is_dead:
		return

	var hp_ratio: float = get_hp_ratio()
	var bullet_count: int = phase1_bullet_count
	var spread_degrees: float = phase1_spread_degrees

	if hp_ratio <= 0.5:
		bullet_count = phase3_bullet_count
		spread_degrees = phase3_spread_degrees
	elif hp_ratio <= 0.75:
		bullet_count = phase2_bullet_count
		spread_degrees = phase2_spread_degrees

	var base_dir: Vector2 = player.global_position - global_position

	if base_dir.length_squared() <= 0.0001:
		base_dir = Vector2.RIGHT

	base_dir = base_dir.normalized()

	if bullet_count <= 1:
		_spawn_boss_toxic_bullet(base_dir)
		return

	var spread_rad: float = deg_to_rad(spread_degrees)
	var start_angle: float = -spread_rad / 2.0
	var angle_step: float = spread_rad / float(bullet_count - 1)

	for i in range(bullet_count):
		var angle_offset: float = start_angle + angle_step * i
		var fire_dir: Vector2 = base_dir.rotated(angle_offset)
		_spawn_boss_toxic_bullet(fire_dir)

	if debug_enabled:
		print("Boss2 shoot toxic barrage count = ", bullet_count)


func _spawn_boss_toxic_bullet(fire_dir: Vector2) -> void:
	if toxic_bullet_scene == null:
		return

	var spawn_parent: Node = _get_spawn_parent()

	if spawn_parent == null:
		return

	var bullet: Node = toxic_bullet_scene.instantiate()
	spawn_parent.add_child(bullet)

	if bullet.has_method("setup"):
		bullet.setup(global_position, fire_dir.normalized())


func _shoot_burst_bullet() -> void:
	if burst_bullet_scene == null:
		if debug_enabled:
			print("Boss2 burst_bullet_scene not assigned")
		return

	if player == null or not is_instance_valid(player):
		return

	_show_burst_attack_texture()
	var wait_completed: bool = await _safe_wait(burst_charge_time)

	if not wait_completed:
		return

	_show_normal_texture()

	if _is_dead:
		return

	var dir: Vector2 = player.global_position - global_position

	if dir.length_squared() <= 0.0001:
		dir = Vector2.RIGHT

	var spawn_parent: Node = _get_spawn_parent()

	if spawn_parent == null:
		return

	var bullet: Node = burst_bullet_scene.instantiate()
	spawn_parent.add_child(bullet)

	if bullet.has_method("setup"):
		bullet.setup(global_position, dir.normalized())

	if debug_enabled:
		print("Boss2 shoot burst bullet")


func _attack_laser() -> void:
	if player == null or not is_instance_valid(player):
		return

	_show_laser_attack_texture()
	var charge_completed: bool = await _safe_wait(laser_charge_time)

	if not charge_completed:
		return

	_show_normal_texture()

	if _is_dead:
		return

	var laser_dir: Vector2 = player.global_position - global_position

	if laser_dir.length_squared() <= 0.0001:
		laser_dir = Vector2.RIGHT

	laser_dir = laser_dir.normalized()

	if laser_warning_scene != null:
		var spawn_parent: Node = _get_spawn_parent()

		if spawn_parent != null:
			var warning: Node = laser_warning_scene.instantiate()
			spawn_parent.add_child(warning)

			if warning.has_method("setup"):
				warning.setup(
					global_position,
					laser_dir,
					laser_range,
					laser_angle_degrees,
					laser_prepare_time
				)
	else:
		if debug_enabled:
			print("Boss2 laser_warning_scene not assigned")

	if debug_enabled:
		print("Boss2 preparing 90 degree laser")

	var prepare_completed: bool = await _safe_wait(laser_prepare_time)

	if not prepare_completed:
		return

	if _is_dead:
		return

	_deal_laser_damage(laser_dir)


func _deal_laser_damage(laser_dir: Vector2) -> void:
	if player == null or not is_instance_valid(player):
		return

	var to_player: Vector2 = player.global_position - global_position
	var distance: float = to_player.length()

	if distance > laser_range:
		if debug_enabled:
			print("Boss2 laser missed: player out of range")
		return

	if to_player.length_squared() <= 0.0001:
		return

	var angle_to_player: float = abs(laser_dir.angle_to(to_player.normalized()))
	var half_angle: float = deg_to_rad(laser_angle_degrees) * 0.5

	if angle_to_player > half_angle:
		if debug_enabled:
			print("Boss2 laser missed: player out of angle")
		return

	var damage: int = phase2_laser_damage

	if get_hp_ratio() <= 0.5:
		damage = phase3_laser_damage

	if player.has_method("take_damage"):
		player.take_damage(float(damage))

	if debug_enabled:
		print("Boss2 laser hit player, damage = ", damage)


# ============================================================
# Fish Summon
# ============================================================

func _get_alive_group_count(group_name: String) -> int:
	var count: int = 0

	for node in get_tree().get_nodes_in_group(group_name):
		if node != null and is_instance_valid(node):
			count += 1

	return count


func _summon_fish_group() -> void:
	var normal_count: int = _get_alive_group_count("normal_fish")
	var explode_count: int = _get_alive_group_count("explode_fish")
	var spawn_count: int = randi_range(fish_spawn_count_min, fish_spawn_count_max)
	var actually_spawned: int = 0

	for i in range(spawn_count):
		var use_explode_fish: bool = randf() < 0.35
		var scene_to_use: PackedScene = null

		if use_explode_fish:
			if explode_count >= max_explode_fish:
				continue

			if explode_fish_scene == null:
				continue

			scene_to_use = explode_fish_scene
			explode_count += 1
		else:
			if normal_count >= max_normal_fish:
				continue

			if fish_scene == null:
				continue

			scene_to_use = fish_scene
			normal_count += 1

		var spawn_parent: Node = _get_spawn_parent()

		if spawn_parent == null:
			continue

		var fish: Node = scene_to_use.instantiate()
		spawn_parent.add_child(fish)

		if fish.has_method("set_boss_ref"):
			fish.set_boss_ref(self)

		if fish is Node2D:
			(fish as Node2D).global_position = _get_fish_spawn_position()

		actually_spawned += 1

	if debug_enabled:
		print("Boss2 summon fish group count = ", actually_spawned)


func _get_fish_spawn_position() -> Vector2:
	var fallback_pos: Vector2 = global_position + Vector2.RIGHT.rotated(randf() * TAU) * fish_spawn_radius

	if _room_controller == null:
		return fallback_pos

	if not _room_controller.has_method("get_fish_spawn_rect"):
		return fallback_pos

	var rect: Rect2 = _room_controller.get_fish_spawn_rect()

	for attempt in range(40):
		var angle: float = randf() * TAU
		var distance: float = randf_range(fish_spawn_radius * 0.35, fish_spawn_radius)
		var candidate: Vector2 = global_position + Vector2.RIGHT.rotated(angle) * distance

		if rect.has_point(candidate):
			return candidate

	return Vector2(
		randf_range(rect.position.x, rect.position.x + rect.size.x),
		randf_range(rect.position.y, rect.position.y + rect.size.y)
	)
# ============================================================
# Damage / Tentacle System
# ============================================================

func on_tentacle_destroyed(pos: Vector2) -> void:
	if _is_dead:
		return

	var hp_ratio: float = get_hp_ratio()

	if debug_enabled:
		print("觸手被打掉，位置 = ", pos)

	if hp_ratio > 0.75:
		_apply_tentacle_damage(phase1_tentacle_damage_to_boss)

		if debug_enabled:
			print("Phase 1：觸手死亡造成 Boss 傷害 = ", phase1_tentacle_damage_to_boss)

		return

	if hp_ratio > 0.5:
		_apply_tentacle_damage(phase2_tentacle_damage_to_boss)

		if _is_dead:
			return

		enter_weak_state()

		if debug_enabled:
			print("Phase 2：觸手死亡造成少量傷害 = ", phase2_tentacle_damage_to_boss, "，並觸發虛弱")

		return

	if debug_enabled:
		print("Phase 3：觸手死亡不直接傷害 Boss，清完觸手後才能攻擊本體")


func on_tentacle_removed(remaining_count: int) -> void:
	if debug_enabled:
		print("剩餘觸手數量 = ", remaining_count)

	var hp_ratio: float = get_hp_ratio()

	if hp_ratio <= 0.5 and remaining_count <= 0:
		if debug_enabled:
			print("Phase 3：觸手全清，Boss 進入虛弱可傷害狀態")

		enter_weak_state()


func take_damage(amount: int) -> void:
	if _is_dead:
		return

	var hp_ratio: float = get_hp_ratio()

	if hp_ratio > 0.75:
		if debug_enabled:
			print("Phase 1：Boss 本體無敵，請打觸手")
		return

	if hp_ratio > 0.5:
		if _is_weak:
			if debug_enabled:
				print("Phase 2：Boss 虛弱中，承受完整傷害 = ", amount)

			_apply_damage(amount)
		else:
			var reduced_damage: int = max(1, int(float(amount) * phase2_direct_damage_multiplier))

			if debug_enabled:
				print("Phase 2：Boss 減傷，原傷害 = ", amount, " 實際傷害 = ", reduced_damage)

			_apply_damage(reduced_damage)

		return

	if _has_active_tentacles():
		if debug_enabled:
			print("Phase 3：場上還有觸手，Boss 本體無敵")
		return

	if not _is_weak:
		if debug_enabled:
			print("Phase 3：觸手已清完，但 Boss 尚未進入虛弱，暫時無法傷害")
		return

	if debug_enabled:
		print("Phase 3：Boss 虛弱中，承受傷害 = ", amount)

	_apply_damage(amount)


func _apply_tentacle_damage(amount: int) -> void:
	_apply_damage(amount)


func _apply_damage(amount: int) -> void:
	if _is_dead:
		return

	hp -= amount
	hp = max(hp, 0)

	if debug_enabled:
		print("Boss2 HP = ", hp, " / ", max_hp)

	if hp <= 0:
		die()


func _has_active_tentacles() -> bool:
	if _room_controller == null:
		return false

	if not _room_controller.has_method("get_active_tentacle_count"):
		return false

	return int(_room_controller.get_active_tentacle_count()) > 0


func enter_weak_state() -> void:
	if _is_dead:
		return

	if _is_weak:
		return

	if not is_inside_tree():
		return

	_is_weak = true
	_show_normal_texture()

	var duration: float = phase2_weak_duration

	if get_hp_ratio() <= 0.5:
		duration = phase3_weak_duration

	if debug_enabled:
		print("Boss2 進入虛弱狀態，duration = ", duration)

	modulate = Color(1.0, 0.45, 0.45)

	if get_hp_ratio() <= 0.5:
		if weak_attack != null and weak_attack.has_method("start"):
			weak_attack.start()

	var wait_completed: bool = await _safe_wait(duration)

	if weak_attack != null and weak_attack.has_method("stop"):
		weak_attack.stop()

	if not wait_completed:
		return

	if _is_dead:
		return

	modulate = Color(1.0, 1.0, 1.0)
	_is_weak = false

	if debug_enabled:
		print("Boss2 虛弱結束")


func die() -> void:
	if _is_dead:
		return

	_is_dead = true
	_is_weak = false
	_show_normal_texture()

	if debug_enabled:
		print("Boss2 死了")

	died.emit()

	queue_free()


# ============================================================
# Helper
# ============================================================

func _get_spawn_parent() -> Node:
	var tree := get_tree()

	if tree == null:
		return null

	if tree.current_scene != null:
		return tree.current_scene

	return tree.root


func _safe_wait(seconds: float) -> bool:
	if not is_inside_tree():
		return false

	var tree := get_tree()

	if tree == null:
		return false

	await tree.create_timer(seconds).timeout

	if not is_instance_valid(self):
		return false

	if not is_inside_tree():
		return false

	return true


func _can_use_tide() -> bool:
	if get_hp_ratio() > 0.75:
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

	if debug_enabled:
		print("Boss2 tide cooldown started: ", tide_cooldown)
		print("Boss2 delayed big attacks after tide by: ", tide_big_attack_delay_after_use)

		
func _attack_tide() -> void:
	if player == null or not is_instance_valid(player):
		return

	var use_pull: bool = true

	# Phase 2：只吸引
	# Phase 3：吸引 / 推人各 50%
	if get_hp_ratio() <= 0.5:
		use_pull = randf() < 0.5

	if debug_enabled:
		if use_pull:
			print("Boss2 preparing pull tide")
		else:
			print("Boss2 preparing push tide")

	var original_modulate: Color = modulate

	if use_pull:
		# 吸引：藍色
		modulate = Color(0.35, 0.75, 1.0, 1.0)
	else:
		# 推人：橘紅色
		modulate = Color(1.0, 0.35, 0.2, 1.0)

	var wait_completed: bool = await _safe_wait(tide_prepare_time)

	if not wait_completed:
		modulate = original_modulate
		return

	if _is_dead:
		modulate = original_modulate
		return

	set_meta("tide_active", true)

	if use_pull:
		await _apply_tide_pull()
	else:
		await _apply_tide_push()

	set_meta("tide_active", false)

	modulate = original_modulate

	if debug_enabled:
		print("Boss2 tide finished, recovery started")

	var recovery_completed: bool = await _safe_wait(tide_recovery_time)

	if not recovery_completed:
		return

	if debug_enabled:
		print("Boss2 tide recovery finished")
		
		
func _apply_tide_push() -> void:
	var elapsed: float = 0.0

	if debug_enabled:
		print("Boss2 push tide started")

	while elapsed < tide_duration:
		var delta: float = get_physics_process_delta_time()
		elapsed += delta

		if player == null or not is_instance_valid(player):
			return

		var dir: Vector2 = player.global_position - global_position

		if dir.length_squared() > 0.0001:
			player.global_position += dir.normalized() * push_force * delta

		if tide_affects_bubbles:
			_apply_tide_to_bubbles(false, delta)

		await get_tree().physics_frame


func _apply_tide_to_bubbles(is_pull: bool, delta: float) -> void:
	for bubble in get_tree().get_nodes_in_group("boss2_bubble"):
		if bubble == null or not is_instance_valid(bubble):
			continue

		if not bubble is Node2D:
			continue

		var bubble_node := bubble as Node2D
		var dir: Vector2

		if is_pull:
			dir = global_position - bubble_node.global_position
		else:
			dir = bubble_node.global_position - global_position

		if dir.length_squared() <= 0.0001:
			continue

		var force: float = pull_force

		if not is_pull:
			force = push_force

		bubble_node.global_position += dir.normalized() * force * bubble_tide_force_multiplier * delta


func _apply_tide_pull() -> void:
	var elapsed: float = 0.0

	if debug_enabled:
		print("Boss2 pull tide started")

	while elapsed < tide_duration:
		var delta: float = get_physics_process_delta_time()
		elapsed += delta

		if player == null or not is_instance_valid(player):
			return

		var dir: Vector2 = global_position - player.global_position

		if dir.length_squared() > 0.0001:
			player.global_position += dir.normalized() * pull_force * delta

		if tide_affects_bubbles:
			_apply_tide_to_bubbles(true, delta)

		await get_tree().physics_frame


func _debug_space_damage_boss() -> void:
	if _is_dead:
		return

	if debug_enabled:
		print("DEBUG：Space 對 Boss 造成傷害 = ", debug_space_damage_amount)

	_apply_damage(debug_space_damage_amount)
