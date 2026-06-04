extends StaticBody2D

@export var lifetime: float = 7.0
@export var debug_enabled: bool = true


func _ready() -> void:
	add_to_group("boss2_obstacle")

	# 你的玩家目前 collision_mask = 16，所以木板放在 Layer 5 (16)。
	# 如果你的玩家碰撞設定不同，這裡要跟著調。
	collision_layer = 16
	collision_mask = 0

	if debug_enabled:
		print("Obstacle ready at ", global_position)

	var completed: bool = await _safe_wait(lifetime)

	if not completed:
		return

	if is_instance_valid(self):
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
