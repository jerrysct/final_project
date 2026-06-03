extends Node

@export var obstacle_scene: PackedScene

@export var spawn_interval_min: float = 9.0
@export var spawn_interval_max: float = 12.0

@export var spawn_count_min: int = 1
@export var spawn_count_max: int = 2

@export var obstacle_lifetime: float = 7.0
@export var max_obstacles: int = 3

@export var spawn_margin: float = 160.0
@export var object_radius: float = 90.0
@export var min_player_distance: float = 180.0
@export var max_spawn_attempts: int = 80

@export var debug_enabled: bool = true

var room: Node = null
var boss: Node = null

var _spawn_timer: float = 0.0


func setup(room_ref: Node, boss_ref: Node) -> void:
	room = room_ref
	boss = boss_ref
	_schedule_next_spawn()


func _process(delta: float) -> void:
	if room == null:
		return

	if boss == null or not is_instance_valid(boss):
		return

	_spawn_timer -= delta

	if _spawn_timer <= 0.0:
		_spawn_obstacle_group()
		_schedule_next_spawn()


func _spawn_obstacle_group() -> void:
	if obstacle_scene == null:
		return

	if _get_obstacle_count() >= max_obstacles:
		return

	var count: int = randi_range(spawn_count_min, spawn_count_max)

	for i in range(count):
		if _get_obstacle_count() >= max_obstacles:
			return

		var pos: Vector2 = room.get_safe_position_custom(
			spawn_margin,
			object_radius,
			min_player_distance,
			max_spawn_attempts,
			Callable(room, "is_position_valid_for_obstacle")
		)

		if pos == Vector2.INF:
			return

		var obstacle: Node = obstacle_scene.instantiate()

		if obstacle == null:
			return

		if obstacle is Node2D:
			(obstacle as Node2D).global_position = pos

		# ✅ 修正這裡（沒有 has_variable）
		if "lifetime" in obstacle:
			obstacle.set("lifetime", obstacle_lifetime)

		get_tree().current_scene.add_child(obstacle)


func _schedule_next_spawn() -> void:
	_spawn_timer = randf_range(spawn_interval_min, spawn_interval_max)


func _get_obstacle_count() -> int:
	return get_tree().get_nodes_in_group("boss2_obstacle").size()
