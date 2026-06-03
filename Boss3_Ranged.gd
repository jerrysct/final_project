extends CharacterBody2D

enum State {
	IDLE,
	ATTACK,
	RECOVER,
	DEAD,
}


enum AttackType {
	BURST,
	FAN,
	CHARGE_SHOT,
	HEAL_MELEE,
	BUFF_MELEE,
	SPIRAL,
	PINCER,
	BULLET_WALL,
	LINE_CRUSH,
	WALL_SWEEP,
}

const SPRITE_COLOR_NORMAL: Color = Color(1, 1, 1)
const SPRITE_COLOR_CHARGE: Color = Color(1.0, 0.45, 0.25)
const SPRITE_COLOR_HEAL: Color = Color(0.35, 1.0, 0.45)
const SPRITE_COLOR_SPIRAL: Color = Color(1.0, 0.75, 0.25)
const SPRITE_COLOR_PINCER: Color = Color(0.8, 0.45, 1.0)
const SPRITE_COLOR_WALL: Color = Color(0.55, 0.9, 1.0)
const SPRITE_COLOR_LINE_CRUSH: Color = Color(1.0, 0.35, 0.35)
const SPRITE_COLOR_WALL_SWEEP: Color = Color(1.0, 0.15, 0.15)

const MOUTH_OPEN_FRAME: int = 3 # 嘴巴張開的動畫幀數，可根據實際動畫調整

@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D

@export var max_hp: int = 200

@export var attack_cooldown_min: float = 1.2
@export var attack_cooldown_max: float = 2.4
@export var recover_time: float = 0.7

# --- 瞬移設定 ---
@export var teleport_interval_min: float = 5.0
@export var teleport_interval_max: float = 8.0
@export var teleport_range_x: float = 520.0
@export var teleport_range_y: float = 300.0
@export var teleport_margin: float = 80.0
@export var teleport_effect_time: float = 0.15

@export var bullet_scene: PackedScene
@export var debug_enabled: bool = false

@export var burst_count_min: int = 2
@export var burst_count_max: int = 4
@export var burst_interval: float = 0.18

@export var fan_bullet_count: int = 5
@export var fan_spread_degrees: float = 45.0

@export var charge_prepare_time: float = 0.65


# --- 新彈幕：螺旋連射 ---
@export var spiral_bullet_count: int = 22
@export var spiral_interval: float = 0.075
@export var spiral_angle_step_degrees: float = 24.0

# --- 新彈幕：夾擊彈幕 ---
@export var pincer_bullet_count: int = 9
@export var pincer_angle_degrees: float = 32.0
@export var pincer_interval: float = 0.14

# --- 新彈幕：慢速子彈牆 ---
@export var wall_bullet_count: int = 9
@export var wall_gap_index: int = -1
@export var wall_spacing: float = 42.0
@export var wall_repeat: int = 1
@export var wall_repeat_interval: float = 0.55
@export var wall_bullet_speed: float = 120.0

# --- 新彈幕：雙線夾擊 ---
@export var line_crush_rows: int = 5
@export var line_crush_spacing: float = 42.0
@export var line_crush_side_distance: float = 280.0
@export var line_crush_speed: float = 180.0
@export var line_crush_lifetime: float = 1.6
@export var line_crush_repeat: int = 2
@export var line_crush_repeat_interval: float = 0.45

# --- 二階段殺招：四面牆掃射 ---
@export var wall_sweep_bullet_count: int = 7
@export var wall_sweep_spacing: float = 95.0
@export var wall_sweep_left: float = -520.0
@export var wall_sweep_right: float = 520.0
@export var wall_sweep_top: float = -300.0
@export var wall_sweep_bottom: float = 300.0
@export var wall_sweep_speed: float = 190.0
@export var wall_sweep_lifetime: float = 6.0
@export var wall_sweep_cooldown: float = 8.0
@export var phase2_wall_sweep_delay: float = 0.35

@export var melee_boss_path: NodePath
@export var heal_amount: int = 25
@export var heal_chance: float = 0.25
@export var heal_prepare_time: float = 0.8
@export var heal_cooldown: float = 5.0
@export var link_scene: PackedScene

var _link_instance: Node = null

var hp: int
var state: State = State.IDLE
var player: Node2D = null

