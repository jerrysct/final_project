extends Node2D

@onready var boss_ui: Control = get_node_or_null("CanvasLayer/BossUI") as Control

@onready var melee_hp_bar: ProgressBar = get_node_or_null("CanvasLayer/BossUI/MeleeRow/MeleeHP") as ProgressBar
@onready var ranged_hp_bar: ProgressBar = get_node_or_null("CanvasLayer/BossUI/RangedRow/RangedHP") as ProgressBar

@onready var melee_hp_label: Label = get_node_or_null("CanvasLayer/BossUI/MeleeRow/MeleeLabel") as Label
@onready var ranged_hp_label: Label = get_node_or_null("CanvasLayer/BossUI/RangedRow/RangedLabel") as Label

@onready var player_spawn: Marker2D = $PlayerSpawnPoint
@onready var melee_spawn: Marker2D = $MeleeSpawnPoint
@onready var ranged_spawn: Marker2D = $RangedSpawnPoint

@onready var melee_boss: Node = $Boss3Melee
@onready var ranged_boss: Node = $Boss3Ranged

# --- 結算畫面 UI 參考 ---
@onready var end_screen: Panel = get_node_or_null("CanvasLayer/EndScreen") as Panel
@onready var title_label: Label = get_node_or_null("CanvasLayer/EndScreen/VBoxContainer/TitleLabel") as Label
@onready var gold_label: Label = get_node_or_null("CanvasLayer/EndScreen/VBoxContainer/GoldLabel") as Label
@onready var return_button: Button = get_node_or_null("CanvasLayer/EndScreen/VBoxContainer/ReturnButton") as Button
@onready var bgm_player: AudioStreamPlayer = $BGMPlayer

var player: Node2D = null
var camera: Camera2D = null

var _melee_dead: bool = false
var _ranged_dead: bool = false
var _room_cleared: bool = false

const MAIN_SCENE_PATH: String = "res://main.tscn"


func _ready() -> void:
	_remove_wrong_player_groups()
	_debug_print_players("before spawn")
	_spawn_selected_player()
	_debug_print_players("after spawn")
	_position_boss()
	_refresh_boss_player_targets()
	_setup_camera()
	_setup_boss_hp_ui()
	
	if end_screen:
		end_screen.hide()
		end_screen.process_mode = Node.PROCESS_MODE_ALWAYS
		
	if return_button:
		if not return_button.pressed.is_connected(_on_return_button_pressed):
			return_button.pressed.connect(_on_return_button_pressed)


func _process(_delta: float) -> void:
	_check_boss_clear()
	_update_boss_hp_ui()


func _spawn_selected_player() -> void:
	_remove_existing_players_in_room()

	if Playerdata_Globle.selected_character.is_empty():
		push_warning("尚未選擇角色，使用預設 Character1")
		Playerdata_Globle.selected_character = "Character1"

	var scene_path: String = Playerdata_Globle.get_selected_character_scene_path()
	print("玩家場景路徑：", scene_path)

	var player_scene: PackedScene = load(scene_path) as PackedScene

	if player_scene == null:
		push_error("找不到角色場景：%s" % scene_path)
		return

	var new_player: Node = player_scene.instantiate()
	new_player.name = "Player"
	add_child(new_player)

	if new_player is Node2D:
		player = new_player as Node2D

		if player_spawn != null:
			player.global_position = player_spawn.global_position

		if not player.is_in_group("player"):
			player.add_to_group("player")
	else:
		push_error("生成的玩家不是 Node2D，無法設定位置與 Camera2D")
		return

	print("BossRoom3 已生成 Player")


func _remove_existing_players_in_room() -> void:
	var existing_named_player: Node = get_node_or_null("Player")

	if existing_named_player != null:
		existing_named_player.queue_free()

	for existing_player in get_tree().get_nodes_in_group("player"):
		if existing_player != null and existing_player.get_parent() == self:
			existing_player.queue_free()


func _remove_wrong_player_groups() -> void:
	var wrong_player := get_node_or_null("Boss3Melee/Node2D")

	if wrong_player != null and wrong_player.is_in_group("player"):
		wrong_player.remove_from_group("player")
		print("已從 Boss3Melee/Node2D 移除 player group")


func _position_boss() -> void:
	if is_instance_valid(melee_boss) and melee_boss is Node2D and melee_spawn != null:
		(melee_boss as Node2D).global_position = melee_spawn.global_position

	if is_instance_valid(ranged_boss) and ranged_boss is Node2D and ranged_spawn != null:
		(ranged_boss as Node2D).global_position = ranged_spawn.global_position

		if ranged_boss.has_method("set_home_position"):
			ranged_boss.set_home_position(ranged_spawn.global_position)


func _setup_camera() -> void:
	if player == null:
		player = get_node_or_null("Player") as Node2D

	if player == null:
		push_warning("找不到 Player，無法設定 Camera2D")
		return

	camera = player.get_node_or_null("Camera2D") as Camera2D

	if camera == null:
		push_warning("Player 底下找不到 Camera2D，請確認 Camera2D 是 Player 的直接子節點")
		return

	camera.enabled = true
	camera.make_current()


