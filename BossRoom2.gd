extends Node2D

@export var tentacle_scene: PackedScene
@export var max_tentacles: int = 4

@export var phase2_respawn_interval: float = 10.0
@export var phase3_respawn_delay: float = 15.0
@export var phase3_tentacle_count: int = 3

@export var min_boss_distance: float = 260.0
@export var max_boss_distance: float = 560.0
@export var min_tentacle_distance: float = 160.0
@export var max_spawn_attempts: int = 80

@export var spawn_area_left: float = -700.0
@export var spawn_area_right: float = 700.0
@export var spawn_area_top: float = -450.0
@export var spawn_area_bottom: float = 450.0

@export var tentacle_spawn_margin: float = 80.0
@export var fish_spawn_margin: float = 80.0

@export var apply_camera_limits: bool = true

@onready var player_spawn: Marker2D = $PlayerSpawnPoint
@onready var boss_spawn: Marker2D = $BossSpawnPoint
@onready var boss: Node2D = $Boss2

@export var camera_zoom: Vector2 = Vector2(0.85, 0.85)
var camera: Camera2D = null
# --- 結算畫面 UI ---
@onready var end_screen: Panel = get_node_or_null("CanvasLayer/EndScreen") as Panel
@onready var title_label: Label = get_node_or_null("CanvasLayer/EndScreen/VBoxContainer/TitleLabel") as Label
@onready var gold_label: Label = get_node_or_null("CanvasLayer/EndScreen/VBoxContainer/GoldLabel") as Label
@onready var return_button: Button = get_node_or_null("CanvasLayer/EndScreen/VBoxContainer/ReturnButton") as Button

var _tentacles: Array[Node] = []
var _phase2_respawn_timer: float = 0.0
var _phase3_respawn_timer: float = 0.0

const MAIN_SCENE_PATH: String = "res://main.tscn"


func _ready() -> void:
	_spawn_selected_player()
	_position_boss()
	_setup_camera()
	_setup_result_ui()

	if boss == null:
		print("找不到 Boss，請確認場景裡的 Boss 節點名稱是不是 Boss2")
		return

	if boss.has_method("set_room_controller"):
		boss.set_room_controller(self)

	if boss.has_signal("died"):
		if not boss.died.is_connected(show_victory):
			boss.died.connect(show_victory)
	else:
		print("Boss2 沒有 died signal，勝利畫面可能不會自動顯示")
		
	# 初始化模組化生成器
	var obstacle_spawner = get_node_or_null("ObstacleSpawner")
	if obstacle_spawner and obstacle_spawner.has_method("setup"):
		obstacle_spawner.setup(self, boss)
		
	var reverse_zone_spawner = get_node_or_null("ReverseZoneSpawner")
	if reverse_zone_spawner and reverse_zone_spawner.has_method("setup"):
		reverse_zone_spawner.setup(self, boss)

	print("Boss位置 = ", boss.global_position)
	print("BossRoom2 spawn area = ", get_spawn_area_rect(0.0))

	spawn_initial_tentacles()


func _process(delta: float) -> void:
	_update_tentacle_respawn(delta)


# ============================================================
# Player / Boss / Camera
# ============================================================

func _spawn_selected_player() -> void:
	_remove_existing_players_in_room()

	if Playerdata_Globle.selected_character.is_empty():
		push_warning("尚未選擇角色，使用預設 Character1")
		Playerdata_Globle.selected_character = "Character1"

	var scene_path: String = Playerdata_Globle.get_selected_character_scene_path()
	print("玩家場景路徑：", scene_path)
	print("角色場景是否存在：", ResourceLoader.exists(scene_path))

	var player_scene: PackedScene = load(scene_path) as PackedScene

	if player_scene == null:
		push_error("找不到角色場景：%s" % scene_path)
		return

	var player: Node = player_scene.instantiate()
	player.name = "Player"
	add_child(player)

	print("Player root type = ", player.get_class())

	if player_spawn != null:
		print("PlayerSpawnPoint = ", player_spawn.global_position)

	if player_spawn != null and player is Node2D:
		(player as Node2D).global_position = player_spawn.global_position
		print("Player final position = ", (player as Node2D).global_position)
	else:
		print("player_spawn 為 null，或 player 不是 Node2D")

	if not player.is_in_group("player"):
		player.add_to_group("player")

	print("Player in group player = ", player.is_in_group("player"))
	print("BossRoom2 已生成 Player")


func _remove_existing_players_in_room() -> void:
	var existing_named_player: Node = get_node_or_null("Player")

	if existing_named_player != null:
		existing_named_player.queue_free()

	for existing_player in get_tree().get_nodes_in_group("player"):
		if existing_player != null and existing_player.get_parent() == self:
			existing_player.queue_free()


