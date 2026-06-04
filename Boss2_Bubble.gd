extends Area2D

@export var speed: float = 170.0
@export var travel_time: float = 0.75
@export var linger_time: float = 4.0
@export var arm_after_stop_time: float = 0.15

@export var phase1_damage: int = 6
@export var phase2_damage: int = 9
@export var phase3_damage: int = 12

@export var phase1_slow_multiplier: float = 0.75
@export var phase2_slow_multiplier: float = 0.65
@export var phase3_slow_multiplier: float = 0.55

@export var phase1_slow_duration: float = 0.6
@export var phase2_slow_duration: float = 0.85
@export var phase3_slow_duration: float = 1.1

@export var use_bounds: bool = true
@export var bounds_left: float = -700.0
@export var bounds_right: float = 700.0
@export var bounds_top: float = -450.0
@export var bounds_bottom: float = 450.0
@export var bounds_margin: float = 40.0
@export var obstacle_pop_radius: float = 55.0

@export var debug_enabled: bool = false

var direction: Vector2 = Vector2.RIGHT
var phase: int = 1

var _travel_timer: float = 0.0
var _linger_timer: float = 0.0
var _is_flying: bool = true
var _is_armed: bool = false
var _is_dead: bool = false


func setup(
    start_pos: Vector2,
    fire_dir: Vector2,
    bubble_speed: float,
    bubble_travel_time: float,
    bubble_linger_time: float,
    bubble_arm_after_stop_time: float,
    boss_phase: int
) -> void:
    global_position = start_pos

    if fire_dir.length_squared() <= 0.0001:
        direction = Vector2.RIGHT
    else:
        direction = fire_dir.normalized()

    speed = bubble_speed
    travel_time = bubble_travel_time
    linger_time = bubble_linger_time
    arm_after_stop_time = bubble_arm_after_stop_time
    phase = boss_phase


func _ready() -> void:
    add_to_group("boss2_bubble")

    monitoring = true
    monitorable = true

    _travel_timer = travel_time
    _linger_timer = linger_time
    _is_flying = true
    _is_armed = false
    _is_dead = false

    if not body_entered.is_connected(_on_body_entered):
        body_entered.connect(_on_body_entered)

    call_deferred("_check_initial_obstacle_overlap")
    _update_visual()


func _physics_process(delta: float) -> void:
    if _is_dead:
        return

    if _is_overlapping_obstacle_by_distance():
        _pop()
        return

    if _is_flying:
        global_position += direction * speed * delta
        _travel_timer -= delta

        if use_bounds:
            _clamp_to_bounds()

        if _travel_timer <= 0.0:
            _stop_and_arm()

        return

    _linger_timer -= delta

    if _linger_timer <= 0.0:
        _pop()


func _stop_and_arm() -> void:
    if _is_dead:
        return

    if not _is_flying:
        return

    _is_flying = false
    _update_visual()

    await get_tree().create_timer(arm_after_stop_time).timeout

    if not is_instance_valid(self):
        return

    if _is_dead:
        return

    _is_armed = true
    _update_visual()


func _on_body_entered(body: Node) -> void:
    if _is_dead:
        return

    if body == null:
        return

    if body.is_in_group("boss2_obstacle"):
        _pop()
        return

    if not _is_armed:
        return

    if not body.is_in_group("player"):
        return

    var damage: int = _get_damage_by_phase()
    var slow_multiplier: float = _get_slow_multiplier_by_phase()
    var slow_duration: float = _get_slow_duration_by_phase()

    if body.has_method("take_damage"):
        body.take_damage(float(damage))

    if body.has_method("apply_slow"):
        body.apply_slow(slow_multiplier, slow_duration)

    if debug_enabled:
        print("Bubble hit player. phase = ", phase, " damage = ", damage)

    _pop()


func _get_damage_by_phase() -> int:
    if phase == 1:
        return phase1_damage

    if phase == 2:
        return phase2_damage

    return phase3_damage


func _get_slow_multiplier_by_phase() -> float:
    if phase == 1:
        return phase1_slow_multiplier

    if phase == 2:
        return phase2_slow_multiplier

    return phase3_slow_multiplier


func _get_slow_duration_by_phase() -> float:
    if phase == 1:
        return phase1_slow_duration

    if phase == 2:
        return phase2_slow_duration

    return phase3_slow_duration


func _clamp_to_bounds() -> void:
    var left: float = min(bounds_left, bounds_right) + bounds_margin
    var right: float = max(bounds_left, bounds_right) - bounds_margin
    var top: float = min(bounds_top, bounds_bottom) + bounds_margin
    var bottom: float = max(bounds_top, bounds_bottom) - bounds_margin

    var before_pos: Vector2 = global_position

    global_position.x = clamp(global_position.x, left, right)
    global_position.y = clamp(global_position.y, top, bottom)

    if before_pos != global_position:
        _stop_and_arm()


func _update_visual() -> void:
    var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D

    if sprite == null:
        return

    if _is_flying:
        sprite.modulate = Color(0.65, 0.95, 1.0, 0.65)
        return

    if _is_armed:
        sprite.modulate = Color(0.45, 1.0, 0.9, 0.95)
        return

    sprite.modulate = Color(0.65, 0.9, 1.0, 0.75)


func _check_initial_obstacle_overlap() -> void:
    if _is_dead:
        return

    for body in get_overlapping_bodies():
        if body != null and body.is_in_group("boss2_obstacle"):
            _pop()
            return


func _pop() -> void:
    if _is_dead:
        return

    _is_dead = true
    queue_free()


func _is_overlapping_obstacle_by_distance() -> bool:
    for obstacle in get_tree().get_nodes_in_group("boss2_obstacle"):
        if obstacle == null:
            continue

        if not is_instance_valid(obstacle):
            continue

        if not obstacle is Node2D:
            continue

        var obstacle_pos: Vector2 = (obstacle as Node2D).global_position
        var distance: float = global_position.distance_to(obstacle_pos)

        if distance <= obstacle_pop_radius:
            return true

    return false
