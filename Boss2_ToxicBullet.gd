extends Area2D

@export var speed: float = 200.0
@export var damage: float = 5.0
@export var damage_to_tentacle: int = 25
@export var damage_to_fish: int = 25
@export var damage_to_boss_phase2: int = 18
@export var damage_to_boss_phase3: int = 8
@export var lifetime: float = 5.0
@export var debug_enabled: bool = false

@export var reflect_arm_time: float = 0.18
@export var reflect_arm_distance: float = 70.0

var can_be_reflected: bool = false
var direction: Vector2 = Vector2.RIGHT
var is_reflected: bool = false
var is_absorbed: bool = false

# 反轉區內反彈時會變成 1.2
var reflected_damage_multiplier: float = 1.0

var _spawn_position: Vector2 = Vector2.ZERO
var _age: float = 0.0


func _ready() -> void:
    set_deferred("monitoring", true)
    set_deferred("monitorable", true)

    if not body_entered.is_connected(_on_body_entered):
        body_entered.connect(_on_body_entered)

    var completed: bool = await _safe_wait(lifetime)

    if not completed:
        return

    if is_instance_valid(self):
        queue_free()


func setup(spawn_pos: Vector2, fire_direction: Vector2) -> void:
    global_position = spawn_pos
    _spawn_position = spawn_pos
    _age = 0.0

    can_be_reflected = false
    is_reflected = false
    is_absorbed = false
    reflected_damage_multiplier = 1.0

    if fire_direction.length_squared() > 0.0001:
        direction = fire_direction.normalized()
    else:
        direction = Vector2.RIGHT


func _physics_process(delta: float) -> void:
    if is_absorbed:
        return

    _age += delta
    global_position += direction * speed * delta

    if not can_be_reflected:
        var traveled_distance: float = global_position.distance_to(_spawn_position)

        if _age >= reflect_arm_time or traveled_distance >= reflect_arm_distance:
            can_be_reflected = true


func set_reflected_damage_multiplier(multiplier: float) -> void:
    reflected_damage_multiplier = multiplier


func _apply_reverse_zone_damage_bonus_if_needed() -> void:
    reflected_damage_multiplier = 1.0

    for zone in get_tree().get_nodes_in_group("reverse_input_zone"):
        if zone == null:
            continue

        if not is_instance_valid(zone):
            continue

        if not zone.has_method("contains_point_for_damage_bonus"):
            continue

        if zone.contains_point_for_damage_bonus(global_position):
            if zone.has_method("get_damage_bonus_multiplier"):
                reflected_damage_multiplier = float(zone.get_damage_bonus_multiplier())
            else:
                reflected_damage_multiplier = 1.2

            if debug_enabled:
                print("Toxic bullet got reverse zone damage bonus x", reflected_damage_multiplier)

            return


func reflect(new_direction: Vector2 = Vector2.ZERO, power_multiplier: float = 1.0) -> void:
    if not can_be_reflected:
        if debug_enabled:
            print("Toxic bullet not armed yet, cannot reflect")
        return

    is_reflected = true
    is_absorbed = false

    _apply_reverse_zone_damage_bonus_if_needed()

    if new_direction.length_squared() > 0.0001:
        direction = new_direction.normalized()
    else:
        direction = -direction

    speed *= power_multiplier

    if debug_enabled:
        print("Boss2_ToxicBullet reflected")

func _is_boss_target(body: Node) -> bool:
    if body == null:
        return false

    if body.has_method("get_current_phase") and body.has_method("get_hp_ratio"):
        return true

    return false


func _get_reflected_damage_for_body(body: Node) -> int:
    var damage_amount: int = damage_to_tentacle

    if _is_boss_target(body):
        var phase: int = 1

        if body.has_method("get_current_phase"):
            phase = int(body.get_current_phase())

        if phase >= 3:
            damage_amount = damage_to_boss_phase3
        else:
            damage_amount = damage_to_boss_phase2

    elif body.is_in_group("boss2_fish"):
        damage_amount = damage_to_fish

    damage_amount = int(round(float(damage_amount) * reflected_damage_multiplier))

    return max(1, damage_amount)

func _on_body_entered(body: Node) -> void:
    if body == null:
        return

    # ✅ 撞障礙
    if body.is_in_group("boss2_obstacle"):
        if body.has_method("take_bullet_hit"):
            body.take_bullet_hit()

        call_deferred("queue_free")   # ✅ 修正
        return

    if is_absorbed:
        return

    if not is_reflected:
        return

    if body.is_in_group("player"):
        return

    if not body.has_method("take_damage"):
        return

    var damage_amount: int = _get_reflected_damage_for_body(body)

    body.take_damage(damage_amount)

    if debug_enabled:
        print("Reflected toxic bullet hit: ", body.name, " damage = ", damage_amount)

    call_deferred("queue_free")   # ✅ 修正


func _safe_wait(seconds: float) -> bool:
    if not is_inside_tree():
        return false

    var tree := get_tree()

    if tree == null:
        return false

    await tree.create_timer(seconds).timeout

    if not is_instance_valid(self):
        return false

    if not is_inside_tree():
        return false

    return true
