extends Area2D

@export var lifetime: float = 5.0
@export var reverse_duration: float = 2.5
@export var trigger_once_per_zone: bool = true

# 反轉區內反彈傷害倍率
@export var damage_bonus_multiplier: float = 1.2

# 這個半徑要跟 CollisionShape2D 的範圍差不多
# 如果你的 CircleShape2D Radius 是 120，這裡就設 120
@export var damage_bonus_radius: float = 120.0

@export var debug_enabled: bool = true

var triggered_players: Array[Node] = []


func _ready() -> void:
	add_to_group("reverse_input_zone")

	monitoring = true
	monitorable = true

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	var completed: bool = await _safe_wait(lifetime)

	if not completed:
		return

	if is_instance_valid(self):
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body == null:
		return

	if not body.is_in_group("player"):
		return

	if trigger_once_per_zone and triggered_players.has(body):
		return

	triggered_players.append(body)

	if body.has_method("apply_reverse_input"):
		body.apply_reverse_input(reverse_duration)
	elif body.has_method("set_reverse_input"):
		body.set_reverse_input(true)
		_turn_off_later(body, reverse_duration)

	if debug_enabled:
		print("Reverse zone triggered player for ", reverse_duration, " seconds")


func _turn_off_later(body: Node, duration: float) -> void:
	var completed: bool = await _safe_wait(duration)

	if not completed:
		return

	if body == null or not is_instance_valid(body):
		return

	if body.has_method("set_reverse_input"):
		body.set_reverse_input(false)


# 給子彈 reflect() 時檢查：
# 子彈如果在這個範圍內被反彈，就吃 damage_bonus_multiplier
func contains_point_for_damage_bonus(point: Vector2) -> bool:
	return global_position.distance_to(point) <= damage_bonus_radius


func get_damage_bonus_multiplier() -> float:
	return damage_bonus_multiplier


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
