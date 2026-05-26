extends Node

const SAVE_PATH = "user://save_slot_%d.json"

# 從 Playerdata_Globle 收集所有需要存檔的資料
func get_save_data() -> Dictionary:
	return {
		"gold": Playerdata_Globle.gold,
		"purchased_items": Playerdata_Globle.purchased_items,
		"inventory": Playerdata_Globle.inventory,
		"equipped_items": Playerdata_Globle.equipped_items,
		"max_hp": Playerdata_Globle.max_hp,
		"max_stamina": Playerdata_Globle.max_stamina,
		"max_mp": Playerdata_Globle.max_mp,
		"walk_speed": Playerdata_Globle.walk_speed,
		"dash_speed": Playerdata_Globle.dash_speed,
		"stamina_regen_idle": Playerdata_Globle.stamina_regen_idle,
		"stamina_regen_move": Playerdata_Globle.stamina_regen_move,
		"mp_regen_speed": Playerdata_Globle.mp_regen_speed,
		"hp_regen_speed": Playerdata_Globle.hp_regen_speed,
		"dash_stamina_cost": Playerdata_Globle.dash_stamina_cost,
		"absorb_mp_cost": Playerdata_Globle.absorb_mp_cost,
		"base_hp_potion": Playerdata_Globle.base_hp_potion,
		"base_stamina_potion": Playerdata_Globle.base_stamina_potion,
		"base_mp_potion": Playerdata_Globle.base_mp_potion,
		"base_invincible": Playerdata_Globle.base_invincible,
		"hp_potion_upgrades": Playerdata_Globle.hp_potion_upgrades,
		"stamina_potion_upgrades": Playerdata_Globle.stamina_potion_upgrades,
		"mp_potion_upgrades": Playerdata_Globle.mp_potion_upgrades,
		"invincible_upgrades": Playerdata_Globle.invincible_upgrades,
		"reward_multiplier_upgrades": Playerdata_Globle.reward_multiplier_upgrades,
		"reward_multiplier": Playerdata_Globle.reward_multiplier,
	}

# 將存檔資料寫回 Playerdata_Globle
func apply_save_data(data: Dictionary):
	Playerdata_Globle.gold = data.get("gold", 1000)
	
	# 強制把陣列內容轉成 int，避免 JSON 讀出 float 造成比對失敗
	var raw_purchased = data.get("purchased_items", [])
	Playerdata_Globle.purchased_items = []
	for v in raw_purchased:
		Playerdata_Globle.purchased_items.append(int(v))
	
	var raw_inventory = data.get("inventory", [])
	Playerdata_Globle.inventory = []
	for v in raw_inventory:
		Playerdata_Globle.inventory.append(int(v))
	
	var raw_equipped = data.get("equipped_items", [-1,-1,-1,-1,-1])
	Playerdata_Globle.equipped_items = []
	for v in raw_equipped:
		Playerdata_Globle.equipped_items.append(int(v))
	
	# 以下維持原本不變
	Playerdata_Globle.max_hp = data.get("max_hp", 100.0)
	Playerdata_Globle.max_stamina = data.get("max_stamina", 100.0)
	Playerdata_Globle.max_mp = data.get("max_mp", 100.0)
	Playerdata_Globle.walk_speed = data.get("walk_speed", 200.0)
	Playerdata_Globle.dash_speed = data.get("dash_speed", 1000.0)
	Playerdata_Globle.stamina_regen_idle = data.get("stamina_regen_idle", 20.0)
	Playerdata_Globle.stamina_regen_move = data.get("stamina_regen_move", 5.0)
	Playerdata_Globle.mp_regen_speed = data.get("mp_regen_speed", 0.2)
	Playerdata_Globle.hp_regen_speed = data.get("hp_regen_speed", 0.01)
	Playerdata_Globle.dash_stamina_cost = data.get("dash_stamina_cost", 30.0)
	Playerdata_Globle.absorb_mp_cost = data.get("absorb_mp_cost", 10.0)
	Playerdata_Globle.base_hp_potion = int(data.get("base_hp_potion", 5))
	Playerdata_Globle.base_stamina_potion = int(data.get("base_stamina_potion", 1))
	Playerdata_Globle.base_mp_potion = int(data.get("base_mp_potion", 1))
	Playerdata_Globle.base_invincible = int(data.get("base_invincible", 1))
	Playerdata_Globle.hp_potion_upgrades = int(data.get("hp_potion_upgrades", 0))
	Playerdata_Globle.stamina_potion_upgrades = int(data.get("stamina_potion_upgrades", 0))
	Playerdata_Globle.mp_potion_upgrades = int(data.get("mp_potion_upgrades", 0))
	Playerdata_Globle.invincible_upgrades = int(data.get("invincible_upgrades", 0))
	Playerdata_Globle.reward_multiplier_upgrades = int(data.get("reward_multiplier_upgrades", 0))
	Playerdata_Globle.reward_multiplier = data.get("reward_multiplier", 1.0)
	Playerdata_Globle.reset_consumables()

# 存檔到指定槽
func save_slot(slot: int):
	var path = SAVE_PATH % slot
	var data = get_save_data()
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	print("存檔成功：槽位 ", slot)

# 從指定槽讀取
func load_slot(slot: int) -> bool:
	var path = SAVE_PATH % slot
	if not FileAccess.file_exists(path):
		return false
	var file = FileAccess.open(path, FileAccess.READ)
	var text = file.get_as_text()
	file.close()
	var data = JSON.parse_string(text)
	if data == null:
		return false
	apply_save_data(data)
	print("讀取成功：槽位 ", slot)
	return true

# 刪除指定槽（初始化）
func delete_slot(slot: int):
	var path = SAVE_PATH % slot
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("已刪除槽位 ", slot)

# 檢查槽位是否有存檔
func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(SAVE_PATH % slot)

# 取得槽位摘要文字（顯示在選擇畫面）
func get_slot_summary(slot: int) -> String:
	if not slot_exists(slot):
		return "（空）"
	var file = FileAccess.open(SAVE_PATH % slot, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if data == null:
		return "（讀取失敗）"
	return "金幣：%d　倍率：%.1f　已購裝備：%d件" % [
		data.get("gold", 0),
		data.get("reward_multiplier", 1.0),
		(data.get("purchased_items", []) as Array).size()
	]
