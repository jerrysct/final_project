extends CharacterBody2D

@export var max_hp: int = 200
@export var slam_lead_time: float = 0.5
@export var debug_enabled: bool = true
@export var slam_random_offset: float = 22.0

@export var phase2_attack_speed_multiplier: float = 0.85
@export var phase3_attack_speed_multiplier: float = 0.7
@export var phase3_extra_shot_chance: float = 0.35

@export var damage_cooldown: float = 0.1

var hp: int
var boss_ref: Node = null
var player: Node2D = null

var _shoot_timer: float = 0.0
var _is_attacking: bool = false
var _is_dead: bool = false
var _can_take_damage: bool = true


func _ready() -> void:
    hp = max_hp
    find_player()
    _roll_shoot_timer()

    if debug_enabled:
        print("Tentacle ready HP = ", hp)


func setup_boss(boss_node: Node) -> void:
    boss_ref = boss_node

    if debug_enabled:
        print("Tentacle received boss_ref = ", boss_ref)


func _physics_process(delta: float) -> void:
    if _is_dead:
        return

    if player == null or not is_instance_valid(player):
        find_player()
        return

    if _is_attacking:
        return

    _shoot_timer -= delta

    if _shoot_timer <= 0.0:
        _is_attacking = true

        var phase: int = _get_boss_phase()
        var can_slam_now: bool = _can_use_global_slam()

        if can_slam_now and randf() <= slam_chance:
            _register_global_slam_cooldown()
            await _attack_slam()
        else:
            await _attack_bullet_pattern()

            if phase == 3 and randf() <= phase3_extra_shot_chance:
                var wait_completed: bool = await _safe_wait(0.18)

                if wait_completed and not _is_dead:
                    await _attack_bullet_pattern()

        if _is_dead:
            return

        if not is_inside_tree():
            return

        _roll_shoot_timer()
        _is_attacking = false


func find_player() -> void:
    var players: Array[Node] = get_tree().get_nodes_in_group("player")

    if players.size() > 0:
        player = players[0] as Node2D


func _roll_shoot_timer() -> void:
    var phase: int = _get_boss_phase()

    var min_time: float = shoot_interval_min
    var max_time: float = shoot_interval_max

    if phase == 2:
        min_time *= phase2_attack_speed_multiplier
        max_time *= phase2_attack_speed_multiplier
    elif phase == 3:
        min_time *= phase3_attack_speed_multiplier
        max_time *= phase3_attack_speed_multiplier

    _shoot_timer = randf_range(min_time, max_time)


func _can_use_global_slam() -> bool:
    if boss_ref == null or not is_instance_valid(boss_ref):
        return true

    var now: float = float(Time.get_ticks_msec()) / 1000.0
    var next_allowed_time: float = 0.0

    if boss_ref.has_meta("global_slam_next_allowed_time"):
        next_allowed_time = float(boss_ref.get_meta("global_slam_next_allowed_time"))

    return now >= next_allowed_time


func _register_global_slam_cooldown() -> void:
    if boss_ref == null or not is_instance_valid(boss_ref):
        return

    var now: float = float(Time.get_ticks_msec()) / 1000.0
    boss_ref.set_meta("global_slam_next_allowed_time", now + global_slam_cooldown)

    if debug_enabled:
        print("Global slam cooldown started: ", global_slam_cooldown, " seconds")


func _attack_bullet_pattern() -> void:
    var roll: float = randf()
    var phase: int = _get_boss_phase()

    if phase == 1:
        if roll < 0.55:
            await _shoot_toxic_barrage()
        else:
            _shoot_toxic_fan()
    elif phase == 2:
        if roll < 0.45:
            await _shoot_toxic_barrage()
        else:
            _shoot_toxic_fan()
    else:
        if roll < 0.35:
            await _shoot_toxic_barrage()
        else:
            _shoot_toxic_fan()


func _shoot_toxic_barrage() -> void:
    if toxic_bullet_scene == null:
        if debug_enabled:
            print("Tentacle toxic_bullet_scene not assigned")
        return

    if player == null or not is_instance_valid(player):
        return

    var phase: int = _get_boss_phase()
    var count_bonus: int = 0
    var spread_bonus: float = 0.0

    if phase == 2:
        count_bonus = 1
        spread_bonus = 10.0
    elif phase == 3:
        count_bonus = 2
        spread_bonus = 18.0

    var bullet_count: int = randi_range(
        toxic_bullet_count_min + count_bonus,
        toxic_bullet_count_max + count_bonus
    )

    var base_dir: Vector2 = player.global_position - global_position

    if base_dir.length_squared() <= 0.0001:
        base_dir = Vector2.RIGHT

    base_dir = base_dir.normalized()

    var spread_rad: float = deg_to_rad(toxic_bullet_spread_degrees + spread_bonus)

    for i in range(bullet_count):
        if _is_dead:
            return

        if not is_instance_valid(self):
            return

        var random_angle: float = randf_range(-spread_rad * 0.5, spread_rad * 0.5)
        var fire_dir: Vector2 = base_dir.rotated(random_angle)

        _spawn_toxic_bullet(fire_dir)

        if debug_enabled:
            print("Tentacle shoot toxic barrage bullet")

        var wait_completed: bool = await _safe_wait(toxic_bullet_fire_interval)

        if not wait_completed:
            return


