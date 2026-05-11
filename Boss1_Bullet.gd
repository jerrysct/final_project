extends Area2D

enum BulletColor {
	RED,
	BLUE,
	GREEN,
	YELLOW
}

@export var speed: float = 260.0
@export var damage: int = 10
@export var slow_duration: float = 2.0
@export var slow_multiplier: float = 0.5

var direction: Vector2 = Vector2.DOWN
var color_type: int = BulletColor.RED
var is_reflected: bool = false
var is_phantom: bool = false
var can_slow_player: bool = false

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("bullets")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	update_visual()


func _physics_process(delta: float) -> void:
	global_position += direction.normalized() * speed * delta


func setup(
	new_color: int,
	new_direction: Vector2,
	phantom: bool = false,
	slow_bullet: bool = false
) -> void:
	color_type = new_color
	direction = new_direction.normalized()
	is_phantom = phantom
	can_slow_player = slow_bullet
	
	update_visual()


func reflect(new_direction: Vector2, multiplier: float = 1.0) -> void:
	if is_phantom:
		queue_free()
		return
	
	is_reflected = true
	direction = new_direction.normalized()
	speed *= 1.2
	damage *= multiplier
	
	modulate = Color.WHITE


func change_color(new_color: int) -> void:
	color_type = new_color
	update_visual()


func update_visual() -> void:
	if sprite == null:
		return
	
	match color_type:
		BulletColor.RED:
			sprite.modulate = Color.RED
		
		BulletColor.BLUE:
			sprite.modulate = Color.BLUE
		
		BulletColor.GREEN:
			sprite.modulate = Color.GREEN
		
		BulletColor.YELLOW:
			sprite.modulate = Color.YELLOW
	
	if is_phantom:
		sprite.modulate.a = 0.35
	else:
		sprite.modulate.a = 1.0


func _on_body_entered(body: Node) -> void:
	# 反彈後打到 Boss：交給 Boss 判斷顏色
	if is_reflected and body.has_method("receive_reflected_bullet"):
		body.receive_reflected_bullet(color_type, is_phantom)
		queue_free()
		return
	
	# 反彈後撞到其他東西，不扣血
	if is_reflected:
		return
	
	# 未反彈時，只能傷害玩家
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		
		if can_slow_player and body.has_method("apply_slow"):
			body.apply_slow(slow_multiplier, slow_duration)
		
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	# 稜鏡場
	if area.has_method("refract_bullet"):
		area.refract_bullet(self)
