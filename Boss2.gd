extends Node2D

@export var max_hp: int = 720
@export var phase1_tentacle_damage_to_boss: int = 48
@export var phase2_tentacle_damage_to_boss: int = 12
@export var phase2_direct_damage_multiplier: float = 0.35
@export var weak_duration: float = 2.5
@export var debug_enabled: bool = true

@export var toxic_bullet_scene: PackedScene

@export var boss_attack_interval_min: float = 2.4
@export var boss_attack_interval_max: float = 4.0


@export var phase1_bullet_count: int = 3
@export var phase2_bullet_count: int = 5
@export var phase3_bullet_count: int = 7

@export var phase1_spread_degrees: float = 30.0
@export var phase2_spread_degrees: float = 55.0
@export var phase3_spread_degrees: float = 80.0

@export var burst_bullet_scene: PackedScene
@export var burst_attack_chance: float = 0.22

@export var fish_scene: PackedScene
@export var explode_fish_scene: PackedScene
@export var summon_fish_chance: float = 0.20
@export var fish_spawn_count_min: int = 2
@export var fish_spawn_count_max: int = 4
@export var fish_spawn_radius: float = 260.0

@export var max_normal_fish: int = 4
@export var max_explode_fish: int = 2

@export var laser_warning_scene: PackedScene
@export var laser_attack_chance: float = 0.16
@export var laser_range: float = 420.0
@export var laser_angle_degrees: float = 90.0
@export var laser_prepare_time: float = 0.8
@export var phase2_laser_damage: int = 14
@export var phase3_laser_damage: int = 18

@export var toxic_charge_time: float = 0.35
@export var burst_charge_time: float = 0.5
@export var laser_charge_time: float = 0.4

@export var normal_texture: Texture2D
@export var toxic_attack_texture: Texture2D
@export var burst_attack_texture: Texture2D
@export var laser_attack_texture: Texture2D

@onready var body_sprite: Sprite2D = get_node_or_null("BodySprite") as Sprite2D

@export var target_visual_height: float = 220.0

@export var normal_texture_scale_multiplier: float = 1.0
@export var toxic_texture_scale_multiplier: float = 1.0
@export var burst_texture_scale_multiplier: float = 1.0
@export var laser_texture_scale_multiplier: float = 1.0

@export var normal_texture_offset: Vector2 = Vector2.ZERO
@export var toxic_texture_offset: Vector2 = Vector2.ZERO
@export var burst_texture_offset: Vector2 = Vector2.ZERO
@export var laser_texture_offset: Vector2 = Vector2.ZERO

var hp: int
var _is_weak: bool = false
var _is_dead: bool = false
var _is_attacking: bool = false
var _is_phase_transitioning: bool = false

var _room_controller: Node = null
var player: Node2D = null
var _attack_timer: float = 0.0
var _current_phase: int = 1


func _ready() -> void:
    hp = max_hp
    find_player()
    _roll_attack_timer()
    _show_normal_texture()

    if debug_enabled:
        print("Boss2 ready, HP = ", hp)


func _physics_process(delta: float) -> void:
    if _is_dead:
        return

    if hp <= 0:
        return

    if player == null or not is_instance_valid(player):
        find_player()
        return

    _check_phase_transition()

    if _is_phase_transitioning:
        return

    if _is_attacking:
        return

    _attack_timer -= delta

    if _attack_timer <= 0.0:
        _is_attacking = true

        var roll: float = randf()
        var hp_ratio: float = get_hp_ratio()

        if hp_ratio <= 0.75 and roll < laser_attack_chance:
            await _attack_laser()
        elif roll < laser_attack_chance + summon_fish_chance:
            _summon_fish_group()
        elif roll < laser_attack_chance + summon_fish_chance + burst_attack_chance:
            await _shoot_burst_bullet()
        else:
            await _shoot_boss_toxic_barrage()

        _roll_attack_timer()
        _is_attacking = false


func set_room_controller(room: Node) -> void:
    _room_controller = room

    if debug_enabled:
        print("Boss2 已接收 BossRoom2 控制器")


func find_player() -> void:
    var players: Array[Node] = get_tree().get_nodes_in_group("player")

    if players.size() > 0:
        player = players[0] as Node2D


func _roll_attack_timer() -> void:
    _attack_timer = randf_range(boss_attack_interval_min, boss_attack_interval_max)


# ============================================================
# Texture Control
# ============================================================

