extends CharacterBody2D

enum BulletColor {
	RED,
	BLUE,
	GREEN,
	YELLOW
}

enum BossState {
	IDLE,
	ATTACK,
	STUN,
	DEAD
}

enum AttackPattern {
	NORMAL,
	PHANTOM,
	PRISM,
	SLOW
}
@onready var health_bar: ProgressBar = $HealthBar
@export var max_hp: int = 1000
@export var normal_damage: int = 30
@export var sequence_damage: int = 200
@export var heal_amount: int = 80

@export var bullet_scene: PackedScene
@export var prism_field_scene: PackedScene

@export var fire_interval: float = 0.8
@export var phase_two_fire_interval: float = 0.55
@export var stun_time: float = 2.0

@export var sequence_length: int = 3

@export var normal_pattern_time: float = 5.0
@export var phantom_pattern_time: float = 5.0
@export var prism_pattern_time: float = 6.0
@export var slow_pattern_time: float = 4.0
@export var pattern_break_time: float = 1.0

@export var phantom_chance: float = 0.3
@export var phase_two_phantom_chance: float = 0.5

@export var slow_bullet_chance: float = 0.2
@export var phase_two_slow_bullet_chance: float = 0.35

@export var move_speed: float = 55.0
@export var move_range_x: float = 220.0
@export var move_range_y: float = 120.0
@export var arrive_distance: float = 10.0

@export var prism_spawn_range_x: float = 260.0
@export var prism_spawn_range_y: float = 140.0
@export var prism_lifetime: float = 5.0

@onready var fire_timer: Timer = $FireTimer
@onready var stun_timer: Timer = $StunTimer
@onready var bullet_spawn_point: Marker2D = $BulletSpawnPoint
@onready var sequence_ui: Node = $SequenceUI

var hp: int
var state: BossState = BossState.IDLE

var target_sequence: Array[int] = []
var player_sequence_index: int = 0

var is_phase_two: bool = false
var color_reversed: bool = false

var start_position: Vector2
var target_position: Vector2

var current_pattern: AttackPattern = AttackPattern.NORMAL
var skill_loop_running: bool = false


func _ready() -> void:
	hp = max_hp
	health_bar.setup(max_hp)
	randomize()

	start_position = global_position
	choose_new_target_position()

	generate_sequence()
	update_sequence_ui()

	fire_timer.wait_time = fire_interval
	fire_timer.timeout.connect(_on_fire_timer_timeout)
	stun_timer.timeout.connect(_on_stun_timer_timeout)

	change_state(BossState.ATTACK)
	start_skill_loop()


func _physics_process(delta: float) -> void:
	if state == BossState.DEAD:
		return

	if state == BossState.STUN:
		return

	move_boss(delta)


func change_state(new_state: BossState) -> void:
	state = new_state

	match state:
		BossState.IDLE:
			fire_timer.stop()

		BossState.ATTACK:
			fire_timer.start()

		BossState.STUN:
			fire_timer.stop()
			stun_timer.start(stun_time)

		BossState.DEAD:
			fire_timer.stop()
			stun_timer.stop()
			skill_loop_running = false
			print("Boss 死亡")
			queue_free()


func start_skill_loop() -> void:
	if skill_loop_running:
		return

	skill_loop_running = true
	skill_loop()


func skill_loop() -> void:
	while skill_loop_running and state != BossState.DEAD:
		current_pattern = AttackPattern.NORMAL
		print("攻擊模式：普通彈幕")
		await get_tree().create_timer(normal_pattern_time).timeout
		await pattern_break()

		current_pattern = AttackPattern.PHANTOM
		print("攻擊模式：幻影殘響")
		await get_tree().create_timer(phantom_pattern_time).timeout
		await pattern_break()

		current_pattern = AttackPattern.PRISM
		print("攻擊模式：稜鏡折射")
		spawn_prism_fields()
		await get_tree().create_timer(prism_pattern_time).timeout
		await pattern_break()

		current_pattern = AttackPattern.SLOW
		print("攻擊模式：遲緩子彈")
		await get_tree().create_timer(slow_pattern_time).timeout
		await pattern_break()


func pattern_break() -> void:
	if state == BossState.DEAD:
		return

	fire_timer.stop()
	await get_tree().create_timer(pattern_break_time).timeout

	if state == BossState.ATTACK:
		fire_timer.start()


func move_boss(delta: float) -> void:
	var direction_to_target = target_position - global_position

	if direction_to_target.length() <= arrive_distance:
		choose_new_target_position()
		return

	global_position += direction_to_target.normalized() * move_speed * delta


func choose_new_target_position() -> void:
	var random_x = randf_range(-move_range_x, move_range_x)
	var random_y = randf_range(-move_range_y, move_range_y)

	target_position = start_position + Vector2(random_x, random_y)


func generate_sequence() -> void:
	target_sequence.clear()
	player_sequence_index = 0

	var colors = [
		BulletColor.RED,
		BulletColor.BLUE,
		BulletColor.GREEN,
		BulletColor.YELLOW
	]

	for i in range(sequence_length):
		target_sequence.append(colors.pick_random())

	print("Boss 目標序列：", target_sequence)