func _position_boss() -> void:
	if boss == null:
		return

	if boss_spawn != null:
		boss.global_position = boss_spawn.global_position


func _setup_camera() -> void:
	var player: Node = get_node_or_null("Player")

	if player == null:
		push_warning("找不到 Player，無法設定 Camera2D")
		return

	camera = player.get_node_or_null("Camera2D") as Camera2D

	if camera == null:
		push_warning("Player 底下找不到 Camera2D，請確認 Camera2D 是 Player 的直接子節點")
		return

	camera.enabled = true
	camera.make_current()
	camera.zoom = camera_zoom

	if apply_camera_limits:
		camera.limit_left = int(min(spawn_area_left, spawn_area_right))
		camera.limit_right = int(max(spawn_area_left, spawn_area_right))
		camera.limit_top = int(min(spawn_area_top, spawn_area_bottom))
		camera.limit_bottom = int(max(spawn_area_top, spawn_area_bottom))

# ============================================================
# Result UI
# ============================================================

func _setup_result_ui() -> void:
	if end_screen != null:
		end_screen.hide()
		end_screen.process_mode = Node.PROCESS_MODE_ALWAYS

	if return_button != null:
		if not return_button.pressed.is_connected(_on_return_button_pressed):
			return_button.pressed.connect(_on_return_button_pressed)


func show_victory() -> void:
	var earned_gold: int = int(100 * Playerdata_Globle.reward_multiplier)

	if title_label != null:
		title_label.text = "Victory"

	if gold_label != null:
		gold_label.text = "+%d Gold" % earned_gold
		gold_label.show()

	if end_screen != null:
		end_screen.show()

	Playerdata_Globle.gold += earned_gold
	SaveManager.save_slot(Playerdata_Globle.current_slot)

	print("戰鬥勝利！獲得金幣：", earned_gold, "，目前總金幣：", Playerdata_Globle.gold)

	get_tree().paused = true


func show_defeat() -> void:
	if title_label != null:
		title_label.text = "You Loss"

	if gold_label != null:
		gold_label.hide()

	if end_screen != null:
		end_screen.show()

	get_tree().paused = true


func _on_return_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)


# ============================================================
# Spawn Area API
# Boss2.gd 會使用 get_fish_spawn_rect()
# BossRoom2 自己會使用 get_tentacle_spawn_rect()
# ============================================================

# ============================================================# =================================================

func get_spawn_area_rect(margin: float = 0.0) -> Rect2:
	var left: float = min(spawn_area_left, spawn_area_right) + margin
	var right: float = max(spawn_area_left, spawn_area_right) - margin
	var top: float = min(spawn_area_top, spawn_area_bottom) + margin
	var bottom: float = max(spawn_area_top, spawn_area_bottom) - margin

	if right < left:
		var center_x: float = (left + right) * 0.5
		left = center_x - 1.0
		right = center_x + 1.0

	if bottom < top:
		var center_y: float = (top + bottom) * 0.5
		top = center_y - 1.0
		bottom = center_y + 1.0

	return Rect2(
		Vector2(left, top),
		Vector2(right - left, bottom - top)
	)


func get_tentacle_spawn_rect() -> Rect2:
	return get_spawn_area_rect(tentacle_spawn_margin)


func get_fish_spawn_rect() -> Rect2:
	return get_spawn_area_rect(fish_spawn_margin)


func get_random_point_in_spawn_area(margin: float = 0.0) -> Vector2:
	var rect: Rect2 = get_spawn_area_rect(margin)
	return _get_random_point_in_rect(rect)


func get_safe_field_spawn_position(margin: float, radius: float, min_player_dist: float, max_attempts: int) -> Vector2:
	var rect: Rect2 = get_spawn_area_rect(margin)
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	var player_node: Node2D = null
	if players.size() > 0:
		player_node = players[0] as Node2D
		
	for i in range(max_attempts):
		var pos: Vector2 = _get_random_point_in_rect(rect)
		
		# 檢查與玩家距離
		if player_node and pos.distance_to(player_node.global_position) < min_player_dist:
			continue
			
		# 檢查與 Boss 距離
		if boss and pos.distance_to(boss.global_position) < min_boss_distance:
			continue
			
		# 檢查與觸手距離
		var too_close_to_tentacle := false
		for tentacle in _tentacles:
			if is_instance_valid(tentacle) and tentacle is Node2D:
				if pos.distance_to(tentacle.global_position) < min_tentacle_distance:
					too_close_to_tentacle = true
					break
		if too_close_to_tentacle:
			continue
			
		return pos
		
	return Vector2.INF