var _attack_cooldown_left: float = 0.0
var _home_position: Vector2 = Vector2.ZERO
var _has_home_position: bool = false
var _state_time: float = 0.0
var _is_attacking: bool = false

var _teleport_timer: float = 0.0
var _is_teleporting: bool = false

var _last_attack: AttackType = AttackType.BURST
var _same_attack_count: int = 0

var _heal_cooldown_left: float = 0.0
var _wall_sweep_cooldown_left: float = 0.0
var _phase2_opening_wall_sweep_used: bool = false

var _is_enraged: bool = false

var _base_attack_cooldown_min: float
var _base_attack_cooldown_max: float
var _base_burst_count_min: int
var _base_burst_count_max: int
var _base_fan_bullet_count: int
var _base_charge_prepare_time: float

var _base_spiral_bullet_count: int
var _base_pincer_bullet_count: int
var _base_wall_bullet_count: int
var _base_wall_repeat: int
var _base_wall_bullet_speed: float
var _base_line_crush_rows: int
var _base_line_crush_repeat: int
var _base_line_crush_speed: float


func _ready() -> void:
	hp = max_hp

	_base_attack_cooldown_min = attack_cooldown_min
	_base_attack_cooldown_max = attack_cooldown_max
	_base_burst_count_min = burst_count_min
	_base_burst_count_max = burst_count_max
	_base_fan_bullet_count = fan_bullet_count
	_base_charge_prepare_time = charge_prepare_time

	_base_spiral_bullet_count = spiral_bullet_count
	_base_pincer_bullet_count = pincer_bullet_count
	_base_wall_bullet_count = wall_bullet_count
	_base_wall_repeat = wall_repeat
	_base_wall_bullet_speed = wall_bullet_speed
	_base_line_crush_rows = line_crush_rows
	_base_line_crush_repeat = line_crush_repeat
	_base_line_crush_speed = line_crush_speed

	find_player()
	_roll_attack_cooldown()
	_roll_teleport_timer()
	
	if _anim:
		_anim.play("idle")
		_anim.animation_finished.connect(_on_animation_finished)
		# 確保攻擊動畫不循環，以便能夠觸發 animation_finished 或手動控制
		if _anim.sprite_frames.has_animation("attack"):
			_anim.sprite_frames.set_animation_loop("attack", false)


func _on_animation_finished() -> void:
	if _anim.animation == "attack":
		_anim.play("idle")
	elif _anim.animation == "death":
		queue_free()


func enter_enraged_mode() -> void:
	if _is_enraged:
		return

	_is_enraged = true

	attack_cooldown_min *= 0.6
	attack_cooldown_max *= 0.6

	burst_count_min += 1
	burst_count_max += 1
	fan_bullet_count += 1

	spiral_bullet_count += 5
	pincer_bullet_count += 3
	wall_bullet_count += 1
	wall_bullet_speed += 15.0
	line_crush_rows += 1
	line_crush_repeat += 1
	line_crush_speed += 20.0

	charge_prepare_time *= 0.7

	modulate = Color(1, 0.3, 0.3)

	print("Boss3_Ranged 狂暴了🔥")

	if not _phase2_opening_wall_sweep_used:
		_phase2_opening_wall_sweep_used = true
		call_deferred("_start_phase2_opening_wall_sweep")


func set_home_position(pos: Vector2) -> void:
	_home_position = pos
	_has_home_position = true
	global_position = _home_position


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	if _has_home_position:
		global_position = _home_position

	velocity = Vector2.ZERO
	move_and_slide()

	if _has_home_position:
		global_position = _home_position

	if _heal_cooldown_left > 0.0:
		_heal_cooldown_left -= delta

	if _wall_sweep_cooldown_left > 0.0:
		_wall_sweep_cooldown_left -= delta

	_update_teleport(delta)

	if player == null or not is_instance_valid(player):
		find_player()
		return

	_face_player()

	match state:
		State.IDLE:
			_update_idle(delta)
		State.ATTACK:
			pass
		State.RECOVER:
			_update_recover(delta)


func _update_idle(delta: float) -> void:
	_attack_cooldown_left -= delta

	if _attack_cooldown_left <= 0.0 and not _is_attacking:
		var attack_type: AttackType = _choose_attack()
		_start_attack(attack_type)


