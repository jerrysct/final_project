extends CharacterBody2D

enum State {
	CHASE,                  
	PREPARE_CRASH,          
	CRASH_HOMING,           
	CRASH_WARNING,          
	CRASH_SLIDE,            
	PREPARE_FIRE_CHARGE,    
	FIRE_CHARGE,            
	PREPARE_SHOTGUN_CHARGE, 
	SHOTGUN_CHARGE,         
	SHOOT_SHOTGUN,          
	RANGED_ATTACK,          
	RETREAT,                
	RECOVER,                
	DEAD,
}

const ENRAGED_MOVE_SPEED_MULT: float = 1.35
const ENRAGED_CHARGE_SPEED_MULT: float = 1.35

const SPRITE_COLOR_NORMAL: Color = Color(1, 1, 1)
const SPRITE_COLOR_PREPARE_CRASH: Color = Color(1.0, 0.35, 0.35)   
const SPRITE_COLOR_PREPARE_FIRE: Color = Color(1.0, 0.6, 0.1)      
const SPRITE_COLOR_PREPARE_SHOTGUN: Color = Color(1.0, 0.9, 0.2)   
const SPRITE_COLOR_PREPARE_RANGED: Color = Color(0.4, 0.8, 1.0)    

@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var roar_audio: AudioStreamPlayer2D = get_node_or_null("RoarAudio")

@export var max_hp: int = 300
@export var move_speed: float = 120.0
@export var chase_stop_distance: float = 120.0
@export var contact_damage: int = 10
@export var contact_damage_cooldown: float = 0.8
@export var attack_cooldown_min: float = 1.5
@export var attack_cooldown_max: float = 2.5

# ================= 招式參數設定 =================

# 1. 毀滅衝撞
@export var crash_prepare_time: float = 2.0             
@export var crash_homing_speed: float = 350.0           
@export var crash_stop_homing_distance: float = 180.0  
@export var crash_warning_time: float = 0.6             
@export var crash_aoe_radius: float = 160.0              
@export var crash_slide_speed: float = 450.0            
@export var crash_slide_duration: float = 0.25          
@export var crash_scene: PackedScene                    

# 2. 烈焰衝刺 (死亡彈珠)
@export var fire_charge_speed: float = 300.0
@export var fire_charge_prepare_time: float = 0.6
@export var fire_drop_interval: float = 0.05 
@export var fire_scene: PackedScene 
@export var dead_charge_max_bounces: int = 5
@export var fire_charge_shotgun_interval: float = 1.0 
@export var dead_charge_shotgun_bullet_speed: float = 350.0 

# 3. 衝刺散彈
@export var shotgun_charge_speed: float = 450.0
@export var shotgun_charge_prepare_time: float = 0.5
@export var shotgun_bullet_scene: PackedScene 
@export var shotgun_stop_distance: float = 120.0 
@export var shotgun_spread_angle: float = 60.0 
@export var shotgun_bullet_speed: float = 300.0 
@export var shotgun_wave_delay: float = 0.2 
@export var fire_charge_max_bounces: int = 3

# 4. 遠程攻擊 (追蹤彈)
@export var ranged_prepare_time: float = 0.5
@export var homing_bullet_scene: PackedScene
@export var homing_bullet_count_min: int = 2
@export var homing_bullet_count_max: int = 3

# 撤退與喘息
@export var retreat_speed: float = 300.0
@export var retreat_duration_min: float = 0.4
@export var retreat_duration_max: float = 0.9
@export var post_retreat_recover_time: float = 0.6

@export var debug_enabled: bool = false

# ================= 內部變數 =================
var hp: int
var player: Node2D = null
var state: State = State.CHASE

var _state_elapsed: float = 0.0
var _attack_cooldown_left: float = 0.0

var _locked_charge_direction: Vector2 = Vector2.RIGHT
var _retreat_direction: Vector2 = Vector2.LEFT
var _current_retreat_duration: float = 0.7

