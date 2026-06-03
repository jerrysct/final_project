extends Node

@export var reverse_zone_scene: PackedScene

@export var phase_required: int = 3
@export var spawn_margin: float = 170.0
@export var min_player_distance: float = 180.0
@export var min_boss_distance: float = 300.0
@export var min_tentacle_distance: float = 220.0
@export var max_spawn_attempts: int = 40
@export var min_occupied_distance: float = 220.0
@export var object_radius: float = 120.0
@export var spawn_interval_min: float = 14.0
@export var spawn_interval_max: float = 18.0

@export var zone_lifetime: float = 5.0
@export var max_zones: int = 1

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
		print("ReverseZoneSpawner setup complete")


func _process(delta: float) -> void:
	if room == null:
		return

	if boss == null or not is_instance_valid(boss):
		return

	if not boss.has_method("get_current_phase"):
		return

	var phase: int = boss.get_current_phase()

	if phase < phase_required:
		return

	_find_player_if_needed()

	_timer -= delta

	if _timer <= 0.0:
		_roll_timer()
		_spawn_reverse_zone()


func _roll_timer() -> void:
	_timer = randf_range(spawn_interval_min, spawn_interval_max)


func _spawn_reverse_zone() -> void:
	if reverse_zone_scene == null:
		if debug_enabled:
			print("ReverseZoneSpawner reverse_zone_scene not assigned")
		return

	if _get_zone_count() >= max_zones:
		if debug_enabled:
			print("ReverseZone count reached max: ", max_zones)
		return

	var pos: Vector2 = _get_safe_spawn_position()

	if pos == Vector2.INF:
		if debug_enabled:
			print("ReverseZone spawn skipped: no safe position")
		return

	var zone: Node = reverse_zone_scene.instantiate()

	if zone == null:
		print("ReverseZone instantiate failed")
		return

	if zone is Node2D:
		(zone as Node2D).global_position = pos

	zone.set("lifetime", zone_lifetime)

	get_tree().current_scene.add_child(zone)

	if debug_enabled:
		print("ReverseZone spawned at ", pos)


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


func _get_zone_count() -> int:
	var count: int = 0

	for node in get_tree().get_nodes_in_group("reverse_input_zone"):
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
