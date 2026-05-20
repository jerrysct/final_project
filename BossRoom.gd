extends Node2D

@onready var player_spawn: Marker2D = $PlayerSpawnPoint
@onready var boss_spawn: Marker2D = $BossSpawnPoint
@onready var camera: Camera2D = $Camera2D

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

	var player := player_scene.instantiate()
	player.name = "Player"
	add_child(player)

	if player_spawn:
		player.global_position = player_spawn.global_position

	print("已加入所選角色：", Playerdata_Globle.selected_character, " → ", scene_path)

func _position_boss() -> void:
	var boss := get_node_or_null("Boss")
	if boss == null or boss_spawn == null:
		return
	boss.global_position = boss_spawn.global_position

func _setup_camera() -> void:
	if camera == null:
		return
	camera.make_current()
	var player := get_node_or_null("Player")
	if player:
		camera.global_position = player.global_position
