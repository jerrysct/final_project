extends Node2D

@export var laser_range: float = 420.0
@export var laser_angle_degrees: float = 90.0
@export var lifetime: float = 0.8

@export var fill_color: Color = Color(1.0, 0.0, 0.0, 0.22)
@export var outline_color: Color = Color(1.0, 0.0, 0.0, 0.85)

var direction: Vector2 = Vector2.RIGHT


func setup(origin_pos: Vector2, laser_dir: Vector2, new_range: float, new_angle: float, new_lifetime: float) -> void:
	global_position = origin_pos

	if laser_dir.length_squared() > 0.0001:
		direction = laser_dir.normalized()

	laser_range = new_range
	laser_angle_degrees = new_angle
	lifetime = new_lifetime

	queue_redraw()


func _ready() -> void:
	z_index = 180
	queue_redraw()

	await get_tree().create_timer(lifetime).timeout

	if is_instance_valid(self):
		queue_free()


func _draw() -> void:
	var points: PackedVector2Array = PackedVector2Array()

	points.append(Vector2.ZERO)

	var half_angle: float = deg_to_rad(laser_angle_degrees) * 0.5
	var base_angle: float = direction.angle()
	var segment_count: int = 24

	for i in range(segment_count + 1):
		var t: float = float(i) / float(segment_count)
		var angle: float = base_angle - half_angle + (half_angle * 2.0 * t)
		var p: Vector2 = Vector2.RIGHT.rotated(angle) * laser_range
		points.append(p)

	draw_colored_polygon(points, fill_color)

	for i in range(1, points.size() - 1):
		draw_line(points[i], points[i + 1], outline_color, 3.0)

	if points.size() >= 3:
		draw_line(Vector2.ZERO, points[1], outline_color, 3.0)
		draw_line(Vector2.ZERO, points[points.size() - 1], outline_color, 3.0)
