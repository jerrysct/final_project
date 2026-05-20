extends Node2D

var is_parry_preparing := false
var is_absorb_preparing := false
var is_aiming := false
var bounce_collision: CollisionShape2D

var _absorb_anim_time: float = 0.0
const ABSORB_RING_COUNT := 4
const ABSORB_ANIM_SPEED := 1.8

func _process(delta: float) -> void:
	if is_absorb_preparing:
		_absorb_anim_time += delta * ABSORB_ANIM_SPEED
	elif _absorb_anim_time != 0.0:
		_absorb_anim_time = 0.0

	if is_parry_preparing or is_absorb_preparing or is_aiming:
		queue_redraw()

func _get_radius() -> float:
	var radius: float = 100.0
	if is_instance_valid(bounce_collision) and bounce_collision.shape is CircleShape2D:
		if bounce_collision.shape.radius > 0:
			radius = bounce_collision.shape.radius

	if is_parry_preparing:
		draw_circle(Vector2.ZERO, radius, Color(1.0, 1.0, 1.0, 0.15))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(1.0, 1.0, 1.0, 0.8), 3.0)

	if is_absorb_preparing:
		draw_circle(Vector2.ZERO, radius, Color(0.0, 0.6, 1.0, 0.2))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(0.0, 0.8, 1.0, 0.7), 3.0)

	if is_aiming:
		var pulse = (sin(Time.get_ticks_msec() * 0.01) * 0.08) + 1.0
		draw_circle(Vector2.ZERO, radius * pulse, Color(1.0, 0.3, 0.1, 0.15))
		draw_arc(Vector2.ZERO, radius * pulse, 0.0, TAU, 64, Color(1.0, 0.7, 0.0, 0.8), 3.0)
