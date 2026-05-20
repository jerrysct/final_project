extends Control

@onready var confirm_panel = $ConfirmPanel
@onready var confirm_label = $ConfirmPanel/VBoxContainer/Label
var pending_delete_slot: int = -1

func _ready():
	confirm_panel.visible = false
	$QuitGame.pressed.connect(func(): get_tree().quit())

	for i in range(3):
		var slot_btn = get_node("SlotsContainer/Slot%d/SlotButton" % i)
		var delete_btn = get_node("SlotsContainer/Slot%d/DeleteButton" % i)

		# 只顯示存檔名稱，不顯示摘要
		slot_btn.text = "存檔 %d" % (i + 1)

		slot_btn.pressed.connect(_on_slot_selected.bind(i))
		delete_btn.pressed.connect(_on_delete_pressed.bind(i))

	# 路徑加上 HBoxContainer/
	$ConfirmPanel/VBoxContainer/HBoxContainer/ConfirmYes.pressed.connect(_on_confirm_yes)
	$ConfirmPanel/VBoxContainer/HBoxContainer/ConfirmNo.pressed.connect(_on_confirm_no)

func _on_slot_selected(slot: int):
	if SaveManager.slot_exists(slot):
		SaveManager.load_slot(slot)
	else:
		SaveManager.apply_save_data({})
	Playerdata_Globle.current_slot = slot
	get_tree().change_scene_to_file("res://main.tscn")

func _on_delete_pressed(slot: int):
	if not SaveManager.slot_exists(slot):
		print("槽位 ", slot, " 沒有存檔")
		return
	pending_delete_slot = slot
	confirm_label.text = "確定要刪除存檔 %d 嗎？\n此操作無法復原！" % (slot + 1)
	confirm_panel.visible = true

func _on_confirm_yes():
	SaveManager.delete_slot(pending_delete_slot)
	var slot_btn = get_node("SlotsContainer/Slot%d/SlotButton" % pending_delete_slot)
	# 只顯示存檔名稱，不顯示摘要
	slot_btn.text = "存檔 %d" % (pending_delete_slot + 1)
	confirm_panel.visible = false
	pending_delete_slot = -1

func _on_confirm_no():
	confirm_panel.visible = false
	pending_delete_slot = -1
