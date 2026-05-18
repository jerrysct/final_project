extends Node

const ITEMS = [
	{ "name": "HP + 100",       "cost": 10, "hp": 100.0 },
	{ "name": "體力 + 100",     "cost": 10, "stamina": 100.0 },
	{ "name": "MP + 100",       "cost": 10, "mp": 100.0 },
	{ "name": "血量回復 + 0.1", "cost": 10, "hp_regen": 0.1 },
	{ "name": "體力回復 + 10",  "cost": 10, "stamina_regen": 10.0 },
	{ "name": "MP 回復 + 10",   "cost": 10, "mp_regen": 10.0 },
	{ "name": "位移消耗 - 10",  "cost": 10, "dash_cost": -10.0 },
	{ "name": "蓄力消耗 - 10",  "cost": 10, "absorb_cost": -10.0 }
]

var current_slot: int = 0  # 記錄目前使用哪個存檔槽

<<<<<<< HEAD
# === 【核心修正】加入角色選擇變數，預設為空字串 ===
var selected_character: String = ""

=======
>>>>>>> 1e117bf6e76abe51d0e8b6efedf84895643d357f
# 數值上限
var max_hp: float = 100.0
var max_stamina: float = 100.0
var max_mp: float = 100.0
# 移動與性能數值
var walk_speed: float = 200.0
var dash_speed: float = 1000.0
var stamina_regen_idle: float = 20.0
var stamina_regen_move: float = 5.0
var mp_regen_speed: float = 5.0
var hp_regen_speed: float = 0.01
# 動作消耗數值
var dash_stamina_cost: float = 30.0
var absorb_mp_cost: float = 20.0
# 金幣
var gold: int = 1000
<<<<<<< HEAD
var max_bullet_storage: int = 5      # 吸收子彈的上限次數
var bullet_time_scale: float = 0.3    # 蓄力釋放時的子彈時間倍率（0.3 代表慢動作 30%）
=======
>>>>>>> 1e117bf6e76abe51d0e8b6efedf84895643d357f
# 裝備系統
var purchased_items: Array = []
var inventory: Array = []
var equipped_items: Array = [-1, -1, -1, -1, -1]
var selected_slot: int = -1

# --- 消耗品（每局重置）---
var base_hp_potion: int = 5        # 血瓶基礎數量
var base_stamina_potion: int = 1   # 體力瓶基礎數量
var base_mp_potion: int = 1        # 魔力瓶基礎數量
var base_invincible: int = 1       # 無敵基礎數量

var hp_potion: int = 5             # 當前血瓶數量
var stamina_potion: int = 1        # 當前體力瓶數量
var mp_potion: int = 1             # 當前魔力瓶數量
var invincible: int = 1            # 當前無敵數量

# --- 永久升級次數紀錄 ---
var hp_potion_upgrades: int = 0      # 最多5次
var stamina_potion_upgrades: int = 0 # 最多2次
var mp_potion_upgrades: int = 0      # 最多2次
var invincible_upgrades: int = 0     # 最多2次
var reward_multiplier_upgrades: int = 0 # 最多3次

# --- 獎勵倍率 ---
var reward_multiplier: float = 1.0

# 每局開始時重置消耗品數量
func reset_consumables():
	hp_potion = base_hp_potion
	stamina_potion = base_stamina_potion
	mp_potion = base_mp_potion
	invincible = base_invincible

# 套用裝備效果
func apply_item_effect(item_index: int):
	var item = ITEMS[item_index]
	if item.has("hp"):            max_hp += item["hp"]
	if item.has("stamina"):       max_stamina += item["stamina"]
	if item.has("mp"):            max_mp += item["mp"]
	if item.has("hp_regen"):      hp_regen_speed += item["hp_regen"]
	if item.has("stamina_regen"):
		stamina_regen_idle += item["stamina_regen"]
		stamina_regen_move += item["stamina_regen"]
	if item.has("mp_regen"):      mp_regen_speed += item["mp_regen"]
	if item.has("dash_cost"):     dash_stamina_cost = max(0.0, dash_stamina_cost + item["dash_cost"])
	if item.has("absorb_cost"):   absorb_mp_cost = max(0.0, absorb_mp_cost + item["absorb_cost"])

# 移除裝備效果
func remove_item_effect(item_index: int):
	var item = ITEMS[item_index]
	if item.has("hp"):            max_hp -= item["hp"]
	if item.has("stamina"):       max_stamina -= item["stamina"]
	if item.has("mp"):            max_mp -= item["mp"]
	if item.has("hp_regen"):      hp_regen_speed -= item["hp_regen"]
	if item.has("stamina_regen"):
		stamina_regen_idle -= item["stamina_regen"]
		stamina_regen_move -= item["stamina_regen"]
	if item.has("mp_regen"):      mp_regen_speed -= item["mp_regen"]
	if item.has("dash_cost"):     dash_stamina_cost += abs(item["dash_cost"])
	if item.has("absorb_cost"):   absorb_mp_cost += abs(item["absorb_cost"])
