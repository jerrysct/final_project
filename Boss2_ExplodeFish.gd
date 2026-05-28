extends CharacterBody2D

@export var move_speed: float = 105.0
@export var max_hp: int = 75

@export var explosion_damage: float = 18.0
@export var explosion_radius: float = 120.0
@export var trigger_distance: float = 90.0
@export var trigger_delay: float = 0.45

@export var lifetime: float = 8.0
@export var debug_enabled: bool = true

var hp: int
var player: Node2D = null

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
		queue_free()


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

	if debug_enabled:
		print("ExplodeFish exploded")

	if player != null and is_instance_valid(player):
		var dist: float = player.global_position.distance_to(global_position)

		if dist <= explosion_radius:
			if player.has_method("take_damage"):
				player.take_damage(explosion_damage)

			if debug_enabled:
				print("ExplodeFish hit player, distance = ", dist)
		else:
			if debug_enabled:
				print("ExplodeFish missed player, distance = ", dist)

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