func _shoot_toxic_fan() -> void:
    if toxic_bullet_scene == null:
        if debug_enabled:
            print("Tentacle toxic_bullet_scene not assigned")
        return

    if player == null or not is_instance_valid(player):
        return

    var phase: int = _get_boss_phase()
    var count_bonus: int = 0
    var spread_bonus: float = 0.0

    if phase == 2:
        count_bonus = 1
        spread_bonus = 10.0
    elif phase == 3:
        count_bonus = 2
        spread_bonus = 20.0

    var bullet_count: int = randi_range(
        fan_bullet_count_min + count_bonus,
        fan_bullet_count_max + count_bonus
    )

    var base_dir: Vector2 = player.global_position - global_position

    if base_dir.length_squared() <= 0.0001:
        base_dir = Vector2.RIGHT

    base_dir = base_dir.normalized()

    if bullet_count <= 1:
        _spawn_toxic_bullet(base_dir)
        return

    var spread_rad: float = deg_to_rad(fan_spread_degrees + spread_bonus)
    var start_angle: float = -spread_rad / 2.0
    var angle_step: float = spread_rad / float(bullet_count - 1)

    for i in range(bullet_count):
        var angle_offset: float = start_angle + angle_step * i
        var fire_dir: Vector2 = base_dir.rotated(angle_offset)

        _spawn_toxic_bullet(fire_dir)

    if debug_enabled:
        print("Tentacle shoot toxic fan count = ", bullet_count)


func _spawn_toxic_bullet(fire_dir: Vector2) -> void:
    if toxic_bullet_scene == null:
        if debug_enabled:
            print("Tentacle toxic_bullet_scene not assigned")
        return

    if _is_dead:
        return

    var spawn_parent: Node = _get_spawn_parent()

    if spawn_parent == null:
        return

    var bullet: Node = toxic_bullet_scene.instantiate()
    spawn_parent.add_child(bullet)

    var normalized_dir: Vector2 = fire_dir.normalized()
    var spawn_pos: Vector2 = global_position + normalized_dir * 28.0

    if bullet.has_method("setup"):
        bullet.setup(spawn_pos, normalized_dir)

    var bullet_speed = bullet.get("speed")

    if bullet_speed != null:
        var speed_mult: float = randf_range(
            toxic_bullet_speed_random_min,
            toxic_bullet_speed_random_max
        )

        var phase: int = _get_boss_phase()

        if phase == 2:
            speed_mult *= 1.08
        elif phase == 3:
            speed_mult *= 1.18

        bullet.set("speed", float(bullet_speed) * speed_mult)


func _attack_slam() -> void:
    if player == null or not is_instance_valid(player):
        return

    var target_pos: Vector2 = _get_predicted_slam_position()

    if slam_warning_scene != null:
        var spawn_parent: Node = _get_spawn_parent()

        if spawn_parent != null:
            var warning: Node = slam_warning_scene.instantiate()
            spawn_parent.add_child(warning)

            if warning.has_method("setup"):
                warning.setup(target_pos, slam_radius, slam_prepare_time)
            elif warning is Node2D:
                (warning as Node2D).global_position = target_pos

            if debug_enabled:
                print("Tentacle spawned slam warning")
    else:
        if debug_enabled:
            print("Tentacle slam_warning_scene not assigned")

    if debug_enabled:
        print("Tentacle preparing slam at ", target_pos)

    var wait_completed: bool = await _safe_wait(slam_prepare_time)

    if not wait_completed:
        return

    if _is_dead:
        return

    _deal_slam_damage(target_pos)


