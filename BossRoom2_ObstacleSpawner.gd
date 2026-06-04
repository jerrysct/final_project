extends Node

@export var obstacle_scene: PackedScene

@export var spawn_interval_min: float = 9.0
@export var spawn_interval_max: float = 12.0
@export var spawn_margin: float = 160.0
@export var object_radius: float = 90.0
@export var min_player_distance: float = 180.0
@export var max_spawn_attempts: int = 80
@export var min_occupied_distance: float = 190.0
@export var spawn_count_min: int = 1
@export var spawn_count_max: int = 2

@export var obstacle_lifetime: float = 7.0
@export var max_obstacles: int = 3

@export var min_boss_distance: float = 260.0
@export var min_tentacle_distance: float = 180.0

@export var debug_enabled: bool = true

var room: Node = null
var boss: Node2D = null
var player: Node2D = null

var _timer: float = 0.0


func setup(room_node: Node, boss_node: Node2D) -> void:
	room = room_node
	boss = boss_node
	_roll_timer()

	if debug_enabled:
		print("ObstacleSpawner setup complete")


func _process(delta: float) -> void:
	if room == null:
		return

	_find_player_if_needed()

	_timer -= delta

	if _timer <= 0.0:
		if debug_enabled:
			print("ObstacleSpawner timer triggered")

		_roll_timer()
		_spawn_obstacle_group()


func _roll_timer() -> void:
	_timer = randf_range(spawn_interval_min, spawn_interval_max)


func _spawn_obstacle_group() -> void:
	if obstacle_scene == null:
		if debug_enabled:
			print("ObstacleSpawner obstacle_scene not assigned")
		return

	if _get_obstacle_count() >= max_obstacles:
		if debug_enabled:
			print("Obstacle count reached max: ", max_obstacles)
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
			print("Obstacle instantiate failed")
			return

		if obstacle is Node2D:
			(obstacle as Node2D).global_position = pos

		if "lifetime" in obstacle:
			obstacle.set("lifetime", obstacle_lifetime)

		get_tree().current_scene.add_child(obstacle)

		if debug_enabled:
			print("Obstacle spawned at ", pos)
			

func _is_valid_spawn_position(pos: Vector2) -> bool:
	if player != null and is_instance_valid(player):
		if pos.distance_to(player.global_position) < min_player_distance:
			return false

	if boss != null and is_instance_valid(boss):
		if pos.distance_to(boss.global_position) < min_boss_distance:
			return false

	return true


func _find_player_if_needed() -> void:
	if player != null and is_instance_valid(player):
		return

	var players: Array[Node] = get_tree().get_nodes_in_group("player")

	if players.size() > 0:
		player = players[0] as Node2D


func _get_obstacle_count() -> int:
	var count: int = 0

	for node in get_tree().get_nodes_in_group("boss2_obstacle"):
		if node != null and is_instance_valid(node):
			count += 1

	return count

func _get_safe_spawn_position() -> Vector2:
	if room == null:
		return Vector2.INF

	if room.has_method("get_safe_field_spawn_position"):
		return room.get_safe_field_spawn_position(
			spawn_margin,
			object_radius,
			min_player_distance,
			max_spawn_attempts
		)

	return Vector2.INF
