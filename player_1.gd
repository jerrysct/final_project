extends CharacterBody2D

# --- 節點引用 ---
@onready var health_bar: ProgressBar = $CanvasLayer/HealthBar
@onready var hp_label: Label = $CanvasLayer/HealthBar/Label
@onready var stamina_bar: ProgressBar = $CanvasLayer/ProgressBar
@onready var stamina_label: Label = $CanvasLayer/ProgressBar/Label # 新增體力文字
@onready var charge_bar: ProgressBar = $CanvasLayer2/ChargeBar
@onready var charge_label: Label = $CanvasLayer2/ChargeBar/Label   # 新增蓄力文字
@onready var bounce_zone: Area2D = $BounceZone
@onready var bounce_collision: CollisionShape2D = $BounceZone/CollisionShape2D
@onready var aim_line: Line2D = $AimLine
@onready var sprite: Sprite2D = $Sprite2D
@onready var skill_indicator: Node2D = $SkillIndicator
@onready var release_burst_particles: CPUParticles2D = $ReleaseBurstParticles
# --- 新增：頭部子彈顯示容器 ---
@onready var head_bullet_display: Node2D = $HeadBulletDisplay

# --- 【新增】道具 UI 標籤引用 (使用 get_node_or_null 避免節點還沒建好時報錯) ---
# 假設你之後會在 CanvasLayer 建立 HBoxContainer 放按鈕與 Label
@onready var btn_hp_label: Label = get_node_or_null("CanvasLayer/HBoxContainer/BtnHP/Label")
@onready var btn_stamina_label: Label = get_node_or_null("CanvasLayer/HBoxContainer/BtnStamina/Label")
@onready var btn_mp_label: Label = get_node_or_null("CanvasLayer/HBoxContainer/BtnMP/Label")
@onready var btn_invincible_label: Label = get_node_or_null("CanvasLayer/HBoxContainer/BtnInvincible/Label")
# -------------------------------------------------------------------------

# --- 冷卻時間設定 (單位：秒) ---
@export var parry_cooldown: float = 1.0  # 反彈冷卻時間
@export var absorb_cooldown: float = 1.5 # 吸收冷卻時間
@export var dash_cooldown: float = 0.5   # 衝刺冷卻時間

# --- 控制「玩家頭上子彈圖示」的縮放大小 ---
@export var head_icon_scale: Vector2 = Vector2(0.1, 0.1)

# --- 內部冷卻計時器 ---
var parry_cd_timer: float = 0.0
var absorb_cd_timer: float = 0.0
var dash_cd_timer: float = 0.0

# --- 狀態變數 ---
var current_hp: float
var current_stamina: float
var is_invincible := false
var is_dashing := false
var is_parry_preparing := false
var is_absorb_preparing := false
var is_aiming := false
var captured_bullets: Array = []
var move_speed_multiplier: float = 1.0

func _ready() -> void:
	current_hp = Playerdata_Globle.max_hp
	current_stamina = Playerdata_Globle.max_stamina

	# 血量條設定
	health_bar.max_value = Playerdata_Globle.max_hp
	health_bar.value = current_hp
	health_bar.show_percentage = false
	hp_label.text = "%d / %d" % [current_hp, Playerdata_Globle.max_hp]

	# 體力條設定
	stamina_bar.max_value = Playerdata_Globle.max_stamina
	stamina_bar.value = current_stamina
	stamina_bar.show_percentage = false
	stamina_label.text = "%d / %d" % [current_stamina, Playerdata_Globle.max_stamina]

	# 蓄力條設定
	charge_bar.max_value = float(Playerdata_Globle.max_bullet_storage)
	charge_bar.value = 0.0
	charge_bar.visible = false
	charge_bar.show_percentage = false
	charge_label.text = "0 / %d" % Playerdata_Globle.max_bullet_storage

	aim_line.visible = false
	aim_line.top_level = true
	aim_line.position = Vector2.ZERO
	aim_line.clear_points()
	aim_line.add_point(Vector2.ZERO)
	aim_line.add_point(Vector2.ZERO)

	# 技能圈用世界座標繪製，避免被父節點縮放影響
	skill_indicator.top_level = true
	skill_indicator.z_index = 50
	release_burst_particles.top_level = true
	release_burst_particles.z_index = 51
	
	head_bullet_display.top_level = true
	head_bullet_display.z_index = 52
	_sync_effect_nodes_position()