func _check_boss_clear() -> void:
	if _room_cleared:
		return

	if not _melee_dead and not is_instance_valid(melee_boss):
		_melee_dead = true
		print("Melee 死了")

		if is_instance_valid(ranged_boss) and ranged_boss.has_method("enter_enraged_mode"):
			ranged_boss.enter_enraged_mode()

	if not _ranged_dead and not is_instance_valid(ranged_boss):
		_ranged_dead = true
		print("Ranged 死了")

		if is_instance_valid(melee_boss) and melee_boss.has_method("enter_enraged_mode"):
			melee_boss.enter_enraged_mode()

	if _melee_dead and _ranged_dead:
		_room_cleared = true
		_on_boss_room_clear()


func _on_boss_room_clear() -> void:
	print("BossRoom3 通關 ✅")
	show_victory()


# 當 Boss 死亡時呼叫此函數
func show_victory() -> void:
	# 根據全域變數的倍率計算實際獲得的金幣
	var earned_gold: int = int(200 * Playerdata_Globle.reward_multiplier) # Boss3 獎勵較多
	
	if title_label: title_label.text = "Victory"
	if gold_label:
		gold_label.text = "+%d Gold" % earned_gold
		gold_label.show()
	if end_screen: end_screen.show()
	if bgm_player: bgm_player.stop()
	
	# 將金幣加進全域變數中
	Playerdata_Globle.gold += earned_gold
	SaveManager.save_slot(Playerdata_Globle.current_slot)
	print("戰鬥勝利！獲得金幣：", earned_gold, "，目前總金幣：", Playerdata_Globle.gold)
	
	# 暫停遊戲
	get_tree().paused = true

# 當 Player 死亡時呼叫此函數
func show_defeat() -> void:
	if title_label: title_label.text = "You Loss"
	if gold_label: gold_label.hide() # 輸了不顯示金幣
	if end_screen: end_screen.show()
	if bgm_player: bgm_player.stop()
	
	# 暫停遊戲
	get_tree().paused = true


## 按鈕回呼函數
func _on_return_button_pressed() -> void:
	# 1. 先解除暫停
	get_tree().paused = false 
	
	# 2. 直接切換場景
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)


func _debug_print_players(label: String) -> void:
	print("==== Player Debug: ", label, " ====")

	var players := get_tree().get_nodes_in_group("player")
	print("player group count = ", players.size())

	for p in players:
		if p == null:
			continue

		var parent_name := "no parent"

		if p.get_parent() != null:
			parent_name = p.get_parent().name

		print("player node = ", p.name, " path = ", p.get_path(), " parent = ", parent_name)


func _refresh_boss_player_targets() -> void:
	print("melee valid = ", is_instance_valid(melee_boss), " has find_player = ", melee_boss != null and melee_boss.has_method("find_player"))
	print("ranged valid = ", is_instance_valid(ranged_boss), " has find_player = ", ranged_boss != null and ranged_boss.has_method("find_player"))

	if is_instance_valid(melee_boss) and melee_boss.has_method("find_player"):
		melee_boss.find_player()

	if is_instance_valid(ranged_boss) and ranged_boss.has_method("find_player"):
		ranged_boss.find_player()

	print("BossRoom3：已要求兩隻 Boss 重新尋找 Player")


func _setup_boss_hp_ui() -> void:
	if boss_ui != null:
		boss_ui.visible = true
		boss_ui.z_index = 100

	if melee_hp_bar != null:
		melee_hp_bar.show_percentage = false
		if is_instance_valid(melee_boss):
			melee_hp_bar.max_value = melee_boss.max_hp
			melee_hp_bar.value = melee_boss.hp

	if ranged_hp_bar != null:
		ranged_hp_bar.show_percentage = false
		if is_instance_valid(ranged_boss):
			ranged_hp_bar.max_value = ranged_boss.max_hp
			ranged_hp_bar.value = ranged_boss.hp

	_update_boss_hp_ui()


func _update_boss_hp_ui() -> void:
	if melee_hp_bar != null and melee_hp_label != null:
		if is_instance_valid(melee_boss):
			melee_hp_bar.value = melee_boss.hp
			melee_hp_label.text = str(melee_boss.hp) + " / " + str(melee_boss.max_hp)
		else:
			melee_hp_bar.value = 0
			melee_hp_label.text = "0 / 0"

	if ranged_hp_bar != null and ranged_hp_label != null:
		if is_instance_valid(ranged_boss):
			ranged_hp_bar.value = ranged_boss.hp
			ranged_hp_label.text = str(ranged_boss.hp) + " / " + str(ranged_boss.max_hp)
		else:
			ranged_hp_bar.value = 0
			ranged_hp_label.text = "0 / 0"