var _fire_drop_timer: float = 0.0
var _fire_charge_bounce_count: int = 0
var _fire_charge_shotgun_timer: float = 0.0

var _shotgun_charge_bounce_count: int = 0
var _shotgun_wave_count: int = 0
var _shotgun_shoot_timer: float = 0.0

var _crash_target_pos: Vector2 = Vector2.ZERO
var _warning_shadow_node: Node2D = null

var _is_enraged: bool = false
var _base_move_speed: float = 0.0
var _contact_damage_cooldown_left: float = 0.0
var _charge_hit_player: bool = false
var _is_buffed: bool = false
var _bounce_cooldown: float = 0.0 

func _ready() -> void:
	hp = max_hp
	_base_move_speed = move_speed
	find_player()
	_attack_cooldown_left = _roll_attack_cooldown()
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	
	if _anim:
		_anim.play("idle")
		_anim.animation_finished.connect(_on_animation_finished)

func _on_animation_finished() -> void:
	if _anim.animation == "attack":
		_anim.play("idle")

func apply_buff(duration: float) -> void:
	if _is_buffed: return
	_is_buffed = true
	move_speed *= 1.3
	modulate = Color(0.4, 0.7, 1.0)
	await get_tree().create_timer(duration).timeout
	move_speed /= 1.3
	modulate = Color(1,1,1)
	_is_buffed = false

func enter_enraged_mode() -> void:
	if _is_enraged: return
	_is_enraged = true
	move_speed *= 1.4
	attack_cooldown_min *= 0.6
	attack_cooldown_max *= 0.6
	modulate = Color(1, 0.25, 0.25)

func trigger_death_sequence(roar_stream: AudioStream) -> void:
	# 移除 if state == State.DEAD: return 以允許從死亡中恢復
	
	# 進入恢復/停止狀態，並鎖定時間防止自動切換
	state = State.RECOVER
	velocity = Vector2.ZERO
	_state_elapsed = -999.0 
	
	# 重新啟用碰撞與視覺
	var col = get_node_or_null("CollisionShape2D")
	if col:
		col.set_deferred("disabled", false)
	_set_sprite_modulate(SPRITE_COLOR_NORMAL)
	
	# 播放吼叫
	if roar_audio:
		roar_audio.stream = roar_stream
		roar_audio.play()
		await roar_audio.finished
	else:
		await get_tree().create_timer(2.0).timeout
	
	# 回血與狂暴
	hp = max_hp
	_state_elapsed = 0.0 # 重置時間
	enter_enraged_mode()
	
	# 固定施放一次烈焰衝刺 (FIRE_CHARGE)
	print("Boss3_Melee 狂暴序列完成，強制發動死亡彈珠")
	_start_prepare_fire_charge()
func _physics_process(delta: float) -> void:
	if state == State.DEAD: return

	if player == null or not is_instance_valid(player):
		find_player()
		if player == null:
			velocity = Vector2.ZERO
			move_and_slide()
			return

	if _bounce_cooldown > 0.0:
		_bounce_cooldown -= delta

	_face_player()

	match state:
		State.CHASE: _update_chase(delta)
		State.PREPARE_CRASH: _update_prepare_crash(delta)
		State.CRASH_HOMING: _update_crash_homing(delta)
		State.CRASH_WARNING: _update_crash_warning(delta)  
		State.CRASH_SLIDE: _update_crash_slide(delta)
		State.PREPARE_FIRE_CHARGE: _update_prepare_fire_charge(delta)
		State.FIRE_CHARGE: _update_fire_charge(delta)
		State.PREPARE_SHOTGUN_CHARGE: _update_prepare_shotgun_charge(delta)
		State.SHOTGUN_CHARGE: _update_shotgun_charge(delta)
		State.SHOOT_SHOTGUN: _update_shoot_shotgun(delta)
		State.RANGED_ATTACK: _update_ranged_attack(delta)
		State.RETREAT: _update_retreat(delta)
		State.RECOVER: _update_recover(delta)

	move_and_slide()

	if _contact_damage_cooldown_left > 0.0:
		_contact_damage_cooldown_left -= delta
	_try_deal_contact_damage()

