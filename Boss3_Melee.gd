extends CharacterBody2D

@export var max_hp: int = 300
@export var move_speed: float = 120.0
@export var contact_damage: int = 10

var hp: int
var player: Node2D = null

func _ready():
	hp = max_hp
	find_player()

func _physics_process(delta):
	if player == null:
		find_player()
		return

	var direction = (player.global_position - global_position).normalized()
	velocity = direction * move_speed

	move_and_slide()

func find_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func take_damage(amount: int):
	hp -= amount
	print("Boss3 近戰 HP:", hp)

	if hp <= 0:
		die()

func die():
	print("Boss3 近戰死亡")
	queue_free()
