extends CharacterBody2D

# --- 節點引用 ---
@onready var health_bar: ProgressBar = null
@onready var hp_label: Label = null
@onready var stamina_bar: ProgressBar = null
@onready var stamina_label: Label = null
@onready var mp_bar: ProgressBar = null
@onready var mp_label: Label = null

@onready var bounce_zone: Area2D = $BounceZone
@onready var bounce_collision: CollisionShape2D = $BounceZone/CollisionShape2D
@onready var aim_line: Line2D = $AimLine

# 【修正】將外殼容器與圖片本體分開抓取！
@onready var sprite_container: Node2D = $SpriteContainer
@onready var sprite: Sprite2D = $SpriteContainer/Sprite2D

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var skill_indicator: Node2D = $SkillIndicator
@onready var release_burst_particles: CPUParticles2D = $ReleaseBurstParticles
@onready var head_bullet_display: Node2D = $HeadBulletDisplay

# --- 道具 UI 標籤引用 ---
@onready var btn_hp_label: Label = get_node_or_null("CanvasLayer/HBoxContainer/BtnHP/Label")
@onready var btn_stamina_label: Label = get_node_or_null("CanvasLayer/HBoxContainer/BtnStamina/Label")
@onready var btn_mp_label: Label = get_node_or_null("CanvasLayer/HBoxContainer/BtnMP/Label")
@onready var btn_invincible_label: Label = get_node_or_null("CanvasLayer/HBoxContainer/BtnInvincible/Label")

# --- 技能冷卻與範圍設定 ---
@export var parry_cooldown: float = 1.0  
@export var absorb_cooldown: float = 1.5 
@export var dash_cooldown: float = 0.5   

@export var parry_inner_radius: float = 50.0 
@export var parry_outer_radius: float = 300.0

# --- 控制「玩家頭上子彈圖示」 ---
@export var head_icon_scale: Vector2 = Vector2(0.05, 0.05)
@export var bullet_spacing_head: float = 12.0

# --- 內部計時與狀態變數 ---
var parry_cd_timer: float = 0.0
var absorb_cd_timer: float = 0.0
var dash_cd_timer: float = 0.0

var current_hp: float
var current_stamina: float
var current_mp: float

var is_invincible := false
var is_dashing := false
var is_parry_preparing := false
var is_absorb_preparing := false
var is_aiming := false

var captured_bullets: Array = []
var move_speed_multiplier: float = 1.0

# --- 無限狀態變數 ---
var has_infinite_stamina: bool = false
var has_infinite_mp: bool = false

# --- 灼燒狀態變數 ---
var burn_time_left: float = 0.0
var burn_tick_timer: float = 0.0
var burn_damage: float = 0.0
var burn_interval: float = 1.0

# --- 緩速狀態變數 ---
var slow_debuff_timer: float = 0.0
var slow_multiplier: float = 1.0

var reverse_input_enabled: bool = false
var _reverse_input_token: int = 0

# --- 用於偽走路動畫的時間變數 ---
var walk_time: float = 0.0

