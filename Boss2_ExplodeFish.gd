extends CharacterBody2D

var trigger_delay: float = 0.45
@export var move_speed: float = 105.0
@export var max_hp: int = 75

@export var explosion_damage: float = 8.0
@export var explosion_radius: float = 120.0
@export var trigger_distance: float = 90.0

@export var lifetime: float = 8.0
@export var debug_enabled: bool = true

@export var poison_bubble_scene: PackedScene
@export var poison_bubble_count_min: int = 4
@export var poison_bubble_count_max: int = 6

@export var poison_bubble_speed: float = 120.0
@export var poison_bubble_travel_time_min: float = 0.35
@export var poison_bubble_travel_time_max: float = 0.65
@export var poison_bubble_linger_time: float = 2.5
@export var poison_bubble_arm_after_stop_time: float = 0.1
@export var poison_bubble_spawn_offset: float = 20.0

var hp: int
var player: Node2D = null
var boss_ref: Node = null

var _is_dead: bool = false
var _is_exploding: bool = false


func _ready() -> void:
	add_to_group("explode_fish")

	hp = max_hp
	find_player()
	call_deferred("_apply_player_collision_exception")

	var completed: bool = await _safe_wait(lifetime)

	if not completed:
		return

	if is_instance_valid(self) and not _is_dead:
		explode()


func _physics_process(_delta: float) -> void:
	if _is_dead:
		return

	if player == null or not is_instance_valid(player):
		find_player()
		return

	if _is_exploding:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var dir: Vector2 = player.global_position - global_position

	if dir.length_squared() > 0.0001:
		velocity = dir.normalized() * move_speed
	else:
		velocity = Vector2.ZERO

	move_and_slide()

	if global_position.distance_to(player.global_position) <= trigger_distance:
		_start_explosion()


func set_boss_ref(boss_node: Node) -> void:
	boss_ref = boss_node


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
		print("ExplodeFish HP = ", hp)

	if hp <= 0:
		explode()


func _start_explosion() -> void:
	if _is_exploding:
		return

	if _is_dead:
		return

	_is_exploding = true
	velocity = Vector2.ZERO

	if debug_enabled:
		print("ExplodeFish preparing explosion")

	var completed: bool = await _safe_wait(trigger_delay)

	if not completed:
		return

	if not is_instance_valid(self):
		return

	explode()


func explode() -> void:
	if _is_dead:
		return

	_is_dead = true
	velocity = Vector2.ZERO

	if debug_enabled:
		print("ExplodeFish exploded")

	_deal_explosion_damage()
	_spawn_poison_bubbles()

	queue_free()


func _deal_explosion_damage() -> void:
	if player == null or not is_instance_valid(player):
		return

	var dist: float = player.global_position.distance_to(global_position)

	if dist <= explosion_radius:
		if player.has_method("take_damage"):
			player.take_damage(explosion_damage)

		if debug_enabled:
			print("ExplodeFish hit player, distance = ", dist)
	else:
		if debug_enabled:
			print("ExplodeFish missed player, distance = ", dist)


func _spawn_poison_bubbles() -> void:
	if poison_bubble_scene == null:
		if debug_enabled:
			print("ExplodeFish poison_bubble_scene not assigned")
		return

	var spawn_parent: Node = _get_spawn_parent()

	if spawn_parent == null:
		return

	var bubble_count: int = randi_range(
		poison_bubble_count_min,
		poison_bubble_count_max
	)

	var phase: int = _get_boss_phase()
	var angle_offset: float = randf() * TAU

	for i in range(bubble_count):
		var angle: float = angle_offset + TAU * float(i) / float(bubble_count)
		var fire_dir: Vector2 = Vector2.RIGHT.rotated(angle).normalized()
		var start_pos: Vector2 = global_position + fire_dir * poison_bubble_spawn_offset

		var travel_time: float = randf_range(
			poison_bubble_travel_time_min,
			poison_bubble_travel_time_max
		)

		var bubble: Node = poison_bubble_scene.instantiate()
		spawn_parent.add_child(bubble)
		bubble.add_to_group("boss2_bubble")

		if bubble.has_method("setup"):
			bubble.setup(
				start_pos,
				fire_dir,
				poison_bubble_speed,
				travel_time,
				poison_bubble_linger_time,
				poison_bubble_arm_after_stop_time,
				phase
			)
		elif bubble is Node2D:
			(bubble as Node2D).global_position = start_pos

	if debug_enabled:
		print("ExplodeFish spawned poison bubbles count = ", bubble_count)


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
