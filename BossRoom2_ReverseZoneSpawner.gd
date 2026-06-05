extends Node

@export var reverse_zone_scene: PackedScene

@export var phase_required: int = 1

@export var spawn_interval_min: float = 4.0
@export var spawn_interval_max: float = 6.0

@export var zone_lifetime: float = 5.0
@export var max_zones: int = 1

@export var spawn_margin: float = 80.0
@export var object_radius: float = 45.0
@export var min_player_distance: float = 100.0
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
		print("ReverseZoneSpawner setup complete")


func _process(delta: float) -> void:
	if room == null:
		return

	if boss == null or not is_instance_valid(boss):
		return

	if not _can_spawn_in_current_phase():
		return

	_spawn_timer -= delta

	if _spawn_timer <= 0.0:
		if debug_enabled:
			print("ReverseZoneSpawner timer triggered")

		_spawn_zone()
		_schedule_next_spawn()


func _can_spawn_in_current_phase() -> bool:
	if boss == null or not is_instance_valid(boss):
		return false

	if boss.has_method("get_current_phase"):
		return int(boss.get_current_phase()) >= phase_required

	if boss.has_method("get_hp_ratio"):
		var hp_ratio: float = boss.get_hp_ratio()

		if phase_required <= 1:
			return true

		if phase_required == 2:
			return hp_ratio <= 0.75

		if phase_required >= 3:
			return hp_ratio <= 0.5

	return true


func _spawn_zone() -> void:
	if reverse_zone_scene == null:
		if debug_enabled:
			print("ReverseZoneSpawner reverse_zone_scene not assigned")
		return

	if _get_zone_count() >= max_zones:
		if debug_enabled:
			print("ReverseZoneSpawner max reached")
		return

	var pos: Vector2 = _get_safe_spawn_position()

	if pos == Vector2.INF:
		if debug_enabled:
			print("ReverseZone spawn skipped: no safe position")
		return

	var zone: Node = reverse_zone_scene.instantiate()

	if zone == null:
		if debug_enabled:
			print("ReverseZone instantiate failed")
		return

	if zone is Node2D:
		(zone as Node2D).global_position = pos

	if "lifetime" in zone:
		zone.set("lifetime", zone_lifetime)

	_get_spawn_parent().add_child(zone)

	if debug_enabled:
		print("ReverseZone spawned at ", pos)


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
		Callable(room, "is_position_valid_for_reverse_zone")
	)


func _schedule_next_spawn() -> void:
	_spawn_timer = randf_range(spawn_interval_min, spawn_interval_max)


func _get_zone_count() -> int:
	return get_tree().get_nodes_in_group("reverse_input_zone").size()


func _get_spawn_parent() -> Node:
	var tree := get_tree()

	if tree == null:
		return self

	if tree.current_scene != null:
		return tree.current_scene

	return tree.root