func _sync_effect_nodes_position() -> void:
	var feet_offset := Vector2(1.2000008, -0.79999924)
	skill_indicator.global_position = global_position + feet_offset
	release_burst_particles.global_position = global_position + feet_offset
	
	var head_offset := Vector2(0, -32)
	head_bullet_display.global_position = global_position + head_offset

func _physics_process(delta: float) -> void:
	_sync_effect_nodes_position()
	handle_resources(delta)

	# --- 更新冷卻計時器 ---
	if parry_cd_timer > 0:
		parry_cd_timer -= delta
	if absorb_cd_timer > 0:
		absorb_cd_timer -= delta
	if dash_cd_timer > 0:
		dash_cd_timer -= delta

	# 持續更新血量與體力顯示
	health_bar.value = current_hp
	hp_label.text = "%d / %d" % [current_hp, Playerdata_Globle.max_hp]
	stamina_bar.value = current_stamina
	stamina_label.text = "%d / %d" % [current_stamina, Playerdata_Globle.max_stamina]

	# --- 【新增】持續更新 UI 上的道具數量顯示 ---
	if btn_hp_label: btn_hp_label.text = str(Playerdata_Globle.hp_potion)
	if btn_stamina_label: btn_stamina_label.text = str(Playerdata_Globle.stamina_potion)
	if btn_mp_label: btn_mp_label.text = str(Playerdata_Globle.mp_potion)
	if btn_invincible_label: btn_invincible_label.text = str(Playerdata_Globle.invincible)
	# -----------------------------------------------------

	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	handle_movement(direction)

	# ==========================================
	# 互斥動作判斷 (反彈 / 吸收 / 射擊 一次只能做一種)
	# ==========================================
	
	if Input.is_action_pressed("parry") and parry_cd_timer <= 0.0 and not is_absorb_preparing and not is_aiming:
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

	skill_indicator.is_parry_preparing = is_parry_preparing
	skill_indicator.is_absorb_preparing = is_absorb_preparing
	skill_indicator.is_aiming = is_aiming
	skill_indicator.bounce_collision = bounce_collision
	skill_indicator.queue_redraw()

	move_and_slide()

# --- 【新增】接收鍵盤快捷鍵 (1, 2, 3, 4) ---
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("use_item_1"):
		use_hp_potion()
	elif event.is_action_pressed("use_item_2"):
		use_stamina_potion()
	elif event.is_action_pressed("use_item_3"):
		use_mp_potion()
	elif event.is_action_pressed("use_item_4"):
		use_invincible_potion()
# ---------------------------------------------

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if is_parry_preparing or is_absorb_preparing or is_invincible:
		return
	if not area.has_method("reflect"):
		return
	if area.get("is_reflected") or area.get("is_absorbed"):
		return

	var damage_amount: float = area.damage if "damage" in area else 10.0
	take_damage(damage_amount)
	area.queue_free()

func take_damage(amount: float) -> void:
	if is_invincible:
		return
	current_hp -= amount
	current_hp = maxf(current_hp, 0.0)
	play_hit_effect()
	if current_hp <= 0.0:
		for child in head_bullet_display.get_children():
			child.queue_free()
			
		await get_tree().create_timer(0.6).timeout
		get_tree().reload_current_scene()

func play_hit_effect() -> void:
	is_invincible = true
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.RED, 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	tween.set_loops(3)

	await get_tree().create_timer(0.6).timeout
	is_invincible = false

func execute_instant_parry() -> void:
	for area in bounce_zone.get_overlapping_areas():
		if not area.has_method("reflect"):
			continue
		if area.get("is_reflected") or area.get("is_absorbed"):
			continue
		var reflect_dir: Vector2 = Vector2.ZERO
		if "direction" in area:
			reflect_dir = -(area.direction as Vector2).normalized()
		area.reflect(reflect_dir, 1.5)