func _update_recover(delta: float) -> void:
	_state_time += delta

	if _state_time >= recover_time:
		state = State.IDLE
		_state_time = 0.0
		_roll_attack_cooldown()

		if debug_enabled:
			print("Boss3_Ranged -> IDLE")


func _start_attack(attack_type: AttackType) -> void:
	if state == State.DEAD:
		return

	state = State.ATTACK
	_is_attacking = true

	if debug_enabled:
		print("Boss3_Ranged attack = ", _attack_type_to_string(attack_type))

	call_deferred("_run_attack", attack_type)


func _run_attack(attack_type: AttackType) -> void:
	match attack_type:
		AttackType.BURST:
			await _attack_burst()
		AttackType.FAN:
			await _attack_fan()
		AttackType.CHARGE_SHOT:
			await _attack_charge_shot()
		AttackType.HEAL_MELEE:
			await _attack_heal_melee()
		AttackType.BUFF_MELEE:
			await _attack_buff_melee()
		AttackType.SPIRAL:
			await _attack_spiral()
		AttackType.PINCER:
			await _attack_pincer()
		AttackType.BULLET_WALL:
			await _attack_bullet_wall()
		AttackType.LINE_CRUSH:
			await _attack_line_crush()
		AttackType.WALL_SWEEP:
			_attack_wall_sweep()

	if state == State.DEAD:
		return

	_is_attacking = false
	state = State.RECOVER
	_state_time = 0.0
	_set_sprite_modulate(SPRITE_COLOR_NORMAL)

	if debug_enabled:
		print("Boss3_Ranged -> RECOVER")



func _start_phase2_opening_wall_sweep() -> void:
	if state == State.DEAD:
		return

	await get_tree().create_timer(phase2_wall_sweep_delay).timeout

	if state == State.DEAD:
		return

	# 二階段一開始強制施放一次 WALL_SWEEP，不等隨機選招。
	_wall_sweep_cooldown_left = 0.0
	state = State.ATTACK
	_is_attacking = true

	_attack_wall_sweep()

	if state == State.DEAD:
		return

	_is_attacking = false
	state = State.RECOVER
	_state_time = 0.0
	_set_sprite_modulate(SPRITE_COLOR_NORMAL)


func _attack_burst() -> void:
	await _wait_for_mouth_open()
	_pause_animation() # 連發時保持嘴巴張開

	var count: int = randi_range(burst_count_min, burst_count_max)

	for i in range(count):
		if state == State.DEAD:
			_resume_animation()
			return

		var dir: Vector2 = _get_direction_to_player()
		_spawn_bullet(dir)

		await get_tree().create_timer(burst_interval).timeout

	_resume_animation() # 結束後恢復動畫以便關嘴


func _attack_fan() -> void:
	await _wait_for_mouth_open()
	var base_dir: Vector2 = _get_direction_to_player()

	if fan_bullet_count <= 1:
		_spawn_bullet(base_dir)
		return

	var spread_rad: float = deg_to_rad(fan_spread_degrees)
	var start_angle: float = -spread_rad / 2.0
	var angle_step: float = spread_rad / float(fan_bullet_count - 1)

	for i in range(fan_bullet_count):
		var angle_offset: float = start_angle + angle_step * float(i)
		var dir: Vector2 = base_dir.rotated(angle_offset)
		_spawn_bullet(dir)


func _attack_charge_shot() -> void:
	_set_sprite_modulate(SPRITE_COLOR_CHARGE)

	var locked_dir: Vector2 = _get_direction_to_player()

	await get_tree().create_timer(charge_prepare_time).timeout

	if state == State.DEAD:
		return

	await _wait_for_mouth_open()
	_set_sprite_modulate(SPRITE_COLOR_NORMAL)
	_spawn_bullet(locked_dir)


func _attack_spiral() -> void:
	_set_sprite_modulate(SPRITE_COLOR_SPIRAL)
	await _wait_for_mouth_open()
	_pause_animation()

	var base_dir: Vector2 = _get_direction_to_player()
	var base_angle: float = base_dir.angle()

	for i in range(spiral_bullet_count):
		if state == State.DEAD:
			_resume_animation()
			return

		var angle_offset: float = deg_to_rad(spiral_angle_step_degrees) * float(i)
		var dir: Vector2 = Vector2.RIGHT.rotated(base_angle + angle_offset)

		_spawn_bullet(dir)

		await get_tree().create_timer(spiral_interval).timeout

	_resume_animation()


