extends Control

<<<<<<< HEAD
# 將開始遊戲的目的地改為角色選擇場景
const CHARACTER_SELECT_PATH = "res://character_select.tscn" 
const SHOP_SCENE_PATH = "res://Shop.tscn"
const SKILL_SCENE_PATH = "res://Equipment.tscn"
=======
const SHOP_SCENE_PATH = "res://Shop.tscn"
const SKILL_SCENE_PATH = "res://Equipment.tscn"
const STAGE_1_PATH = "res://scenes/stage_1.tscn"
>>>>>>> 1e117bf6e76abe51d0e8b6efedf84895643d357f

func _ready():
	$VBoxContainer/開始遊戲.pressed.connect(_on_start_pressed)
	$VBoxContainer/商店.pressed.connect(_on_shop_pressed)
	$VBoxContainer/裝備.pressed.connect(_on_skill_pressed)
<<<<<<< HEAD
	$MenuButton.pressed.connect(_on_menu_pressed)   # 目錄按鈕連線

func _on_start_pressed():
	Playerdata_Globle.reset_consumables()
	# 切換到角色選擇畫面
	get_tree().change_scene_to_file(CHARACTER_SELECT_PATH)
=======
	$MenuButton.pressed.connect(_on_menu_pressed)   # 新增目錄按鈕

func _on_start_pressed():
	Playerdata_Globle.reset_consumables()
	get_tree().change_scene_to_file(STAGE_1_PATH)
>>>>>>> 1e117bf6e76abe51d0e8b6efedf84895643d357f

func _on_shop_pressed():
	get_tree().change_scene_to_file(SHOP_SCENE_PATH)

func _on_skill_pressed():
	get_tree().change_scene_to_file(SKILL_SCENE_PATH)

func _on_menu_pressed():
	get_tree().change_scene_to_file("res://GameMenu.tscn")
