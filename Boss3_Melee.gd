extends CharacterBody2D

enum State {
	CHASE,
	PREPARE_CHARGE,
	CHARGE,
	RETREAT,
	RECOVER,
	PREPARE_DIVE,
	DIVE,
	DIVE_RECOVER,
	DEAD,
}

const ENRAGED_MOVE_SPEED_MULT: float = 1.35
const ENRAGED_CHARGE_SPEED_MULT: float = 1.35
const ENRAGED_CHARGE_COOLDOWN_MULT: float = 0.65

const SPRITE_COLOR_NORMAL: Color = Color(1, 1, 1)
const SPRITE_COLOR_PREPARE_CHARGE: Color = Color(1.0, 0.35, 0.35)
const SPRITE_COLOR_PREPARE_DIVE: Color = Color(0.75, 0.35, 1.0)

@onready var _sprite: Sprite2D = $Sprite2D

@export var max_hp: int = 300
@export var move_speed: float = 120.0
@export var chase_stop_distance: float = 120.0
@export var contact_damage: int = 10

@export var charge_speed: float = 420.0
@export var charge_prepare_time: float = 0.45
@export var charge_duration: float = 0.32
@export var recover_time: float = 0.4

@export var retreat_speed: float = 300.0
@export var retreat_duration: float = 0.7
@export var retreat_duration_min: float = 0.4
@export var retreat_duration_max: float = 0.9
@export var post_retreat_recover_time: float = 0.6

@export var charge_cooldown: float = 2.2
@export var charge_cooldown_min: float = 1.6
@export var charge_cooldown_max: float = 3.0
@export var contact_damage_cooldown: float = 0.8

@export var fire_spawn_chance: float = 0.7
@export var fire_scene: PackedScene

@export var homing_bullet_scene: PackedScene
@export var homing_bullet_chance: float = 0.45
@export var homing_bullet_count_min: int = 1
@export var homing_bullet_count_max: int = 1

@export var dive_chance: float = 0.35
@export var dive_speed: float = 520.0
@export var dive_prepare_time: float = 0.7
@export var dive_duration: float = 0.45
@export var dive_damage: float = 15.0
@export var dive_recover_time: float = 0.8
@export var dive_fire_chance: float = 0.6

@export var debug_enabled: bool = false

var hp: int
var player: Node2D = null

var state: State = State.CHASE

var _state_elapsed: float = 0.0
var _charge_cooldown_left: float = 0.0

var _locked_charge_direction: Vector2 = Vector2.RIGHT
var _retreat_direction: Vector2 = Vector2.LEFT
var _current_retreat_duration: float = 0.7

var _locked_dive_target: Vector2 = Vector2.ZERO
var _locked_dive_direction: Vector2 = Vector2.DOWN

var _is_enraged: bool = false
var _base_move_speed: float = 0.0
var _base_charge_speed: float = 0.0
var _base_charge_cooldown: float = 0.0

var _debug_last_logged_state: Variant = null
var _debug_chase_log_timer: float = 0.0

var _contact_damage_cooldown_left: float = 0.0
var _charge_hit_player: bool = false
var _dive_hit_player: bool = false


var _base_charge_cd_min: float
var _base_charge_cd_max: float
var _base_fire_chance: float
var _base_homing_chance: float

var _is_buffed: bool = false


func apply_buff(duration: float) -> void:
	if _is_buffed:
		return

	_is_buffed = true

	move_speed *= 1.3
	charge_speed *= 1.4

	modulate = Color(0.4, 0.7, 1.0)

	await get_tree().create_timer(duration).timeout

	move_speed /= 1.3
	charge_speed /= 1.4

	modulate = Color(1,1,1)
	_is_buffed = false


func _ready() -> void:
	hp = max_hp

	_base_move_speed = move_speed
	_base_charge_speed = charge_speed
	_base_charge_cd_min = charge_cooldown_min
	_base_charge_cd_max = charge_cooldown_max
	_base_fire_chance = fire_spawn_chance
	_base_homing_chance = homing_bullet_chance

	find_player()
	_charge_cooldown_left = _roll_charge_cooldown()


func enter_enraged_mode() -> void:
	if _is_enraged:
		return

	_is_enraged = true

	move_speed *= 1.4
	charge_speed *= 1.5

	charge_cooldown_min *= 0.6
	charge_cooldown_max *= 0.6

	fire_spawn_chance = min(1.0, _base_fire_chance + 0.3)
	homing_bullet_chance = min(1.0, _base_homing_chance + 0.3)

	modulate = Color(1, 0.25, 0.25)

	print("Boss3_Melee 狂暴🔥")


