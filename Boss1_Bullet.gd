extends Area2D

enum BulletColor {
	RED,
	BLUE,
	GREEN,
	YELLOW
}

enum BulletType {
	NORMAL,
	BURST
}

@export var speed: float = 260.0
@export var damage: int = 10
@export var slow_duration: float = 2.0
@export var slow_multiplier: float = 0.5

@export var life_time: float = 8.0
@export var rotate_speed: float = 8.0

@export var burst_travel_time: float = 0.9
@export var burst_ring_count: int = 16
@export var burst_ring_speed: float = 230.0
@export var phase_two_burst_ring_count: int = 24
@export var phase_two_burst_ring_speed: float = 270.0

var direction: Vector2 = Vector2.DOWN
var color_type: int = BulletColor.RED
var bullet_type: int = BulletType.NORMAL

var is_reflected: bool = false
var is_absorbed: bool = false
var is_phantom: bool = false
var can_slow_player: bool = false
var is_phase_two: bool = false

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("bullets")

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

	update_visual()


func _physics_process(delta: float) -> void:
	if is_absorbed:
		return

	if direction == Vector2.ZERO:
		direction = Vector2.DOWN

	global_position += direction.normalized() * speed * delta

	if sprite != null:
		sprite.rotation += rotate_speed * delta


func setup(
	new_color: int,
	new_direction: Vector2,
	phantom: bool = false,
	slow_bullet: bool = false,
	new_speed: float = -1.0,
	new_bullet_type: int = BulletType.NORMAL,
	phase_two: bool = false
) -> void:
	color_type = new_color
	direction = new_direction.normalized() if new_direction != Vector2.ZERO else Vector2.DOWN
	is_phantom = phantom
	can_slow_player = slow_bullet
	bullet_type = new_bullet_type
	is_phase_two = phase_two
	is_reflected = false
	is_absorbed = false

	if new_speed > 0.0:
		speed = new_speed

	update_visual()

	if bullet_type == BulletType.BURST:
		start_burst_timer()
	else:
		start_life_timer()


func start_life_timer() -> void:
	await get_tree().create_timer(life_time).timeout

	if is_instance_valid(self) and not is_absorbed:
		queue_free()


func start_burst_timer() -> void:
	await get_tree().create_timer(burst_travel_time).timeout

	if is_instance_valid(self) and not is_absorbed:
		explode_into_ring()


func explode_into_ring() -> void:
	if bullet_type != BulletType.BURST:
		return

	var ring_count = phase_two_burst_ring_count if is_phase_two else burst_ring_count
	var ring_speed = phase_two_burst_ring_speed if is_phase_two else burst_ring_speed

	for i in range(ring_count):
		var bullet = duplicate()
		get_tree().current_scene.add_child(bullet)

		bullet.global_position = global_position

		var angle = TAU * float(i) / float(ring_count)
		var ring_direction = Vector2.RIGHT.rotated(angle)

		var phantom = false
		var slow_bullet = false

		if is_phase_two:
			phantom = randf() < 0.25
			slow_bullet = randf() < 0.15

		bullet.setup(
			get_random_color(),
			ring_direction,
			phantom,
			slow_bullet,
			ring_speed,
			BulletType.NORMAL,
			is_phase_two
		)

	queue_free()


func reflect(new_direction: Vector2, multiplier: float = 1.0) -> void:
	if is_phantom:
		queue_free()
		return

	is_reflected = true
	is_absorbed = false
	direction = new_direction.normalized() if new_direction != Vector2.ZERO else -direction.normalized()
	speed *= 1.2
	damage = int(float(damage) * multiplier)

	visible = true
	set_physics_process(true)
	set_deferred("monitorable", true)
	set_deferred("monitoring", true)

	modulate = Color.WHITE
	update_visual()


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

	if bullet_type == BulletType.BURST:
		scale = Vector2(2.0, 2.0)
	else:
		scale = Vector2(1.0, 1.0)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("wall"):
		queue_free()
		return

	if bullet_type == BulletType.BURST:
		return

	if is_absorbed:
		return

	if is_reflected and body.has_method("receive_reflected_bullet"):
		body.receive_reflected_bullet(color_type, is_phantom)
		queue_free()
		return

	if is_reflected:
		return

	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)

		if can_slow_player and body.has_method("apply_slow"):
			body.apply_slow(slow_multiplier, slow_duration)

		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if bullet_type == BulletType.BURST:
		return

	if is_absorbed:
		return

	if area.has_method("refract_bullet"):
		area.refract_bullet(self)


func get_random_color() -> int:
	var colors = [
		BulletColor.RED,
		BulletColor.BLUE,
		BulletColor.GREEN,
		BulletColor.YELLOW
	]

	return colors.pick_random()