func _attack_pincer() -> void:
	_set_sprite_modulate(SPRITE_COLOR_PINCER)
	await _wait_for_mouth_open()
	_pause_animation()

	var base_dir: Vector2 = _get_direction_to_player()
	var angle_rad: float = deg_to_rad(pincer_angle_degrees)

	for i in range(pincer_bullet_count):
		if state == State.DEAD:
			_resume_animation()
			return

		var left_dir: Vector2 = base_dir.rotated(-angle_rad)
		var right_dir: Vector2 = base_dir.rotated(angle_rad)

		_spawn_bullet(left_dir)
		_spawn_bullet(right_dir)

		await get_tree().create_timer(pincer_interval).timeout

	_resume_animation()



func _attack_bullet_wall() -> void:
	_set_sprite_modulate(SPRITE_COLOR_WALL)
	await _wait_for_mouth_open()
	_pause_animation()

	for repeat_index in range(wall_repeat):
		if state == State.DEAD:
			_resume_animation()
			return

		var forward_dir: Vector2 = _get_direction_to_player()

		if forward_dir.length_squared() <= 0.0001:
			forward_dir = Vector2.RIGHT

		var side_dir: Vector2 = forward_dir.rotated(PI / 2.0)
		var spawn_center: Vector2 = _get_spawn_position()

		var gap_index: int = wall_gap_index

		if gap_index < 0 or gap_index >= wall_bullet_count:
			gap_index = randi_range(2, wall_bullet_count - 3)

		var half_count: float = float(wall_bullet_count - 1) / 2.0

		for i in range(wall_bullet_count):
			if i == gap_index:
				continue

			var offset: float = (float(i) - half_count) * wall_spacing
			var spawn_pos: Vector2 = spawn_center + side_dir * offset

			_spawn_bullet_with_speed(spawn_pos, forward_dir, wall_bullet_speed)

		if repeat_index < wall_repeat - 1:
			await get_tree().create_timer(wall_repeat_interval).timeout

	_resume_animation()
	_set_sprite_modulate(SPRITE_COLOR_NORMAL)



func _attack_line_crush() -> void:
	_set_sprite_modulate(SPRITE_COLOR_LINE_CRUSH)

	if player == null or not is_instance_valid(player):
		find_player()

	if player == null or not is_instance_valid(player):
		_set_sprite_modulate(SPRITE_COLOR_NORMAL)
		return

	await _wait_for_mouth_open()
	_pause_animation()

	for repeat_index in range(line_crush_repeat):
		if state == State.DEAD:
			_resume_animation()
			return

		var center_pos: Vector2 = player.global_position

		var left_start_x: float = center_pos.x - line_crush_side_distance
		var right_start_x: float = center_pos.x + line_crush_side_distance

		var half_rows: float = float(line_crush_rows - 1) / 2.0

		for i in range(line_crush_rows):
			var y_offset: float = (float(i) - half_rows) * line_crush_spacing

			var left_pos: Vector2 = Vector2(left_start_x, center_pos.y + y_offset)
			var right_pos: Vector2 = Vector2(right_start_x, center_pos.y + y_offset)

			_spawn_line_crush_bullet(left_pos, Vector2.RIGHT)
			_spawn_line_crush_bullet(right_pos, Vector2.LEFT)
		if repeat_index < line_crush_repeat - 1:
			await get_tree().create_timer(line_crush_repeat_interval).timeout

	_resume_animation()
	_set_sprite_modulate(SPRITE_COLOR_NORMAL)



