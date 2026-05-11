extends CharacterBody2D

# --- 基礎移動數值 ---
@export var walk_speed = 200.0     # 正常走路速度
@export var dash_speed = 600.0    # 位移時的衝刺速度
@export var max_stamina = 100.0   # 體力上限
@export var stamina_regen_idle = 20.0
@export var stamina_regen_move = 5.0

# --- 反彈與蓄力數值 ---
@export var energy_max = 100.0    # 能量上限
@export var absorb_energy_cost = 20.0 # 蓄力每秒消耗能量

# --- 節點引用 (請確保場景中名稱一致) ---
@onready var stamina_bar = $CanvasLayer/ProgressBar 
@onready var bounce_zone = $BounceZone  

# --- 內部狀態變數 ---
var current_stamina = 100.0
var current_energy = 100.0
var is_dashing = false
var is_absorbing = false
var captured_bullets = [] # 儲存吸收的子彈

func _physics_process(delta):
	# 1. 處理體力與能量回復
	handle_resources(delta)
	
	# 2. 更新 UI (假設進度條顯示體力)
	stamina_bar.value = current_stamina
	
	# 3. 移動邏輯
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	handle_movement(direction)
	
	# 4. 瞬間反彈機制 (Parry)
	if Input.is_action_just_pressed("parry"):
		execute_instant_parry()
		
	# 5. 蓄力吸收機制 (Absorb)
	handle_absorb_mechanic(delta)
	
	move_and_slide()

# --- 資源管理 ---
func handle_resources(delta):
	# 體力回復
	if current_stamina < max_stamina:
		var regen = stamina_regen_idle if velocity == Vector2.ZERO else stamina_regen_move
		current_stamina = min(current_stamina + regen * delta, max_stamina)
	
	# 能量自然回補 (可選)
	if not is_absorbing and current_energy < energy_max:
		current_energy = min(current_energy + 5.0 * delta, energy_max)

# --- 移動與衝刺 ---
func handle_movement(direction):
	if Input.is_action_just_pressed("dash") and direction != Vector2.ZERO and current_stamina >= 30.0:
		perform_dash()
	
	if is_dashing:
		velocity = direction.normalized() * dash_speed
	else:
		velocity = direction * walk_speed

func perform_dash():
	current_stamina -= 30.0 
	is_dashing = true
	await get_tree().create_timer(0.2).timeout
	is_dashing = false

# --- 核心機制 A：瞬間反彈 ---
func execute_instant_parry():
	var targets = bounce_zone.get_overlapping_areas()
	var success = false
	
	for bullet in targets:
		if bullet.has_method("reflect") and not bullet.get("is_reflected"):
			# 1.5倍傷害，朝反方向彈回
			var reflect_dir = -bullet.direction if "direction" in bullet else Vector2.ZERO
			bullet.reflect(reflect_dir, 1.5)
			success = true
			current_energy = min(current_energy + 10.0, energy_max) # 成功反彈獎勵能量
	
	if success:
		print("成功瞬間反彈！")

# --- 核心機制 B：蓄力吸收 ---
func handle_absorb_mechanic(delta):
	# 按住吸收鍵且還有能量
	if Input.is_action_pressed("absorb") and current_energy > 0:
		is_absorbing = true
		current_energy -= absorb_energy_cost * delta
		
		var targets = bounce_zone.get_overlapping_areas()
		for bullet in targets:
			if bullet.has_method("reflect") and not bullet.get("is_reflected"):
				if not captured_bullets.has(bullet):
					absorb_bullet(bullet)
	else:
		if is_absorbing: # 如果原本在吸收但現在停止了 (按鍵放開或能量耗盡)
			launch_captured_bullets()
			is_absorbing = false

func absorb_bullet(bullet):
	captured_bullets.append(bullet)
	# 停止子彈運作並隱藏
	bullet.set_physics_process(false)
	bullet.visible = false
	# 關閉碰撞層避免重複觸發
	bullet.set_deferred("monitorable", false)
	bullet.set_deferred("monitoring", false)

func launch_captured_bullets():
	if captured_bullets.is_empty():
		return
		
	# 朝滑鼠方向發射
	var target_dir = (get_global_mouse_position() - global_position).normalized()
	
	for bullet in captured_bullets:
		if is_instance_valid(bullet):
			bullet.visible = true
			bullet.global_position = global_position # 從玩家位置統一射出
			bullet.set_deferred("monitorable", true)
			bullet.set_deferred("monitoring", true)
			bullet.set_physics_process(true)
			bullet.reflect(target_dir, 1.0)
			
	captured_bullets.clear()
	print("蓄力釋放！")
