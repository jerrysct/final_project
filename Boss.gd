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
	SLOW,
	RADIAL,
	BURST
}

@onready var health_bar: ProgressBar = get_tree().current_scene.get_node("CanvasLayer/BossHealthBar")

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
@export var radial_pattern_time: float = 5.0
@export var burst_pattern_time: float = 5.0

@export var phantom_chance: float = 0.3
@export var phase_two_phantom_chance: float = 0.5

@export var slow_bullet_chance: float = 0.2
@export var phase_two_slow_bullet_chance: float = 0.35

@export var move_speed: float = 28.0
@export var player_group_name: String = "player"
@export var room_left: float = -300.0
@export var room_right: float = 300.0
@export var room_top: float = -200.0
@export var room_bottom: float = 200.0
@export var arrive_distance: float = 12.0
@export var move_smooth: float = 3.0
@export var idle_after_arrive: float = 0.6

@export var prism_spawn_range_x: float = 260.0
@export var prism_spawn_range_y: float = 140.0
@export var prism_lifetime: float = 5.0

@export var prism_spawn_center: Vector2 = Vector2.ZERO
@export var prism_spawn_size: Vector2 = Vector2(400, 250)

@onready var fire_timer: Timer = $FireTimer
@onready var stun_timer: Timer = $StunTimer
@onready var bullet_spawn_point: Marker2D = $BulletSpawnPoint
@onready var sequence_ui: Node = $"../CanvasLayer/SequenceUI"

@onready var boss_sprite: Sprite2D = $Sprite2D

var player: Node2D = null

var hp: int
var state: BossState = BossState.IDLE

var target_sequence: Array[int] = []
var player_sequence_index: int = 0

var is_phase_two: bool = false
var color_reversed: bool = false

var start_position: Vector2
var target_position: Vector2
var move_velocity: Vector2 = Vector2.ZERO
var is_waiting_for_next_move: bool = false

var current_pattern: AttackPattern = AttackPattern.NORMAL
var skill_loop_running: bool = false

var color_map: Dictionary = {}


func _ready() -> void:
	hp = max_hp
	if health_bar:
		health_bar.setup(max_hp)
	randomize()
	find_player()

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
		move_velocity = Vector2.ZERO
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
			move_velocity = Vector2.ZERO
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
		current_pattern = choose_next_pattern()

		match current_pattern:
			AttackPattern.NORMAL:
				print("攻擊模式：普通彈幕")
				await get_tree().create_timer(normal_pattern_time).timeout

			AttackPattern.PHANTOM:
				print("攻擊模式：幻影殘響")
				await get_tree().create_timer(phantom_pattern_time).timeout

			AttackPattern.PRISM:
				print("攻擊模式：稜鏡折射")
				spawn_prism_fields()
				await get_tree().create_timer(prism_pattern_time).timeout

			AttackPattern.SLOW:
				print("攻擊模式：遲緩子彈")
				await get_tree().create_timer(slow_pattern_time).timeout

			AttackPattern.RADIAL:
				print("攻擊模式：環形彈幕")
				await get_tree().create_timer(radial_pattern_time).timeout

			AttackPattern.BURST:
				print("攻擊模式：大球爆散環形彈幕")
				await get_tree().create_timer(burst_pattern_time).timeout

		await pattern_break()


func pattern_break() -> void:
	if state == BossState.DEAD:
		return

	fire_timer.stop()
	await get_tree().create_timer(pattern_break_time).timeout

	if state == BossState.ATTACK:
		fire_timer.start()


func move_boss(delta: float) -> void:
	if is_waiting_for_next_move:
		move_velocity = move_velocity.move_toward(Vector2.ZERO, move_speed * delta)
		global_position += move_velocity * delta
		return

	var direction_to_target = target_position - global_position

	if direction_to_target.length() <= arrive_distance:
		wait_then_choose_new_target()
		return

	var desired_velocity = direction_to_target.normalized() * move_speed
	move_velocity = move_velocity.lerp(desired_velocity, move_smooth * delta)

	global_position += move_velocity * delta


func wait_then_choose_new_target() -> void:
	if is_waiting_for_next_move:
		return

	is_waiting_for_next_move = true
	move_velocity = Vector2.ZERO

	await get_tree().create_timer(idle_after_arrive).timeout

	if state != BossState.DEAD and state != BossState.STUN:
		choose_new_target_position()

	is_waiting_for_next_move = false


func choose_new_target_position() -> void:
	var random_x = randf_range(room_left, room_right)
	var random_y = randf_range(room_top, room_bottom)

	target_position = Vector2(random_x, random_y)


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

	if color_map.has(color):
		return color_map[color]

	return color


func take_damage(amount: int) -> void:
	hp -= amount
	hp = max(hp, 0)
	if health_bar:
		health_bar.update_hp(hp)
	play_hit_effect()

	print("Boss HP:", hp)

	if hp <= max_hp / 2.0 and not is_phase_two:
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

	generate_random_color_map()

	fire_timer.wait_time = phase_two_fire_interval
	move_speed += 8.0

	print("Boss 進入二階段：半血隨機顏色反轉")


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

		AttackPattern.RADIAL:
			fire_radial_bullets()

		AttackPattern.BURST:
			fire_burst_bullet()