func _cache_base_stats() -> void:
	_base_move_speed = move_speed
	_base_charge_speed = charge_speed
	_base_charge_cooldown = charge_cooldown


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	if player == null or not is_instance_valid(player):
		find_player()
		if player == null:
			velocity = Vector2.ZERO
			move_and_slide()
			return

	match state:
		State.CHASE:
			_update_chase(delta)
		State.PREPARE_CHARGE:
			_update_prepare_charge(delta)
		State.CHARGE:
			_update_charge(delta)
		State.RETREAT:
			_update_retreat(delta)
		State.RECOVER:
			_update_recover(delta)
		State.PREPARE_DIVE:
			_update_prepare_dive(delta)
		State.DIVE:
			_update_dive(delta)
		State.DIVE_RECOVER:
			_update_dive_recover(delta)

	move_and_slide()

	if _contact_damage_cooldown_left > 0.0:
		_contact_damage_cooldown_left -= delta

	_try_deal_contact_damage()

	if _debug_last_logged_state == null or state != _debug_last_logged_state:
		_debug_last_logged_state = state
		if debug_enabled:
			print("Boss3_Melee state -> ", _debug_state_to_string(state))


func _update_chase(delta: float) -> void:
	var to_player: Vector2 = player.global_position - global_position
	var distance_sq: float = to_player.length_squared()
	var stop_distance_sq: float = chase_stop_distance * chase_stop_distance

	if distance_sq > stop_distance_sq and distance_sq > 0.0001:
		velocity = to_player.normalized() * move_speed
	else:
		velocity = Vector2.ZERO

	if debug_enabled:
		_debug_chase_log_timer += delta
		if _debug_chase_log_timer >= 0.5:
			_debug_chase_log_timer = 0.0
			var distance_to_player: float = sqrt(distance_sq)
			print(
				"Boss3_Melee CHASE: _charge_cooldown_left = ",
				_charge_cooldown_left,
				", distance_to_player = ",
				distance_to_player
			)

	_tick_charge_cooldown(delta)


func _tick_charge_cooldown(delta: float) -> void:
	_charge_cooldown_left -= delta
	if _charge_cooldown_left <= 0.0:
		_charge_cooldown_left = 0.0
		_start_prepare_charge()


func _start_prepare_charge() -> void:
	state = State.PREPARE_CHARGE
	_state_elapsed = 0.0
	velocity = Vector2.ZERO
	_set_sprite_modulate(SPRITE_COLOR_PREPARE_CHARGE)

	if debug_enabled:
		print("Enter PREPARE_CHARGE")

	var to_player: Vector2 = player.global_position - global_position
	if to_player.length_squared() > 0.0001:
		_locked_charge_direction = to_player.normalized()
	else:
		_locked_charge_direction = Vector2.RIGHT


func _update_prepare_charge(delta: float) -> void:
	velocity = Vector2.ZERO
	_state_elapsed += delta

	if _state_elapsed >= charge_prepare_time:
		state = State.CHARGE
		_state_elapsed = 0.0
		_charge_hit_player = false
		_set_sprite_modulate(SPRITE_COLOR_NORMAL)

		if debug_enabled:
			print("Enter CHARGE")


func _update_charge(delta: float) -> void:
	velocity = _locked_charge_direction * charge_speed
	_state_elapsed += delta

	if _state_elapsed >= charge_duration:
		_try_spawn_fire_at(global_position)
		_start_retreat()


func _start_retreat() -> void:
	var away_direction: Vector2 = Vector2.ZERO

	if player != null and is_instance_valid(player):
		var away_from_player: Vector2 = global_position - player.global_position
		if away_from_player.length_squared() > 0.0001:
			away_direction = away_from_player.normalized()

	if away_direction.length_squared() <= 0.0001:
		away_direction = -_locked_charge_direction
		if away_direction.length_squared() <= 0.0001:
			away_direction = Vector2.LEFT

	_retreat_direction = away_direction
	_current_retreat_duration = _roll_retreat_duration()

	state = State.RETREAT
	_state_elapsed = 0.0
	velocity = _retreat_direction * retreat_speed
	_set_sprite_modulate(SPRITE_COLOR_NORMAL)


