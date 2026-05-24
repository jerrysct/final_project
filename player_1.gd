extends CharacterBody2D

# --- UI 節點引用 ---
var stamina_bar: ProgressBar = null
var stamina_label: Label = null

var health_bar: ProgressBar = null
var health_label: Label = null

var charge_bar: ProgressBar = null
var charge_label: Label = null

# --- 玩家本體節點引用 ---
@onready var bounce_zone: Area2D = get_node_or_null("BounceZone") as Area2D
@onready var bounce_collision: CollisionShape2D = get_node_or_null("BounceZone/CollisionShape2D") as CollisionShape2D
@onready var aim_line: Line2D = get_node_or_null("AimLine") as Line2D
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
@onready var skill_indicator: Node2D = get_node_or_null("SkillIndicator") as Node2D
@onready var release_burst_particles: CPUParticles2D = get_node_or_null("ReleaseBurstParticles") as CPUParticles2D

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
	_find_ui_nodes()

	current_hp = Playerdata_Globle.max_hp
	current_stamina = Playerdata_Globle.max_stamina

	if health_bar:
		health_bar.max_value = Playerdata_Globle.max_hp
		health_bar.value = current_hp
		health_bar.show_percentage = false

	if stamina_bar:
		stamina_bar.max_value = Playerdata_Globle.max_stamina
		stamina_bar.value = current_stamina
		stamina_bar.show_percentage = false

	if charge_bar:
		charge_bar.max_value = float(Playerdata_Globle.max_bullet_storage)
		charge_bar.value = 0.0
		charge_bar.visible = false
		charge_bar.show_percentage = false

	if charge_label:
		charge_label.visible = false

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
	_update_player_ui()


func _find_ui_nodes() -> void:
	var scene_root := get_tree().current_scene

	# 優先找目前房間場景 CanvasLayer 裡的 UI
	if scene_root != null:
		health_bar = scene_root.get_node_or_null("CanvasLayer/HealthBar") as ProgressBar
		health_label = scene_root.get_node_or_null("CanvasLayer/HealthLabel") as Label

		stamina_bar = scene_root.get_node_or_null("CanvasLayer/ProgressBar") as ProgressBar
		stamina_label = scene_root.get_node_or_null("CanvasLayer/StaminaLabel") as Label

		charge_bar = scene_root.get_node_or_null("CanvasLayer/ChargeBar") as ProgressBar
		charge_label = scene_root.get_node_or_null("CanvasLayer/ChargeLabel") as Label

	# 如果房間場景找不到，就找玩家自己底下的 UI
	if health_bar == null:
		health_bar = get_node_or_null("CanvasLayer/HealthBar") as ProgressBar

	if health_label == null:
		health_label = get_node_or_null("CanvasLayer/HealthLabel") as Label

	if stamina_bar == null:
		stamina_bar = get_node_or_null("CanvasLayer/ProgressBar") as ProgressBar

	if stamina_label == null:
		stamina_label = get_node_or_null("CanvasLayer/StaminaLabel") as Label

	if charge_bar == null:
		charge_bar = get_node_or_null("CanvasLayer/ChargeBar") as ProgressBar

	if charge_bar == null:
		charge_bar = get_node_or_null("CanvasLayer2/ChargeBar") as ProgressBar

	if charge_label == null:
		charge_label = get_node_or_null("CanvasLayer/ChargeLabel") as Label

	if charge_label == null:
		charge_label = get_node_or_null("CanvasLayer2/ChargeLabel") as Label


func _get_hp_text() -> String:
	return str(int(current_hp)) + " / " + str(int(Playerdata_Globle.max_hp))


func _get_stamina_text() -> String:
	return str(int(current_stamina)) + " / " + str(int(Playerdata_Globle.max_stamina))


func _get_charge_text() -> String:
	return str(captured_bullets.size()) + " / " + str(Playerdata_Globle.max_bullet_storage)


func _update_player_ui() -> void:
	if health_bar:
		health_bar.value = current_hp

	if health_label:
		health_label.text = _get_hp_text()

	if stamina_bar:
		stamina_bar.value = current_stamina

	if stamina_label:
		stamina_label.text = _get_stamina_text()

	if charge_bar:
		charge_bar.value = float(captured_bullets.size())
		charge_bar.visible = not captured_bullets.is_empty()

	if charge_label:
		charge_label.text = _get_charge_text()
		charge_label.visible = not captured_bullets.is_empty()


func _sync_effect_nodes_position() -> void:
	var feet_offset := Vector2(1.2000008, -0.79999924)

	if skill_indicator:
		skill_indicator.global_position = global_position + feet_offset

	if release_burst_particles:
		release_burst_particles.global_position = global_position + feet_offset


