extends Control

func _ready():
	# 使用匿名函式並綁定參數，將角色名稱傳入 _select_character
	$ScrollContainer/HBoxContainer/Character1.pressed.connect(func(): _select_character("Character1"))
	$ScrollContainer/HBoxContainer/Character2.pressed.connect(func(): _select_character("Character2"))
	$ScrollContainer/HBoxContainer/Character3.pressed.connect(func(): _select_character("Character3"))

func _select_character(character_name: String):
	Playerdata_Globle.selected_character = character_name
	
	# 【修改這裡】選完角色後，改為跳轉到你的關卡選擇場景（請確認你的關卡選擇檔名與路徑是否為 res://stage_select.tscn）
	get_tree().change_scene_to_file("res://stage_select.tscn")
