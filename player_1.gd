extends CharacterBody2D


# --- 節點引用 ---
@onready var stamina_bar = $CanvasLayer/ProgressBar
@onready var charge_bar = $CanvasLayer2/ChargeBar
@onready var bounce_zone = $BounceZone  
@onready var aim_line = $AimLine 

# 指示圈畫在子節點上，避免被 Sprite2D 蓋住
@onready var skill_indicator = $SkillIndicator
@onready var release_burst_particles = $ReleaseBurstParticles

# --- 狀態變數 ---
var current_hp: float
var current_stamina: float
var is_invincible = false
var is_dashing = false
var is_aiming = false
var captured_bullets = [] 

func _ready():
	# 1. 優先初始化血量與體力（最重要，放到最上面防當機）
	current_hp = Playerdata_Globle.max_hp
	current_stamina = Playerdata_Globle.max_stamina
	
	health_bar.max_value = Playerdata_Globle.max_hp
	health_bar.value = current_hp
	health_bar.show_percentage = true
	stamina_bar.max_value = Playerdata_Globle.max_stamina
	stamina_bar.value = current_stamina
	
	# 2. 初始化蓄力條與瞄準線
	charge_bar.max_value = float(Playerdata_Globle.max_bullet_storage)
	charge_bar.value = 0.0
	charge_bar.visible = false
	
	aim_line.visible = false
	aim_line.top_level = true
	aim_line.position = Vector2.ZERO
	aim_line.clear_points()
	aim_line.add_point(Vector2.ZERO)
	aim_line.add_point(Vector2.ZERO)

func _physics_process(delta):
	handle_resources(delta)
	
	health_bar.value = current_hp
	stamina_bar.value = current_stamina
	
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	handle_movement(direction)
	
	# --- 技能邏輯 ---
	
	# 1. 瞬間反彈 (Parry)
	if Input.is_action_pressed("parry"):
		is_parry_preparing = true  # 按住時，維持 true 讓 _draw() 畫出指示圈
	else:
		if is_parry_preparing:
			execute_instant_parry()  # 放開按鍵時才判定反彈
			is_parry_preparing = false  # 判定完關閉指示圈

	# 2. 吸收子彈 (Absorb) — 按住期間持續吸收，避免受傷判定讓玩家閃爍/消失
	if Input.is_action_pressed("absorb"):
		is_absorb_preparing = true
		execute_absorb_action()
	else:
		is_absorb_preparing = false
			
	handle_aim_and_release()

	if Input.is_action_just_released("skill_release"):
		play_release_burst_particles()
	
	skill_indicator.is_parry_preparing = is_parry_preparing
	skill_indicator.is_absorb_preparing = is_absorb_preparing
	skill_indicator.is_aiming = is_aiming
	skill_indicator.bounce_collision = bounce_collision
	skill_indicator.queue_redraw()
	move_and_slide()

# --- 受傷判定 ---
func _on_hurtbox_area_entered(area):
	if is_parry_preparing or is_absorb_preparing or is_invincible:
		return
	if area.has_method("reflect") and not area.get("is_reflected") and not area.get("is_absorbed"):
		var damage_amount = area.get("damage") if "damage" in area else 10.0
		take_damage(damage_amount)
		area.queue_free()

func take_damage(amount: float):
	if is_invincible: return
	current_hp -= amount
	play_hit_effect()
	if current_hp <= 0:
		get_tree().reload_current_scene()

# --- 動作執行 ---
func execute_instant_parry():
	var targets = bounce_zone.get_overlapping_areas()
	for area in targets:
		if area.has_method("reflect") and not area.get("is_reflected") and not area.get("is_absorbed"):
			area.reflect(-area.direction if "direction" in area else Vector2.ZERO, 1.5)

func execute_absorb_action():
	var targets = bounce_zone.get_overlapping_areas()
	for area in targets:
		if area.has_method("reflect") and not area.get("is_reflected") and not area.get("is_absorbed"):
			if captured_bullets.size() < Playerdata_Globle.max_bullet_storage:
				absorb_bullet(area)
	charge_bar.visible = not captured_bullets.is_empty()
	charge_bar.value = float(captured_bullets.size())

# --- 基本功能輔助 ---
func play_hit_effect():
	is_invincible = true
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.RED, 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	tween.set_loops(3)
	await get_tree().create_timer(0.6).timeout
	is_invincible = false

