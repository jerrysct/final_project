extends Area2D

@export var speed: float = 220.0
@export var turn_speed: float = 2.5
@export var damage: float = 8.0
@export var lifetime: float = 6.0

var direction: Vector2 = Vector2.RIGHT
var is_reflected: bool = false
var is_absorbed: bool = false

var _target: Node2D = null

func _ready() -> void:
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

func _physics_process(delta: float) -> void:
	if is_reflected:
		global_position += direction.normalized() * speed * delta
		return

	_update_homing_direction(delta)
	global_position += direction.normalized() * speed * delta

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
	direction = Vector2.from_angle(current_angle + turn_amount)

func reflect(new_direction: Vector2, multiplier: float = 1.0) -> void:
	is_reflected = true
	_target = null
	if new_direction.length_squared() > 0.0001:
		direction = new_direction.normalized()
	damage *= multiplier

func _on_area_entered(area: Area2D) -> void:
	if is_reflected or is_absorbed:
		return
	if area.name != "Hurtbox":
		return

	var player_body: Node = area.get_parent()
	if player_body == null or not player_body.has_method("take_damage"):
		return

	player_body.take_damage(damage)
	queue_free()

func _on_body_entered(body: Node) -> void:
	if not is_reflected:
		return
	if body.is_in_group("player"):
		return
	if not body.has_method("take_damage"):
		return

	body.take_damage(damage)
	queue_free()

func _find_player_target() -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_target = players[0] as Node2D
