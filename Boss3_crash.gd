extends Area2D

@export var damage: float = 20.0
@export var crack_lifetime: float = 5.0 # 裂痕圖片殘留時間 (5秒)

var _hit_targets: Array = []

func _ready() -> void:
	# 剛生成時，開啟傷害判定
	monitoring = true
	monitorable = false

	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

	# 【關鍵】：0.2 秒後，關閉碰撞判定，這樣玩家之後踩過去就不會扣血了
	get_tree().create_timer(0.2).timeout.connect(_disable_collision)

	# 5 秒後自動銷毀整個裂痕場景
	await get_tree().create_timer(crack_lifetime).timeout
	queue_free()

func _disable_collision() -> void:
	# 安全地關閉物理監聽
	set_deferred("monitoring", false)

func _on_area_entered(area: Area2D) -> void:
	# 檢查進來的是否為玩家的 Hurtbox
	if area.name == "Hurtbox":
		_try_deal_damage(area.get_parent())

func _on_body_entered(body: Node2D) -> void:
	_try_deal_damage(body)

func _try_deal_damage(target: Node) -> void:
	if target == null or not is_instance_valid(target): return
	if target in _hit_targets: return # 防止重複扣血

	if target.is_in_group("player"):
		# 1. 扣 20 滴血
		if target.has_method("take_damage"):
			target.take_damage(damage)
			
		# 2. 扣掉最大體力的 50%，最低扣至 0
		if "current_stamina" in target:
			var stamina_loss = Playerdata_Globle.max_stamina * 0.5
			target.current_stamina = maxf(0.0, target.current_stamina - stamina_loss)
			
		_hit_targets.append(target)
		print("Boss3_Crash 瞬間衝擊擊中玩家！造成傷害與體力扣除。")
