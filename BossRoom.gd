extends Node2D

@onready var player_spawn: Marker2D = $PlayerSpawnPoint
@onready var boss_spawn: Marker2D = $BossSpawnPoint

var player: Node2D = null
var camera: Camera2D = null


func _ready() -> void:
	_spawn_selected_player()
	_position_boss()
	_setup_camera()


func _spawn_selected_player() -> void:
	var existing := get_node_or_null("Player")
	if existing:
		existing.queue_free()

	if Playerdata_Globle.selected_character.is_empty():
		push_warning("尚未選擇角色，使用預設 Character1")
		Playerdata_Globle.selected_character = "Character1"

	var scene_path := Playerdata_Globle.get_selected_character_scene_path()
	var player_scene: PackedScene = load(scene_path) as PackedScene

	if player_scene == null:
		push_error("找不到角色場景：%s" % scene_path)
		return

	player = player_scene.instantiate()
	player.name = "Player"
	add_child(player)

	if player_spawn != null:
		player.global_position = player_spawn.global_position

	if not player.is_in_group("player"):
		player.add_to_group("player")

	print("已加入所選角色：", Playerdata_Globle.selected_character, " → ", scene_path)


func _position_boss() -> void:
	var boss := get_node_or_null("Boss")

	if boss == null or boss_spawn == null:
		return

	boss.global_position = boss_spawn.global_position


func _setup_camera() -> void:
	if player == null:
		player = get_node_or_null("Player")

	if player == null:
		push_warning("找不到 Player，無法設定 Camera2D")
		return

	camera = player.get_node_or_null("Camera2D") as Camera2D

	if camera == null:
		push_warning("Player 底下找不到 Camera2D，請確認 Camera2D 是 Player 的直接子節點")
		return

	camera.enabled = true
	camera.make_current()
