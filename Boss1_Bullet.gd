extends Area2D

enum BulletColor {
	RED,
	BLUE,
	GREEN,
	YELLOW
}

enum BulletType {
	NORMAL,
	BURST
}

@export var speed: float = 260.0
@export var damage: int = 10
@export var slow_duration: float = 2.0
@export var slow_multiplier: float = 0.5

@export var life_time: float = 8.0
@export var rotate_speed: float = 8.0

@export var burst_travel_time: float = 0.9
@export var burst_ring_count: int = 16
@export var burst_ring_speed: float = 230.0
@export var phase_two_burst_ring_count: int = 24
@export var phase_two_burst_ring_speed: float = 270.0

# 緩速彈視覺設定
# slow_aura_size_multiplier 會依照普通子彈貼圖大小，自動縮放冰環。
# 如果冰環還是太大，請把 1.05 改成 0.9 或 0.8。
@export var slow_aura_size_multiplier: float = 1.05
@export var slow_aura_alpha: float = 0.75
@export var slow_bullet_scale: float = 1.0
@export var slow_rotate_speed: float = 14.0

# 👇 【修改】：移除了 @export，確保預設絕對是 0 (不會反彈)，且不會在面板被誤改
var max_bounces: int = 0 
var _current_bounces: int = 0
# 👆 ================== 👆

var direction: Vector2 = Vector2.DOWN
var color_type: int = BulletColor.RED
var bullet_type: int = BulletType.NORMAL

var is_reflected: bool = false
var is_absorbed: bool = false
var is_phantom: bool = false
var can_slow_player: bool = false
var is_phase_two: bool = false

var _base_rotate_speed: float = 8.0

# --- 用來讓玩家判斷能不能吸收的變數 ---
var can_be_absorbed: bool = true
# ----------------------------------------

@onready var sprite: Sprite2D = $Sprite2D
@onready var slow_aura: Sprite2D = get_node_or_null("SlowAura") as Sprite2D


func _ready() -> void:
	add_to_group("bullets")

	_base_rotate_speed = rotate_speed
	_ensure_slow_aura()

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

	update_visual()


func _physics_process(delta: float) -> void:
	if is_absorbed:
		return

	if direction == Vector2.ZERO:
		direction = Vector2.DOWN

	var move_dist = speed * delta
	var new_pos = global_position + direction.normalized() * move_dist

	# 【反彈邏輯】：在移動前先用射線看前方有沒有牆壁
	if max_bounces > 0 and _current_bounces < max_bounces:
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsRayQueryParameters2D.create(global_position, new_pos)
		var result = space_state.intersect_ray(query)

		# 如果撞到了，而且是牆壁
		if result and result.collider.is_in_group("wall"):
			_current_bounces += 1
			# 入射角 = 反射角 (使用 bounce 計算)
			direction = direction.bounce(result.normal).normalized()

			# 稍微把子彈推離牆壁一點點，避免卡牆
			global_position = result.position + direction * 2.0
			return

	# 如果沒撞牆，就正常移動
	global_position = new_pos

	if sprite != null:
		sprite.rotation += rotate_speed * delta

	if slow_aura != null and slow_aura.visible:
		slow_aura.rotation -= rotate_speed * 0.75 * delta


func setup(
	new_color: int,
	new_direction: Vector2,
	phantom: bool = false,
	slow_bullet: bool = false,
	new_speed: float = -1.0,
	new_bullet_type: int = BulletType.NORMAL,
	phase_two: bool = false
) -> void:
	color_type = new_color
	direction = new_direction.normalized() if new_direction != Vector2.ZERO else Vector2.DOWN
	is_phantom = phantom
	can_slow_player = slow_bullet
	bullet_type = new_bullet_type
	is_phase_two = phase_two
	is_reflected = false
	is_absorbed = false

	# 【保險機制】：在 setup 呼叫時重置反彈次數，確保重複利用時乾淨
	_current_bounces = 0

	# 自動判斷此子彈是否能被吸收
	can_be_absorbed = (not is_phantom) and (bullet_type != BulletType.BURST)

	if new_speed > 0.0:
		speed = new_speed

	update_visual()

	if bullet_type == BulletType.BURST:
		start_burst_timer()
	else:
		start_life_timer()


func start_life_timer() -> void:
	await get_tree().create_timer(life_time).timeout

	if is_instance_valid(self) and not is_absorbed:
		queue_free()


func start_burst_timer() -> void:
	await get_tree().create_timer(burst_travel_time).timeout

	if is_instance_valid(self) and not is_absorbed:
		explode_into_ring()


func explode_into_ring() -> void:
	if bullet_type != BulletType.BURST:
		return

	var ring_count = phase_two_burst_ring_count if is_phase_two else burst_ring_count
	var ring_speed = phase_two_burst_ring_speed if is_phase_two else burst_ring_speed

	for i in range(ring_count):
		var bullet = duplicate()
		get_tree().current_scene.add_child(bullet)

		bullet.global_position = global_position

		var angle = TAU * float(i) / float(ring_count)
		var ring_direction = Vector2.RIGHT.rotated(angle)

		var phantom = false
		var slow_bullet = false

		if is_phase_two:
			phantom = randf() < 0.25
			slow_bullet = randf() < 0.15

		bullet.setup(
			get_random_color(),
			ring_direction,
			phantom,
			slow_bullet,
			ring_speed,
			BulletType.NORMAL,
			is_phase_two
		)

	queue_free()


