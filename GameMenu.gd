extends Control

func _ready():
	$BackButton.pressed.connect(_on_back_pressed)
	$VBoxContainer/SaveButton.pressed.connect(_on_save_pressed)
	$VBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)
	$VBoxContainer/CreditsButton.pressed.connect(_on_credits_pressed)
	$CreditsPanel.visible = false

	# 填入開發者名單（改成你們的名字）
	$CreditsPanel/VBoxContainer/Dev1.text = "開發者一：（名字）"
	$CreditsPanel/VBoxContainer/Dev2.text = "開發者二：（名字）"
	$CreditsPanel/VBoxContainer/Dev3.text = "開發者三：（名字）"
	$CreditsPanel/VBoxContainer/Dev4.text = "開發者四：（名字）"
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
