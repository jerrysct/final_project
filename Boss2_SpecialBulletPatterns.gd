extends Node

@export var pattern_bullet_scene: PackedScene
@export var debug_enabled: bool = true

# ============================================================
# ✅ 全局強化
# ============================================================
@export var special_speed_multiplier: float = 1.6

# ============================================================
# Pattern Weights
# ============================================================
@export var phase2_return_weight: float = 55.0
@export var phase2_orbit_weight: float = 45.0

@export var phase3_return_weight: float = 30.0
@export var phase3_double_ring_weight: float = 20.0
@export var phase3_gap_ring_weight: float = 25.0
@export var phase3_orbit_weight: float = 25.0

# ============================================================
# Speeds
# ============================================================
@export var return_out_speed: float = 150.0
@export var return_back_speed: float = 190.0

@export var double_ring_inner_speed: float = 140.0
@export var double_ring_outer_speed: float = 210.0

@export var gap_ring_speed: float = 170.0
@export var orbit_release_speed: float = 180.0

# ============================================================

var boss: Node2D = null


func setup(boss_node: Node2D) -> void:
    boss = boss_node


# ============================================================
# 主入口
# ============================================================

func execute_random_pattern() -> void:
    if boss == null or not is_instance_valid(boss):
        return

    var pattern = _roll_pattern()

    if debug_enabled:
        print("Special pattern = ", pattern)

    match pattern:
        "return":
            _shoot_return()
        "double":
            await _shoot_double()
        "gap":
            await _shoot_gap_hybrid()
        "orbit":
            _shoot_orbit()


# ============================================================
# Pattern Roll
# ============================================================

func _roll_pattern() -> String:
    var r = randf()
    if r < 0.25:
        return "return"
    elif r < 0.5:
        return "double"
    elif r < 0.75:
        return "gap"
    else:
        return "orbit"


# ============================================================
# ✅ 子彈生成（關鍵修正）
# ============================================================

func _spawn_bullet() -> Node:
    if pattern_bullet_scene == null:
        return null

    if boss == null:
        return null

    var b = pattern_bullet_scene.instantiate()
    get_tree().current_scene.add_child(b)

    # ✅ 強制中心發射
    if b is Node2D:
        (b as Node2D).global_position = boss.global_position

    return b


# ============================================================
# ✅ Return
# ============================================================

func _shoot_return() -> void:
    var player = _get_player()
    if player == null:
        return

    var base_dir = (player.global_position - boss.global_position).normalized()

    for i in range(8):
        var angle = base_dir.angle() + TAU * i / 8.0
        var dir = Vector2.RIGHT.rotated(angle)

        var speed = return_out_speed * special_speed_multiplier

        var b = _spawn_bullet()
        if b and b.has_method("setup_straight"):
            b.setup_straight(boss.global_position, dir, speed)


# ============================================================
# ✅ Double Ring
# ============================================================

func _shoot_double() -> void:
    var base = _get_angle_to_player()

    for i in range(10):
        var angle = base + TAU * i / 10.0
        var dir = Vector2.RIGHT.rotated(angle)

        var b = _spawn_bullet()
        if b:
            b.setup_straight(
                boss.global_position,
                dir,
                double_ring_inner_speed * special_speed_multiplier
            )

    await get_tree().create_timer(0.2).timeout

    for i in range(10):
        var angle = base + TAU * i / 10.0 + deg_to_rad(18)
        var dir = Vector2.RIGHT.rotated(angle)

        var b = _spawn_bullet()
        if b:
            b.setup_straight(
                boss.global_position,
                dir,
                double_ring_outer_speed * special_speed_multiplier
            )


# ============================================================
# ✅ Gap Ring（最終壓迫版）
# ============================================================

func _shoot_gap_hybrid() -> void:
    var player = _get_player()
    if player == null:
        return

    var boss_pos = boss.global_position
    var base_dir = (player.global_position - boss_pos).normalized()
    var base_angle = base_dir.angle()

    var total = 14
    var gap = 3

    var slot_angle = TAU / total
    var center = int(round(base_angle / slot_angle)) % total

    # 🔴 環封
    for i in range(total):
        var skip = false
        for g in range(gap):
            if i == (center + g) % total:
                skip = true
        if skip:
            continue

        var angle = TAU * i / total
        var dir = Vector2.RIGHT.rotated(angle)

        var b = _spawn_bullet()
        if b:
            b.setup_straight(
                boss_pos,
                dir,
                gap_ring_speed * special_speed_multiplier
            )

    # 🔴 中央彈
    var b1 = _spawn_bullet()
    if b1:
        b1.setup_straight(
            boss_pos,
            base_dir,
            gap_ring_speed * 1.5 * special_speed_multiplier
        )

    # 🔴 左右夾
    for offset in [-0.3, 0.3]:
        var dir = base_dir.rotated(offset)

        var b2 = _spawn_bullet()
        if b2:
            b2.setup_straight(
                boss_pos,
                dir,
                gap_ring_speed * 1.3 * special_speed_multiplier
            )

    # 🔴 延遲補刀
    await get_tree().create_timer(0.35).timeout

    var follow = (player.global_position - boss_pos).normalized()

    var b3 = _spawn_bullet()
    if b3:
        b3.setup_straight(
            boss_pos,
            follow,
            gap_ring_speed * 1.7 * special_speed_multiplier
        )


# ============================================================
# ✅ Orbit
# ============================================================

func _shoot_orbit() -> void:
    var player = _get_player()
    if player == null:
        return

    var base = _get_angle_to_player()

    for i in range(6):
        var angle = base + TAU * i / 6.0

        var b = _spawn_bullet()
        if b and b.has_method("setup_orbit"):
            b.setup_orbit(
                boss,
                angle,
                70,
                0.8,
                6.0,
                orbit_release_speed * special_speed_multiplier,
                player
            )


# ============================================================
# Helper
# ============================================================

func _get_player() -> Node2D:
    if "player" in boss:
        return boss.player

    var players = get_tree().get_nodes_in_group("player")
    if players.size() > 0:
        return players[0]

    return null


func _get_angle_to_player() -> float:
    var p = _get_player()
    if p == null:
        return 0

    return (p.global_position - boss.global_position).angle()
