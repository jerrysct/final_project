extends Control

const UPGRADES = [
	{
		"name": "永久增加血瓶數量",
		"cost_list": [100, 200, 300, 400, 500],
		"max_buy": 5,
		"type": "hp_potion"
	},
	{
		"name": "永久增加體力瓶數量",
		"cost_list": [100, 200],
		"max_buy": 2,
		"type": "stamina_potion"
	},
	{
		"name": "永久增加魔力瓶數量",
		"cost_list": [100, 200],
		"max_buy": 2,
		"type": "mp_potion"
	},
	{
		"name": "永久增加無敵數量",
		"cost_list": [200, 400],
		"max_buy": 2,
		"type": "invincible"
	},
	{
		"name": "提升金幣獎勵倍率",
		"cost_list": [200, 400, 600],
		"max_buy": 3,
		"type": "reward_multiplier"
	}
]

@onready var gold_label = $GoldLabel
@onready var container = $VBoxContainer

func _ready():
	$Back.pressed.connect(_on_Back_pressed)
	$PrevPage.pressed.connect(_on_PrevPage_pressed)
	_update_gold_label()
	_build_buttons()

func _build_buttons():
	var buttons = container.get_children()
	for i in range(min(buttons.size(), UPGRADES.size())):
		var btn = buttons[i]
		_refresh_button(btn, i)
		if not btn.pressed.is_connected(_on_upgrade):
			btn.pressed.connect(_on_upgrade.bind(i, btn))

func _refresh_button(btn: Button, i: int):
	var upgrade = UPGRADES[i]
	var bought = _get_bought_count(upgrade["type"])
	var max_buy = upgrade["max_buy"]
	var price_label = btn.get_node_or_null("Price_Label")

	btn.text = upgrade["name"]

	if bought >= max_buy:
		if price_label:
			price_label.text = "已達上限（" + str(bought) + "/" + str(max_buy) + "）"
		btn.disabled = true
		btn.modulate = Color(0.4, 0.4, 0.4)
		if price_label:
			price_label.modulate = Color(0.4, 0.4, 0.4)
	else:
		var next_cost = upgrade["cost_list"][bought]
		if price_label:
			price_label.text = str(next_cost) + " 金幣（" + str(bought) + "/" + str(max_buy) + "）"
			price_label.modulate = Color(1, 1, 1)
		btn.disabled = false
		btn.modulate = Color(1, 1, 1)

func _get_bought_count(type: String) -> int:
	match type:
		"hp_potion":         return Playerdata_Globle.hp_potion_upgrades
		"stamina_potion":    return Playerdata_Globle.stamina_potion_upgrades
		"mp_potion":         return Playerdata_Globle.mp_potion_upgrades
		"invincible":        return Playerdata_Globle.invincible_upgrades
		"reward_multiplier": return Playerdata_Globle.reward_multiplier_upgrades
	return 0

func _on_upgrade(i: int, btn: Button):
	var upgrade = UPGRADES[i]
	var bought = _get_bought_count(upgrade["type"])
	if bought >= upgrade["max_buy"]:
		return
	var cost = upgrade["cost_list"][bought]
	if Playerdata_Globle.gold < cost:
		print("金幣不足！需要 ", cost)
		return
	Playerdata_Globle.gold -= cost
	match upgrade["type"]:
		"hp_potion":
			Playerdata_Globle.hp_potion_upgrades += 1
			Playerdata_Globle.base_hp_potion += 1
		"stamina_potion":
			Playerdata_Globle.stamina_potion_upgrades += 1
			Playerdata_Globle.base_stamina_potion += 1
		"mp_potion":
			Playerdata_Globle.mp_potion_upgrades += 1
			Playerdata_Globle.base_mp_potion += 1
		"invincible":
			Playerdata_Globle.invincible_upgrades += 1
			Playerdata_Globle.base_invincible += 1
		"reward_multiplier":
			Playerdata_Globle.reward_multiplier_upgrades += 1
			Playerdata_Globle.reward_multiplier += 0.2
	_refresh_button(btn, i)
	_update_gold_label()

func _update_gold_label():
	if gold_label:
		gold_label.text = "金幣：" + str(Playerdata_Globle.gold)

func _on_Back_pressed():
	get_tree().change_scene_to_file("res://main.tscn")

func _on_PrevPage_pressed():
	get_tree().change_scene_to_file("res://Shop.tscn")
