extends Control

# 用變數記錄目前「被選中」的關卡場景路徑（預設為空）
var selected_stage_path: String = ""

func _ready():
	# 1. 連結各個 Boss 關卡按鈕的點擊事件
	# 當點擊 Boss 按鈕時，只會「記錄目標關卡」，不會馬上切換場景
	$ScrollContainer/HBoxContainer/Boss1.pressed.connect(func(): _on_stage_selected("res://scenes/Boss1.tscn"))
	$ScrollContainer/HBoxContainer/Boss2.pressed.connect(func(): _on_stage_selected("res://scenes/Boss2.tscn"))
	$ScrollContainer/HBoxContainer/Boss3.pressed.connect(func(): _on_stage_selected("res://scenes/Boss3_Melee.tscn"))
	
	# 2. 連結右下角「開始戰鬥」按鈕
	$StartBattleButton.pressed.connect(_on_start_battle_pressed)
	
	# 3. 遊戲剛開始時，因為還沒選關卡，先把開始戰鬥按鈕停用（變灰色），避免玩家空選進去
	$StartBattleButton.disabled = true

# 當玩家點選某個 Boss 關卡時觸發
func _on_stage_selected(stage_path: String):
	selected_stage_path = stage_path
	print("目前選中的關卡路徑：", selected_stage_path)
	
	# 既然玩家已經選了關卡，就把右下角的「開始戰鬥」按鈕啟用
	$StartBattleButton.disabled = false
	
	# 【進階可選效果】你可以在這裡加上讓選中的按鈕變色或放大的視覺提示

# 當玩家按下右下角的「開始戰鬥」時觸發
func _on_start_battle_pressed():
	if selected_stage_path != "":
		print("正式進入戰鬥！載入：", selected_stage_path)
		get_tree().change_scene_to_file(selected_stage_path)