func _face_player() -> void:
	if _anim == null or player == null or not is_instance_valid(player):
		return
	var player_is_left: bool = player.global_position.x < global_position.x
	_anim.flip_h = player_is_left

func _get_real_wall_normal() -> Vector2:
	if not is_on_wall(): return Vector2.ZERO
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider != null and not collider.is_in_group("player"):
			return collision.get_normal()
	return Vector2.ZERO

func _update_chase(delta: float) -> void:
	var to_player: Vector2 = player.global_position - global_position
	var distance_sq: float = to_player.length_squared()
	var stop_distance_sq: float = chase_stop_distance * chase_stop_distance

	if distance_sq > stop_distance_sq and distance_sq > 0.0001:
		velocity = to_player.normalized() * move_speed
	else:
		velocity = Vector2.ZERO

	_attack_cooldown_left -= delta
	if _attack_cooldown_left <= 0.0:
		_roll_next_attack()

func _roll_next_attack() -> void:
	velocity = Vector2.ZERO
	var is_melee: bool = randf() <= 0.7 
	
	if is_melee:
		var melee_roll = randf()
		if melee_roll <= 0.333: _start_prepare_crash()
		elif melee_roll <= 0.666: _start_prepare_fire_charge()
		else: _start_prepare_shotgun_charge()
	else:
		_start_ranged_attack()

func _start_prepare_crash() -> void:
	state = State.PREPARE_CRASH
	_state_elapsed = 0.0
	_set_sprite_modulate(SPRITE_COLOR_PREPARE_CRASH)
	if _anim: _anim.play("attack")
	if roar_audio != null and not roar_audio.playing:
		roar_audio.play()

func _update_prepare_crash(delta: float) -> void:
	_state_elapsed += delta
	if _state_elapsed >= crash_prepare_time:
		state = State.CRASH_HOMING
		_charge_hit_player = false
		_set_sprite_modulate(SPRITE_COLOR_NORMAL)

func _update_crash_homing(_delta: float) -> void:
	if player == null or not is_instance_valid(player): return
	var to_player: Vector2 = player.global_position - global_position
	var distance: float = to_player.length()
	if distance > crash_stop_homing_distance:
		_locked_charge_direction = to_player.normalized()
		velocity = _locked_charge_direction * crash_homing_speed
	else:
		state = State.CRASH_WARNING
		_state_elapsed = 0.0
		velocity = Vector2.ZERO 
		_locked_charge_direction = to_player.normalized()
		var slide_distance = crash_slide_speed * crash_slide_duration
		_crash_target_pos = global_position + _locked_charge_direction * slide_distance
		_spawn_warning_shadow(_crash_target_pos, crash_aoe_radius)

func _update_crash_warning(delta: float) -> void:
	velocity = Vector2.ZERO 
	_state_elapsed += delta
	if _state_elapsed >= crash_warning_time:
		state = State.CRASH_SLIDE
		_state_elapsed = 0.0
		velocity = _locked_charge_direction * crash_slide_speed

func _update_crash_slide(delta: float) -> void:
	_state_elapsed += delta
	velocity = _locked_charge_direction * crash_slide_speed
	var dist_to_target = global_position.distance_to(_crash_target_pos)
	if dist_to_target <= crash_slide_speed * delta or _state_elapsed >= crash_slide_duration or _get_real_wall_normal() != Vector2.ZERO:
		_execute_crash_impact()

