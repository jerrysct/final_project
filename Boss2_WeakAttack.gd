extends Node

@export var toxic_bullet_scene: PackedScene

@export var weak_bullet_interval: float = 0.55
@export var weak_bullet_count: int = 4
@export var weak_bullet_spread_degrees: float = 45.0
@export var weak_bullet_speed_multiplier: float = 0.65

@export var debug_enabled: bool = true

var boss: Node2D = null
var _running: bool = false


func setup(boss_node: Node2D) -> void:
	boss = boss_node


func start() -> void:
	if _running:
		return

	if boss == null or not is_instance_valid(boss):
		return

	_running = true
	_run_loop()


func stop() -> void:
	_running = false


func _run_loop() -> void:
	while _running:
		if boss == null or not is_instance_valid(boss):
			break

		if boss.has_method("is_weak"):
			if not boss.is_weak():
				break

		_shoot_weak_reflect_barrage()

		var completed: bool = await _safe_wait(weak_bullet_interval)

		if not completed:
			break

	_running = false


func _shoot_weak_reflect_barrage() -> void:
	if toxic_bullet_scene == null:
		if debug_enabled:
			print("Boss2WeakAttack toxic_bullet_scene not assigned")
		return

	var player: Node2D = _find_player()

	if player == null:
		return

	if boss == null or not is_instance_valid(boss):
		return

	var base_dir: Vector2 = player.global_position - boss.global_position

	if base_dir.length_squared() <= 0.0001:
		base_dir = Vector2.RIGHT

	base_dir = base_dir.normalized()

	if weak_bullet_count <= 1:
		_spawn_weak_bullet(base_dir)
		return

	var spread_rad: float = deg_to_rad(weak_bullet_spread_degrees)
	var start_angle: float = -spread_rad / 2.0
	var angle_step: float = spread_rad / float(weak_bullet_count - 1)

	for i in range(weak_bullet_count):
		var angle_offset: float = start_angle + angle_step * i
		var fire_dir: Vector2 = base_dir.rotated(angle_offset)
		_spawn_weak_bullet(fire_dir)

	if debug_enabled:
		print("Boss2 weak reflect barrage count = ", weak_bullet_count)


func _spawn_weak_bullet(fire_dir: Vector2) -> void:
	if toxic_bullet_scene == null:
		return

	if boss == null or not is_instance_valid(boss):
		return

	var spawn_parent: Node = _get_spawn_parent()

	if spawn_parent == null:
		return

	var bullet: Node = toxic_bullet_scene.instantiate()
	spawn_parent.add_child(bullet)

	if bullet.has_method("setup"):
		bullet.setup(boss.global_position, fire_dir.normalized())

	var bullet_speed = bullet.get("speed")

	if bullet_speed != null:
		bullet.set("speed", float(bullet_speed) * weak_bullet_speed_multiplier)


func _find_player() -> Node2D:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")

	if players.size() <= 0:
		return null

	return players[0] as Node2D


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
