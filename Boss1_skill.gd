extends Area2D

enum BulletColor {
	RED,
	BLUE,
	GREEN,
	YELLOW
}

@export var default_lifetime: float = 5.0
@export var warning_time: float = 1.0
@export var blink_interval: float = 0.12
@export var normal_alpha: float = 0.8
@export var warning_alpha_low: float = 0.25

var color_type: int = BulletColor.RED
var has_lifetime: bool = false
var lifetime: float = 5.0
var lifetime_started: bool = false
var is_warning: bool = false

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D


func _ready() -> void:
	update_visual()

	if has_lifetime:
		_start_lifetime_timer()


func set_color_type(new_color: int) -> void:
	color_type = new_color
	update_visual()


func refract_bullet(bullet: Node) -> void:
	if bullet == null:
		return

	if not bullet.has_method("change_color"):
		return

	bullet.change_color(color_type)


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

	sprite.modulate.a = normal_alpha


func set_lifetime(new_lifetime: float) -> void:
	lifetime = new_lifetime
	has_lifetime = true

	if not is_inside_tree():
		await tree_entered

	_start_lifetime_timer()


func _start_lifetime_timer() -> void:
	if lifetime_started:
		return

	lifetime_started = true

	var timer_time := lifetime
	if timer_time <= 0.0:
		timer_time = default_lifetime

	var safe_warning_time = min(warning_time, timer_time)

	var stable_time = timer_time - safe_warning_time

	if stable_time > 0.0:
		await get_tree().create_timer(stable_time).timeout

	if not is_instance_valid(self):
		return

	start_warning_blink()

	await get_tree().create_timer(safe_warning_time).timeout

	if is_instance_valid(self):
		queue_free()


func start_warning_blink() -> void:
	if is_warning:
		return

	is_warning = true
	_blink_loop()


func _blink_loop() -> void:
	while is_warning and is_instance_valid(self):
		if sprite != null:
			sprite.modulate.a = warning_alpha_low

		await get_tree().create_timer(blink_interval).timeout

		if sprite != null:
			sprite.modulate.a = normal_alpha

		await get_tree().create_timer(blink_interval).timeout
