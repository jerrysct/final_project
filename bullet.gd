# Bullet.gd
extends Area2D

var direction = Vector2.RIGHT
var speed = 200.0
var damage = 10.0
var is_reflected = false
var is_absorbed = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	position += direction * speed * delta

func _on_body_entered(body: Node) -> void:
	# 1. 撞牆消失
	if body.is_in_group("wall") or body.get_collision_layer_value(1):
		queue_free()
		return
		
	# 2. 反彈狀態下撞到敵人
	if is_reflected:
		if body.is_in_group("player"): return
		if body.has_method("take_damage"):
			body.take_damage(damage)
			queue_free()
			return
		queue_free()
		return
	
	# 3. 未反彈撞到玩家
	if not is_reflected and body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()

# 被反彈時呼叫此函式
func reflect(new_direction: Vector2, multiplier: float = 1.0):
	direction = new_direction
	damage *= multiplier
	is_reflected = true
	# 改變顏色或特效來區分
	modulate = Color.GOLD
