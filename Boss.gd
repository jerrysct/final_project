extends CharacterBody2D

signal died

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

@onready var health_bar: ProgressBar = get_tree().current_scene.get_node_or_null("CanvasLayer/BossHealthBar") as ProgressBar
@onready var health_label: Label = get_tree().current_scene.get_node_or_null("CanvasLayer/BossHealthLabel") as Label

@export var max_hp: int = 1000
@export var normal_damage: int = 30
@export var sequence_damage: int = 200
@export var heal_amount: int = 80

@export var bullet_scene: PackedScene

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

# 遠距離接近玩家
@export var far_distance_threshold: float = 520.0
@export var approach_cooldown: float = 4.0
@export var approach_distance: float = 260.0
@export var approach_speed_multiplier: float = 1.8

# 遠距離機槍掃射：單次掃射，不來回掃
@export var far_sweep_cooldown: float = 5.0
@export var far_sweep_bullet_count: int = 16
@export var far_sweep_spread_degrees: float = 70.0
@export var far_sweep_bullet_speed: float = 300.0
@export var far_sweep_interval: float = 0.055
@export var far_sweep_random_direction: bool = true

@onready var fire_timer: Timer = $FireTimer
@onready var stun_timer: Timer = $StunTimer
@onready var bullet_spawn_point: Marker2D = $BulletSpawnPoint
@onready var sequence_ui: Node = get_tree().current_scene.get_node_or_null("CanvasLayer/SequenceUI")
@onready var boss_sprite: Sprite2D = $Sprite2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
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
var is_approaching_player: bool = false

var current_pattern: AttackPattern = AttackPattern.NORMAL
var skill_loop_running: bool = false

var color_map: Dictionary = {}

var approach_cooldown_timer: float = 0.0
var far_sweep_cooldown_timer: float = 0.0
var is_doing_far_sweep: bool = false


func _ready() -> void:
	animated_sprite.play("idle")
	hp = max_hp

	if health_bar != null:
		if health_bar.has_method("setup"):
			health_bar.setup(max_hp)
		else:
			health_bar.max_value = max_hp
			health_bar.value = hp

		health_bar.show_percentage = false

	update_boss_hp_ui()

	randomize()
	find_player()

	start_position = global_position
	choose_new_target_position()

	generate_sequence()
	update_sequence_ui()

	fire_timer.one_shot = false
	fire_timer.autostart = false
	fire_timer.wait_time = fire_interval

	var fire_callable := Callable(self, "_on_fire_timer_timeout")
	if fire_timer.timeout.is_connected(fire_callable):
		fire_timer.timeout.disconnect(fire_callable)
	fire_timer.timeout.connect(fire_callable)

	var stun_callable := Callable(self, "_on_stun_timer_timeout")
	if stun_timer.timeout.is_connected(stun_callable):
		stun_timer.timeout.disconnect(stun_callable)
	stun_timer.timeout.connect(stun_callable)

	change_state(BossState.ATTACK)
	start_skill_loop()


func _physics_process(delta: float) -> void:
	if state == BossState.DEAD:
		return

	if state == BossState.STUN:
		move_velocity = Vector2.ZERO
		return

	update_distance_logic(delta)
	move_boss(delta)


func change_state(new_state: BossState) -> void:
	state = new_state

	match state:
		BossState.IDLE:
			fire_timer.stop()

		BossState.ATTACK:
			fire_timer.wait_time = fire_interval if not is_phase_two else phase_two_fire_interval
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
			died.emit()
			call_deferred("queue_free")


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
				await get_tree().create_timer(normal_pattern_time).timeout

			AttackPattern.PHANTOM:
				await get_tree().create_timer(phantom_pattern_time).timeout

			AttackPattern.PRISM:
				await get_tree().create_timer(prism_pattern_time).timeout

			AttackPattern.SLOW:
				await get_tree().create_timer(slow_pattern_time).timeout

			AttackPattern.RADIAL:
				await get_tree().create_timer(radial_pattern_time).timeout

			AttackPattern.BURST:
				await get_tree().create_timer(burst_pattern_time).timeout

		await pattern_break()