func _get_random_point_in_rect(rect: Rect2) -> Vector2:
	return Vector2(
		randf_range(rect.position.x, rect.position.x + rect.size.x),
		randf_range(rect.position.y, rect.position.y + rect.size.y)
	)


func _clamp_point_to_rect(point: Vector2, rect: Rect2) -> Vector2:
	var min_x: float = rect.position.x
	var max_x: float = rect.position.x + rect.size.x
	var min_y: float = rect.position.y
	var max_y: float = rect.position.y + rect.size.y

	return Vector2(
		clamp(point.x, min_x, max_x),
		clamp(point.y, min_y, max_y)
	)


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

	var rect: Rect2 = get_tentacle_spawn_rect()
	var spawn_pos: Vector2 = _get_safe_tentacle_spawn_position()
	spawn_pos = _clamp_point_to_rect(spawn_pos, rect)

	var tentacle: Node = tentacle_scene.instantiate()
	add_child(tentacle)

	if tentacle is Node2D:
		(tentacle as Node2D).global_position = spawn_pos
	else:
		print("觸手不是 Node2D，無法設定位置")
		tentacle.queue_free()
		return

	if tentacle.has_method("setup_boss"):
		tentacle.setup_boss(boss)
	else:
		print("觸手沒有 setup_boss，請確認 Boss2_Tentacle.gd 掛在觸手根節點")

	print("Tentacle rect = ", rect)
	print("Tentacle final spawn_pos = ", spawn_pos)
	print("Tentacle in rect = ", rect.has_point(spawn_pos))
	print("觸手生成在：", spawn_pos)

	_tentacles.append(tentacle)

	tentacle.tree_exited.connect(
		Callable(self, "_on_tentacle_tree_exited").bind(tentacle)
	)


func _get_safe_tentacle_spawn_position() -> Vector2:
	var rect: Rect2 = get_tentacle_spawn_rect()

	if boss == null or not is_instance_valid(boss):
		return _get_random_point_in_rect(rect)

	var boss_pos: Vector2 = boss.global_position

	for attempt in range(max_spawn_attempts):
		var spawn_pos: Vector2 = _get_random_point_in_rect(rect)
		spawn_pos = _clamp_point_to_rect(spawn_pos, rect)

		if _is_valid_tentacle_position(spawn_pos, boss_pos):
			return spawn_pos

	# 保底 1：
	# 找不到同時符合 Boss 距離與觸手距離的點時，
	# 仍然只在 rect 內找不靠近其他觸手的位置。
	for attempt in range(30):
		var fallback_pos: Vector2 = _get_random_point_in_rect(rect)
		fallback_pos = _clamp_point_to_rect(fallback_pos, rect)

		if _is_not_too_close_to_other_tentacles(fallback_pos):
			return fallback_pos

	# 保底 2：
	# 最後回傳 rect 中心點，保證不出界。
	var center_pos: Vector2 = rect.position + rect.size * 0.5
	return _clamp_point_to_rect(center_pos, rect)


func _is_valid_tentacle_position(spawn_pos: Vector2, boss_pos: Vector2) -> bool:
	var rect: Rect2 = get_tentacle_spawn_rect()

	if not rect.has_point(spawn_pos):
		return false

	var distance_to_boss: float = spawn_pos.distance_to(boss_pos)

	if distance_to_boss < min_boss_distance:
		return false

	if distance_to_boss > max_boss_distance:
		return false

	if not _is_not_too_close_to_other_tentacles(spawn_pos):
		return false

	return true


func _is_not_too_close_to_other_tentacles(spawn_pos: Vector2) -> bool:
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

	if hp_ratio > 0.75:
		return

	if hp_ratio > 0.5:
		_phase2_respawn_timer -= delta

		if _phase2_respawn_timer <= 0.0:
			_phase2_respawn_timer = phase2_respawn_interval

			if active_count < max_tentacles:
				spawn_tentacle()

		return

	if active_count > 0:
		_phase3_respawn_timer = phase3_respawn_delay
		return

	if boss.has_method("is_weak") and boss.is_weak():
		_phase3_respawn_timer = phase3_respawn_delay
		return

	_phase3_respawn_timer -= delta

	if _phase3_respawn_timer <= 0.0:
		_phase3_respawn_timer = phase3_respawn_delay
		_spawn_phase3_tentacle_wave()


func _spawn_phase3_tentacle_wave() -> void:
	var spawn_count: int = min(phase3_tentacle_count, max_tentacles)

	for i in range(spawn_count):
		spawn_tentacle()

	print("Phase 3 重新生成觸手波次，數量 = ", spawn_count)