func _execute_crash_impact() -> void:
	velocity = Vector2.ZERO 
	_remove_warning_shadow()
	if crash_scene != null:
		var crash_obj = crash_scene.instantiate()
		get_tree().current_scene.add_child(crash_obj)
		crash_obj.global_position = _crash_target_pos 
	await get_tree().create_timer(1.0).timeout
	if player != null and is_instance_valid(player):
		var to_player = player.global_position - global_position
		if to_player.length_squared() > 0.0001:
			_locked_charge_direction = to_player.normalized()
		_fire_shotgun_wave(0, true)
	_start_retreat()

func _spawn_warning_shadow(pos: Vector2, radius: float) -> void:
	_remove_warning_shadow() 
	_warning_shadow_node = Node2D.new()
	_warning_shadow_node.top_level = true 
	_warning_shadow_node.global_position = pos
	_warning_shadow_node.draw.connect(func():
		_warning_shadow_node.draw_circle(Vector2.ZERO, radius, Color(0, 0, 0, 0.5))
	)
	get_tree().current_scene.add_child(_warning_shadow_node)
	_warning_shadow_node.queue_redraw()

func _remove_warning_shadow() -> void:
	if _warning_shadow_node != null and is_instance_valid(_warning_shadow_node):
		_warning_shadow_node.queue_free()
		_warning_shadow_node = null

func _start_prepare_fire_charge() -> void:
	state = State.PREPARE_FIRE_CHARGE
	_state_elapsed = 0.0
	_set_sprite_modulate(SPRITE_COLOR_PREPARE_FIRE)
	if _anim: _anim.play("attack")
	if player != null and is_instance_valid(player):
		var to_player = player.global_position - global_position
		if to_player.length_squared() > 0.0001:
			_locked_charge_direction = to_player.normalized()
		else:
			_locked_charge_direction = Vector2.RIGHT
	else:
		_locked_charge_direction = Vector2.RIGHT
	_fire_drop_timer = 0.0
	_fire_charge_bounce_count = 0

func _update_prepare_fire_charge(delta: float) -> void:
	_state_elapsed += delta
	if _state_elapsed >= fire_charge_prepare_time:
		state = State.FIRE_CHARGE
		_state_elapsed = 0.0 
		_charge_hit_player = false
		_set_sprite_modulate(SPRITE_COLOR_NORMAL)
		_fire_charge_shotgun_timer = 0.0 
		_bounce_cooldown = 0.0

func _update_fire_charge(delta: float) -> void:
	_state_elapsed += delta
	_fire_drop_timer -= delta
	if _fire_drop_timer <= 0.0:
		_spawn_fire_at(global_position)
		_fire_drop_timer = fire_drop_interval
	if _is_enraged:
		_fire_charge_shotgun_timer -= delta
		if _fire_charge_shotgun_timer <= 0.0:
			_fire_enraged_bouncing_shotgun()
			_fire_charge_shotgun_timer = fire_charge_shotgun_interval
	var move_vec = _locked_charge_direction * fire_charge_speed * delta
	var collision = move_and_collide(move_vec)
	if collision:
		var wall_normal = collision.get_normal()
		var collider = collision.get_collider()
		if collider != null and not collider.is_in_group("player"):
			_fire_charge_bounce_count += 1
			if _fire_charge_bounce_count >= dead_charge_max_bounces:
				_start_retreat()
			else:
				var target_dir = _locked_charge_direction.bounce(wall_normal).normalized()
				if player != null and is_instance_valid(player):
					var predicted_pos = player.global_position + player.velocity * 1.0
					target_dir = (predicted_pos - global_position).normalized()
					if target_dir.dot(wall_normal) < 0.1:
						target_dir = _locked_charge_direction.bounce(wall_normal).normalized()
				_locked_charge_direction = target_dir
				global_position += wall_normal * 2.0
		else:
			_try_deal_contact_damage()
			_start_retreat()
	velocity = Vector2.ZERO

