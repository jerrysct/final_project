extends Area2D

@export var lifetime: float = 5.0
@export var reverse_duration: float = 2.5
@export var debug_enabled: bool = true

var affected_players: Dictionary = {}   # player -> original state


func _ready() -> void:
    add_to_group("reverse_input_zone")

    monitoring = true
    monitorable = true

    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)

    await get_tree().create_timer(lifetime).timeout
    queue_free()


func _on_body_entered(body: Node) -> void:
    if body == null:
        return

    if not body.is_in_group("player"):
        return

    if not body.has_method("apply_reverse_input"):
        print("這個 player 沒有 apply_reverse_input(): ", body.name)
        return

    body.apply_reverse_input(reverse_duration)

    print("Reverse applied to ", body.name)



func _on_body_exited(body: Node) -> void:
    if not body.is_in_group("player"):
        return

    if body in affected_players:
        _remove_reverse(body)
        affected_players.erase(body)


func _apply_reverse(player: Node) -> void:
    if player.has_method("set_velocity"):
        _reverse_velocity(player)

        _reverse_direction_runtime(player)

    if debug_enabled:
        print("Reverse applied to player")


func _remove_reverse(player: Node) -> void:
    if player == null:
        return

    if not is_instance_valid(player):
        return

    if player.has_meta("reverse_flag"):
        player.set_meta("reverse_flag", false)

    if debug_enabled:
        print("Reverse removed from player")


func _reverse_direction_runtime(player: Node) -> void:
    player.set_meta("reverse_flag", true)

    if not player.has_method("_physics_process"):
        return

    # 用一個小 hack：每幀強制反轉
    _process_reverse(player)


func _process_reverse(player: Node) -> void:
    while is_instance_valid(player) and player.get_meta("reverse_flag", false):
        if "velocity" in player:
            player.velocity = -player.velocity

        await get_tree().process_frame
        
func _reverse_velocity(player: Node) -> void:
    if "velocity" in player:
        player.velocity = -player.velocity
