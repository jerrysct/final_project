extends Node2D

@onready var player_spawn: Marker2D = $PlayerSpawnPoint
@onready var boss_spawn: Marker2D = $BossSpawnPoint

# --- 結算畫面 UI 參考 ---
@onready var end_screen: Panel = $CanvasLayer/EndScreen
@onready var title_label: Label = $CanvasLayer/EndScreen/VBoxContainer/TitleLabel
@onready var gold_label: Label = $CanvasLayer/EndScreen/VBoxContainer/GoldLabel
@onready var return_button: Button = $CanvasLayer/EndScreen/VBoxContainer/ReturnButton

var player: Node2D = null
var camera: Camera2D = null

const MAIN_SCENE_PATH: String = "res://main.tscn"


func _ready() -> void:
	_spawn_selected_player()
	_position_boss()
	_setup_camera()
	if end_screen:
		end_screen.hide()
		
	# 綁定按鈕點擊信號
	if return_button:
		return_button.pressed.connect(_on_return_button_pressed)


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
	
	
# 當 Boss 死亡時呼叫此函數
# 當 Boss 死亡時呼叫此函數
func show_victory() -> void:
	# 根據全域變數的倍率計算實際獲得的金幣
	var earned_gold: int = int(100 * Playerdata_Globle.reward_multiplier)
	
	title_label.text = "Victory"
	gold_label.text = "+%d Gold" % earned_gold
	gold_label.show()
	end_screen.show()
	
	# 將金幣加進全域變數中
	Playerdata_Globle.gold += earned_gold
	print("戰鬥勝利！獲得金幣：", earned_gold, "，目前總金幣：", Playerdata_Globle.gold)
	
	# 暫停遊戲，避免背景繼續運作
	get_tree().paused = true

# 當 Player 死亡時呼叫此函數
func show_defeat() -> void:
	title_label.text = "You Loss"
	gold_label.hide() # 輸了不顯示金幣
	end_screen.show()
	
	# 選擇性：暫停遊戲
	get_tree().paused = true

## 按鈕回呼函數
func _on_return_button_pressed() -> void:
	# 1. 先解除暫停
	get_tree().paused = false 
	
	# 2. 直接切換場景
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)