func _deal_slam_damage(target_pos: Vector2) -> void:
    if player == null or not is_instance_valid(player):
        return

    var distance: float = player.global_position.distance_to(target_pos)

    if distance > slam_radius:
        if debug_enabled:
            print("Tentacle slam missed")
        return

    var phase: int = _get_boss_phase()

    if phase == 1:
        _try_apply_slam_slow(
            slam_phase1_slow_multiplier,
            slam_phase1_slow_duration
        )

        if debug_enabled:
            print("Tentacle slam phase 1 slow only")

        return

    if phase == 2:
        if player.has_method("take_damage"):
            player.take_damage(float(slam_phase2_damage))

        _try_apply_slam_slow(
            slam_phase2_slow_multiplier,
            slam_phase2_slow_duration
        )

        if debug_enabled:
            print("Tentacle slam phase 2 damage and slow")

        return

    if phase == 3:
        if player.has_method("take_damage"):
            player.take_damage(float(slam_phase3_damage))

        _try_apply_slam_slow(
            slam_phase3_slow_multiplier,
            slam_phase3_slow_duration
        )

        if debug_enabled:
            print("Tentacle slam phase 3 damage and heavy slow")


func _try_apply_slam_slow(multiplier: float, duration: float) -> void:
    if player == null or not is_instance_valid(player):
        return

    if not player.has_method("apply_slow"):
        return

    var now: float = float(Time.get_ticks_msec()) / 1000.0
    var next_allowed_time: float = 0.0

    if player.has_meta("slam_slow_next_allowed_time"):
        next_allowed_time = float(player.get_meta("slam_slow_next_allowed_time"))

    if now < next_allowed_time:
        if debug_enabled:
            print("Slam slow skipped by immunity")
        return

    player.apply_slow(multiplier, duration)
    player.set_meta("slam_slow_next_allowed_time", now + slam_slow_immunity_time)


func _get_predicted_slam_position() -> Vector2:
    if player == null or not is_instance_valid(player):
        return global_position

    var predicted_pos: Vector2 = player.global_position

    if player is CharacterBody2D:
        var player_velocity: Vector2 = (player as CharacterBody2D).velocity
        predicted_pos += player_velocity * slam_lead_time

    var random_offset: Vector2 = Vector2(
        randf_range(-slam_random_offset, slam_random_offset),
        randf_range(-slam_random_offset, slam_random_offset)
    )

    return predicted_pos + random_offset


func take_damage(amount: int) -> void:
    if _is_dead:
        return

    if not _can_take_damage:
        return

    _can_take_damage = false

    hp -= amount

    if debug_enabled:
        print("Tentacle HP = ", hp)

    if hp <= 0:
        die()
        return

    _reset_damage_cooldown()


func _reset_damage_cooldown() -> void:
    var wait_completed: bool = await _safe_wait(damage_cooldown)

    if not wait_completed:
        return

    if _is_dead:
        return

    _can_take_damage = true


func die() -> void:
    if _is_dead:
        return

    _is_dead = true

    if debug_enabled:
        print("Tentacle destroyed")

    if boss_ref != null and boss_ref.has_method("on_tentacle_destroyed"):
        boss_ref.on_tentacle_destroyed(global_position)
    else:
        print("Tentacle cannot find boss on_tentacle_destroyed")

    queue_free()


func _get_boss_phase() -> int:
    if boss_ref == null or not is_instance_valid(boss_ref):
        return 1

    if not boss_ref.has_method("get_hp_ratio"):
        return 1

    var hp_ratio: float = boss_ref.get_hp_ratio()

    if hp_ratio > 0.75:
        return 1

    if hp_ratio > 0.5:
        return 2

    return 3


func _get_spawn_parent() -> Node:
    var tree := get_tree()

    if tree == null:
        return null

    if tree.current_scene != null:
        return tree.current_scene

    return tree.root


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

@export var toxic_bullet_scene: PackedScene
@export var shoot_interval_min: float = 1.0
@export var shoot_interval_max: float = 1.8

@export var toxic_bullet_count_min: int = 5
@export var toxic_bullet_count_max: int = 8
@export var toxic_bullet_spread_degrees: float = 55.0
@export var toxic_bullet_speed_random_min: float = 0.9
@export var toxic_bullet_speed_random_max: float = 1.35
@export var toxic_bullet_fire_interval: float = 0.045

@export var fan_bullet_count_min: int = 5
@export var fan_bullet_count_max: int = 9
@export var fan_spread_degrees: float = 75.0

@export var slam_warning_scene: PackedScene
@export var slam_radius: float = 85.0
@export var slam_prepare_time: float = 0.85
@export var slam_chance: float = 0.32
@export var global_slam_cooldown: float = 10.0

@export var slam_phase1_slow_multiplier: float = 0.7
@export var slam_phase1_slow_duration: float = 0.6

@export var slam_phase2_damage: int = 10
@export var slam_phase2_slow_multiplier: float = 0.6
@export var slam_phase2_slow_duration: float = 0.9

@export var slam_phase3_damage: int = 14
@export var slam_phase3_slow_multiplier: float = 0.45
@export var slam_phase3_slow_duration: float = 1.2

@export var slam_slow_immunity_time: float = 0.8
