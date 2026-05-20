extends Area2D

@export var speed: float = 220.0
@export var turn_speed: float = 2.5
@export var damage: float = 8.0
@export var lifetime: float = 6.0

# 遠程 Boss 的散射/連射通常比較適合直線彈。
# 如果你想讓它變追蹤彈，再在 Inspector 打開這個。
@export var homing_enabled: bool = false

var direction: Vector2 = Vector2.RIGHT
var is_reflected: bool = false

var _target: Node2D = null


func _ready() -> void:
	monitoring = true
	monitorable = true

	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

	_find_player_target()

	await get_tree().create_timer(lifetime).timeout

	if is_instance_valid(self):
		queue_free()


func setup(spawn_position: Vector2, initial_direction: Vector2) -> void:
	global_position = spawn_position

	if initial_direction.length_squared() > 0.0001:
		direction = initial_direction.normalized()
	else:
		direction = Vector2.RIGHT

	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	if is_reflected:
		global_position += direction.normalized() * speed * delta
		rotation = direction.angle()
		return

	if homing_enabled:
		_update_homing_direction(delta)

	global_position += direction.normalized() * speed * delta
	rotation = direction.angle()


func _update_homing_direction(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_find_player_target()

	if _target == null:
		return

	var to_target: Vector2 = _target.global_position - global_position

	if to_target.length_squared() <= 0.0001:
		return

	var desired_direction: Vector2 = to_target.normalized()
	var current_angle: float = direction.angle()
	var target_angle: float = desired_direction.angle()
	var angle_diff: float = wrapf(target_angle - current_angle, -PI, PI)
	var max_turn: float = turn_speed * delta
	var turn_amount: float = clampf(angle_diff, -max_turn, max_turn)

	direction = Vector2.from_angle(current_angle + turn_amount).normalized()


func reflect(new_direction: Vector2, multiplier: float = 1.0) -> void:
	is_reflected = true
	_target = null
	homing_enabled = false

	if new_direction.length_squared() > 0.0001:
		direction = new_direction.normalized()

	damage *= multiplier
	modulate = Color.GOLD
	rotation = direction.angle()


func _on_area_entered(area: Area2D) -> void:
	# 反彈後不再用 area_entered 打玩家
	if is_reflected:
		return

	# 玩家受傷判定通常是 Hurtbox
	if area.name != "Hurtbox":
		return

	var player_body: Node = area.get_parent()

	if player_body == null:
		return

	if not player_body.has_method("take_damage"):
		return

	player_body.take_damage(damage)
	queue_free()


func _on_body_entered(body: Node) -> void:
	# 沒反彈時，不用 body_entered 打 Boss 或其他物件
	if not is_reflected:
		return

	# 避免反彈後又打到玩家自己
	if body.is_in_group("player"):
		return

	if not body.has_method("take_damage"):
		return

	body.take_damage(damage)
	queue_free()


func _find_player_target() -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")

	if players.size() > 0:
		player_assign(players[0])


func player_assign(node: Node) -> void:
	if node is Node2D:
		_target = node as Node2D