func _set_boss_texture_advanced(texture: Texture2D, scale_multiplier: float, texture_offset: Vector2) -> void:
    if body_sprite == null:
        return

    if texture == null:
        return

    body_sprite.texture = texture
    body_sprite.centered = true

    var texture_size: Vector2 = texture.get_size()

    if texture_size.y <= 0.0:
        return

    var scale_value: float = target_visual_height / texture_size.y
    body_sprite.scale = Vector2(scale_value, scale_value) * scale_multiplier
    body_sprite.position = texture_offset


func _show_normal_texture() -> void:
    _set_boss_texture_advanced(
        normal_texture,
        normal_texture_scale_multiplier,
        normal_texture_offset
    )


func _show_toxic_attack_texture() -> void:
    _set_boss_texture_advanced(
        toxic_attack_texture,
        toxic_texture_scale_multiplier,
        toxic_texture_offset
    )


func _show_burst_attack_texture() -> void:
    _set_boss_texture_advanced(
        burst_attack_texture,
        burst_texture_scale_multiplier,
        burst_texture_offset
    )


func _show_laser_attack_texture() -> void:
    _set_boss_texture_advanced(
        laser_attack_texture,
        laser_texture_scale_multiplier,
        laser_texture_offset
    )


# ============================================================
# Phase
# ============================================================

func get_hp_ratio() -> float:
    if max_hp <= 0:
        return 0.0

    return float(hp) / float(max_hp)


func get_current_phase() -> int:
    var hp_ratio: float = get_hp_ratio()

    if hp_ratio > 0.75:
        return 1

    if hp_ratio > 0.5:
        return 2

    return 3


func _check_phase_transition() -> void:
    if _is_phase_transitioning:
        return

    var new_phase: int = get_current_phase()

    if new_phase == _current_phase:
        return

    _current_phase = new_phase

    if new_phase == 2:
        _start_phase2_transition()
    elif new_phase == 3:
        _start_phase3_transition()


func _start_phase2_transition() -> void:
    _is_phase_transitioning = true
    _show_normal_texture()

    if debug_enabled:
        print("Boss2 phase 2 transition")

    var tween := create_tween()
    tween.tween_property(self, "modulate", Color(0.5, 1.0, 0.6), 0.15)
    tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0), 0.15)
    tween.set_loops(3)

    await get_tree().create_timer(0.9).timeout

    if not is_instance_valid(self):
        return

    if _is_dead:
        return

    modulate = Color(1.0, 1.0, 1.0)
    _is_phase_transitioning = false


func _start_phase3_transition() -> void:
    _is_phase_transitioning = true
    _show_normal_texture()

    if debug_enabled:
        print("Boss2 phase 3 transition")

    var tween := create_tween()
    tween.tween_property(self, "modulate", Color(1.0, 0.2, 0.2), 0.12)
    tween.tween_property(self, "modulate", Color(0.5, 0.0, 0.0), 0.12)
    tween.set_loops(5)

    await get_tree().create_timer(1.2).timeout

    if not is_instance_valid(self):
        return

    if _is_dead:
        return

    modulate = Color(1.0, 1.0, 1.0)

    if _room_controller != null:
        if _room_controller.has_method("get_active_tentacle_count"):
            if int(_room_controller.get_active_tentacle_count()) <= 0:
                if _room_controller.has_method("_spawn_phase3_tentacle_wave"):
                    _room_controller._spawn_phase3_tentacle_wave()

    _is_phase_transitioning = false


func is_weak() -> bool:
    return _is_weak


# ============================================================
# Boss Attacks
# ============================================================

func _shoot_boss_toxic_barrage() -> void:
    if toxic_bullet_scene == null:
        if debug_enabled:
            print("Boss2 toxic_bullet_scene not assigned")
        return

    if player == null or not is_instance_valid(player):
        return

    _show_toxic_attack_texture()
    await get_tree().create_timer(toxic_charge_time).timeout
    _show_normal_texture()

    if _is_dead:
        return

    var hp_ratio: float = get_hp_ratio()

    var bullet_count: int = phase1_bullet_count
    var spread_degrees: float = phase1_spread_degrees

    if hp_ratio <= 0.5:
        bullet_count = phase3_bullet_count
        spread_degrees = phase3_spread_degrees
    elif hp_ratio <= 0.75:
        bullet_count = phase2_bullet_count
        spread_degrees = phase2_spread_degrees

    var base_dir: Vector2 = player.global_position - global_position

    if base_dir.length_squared() <= 0.0001:
        base_dir = Vector2.RIGHT

    base_dir = base_dir.normalized()

    if bullet_count <= 1:
        _spawn_boss_toxic_bullet(base_dir)
        return

    var spread_rad: float = deg_to_rad(spread_degrees)
    var start_angle: float = -spread_rad / 2.0
    var angle_step: float = spread_rad / float(bullet_count - 1)

    for i in range(bullet_count):
        var angle_offset: float = start_angle + angle_step * i
        var fire_dir: Vector2 = base_dir.rotated(angle_offset)

        _spawn_boss_toxic_bullet(fire_dir)

    if debug_enabled:
        print("Boss2 shoot toxic barrage count = ", bullet_count)