func pattern_break() -> void:
	if state == BossState.DEAD:
		return

	fire_timer.stop()
	await get_tree().create_timer(pattern_break_time).timeout

	if state == BossState.ATTACK:
		fire_timer.start()


func update_distance_logic(delta: float) -> void:
	if approach_cooldown_timer > 0.0:
		approach_cooldown_timer -= delta

	if far_sweep_cooldown_timer > 0.0:
		far_sweep_cooldown_timer -= delta

	if player == null or not is_instance_valid(player):
		find_player()
		return

	var distance_to_player: float = global_position.distance_to(player.global_position)

	if distance_to_player >= far_distance_threshold:
		try_approach_player()
		try_fire_far_sweep()


func try_approach_player() -> void:
	if approach_cooldown_timer > 0.0:
		return

	if is_approaching_player:
		return

	if player == null or not is_instance_valid(player):
		return

	var direction_to_player: Vector2 = player.global_position - global_position

	if direction_to_player.length() <= 0.001:
		return

	var desired_position: Vector2 = global_position + direction_to_player.normalized() * approach_distance

	desired_position.x = clamp(desired_position.x, room_left, room_right)
	desired_position.y = clamp(desired_position.y, room_top, room_bottom)

	target_position = desired_position
	is_approaching_player = true
	is_waiting_for_next_move = false
	approach_cooldown_timer = approach_cooldown


func try_fire_far_sweep() -> void:
	if far_sweep_cooldown_timer > 0.0:
		return

	if is_doing_far_sweep:
		return

	if state != BossState.ATTACK:
		return

	is_doing_far_sweep = true
	call_deferred("fire_far_machine_gun_sweep")


func move_boss(delta: float) -> void:
	if is_waiting_for_next_move:
		move_velocity = move_velocity.move_toward(Vector2.ZERO, move_speed * delta)
		global_position += move_velocity * delta
		clamp_boss_inside_room()
		return

	var direction_to_target: Vector2 = target_position - global_position

	if direction_to_target.length() <= arrive_distance:
		if is_approaching_player:
			is_approaching_player = false

		wait_then_choose_new_target()
		return

	var current_move_speed: float = move_speed

	if is_approaching_player:
		current_move_speed *= approach_speed_multiplier

	var desired_velocity: Vector2 = direction_to_target.normalized() * current_move_speed
	move_velocity = move_velocity.lerp(desired_velocity, move_smooth * delta)

	global_position += move_velocity * delta
	clamp_boss_inside_room()


func wait_then_choose_new_target() -> void:
	if is_waiting_for_next_move:
		return

	is_waiting_for_next_move = true
	move_velocity = Vector2.ZERO

	await get_tree().create_timer(idle_after_arrive).timeout

	if state != BossState.DEAD and state != BossState.STUN and not is_approaching_player:
		choose_new_target_position()

	is_waiting_for_next_move = false


func choose_new_target_position() -> void:
	var random_x: float = randf_range(room_left, room_right)
	var random_y: float = randf_range(room_top, room_bottom)

	target_position = Vector2(random_x, random_y)


func clamp_boss_inside_room() -> void:
	global_position.x = clamp(global_position.x, room_left, room_right)
	global_position.y = clamp(global_position.y, room_top, room_bottom)


func generate_sequence() -> void:
	target_sequence.clear()
	player_sequence_index = 0

	var colors: Array[int] = [
		BulletColor.RED,
		BulletColor.BLUE,
		BulletColor.GREEN,
		BulletColor.YELLOW
	]

	for i in range(sequence_length):
		target_sequence.append(colors.pick_random())


func receive_reflected_bullet(bullet_color: int, is_phantom: bool = false) -> void:
	if state == BossState.DEAD:
		return

	if is_phantom:
		return

	var actual_color: int = get_actual_color(bullet_color)
	var expected_color: int = target_sequence[player_sequence_index]

	if actual_color == expected_color:
		player_sequence_index += 1
		take_damage(normal_damage)

		if player_sequence_index >= target_sequence.size():
			take_damage(sequence_damage)
			generate_sequence()
			update_sequence_ui()
			change_state(BossState.STUN)
		else:
			update_sequence_ui()

	else:
		heal(heal_amount)
		player_sequence_index = 0
		update_sequence_ui()


