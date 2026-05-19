# Bullet.gd
extends Area2D

var direction = Vector2.RIGHT
var speed = 200.0
var damage = 10.0
var is_reflected = false
var is_absorbed = false

func _physics_process(delta):
	position += direction * speed * delta

# 被反彈時呼叫此函式
func reflect(new_direction: Vector2, multiplier: float = 1.0):
	direction = new_direction
	damage *= multiplier
	is_reflected = true