func _physics_process(delta: float) -> void:
	_sync_effect_nodes_position()
	handle_resources(delta)
	_update_player_ui()

	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	handle_movement(direction)

	# 瞬間反彈（左鍵按住 → 放開判定）
	if Input.is_action_pressed("parry"):
		is_parry_preparing = true
	else:
		if is_parry_preparing:
			execute_instant_parry()
			is_parry_preparing = false

	# 吸收子彈（右鍵按住持續吸收）
	if Input.is_action_pressed("absorb"):
		is_absorb_preparing = true
		execute_absorb_action()
	else:
		is_absorb_preparing = false

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

	var damage_value = area.get("damage")
	var damage_amount: float = 10.0

	if damage_value != null:
		damage_amount = float(damage_value)

	take_damage(damage_amount)
	area.call_deferred("queue_free")


func take_damage(amount: float) -> void:
	if is_invincible:
		return

	current_hp -= amount
	current_hp = maxf(current_hp, 0.0)
	_update_player_ui()
	play_hit_effect()

	if current_hp <= 0.0:
		# 等待受擊動畫播放完畢
		await get_tree().create_timer(0.6).timeout

		# 呼叫 BossRoom 的結算畫面
		var room = get_parent()
		if room != null and room.has_method("show_defeat"):
			room.show_defeat()
		else:
			get_tree().call_deferred("reload_current_scene")


func play_hit_effect() -> void:
	if sprite == null:
		return

	is_invincible = true

	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color.RED, 0.1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	tween.set_loops(3)

	await get_tree().create_timer(0.6).timeout
	is_invincible = false


func execute_instant_parry() -> void:
	if bounce_zone == null:
		return

	for area in bounce_zone.get_overlapping_areas():
		if not area.has_method("reflect"):
			continue

		if area.get("is_reflected") or area.get("is_absorbed"):
			continue

		var reflect_dir: Vector2 = Vector2.ZERO
		var area_direction = area.get("direction")

		if area_direction is Vector2:
			reflect_dir = -(area_direction as Vector2).normalized()

		area.reflect(reflect_dir, 1.5)


func execute_absorb_action() -> void:
	if bounce_zone == null:
		return

	for area in bounce_zone.get_overlapping_areas():
		if not area.has_method("reflect"):
			continue

		if area.get("is_reflected") or area.get("is_absorbed"):
			continue

		if captured_bullets.size() >= Playerdata_Globle.max_bullet_storage:
			break

		absorb_bullet(area)

	_update_player_ui()


func absorb_bullet(bullet: Node) -> void:
	if captured_bullets.has(bullet):
		return

	captured_bullets.append(bullet)

	if bullet.get("is_absorbed") != null:
		bullet.set("is_absorbed", true)

	if bullet is Node2D:
		var bullet_2d := bullet as Node2D
		var global_pos := bullet_2d.global_position
		var scene_root := get_tree().current_scene

		if scene_root != null and bullet.get_parent() != scene_root:
			bullet.reparent(scene_root)
			bullet_2d.global_position = global_pos

	bullet.set_physics_process(false)
	bullet.visible = false
	bullet.set_deferred("monitorable", false)
	bullet.set_deferred("monitoring", false)


func handle_movement(direction: Vector2) -> void:
	if Input.is_action_just_pressed("dash") and direction != Vector2.ZERO and current_stamina >= Playerdata_Globle.dash_stamina_cost:
		perform_dash()

	var speed := Playerdata_Globle.dash_speed if is_dashing else Playerdata_Globle.walk_speed
	var speed_mult := 1.0 / float(Engine.time_scale) if is_aiming else 1.0
	velocity = direction * speed * speed_mult * move_speed_multiplier


func perform_dash() -> void:
	current_stamina -= Playerdata_Globle.dash_stamina_cost
	current_stamina = maxf(current_stamina, 0.0)
	_update_player_ui()

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
	if aim_line == null:
		return

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

	if target_dir == Vector2.ZERO:
		target_dir = Vector2.RIGHT

	for bullet in captured_bullets:
		if not is_instance_valid(bullet) or not bullet.is_inside_tree():
			continue

		if bullet.get("is_absorbed") != null:
			bullet.set("is_absorbed", false)

		if bullet is Node2D:
			(bullet as Node2D).global_position = global_position

		bullet.visible = true
		bullet.set_deferred("monitorable", true)
		bullet.set_deferred("monitoring", true)
		bullet.set_physics_process(true)

		if bullet.has_method("reflect"):
			bullet.reflect(target_dir, power_multiplier)

	captured_bullets.clear()
	_update_player_ui()


func apply_slow(multiplier: float, duration: float) -> void:
	move_speed_multiplier *= multiplier

	await get_tree().create_timer(duration).timeout

	if is_instance_valid(self):
		move_speed_multiplier /= multiplier