func _ready() -> void:
	# 玩家本身如果還有舊 CanvasLayer，就先隱藏，避免和 BossRoom / BossRoom3 的 UI 重疊。
	var own_canvas: CanvasLayer = get_node_or_null("CanvasLayer") as CanvasLayer
	if own_canvas != null:
		own_canvas.visible = false

	_find_ui_nodes()

	z_index = 6

	current_hp = Playerdata_Globle.max_hp
	current_stamina = Playerdata_Globle.max_stamina
	current_mp = Playerdata_Globle.max_mp

	if bounce_collision and bounce_collision.shape is CircleShape2D:
		bounce_collision.shape = bounce_collision.shape.duplicate() 
		bounce_collision.shape.radius = parry_outer_radius

	# UI 設定
	if health_bar:
		health_bar.max_value = Playerdata_Globle.max_hp
		health_bar.value = current_hp
		health_bar.show_percentage = false
	if hp_label: hp_label.text = "%d / %d" % [current_hp, Playerdata_Globle.max_hp]
	if stamina_bar:
		stamina_bar.max_value = Playerdata_Globle.max_stamina
		stamina_bar.value = current_stamina
		stamina_bar.show_percentage = false
	if stamina_label: stamina_label.text = "%d / %d" % [current_stamina, Playerdata_Globle.max_stamina]
	if mp_bar:
		mp_bar.max_value = Playerdata_Globle.max_mp
		mp_bar.value = current_mp
		mp_bar.show_percentage = false
	if mp_label: mp_label.text = "%d / %d" % [current_mp, Playerdata_Globle.max_mp]

	if sprite: sprite.visible = true
	
	if aim_line:
		aim_line.visible = false
		aim_line.top_level = true
		aim_line.position = Vector2.ZERO
		aim_line.clear_points()
		aim_line.add_point(Vector2.ZERO)
		aim_line.add_point(Vector2.ZERO)

	if skill_indicator:
		skill_indicator.top_level = true
		skill_indicator.z_index = 50

	if release_burst_particles:
		release_burst_particles.top_level = true
		release_burst_particles.z_index = 51

	if head_bullet_display:
		head_bullet_display.top_level = true
		head_bullet_display.z_index = 52

	_sync_effect_nodes_position()
	_update_player_ui()

	print("遊戲剛開始，Global 的消耗數值是: ", Playerdata_Globle.absorb_mp_cost)


func _find_ui_nodes() -> void:
	var scene_root: Node = get_tree().current_scene

	# 優先找 BossRoom / BossRoom3 的 CanvasLayer。
	if scene_root != null:
		health_bar = scene_root.get_node_or_null("CanvasLayer/HealthBar") as ProgressBar
		hp_label = scene_root.get_node_or_null("CanvasLayer/HealthBar/Label") as Label
		stamina_bar = scene_root.get_node_or_null("CanvasLayer/ProgressBar") as ProgressBar
		stamina_label = scene_root.get_node_or_null("CanvasLayer/ProgressBar/Label") as Label
		mp_bar = scene_root.get_node_or_null("CanvasLayer/MPBar") as ProgressBar
		mp_label = scene_root.get_node_or_null("CanvasLayer/MPBar/Label") as Label

		btn_hp_label = scene_root.get_node_or_null("CanvasLayer/HBoxContainer/BtnHP/Label") as Label
		btn_stamina_label = scene_root.get_node_or_null("CanvasLayer/HBoxContainer/BtnStamina/Label") as Label
		btn_mp_label = scene_root.get_node_or_null("CanvasLayer/HBoxContainer/BtnMP/Label") as Label
		btn_invincible_label = scene_root.get_node_or_null("CanvasLayer/HBoxContainer/BtnInvincible/Label") as Label

	# 如果房間 UI 找不到，才回頭找玩家自己底下的 UI。
	if health_bar == null:
		health_bar = get_node_or_null("CanvasLayer/HealthBar") as ProgressBar
	if hp_label == null:
		hp_label = get_node_or_null("CanvasLayer/HealthBar/Label") as Label

	if stamina_bar == null:
		stamina_bar = get_node_or_null("CanvasLayer/ProgressBar") as ProgressBar
	if stamina_label == null:
		stamina_label = get_node_or_null("CanvasLayer/ProgressBar/Label") as Label

	if mp_bar == null:
		mp_bar = get_node_or_null("CanvasLayer/MPBar") as ProgressBar
	if mp_label == null:
		mp_label = get_node_or_null("CanvasLayer/MPBar/Label") as Label

	if btn_hp_label == null:
		btn_hp_label = get_node_or_null("CanvasLayer/HBoxContainer/BtnHP/Label") as Label
	if btn_stamina_label == null:
		btn_stamina_label = get_node_or_null("CanvasLayer/HBoxContainer/BtnStamina/Label") as Label
	if btn_mp_label == null:
		btn_mp_label = get_node_or_null("CanvasLayer/HBoxContainer/BtnMP/Label") as Label
	if btn_invincible_label == null:
		btn_invincible_label = get_node_or_null("CanvasLayer/HBoxContainer/BtnInvincible/Label") as Label


