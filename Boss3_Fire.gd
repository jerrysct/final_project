extends Area2D

@export var lifetime: float = 10.0 # 火焰存在 10 秒
@export var debug_enabled: bool = false

# 灼燒效果的參數設定 (會傳遞給玩家)
@export var burn_duration: float = 5.0
@export var burn_damage_per_tick: int = 2
@export var burn_tick_interval: float = 1.0

# 緩速效果的參數設定
@export var slow_multiplier: float = 0.5
@export var slow_duration: float = 5.0

func _ready() -> void:
	# 確保可以偵測碰撞
	monitoring = true
	monitorable = true

	# 連接信號
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered) # 保險起見，也偵測 body

	if debug_enabled:
		print("Boss3_Fire ready at: ", global_position, " (將存活 ", lifetime, " 秒)")

	# 10秒後自動銷毀s
	await get_tree().create_timer(lifetime).timeout
	queue_free()

# 當有 Area2D (例如玩家的 Hurtbox) 進入火焰時
func _on_area_entered(area: Area2D) -> void:
	#【關鍵修改】：嚴格檢查進來的判定框是不是叫做 "Hurtbox"
	if area.name != "Hurtbox":
		return # 如果是 BounceZone 或其他的框碰到，直接無視，不扣血！
		
	var target = area.get_parent()
	_try_apply_burn(target)

# 當有 PhysicsBody2D (例如玩家的 CharacterBody2D 本體) 進入火焰時
func _on_body_entered(body: Node2D) -> void:
	_try_apply_burn(body)

# 嘗試對目標施加灼燒與緩速狀態
func _try_apply_burn(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
		
	# 檢查目標是否為玩家 (透過群組判定最安全)
	if target.is_in_group("player"):
		# 1. 扣 10 滴血
		if target.has_method("take_damage"):
			target.take_damage(10.0)
			
		# 2. 施加灼燒
		if target.has_method("apply_burn"):
			target.apply_burn(burn_duration, burn_damage_per_tick, burn_tick_interval)
			
		# 3. 施加緩速
		if target.has_method("apply_slow_debuff"):
			target.apply_slow_debuff(slow_multiplier, slow_duration)
			
		if debug_enabled:
			print("Boss3_Fire 對玩家造成 10 傷害並施加了灼燒與緩速狀態！")
