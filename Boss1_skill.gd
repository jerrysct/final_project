extends Area2D

@export var default_lifetime: float = 5.0

var has_lifetime: bool = false
var lifetime: float = 5.0


func _ready() -> void:
	if has_lifetime:
		await get_tree().create_timer(lifetime).timeout
		queue_free()


func refract_bullet(bullet: Node) -> void:
	if not bullet.has_method("change_color"):
		return

	match bullet.color_type:
		0:
			bullet.change_color(1) # Red -> Blue
		1:
			bullet.change_color(2) # Blue -> Green
		2:
			bullet.change_color(3) # Green -> Yellow
		3:
			bullet.change_color(0) # Yellow -> Red


func set_lifetime(new_lifetime: float) -> void:
	lifetime = new_lifetime
	has_lifetime = true

	await get_tree().create_timer(lifetime).timeout
	queue_free()
