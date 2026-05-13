extends CharacterBody2D

# --- 基礎設定 ---
@export var walk_speed = 200.0
@export var dash_speed = 600.0
@export var max_stamina = 100.0
@export var max_bullet_storage = 10 
@export var bullet_time_scale = 0.2 

# --- HP 系統 ---
@export var max_hp = 100.0
var current_hp = 100.0
var is_invincible = false 

# --- 節點引用 ---
@onready var health_bar = $CanvasLayer/HealthBar
@onready var stamina_bar = $CanvasLayer/ProgressBar
@onready var charge_bar = $CanvasLayer2/ChargeBar
@onready var bounce_zone = $BounceZone          
@onready var bounce_collision = $BounceZone/CollisionShape2D 
@onready var aim_line = $AimLine 
@onready var sprite = $Sprite2D 

# --- 狀態變數 ---
var current_stamina = 100.0
var is_dashing = false
var is_parry_preparing = false   
var is_absorb_preparing = false  
var is_aiming = false            
var captured_bullets = [] 

func _ready():
	current_hp = max_hp
	health_bar.max_value = max_hp
	charge_bar.max_value = float(max_bullet_storage) # 修正：轉成 float
	charge_bar.visible = false
	aim_line.visible = false
	aim_line.top_level = true 

func _physics_process(delta):
	handle_resources(delta)
	
	# 修正：UI 更新時確保是 float，避免 image_387f7e.png 中的警告
	health_bar.value = current_hp
	stamina_bar.value = current_stamina
	
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	handle_movement(direction)
	
	# --- 技能邏輯 ---
	if Input.is_action_pressed("parry"):
		is_parry_preparing = true
	elif is_parry_preparing:
		execute_instant_parry()
		is_parry_preparing = false
			
	if Input.is_action_pressed("absorb"):
		is_absorb_preparing = true
	elif is_absorb_preparing:
		execute_absorb_action()
		is_absorb_preparing = false
			
	handle_aim_and_release()
	
	queue_redraw()
	move_and_slide()

# --- 受傷判定 (由 Hurtbox 節點連線過來) ---
func _on_hurtbox_area_entered(area):
	if area.has_method("reflect") and not area.get("is_reflected"):
		if not is_invincible:
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
		if area.has_method("reflect") and not area.get("is_reflected"):
			area.reflect(-area.direction if "direction" in area else Vector2.ZERO, 1.5)

func execute_absorb_action():
	var targets = bounce_zone.get_overlapping_areas()
	for area in targets:
		if area.has_method("reflect") and not area.get("is_reflected"):
			if captured_bullets.size() < max_bullet_storage:
				absorb_bullet(area)
	charge_bar.visible = not captured_bullets.is_empty()
	# 修正：使用 float() 避免精度丟失警告
	charge_bar.value = float(captured_bullets.size())

# --- 視覺繪製 ---
func _draw():
	var radius = 50.0
	if bounce_collision.shape is CircleShape2D:
		radius = bounce_collision.shape.radius

	if is_parry_preparing:
		draw_circle(Vector2.ZERO, radius, Color(1, 1, 1, 0.1))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color(1, 1, 1, 0.8), 2.0)

	if is_absorb_preparing:
		draw_circle(Vector2.ZERO, radius, Color(0, 0.5, 1.0, 0.15))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color(0, 0.8, 1.0, 0.6), 2.0)
	
	if is_aiming:
		var pulse = (sin(Time.get_ticks_msec() * 0.01) * 0.1) + 1.0
		draw_circle(Vector2.ZERO, radius * pulse, Color(1.0, 0.3, 0.1, 0.2))
		draw_arc(Vector2.ZERO, radius * pulse, 0, TAU, 48, Color(1.0, 0.8, 0.0, 0.8), 3.0)

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
	if Input.is_action_just_pressed("dash") and direction != Vector2.ZERO and current_stamina >= 30.0:
		perform_dash()
	var current_speed = dash_speed if is_dashing else walk_speed
	# 修正：確保除法中使用 float 避免 "Integer division" 警告
	var speed_mult = 1.0 / float(Engine.time_scale) if is_aiming else 1.0
	velocity = direction * current_speed * speed_mult

func perform_dash():
	current_stamina -= 30.0
	is_dashing = true
	await get_tree().create_timer(0.15).timeout 
	is_dashing = false

func handle_resources(delta):
	if current_stamina < max_stamina:
		current_stamina = min(current_stamina + 15.0 * delta, max_stamina)

func absorb_bullet(bullet):
	if not captured_bullets.has(bullet):
		captured_bullets.append(bullet)
		bullet.set_physics_process(false)
		bullet.visible = false
		bullet.set_deferred("monitorable", false)
		bullet.set_deferred("monitoring", false)

func handle_aim_and_release():
	if captured_bullets.is_empty(): 
		aim_line.visible = false
		is_aiming = false
		return
	if Input.is_action_pressed("skill_release"):
		is_aiming = true
		Engine.time_scale = bullet_time_scale
		aim_line.visible = true
		aim_line.set_point_position(0, global_position) 
		aim_line.set_point_position(1, get_global_mouse_position())
	if Input.is_action_just_released("skill_release"):
		is_aiming = false
		Engine.time_scale = 1.0
		aim_line.visible = false
		launch_captured_bullets()

func launch_captured_bullets():
	var power_multiplier = 1.0 + (float(captured_bullets.size()) * 0.2)
	var target_dir = (get_global_mouse_position() - global_position).normalized()
	for bullet in captured_bullets:
		if is_instance_valid(bullet):
			bullet.visible = true
			bullet.global_position = global_position
			bullet.set_deferred("monitorable", true)
			bullet.set_deferred("monitoring", true)
			bullet.set_physics_process(true)
			bullet.reflect(target_dir, power_multiplier)
	captured_bullets.clear()
	charge_bar.visible = false
