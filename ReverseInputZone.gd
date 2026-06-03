extends Area2D

@export var lifetime: float = 5.0
@export var reverse_duration: float = 2.5
@export var trigger_once_per_zone: bool = true
@export var debug_enabled: bool = true

var triggered_players: Array[Node] = []


func _ready() -> void:
    add_to_group("reverse_input_zone")

    monitoring = true
    monitorable = true

    if not body_entered.is_connected(_on_body_entered):
        body_entered.connect(_on_body_entered)

    var completed: bool = await _safe_wait(lifetime)

    if not completed:
        return

    if is_instance_valid(self):
        queue_free()


func _on_body_entered(body: Node) -> void:
    if body == null:
        return

    if not body.is_in_group("player"):
        return

    if trigger_once_per_zone and triggered_players.has(body):
        return

    triggered_players.append(body)

    if body.has_method("apply_reverse_input"):
        body.apply_reverse_input(reverse_duration)
    elif body.has_method("set_reverse_input"):
        body.set_reverse_input(true)
        _turn_off_later(body, reverse_duration)

    if debug_enabled:
        print("Reverse zone triggered player for ", reverse_duration, " seconds")


func _turn_off_later(body: Node, duration: float) -> void:
    var completed: bool = await _safe_wait(duration)

    if not completed:
        return

    if body == null or not is_instance_valid(body):
        return

    if body.has_method("set_reverse_input"):
        body.set_reverse_input(false)


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
