extends CharacterBody2D

# --- 節點引用 (已加上防呆機制) ---
@onready var stamina_bar = get_tree().current_scene.get_node_or_null("CanvasLayer/ProgressBar")
@onready var health_bar = get_tree().current_scene.get_node_or_null("CanvasLayer/HealthBar")
@onready var charge_bar = get_tree().current_scene.get_node_or_null("CanvasLayer/ChargeBar")
@onready var bounce_zone: Area2D = $BounceZone
@onready var bounce_collision: CollisionShape2D = $BounceZone/CollisionShape2D
@onready var aim_line: Line2D = $AimLine
@onready var sprite: Sprite2D = $Sprite2D
@onready var skill_indicator: Node2D = $SkillIndicator
@onready var release_burst_particles: CPUParticles2D = $ReleaseBurstParticles

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

<<<<<<< HEAD
	health_bar.max_value = Playerdata_Globle.max_hp
	health_bar.value = current_hp
=======
	if health_bar:
		health_bar.max_value = Playerdata_Globle.max_hp
		health_bar.value = current_hp
		health_bar.show_percentage = true
>>>>>>> 3c84d8e0e6fee50109a44a349f38f4681227c55a

	if stamina_bar:
		stamina_bar.max_value = Playerdata_Globle.max_stamina
		stamina_bar.value = current_stamina

	if charge_bar:
		charge_bar.max_value = float(Playerdata_Globle.max_bullet_storage)
		charge_bar.value = 0.0
		charge_bar.visible = false

	if aim_line:
		aim_line.visible = false
		aim_line.top_level = true
		aim_line.position = Vector2.ZERO
		aim_line.clear_points()
		aim_line.add_point(Vector2.ZERO)
		aim_line.add_point(Vector2.ZERO)

	# 技能圈用世界座標繪製，避免被父節點縮放影響
	if skill_indicator:
		skill_indicator.top_level = true
		skill_indicator.z_index = 50
	if release_burst_particles:
		release_burst_particles.top_level = true
		release_burst_particles.z_index = 51
		
	_sync_effect_nodes_position()

func _sync_effect_nodes_position() -> void:
	var feet_offset := Vector2(1.2000008, -0.79999924)
	if skill_indicator:
		skill_indicator.global_position = global_position + feet_offset
	if release_burst_particles:
		release_burst_particles.global_position = global_position + feet_offset

func _physics_process(delta: float) -> void:
	_sync_effect_nodes_position()
	handle_resources(delta)

	if health_bar:
		health_bar.value = current_hp
	if stamina_bar:
		stamina_bar.value = current_stamina

	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	handle_movement(direction)

	# 瞬間反彈（左鍵按住 → 放開判定）
	if Input.is_action_pressed("parry"):
		is_parry_preparing = true
	else:
		if is_parry_preparing:
			execute_instant_parry()
			is_parry_preparing = false
			
	if Input.is_action_pressed("absorb"):
		print("主程式：有按住吸收鍵！")  # <--- 加入這行來測試
		is_absorb_preparing = true
		execute_absorb_action() 
	else:
		is_absorb_preparing = false
		
	# 吸收子彈（右鍵按住持續吸收）
	handle_aim_and_release()

	if skill_indicator:
		skill_indicator.is_parry_preparing = is_parry_preparing
		skill_indicator.is_absorb_preparing = is_absorb_preparing
		skill_indicator.is_aiming = is_aiming
		if bounce_collision:
			skill_indicator.bounce_collision = bounce_collision
		skill_indicator.queue_redraw()

	move_and_slide()

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
		# 等待受擊動畫播放完畢
		await get_tree().create_timer(0.6).timeout 
		
		# 呼叫 BossRoom 的結算畫面
		var room = get_parent()
		if room != null and room.has_method("show_defeat"):
			room.show_defeat()
		else:
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
	if not bounce_zone: return
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
	if not bounce_zone: return
	for area in bounce_zone.get_overlapping_areas():
		if not area.has_method("reflect"):
			continue
		if area.get("is_reflected") or area.get("is_absorbed"):
			continue
		if captured_bullets.size() >= Playerdata_Globle.max_bullet_storage:
			break
		absorb_bullet(area)

	if charge_bar:
		charge_bar.visible = not captured_bullets.is_empty()
		charge_bar.value = float(captured_bullets.size())

func absorb_bullet(bullet: Node) -> void:
	if captured_bullets.has(bullet):
		return
	captured_bullets.append(bullet)
	
	# 將子彈脫離發射者
	var scene_root = get_tree().current_scene
	if bullet.get_parent() != scene_root:
		var global_pos = bullet.global_position
		bullet.get_parent().remove_child(bullet)
		scene_root.add_child(bullet)
		bullet.global_position = global_pos
		
	if "is_absorbed" in bullet:
		bullet.is_absorbed = true
	bullet.set_physics_process(false)
	bullet.visible = false
	bullet.set_deferred("monitorable", false)
	bullet.set_deferred("monitoring", false)

func handle_movement(direction: Vector2) -> void:
	if Input.is_action_just_pressed("dash") and direction != Vector2.ZERO \
			and current_stamina >= Playerdata_Globle.dash_stamina_cost:
		perform_dash()

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
	if not aim_line: return
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

		if aim_line: aim_line.visible = false
		return

	if Input.is_action_pressed("skill_release"):
		is_aiming = true
		Engine.time_scale = Playerdata_Globle.bullet_time_scale
		if aim_line: aim_line.visible = true
		_update_aim_line()
	elif Input.is_action_just_released("skill_release") and is_aiming:
		is_aiming = false
		Engine.time_scale = 1.0
		if aim_line: aim_line.visible = false
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

	for bullet in captured_bullets:
		if not is_instance_valid(bullet) or not bullet.is_inside_tree():
			continue
			
		if "is_absorbed" in bullet:
			bullet.is_absorbed = false
		bullet.visible = true
		bullet.global_position = global_position
		bullet.set_deferred("monitorable", true)
		bullet.set_deferred("monitoring", true)
		bullet.set_physics_process(true)
		bullet.reflect(target_dir, power_multiplier)

	captured_bullets.clear()
	if charge_bar: charge_bar.visible = false

func apply_slow(multiplier: float, duration: float) -> void:
	move_speed_multiplier *= multiplier
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(self):
		move_speed_multiplier /= multiplier
