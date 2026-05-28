extends Node2D

@export var tentacle_scene: PackedScene
@export var max_tentacles: int = 4

@export var phase2_respawn_interval: float = 6.0
@export var phase3_respawn_delay: float = 2.0
@export var phase3_tentacle_count: int = 4

@export var min_boss_distance: float = 280.0
@export var max_boss_distance: float = 460.0
@export var min_tentacle_distance: float = 120.0
@export var max_spawn_attempts: int = 20

@export var spawn_area_left: float = 0.0
@export var spawn_area_right: float = 900.0
@export var spawn_area_top: float = 0.0
@export var spawn_area_bottom: float = 600.0

@onready var player_spawn: Marker2D = $PlayerSpawnPoint
@onready var boss: Node2D = $Boss2
@onready var camera: Camera2D = $Camera2D

var _tentacles: Array[Node] = []
var _phase2_respawn_timer: float = 0.0
var _phase3_respawn_timer: float = 0.0


func _ready() -> void:
	_spawn_selected_player()
	_setup_camera()

	if boss == null:
		print("找不到 Boss，請確認場景裡的 Boss 節點名稱是不是 Boss2")
		return

	if boss.has_method("set_room_controller"):
		boss.set_room_controller(self)

	print("Boss位置 = ", boss.global_position)

	spawn_initial_tentacles()


func _process(delta: float) -> void:
	_update_tentacle_respawn(delta)


# ============================================================
# Player / Camera
# ============================================================

func _spawn_selected_player() -> void:
	_remove_existing_players_in_room()

	if Playerdata_Globle.selected_character.is_empty():
		push_warning("尚未選擇角色，使用預設 Character1")
		Playerdata_Globle.selected_character = "Character1"

	var scene_path: String = Playerdata_Globle.get_selected_character_scene_path()
	print("玩家場景路徑：", scene_path)

	var player_scene: PackedScene = load(scene_path) as PackedScene

	if player_scene == null:
		push_error("找不到角色場景：%s" % scene_path)
		return

	var player: Node = player_scene.instantiate()
	player.name = "Player"
	add_child(player)

	if player_spawn != null and player is Node2D:
		(player as Node2D).global_position = player_spawn.global_position

	print("BossRoom2 已生成 Player")


func _remove_existing_players_in_room() -> void:
	var existing_named_player: Node = get_node_or_null("Player")

	if existing_named_player != null:
		existing_named_player.queue_free()

	for existing_player in get_tree().get_nodes_in_group("player"):
		if existing_player != null and existing_player.get_parent() == self:
			existing_player.queue_free()


func _setup_camera() -> void:
	if camera == null:
		return

	camera.make_current()

	var player: Node = get_node_or_null("Player")

	if player != null and player is Node2D:
		camera.global_position = (player as Node2D).global_position


# ============================================================
# Tentacle Spawn
# ============================================================

func spawn_initial_tentacles() -> void:
	for i in range(max_tentacles):
		spawn_tentacle()


func spawn_tentacle() -> void:
	_cleanup_invalid_tentacles()

	if _tentacles.size() >= max_tentacles:
		return

	if tentacle_scene == null:
		print("tentacle_scene 沒設定")
		return

	if boss == null or not is_instance_valid(boss):
		print("boss 是 null，無法生成觸手")
		return

	var tentacle: Node = tentacle_scene.instantiate()
	add_child(tentacle)

	if tentacle.has_method("setup_boss"):
		tentacle.setup_boss(boss)
	else:
		print("觸手沒有 setup_boss，請確認 Boss2_Tentacle.gd 掛在觸手根節點")

	var spawn_pos: Vector2 = _get_safe_tentacle_spawn_position()

	if tentacle is Node2D:
		(tentacle as Node2D).global_position = spawn_pos
	else:
		print("觸手不是 Node2D，無法設定位置")
		tentacle.queue_free()
		return

	print("觸手生成在：", spawn_pos)

	_tentacles.append(tentacle)

	tentacle.tree_exited.connect(
		Callable(self, "_on_tentacle_tree_exited").bind(tentacle)
	)