func _spawn_boss_toxic_bullet(fire_dir: Vector2) -> void:
    if toxic_bullet_scene == null:
        return

    var bullet: Node = toxic_bullet_scene.instantiate()
    get_tree().current_scene.add_child(bullet)

    if bullet.has_method("setup"):
        bullet.setup(global_position, fire_dir.normalized())


func _shoot_burst_bullet() -> void:
    if burst_bullet_scene == null:
        if debug_enabled:
            print("Boss2 burst_bullet_scene not assigned")
        return

    if player == null or not is_instance_valid(player):
        return

    _show_burst_attack_texture()
    await get_tree().create_timer(burst_charge_time).timeout
    _show_normal_texture()

    if _is_dead:
        return

    var dir: Vector2 = player.global_position - global_position

    if dir.length_squared() <= 0.0001:
        dir = Vector2.RIGHT

    var bullet: Node = burst_bullet_scene.instantiate()
    get_tree().current_scene.add_child(bullet)

    if bullet.has_method("setup"):
        bullet.setup(global_position, dir.normalized())

    if debug_enabled:
        print("Boss2 shoot burst bullet")


func _attack_laser() -> void:
    if player == null or not is_instance_valid(player):
        return

    _show_laser_attack_texture()
    await get_tree().create_timer(laser_charge_time).timeout
    _show_normal_texture()

    if _is_dead:
        return

    var laser_dir: Vector2 = player.global_position - global_position

    if laser_dir.length_squared() <= 0.0001:
        laser_dir = Vector2.RIGHT

    laser_dir = laser_dir.normalized()

    if laser_warning_scene != null:
        var warning: Node = laser_warning_scene.instantiate()
        get_tree().current_scene.add_child(warning)

        if warning.has_method("setup"):
            warning.setup(
                global_position,
                laser_dir,
                laser_range,
                laser_angle_degrees,
                laser_prepare_time
            )
    else:
        if debug_enabled:
            print("Boss2 laser_warning_scene not assigned")

    if debug_enabled:
        print("Boss2 preparing 90 degree laser")

    await get_tree().create_timer(laser_prepare_time).timeout

    if _is_dead:
        return

    _deal_laser_damage(laser_dir)


func _deal_laser_damage(laser_dir: Vector2) -> void:
    if player == null or not is_instance_valid(player):
        return

    var to_player: Vector2 = player.global_position - global_position
    var distance: float = to_player.length()

    if distance > laser_range:
        if debug_enabled:
            print("Boss2 laser missed: player out of range")
        return

    if to_player.length_squared() <= 0.0001:
        return

    var angle_to_player: float = abs(laser_dir.angle_to(to_player.normalized()))
    var half_angle: float = deg_to_rad(laser_angle_degrees) * 0.5

    if angle_to_player > half_angle:
        if debug_enabled:
            print("Boss2 laser missed: player out of angle")
        return

    var damage: int = phase2_laser_damage

    if get_hp_ratio() <= 0.5:
        damage = phase3_laser_damage

    if player.has_method("take_damage"):
        player.take_damage(float(damage))

    if debug_enabled:
        print("Boss2 laser hit player, damage = ", damage)


# ============================================================
# Fish Summon
# ============================================================

func _get_alive_group_count(group_name: String) -> int:
    var count: int = 0

    for node in get_tree().get_nodes_in_group(group_name):
        if node != null and is_instance_valid(node):
            count += 1

    return count


func _summon_fish_group() -> void:
    var normal_count: int = _get_alive_group_count("normal_fish")
    var explode_count: int = _get_alive_group_count("explode_fish")

    var spawn_count: int = randi_range(fish_spawn_count_min, fish_spawn_count_max)
    var actually_spawned: int = 0

    for i in range(spawn_count):
        var use_explode_fish: bool = randf() < 0.35
        var scene_to_use: PackedScene = null

        if use_explode_fish:
            if explode_count >= max_explode_fish:
                continue

            if explode_fish_scene == null:
                continue

            scene_to_use = explode_fish_scene
            explode_count += 1
        else:
            if normal_count >= max_normal_fish:
                continue

            if fish_scene == null:
                continue

            scene_to_use = fish_scene
            normal_count += 1

        var fish: Node = scene_to_use.instantiate()
        get_tree().current_scene.add_child(fish)

        if fish is Node2D:
            var angle: float = randf() * TAU
            var offset: Vector2 = Vector2.RIGHT.rotated(angle) * fish_spawn_radius
            (fish as Node2D).global_position = global_position + offset

        actually_spawned += 1

    if debug_enabled:
        print("Boss2 summon fish group count = ", actually_spawned)