func get_actual_color(color: int) -> int:
	if not color_reversed:
		return color

	if color_map.has(color):
		return int(color_map[color])

	return color


func take_damage(amount: int) -> void:
	if state == BossState.DEAD:
		return

	hp -= amount
	hp = max(hp, 0)

	update_boss_hp_ui()
	play_hit_effect()

	if hp <= max_hp / 2.0 and not is_phase_two:
		enter_phase_two()

	if hp <= 0:
		change_state(BossState.DEAD)


func heal(amount: int) -> void:
	if state == BossState.DEAD:
		return

	hp += amount
	hp = min(hp, max_hp)

	update_boss_hp_ui()


func update_boss_hp_ui() -> void:
	if health_bar != null:
		if health_bar.has_method("update_hp"):
			health_bar.update_hp(hp)
		else:
			health_bar.max_value = max_hp
			health_bar.value = hp

	if health_label != null:
		health_label.text = str(hp) + " / " + str(max_hp)


func enter_phase_two() -> void:
	is_phase_two = true
	color_reversed = true

	generate_random_color_map()

	fire_timer.wait_time = phase_two_fire_interval
	move_speed += 8.0

	far_distance_threshold += 80.0
	far_sweep_bullet_count += 3
	far_sweep_bullet_speed += 25.0
	approach_cooldown = max(2.5, approach_cooldown - 0.8)
	far_sweep_cooldown = max(3.5, far_sweep_cooldown - 0.5)


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
	if bullet_scene == null:
		return

	var bullet: Node = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)

	if bullet is Node2D:
		(bullet as Node2D).global_position = bullet_spawn_point.global_position

	var selected_color: int = get_random_color()
	var bullet_direction: Vector2 = get_direction_to_player().rotated(randf_range(-0.18, 0.18))

	if bullet.has_method("setup"):
		bullet.setup(
			selected_color,
			bullet_direction,
			phantom,
			slow_bullet
		)


func fire_spread_bullets(count: int, phantom: bool, slow_bullet: bool) -> void:
	if bullet_scene == null:
		return

	var start_angle: float = -0.5
	var end_angle: float = 0.5

	for i in range(count):
		var bullet: Node = bullet_scene.instantiate()
		get_tree().current_scene.add_child(bullet)

		if bullet is Node2D:
			(bullet as Node2D).global_position = bullet_spawn_point.global_position

		var t: float = 0.0
		if count > 1:
			t = float(i) / float(count - 1)

		var angle: float = lerpf(start_angle, end_angle, t)
		var bullet_direction: Vector2 = get_direction_to_player().rotated(angle)

		if bullet.has_method("setup"):
			bullet.setup(
				get_random_color(),
				bullet_direction,
				phantom,
				slow_bullet
			)


func fire_radial_bullets() -> void:
	if bullet_scene == null:
		return

	var bullet_count: int = 12
	var bullet_speed: float = 150.0

	if is_phase_two:
		bullet_count = 20
		bullet_speed = 155.0

	for i in range(bullet_count):
		var bullet: Node = bullet_scene.instantiate()
		get_tree().current_scene.add_child(bullet)

		if bullet is Node2D:
			(bullet as Node2D).global_position = bullet_spawn_point.global_position

		var angle: float = TAU * float(i) / float(bullet_count)
		var bullet_direction: Vector2 = Vector2.RIGHT.rotated(angle)

		var phantom: bool = false
		var slow_bullet: bool = false

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
		return

	var bullet: Node = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)

	if bullet is Node2D:
		(bullet as Node2D).global_position = bullet_spawn_point.global_position

	var bullet_direction: Vector2 = get_direction_to_player().rotated(randf_range(-0.35, 0.35))

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


