extends CharacterBody2D

@export var max_hp: int = 50

var hp: int

# ✅ 加這個！（重點）
var boss: Node = null


func _ready():
	hp = max_hp


func take_damage(amount: int) -> void:
	hp -= amount

	if hp <= 0:
		die()


func die():
	# ✅ 通知Boss
	if boss != null and boss.has_method("on_tentacle_destroyed"):
		boss.on_tentacle_destroyed(global_position)

	queue_free()