func _update_retreat(delta: float) -> void:
	velocity = _retreat_direction * retreat_speed
	_state_elapsed += delta

	if _state_elapsed >= _current_retreat_duration:
		velocity = Vector2.ZERO

		if randf() <= dive_chance:
			_start_prepare_dive()
			return

		_try_fire_homing_bullets()

		state = State.RECOVER
		_state_elapsed = 0.0
		_set_sprite_modulate(SPRITE_COLOR_NORMAL)


func _update_recover(delta: float) -> void:
	velocity = Vector2.ZERO
	_state_elapsed += delta

	if _state_elapsed >= post_retreat_recover_time:
		state = State.CHASE
		_charge_cooldown_left = _roll_charge_cooldown()
		_set_sprite_modulate(SPRITE_COLOR_NORMAL)


func _start_prepare_dive() -> void:
	state = State.PREPARE_DIVE
	_state_elapsed = 0.0
	velocity = Vector2.ZERO
	_dive_hit_player = false
	_set_sprite_modulate(SPRITE_COLOR_PREPARE_DIVE)

	if player != null and is_instance_valid(player):
		_locked_dive_target = player.global_position
		var to_target: Vector2 = _locked_dive_target - global_position

		if to_target.length_squared() > 0.0001:
			_locked_dive_direction = to_target.normalized()
		else:
			_locked_dive_direction = _locked_charge_direction
	else:
		_locked_dive_target = global_position + _locked_charge_direction * 200.0
		_locked_dive_direction = _locked_charge_direction

	if _locked_dive_direction.length_squared() <= 0.0001:
		_locked_dive_direction = Vector2.DOWN

	if debug_enabled:
		print("Enter PREPARE_DIVE")


func _update_prepare_dive(delta: float) -> void:
	velocity = Vector2.ZERO
	_state_elapsed += delta

	if _state_elapsed >= dive_prepare_time:
		state = State.DIVE
		_state_elapsed = 0.0
		_dive_hit_player = false
		_set_sprite_modulate(SPRITE_COLOR_NORMAL)

		if debug_enabled:
			print("Enter DIVE")


func _update_dive(delta: float) -> void:
	velocity = _locked_dive_direction * dive_speed
	_state_elapsed += delta

	if not _dive_hit_player and _is_touching_player():
		_deal_dive_damage()
		_try_spawn_dive_fire_at(global_position)
		_start_dive_recover()
		return

	if _state_elapsed >= dive_duration:
		_try_spawn_dive_fire_at(global_position)
		_start_dive_recover()


func _deal_dive_damage() -> void:
	if player == null or not is_instance_valid(player):
		return

	if not player.has_method("take_damage"):
		return

	player.take_damage(float(dive_damage))
	_dive_hit_player = true

	if debug_enabled:
		print("Boss dive hit player, damage = ", dive_damage)


func _try_spawn_dive_fire_at(pos: Vector2) -> void:
	if randf() > dive_fire_chance:
		return

	_spawn_fire_at(pos)


func _start_dive_recover() -> void:
	state = State.DIVE_RECOVER
	_state_elapsed = 0.0
	velocity = Vector2.ZERO
	_set_sprite_modulate(SPRITE_COLOR_NORMAL)


func _update_dive_recover(delta: float) -> void:
	velocity = Vector2.ZERO
	_state_elapsed += delta

	if _state_elapsed >= dive_recover_time:
		state = State.CHASE
		_charge_cooldown_left = _roll_charge_cooldown()
		_set_sprite_modulate(SPRITE_COLOR_NORMAL)


func _set_sprite_modulate(color: Color) -> void:
	if _sprite != null:
		_sprite.modulate = color


func _roll_charge_cooldown() -> float:
	return randf_range(charge_cooldown_min, charge_cooldown_max)


func _roll_retreat_duration() -> float:
	return randf_range(retreat_duration_min, retreat_duration_max)


func _try_spawn_fire_at(pos: Vector2) -> void:
	if randf() > fire_spawn_chance:
		return

	_spawn_fire_at(pos)


func _try_fire_homing_bullets() -> void:
	if homing_bullet_scene == null:
		if debug_enabled:
			print("Boss3_Melee: homing_bullet_scene 尚未指定")
		return

	if randf() > homing_bullet_chance:
		return

	var bullet_count: int = randi_range(homing_bullet_count_min, homing_bullet_count_max)
	var spawn_pos: Vector2 = _get_bullet_spawn_position()

	for i in range(bullet_count):
		var bullet: Node = homing_bullet_scene.instantiate()
		get_tree().current_scene.add_child(bullet)

		var fire_direction: Vector2 = _get_homing_bullet_direction(spawn_pos)

		if bullet.has_method("setup"):
			bullet.setup(spawn_pos, fire_direction)


