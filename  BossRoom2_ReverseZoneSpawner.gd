extends Node

@export var reverse_zone_scene: PackedScene

@export var spawn_interval_min: float = 14.0
@export var spawn_interval_max: float = 18.0

@export var zone_lifetime: float = 5.0
@export var max_zones: int = 1
@export var phase_required: int = 3

@export var spawn_margin: float = 180.0
@export var object_radius: float = 120.0
@export var min_player_distance: float = 180.0
@export var max_spawn_attempts: int = 80

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

	if not _can_spawn():
		return

	_spawn_timer -= delta

	if _spawn_timer <= 0.0:
		_spawn_zone()
		_schedule_next_spawn()


func _can_spawn() -> bool:
	if boss == null:
		return false

	if boss.has_method("get_hp_ratio"):
		var hp_ratio: float = boss.get_hp_ratio()

		if phase_required == 3:
			return hp_ratio <= 0.5

	return true


func _spawn_zone() -> void:
	if reverse_zone_scene == null:
		return

	if _get_zone_count() >= max_zones:
		return

	var pos: Vector2 = room.get_safe_position_custom(
		spawn_margin,
		object_radius,
		min_player_distance,
		max_spawn_attempts,
		Callable(room, "is_position_valid_for_reverse_zone")
	)

	if pos == Vector2.INF:
		return

	var zone: Node = reverse_zone_scene.instantiate()

	if zone == null:
		return

	if zone is Node2D:
		(zone as Node2D).global_position = pos

	# ✅ 修正
	if "lifetime" in zone:
		zone.set("lifetime", zone_lifetime)

	get_tree().current_scene.add_child(zone)


func _schedule_next_spawn() -> void:
	_spawn_timer = randf_range(spawn_interval_min, spawn_interval_max)


func _get_zone_count() -> int:
	return get_tree().get_nodes_in_group("reverse_input_zone").size()
