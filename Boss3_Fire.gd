extends Area2D

@export var damage: int = 5
@export var lifetime: float = 3.0
@export var damage_tick_interval: float = 0.5
@export var debug_enabled: bool = false

var _targets: Dictionary = {}
var _tick_timer: float = 0.0


func _ready() -> void:
	monitoring = true
	monitorable = true

	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

	if debug_enabled:
		print("Boss3_Fire ready at: ", global_position)

	await get_tree().create_timer(lifetime).timeout
	queue_free()


func _physics_process(delta: float) -> void:
	_tick_timer -= delta

	if _tick_timer > 0.0:
		return

	_tick_timer = damage_tick_interval

	var invalid_targets: Array = []

	for target in _targets.keys():
		if not is_instance_valid(target):
			invalid_targets.append(target)
			continue

		if target.has_method("take_damage"):
			target.take_damage(damage)

			if debug_enabled:
				print("Boss3_Fire damage target: ", target.name, " damage = ", damage)

	for target in invalid_targets:
		_targets.erase(target)


func _on_area_entered(area: Area2D) -> void:
	var target := area.get_parent()

	if debug_enabled:
		print("Boss3_Fire area entered: ", area.name, " parent = ", target.name if target != null else "null")

	if target != null and target.has_method("take_damage"):
		_targets[target] = true

		if debug_enabled:
			print("Boss3_Fire add target: ", target.name)


func _on_area_exited(area: Area2D) -> void:
	var target := area.get_parent()

	if target != null and _targets.has(target):
		_targets.erase(target)

		if debug_enabled:
			print("Boss3_Fire remove target: ", target.name)