func _attack_wall_sweep() -> void:
	if not _is_enraged:
		return

	if _wall_sweep_cooldown_left > 0.0:
		return

	_set_sprite_modulate(SPRITE_COLOR_WALL_SWEEP)
	if _anim: _anim.play("attack")

	_wall_sweep_cooldown_left = wall_sweep_cooldown

	var center_pos: Vector2 = Vector2.ZERO
	var half_count: float = float(wall_sweep_bullet_count - 1) / 2.0

	for i in range(wall_sweep_bullet_count):
		if state == State.DEAD:
			return

		var offset: float = (float(i) - half_count) * wall_sweep_spacing

		var top_pos: Vector2 = Vector2(center_pos.x + offset, wall_sweep_top)
		var bottom_pos: Vector2 = Vector2(center_pos.x + offset, wall_sweep_bottom)
		var left_pos: Vector2 = Vector2(wall_sweep_left, center_pos.y + offset)
		var right_pos: Vector2 = Vector2(wall_sweep_right, center_pos.y + offset)

		_spawn_wall_sweep_bullet(top_pos, Vector2.DOWN)
		_spawn_wall_sweep_bullet(bottom_pos, Vector2.UP)
		_spawn_wall_sweep_bullet(left_pos, Vector2.RIGHT)
		_spawn_wall_sweep_bullet(right_pos, Vector2.LEFT)

	_set_sprite_modulate(SPRITE_COLOR_NORMAL)


func _attack_buff_melee() -> void:
	print("BUFF_MELEE 開始執行")

	_set_sprite_modulate(Color(0.3, 0.5, 1.0))
	if _anim: _anim.play("attack")

	await get_tree().create_timer(0.5).timeout

	var melee_boss: Node = get_node_or_null(melee_boss_path)

	if melee_boss == null:
		print("BUFF_MELEE 失敗：找不到 melee_boss")
		_set_sprite_modulate(SPRITE_COLOR_NORMAL)
		return

	print("BUFF_MELEE 找到近戰王：", melee_boss.name)

	if link_scene == null:
		print("BUFF_MELEE 警告：link_scene 沒有指定")
	else:
		print("BUFF_MELEE 正在生成連線")
		_link_instance = link_scene.instantiate()
		get_tree().current_scene.add_child(_link_instance)

		if _link_instance.has_method("setup"):
			_link_instance.setup(self, melee_boss)

	if melee_boss.has_method("apply_buff"):
		melee_boss.apply_buff(4.0)
		print("BUFF_MELEE 已套用 apply_buff")

	await get_tree().create_timer(4.0).timeout

	if _link_instance != null and is_instance_valid(_link_instance):
		_link_instance.queue_free()

	_link_instance = null
	_set_sprite_modulate(SPRITE_COLOR_NORMAL)


func _attack_heal_melee() -> void:
	_set_sprite_modulate(SPRITE_COLOR_HEAL)
	if _anim: _anim.play("attack")

	await get_tree().create_timer(heal_prepare_time).timeout

	if state == State.DEAD:
		return

	var melee_boss: Node = get_node_or_null(melee_boss_path)

	if melee_boss == null:
		if debug_enabled:
			print("Boss3_Ranged: melee_boss_path not assigned")
		_set_sprite_modulate(SPRITE_COLOR_NORMAL)
		return

	if not melee_boss.has_method("heal"):
		if debug_enabled:
			print("Boss3_Ranged: target has no heal method")
		_set_sprite_modulate(SPRITE_COLOR_NORMAL)
		return

	melee_boss.heal(heal_amount)
	_heal_cooldown_left = heal_cooldown

	if debug_enabled:
		print("Boss3_Ranged healed melee boss: ", heal_amount)

	_set_sprite_modulate(SPRITE_COLOR_NORMAL)


func _wait_for_mouth_open() -> void:
	if not _anim: return
	if _anim.animation != "attack":
		_anim.play("attack")
	
	# 等待直到動畫播放到張嘴的那一幀
	while _anim.animation == "attack" and _anim.frame < MOUTH_OPEN_FRAME:
		await _anim.frame_changed

func _pause_animation() -> void:
	if _anim: _anim.pause()

func _resume_animation() -> void:
	if _anim: _anim.play()


func _spawn_bullet(direction: Vector2) -> void:
	if bullet_scene == null:
		if debug_enabled:
			print("Boss3_Ranged ERROR: bullet_scene 尚未指定")
		return

	var bullet: Node = bullet_scene.instantiate()

	if bullet == null:
		if debug_enabled:
			print("Boss3_Ranged ERROR: bullet instantiate failed")
		return

	get_tree().current_scene.add_child(bullet)

	var spawn_pos: Vector2 = _get_spawn_position()

	if debug_enabled:
		print("Boss3_Ranged spawn bullet at = ", spawn_pos, " dir = ", direction)

	if bullet.has_method("setup"):
		bullet.setup(spawn_pos, direction.normalized())
	else:
		if bullet is Node2D:
			(bullet as Node2D).global_position = spawn_pos

		bullet.set("direction", direction.normalized())