func _get_bullet_spawn_position() -> Vector2:
	var spawn_point: Node = get_node_or_null("BulletSpawnPoint")

	if spawn_point is Node2D:
		return (spawn_point as Node2D).global_position

	return global_position


func _get_homing_bullet_direction(from_pos: Vector2) -> Vector2:
	if player != null and is_instance_valid(player):
		var to_player: Vector2 = player.global_position - from_pos

		if to_player.length_squared() > 0.0001:
			return to_player.normalized()

	return Vector2.DOWN


func _try_deal_contact_damage() -> void:
	if state != State.CHARGE:
		return

	if _charge_hit_player:
		return

	if player == null or not is_instance_valid(player):
		return

	if _contact_damage_cooldown_left > 0.0:
		return

	if not _is_touching_player():
		return

	if not player.has_method("take_damage"):
		return

	player.take_damage(float(contact_damage))
	_charge_hit_player = true
	_contact_damage_cooldown_left = contact_damage_cooldown

	if debug_enabled:
		print("Boss charge hit player, damage = ", contact_damage)

	_try_spawn_fire_at(global_position)
	_start_retreat()


func _spawn_fire_at(pos: Vector2) -> void:
	if fire_scene == null:
		if debug_enabled:
			print("Boss3_Melee: fire_scene 尚未指定")
		return

	var fire: Node = fire_scene.instantiate()
	get_tree().current_scene.add_child(fire)

	if fire is Node2D:
		(fire as Node2D).global_position = pos


func _is_touching_player() -> bool:
	var boss_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D

	if boss_shape == null or boss_shape.shape == null:
		return global_position.distance_to(player.global_position) <= 24.0

	var hurtbox: Area2D = player.get_node_or_null("Hurtbox") as Area2D

	if hurtbox == null:
		return global_position.distance_to(player.global_position) <= 24.0

	var hurt_shape: CollisionShape2D = hurtbox.get_node_or_null("CollisionShape2D") as CollisionShape2D

	if hurt_shape == null or hurt_shape.shape == null:
		return global_position.distance_to(player.global_position) <= 24.0

	var boss_center: Vector2 = boss_shape.global_position
	var player_center: Vector2 = hurt_shape.global_position
	var touch_distance: float = _get_shape_radius(boss_shape) + _get_shape_radius(hurt_shape)

	return boss_center.distance_to(player_center) <= touch_distance


func _get_shape_radius(shape_node: CollisionShape2D) -> float:
	if shape_node.shape is CircleShape2D:
		var circle: CircleShape2D = shape_node.shape as CircleShape2D
		var shape_scale: Vector2 = shape_node.global_transform.get_scale()
		var radius: float = circle.radius * maxf(shape_scale.x, shape_scale.y)

		if radius > 0.001:
			return radius

	return 16.0


func find_player() -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")

	if debug_enabled:
		print("Boss3_Melee find_player: player group size = ", players.size())

	if players.size() > 0:
		player = players[0] as Node2D

		if debug_enabled:
			print("Boss3_Melee found player: ", players[0].name)
	else:
		if debug_enabled:
			print("Boss3_Melee cannot find player")


func _debug_state_to_string(s: State) -> String:
	match s:
		State.CHASE:
			return "CHASE"
		State.PREPARE_CHARGE:
			return "PREPARE_CHARGE"
		State.CHARGE:
			return "CHARGE"
		State.RETREAT:
			return "RETREAT"
		State.RECOVER:
			return "RECOVER"
		State.PREPARE_DIVE:
			return "PREPARE_DIVE"
		State.DIVE:
			return "DIVE"
		State.DIVE_RECOVER:
			return "DIVE_RECOVER"
		State.DEAD:
			return "DEAD"
		_:
			return str(s)


func take_damage(amount: int) -> void:
	if state == State.DEAD:
		return

	hp -= amount

	if debug_enabled:
		print("Boss3 近戰 HP:", hp)

	if hp <= 0:
		state = State.DEAD
		_set_sprite_modulate(SPRITE_COLOR_NORMAL)
		die()
		
func heal(amount: int) -> void:
	if state == State.DEAD:
		return

	hp = min(hp + amount, max_hp)

	if debug_enabled:
		print("Boss3 近戰 Heal:", amount, " HP:", hp)


func die() -> void:
	_set_sprite_modulate(SPRITE_COLOR_NORMAL)

	if debug_enabled:
		print("Boss3 近戰死亡")

	queue_free()
