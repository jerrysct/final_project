extends Area2D

@export var speed: float = 200.0
@export var damage: float = 5.0
@export var lifetime: float = 5.0
@export var debug_enabled: bool = false

@export var reflect_arm_time: float = 0.18
@export var reflect_arm_distance: float = 70.0

var can_be_reflected: bool = false
var _spawn_position: Vector2 = Vector2.ZERO
var _age: float = 0.0

var direction: Vector2 = Vector2.RIGHT
var is_reflected: bool = false
var is_absorbed: bool = false


func _ready() -> void:
	monitoring = true
	monitorable = true

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	var completed: bool = await _safe_wait(lifetime)

	if not completed:
		return

	if is_instance_valid(self):
		queue_free()


func setup(spawn_pos: Vector2, fire_direction: Vector2) -> void:
	global_position = spawn_pos
	_spawn_position = spawn_pos
	_age = 0.0
	can_be_reflected = false
	is_reflected = false
	is_absorbed = false

	if fire_direction.length_squared() > 0.0001:
		direction = fire_direction.normalized()
	else:
		direction = Vector2.RIGHT


func _physics_process(delta: float) -> void:
	if is_absorbed:
		return

	_age += delta
	global_position += direction * speed * delta

	if not can_be_reflected:
		var traveled_distance: float = global_position.distance_to(_spawn_position)

		if _age >= reflect_arm_time or traveled_distance >= reflect_arm_distance:
			can_be_reflected = true


func reflect(new_direction: Vector2 = Vector2.ZERO, power_multiplier: float = 1.0) -> void:
	if not can_be_reflected:
		if debug_enabled:
			print("Toxic bullet not armed yet, cannot reflect")
		return

	is_reflected = true
	is_absorbed = false

	if new_direction.length_squared() > 0.0001:
		direction = new_direction.normalized()
	else:
		direction = -direction

	speed *= power_multiplier

	if debug_enabled:
		print("Boss2_ToxicBullet reflected")


func _on_body_entered(body: Node) -> void:
	if body == null:
		return

	# 撞到障礙物，不管有沒有被反彈，都直接消失
	if body.is_in_group("boss2_obstacle"):
		if debug_enabled:
			print("Toxic bullet blocked by obstacle: ", body.name)

		queue_free()
		return

	if is_absorbed:
		return

	# 沒有被玩家反彈前，不傷害魚 / 觸手 / Boss
	if not is_reflected:
		return

	# 反彈彈不要打到玩家自己
	if body.is_in_group("player"):
		return

	if not body.has_method("take_damage"):
		return

	var damage_amount: int = damage_to_tentacle

	if body.is_in_group("boss2_fish"):
		damage_amount = damage_to_fish

	body.take_damage(damage_amount)

	if debug_enabled:
		print("Reflected toxic bullet hit: ", body.name, " damage = ", damage_amount)

	queue_free()


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

@export var damage_to_tentacle: int = 25
@export var damage_to_fish: int = 25