func _fire_enraged_bouncing_shotgun() -> void:
	if shotgun_bullet_scene == null: return
	var base_fire_dir = _locked_charge_direction
	if player != null and is_instance_valid(player):
		var to_player = player.global_position - global_position
		if to_player.length_squared() > 0.0001:
			base_fire_dir = to_player.normalized()
	var bullet_count: int = 5
	var total_angle_rad: float = deg_to_rad(shotgun_spread_angle)
	var angle_step: float = total_angle_rad / 4.0
	var start_angle: float = -total_angle_rad / 2.0
	for i in range(bullet_count):
		var bullet: Node = shotgun_bullet_scene.instantiate()
		get_tree().current_scene.add_child(bullet)
		var current_angle: float = start_angle + (i * angle_step)
		var fire_direction: Vector2 = base_fire_dir.rotated(current_angle)
		if bullet is Node2D:
			bullet.global_position = global_position
			bullet.rotation = fire_direction.angle()
		if "color_type" in bullet and bullet.has_method("setup"):
			bullet.setup(3, fire_direction)
			bullet.modulate = Color(1.0, 0.5, 0.0)
			if "speed" in bullet: bullet.speed = dead_charge_shotgun_bullet_speed
			if "max_bounces" in bullet: bullet.max_bounces = 3
		else:
			if bullet.has_method("setup"): bullet.setup(global_position, fire_direction)
			if "speed" in bullet: bullet.speed = dead_charge_shotgun_bullet_speed
			if "max_bounces" in bullet: bullet.max_bounces = 3

func _start_prepare_shotgun_charge() -> void:
	state = State.PREPARE_SHOTGUN_CHARGE
	_state_elapsed = 0.0
	_set_sprite_modulate(SPRITE_COLOR_PREPARE_SHOTGUN)
	if _anim: _anim.play("attack")
	_lock_direction_to_player()
	_shotgun_charge_bounce_count = 0

func _update_prepare_shotgun_charge(delta: float) -> void:
	_state_elapsed += delta
	if _state_elapsed >= shotgun_charge_prepare_time:
		state = State.SHOTGUN_CHARGE
		_state_elapsed = 0.0
		_charge_hit_player = false
		_set_sprite_modulate(SPRITE_COLOR_NORMAL)

func _update_shotgun_charge(delta: float) -> void:
	_state_elapsed += delta
	var dist_to_player: float = 9999.0
	if player != null and is_instance_valid(player):
		dist_to_player = global_position.distance_to(player.global_position)
	if dist_to_player <= shotgun_stop_distance:
		_start_shoot_shotgun()
		return
	var move_vec = _locked_charge_direction * shotgun_charge_speed * delta
	var collision = move_and_collide(move_vec)
	if collision:
		var wall_normal = collision.get_normal()
		var collider = collision.get_collider()
		if collider != null and not collider.is_in_group("player"):
			_shotgun_charge_bounce_count += 1
			if _shotgun_charge_bounce_count >= fire_charge_max_bounces:
				_start_shoot_shotgun()
			else:
				var target_dir = _locked_charge_direction.bounce(wall_normal).normalized()
				if player != null and is_instance_valid(player):
					target_dir = (player.global_position + player.velocity * 1.0 - global_position).normalized()
					if target_dir.dot(wall_normal) < 0.1:
						target_dir = _locked_charge_direction.bounce(wall_normal).normalized()
				_locked_charge_direction = target_dir
				global_position += wall_normal * 2.0
		else:
			_try_deal_contact_damage()
			_start_shoot_shotgun()
	velocity = Vector2.ZERO

func _start_shoot_shotgun() -> void:
	state = State.SHOOT_SHOTGUN
	_state_elapsed = 0.0
	velocity = Vector2.ZERO 
	_shotgun_wave_count = 0
	_shotgun_shoot_timer = 0.0 
	if player != null and is_instance_valid(player):
		var to_player = player.global_position - global_position
		if to_player.length_squared() > 0.0001:
			_locked_charge_direction = to_player.normalized()