func fire_single_bullet(phantom: bool, slow_bullet: bool) -> void:
	var bullet = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)

	bullet.global_position = bullet_spawn_point.global_position

	var selected_color = get_random_color()
	var bullet_direction = get_direction_to_player().rotated(randf_range(-0.18, 0.18))

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
		var bullet_direction = get_direction_to_player().rotated(angle)

		if bullet.has_method("setup"):
			bullet.setup(
				get_random_color(),
				bullet_direction,
				phantom,
				slow_bullet
			)


func fire_radial_bullets() -> void:
	var bullet_count = 12
	var bullet_speed = 150.0

	if is_phase_two:
		bullet_count = 20
		bullet_speed = 155.0

	for i in range(bullet_count):
		var bullet = bullet_scene.instantiate()
		get_tree().current_scene.add_child(bullet)

		bullet.global_position = bullet_spawn_point.global_position

		var angle = TAU * float(i) / float(bullet_count)
		var bullet_direction = Vector2.RIGHT.rotated(angle)

		var phantom = false
		var slow_bullet = false

		if is_phase_two:
			phantom = randf() < 0.25
			slow_bullet = randf() < 0.15

		if bullet.has_method("setup"):
			bullet.setup(
				get_random_color(),
				bullet_direction,
				phantom,
				slow_bullet,
				bullet_speed
			)


func fire_burst_bullet() -> void:
	if bullet_scene == null:
		print("尚未指定 bullet_scene")
		return

	var bullet = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)

	bullet.global_position = bullet_spawn_point.global_position

	var bullet_direction = get_direction_to_player().rotated(randf_range(-0.35, 0.35))

	if bullet.has_method("setup"):
		bullet.setup(
			get_random_color(),
			bullet_direction,
			false,
			false,
			100.0,
			1,
			is_phase_two
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

		var random_x = randf_range(-prism_spawn_range_x, prism_spawn_range_x)
		var random_y = randf_range(-prism_spawn_range_y, prism_spawn_range_y)

		prism.global_position = start_position + Vector2(random_x, random_y)

		get_tree().current_scene.call_deferred("add_child", prism)

		if prism.has_method("set_lifetime"):
			prism.call_deferred("set_lifetime", prism_lifetime)

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


func _input(event):
	if event.is_action_pressed("ui_accept"):
		take_damage(100)
		
func find_player() -> void:
	player = get_tree().get_first_node_in_group(player_group_name) as Node2D

	if player != null:
		return

	var scene_root = get_tree().current_scene
	if scene_root == null:
		return

	# 備用搜尋：如果玩家還沒有加入 player 群組，就用常見節點名稱尋找。
	var possible_names = [
		"Player_1",
		"player_1",
		"Player",
		"No"
	]

	for node_name in possible_names:
		var found_node = scene_root.find_child(node_name, true, false)
		if found_node is Node2D:
			player = found_node
			return


func get_direction_to_player() -> Vector2:
	if player == null or not is_instance_valid(player):
		find_player()

	if player == null or not is_instance_valid(player):
		return Vector2.DOWN

	var direction = player.global_position - bullet_spawn_point.global_position
	if direction.length() <= 0.001:
		return Vector2.DOWN

	return direction.normalized()

func play_hit_effect() -> void:
	if boss_sprite == null:
		return

	var original_modulate = boss_sprite.modulate
	var original_position = boss_sprite.position

	boss_sprite.modulate = Color.WHITE
	boss_sprite.position += Vector2(randf_range(-4, 4), randf_range(-4, 4))

	await get_tree().create_timer(0.06).timeout

	if boss_sprite == null:
		return

	boss_sprite.modulate = original_modulate
	boss_sprite.position = original_position
	
func generate_random_color_map() -> void:
	var original_colors = [
		BulletColor.RED,
		BulletColor.BLUE,
		BulletColor.GREEN,
		BulletColor.YELLOW
	]

	var shuffled_colors = original_colors.duplicate()
	shuffled_colors.shuffle()

	color_map.clear()

	for i in range(original_colors.size()):
		color_map[original_colors[i]] = shuffled_colors[i]

	print("二階段顏色對應：", color_map)
	
func choose_next_pattern() -> AttackPattern:
	var patterns = [
		AttackPattern.NORMAL,
		AttackPattern.PHANTOM,
		AttackPattern.PRISM,
		AttackPattern.SLOW,
		AttackPattern.RADIAL,
		AttackPattern.BURST
	]

	if not is_phase_two:
		return patterns.pick_random()

	# 二階段提高危險招式出現率
	var phase_two_patterns = [
		AttackPattern.PHANTOM,
		AttackPattern.PRISM,
		AttackPattern.RADIAL,
		AttackPattern.RADIAL,
		AttackPattern.BURST,
		AttackPattern.BURST,
		AttackPattern.SLOW
	]

	return phase_two_patterns.pick_random()