func _spawn_bullet_with_speed(spawn_position: Vector2, direction: Vector2, custom_speed: float) -> void:
	if bullet_scene == null:
		if debug_enabled:
			print("Boss3_Ranged ERROR: bullet_scene 尚未指定")
		return

	var bullet: Node = bullet_scene.instantiate()

	if bullet == null:
		return

	get_tree().current_scene.add_child(bullet)

	if bullet.has_method("setup"):
		bullet.setup(spawn_position, direction.normalized())
	else:
		if bullet is Node2D:
			(bullet as Node2D).global_position = spawn_position

		bullet.set("direction", direction.normalized())

	bullet.set("speed", custom_speed)



func _spawn_line_crush_bullet(spawn_position: Vector2, direction: Vector2) -> void:
	if bullet_scene == null:
		if debug_enabled:
			print("Boss3_Ranged ERROR: bullet_scene 尚未指定")
		return

	var bullet: Node = bullet_scene.instantiate()

	if bullet == null:
		return

	get_tree().current_scene.add_child(bullet)

	if bullet.has_method("setup"):
		bullet.setup(spawn_position, direction.normalized())
	else:
		if bullet is Node2D:
			(bullet as Node2D).global_position = spawn_position

		bullet.set("direction", direction.normalized())

	bullet.set("speed", line_crush_speed)
	bullet.set("lifetime", line_crush_lifetime)



func _spawn_wall_sweep_bullet(spawn_position: Vector2, direction: Vector2) -> void:
	if bullet_scene == null:
		if debug_enabled:
			print("Boss3_Ranged ERROR: bullet_scene 尚未指定")
		return

	var bullet: Node = bullet_scene.instantiate()

	if bullet == null:
		return

	get_tree().current_scene.add_child(bullet)

	if bullet.has_method("setup"):
		bullet.setup(spawn_position, direction.normalized())
	else:
		if bullet is Node2D:
			(bullet as Node2D).global_position = spawn_position

		bullet.set("direction", direction.normalized())

	bullet.set("speed", wall_sweep_speed)
	bullet.set("lifetime", wall_sweep_lifetime)


func _get_spawn_position() -> Vector2:
	var spawn_point: Node = get_node_or_null("BulletSpawnPoint")

	if spawn_point is Node2D:
		return (spawn_point as Node2D).global_position

	return global_position


func _get_direction_to_player() -> Vector2:
	if player != null and is_instance_valid(player):
		var dir: Vector2 = player.global_position - _get_spawn_position()

		if dir.length_squared() > 0.0001:
			return dir.normalized()

	return Vector2.RIGHT


func _choose_attack() -> AttackType:
	if _can_heal_melee() and randf() <= heal_chance:
		_last_attack = AttackType.HEAL_MELEE
		_same_attack_count = 0
		return AttackType.HEAL_MELEE

	var choices: Array[AttackType] = []

	if _is_enraged:
		choices = [
			AttackType.FAN,
			AttackType.CHARGE_SHOT,
			AttackType.PINCER,
			AttackType.BULLET_WALL,
			AttackType.LINE_CRUSH,
			AttackType.WALL_SWEEP,
		]
	else:
		choices = [
			AttackType.BURST,
			AttackType.FAN,
			AttackType.CHARGE_SHOT,
			AttackType.SPIRAL,
			AttackType.PINCER,
			AttackType.BULLET_WALL,
			AttackType.LINE_CRUSH,
			AttackType.LINE_CRUSH,
		]

	var chosen: AttackType = choices[randi_range(0, choices.size() - 1)]

	if chosen == AttackType.WALL_SWEEP and _wall_sweep_cooldown_left > 0.0:
		chosen = AttackType.LINE_CRUSH

	if chosen == _last_attack:
		_same_attack_count += 1
	else:
		_same_attack_count = 0

	if _same_attack_count >= 2:
		while chosen == _last_attack:
			chosen = choices[randi_range(0, choices.size() - 1)]

			if chosen == AttackType.WALL_SWEEP and _wall_sweep_cooldown_left > 0.0:
				chosen = AttackType.LINE_CRUSH

		_same_attack_count = 0

	_last_attack = chosen
	return chosen