func execute_absorb_action() -> void:
	for area in bounce_zone.get_overlapping_areas():
		if not area.has_method("reflect"):
			continue
		if area.get("is_reflected") or area.get("is_absorbed"):
			continue
			
		if "can_be_absorbed" in area and area.can_be_absorbed == false:
			continue
		
		if captured_bullets.size() >= Playerdata_Globle.max_bullet_storage:
			break
		absorb_bullet(area)

	charge_bar.visible = not captured_bullets.is_empty()
	charge_bar.value = float(captured_bullets.size())
	charge_label.text = "%d / %d" % [captured_bullets.size(), Playerdata_Globle.max_bullet_storage]

func absorb_bullet(bullet: Node) -> void:
	if captured_bullets.has(bullet):
		return
	captured_bullets.append(bullet)
	
	var original_global_scale = bullet.global_scale
	var scene_root = get_tree().current_scene
	if bullet.get_parent() != scene_root:
		var global_pos = bullet.global_position
		bullet.get_parent().remove_child(bullet)
		scene_root.add_child(bullet)
		bullet.global_position = global_pos
		bullet.global_scale = original_global_scale
		
	if "is_absorbed" in bullet:
		bullet.is_absorbed = true
		
	bullet.process_mode = Node.PROCESS_MODE_DISABLED
	bullet.visible = false
	bullet.set_deferred("monitorable", false)
	bullet.set_deferred("monitoring", false)

	_add_bullet_to_ui(bullet)

func _add_bullet_to_ui(bullet: Node) -> void:
	var icon := Sprite2D.new()
	icon.scale = head_icon_scale
	var bullet_sprite = bullet.get_node_or_null("Sprite2D")
	if bullet_sprite and bullet_sprite is Sprite2D:
		icon.texture = bullet_sprite.texture
		icon.modulate = bullet_sprite.modulate 
		
	head_bullet_display.add_child(icon)
	_arrange_headshot_bullets()

func _arrange_headshot_bullets() -> void:
	var bullet_spacing := 16.0
	var num_bullets = head_bullet_display.get_child_count()
	if num_bullets == 0:
		return
		
	var total_width = float(num_bullets - 1) * bullet_spacing
	
	for i in range(num_bullets):
		var child = head_bullet_display.get_child(i) as Sprite2D
		var target_x = -total_width / 2.0 + float(i) * bullet_spacing
		child.position = Vector2(target_x, 0)

func handle_movement(direction: Vector2) -> void:
	if Input.is_action_just_pressed("dash") and direction != Vector2.ZERO \
			and current_stamina >= Playerdata_Globle.dash_stamina_cost \
			and dash_cd_timer <= 0.0:
		perform_dash()
		dash_cd_timer = dash_cooldown

	var speed := Playerdata_Globle.dash_speed if is_dashing else Playerdata_Globle.walk_speed
	var speed_mult := 1.0 / float(Engine.time_scale) if is_aiming else 1.0
	velocity = direction * speed * speed_mult * move_speed_multiplier

func perform_dash() -> void:
	current_stamina -= Playerdata_Globle.dash_stamina_cost
	is_dashing = true
	await get_tree().create_timer(0.15).timeout
	is_dashing = false

func handle_resources(delta: float) -> void:
	if current_hp > 0.0 and current_hp < Playerdata_Globle.max_hp:
		current_hp = minf(
			current_hp + Playerdata_Globle.hp_regen_speed * delta,
			Playerdata_Globle.max_hp
		)

	if current_stamina < Playerdata_Globle.max_stamina:
		var regen := Playerdata_Globle.stamina_regen_idle
		if velocity != Vector2.ZERO:
			regen = Playerdata_Globle.stamina_regen_move
		current_stamina = minf(current_stamina + regen * delta, Playerdata_Globle.max_stamina)

func _update_aim_line() -> void:
	if aim_line.get_point_count() < 2:
		aim_line.clear_points()
		aim_line.add_point(Vector2.ZERO)
		aim_line.add_point(Vector2.ZERO)

	aim_line.set_point_position(0, global_position)
	aim_line.set_point_position(1, get_global_mouse_position())