func _get_hp_text() -> String:
	return str(int(current_hp)) + " / " + str(int(Playerdata_Globle.max_hp))


func _get_stamina_text() -> String:
	return str(int(current_stamina)) + " / " + str(int(Playerdata_Globle.max_stamina))


func _get_mp_text() -> String:
	return str(int(current_mp)) + " / " + str(int(Playerdata_Globle.max_mp))


func _update_player_ui() -> void:
	if health_bar:
		health_bar.max_value = Playerdata_Globle.max_hp
		health_bar.value = current_hp
	if hp_label:
		hp_label.text = _get_hp_text()

	if stamina_bar:
		stamina_bar.max_value = Playerdata_Globle.max_stamina
		stamina_bar.value = current_stamina
	if stamina_label:
		stamina_label.text = _get_stamina_text()

	if mp_bar:
		mp_bar.max_value = Playerdata_Globle.max_mp
		mp_bar.value = current_mp
	if mp_label:
		mp_label.text = _get_mp_text()

	if btn_hp_label:
		btn_hp_label.text = str(Playerdata_Globle.hp_potion)
	if btn_stamina_label:
		btn_stamina_label.text = str(Playerdata_Globle.stamina_potion)
	if btn_mp_label:
		btn_mp_label.text = str(Playerdata_Globle.mp_potion)
	if btn_invincible_label:
		btn_invincible_label.text = str(Playerdata_Globle.invincible)


func _sync_effect_nodes_position() -> void:
	var feet_offset: Vector2 = Vector2(1.2000008, -0.79999924)

	if skill_indicator:
		skill_indicator.global_position = global_position + feet_offset
	if release_burst_particles:
		release_burst_particles.global_position = global_position + feet_offset

	var head_offset: Vector2 = Vector2(0, -32)
	if head_bullet_display:
		head_bullet_display.global_position = global_position + head_offset


func _physics_process(delta: float) -> void:
	_sync_effect_nodes_position()
	handle_resources(delta)

	# --- 計時器 ---
	if parry_cd_timer > 0: parry_cd_timer -= delta
	if absorb_cd_timer > 0: absorb_cd_timer -= delta
	if dash_cd_timer > 0: dash_cd_timer -= delta

	# --- 負面狀態 ---
	if burn_time_left > 0.0:
		burn_time_left -= delta
		burn_tick_timer -= delta
		if burn_tick_timer <= 0.0:
			take_damage(burn_damage)
			burn_tick_timer = burn_interval
		if burn_time_left <= 0.0:
			if sprite and not is_invincible:
				sprite.modulate = Color.WHITE

	if slow_debuff_timer > 0.0:
		slow_debuff_timer -= delta
		if slow_debuff_timer <= 0.0:
			slow_multiplier = 1.0

	# --- 移動 ---
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if reverse_input_enabled:
		direction = -direction
	handle_movement(direction)

	# --- 動作判定 ---
	if Input.is_action_pressed("parry") and parry_cd_timer <= 0.0 and not is_absorb_preparing and not is_aiming:
		if not is_parry_preparing:
			is_parry_preparing = true
	else:
		if is_parry_preparing:
			execute_instant_parry()
			is_parry_preparing = false
			parry_cd_timer = parry_cooldown

	if Input.is_action_pressed("absorb") and absorb_cd_timer <= 0.0 and not is_parry_preparing and not is_aiming:
		is_absorb_preparing = true
		execute_absorb_action()
	else:
		if is_absorb_preparing:
			is_absorb_preparing = false
			absorb_cd_timer = absorb_cooldown

	if not is_parry_preparing and not is_absorb_preparing:
		handle_aim_and_release()
		
	# --- 視覺與動畫 ---
	if velocity.x > 0:
		sprite.flip_h = false 
	elif velocity.x < 0:
		sprite.flip_h = true  
		
	if not is_dashing:
		if velocity != Vector2.ZERO:
			walk_time += delta * 12.0
			sprite_container.position.y = sin(walk_time) * 3.0
			sprite_container.rotation = sin(walk_time * 0.5) * 0.02
		else:
			walk_time = 0.0
			sprite_container.position.y = lerp(sprite_container.position.y, 0.0, 0.2)
			sprite_container.rotation = lerp(sprite_container.rotation, 0.0, 0.2)
		
	if skill_indicator:
		skill_indicator.is_parry_preparing = is_parry_preparing
		skill_indicator.is_absorb_preparing = is_absorb_preparing
		skill_indicator.is_aiming = is_aiming
		skill_indicator.inner_radius = parry_inner_radius 
		skill_indicator.outer_radius = parry_outer_radius 
		skill_indicator.aim_angle = (get_global_mouse_position() - global_position).angle()
		skill_indicator.queue_redraw()

	_update_player_ui()
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("use_item_1"):
		use_hp_potion()
	elif event.is_action_pressed("use_item_2"):
		use_stamina_potion()
	elif event.is_action_pressed("use_item_3"):
		use_mp_potion()
	elif event.is_action_pressed("use_item_4"):
		use_invincible_potion()


