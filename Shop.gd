extends Control

@onready var gold_label = $GoldLabel
@onready var item_container = $VBoxContainer

func _ready():
	$Back.pressed.connect(_on_Back_pressed)
	$NextPage.pressed.connect(_on_NextPage_pressed)  # 新增
	_update_gold_label()

	var buttons = item_container.get_children()
	for i in range(min(buttons.size(), Playerdata_Globle.ITEMS.size())):
		var btn = buttons[i]
		var item_data = Playerdata_Globle.ITEMS[i]
		btn.text = item_data["name"]
		var price_label = btn.get_node_or_null("Price_Label")
		if price_label:
			price_label.text = str(item_data["cost"]) + " coin"
		if i in Playerdata_Globle.purchased_items:
			_grey_out(btn)
		else:
			btn.pressed.connect(_on_buy_item.bind(i, btn))

func _on_buy_item(index: int, btn: Button):
	var item = Playerdata_Globle.ITEMS[index]
	if Playerdata_Globle.gold < item["cost"]:
		print("金幣不足！")
		return
	Playerdata_Globle.gold -= item["cost"]
	Playerdata_Globle.purchased_items.append(index)
	Playerdata_Globle.inventory.append(index)
	_grey_out(btn)
	_update_gold_label()
	print("購買：", item["name"], "，已加入背包")

func _grey_out(btn: Button):
	btn.disabled = true
	btn.modulate = Color(0.4, 0.4, 0.4)
	var price_label = btn.get_node_or_null("Price_Label")
	if price_label:
		price_label.modulate = Color(0.4, 0.4, 0.4)

func _update_gold_label():
	if gold_label:
		gold_label.text = "金幣：" + str(Playerdata_Globle.gold)

func _on_Back_pressed():
	get_tree().change_scene_to_file("res://main.tscn")

func _on_NextPage_pressed():
	get_tree().change_scene_to_file("res://Shop2.tscn")