func handle_aim_and_release() -> void:
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
		_update_aim_line()
	elif Input.is_action_just_released("skill_release") and is_aiming:
		is_aiming = false
		Engine.time_scale = 1.0
		aim_line.visible = false
		launch_captured_bullets()

func play_release_burst_particles() -> void:
	if not is_instance_valid(release_burst_particles):
		return
	_sync_effect_nodes_position()
	release_burst_particles.emitting = false
	release_burst_particles.restart()
	release_burst_particles.emitting = true

func launch_captured_bullets() -> void:
	if captured_bullets.is_empty():
		return

	play_release_burst_particles()

	var power_multiplier := 1.0 + (float(captured_bullets.size()) * 0.2)
	var target_dir := (get_global_mouse_position() - global_position).normalized()

	var bullets_to_fire = captured_bullets.duplicate()
	captured_bullets.clear()
	charge_bar.visible = false
	charge_label.text = "0 / %d" % Playerdata_Globle.max_bullet_storage

	for bullet in bullets_to_fire:
		if head_bullet_display.get_child_count() > 0:
			var icon = head_bullet_display.get_child(0)
			head_bullet_display.remove_child(icon)
			icon.queue_free()

		if not is_instance_valid(bullet) or not bullet.is_inside_tree():
			continue
			
		if "is_absorbed" in bullet:
			bullet.is_absorbed = false
			
		bullet.visible = true
		bullet.global_position = global_position
		
		bullet.set_deferred("monitorable", true)
		bullet.set_deferred("monitoring", true)
		
		bullet.process_mode = Node.PROCESS_MODE_INHERIT 
		
		bullet.reflect(target_dir, power_multiplier)
		await get_tree().create_timer(0.15).timeout

func apply_slow(multiplier: float, duration: float) -> void:
	move_speed_multiplier *= multiplier
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(self):
		move_speed_multiplier /= multiplier


# ==========================================
# 【新增】道具使用邏輯與 UI 點擊事件
# ==========================================
func use_hp_potion() -> void:
	if Playerdata_Globle.hp_potion > 0 and current_hp < Playerdata_Globle.max_hp:
		Playerdata_Globle.hp_potion -= 1
		current_hp = minf(current_hp + 50.0, Playerdata_Globle.max_hp) # 假設回復 50 血量
		print("使用了血瓶，剩餘: ", Playerdata_Globle.hp_potion)

func use_stamina_potion() -> void:
	if Playerdata_Globle.stamina_potion > 0 and current_stamina < Playerdata_Globle.max_stamina:
		Playerdata_Globle.stamina_potion -= 1
		current_stamina = minf(current_stamina + 50.0, Playerdata_Globle.max_stamina) # 假設回復 50 體力
		print("使用了體力瓶，剩餘: ", Playerdata_Globle.stamina_potion)

func use_mp_potion() -> void:
	if Playerdata_Globle.mp_potion > 0:
		Playerdata_Globle.mp_potion -= 1
		print("使用了魔力瓶，剩餘: ", Playerdata_Globle.mp_potion)
		# 若未來你有 current_mp 變數，可在此增加它的數值

func use_invincible_potion() -> void:
	if Playerdata_Globle.invincible > 0 and not is_invincible:
		Playerdata_Globle.invincible -= 1
		print("使用了無敵道具，剩餘: ", Playerdata_Globle.invincible)
		
		is_invincible = true
		var original_modulate = sprite.modulate
		sprite.modulate = Color(1.5, 1.5, 0.5, 1.0) # 讓玩家變成閃亮的金色
		
		await get_tree().create_timer(3.0).timeout # 無敵維持 3 秒
		
		sprite.modulate = original_modulate
		is_invincible = false

# 若你有設定 UI 的 Button，把它們的 pressed 訊號連過來這裡：
func _on_btn_hp_pressed() -> void:
	use_hp_potion()

func _on_btn_stamina_pressed() -> void:
	use_stamina_potion()

func _on_btn_mp_pressed() -> void:
	use_mp_potion()

func _on_btn_invincible_pressed() -> void:
	use_invincible_potion()