func fire_far_machine_gun_sweep() -> void:
	if bullet_scene == null:
		is_doing_far_sweep = false
		return

	var base_direction: Vector2 = get_direction_to_player()
	var base_angle: float = base_direction.angle()

	var spread_rad: float = deg_to_rad(far_sweep_spread_degrees)
	var half_spread: float = spread_rad / 2.0

	var reverse: bool = false
	if far_sweep_random_direction:
		reverse = randf() < 0.5

	for bullet_index_value in range(far_sweep_bullet_count):
		if state == BossState.DEAD:
			break

		var bullet_index: int = int(bullet_index_value)
		var t: float = 0.0

		if far_sweep_bullet_count > 1:
			t = float(bullet_index) / float(far_sweep_bullet_count - 1)

		if reverse:
			t = 1.0 - t

		var angle_offset: float = lerpf(-half_spread, half_spread, t)
		var bullet_direction: Vector2 = Vector2.RIGHT.rotated(base_angle + angle_offset)

		spawn_far_sweep_bullet(bullet_direction)

		await get_tree().create_timer(far_sweep_interval).timeout

	is_doing_far_sweep = false
	far_sweep_cooldown_timer = far_sweep_cooldown


func spawn_far_sweep_bullet(direction: Vector2) -> void:
	if bullet_scene == null:
		return

	var bullet: Node = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)

	if bullet is Node2D:
		(bullet as Node2D).global_position = bullet_spawn_point.global_position

	if bullet.has_method("setup"):
		bullet.setup(
			get_random_color(),
			direction.normalized(),
			false,
			false,
			far_sweep_bullet_speed
		)


func get_random_color() -> int:
	var colors: Array[int] = [
		BulletColor.RED,
		BulletColor.BLUE,
		BulletColor.GREEN,
		BulletColor.YELLOW
	]

	return int(colors.pick_random())


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
		var scene_root: Node = get_tree().current_scene
		if scene_root != null:
			sequence_ui = scene_root.get_node_or_null("CanvasLayer/SequenceUI")

	if sequence_ui == null:
		return

	if sequence_ui.has_method("set_sequence"):
		sequence_ui.set_sequence(target_sequence, player_sequence_index)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		take_damage(100)


func find_player() -> void:
	player = get_tree().get_first_node_in_group(player_group_name) as Node2D

	if player != null:
		return

	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return

	var possible_names: Array[String] = [
		"Player_1",
		"player_1",
		"Player",
		"No"
	]

	for node_name in possible_names:
		var found_node: Node = scene_root.find_child(node_name, true, false)
		if found_node is Node2D:
			player = found_node as Node2D
			return


func get_direction_to_player() -> Vector2:
	if player == null or not is_instance_valid(player):
		find_player()

	if player == null or not is_instance_valid(player):
		return Vector2.DOWN

	var direction: Vector2 = player.global_position - bullet_spawn_point.global_position

	if direction.length() <= 0.001:
		return Vector2.DOWN

	return direction.normalized()


func play_hit_effect() -> void:
	if boss_sprite == null:
		return

	var original_modulate: Color = boss_sprite.modulate
	var original_position: Vector2 = boss_sprite.position

	boss_sprite.modulate = Color.WHITE
	boss_sprite.position += Vector2(randf_range(-4, 4), randf_range(-4, 4))

	await get_tree().create_timer(0.06).timeout

	if boss_sprite == null:
		return

	boss_sprite.modulate = original_modulate
	boss_sprite.position = original_position


func generate_random_color_map() -> void:
	var original_colors: Array[int] = [
		BulletColor.RED,
		BulletColor.BLUE,
		BulletColor.GREEN,
		BulletColor.YELLOW
	]

	var shuffled_colors: Array[int] = original_colors.duplicate()
	shuffled_colors.shuffle()

	color_map.clear()

	for i in range(original_colors.size()):
		color_map[original_colors[i]] = shuffled_colors[i]


func choose_next_pattern() -> AttackPattern:
	var patterns: Array[AttackPattern] = [
		AttackPattern.NORMAL,
		AttackPattern.PHANTOM,
		AttackPattern.PRISM,
		AttackPattern.SLOW,
		AttackPattern.RADIAL,
		AttackPattern.BURST
	]

	if not is_phase_two:
		return patterns.pick_random() as AttackPattern

	var phase_two_patterns: Array[AttackPattern] = [
		AttackPattern.PHANTOM,
		AttackPattern.PRISM,
		AttackPattern.RADIAL,
		AttackPattern.RADIAL,
		AttackPattern.BURST,
		AttackPattern.BURST,
		AttackPattern.SLOW
	]

	return phase_two_patterns.pick_random() as AttackPattern