func _update_shoot_shotgun(delta: float) -> void:
	_shotgun_shoot_timer -= delta
	if _shotgun_shoot_timer <= 0.0 and _shotgun_wave_count < 3:
		_fire_shotgun_wave(_shotgun_wave_count)
		_shotgun_wave_count += 1
		_shotgun_shoot_timer = shotgun_wave_delay
	if _shotgun_wave_count >= 3 and _shotgun_shoot_timer <= -0.3:
		_start_retreat()

func _fire_shotgun_wave(wave_index: int, make_unparryable: bool = false) -> void:
	if shotgun_bullet_scene == null: return
	var is_second_wave: bool = (wave_index == 1)
	var bullet_count: int = 4 if is_second_wave else 5
	var total_angle_rad: float = deg_to_rad(shotgun_spread_angle)
	var angle_step: float = total_angle_rad / 4.0
	var start_angle: float = -total_angle_rad / 2.0
	if is_second_wave:
		start_angle += angle_step / 2.0
	for i in range(bullet_count):
		var bullet: Node = shotgun_bullet_scene.instantiate()
		get_tree().current_scene.add_child(bullet)
		var current_angle: float = start_angle + (i * angle_step)
		var fire_direction: Vector2 = _locked_charge_direction.rotated(current_angle)
		var spawn_pos: Vector2 = global_position
		if bullet is Node2D:
			bullet.global_position = spawn_pos
			bullet.rotation = fire_direction.angle()
		if "color_type" in bullet and bullet.has_method("setup"):
			bullet.setup(3, fire_direction)
			bullet.modulate = Color(1.0, 0.5, 0.0)
			if "speed" in bullet: bullet.speed = shotgun_bullet_speed
		else:
			if bullet.has_method("setup"):
				bullet.setup(spawn_pos, fire_direction)
		if make_unparryable:
			bullet.set("cannot_parry", true)

func _start_ranged_attack() -> void:
	state = State.RANGED_ATTACK
	_state_elapsed = 0.0
	velocity = Vector2.ZERO
	_set_sprite_modulate(SPRITE_COLOR_PREPARE_RANGED)
	if _anim: _anim.play("attack")

func _update_ranged_attack(delta: float) -> void:
	_state_elapsed += delta
	if _state_elapsed >= ranged_prepare_time:
		_try_fire_homing_bullets()
		_set_sprite_modulate(SPRITE_COLOR_NORMAL)
		_start_retreat()

func _try_fire_homing_bullets() -> void:
	if homing_bullet_scene == null: return
	var bullet_count: int = 5
	var spawn_pos: Vector2 = global_position
	var spawn_point: Node = get_node_or_null("BulletSpawnPoint")
	if spawn_point is Node2D: spawn_pos = (spawn_point as Node2D).global_position
	var base_dir = Vector2.DOWN
	if player != null and is_instance_valid(player):
		var to_player = player.global_position - spawn_pos
		if to_player.length_squared() > 0.0001:
			base_dir = to_player.normalized()
	var spread_angle = deg_to_rad(140.0)
	var angle_step = spread_angle / (bullet_count - 1)
	var start_angle = -spread_angle / 2.0
	for i in range(bullet_count):
		var bullet: Node = homing_bullet_scene.instantiate()
		get_tree().current_scene.add_child(bullet)
		var current_angle = start_angle + (i * angle_step)
		var fire_direction = base_dir.rotated(current_angle)
		if bullet is Node2D:
			bullet.global_position = spawn_pos
			bullet.rotation = fire_direction.angle()
		if bullet.has_method("setup"):
			bullet.setup(spawn_pos, fire_direction)
		
		# 👈 【新增】：讓追蹤彈不可普通反彈
		bullet.set("cannot_parry", true)