func _get_safe_tentacle_spawn_position() -> Vector2:
	for attempt in range(max_spawn_attempts):
		var angle: float = randf() * TAU
		var dist: float = randf_range(min_boss_distance, max_boss_distance)
		var offset: Vector2 = Vector2.RIGHT.rotated(angle) * dist
		var spawn_pos: Vector2 = boss.to_global(offset)

		if _is_valid_tentacle_position(spawn_pos):
			return spawn_pos

	var fallback_angle: float = randf() * TAU
	var fallback_offset: Vector2 = Vector2.RIGHT.rotated(fallback_angle) * max_boss_distance
	var fallback_pos: Vector2 = boss.to_global(fallback_offset)

	fallback_pos.x = clamp(fallback_pos.x, spawn_area_left, spawn_area_right)
	fallback_pos.y = clamp(fallback_pos.y, spawn_area_top, spawn_area_bottom)

	return fallback_pos


func _is_valid_tentacle_position(spawn_pos: Vector2) -> bool:
	if spawn_pos.x < spawn_area_left:
		return false

	if spawn_pos.x > spawn_area_right:
		return false

	if spawn_pos.y < spawn_area_top:
		return false

	if spawn_pos.y > spawn_area_bottom:
		return false

	for existing_tentacle in _tentacles:
		if existing_tentacle == null:
			continue

		if not is_instance_valid(existing_tentacle):
			continue

		if existing_tentacle is Node2D:
			var existing_pos: Vector2 = (existing_tentacle as Node2D).global_position
			var distance_to_tentacle: float = spawn_pos.distance_to(existing_pos)

			if distance_to_tentacle < min_tentacle_distance:
				return false

	return true


func _cleanup_invalid_tentacles() -> void:
	for i in range(_tentacles.size() - 1, -1, -1):
		var tentacle: Node = _tentacles[i]

		if tentacle == null or not is_instance_valid(tentacle):
			_tentacles.remove_at(i)


func get_active_tentacle_count() -> int:
	_cleanup_invalid_tentacles()
	return _tentacles.size()


func _on_tentacle_tree_exited(tentacle: Node) -> void:
	_tentacles.erase(tentacle)

	if boss != null and is_instance_valid(boss):
		if boss.has_method("on_tentacle_removed"):
			boss.on_tentacle_removed(_tentacles.size())


# ============================================================
# Phase 2 / Phase 3 Tentacle Respawn
# ============================================================

func _update_tentacle_respawn(delta: float) -> void:
	if boss == null or not is_instance_valid(boss):
		return

	if not boss.has_method("get_hp_ratio"):
		return

	var hp_ratio: float = boss.get_hp_ratio()
	var active_count: int = get_active_tentacle_count()

	# Phase 1：75%以上，不自動補觸手
	if hp_ratio > 0.75:
		return

	# Phase 2：50%~75%，每隔一段時間補一隻觸手
	if hp_ratio > 0.5:
		_phase2_respawn_timer -= delta

		if _phase2_respawn_timer <= 0.0:
			_phase2_respawn_timer = phase2_respawn_interval

			if active_count < max_tentacles:
				spawn_tentacle()

		return

	# Phase 3：50%以下
	# 有觸手時，不補
	if active_count > 0:
		_phase3_respawn_timer = phase3_respawn_delay
		return

	# Boss 虛弱中時，不補
	if boss.has_method("is_weak") and boss.is_weak():
		_phase3_respawn_timer = phase3_respawn_delay
		return

	# 觸手全清且 Boss 虛弱結束後，延遲生成下一波觸手
	_phase3_respawn_timer -= delta

	if _phase3_respawn_timer <= 0.0:
		_phase3_respawn_timer = phase3_respawn_delay
		_spawn_phase3_tentacle_wave()


func _spawn_phase3_tentacle_wave() -> void:
	var spawn_count: int = min(phase3_tentacle_count, max_tentacles)

	for i in range(spawn_count):
		spawn_tentacle()

	print("Phase 3 重新生成觸手波次，數量 = ", spawn_count)
