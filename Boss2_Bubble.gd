extends Area2D

@export var speed: float = 170.0
@export var travel_time: float = 0.75
@export var linger_time: float = 4.0
@export var arm_after_stop_time: float = 0.15

@export var phase1_damage: int = 6
@export var phase2_damage: int = 9
@export var phase3_damage: int = 12

@export var phase1_slow_multiplier: float = 0.75
@export var phase2_slow_multiplier: float = 0.65
@export var phase3_slow_multiplier: float = 0.55

@export var phase1_slow_duration: float = 0.6
@export var phase2_slow_duration: float = 0.85
@export var phase3_slow_duration: float = 1.1

# ✅ 爆炸設定
@export var explode_delay: float = 0.3
@export var explode_radius: float = 90.0

# ✅ 連鎖設定
@export var chain_radius: float = 80.0
@export var chain_delay: float = 0.08   # 連鎖延遲（讓爆炸更有節奏）

# ✅ 邊界
@export var use_bounds: bool = true
@export var bounds_left: float = -700.0
@export var bounds_right: float = 700.0
@export var bounds_top: float = -450.0
@export var bounds_bottom: float = 450.0
@export var bounds_margin: float = 40.0

@export var obstacle_pop_radius: float = 55.0

@export var debug_enabled: bool = false

var direction: Vector2 = Vector2.RIGHT
var phase: int = 1

var _travel_timer: float = 0.0
var _linger_timer: float = 0.0

var _is_flying: bool = true
var _is_armed: bool = false
var _is_dead: bool = false


# ============================================================
# ✅ 初始化
# ============================================================

func setup(
	start_pos: Vector2,
	fire_dir: Vector2,
	bubble_speed: float,
	bubble_travel_time: float,
	bubble_linger_time: float,
	bubble_arm_after_stop_time: float,
	boss_phase: int
) -> void:

	global_position = start_pos

	if fire_dir.length_squared() <= 0.0001:
		direction = Vector2.RIGHT
	else:
		direction = fire_dir.normalized()

	speed = bubble_speed
	travel_time = bubble_travel_time
	linger_time = bubble_linger_time
	arm_after_stop_time = bubble_arm_after_stop_time
	phase = boss_phase


func _ready() -> void:
	add_to_group("boss2_bubble")
	add_to_group("non_reflectable")  # ✅ 禁止反彈

	monitoring = true
	monitorable = true

	_travel_timer = travel_time
	_linger_timer = linger_time

	body_entered.connect(_on_body_entered)
	call_deferred("_check_initial_obstacle_overlap")

	_update_visual()


# ============================================================
# ✅ 主流程
# ============================================================

func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	if _is_flying:
		global_position += direction * speed * delta
		_travel_timer -= delta

		if use_bounds:
			_clamp_to_bounds()

		if _travel_timer <= 0.0:
			_stop_and_arm()

		return

	_linger_timer -= delta

	if _linger_timer <= 0.0:
		_explode()


# ============================================================
# ✅ 停止 + armed
# ============================================================

func _stop_and_arm() -> void:
	if _is_dead or not _is_flying:
		return

	_is_flying = false
	_update_visual()

	await get_tree().create_timer(arm_after_stop_time).timeout

	if not is_instance_valid(self) or _is_dead:
		return

	_is_armed = true
	_update_visual()


# ============================================================
# ✅ 玩家觸發
# ============================================================

func _on_body_entered(body: Node) -> void:
	if _is_dead or body == null:
		return

	if body.is_in_group("boss2_obstacle"):
		_explode()
		return

	if not _is_armed:
		return

	if body.is_in_group("player"):
		_trigger_delayed_explosion()


# ============================================================
# ✅ 延遲爆炸（入口）
# ============================================================

func _trigger_delayed_explosion() -> void:
	if _is_dead:
		return

	_is_armed = false

	await get_tree().create_timer(explode_delay).timeout

	if not is_instance_valid(self):
		return

	_explode()


# ============================================================
# ✅ 真正爆炸（核心）
# ============================================================

func _explode() -> void:
	if _is_dead:
		return

	_is_dead = true

	# ✅ AOE 傷害
	for body in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(body):
			continue

		var dist = global_position.distance_to(body.global_position)

		if dist <= explode_radius:
			var damage = _get_damage()

			if body.has_method("take_damage"):
				body.take_damage(float(damage))

			if body.has_method("apply_slow"):
				body.apply_slow(
					_get_slow_multiplier(),
					_get_slow_duration()
				)

	# ✅ 觸發周圍泡泡（真正連鎖）
	_trigger_chain()

	queue_free()


# ============================================================
# ✅ 真正連鎖系統（核心）
# ============================================================

func _trigger_chain() -> void:
	for other in get_tree().get_nodes_in_group("boss2_bubble"):
		if other == self:
			continue

		if not is_instance_valid(other):
			continue

		var dist = global_position.distance_to(other.global_position)

		if dist <= chain_radius:
			other.call_deferred("_chain_explode")


func _chain_explode() -> void:
	if _is_dead:
		return

	_is_armed = false

	await get_tree().create_timer(chain_delay).timeout

	if not is_instance_valid(self):
		return

	_explode()


# ============================================================
# ✅ Tide 推動
# ============================================================

func apply_force(dir: Vector2, force: float) -> void:
	if _is_dead:
		return

	direction = dir.normalized()
	speed = force

	_is_flying = true
	_is_armed = false
	_travel_timer = 0.5


# ============================================================
# ✅ Bounds
# ============================================================

func _clamp_to_bounds() -> void:
	var left = min(bounds_left, bounds_right) + bounds_margin
	var right = max(bounds_left, bounds_right) - bounds_margin
	var top = min(bounds_top, bounds_bottom) + bounds_margin
	var bottom = max(bounds_top, bounds_bottom) - bounds_margin

	var before = global_position

	global_position.x = clamp(global_position.x, left, right)
	global_position.y = clamp(global_position.y, top, bottom)

	if before != global_position:
		_stop_and_arm()


# ============================================================
# ✅ Obstacle
# ============================================================

func _check_initial_obstacle_overlap() -> void:
	for body in get_overlapping_bodies():
		if body != null and body.is_in_group("boss2_obstacle"):
			_explode()


# ============================================================
# ✅ Phase
# ============================================================

func _get_damage() -> int:
	match phase:
		1: return phase1_damage
		2: return phase2_damage
		_: return phase3_damage


func _get_slow_multiplier() -> float:
	match phase:
		1: return phase1_slow_multiplier
		2: return phase2_slow_multiplier
		_: return phase3_slow_multiplier


func _get_slow_duration() -> float:
	match phase:
		1: return phase1_slow_duration
		2: return phase2_slow_duration
		_: return phase3_slow_duration


# ============================================================
# ✅ 視覺
# ============================================================

func _update_visual() -> void:
	var sprite: Sprite2D = get_node_or_null("Sprite2D")

	if sprite == null:
		return

	if _is_flying:
		sprite.modulate = Color(0.6, 0.9, 1.0, 0.6)
	elif _is_armed:
		sprite.modulate = Color(0.2, 1.0, 0.8, 1.0)
	else:
		sprite.modulate = Color(0.7, 0.9, 1.0, 0.8)
