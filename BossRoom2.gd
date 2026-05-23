extends Node2D

@export var tentacle_scene: PackedScene

var _tentacles: Array = []
var _max_tentacles: int = 4

# ✅ 改成你場景裡真正的Boss名稱
@onready var boss: Node2D = $Boss2


func _ready() -> void:
	if boss == null:
		print("❌ 找不到 Boss，請確認名稱是不是 Boss2")
		return

	print("Boss位置 = ", boss.global_position)

	spawn_initial_tentacles()


# ✅ 初始生成
func spawn_initial_tentacles() -> void:
	for i in range(_max_tentacles):
		spawn_tentacle()


# ✅ 生單支觸手
func spawn_tentacle() -> void:
	if _tentacles.size() >= _max_tentacles:
		return

	if tentacle_scene == null:
		print("❌ tentacle_scene 沒設定")
		return

	var tentacle = tentacle_scene.instantiate()
	add_child(tentacle)
	tentacle.boss = boss 

	# ✅ 用Boss當中心（正確方式）
	var offset = _get_random_offset()
	var spawn_pos = boss.to_global(offset)

	tentacle.global_position = spawn_pos

	print("觸手生成在：", spawn_pos)

	_tentacles.append(tentacle)

	# ✅ 自動移除陣列
	tentacle.tree_exited.connect(func():
		_tentacles.erase(tentacle)
	)


# ✅ 隨機生成範圍（優化版）
func _get_random_offset() -> Vector2:
	var angle = randf() * TAU
	var dist = randf_range(120.0, 200.0)

	return Vector2.RIGHT.rotated(angle) * dist
