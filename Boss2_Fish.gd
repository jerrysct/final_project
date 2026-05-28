extends CharacterBody2D

@export var move_speed: float = 115.0
@export var max_hp: int = 50
@export var lifetime: float = 9.0

@export var trigger_distance: float = 70.0
@export var slow_multiplier: float = 0.65
@export var slow_duration: float = 0.9
@export var fish_slow_immunity_time: float = 1.2

@export var debug_enabled: bool = true

var hp: int
var player: Node2D = null

var _is_dead: bool = false
var _has_triggered: bool = false


func _ready() -> void:
    add_to_group("normal_fish")

    hp = max_hp
    find_player()
    call_deferred("_apply_player_collision_exception")

    var completed: bool = await _safe_wait(lifetime)

    if not completed:
        return

    if is_instance_valid(self) and not _is_dead:
        queue_free()


func _physics_process(_delta: float) -> void:
    if _is_dead:
        return

    if player == null or not is_instance_valid(player):
        find_player()
        return

    var distance: float = global_position.distance_to(player.global_position)

    if distance <= trigger_distance:
        _trigger_slow()
        return

    _chase_player()


func _chase_player() -> void:
    var dir: Vector2 = player.global_position - global_position

    if dir.length_squared() > 0.0001:
        velocity = dir.normalized() * move_speed
    else:
        velocity = Vector2.ZERO

    move_and_slide()


func _trigger_slow() -> void:
    if _has_triggered:
        return

    _has_triggered = true

    if player != null and is_instance_valid(player):
        if player.has_method("apply_slow"):
            var now: float = float(Time.get_ticks_msec()) / 1000.0
            var next_allowed_time: float = 0.0

            if player.has_meta("fish_slow_next_allowed_time"):
                next_allowed_time = float(player.get_meta("fish_slow_next_allowed_time"))

            if now >= next_allowed_time:
                player.apply_slow(slow_multiplier, slow_duration)
                player.set_meta("fish_slow_next_allowed_time", now + fish_slow_immunity_time)

                if debug_enabled:
                    print("Fish slowed player")
            else:
                if debug_enabled:
                    print("Fish slow skipped by immunity")

    die()


func find_player() -> void:
    var players: Array[Node] = get_tree().get_nodes_in_group("player")

    if players.size() > 0:
        player = players[0] as Node2D


func _apply_player_collision_exception() -> void:
    if player == null or not is_instance_valid(player):
        find_player()

    if player != null and player is PhysicsBody2D:
        add_collision_exception_with(player as PhysicsBody2D)


func take_damage(amount: int) -> void:
    if _is_dead:
        return

    hp -= amount

    if debug_enabled:
        print("Fish HP = ", hp)

    if hp <= 0:
        die()


func die() -> void:
    if _is_dead:
        return

    _is_dead = true
    queue_free()


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