func handle_movement(direction):
	if Input.is_action_just_pressed("dash") and direction != Vector2.ZERO and current_stamina >= Playerdata_Globle.dash_stamina_cost:
		perform_dash()
	var current_speed = Playerdata_Globle.dash_speed if is_dashing else Playerdata_Globle.walk_speed
	var speed_mult = 1.0 / float(Engine.time_scale) if is_aiming else 1.0
	velocity = direction * current_speed * speed_mult

func perform_dash():
	current_stamina -= Playerdata_Globle.dash_stamina_cost
	is_dashing = true
	await get_tree().create_timer(0.15).timeout 
	is_dashing = false

func handle_resources(delta):
	if current_stamina < Playerdata_Globle.max_stamina:
		current_stamina = min(current_stamina + Playerdata_Globle.stamina_regen_idle * delta, Playerdata_Globle.max_stamina)

func absorb_bullet(bullet):
	if not captured_bullets.has(bullet):
		captured_bullets.append(bullet)
		if "is_absorbed" in bullet:
			bullet.is_absorbed = true
		bullet.set_physics_process(false)
		bullet.visible = false
		bullet.set_deferred("monitorable", false)
		bullet.set_deferred("monitoring", false)

func _update_aim_line() -> void:
	if aim_line.get_point_count() < 2:
		aim_line.clear_points()
		aim_line.add_point(Vector2.ZERO)
		aim_line.add_point(Vector2.ZERO)
	aim_line.set_point_position(0, global_position)
	aim_line.set_point_position(1, get_global_mouse_position())

# --- 指向瞄準與釋放 (F 鍵) ---
func handle_aim_and_release():
	if captured_bullets.is_empty():
		if is_aiming:
			is_aiming = false
			Engine.time_scale = 1.0
		aim_line.visible = false
		return

	if Input.is_action_pressed("skill_release"):
		is_aiming = true
		Engine.time_scale = Playerdata_Globle.bullet_time_scale
		aim_line.visible = true
		
		# --- 終極修正方案 ---
		# 1. 強制重設起點為玩家中心
		aim_line.set_point_position(0, global_position) 
		
		# 2. 獲取滑鼠相對於相機/視口的局部座標
		# 使用 get_local_mouse_position() 是最穩定的，前提是 AimLine 是 Player 的直接子節點
		var target_pos = get_local_mouse_position()
		
		# 3. 更新線條終點
		aim_line.set_point_position(1, target_pos)
		
	if Input.is_action_just_released("skill_release") and is_aiming:
		is_aiming = false
		Engine.time_scale = 1.0
		aim_line.visible = false
		launch_captured_bullets()

func play_release_burst_particles() -> void:
	if not is_instance_valid(release_burst_particles):
		return
	release_burst_particles.restart()

func launch_captured_bullets():
	var power_multiplier = 1.0 + (captured_bullets.size() * 0.2)
	var target_dir = (get_global_mouse_position() - global_position).normalized()
	
	for bullet in captured_bullets:
		if is_instance_valid(bullet):
			if "is_absorbed" in bullet:
				bullet.is_absorbed = false
			bullet.visible = true
			bullet.global_position = global_position
			bullet.set_deferred("monitorable", true)
			bullet.set_deferred("monitoring", true)
			bullet.set_physics_process(true)
			bullet.reflect(target_dir, power_multiplier)
			
	captured_bullets.clear()
	charge_bar.visible = false

# --- 基礎功能 ---
func absorb_bullet(bullet):
	captured_bullets.append(bullet)
	bullet.set_physics_process(false)
	bullet.visible = false
	bullet.set_deferred("monitorable", false)
	bullet.set_deferred("monitoring", false)

func execute_instant_parry():
	var targets = bounce_zone.get_overlapping_areas()
	for bullet in targets:
		if bullet.has_method("reflect") and not bullet.get("is_reflected"):
			bullet.reflect(-bullet.direction, 1.5)

func handle_movement(direction):
	var speed_mult = 1.0 / Engine.time_scale if is_aiming else 1.0
	velocity = direction * walk_speed * speed_mult
	
func take_damage(amount):
	print("玩家受到傷害：", amount)


func apply_slow(multiplier: float, duration: float):
	walk_speed *= multiplier
	
	await get_tree().create_timer(duration).timeout
	
	walk_speed /= multiplier
