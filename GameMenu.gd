extends Control

func _ready():
	$BackButton.pressed.connect(_on_back_pressed)
	$VBoxContainer/SaveButton.pressed.connect(_on_save_pressed)
	$VBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)
	$VBoxContainer/CreditsButton.pressed.connect(_on_credits_pressed)
	$CreditsPanel.visible = false

	# 填入開發者名單（改成你們的名字）
	$CreditsPanel/VBoxContainer/Dev1.text = "爆肝一號：（歐騰）"
	$CreditsPanel/VBoxContainer/Dev2.text = "爆肝二號：（剉冰）"
	$CreditsPanel/VBoxContainer/Dev3.text = "爆肝三號：（無鹽）"
	$CreditsPanel/VBoxContainer/Dev4.text = "爆肝四號：（薯條）"
	$CreditsPanel/VBoxContainer/CloseBtn.pressed.connect(
		func(): $CreditsPanel.visible = false
	)

func _on_save_pressed():
	SaveManager.save_slot(Playerdata_Globle.current_slot)
	print("已存檔至槽位 ", Playerdata_Globle.current_slot)

func _on_quit_pressed():
	get_tree().change_scene_to_file("res://SaveSelect.tscn")

func _on_credits_pressed():
	$CreditsPanel.visible = true

func _on_back_pressed():
	get_tree().change_scene_to_file("res://main.tscn")
