extends Node2D

@export var lifetime: float = 0.75
@export var radius: float = 85.0

# 如果紅圈圖是 128x128，設 64
# 如果紅圈圖是 256x256，設 128
# 如果紅圈圖是 512x512，設 256
@export var texture_radius: float = 128.0

# 控制整個視覺半徑，不影響實際拍擊判定
@export var visual_radius_multiplier: float = 0.9

# 控制 Sprite 圖片額外縮放，也不影響實際拍擊判定
@export var visual_scale_multiplier: float = 1.15

@export var fill_color: Color = Color(1.0, 0.0, 0.0, 0.18)
@export var outer_flash_color: Color = Color(1.0, 0.1, 0.1, 0.28)

@export var debug_enabled: bool = false

@onready var sprite: Sprite2D = $Sprite2D

var _started: bool = false


func _ready() -> void:
	top_level = true
	z_index = 500
	z_as_relative = false

	if sprite != null:
		sprite.visible = true
		sprite.centered = true
		sprite.position = Vector2.ZERO
		sprite.z_index = 501
		sprite.z_as_relative = false
		sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)

	call_deferred("_start_warning")


func setup(pos: Vector2, new_radius: float, new_lifetime: float) -> void:
	global_position = pos
	radius = new_radius
	lifetime = new_lifetime

	top_level = true
	z_index = 500
	z_as_relative = false

	_update_visual_size()
	queue_redraw()

	if debug_enabled:
		print("Slam warning setup at ", global_position, " radius = ", radius)


func _draw() -> void:
	var visual_radius: float = radius * visual_radius_multiplier

	draw_circle(Vector2.ZERO, visual_radius, fill_color)
	draw_circle(Vector2.ZERO, visual_radius * 1.12, outer_flash_color)


func _start_warning() -> void:
	if _started:
		return

	_started = true

	_update_visual_size()
	queue_redraw()

	if debug_enabled:
		print("Slam warning ready at ", global_position)

	scale = Vector2(0.78, 0.78)

	var scale_tween := create_tween()
	scale_tween.tween_property(self, "scale", Vector2.ONE, lifetime).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if sprite != null:
		var flash_tween := create_tween()
		flash_tween.set_loops()
		flash_tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 0.45), 0.12)
		flash_tween.tween_property(sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.12)

	if not is_inside_tree():
		return

	var tree := get_tree()

	if tree == null:
		return

	await tree.create_timer(lifetime).timeout

	if is_instance_valid(self):
		queue_free()


func _update_visual_size() -> void:
	if sprite == null:
		return

	if sprite.texture == null:
		if debug_enabled:
			print("Slam warning Sprite2D has no texture")
		return

	if texture_radius <= 0.0:
		texture_radius = 128.0

	var visual_radius: float = radius * visual_radius_multiplier
	var scale_value: float = visual_radius / texture_radius

	sprite.scale = Vector2(scale_value, scale_value) * visual_scale_multiplier
	sprite.position = Vector2.ZERO
	sprite.centered = true
