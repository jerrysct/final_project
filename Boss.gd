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

@export var max_hp: int = 1000
@export var normal_damage: int = 30
@export var sequence_damage: int = 200
@export var heal_amount: int = 80

@export var bullet_scene: PackedScene
@export var fire_interval: float = 0.8
@export var phase_two_fire_interval: float = 0.55
@export var stun_time: float = 2.0

@export var sequence_length: int = 3
@export var phantom_chance: float = 0.3
@export var slow_bullet_chance: float = 0.2

@export var move_speed: float = 55.0
@export var move_range_x: float = 220.0
@export var move_range_y: float = 120.0
@export var arrive_distance: float = 10.0

@onready var fire_timer: Timer = $FireTimer
@onready var stun_timer: Timer = $StunTimer
@onready var bullet_spawn_point: Marker2D = $BulletSpawnPoint
@onready var sequence_ui: Node = $SequenceUI

var start_position: Vector2
var target_position: Vector2

var hp: int
var state: BossState = BossState.IDLE

var target_sequence: Array[int] = []
var player_sequence_index: int = 0

var is_phase_two: bool = false
var color_reversed: bool = false


func _ready() -> void:
	hp = max_hp
	randomize()

	start_position = global_position
	choose_new_target_position()

	generate_sequence()
	update_sequence_ui()

	fire_timer.wait_time = fire_interval
	fire_timer.timeout.connect(_on_fire_timer_timeout)
	stun_timer.timeout.connect(_on_stun_timer_timeout)

	change_state(BossState.ATTACK)


func _physics_process(delta: float) -> void:
	if state == BossState.DEAD:
		return
	
	if state == BossState.STUN:
		return
	
	move_boss(delta)


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
			print("Boss 死亡")
			queue_free()


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

	print("Boss HP:", hp)

	if hp <= max_hp / 2 and not is_phase_two:
		enter_phase_two()

	if hp <= 0:
		change_state(BossState.DEAD)


func heal(amount: int) -> void:
	hp += amount
	hp = min(hp, max_hp)
	print("Boss 回血，目前 HP:", hp)


func enter_phase_two() -> void:
	is_phase_two = true
	color_reversed = true
	fire_timer.wait_time = phase_two_fire_interval

	print("Boss 進入二階段：半血反轉")


func _on_fire_timer_timeout() -> void:
	if state != BossState.ATTACK:
		return

	fire_bullet()


func fire_bullet() -> void:
	if bullet_scene == null:
		print("尚未指定 bullet_scene")
		return

	var bullet = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)

	bullet.global_position = bullet_spawn_point.global_position

	var colors = [
		BulletColor.RED,
		BulletColor.BLUE,
		BulletColor.GREEN,
		BulletColor.YELLOW
	]

	var selected_color = colors.pick_random()
	var bullet_direction = Vector2.DOWN.rotated(randf_range(-0.5, 0.5))
	var phantom = randf() < phantom_chance
	var slow_bullet = randf() < slow_bullet_chance

	if bullet.has_method("setup"):
		bullet.setup(
			selected_color,
			bullet_direction,
			phantom,
			slow_bullet
		)


func _on_stun_timer_timeout() -> void:
	if state != BossState.DEAD:
		change_state(BossState.ATTACK)


func update_sequence_ui() -> void:
	if sequence_ui == null:
		return

	if sequence_ui.has_method("set_sequence"):
		sequence_ui.set_sequence(target_sequence, player_sequence_index)