func _can_heal_melee() -> bool:
	if _heal_cooldown_left > 0.0:
		return false

	var melee_boss: Node = get_node_or_null(melee_boss_path)

	if melee_boss == null:
		return false

	if not melee_boss.has_method("heal"):
		return false

	var current_hp = melee_boss.get("hp")
	var current_max_hp = melee_boss.get("max_hp")

	if current_hp == null or current_max_hp == null:
		return true

	return int(current_hp) < int(current_max_hp)



func _update_teleport(delta: float) -> void:
	if state == State.DEAD:
		return

	if _is_attacking:
		return

	if _is_teleporting:
		return

	_teleport_timer -= delta

	if _teleport_timer <= 0.0:
		_start_teleport()


func _start_teleport() -> void:
	if _is_teleporting:
		return

	_is_teleporting = true
	call_deferred("_do_teleport")


func _do_teleport() -> void:
	_set_sprite_modulate(Color(0.5, 0.8, 1.0, 0.5))

	await get_tree().create_timer(teleport_effect_time).timeout

	if state == State.DEAD:
		return

	var new_pos: Vector2 = _get_random_teleport_position()

	_home_position = new_pos
	_has_home_position = true
	global_position = new_pos

	_set_sprite_modulate(SPRITE_COLOR_NORMAL)

	_is_teleporting = false
	_roll_teleport_timer()

	if debug_enabled:
		print("Boss3_Ranged teleport to: ", new_pos)


func _get_random_teleport_position() -> Vector2:
	var min_x: float = -teleport_range_x + teleport_margin
	var max_x: float = teleport_range_x - teleport_margin
	var min_y: float = -teleport_range_y + teleport_margin
	var max_y: float = teleport_range_y - teleport_margin

	var random_x: float = randf_range(min_x, max_x)
	var random_y: float = randf_range(min_y, max_y)

	return Vector2(random_x, random_y)


func _roll_teleport_timer() -> void:
	_teleport_timer = randf_range(teleport_interval_min, teleport_interval_max)


func _roll_attack_cooldown() -> void:
	_attack_cooldown_left = randf_range(attack_cooldown_min, attack_cooldown_max)


func _face_player() -> void:
	if _anim == null:
		return

	if player == null or not is_instance_valid(player):
		return

	var player_is_left: bool = player.global_position.x < global_position.x
	_anim.flip_h = player_is_left


func _set_sprite_modulate(color: Color) -> void:
	if _anim != null:
		_anim.modulate = color


func find_player() -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")

	if players.size() > 0:
		player = players[0] as Node2D

		if debug_enabled:
			print("Boss3_Ranged found player: ", player.name)
	else:
		if debug_enabled:
			print("Boss3_Ranged cannot find player")


func take_damage(amount: int) -> void:
	if state == State.DEAD:
		return

	hp -= amount

	if debug_enabled:
		print("Boss3_Ranged HP: ", hp)

	if hp <= 0:
		state = State.DEAD
		die()


func die() -> void:
	if debug_enabled:
		print("Boss3_Ranged dead")
	
	if _anim:
		_anim.play("death")
		var col = get_node_or_null("CollisionShape2D")
		if col:
			col.set_deferred("disabled", true)
	else:
		queue_free()


func _attack_type_to_string(attack_type: AttackType) -> String:
	match attack_type:
		AttackType.BURST:
			return "BURST"
		AttackType.FAN:
			return "FAN"
		AttackType.CHARGE_SHOT:
			return "CHARGE_SHOT"
		AttackType.HEAL_MELEE:
			return "HEAL_MELEE"
		AttackType.BUFF_MELEE:
			return "BUFF_MELEE"
		AttackType.SPIRAL:
			return "SPIRAL"
		AttackType.PINCER:
			return "PINCER"
		AttackType.BULLET_WALL:
			return "BULLET_WALL"
		AttackType.LINE_CRUSH:
			return "LINE_CRUSH"
		AttackType.WALL_SWEEP:
			return "WALL_SWEEP"
		_:
			return "UNKNOWN"
