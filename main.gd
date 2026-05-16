extends Control

const SHOP_SCENE_PATH = "res://Shop.tscn"
const SKILL_SCENE_PATH = "res://Equipment.tscn"
const STAGE_1_PATH = "res://scenes/stage_1.tscn"

func _ready():
	$VBoxContainer/開始遊戲.pressed.connect(_on_start_pressed)
	$VBoxContainer/商店.pressed.connect(_on_shop_pressed)
	$VBoxContainer/裝備.pressed.connect(_on_skill_pressed)
	$MenuButton.pressed.connect(_on_menu_pressed)   # 新增目錄按鈕

func _on_start_pressed():
	Playerdata_Globle.reset_consumables()
	get_tree().change_scene_to_file(STAGE_1_PATH)

func _on_shop_pressed():
	get_tree().change_scene_to_file(SHOP_SCENE_PATH)

func _on_skill_pressed():
	get_tree().change_scene_to_file(SKILL_SCENE_PATH)

func _on_menu_pressed():
	get_tree().change_scene_to_file("res://GameMenu.tscn")