func receive_reflected_bullet(bullet_color: int, is_phantom: bool = false) -> void:
	if state == BossState.DEAD:
		return

	if is_phantom:
		print("幻影彈命中 Boss，無效")
		return

	var actual_color = get_actual_color(bullet_color)
	var expected_color = target_sequence[player_sequence_index]

	if actual_color == expected_color:
		print("正確顏色")
		player_sequence_index += 1
		take_damage(normal_damage)

		if player_sequence_index >= target_sequence.size():
			print("完整序列成功！Boss 受到大量傷害")
			take_damage(sequence_damage)
			generate_sequence()
			update_sequence_ui()
			change_state(BossState.STUN)
		else:
			update_sequence_ui()

	else:
		print("錯誤顏色，Boss 回血")
		heal(heal_amount)
		player_sequence_index = 0
		update_sequence_ui()


func get_actual_color(color: int) -> int:
	if not color_reversed:
		return color

	match color:
		BulletColor.RED:
			return BulletColor.BLUE
		BulletColor.BLUE:
			return BulletColor.RED
		BulletColor.GREEN:
			return BulletColor.YELLOW
		BulletColor.YELLOW:
			return BulletColor.GREEN

	return color


func take_damage(amount: int) -> void:
	hp -= amount
	hp = max(hp, 0)
	health_bar.update_hp(hp)

	print("Boss HP:", hp)

	if hp <= max_hp / 2 and not is_phase_two:
		enter_phase_two()

	if hp <= 0:
		change_state(BossState.DEAD)


func heal(amount: int) -> void:
	hp += amount
	hp = min(hp, max_hp)
	health_bar.update_hp(hp)
	print("Boss 回血，目前 HP:", hp)


func enter_phase_two() -> void:
	is_phase_two = true
	color_reversed = true

	fire_timer.wait_time = phase_two_fire_interval
	move_speed += 15.0

	print("Boss 進入二階段：半血反轉")


func _on_fire_timer_timeout() -> void:
	if state != BossState.ATTACK:
		return

	fire_bullet()


func fire_bullet() -> void:
	if bullet_scene == null:
		print("尚未指定 bullet_scene")
		return

	match current_pattern:
		AttackPattern.NORMAL:
			fire_single_bullet(false, false)

		AttackPattern.PHANTOM:
			fire_single_bullet(randf() < get_current_phantom_chance(), false)

		AttackPattern.PRISM:
			fire_spread_bullets(3, false, false)

		AttackPattern.SLOW:
			fire_single_bullet(false, randf() < get_current_slow_chance())


func fire_single_bullet(phantom: bool, slow_bullet: bool) -> void:
	var bullet = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)

	bullet.global_position = bullet_spawn_point.global_position

	var selected_color = get_random_color()
	var bullet_direction = Vector2.DOWN.rotated(randf_range(-0.5, 0.5))

	if bullet.has_method("setup"):
		bullet.setup(
			selected_color,
			bullet_direction,
			phantom,
			slow_bullet
		)


func fire_spread_bullets(count: int, phantom: bool, slow_bullet: bool) -> void:
	var start_angle = -0.5
	var end_angle = 0.5

	for i in range(count):
		var bullet = bullet_scene.instantiate()
		get_tree().current_scene.add_child(bullet)

		bullet.global_position = bullet_spawn_point.global_position

		var t = 0.0
		if count > 1:
			t = float(i) / float(count - 1)

		var angle = lerp(start_angle, end_angle, t)
		var bullet_direction = Vector2.DOWN.rotated(angle)

		if bullet.has_method("setup"):
			bullet.setup(
				get_random_color(),
				bullet_direction,
				phantom,
				slow_bullet
			)


func spawn_prism_fields() -> void:
	if prism_field_scene == null:
		print("尚未指定 prism_field_scene")
		return

	var prism_count = 1

	if is_phase_two:
		prism_count = 2

	for i in range(prism_count):
		var prism = prism_field_scene.instantiate()
		get_tree().current_scene.add_child(prism)

		var random_x = randf_range(-prism_spawn_range_x, prism_spawn_range_x)
		var random_y = randf_range(-prism_spawn_range_y, prism_spawn_range_y)

		prism.global_position = start_position + Vector2(random_x, random_y)

		if prism.has_method("set_lifetime"):
			prism.set_lifetime(prism_lifetime)


func get_random_color() -> int:
	var colors = [
		BulletColor.RED,
		BulletColor.BLUE,
		BulletColor.GREEN,
		BulletColor.YELLOW
	]

	return colors.pick_random()


func get_current_phantom_chance() -> float:
	if is_phase_two:
		return phase_two_phantom_chance

	return phantom_chance


func get_current_slow_chance() -> float:
	if is_phase_two:
		return phase_two_slow_bullet_chance

	return slow_bullet_chance


func _on_stun_timer_timeout() -> void:
	if state != BossState.DEAD:
		change_state(BossState.ATTACK)


func update_sequence_ui() -> void:
	if sequence_ui == null:
		return

	if sequence_ui.has_method("set_sequence"):
		sequence_ui.set_sequence(target_sequence, player_sequence_index)
