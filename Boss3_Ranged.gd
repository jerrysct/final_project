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
	BUFF_MELEE   # ✅新技能
}

const SPRITE_COLOR_NORMAL: Color = Color(1, 1, 1)
const SPRITE_COLOR_CHARGE: Color = Color(1.0, 0.45, 0.25)
const SPRITE_COLOR_HEAL: Color = Color(0.35, 1.0, 0.45)

@onready var _sprite: Sprite2D = $Sprite2D

@export var max_hp: int = 200

@export var attack_cooldown_min: float = 1.2
@export var attack_cooldown_max: float = 2.4
@export var recover_time: float = 0.7

@export var bullet_scene: PackedScene
@export var debug_enabled: bool = false

@export var burst_count_min: int = 3
@export var burst_count_max: int = 5
@export var burst_interval: float = 0.12

@export var fan_bullet_count: int = 7
@export var fan_spread_degrees: float = 60.0

@export var charge_prepare_time: float = 0.65

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

var _last_attack: AttackType = AttackType.BURST
var _same_attack_count: int = 0

var _heal_cooldown_left: float = 0.0

var _is_enraged: bool = false

var _base_attack_cooldown_min: float
var _base_attack_cooldown_max: float
var _base_burst_count_min: int
var _base_burst_count_max: int
var _base_fan_bullet_count: int
var _base_charge_prepare_time: float


func _ready() -> void:
	hp = max_hp

	_base_attack_cooldown_min = attack_cooldown_min
	_base_attack_cooldown_max = attack_cooldown_max
	_base_burst_count_min = burst_count_min
	_base_burst_count_max = burst_count_max
	_base_fan_bullet_count = fan_bullet_count
	_base_charge_prepare_time = charge_prepare_time

	find_player()
	_roll_attack_cooldown()


func enter_enraged_mode() -> void:
	if _is_enraged:
		return

	_is_enraged = true

	attack_cooldown_min *= 0.6
	attack_cooldown_max *= 0.6

	burst_count_min += 2
	burst_count_max += 2
	fan_bullet_count += 2

	charge_prepare_time *= 0.7

	modulate = Color(1, 0.3, 0.3)  # 紅色

	print("Boss3_Ranged 狂暴了🔥")
	

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
			_attack_fan()
		AttackType.CHARGE_SHOT:
			await _attack_charge_shot()
		AttackType.HEAL_MELEE:
			await _attack_heal_melee()
		AttackType.BUFF_MELEE:
			await _attack_buff_melee()

	if state == State.DEAD:
		return

	_is_attacking = false
	state = State.RECOVER
	_state_time = 0.0
	_set_sprite_modulate(SPRITE_COLOR_NORMAL)

	if debug_enabled:
		print("Boss3_Ranged -> RECOVER")


func _attack_burst() -> void:
	var count: int = randi_range(burst_count_min, burst_count_max)

	for i in range(count):
		if state == State.DEAD:
			return

		var dir: Vector2 = _get_direction_to_player()
		_spawn_bullet(dir)

		await get_tree().create_timer(burst_interval).timeout


func _attack_fan() -> void:
	var base_dir: Vector2 = _get_direction_to_player()

	if fan_bullet_count <= 1:
		_spawn_bullet(base_dir)
		return

	var spread_rad: float = deg_to_rad(fan_spread_degrees)
	var start_angle: float = -spread_rad / 2.0
	var angle_step: float = spread_rad / float(fan_bullet_count - 1)

	for i in range(fan_bullet_count):
		var angle_offset: float = start_angle + angle_step * i
		var dir: Vector2 = base_dir.rotated(angle_offset)
		_spawn_bullet(dir)


func _attack_charge_shot() -> void:
	_set_sprite_modulate(SPRITE_COLOR_CHARGE)

	var locked_dir: Vector2 = _get_direction_to_player()

	await get_tree().create_timer(charge_prepare_time).timeout

	if state == State.DEAD:
		return

	_set_sprite_modulate(SPRITE_COLOR_NORMAL)
	_spawn_bullet(locked_dir)


func _attack_buff_melee() -> void:
	print("BUFF_MELEE 開始執行")

	_set_sprite_modulate(Color(0.3, 0.5, 1.0))

	await get_tree().create_timer(0.5).timeout

	var melee_boss := get_node_or_null(melee_boss_path)

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

	var choices: Array[AttackType] = [
		AttackType.BURST,
		AttackType.FAN,
		AttackType.CHARGE_SHOT,
	]

	var chosen: AttackType = choices[randi_range(0, choices.size() - 1)]

	if chosen == _last_attack:
		_same_attack_count += 1
	else:
		_same_attack_count = 0

	if _same_attack_count >= 2:
		while chosen == _last_attack:
			chosen = choices[randi_range(0, choices.size() - 1)]
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


func _roll_attack_cooldown() -> void:
	_attack_cooldown_left = randf_range(attack_cooldown_min, attack_cooldown_max)


func _face_player() -> void:
	if _sprite == null:
		return

	if player == null or not is_instance_valid(player):
		return

	var player_is_left: bool = player.global_position.x < global_position.x
	_sprite.flip_h = player_is_left


func _set_sprite_modulate(color: Color) -> void:
	if _sprite != null:
		_sprite.modulate = color


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
		_:
			return "UNKNOWN"