func _on_hurtbox_area_entered(area: Area2D) -> void:
	if is_parry_preparing or is_absorb_preparing or is_invincible:
		return
	if not area.has_method("reflect"):
		return
	if area.get("is_reflected") or area.get("is_absorbed"):
		return

	var damage_value = area.get("damage")
	var damage_amount: float = 10.0

	if damage_value != null:
		damage_amount = float(damage_value)

	take_damage(damage_amount)
	area.call_deferred("queue_free")

func take_damage(amount: float) -> void:
	if is_invincible: return

	current_hp -= amount
	current_hp = maxf(current_hp, 0.0)
	_update_player_ui()
	play_hit_effect()

	if current_hp <= 0.0:
		await get_tree().create_timer(0.6).timeout
		var room: Node = get_parent()
		if room != null and room.has_method("show_defeat"):
			room.show_defeat()
		else:
			get_tree().call_deferred("reload_current_scene")

func play_hit_effect() -> void:
	if sprite == null: return

	is_invincible = true
	var tween := create_tween()
	# 受擊變色一樣要針對圖片本體 (sprite)
	tween.tween_property(sprite, "modulate", Color.RED, 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	tween.set_loops(3)

	await get_tree().create_timer(0.6).timeout

	if burn_time_left > 0.0:
		sprite.modulate = Color(1.0, 0.5, 0.0)
	else:
		sprite.modulate = Color.WHITE

	is_invincible = false


func apply_burn(duration: float, damage_per_tick: int, tick_interval: float) -> void:
	if is_invincible:
		print("🛡️ 玩家處於無敵狀態，免疫灼燒！")
		return

	burn_time_left = maxf(burn_time_left, duration)
	burn_damage = float(damage_per_tick)
	burn_interval = tick_interval
	burn_tick_timer = tick_interval

	if sprite:
		sprite.modulate = Color(1.0, 0.5, 0.0)

	print("🔥 玩家遭到灼燒！持續 ", duration, " 秒，每 ", tick_interval, " 秒扣 ", damage_per_tick, " 滴血！")


func apply_slow_debuff(multiplier: float, duration: float) -> void:
	slow_multiplier = multiplier
	slow_debuff_timer = duration
	print("❄️ 玩家遭到緩速！速度降低 ", (1.0 - multiplier) * 100, "%，持續 ", duration, " 秒")


func execute_instant_parry() -> void:
	if anim_player: anim_player.play("player_attack")
	if bounce_zone == null: return

	# 取得滑鼠當前相對於玩家的方向向量
	var aim_dir: Vector2 = (get_global_mouse_position() - global_position).normalized()

	for area in bounce_zone.get_overlapping_areas():
		if not area.has_method("reflect"): continue
		if area.get("is_reflected") or area.get("is_absorbed"): continue
		if area.get("cannot_parry") == true: continue # 👈 【新增】跳過不可普通反彈的子彈

		var distance_to_bullet = global_position.distance_to(area.global_position)
		if distance_to_bullet < parry_inner_radius or distance_to_bullet > parry_outer_radius:
			continue 

		# --- 半圓範圍判定 ---
		var dir_to_bullet: Vector2 = (area.global_position - global_position).normalized()
		if dir_to_bullet.dot(aim_dir) <= 0.0:
			continue
		# --------------------

		# 直接將反彈方向設定為玩家當前的瞄準方向 (滑鼠方向)
		var reflect_dir: Vector2 = aim_dir

		area.reflect(reflect_dir, 1.5)

func execute_absorb_action() -> void:
	if bounce_zone == null: return
	
	# 取得滑鼠當前相對於玩家的方向向量
	var aim_dir: Vector2 = (get_global_mouse_position() - global_position).normalized()
	
	for area in bounce_zone.get_overlapping_areas():
		if not area.has_method("reflect"):
			continue
		if area.get("is_reflected") or area.get("is_absorbed"):
			continue
		if "can_be_absorbed" in area and area.can_be_absorbed == false:
			continue
			
		# --- 半圓範圍判定 ---
		var dir_to_bullet: Vector2 = (area.global_position - global_position).normalized()
		if dir_to_bullet.dot(aim_dir) <= 0.0:
			continue
		# --------------------
			
		if captured_bullets.size() >= Playerdata_Globle.max_bullet_storage:
			break

		absorb_bullet(area)

func absorb_bullet(bullet: Node) -> void:
	if captured_bullets.has(bullet): return
	captured_bullets.append(bullet)

	var original_global_scale: Vector2 = Vector2.ONE
	if bullet is Node2D:
		original_global_scale = (bullet as Node2D).global_scale

	var scene_root: Node = get_tree().current_scene
	if scene_root != null and bullet.get_parent() != scene_root:
		var bullet_2d: Node2D = bullet as Node2D
		var global_pos: Vector2 = Vector2.ZERO

		if bullet_2d != null:
			global_pos = bullet_2d.global_position

		bullet.reparent(scene_root)

		if bullet_2d != null:
			bullet_2d.global_position = global_pos
			bullet_2d.global_scale = original_global_scale

	if "is_absorbed" in bullet:
		bullet.is_absorbed = true

	bullet.process_mode = Node.PROCESS_MODE_DISABLED
	bullet.visible = false
	bullet.set_deferred("monitorable", false)
	bullet.set_deferred("monitoring", false)
	_add_bullet_to_ui(bullet)

func _add_bullet_to_ui(bullet: Node) -> void:
	if head_bullet_display == null:
		return

	var icon: Sprite2D = Sprite2D.new()
	var bullet_sprite: Node = bullet.get_node_or_null("Sprite2D")

	if bullet_sprite is Sprite2D:
		icon.texture = (bullet_sprite as Sprite2D).texture
		icon.modulate = (bullet_sprite as Sprite2D).modulate

		if icon.texture != null:
			# 直接套用你在 Inspector 裡設定的 head_icon_scale
			icon.scale = head_icon_scale

	head_bullet_display.add_child(icon)
	_arrange_headshot_bullets()

func _arrange_headshot_bullets() -> void:
	if head_bullet_display == null:
		return

	var num_bullets: int = head_bullet_display.get_child_count()
	if num_bullets == 0:
		return

	for i in range(num_bullets):
		var child: Sprite2D = head_bullet_display.get_child(i) as Sprite2D
		if child == null:
			continue

		var target_x: float = float(i - 1) * bullet_spacing_head
		child.position = Vector2(target_x, 0)

func handle_movement(direction: Vector2) -> void:
	if Input.is_action_just_pressed("dash") and direction != Vector2.ZERO \
			and (has_infinite_stamina or current_stamina >= Playerdata_Globle.dash_stamina_cost) \
			and dash_cd_timer <= 0.0:
		perform_dash()
		dash_cd_timer = dash_cooldown

	var speed: float = Playerdata_Globle.walk_speed
	if is_dashing:
		speed = Playerdata_Globle.dash_speed

	var speed_mult: float = 1.0
	if is_aiming:
		speed_mult = 1.0 / float(Engine.time_scale)

	velocity = direction * speed * speed_mult * move_speed_multiplier * slow_multiplier

func perform_dash() -> void:
	if anim_player:
		anim_player.play("dash")
	if burn_time_left > 0.0:
		burn_time_left = 0.0
		if sprite and not is_invincible:
			sprite.modulate = Color.WHITE
		print("💦 衝刺發動！成功解除灼燒狀態！")

	if not has_infinite_stamina:
		current_stamina -= Playerdata_Globle.dash_stamina_cost
		current_stamina = maxf(current_stamina, 0.0)

	_update_player_ui()

	is_dashing = true
	await get_tree().create_timer(0.15).timeout
	is_dashing = false

func handle_resources(delta: float) -> void:
	if current_hp > 0.0 and current_hp < Playerdata_Globle.max_hp:
		current_hp = minf(current_hp + Playerdata_Globle.hp_regen_speed * delta, Playerdata_Globle.max_hp)

	if current_stamina < Playerdata_Globle.max_stamina:
		var regen: float = Playerdata_Globle.stamina_regen_idle
		if velocity != Vector2.ZERO: regen = Playerdata_Globle.stamina_regen_move
		current_stamina = minf(current_stamina + regen * delta, Playerdata_Globle.max_stamina)

	if current_mp < Playerdata_Globle.max_mp:
		current_mp = minf(current_mp + Playerdata_Globle.mp_regen_speed * delta, Playerdata_Globle.max_mp)

func _update_aim_line() -> void:
	if aim_line == null: return
	if aim_line.get_point_count() < 2:
		aim_line.clear_points()
		aim_line.add_point(Vector2.ZERO)
		aim_line.add_point(Vector2.ZERO)
	aim_line.set_point_position(0, global_position)
	aim_line.set_point_position(1, get_global_mouse_position())

func handle_aim_and_release() -> void:
	if captured_bullets.is_empty() or (not has_infinite_mp and current_mp < Playerdata_Globle.absorb_mp_cost):
		if is_aiming:
			is_aiming = false
			Engine.time_scale = 1.0
		if aim_line:
			aim_line.visible = false
		return

	if Input.is_action_pressed("skill_release"):
		is_aiming = true
		Engine.time_scale = Playerdata_Globle.bullet_time_scale
		if aim_line:
			aim_line.visible = true
		_update_aim_line()

	elif Input.is_action_just_released("skill_release") and is_aiming:
		is_aiming = false
		Engine.time_scale = 1.0
		if aim_line:
			aim_line.visible = false
		launch_captured_bullets()

func play_release_burst_particles() -> void:
	if not is_instance_valid(release_burst_particles): return
	_sync_effect_nodes_position()
	release_burst_particles.emitting = false
	release_burst_particles.restart()
	release_burst_particles.emitting = true

func launch_captured_bullets() -> void:
	if captured_bullets.is_empty():
		return

	if not has_infinite_mp:
		var cost = Playerdata_Globle.absorb_mp_cost
		print("DEBUG: (Player 2) 發射子彈，扣除 MP. 當前: ", current_mp, " 消耗: ", cost)
		current_mp -= cost
		current_mp = maxf(current_mp, 0.0)
		print("DEBUG: (Player 2) 扣除後 MP: ", current_mp)
	else:
		print("DEBUG: (Player 2) 無限魔力狀態，不扣 MP")

	_update_player_ui()
	play_release_burst_particles()

	var power_multiplier: float = 1.0 + (float(captured_bullets.size()) * 0.2)
	var target_dir: Vector2 = (get_global_mouse_position() - global_position).normalized()

	if target_dir == Vector2.ZERO:
		target_dir = Vector2.RIGHT

	var bullets_to_fire: Array = captured_bullets.duplicate()
	captured_bullets.clear()

	for bullet in bullets_to_fire:
		if head_bullet_display and head_bullet_display.get_child_count() > 0:
			var icon: Node = head_bullet_display.get_child(0)
			head_bullet_display.remove_child(icon)
			icon.queue_free()

		if not is_instance_valid(bullet):
			continue
		if not bullet.is_inside_tree():
			continue

		if "is_absorbed" in bullet:
			bullet.is_absorbed = false

		if bullet is Node2D:
			(bullet as Node2D).global_position = global_position

		bullet.visible = true
		bullet.set_deferred("monitorable", true)
		bullet.set_deferred("monitoring", true)
		bullet.process_mode = Node.PROCESS_MODE_INHERIT

		play_release_burst_particles()

		if bullet.has_method("reflect"):
			bullet.reflect(target_dir, power_multiplier)

		await get_tree().create_timer(0.15).timeout

func apply_slow(multiplier: float, duration: float) -> void:
	move_speed_multiplier *= multiplier
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(self):
		move_speed_multiplier /= multiplier

# ==========================================
# 道具使用邏輯與 UI 點擊事件
# ==========================================
func use_hp_potion() -> void:
	if Playerdata_Globle.hp_potion > 0 and current_hp < Playerdata_Globle.max_hp:
		Playerdata_Globle.hp_potion -= 1
		current_hp = minf(current_hp + 50.0, Playerdata_Globle.max_hp) 
		print("使用了血瓶，剩餘: ", Playerdata_Globle.hp_potion)
		_update_player_ui()


func use_stamina_potion() -> void:
	if Playerdata_Globle.stamina_potion > 0 and not has_infinite_stamina:
		Playerdata_Globle.stamina_potion -= 1
		has_infinite_stamina = true
		current_stamina = Playerdata_Globle.max_stamina
		print("使用了體力瓶，獲得 15 秒無限體力！剩餘: ", Playerdata_Globle.stamina_potion)
		_update_player_ui()
		await get_tree().create_timer(15.0).timeout
		has_infinite_stamina = false
		print("無限體力效果結束！")


func use_mp_potion() -> void:
	if Playerdata_Globle.mp_potion > 0 and not has_infinite_mp:
		Playerdata_Globle.mp_potion -= 1
		has_infinite_mp = true
		current_mp = Playerdata_Globle.max_mp
		print("使用了魔力瓶，獲得 15 秒無限魔力！剩餘: ", Playerdata_Globle.mp_potion)
		_update_player_ui()
		await get_tree().create_timer(15.0).timeout
		has_infinite_mp = false
		print("無限魔力效果結束！")


func use_invincible_potion() -> void:
	if Playerdata_Globle.invincible > 0 and not is_invincible:
		Playerdata_Globle.invincible -= 1
		print("使用了無敵道具，剩餘: ", Playerdata_Globle.invincible)

		if sprite:
			is_invincible = true
			var original_modulate: Color = sprite.modulate
			sprite.modulate = Color(1.5, 1.5, 0.5, 1.0)

			if burn_time_left > 0.0:
				burn_time_left = 0.0
				print("✨ 無敵藥水生效，解除灼燒狀態！")

			await get_tree().create_timer(3.0).timeout
			sprite.modulate = original_modulate
			is_invincible = false


func _on_btn_hp_pressed() -> void:
	use_hp_potion()


func _on_btn_stamina_pressed() -> void:
	use_stamina_potion()


func _on_btn_mp_pressed() -> void:
	use_mp_potion()


func _on_btn_invincible_pressed() -> void:
	use_invincible_potion()

func set_reverse_input(enabled: bool) -> void:
	reverse_input_enabled = enabled
	print("Reverse input enabled = ", reverse_input_enabled)

func apply_reverse_input(duration: float) -> void:
	_reverse_input_token += 1
	var current_token: int = _reverse_input_token

	reverse_input_enabled = true
	print("Reverse input enabled = true, duration = ", duration)

	await get_tree().create_timer(duration).timeout

	if not is_instance_valid(self):
		return

	if current_token != _reverse_input_token:
		return

	reverse_input_enabled = false
	print("Reverse input enabled = false")
