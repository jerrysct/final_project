extends Control

@onready var grid = $GridContainer

func _ready():
	#$Back.pressed.connect(_on_Back_pressed)
	_build_items()

func _build_items():
	for child in grid.get_children():
		child.queue_free()
	
	for i in range(Playerdata_Globle.inventory.size()):
		var item_index = Playerdata_Globle.inventory[i]
		var item = Playerdata_Globle.ITEMS[item_index]
		
		var btn = Button.new()
		btn.text = item["name"]
		btn.custom_minimum_size = Vector2(120, 120)
		btn.pressed.connect(_on_item_selected.bind(i))
		grid.add_child(btn)

func _on_item_selected(inventory_index: int):
	var slot = Playerdata_Globle.selected_slot
	var item_index = Playerdata_Globle.inventory[inventory_index]
	
	Playerdata_Globle.equipped_items[slot] = item_index
	Playerdata_Globle.apply_item_effect(item_index)
	Playerdata_Globle.inventory.remove_at(inventory_index)
	
	print("裝備：", Playerdata_Globle.ITEMS[item_index]["name"], " → 槽位 ", slot)
	get_tree().change_scene_to_file("res://Equipment.tscn")

#func _on_Back_pressed():
	#get_tree().change_scene_to_file("res://Equipment.tscn")
