extends Area2D

@export var speed: float = 220.0
@export var damage: float = 10.0
@export var damage_to_tentacle: int = 25
@export var lifetime: float = 5.0
@export var debug_enabled: bool = false

@export var reflect_arm_time: float = 0.18
@export var reflect_arm_distance: float = 70.0

var can_be_reflected: bool = false
var _spawn_position: Vector2 = Vector2.ZERO
var _age: float = 0.0

var direction: Vector2 = Vector2.RIGHT
var is_reflected: bool = false
var is_absorbed: bool = false


func _ready() -> void:
    body_entered.connect(_on_body_entered)

    await get_tree().create_timer(lifetime).timeout

    if is_instance_valid(self):
        queue_free()


func setup(spawn_pos: Vector2, fire_direction: Vector2) -> void:
    global_position = spawn_pos
    _spawn_position = spawn_pos
    _age = 0.0
    can_be_reflected = false

    if fire_direction.length_squared() > 0.0001:
        direction = fire_direction.normalized()


func _physics_process(delta: float) -> void:
    if is_absorbed:
        return

    _age += delta

    global_position += direction * speed * delta

    if not can_be_reflected:
        var traveled_distance: float = global_position.distance_to(_spawn_position)

        if _age >= reflect_arm_time or traveled_distance >= reflect_arm_distance:
            can_be_reflected = true


func reflect(new_direction: Vector2 = Vector2.ZERO, power_multiplier: float = 1.0) -> void:
    if not can_be_reflected:
        if debug_enabled:
            print("Toxic bullet not armed yet, cannot reflect")
        return

    is_reflected = true
    is_absorbed = false

    if new_direction.length_squared() > 0.0001:
        direction = new_direction.normalized()
    else:
        direction = -direction

    speed *= power_multiplier

    if debug_enabled:
        print("Boss2_ToxicBullet reflected")
        

func _on_body_entered(body: Node) -> void:
    if is_absorbed:
        return

    if not is_reflected:
        return

    if body.has_method("take_damage"):
        body.take_damage(damage_to_tentacle)

        if debug_enabled:
            print("Reflected toxic bullet hit: ", body.name)

        queue_free()
