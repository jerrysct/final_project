extends Area2D

@export var speed: float = 160.0
@export var damage: float = 12.0
@export var lifetime: float = 5.0

@export var split_delay: float = 0.8
@export var split_count: int = 6
@export var split_speed_multiplier: float = 1.15
@export var split_bullet_scene: PackedScene

@export var debug_enabled: bool = true

var direction: Vector2 = Vector2.RIGHT
var is_reflected: bool = false
var is_absorbed: bool = false

var _has_split: bool = false
var _is_dead: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)

	if debug_enabled:
		print("Boss2_BurstBullet ready")

	call_deferred("_start_split_timer")

	var completed: bool = await _safe_wait(lifetime)

	if not completed:
		return

	if is_instance_valid(self) and not _is_dead:
		queue_free()


func setup(spawn_pos: Vector2, fire_direction: Vector2) -> void:
	global_position = spawn_pos

	if fire_direction.length_squared() > 0.0001:
		direction = fire_direction.normalized()


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	if is_absorbed:
		return

	global_position += direction * speed * delta


@warning_ignore("unused_parameter")
func reflect(new_direction: Vector2 = Vector2.ZERO, power_multiplier: float = 1.0) -> void:
	if debug_enabled:
		print("Boss2_BurstBullet cannot be reflected before split")

	# 大顆爆裂彈不能反射，所以這裡什麼都不做
	return


func _start_split_timer() -> void:
	var completed: bool = await _safe_wait(split_delay)

	if not completed:
		return

	if not is_instance_valid(self):
		return

	if _is_dead:
		return

	if is_absorbed:
		if debug_enabled:
			print("Burst bullet did not split because it was absorbed")
		return

	_split()


func _split() -> void:
	if _has_split:
		return

	_has_split = true

	if split_bullet_scene == null:
		if debug_enabled:
			print("Boss2_BurstBullet split_bullet_scene not assigned")
		_is_dead = true
		queue_free()
		return

	if debug_enabled:
		print("Boss2_BurstBullet split into ", split_count, " bullets")

	for i in range(split_count):
		var angle: float = TAU * float(i) / float(split_count)
		var fire_dir: Vector2 = Vector2.RIGHT.rotated(angle)

		var bullet: Node = split_bullet_scene.instantiate()
		get_tree().current_scene.add_child(bullet)

		if bullet.has_method("setup"):
			bullet.setup(global_position, fire_dir)

		if "speed" in bullet:
			bullet.speed = speed * split_speed_multiplier

	_is_dead = true
	queue_free()


@warning_ignore("unused_parameter")
func _on_body_entered(body: Node) -> void:
	if _is_dead:
		return

	if is_absorbed:
		return

	# 大顆爆裂彈不在這裡處理玩家傷害
	# 玩家受傷交給 player.gd 的 Hurtbox area_entered 處理
	return


func _safe_wait(seconds: float) -> bool:
	if not is_inside_tree():
		return false

	var tree := get_tree()

	if tree == null:
		return false

	await tree.create_timer(seconds).timeout

	if not is_instance_valid(self):
		return false

	if not is_inside_tree():
		return false

	return true
