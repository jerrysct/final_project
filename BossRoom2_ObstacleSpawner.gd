extends Node

@export var obstacle_scene: PackedScene

@export var spawn_interval_min: float = 4.0
@export var spawn_interval_max: float = 6.0

@export var spawn_count_min: int = 1
@export var spawn_count_max: int = 1

@export var obstacle_lifetime: float = 7.0
@export var max_obstacles: int = 3

@export var spawn_margin: float = 70.0
@export var object_radius: float = 35.0
@export var min_player_distance: float = 90.0
@export var max_spawn_attempts: int = 300

@export var debug_enabled: bool = true

var room: Node = null
var boss: Node = null
var _spawn_timer: float = 0.0


func setup(room_ref: Node, boss_ref: Node) -> void:
	room = room_ref
	boss = boss_ref
	_schedule_next_spawn()

	if debug_enabled:
		print("ObstacleSpawner setup complete")


func _process(delta: float) -> void:
	if room == null:
		return

	if boss == null or not is_instance_valid(boss):
		return

	_spawn_timer -= delta

	if _spawn_timer <= 0.0:
		if debug_enabled:
			print("ObstacleSpawner timer triggered")

		_spawn_obstacle_group()
		_schedule_next_spawn()


func _spawn_obstacle_group() -> void:
	if obstacle_scene == null:
		if debug_enabled:
			print("ObstacleSpawner obstacle_scene not assigned")
		return

	if _get_obstacle_count() >= max_obstacles:
		if debug_enabled:
			print("ObstacleSpawner max reached")
		return

	var count: int = randi_range(spawn_count_min, spawn_count_max)

	for i in range(count):
		if _get_obstacle_count() >= max_obstacles:
			return

		var pos: Vector2 = _get_safe_spawn_position()

		if pos == Vector2.INF:
			if debug_enabled:
				print("Obstacle spawn skipped: no safe position")
			return

		var obstacle: Node = obstacle_scene.instantiate()

		if obstacle == null:
			if debug_enabled:
				print("Obstacle instantiate failed")
			return

		if obstacle is Node2D:
			(obstacle as Node2D).global_position = pos

		if "lifetime" in obstacle:
			obstacle.set("lifetime", obstacle_lifetime)

		_get_spawn_parent().add_child(obstacle)

		if debug_enabled:
			print("Obstacle spawned at ", pos)


func _get_safe_spawn_position() -> Vector2:
	if room == null:
		return Vector2.INF

	if not room.has_method("get_safe_position_custom"):
		return Vector2.INF

	return room.get_safe_position_custom(
		spawn_margin,
		object_radius,
		min_player_distance,
		max_spawn_attempts,
		Callable(room, "is_position_valid_for_obstacle")
	)


func _schedule_next_spawn() -> void:
	_spawn_timer = randf_range(spawn_interval_min, spawn_interval_max)


func _get_obstacle_count() -> int:
	return get_tree().get_nodes_in_group("boss2_obstacle").size()


func _get_spawn_parent() -> Node:
	var tree := get_tree()

	if tree == null:
		return self

	if tree.current_scene != null:
		return tree.current_scene

	return tree.root
