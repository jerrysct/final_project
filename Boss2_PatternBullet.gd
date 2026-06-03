extends Area2D

@export var speed: float = 180.0
@export var damage: float = 7.0
@export var damage_to_tentacle: int = 25
@export var damage_to_fish: int = 25
@export var lifetime: float = 6.0
@export var debug_enabled: bool = false

@export var reflect_arm_time: float = 0.12
@export var reflect_arm_distance: float = 45.0

var direction: Vector2 = Vector2.RIGHT
var can_be_reflected: bool = false
var is_reflected: bool = false
var is_absorbed: bool = false

var _spawn_position: Vector2 = Vector2.ZERO
var _age: float = 0.0

var _mode: String = "straight"

var _boss: Node2D = null

var _return_out_time: float = 0.75
var _return_pause_time: float = 0.25
var _return_back_speed: float = 190.0
var _return_elapsed: float = 0.0
var _return_state: int = 0

var _orbit_center: Node2D = null
var _orbit_angle: float = 0.0
var _orbit_radius: float = 70.0
var _orbit_angular_speed: float = 6.0
var _orbit_time: float = 0.8
var _orbit_elapsed: float = 0.0
var _release_speed: float = 180.0
var _released_from_orbit: bool = false


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


func setup_straight(spawn_pos: Vector2, fire_dir: Vector2, bullet_speed: float) -> void:
	_mode = "straight"
	global_position = spawn_pos
	_spawn_position = spawn_pos
	_age = 0.0
	speed = bullet_speed
	is_reflected = false
	is_absorbed = false
	can_be_reflected = false

	if fire_dir.length_squared() > 0.0001:
		direction = fire_dir.normalized()
	else:
		direction = Vector2.RIGHT


func setup_return(
	spawn_pos: Vector2,
	fire_dir: Vector2,
	boss_node: Node2D,
	out_speed: float,
	back_speed: float,
	out_time: float,
	pause_time: float
) -> void:
	_mode = "return"
	global_position = spawn_pos
	_spawn_position = spawn_pos
	_age = 0.0
	_boss = boss_node
	speed = out_speed
	_return_back_speed = back_speed
	_return_out_time = out_time
	_return_pause_time = pause_time
	_return_elapsed = 0.0
	_return_state = 0
	is_reflected = false
	is_absorbed = false
	can_be_reflected = false

	if fire_dir.length_squared() > 0.0001:
		direction = fire_dir.normalized()
	else:
		direction = Vector2.RIGHT


func setup_orbit(
	boss_node: Node2D,
	start_angle: float,
	orbit_radius: float,
	orbit_time: float,
	angular_speed: float,
	release_speed: float
) -> void:
	_mode = "orbit"
	_boss = boss_node
	_orbit_center = boss_node
	_orbit_angle = start_angle
	_orbit_radius = orbit_radius
	_orbit_time = orbit_time
	_orbit_angular_speed = angular_speed
	_release_speed = release_speed
	_orbit_elapsed = 0.0
	_released_from_orbit = false
	is_reflected = false
	is_absorbed = false
	can_be_reflected = false

	if _orbit_center != null and is_instance_valid(_orbit_center):
		global_position = _orbit_center.global_position + Vector2.RIGHT.rotated(_orbit_angle) * _orbit_radius
		_spawn_position = global_position


func _physics_process(delta: float) -> void:
	if is_absorbed:
		return

	_age += delta

	if not can_be_reflected:
		var traveled_distance: float = global_position.distance_to(_spawn_position)

		if _age >= reflect_arm_time or traveled_distance >= reflect_arm_distance:
			can_be_reflected = true

	if _mode == "straight":
		_process_straight(delta)
	elif _mode == "return":
		_process_return(delta)
	elif _mode == "orbit":
		_process_orbit(delta)


func _process_straight(delta: float) -> void:
	global_position += direction * speed * delta


func _process_return(delta: float) -> void:
	_return_elapsed += delta

	if _return_state == 0:
		global_position += direction * speed * delta

		if _return_elapsed >= _return_out_time:
			_return_state = 1
			_return_elapsed = 0.0
			return

	if _return_state == 1:
		if _return_elapsed >= _return_pause_time:
			_return_state = 2
			_return_elapsed = 0.0
			return

	if _return_state == 2:
		if _boss == null or not is_instance_valid(_boss):
			global_position += direction * _return_back_speed * delta
			return

		var back_dir: Vector2 = _boss.global_position - global_position

		if back_dir.length_squared() > 0.0001:
			direction = back_dir.normalized()

		global_position += direction * _return_back_speed * delta


func _process_orbit(delta: float) -> void:
	if _released_from_orbit:
		global_position += direction * speed * delta
		return

	if _orbit_center == null or not is_instance_valid(_orbit_center):
		_released_from_orbit = true
		return

	_orbit_elapsed += delta
	_orbit_angle += _orbit_angular_speed * delta

	global_position = _orbit_center.global_position + Vector2.RIGHT.rotated(_orbit_angle) * _orbit_radius

	if _orbit_elapsed >= _orbit_time:
		_released_from_orbit = true
		direction = (global_position - _orbit_center.global_position).normalized()
		speed = _release_speed
		_spawn_position = global_position
		_age = 0.0
		can_be_reflected = true


func reflect(new_direction: Vector2 = Vector2.ZERO, power_multiplier: float = 1.0) -> void:
	if not can_be_reflected:
		if debug_enabled:
			print("Pattern bullet not armed yet, cannot reflect")
		return

	is_reflected = true
	is_absorbed = false
	_mode = "straight"
	_released_from_orbit = true

	if new_direction.length_squared() > 0.0001:
		direction = new_direction.normalized()
	else:
		direction = -direction

	speed *= power_multiplier

	if debug_enabled:
		print("Boss2_PatternBullet reflected")


func _on_body_entered(body: Node) -> void:
	if body == null:
		return

	if body.is_in_group("boss2_obstacle"):
		queue_free()
		return

	if is_absorbed:
		return

	if not is_reflected:
		return

	if body.is_in_group("player"):
		return

	if not body.has_method("take_damage"):
		return

	var damage_amount: int = damage_to_tentacle

	if body.is_in_group("boss2_fish"):
		damage_amount = damage_to_fish

	body.take_damage(damage_amount)

	if debug_enabled:
		print("Reflected pattern bullet hit: ", body.name, " damage = ", damage_amount)

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
