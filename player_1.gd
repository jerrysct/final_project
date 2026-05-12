extends CharacterBody2D

# --- 基礎設定 ---
@export var walk_speed = 200.0
@export var dash_speed = 600.0
@export var max_stamina = 100.0
@export var max_bullet_storage = 10 
@export var bullet_time_scale = 0.2 

# --- 節點引用 ---
@onready var stamina_bar = $CanvasLayer/ProgressBar
@onready var charge_bar = $CanvasLayer2/ChargeBar
@onready var bounce_zone = $BounceZone  
@onready var aim_line = $AimLine 

# --- 狀態變數 ---
var current_stamina = 100.0
var is_dashing = false
var is_aiming = false
var captured_bullets = [] 

func _ready():
	# 初始化 UI 與 指向線
	charge_bar.max_value = max_bullet_storage
	charge_bar.visible = false
	
	aim_line.visible = false
	aim_line.width = 5.0
	# 強制確保 Line2D 只有兩個點
	aim_line.clear_points()
	aim_line.add_point(Vector2.ZERO)
	aim_line.add_point(Vector2.ZERO)
	# 關鍵：確保線條不受父節點縮放或旋轉的干擾
	aim_line.top_level = false 

func _physics_process(delta):
	stamina_bar.value = current_stamina
	
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	handle_movement(direction)
	
	if Input.is_action_just_pressed("parry"):
		execute_instant_parry()
		
	handle_absorb_logic(delta)
	handle_aim_and_release()
	
	move_and_slide()

# --- 吸收邏輯 (右鍵) ---
func handle_absorb_logic(delta):
	if Input.is_action_pressed("absorb"):
		if captured_bullets.size() < max_bullet_storage:
			var targets = bounce_zone.get_overlapping_areas()
			for bullet in targets:
				if bullet.has_method("reflect") and not bullet.get("is_reflected"):
					if not captured_bullets.has(bullet):
						absorb_bullet(bullet)
		
		if not captured_bullets.is_empty():
			charge_bar.visible = true
			charge_bar.value = captured_bullets.size()

# --- 指向瞄準與釋放 (F 鍵) ---
func handle_aim_and_release():
	if captured_bullets.is_empty(): 
		aim_line.visible = false
		is_aiming = false
		return

	if Input.is_action_pressed("skill_release"):
		is_aiming = true
		Engine.time_scale = bullet_time_scale
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

# --- 發射邏輯 ---
func launch_captured_bullets():
	var power_multiplier = 1.0 + (captured_bullets.size() * 0.2)
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
