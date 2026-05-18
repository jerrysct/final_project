extends Area2D

@export var damage: float = 5.0
@export var lifetime: float = 3.0
@export var damage_tick_interval: float = 0.5

var _targets: Dictionary = {}

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	await get_tree().create_timer(lifetime).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	var invalid_targets: Array[Node] = []
	for target: Node in _targets:
		if not is_instance_valid(target):
			invalid_targets.append(target)
			continue

		_targets[target] += delta
		if _targets[target] < damage_tick_interval:
			continue

		if target.has_method("take_damage"):
			target.take_damage(damage)
		_targets[target] = 0.0

	for target in invalid_targets:
		_targets.erase(target)

func _on_area_entered(area: Area2D) -> void:
	var player_body: Node = _get_player_from_hurtbox(area)
	if player_body == null:
		return
	_targets[player_body] = 0.0

func _on_area_exited(area: Area2D) -> void:
	var player_body: Node = _get_player_from_hurtbox(area)
	if player_body == null:
		return
	_targets.erase(player_body)

func _get_player_from_hurtbox(area: Area2D) -> Node:
	if area.name != "Hurtbox":
		return null
	var parent: Node = area.get_parent()
	if parent == null:
		return null
	if not parent.has_method("take_damage"):
		return null
	return parent
