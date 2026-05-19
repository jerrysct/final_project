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
		queue_redraw()
	elif _absorb_anim_time != 0.0:
		_absorb_anim_time = 0.0
		queue_redraw()

func _get_radius() -> float:
	var radius: float = 100.0
	if is_instance_valid(bounce_collision) and bounce_collision.shape is CircleShape2D:
		if bounce_collision.shape.radius > 0.0:
			radius = bounce_collision.shape.radius
	return radius

func _draw_absorb_suction(radius: float) -> void:
	# 外框固定範圍 + 多層波紋向內收縮
	draw_circle(Vector2.ZERO, radius, Color(0.0, 0.55, 1.0, 0.12))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(0.0, 0.75, 1.0, 0.55), 2.5)

	for i in ABSORB_RING_COUNT:
		var phase: float = fmod(_absorb_anim_time + float(i) / float(ABSORB_RING_COUNT), 1.0)
		var ring_radius: float = radius * (1.0 - phase * 0.92)
		var ring_alpha: float = (1.0 - phase) * 0.85
		draw_arc(
			Vector2.ZERO,
			ring_radius,
			0.0,
			TAU,
			48,
			Color(0.2, 0.85, 1.0, ring_alpha),
			lerpf(4.0, 1.5, phase)
		)

	var core_pulse: float = (sin(_absorb_anim_time * TAU) * 0.5 + 0.5)
	var core_radius: float = radius * lerpf(0.08, 0.22, core_pulse)
	draw_circle(Vector2.ZERO, core_radius, Color(0.4, 0.95, 1.0, 0.35))

func _draw() -> void:
	var radius := _get_radius()

	if is_parry_preparing:
		draw_circle(Vector2.ZERO, radius, Color(1.0, 1.0, 1.0, 0.15))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(1.0, 1.0, 1.0, 0.8), 3.0)

	if is_absorb_preparing:
		_draw_absorb_suction(radius)

	if is_aiming:
		var pulse = (sin(Time.get_ticks_msec() * 0.01) * 0.08) + 1.0
		draw_circle(Vector2.ZERO, radius * pulse, Color(1.0, 0.3, 0.1, 0.15))
		draw_arc(Vector2.ZERO, radius * pulse, 0.0, TAU, 64, Color(1.0, 0.7, 0.0, 0.8), 3.0)