func reflect(new_direction: Vector2, multiplier: float = 1.0) -> void:
	if is_phantom:
		# 幻影子彈不能被反彈，也不會因為玩家反彈而消失。
		# 它會繼續照原本方向移動，命中玩家時仍會造成傷害。
		return

	max_bounces = 0 # 玩家反彈後，子彈失去反彈牆壁的能力

	is_reflected = true
	is_absorbed = false
	direction = new_direction.normalized() if new_direction != Vector2.ZERO else -direction.normalized()
	speed *= 1.2
	damage = int(float(damage) * multiplier)

	visible = true
	set_physics_process(true)
	set_deferred("monitorable", true)
	set_deferred("monitoring", true)

	modulate = Color.WHITE
	update_visual()


func change_color(new_color: int) -> void:
	color_type = new_color
	update_visual()


func _ensure_slow_aura() -> void:
	if slow_aura != null:
		return

	if sprite == null:
		return

	slow_aura = Sprite2D.new()
	slow_aura.name = "SlowAura"

	# 如果你有手動放 SlowAura，程式會優先使用你手動放的冰環 PNG。
	# 如果沒有手動放，才會暫時使用本體貼圖當作外圈提示。
	slow_aura.texture = sprite.texture

	slow_aura.centered = sprite.centered
	slow_aura.offset = sprite.offset
	slow_aura.position = sprite.position
	slow_aura.z_index = sprite.z_index - 1
	slow_aura.visible = false
	add_child(slow_aura)


func _sync_slow_aura_size() -> void:
	if slow_aura == null:
		return

	if sprite == null:
		return

	if slow_aura.texture == null:
		return

	if sprite.texture == null:
		return

	var bullet_size: Vector2 = sprite.texture.get_size()
	var aura_size: Vector2 = slow_aura.texture.get_size()

	if bullet_size.x <= 0.0 or bullet_size.y <= 0.0:
		return

	if aura_size.x <= 0.0 or aura_size.y <= 0.0:
		return

	var scale_x: float = bullet_size.x / aura_size.x
	var scale_y: float = bullet_size.y / aura_size.y
	var final_scale: float = min(scale_x, scale_y) * slow_aura_size_multiplier

	# 重要：普通子彈本體通常會在 Sprite2D 上另外縮放，例如 scale = 0.1。
	# 所以冰環不能只看貼圖大小，還必須乘上 sprite.scale，
	# 否則冰環會用原始大小顯示，看起來會比子彈大好幾倍。
	slow_aura.scale = Vector2(
		sprite.scale.x * final_scale,
		sprite.scale.y * final_scale
	)


func update_visual() -> void:
	if sprite == null:
		return

	_ensure_slow_aura()

	match color_type:
		BulletColor.RED:
			sprite.modulate = Color.RED
		BulletColor.BLUE:
			sprite.modulate = Color.BLUE
		BulletColor.GREEN:
			sprite.modulate = Color.GREEN
		BulletColor.YELLOW:
			sprite.modulate = Color.YELLOW

	if is_phantom:
		sprite.modulate.a = 0.35
	else:
		sprite.modulate.a = 1.0

	# 緩速彈不要改變原本顏色，避免干擾 Boss1 的顏色順序機制。
	# 這版只顯示冰藍外圈，且會依照普通子彈貼圖大小自動縮放，不會再變成超大。
	if can_slow_player and bullet_type != BulletType.BURST:
		scale = Vector2(slow_bullet_scale, slow_bullet_scale)
		rotate_speed = slow_rotate_speed

		if slow_aura != null:
			slow_aura.visible = true

			# 重要：不要在這裡寫 slow_aura.texture = sprite.texture。
			# 否則你在場景裡手動設定的冰環 PNG 會被覆蓋。
			_sync_slow_aura_size()

			slow_aura.modulate = Color(0.35, 0.85, 1.0, slow_aura_alpha)
	else:
		rotate_speed = _base_rotate_speed

		if slow_aura != null:
			slow_aura.visible = false

		if bullet_type == BulletType.BURST:
			scale = Vector2(2.0, 2.0)
		else:
			scale = Vector2(1.0, 1.0)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("wall"):
		# 如果還有反彈次數，撞到牆壁不要馬上銷毀
		if max_bounces > 0 and _current_bounces < max_bounces:
			return

		queue_free()
		return

	if bullet_type == BulletType.BURST:
		return

	if is_absorbed:
		return

	if is_reflected and body.has_method("receive_reflected_bullet"):
		body.receive_reflected_bullet(color_type, is_phantom)
		queue_free()
		return

	if is_reflected:
		return

	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)

		if can_slow_player and body.has_method("apply_slow"):
			body.apply_slow(slow_multiplier, slow_duration)

		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if bullet_type == BulletType.BURST:
		return

	if is_absorbed:
		return

	if area.has_method("refract_bullet"):
		area.refract_bullet(self)


func get_random_color() -> int:
	var colors = [
		BulletColor.RED,
		BulletColor.BLUE,
		BulletColor.YELLOW,
		BulletColor.GREEN
	]

	return colors.pick_random()
