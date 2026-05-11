extends Area2D

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