# ============================================================
# Damage / Tentacle System
# ============================================================

func on_tentacle_destroyed(pos: Vector2) -> void:
    if _is_dead:
        return

    var hp_ratio: float = get_hp_ratio()

    if debug_enabled:
        print("觸手被打掉，位置 = ", pos)

    # Phase 1：75%以上，觸手死亡是主要推進手段
    if hp_ratio > 0.75:
        _apply_tentacle_damage(phase1_tentacle_damage_to_boss)

        if debug_enabled:
            print("Phase 1：觸手死亡造成 Boss 傷害 = ", phase1_tentacle_damage_to_boss)

        return

    # Phase 2：50%~75%，觸手死亡只造成少量傷害，主要用途是開虛弱窗口
    if hp_ratio > 0.5:
        _apply_tentacle_damage(phase2_tentacle_damage_to_boss)

        if _is_dead:
            return

        enter_weak_state()

        if debug_enabled:
            print("Phase 2：觸手死亡造成少量傷害 = ", phase2_tentacle_damage_to_boss, "，並觸發虛弱")

        return

    # Phase 3：50%以下，觸手死亡不直接傷害 Boss
    if debug_enabled:
        print("Phase 3：觸手死亡不直接傷害 Boss，清完觸手後才能攻擊本體")


func on_tentacle_removed(remaining_count: int) -> void:
    if debug_enabled:
        print("剩餘觸手數量 = ", remaining_count)

    var hp_ratio: float = get_hp_ratio()

    if hp_ratio <= 0.5 and remaining_count <= 0:
        if debug_enabled:
            print("Phase 3：觸手全清，Boss 進入虛弱可傷害狀態")

        enter_weak_state()


func take_damage(amount: int) -> void:
    if _is_dead:
        return

    var hp_ratio: float = get_hp_ratio()

    if hp_ratio > 0.75:
        if debug_enabled:
            print("Phase 1：Boss 本體無敵，請打觸手")
        return

    if hp_ratio > 0.5:
        if _is_weak:
            if debug_enabled:
                print("Phase 2：Boss 虛弱中，承受完整傷害 = ", amount)

            _apply_damage(amount)
        else:
            var reduced_damage: int = max(1, int(float(amount) * phase2_direct_damage_multiplier))

            if debug_enabled:
                print("Phase 2：Boss 減傷，原傷害 = ", amount, " 實際傷害 = ", reduced_damage)

            _apply_damage(reduced_damage)

        return

    if _has_active_tentacles():
        if debug_enabled:
            print("Phase 3：場上還有觸手，Boss 本體無敵")
        return

    if not _is_weak:
        if debug_enabled:
            print("Phase 3：觸手已清完，但 Boss 尚未進入虛弱，暫時無法傷害")
        return

    if debug_enabled:
        print("Phase 3：Boss 虛弱中，承受傷害 = ", amount)

    _apply_damage(amount)


func _apply_tentacle_damage(amount: int) -> void:
    _apply_damage(amount)


func _apply_damage(amount: int) -> void:
    if _is_dead:
        return

    hp -= amount
    hp = max(hp, 0)

    if debug_enabled:
        print("Boss2 HP = ", hp, " / ", max_hp)

    if hp <= 0:
        die()


func _has_active_tentacles() -> bool:
    if _room_controller == null:
        return false

    if not _room_controller.has_method("get_active_tentacle_count"):
        return false

    return int(_room_controller.get_active_tentacle_count()) > 0


func enter_weak_state() -> void:
    if _is_dead:
        return

    if _is_weak:
        return

    if not is_inside_tree():
        return

    var tree := get_tree()

    if tree == null:
        return

    _is_weak = true
    _show_normal_texture()

    if debug_enabled:
        print("Boss2 進入虛弱狀態")

    modulate = Color(1.0, 0.45, 0.45)

    await tree.create_timer(weak_duration).timeout

    if not is_instance_valid(self):
        return

    if _is_dead:
        return

    if not is_inside_tree():
        return

    modulate = Color(1.0, 1.0, 1.0)
    _is_weak = false

    if debug_enabled:
        print("Boss2 虛弱結束")


func die() -> void:
    if _is_dead:
        return

    _is_dead = true
    _is_weak = false
    _show_normal_texture()

    if debug_enabled:
        print("Boss2 死了")

    queue_free()