func _start_retreat() -> void:
	var away_direction: Vector2 = Vector2.LEFT
	if player != null and is_instance_valid(player):
		var away_from_player: Vector2 = global_position - player.global_position
		if away_from_player.length_squared() > 0.0001:
			away_direction = away_from_player.normalized()
	_retreat_direction = away_direction
	_current_retreat_duration = randf_range(retreat_duration_min, retreat_duration_max)
	state = State.RETREAT
	_state_elapsed = 0.0
	velocity = _retreat_direction * retreat_speed
	_set_sprite_modulate(SPRITE_COLOR_NORMAL)

func _update_retreat(delta: float) -> void:
	velocity = _retreat_direction * retreat_speed
	_state_elapsed += delta
	if _state_elapsed >= _current_retreat_duration:
		state = State.RECOVER
		_state_elapsed = 0.0
		velocity = Vector2.ZERO

func _update_recover(delta: float) -> void:
	velocity = Vector2.ZERO
	_state_elapsed += delta
	if _state_elapsed >= post_retreat_recover_time:
		state = State.CHASE
		_attack_cooldown_left = _roll_attack_cooldown()

func _lock_direction_to_player() -> void:
	if player != null and is_instance_valid(player):
		var to_player: Vector2 = player.global_position - global_position
		if to_player.length_squared() > 0.0001:
			_locked_charge_direction = to_player.normalized()
			return
	_locked_charge_direction = Vector2.RIGHT

func _set_sprite_modulate(color: Color) -> void:
	if _anim != null: _anim.modulate = color

func _roll_attack_cooldown() -> float:
	return randf_range(attack_cooldown_min, attack_cooldown_max)

func _try_deal_contact_damage() -> void:
	if state not in [State.CRASH_HOMING, State.CRASH_SLIDE, State.FIRE_CHARGE, State.SHOTGUN_CHARGE]: return
	if _charge_hit_player: return
	if player == null or not is_instance_valid(player): return
	if _contact_damage_cooldown_left > 0.0: return
	if not _is_touching_player(): return
	if not player.has_method("take_damage"): return
	player.take_damage(float(contact_damage))
	if state in [State.CRASH_HOMING, State.CRASH_SLIDE] and player.has_method("apply_slow_debuff"):
		player.apply_slow_debuff(0.5, 5.0)
	_charge_hit_player = true
	_contact_damage_cooldown_left = contact_damage_cooldown
	if state == State.SHOTGUN_CHARGE: _start_retreat()

func _spawn_fire_at(pos: Vector2) -> void:
	if fire_scene == null: return
	var fire: Node = fire_scene.instantiate()
	if _is_enraged and "lifetime" in fire: fire.lifetime = 20.0
	get_tree().current_scene.add_child(fire)
	if fire is Node2D: (fire as Node2D).global_position = pos

func _is_touching_player() -> bool:
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider != null and collider.is_in_group("player"): return true
	if player != null and is_instance_valid(player):
		if global_position.distance_to(player.global_position) <= 90.0: return true
	return false

func find_player() -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.size() > 0: player = players[0] as Node2D

func take_damage(amount: int) -> void:
	if state == State.DEAD: return
	hp = max(0, hp - amount)
	if hp <= 0:
		state = State.DEAD
		_remove_warning_shadow() 
		_set_sprite_modulate(SPRITE_COLOR_NORMAL)
		die()
		
func heal(amount: int) -> void:
	if state == State.DEAD: return
	hp = min(hp + amount, max_hp)

func die() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	_set_sprite_modulate(SPRITE_COLOR_NORMAL)
	
	# 停止計時器與邏輯
	var attack_timer = get_node_or_null("AttackTimer")
	if attack_timer: attack_timer.stop()
	var charge_timer = get_node_or_null("ChargeTimer")
	if charge_timer: charge_timer.stop()
	
	# 禁用碰撞
	var col = get_node_or_null("CollisionShape2D")
	if col:
		col.set_deferred("disabled", true)
	
	if _anim:
		_anim.play("death")
	
	print("Boss3_Melee 已死亡並顯示死亡圖片")
