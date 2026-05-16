extends CharacterBody2D

# --- 節點引用 ---
@onready var stamina_bar = $CanvasLayer/ProgressBar
@onready var bounce_zone = $BounceZone

# --- 內部狀態變數 (僅紀錄當前值與狀態) ---
var current_hp: float
var current_stamina: float
var current_mp: float
var is_dashing = false
var is_absorbing = false
var captured_bullets = []

func _ready():
	# 讀取全域數值並補滿
	current_hp = Playerdata_Globle.max_hp
	current_stamina = Playerdata_Globle.max_stamina
	current_mp = Playerdata_Globle.max_mp

func _physics_process(delta):
	handle_resources(delta)
	stamina_bar.value = current_stamina
	
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	handle_movement(direction)
	
	if Input.is_action_just_pressed("parry"):
		execute_instant_parry()
		
	handle_absorb_mechanic(delta)
	move_and_slide()

func handle_resources(delta):
	# HP 回覆邏輯 (確保玩家還活著才回血)
	if current_hp > 0 and current_hp < Playerdata_Globle.max_hp:
		current_hp = min(current_hp + Playerdata_Globle.hp_regen_speed * delta, Playerdata_Globle.max_hp)
		
	# 體力回覆邏輯
	if current_stamina < Playerdata_Globle.max_stamina:
		var regen = Playerdata_Globle.stamina_regen_idle if velocity == Vector2.ZERO else Playerdata_Globle.stamina_regen_move
		current_stamina = min(current_stamina + regen * delta, Playerdata_Globle.max_stamina)
	
	# MP 回覆邏輯
	if not is_absorbing and current_mp < Playerdata_Globle.max_mp:
		current_mp = min(current_mp + Playerdata_Globle.mp_regen_speed * delta, Playerdata_Globle.max_mp)

func handle_movement(direction):
	# 衝刺判斷
	if Input.is_action_just_pressed("dash") and direction != Vector2.ZERO and current_stamina >= Playerdata_Globle.dash_stamina_cost:
		perform_dash()
	
	# 套用速度
	if is_dashing:
		velocity = direction.normalized() * Playerdata_Globle.dash_speed
	else:
		velocity = direction * Playerdata_Globle.walk_speed

func perform_dash():
	current_stamina -= Playerdata_Globle.dash_stamina_cost
	is_dashing = true
	await get_tree().create_timer(0.2).timeout
	is_dashing = false

func execute_instant_parry():
	var targets = bounce_zone.get_overlapping_areas()
	var success = false
	for bullet in targets:
		if bullet.has_method("reflect") and not bullet.get("is_reflected"):
			var reflect_dir = -bullet.direction if "direction" in bullet else Vector2.ZERO
			bullet.reflect(reflect_dir, 1.5)
			success = true
			current_mp = min(current_mp + 10.0, Playerdata_Globle.max_mp)
	if success:
		print("成功瞬間反彈！")

func handle_absorb_mechanic(delta):
	if Input.is_action_pressed("absorb") and current_mp > 0:
		is_absorbing = true
		current_mp -= Playerdata_Globle.absorb_mp_cost * delta
		var targets = bounce_zone.get_overlapping_areas()
		for bullet in targets:
			if bullet.has_method("reflect") and not bullet.get("is_reflected"):
				if not captured_bullets.has(bullet):
					absorb_bullet(bullet)
	else:
		if is_absorbing:
			launch_captured_bullets()
			is_absorbing = false

func take_damage(amount: float):
	current_hp -= amount
	current_hp = max(current_hp, 0.0)
	if current_hp <= 0:
		die()

func die():
	get_tree().reload_current_scene()

func absorb_bullet(bullet):
	captured_bullets.append(bullet)
	bullet.set_physics_process(false)
	bullet.visible = false
	bullet.set_deferred("monitorable", false)
	bullet.set_deferred("monitoring", false)

func launch_captured_bullets():
	if captured_bullets.is_empty():
		return
	var target_dir = (get_global_mouse_position() - global_position).normalized()
	for bullet in captured_bullets:
		if is_instance_valid(bullet):
			bullet.visible = true
			bullet.global_position = global_position
			bullet.set_deferred("monitorable", true)
			bullet.set_deferred("monitoring", true)
			bullet.set_physics_process(true)
			bullet.reflect(target_dir, 1.0)
	captured_bullets.clear()
