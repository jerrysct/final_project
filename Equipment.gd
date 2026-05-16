extends Control

const SLOT_COUNT = 5

func _ready():
	$Back.pressed.connect(_on_Back_pressed)
	
	for i in range(SLOT_COUNT):
		var btn = $HBoxContainer.get_child(i)
		btn.pressed.connect(_on_slot_pressed.bind(i))
	
	_refresh_slots()

func _refresh_slots():
	for i in range(SLOT_COUNT):
		var btn = $HBoxContainer.get_child(i)
		var item_index = Playerdata_Globle.equipped_items[i]
		if item_index == -1:
			btn.text = "[ 空 ]"
			btn.modulate = Color(1, 1, 1)
		else:
			btn.text = Playerdata_Globle.ITEMS[item_index]["name"]
			btn.modulate = Color(0.5, 1.0, 0.5)  # 已裝備顯示綠色

func _on_slot_pressed(slot_index: int):
	var current = Playerdata_Globle.equipped_items[slot_index]
	
	if current != -1:
		# 已有裝備 → 卸下，放回背包
		Playerdata_Globle.remove_item_effect(current)
		Playerdata_Globle.inventory.append(current)
		Playerdata_Globle.equipped_items[slot_index] = -1
		print("卸下：", Playerdata_Globle.ITEMS[current]["name"])
		_refresh_slots()
	else:
		# 空槽 → 跳到選擇場景
		if Playerdata_Globle.inventory.is_empty():
			print("背包是空的！")
			return
		Playerdata_Globle.selected_slot = slot_index
		get_tree().change_scene_to_file("res://ItemSelect.tscn")

func _on_Back_pressed():
	get_tree().change_scene_to_file("res://main.tscn")
