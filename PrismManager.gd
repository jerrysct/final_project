extends Node2D

@export var prism_scene: PackedScene

@export var room_left: float = -700.0
@export var room_right: float = 700.0
@export var room_top: float = -450.0
@export var room_bottom: float = 450.0

@export var margin_x: float = 120.0
@export var margin_y: float = 100.0

@export var prism_lifetime: float = 8.0
@export var respawn_delay: float = 3.0

var active_prisms: Array[Node] = []
var cycle_running: bool = false

const PRISM_COLORS = [
	0, # RED
	1, # BLUE
	2, # GREEN
	3  # YELLOW
]

var corner_color_map: Array[int] = []


func _ready() -> void:
	randomize()
	generate_corner_color_map()
	start_prism_cycle()


func generate_corner_color_map() -> void:
	corner_color_map.clear()

	var colors = PRISM_COLORS.duplicate()
	colors.shuffle()

	for color in colors:
		corner_color_map.append(int(color))

	print("四個角落稜鏡顏色分配：", corner_color_map)


func start_prism_cycle() -> void:
	if cycle_running:
		return

	cycle_running = true

	while cycle_running and is_inside_tree():
		spawn_all_prisms()

		await get_tree().create_timer(prism_lifetime).timeout

		remove_all_prisms()

		await get_tree().create_timer(respawn_delay).timeout


func spawn_all_prisms() -> void:
	if prism_scene == null:
		print("尚未指定 prism_scene")
		return

	var scene_root := get_tree().current_scene

	if scene_root == null:
		print("找不到 current_scene，無法生成稜鏡場")
		return

	var areas = get_spawn_areas()

	for i in range(4):
		var prism = prism_scene.instantiate()

		if not (prism is Node2D):
			print("prism_scene 的根節點不是 Node2D，無法設定位置")
			prism.queue_free()
			continue

		var area_rect: Rect2 = areas[i]

		var random_x = randf_range(
			area_rect.position.x,
			area_rect.position.x + area_rect.size.x
		)

		var random_y = randf_range(
			area_rect.position.y,
			area_rect.position.y + area_rect.size.y
		)

		prism.global_position = Vector2(random_x, random_y)

		if prism.has_method("set_color_type"):
			prism.set_color_type(corner_color_map[i])

		scene_root.call_deferred("add_child", prism)

		if prism.has_method("set_lifetime"):
			prism.call_deferred("set_lifetime", prism_lifetime)

		active_prisms.append(prism)


func get_spawn_areas() -> Array[Rect2]:
	var center_x := (room_left + room_right) / 2.0
	var center_y := (room_top + room_bottom) / 2.0

	var left_min := room_left + margin_x
	var left_max := center_x - margin_x

	var right_min := center_x + margin_x
	var right_max := room_right - margin_x

	var top_min := room_top + margin_y
	var top_max := center_y - margin_y

	var bottom_min := center_y + margin_y
	var bottom_max := room_bottom - margin_y

	return [
		Rect2(
			Vector2(left_min, top_min),
			Vector2(left_max - left_min, top_max - top_min)
		),

		Rect2(
			Vector2(right_min, top_min),
			Vector2(right_max - right_min, top_max - top_min)
		),

		Rect2(
			Vector2(left_min, bottom_min),
			Vector2(left_max - left_min, bottom_max - bottom_min)
		),

		Rect2(
			Vector2(right_min, bottom_min),
			Vector2(right_max - right_min, bottom_max - bottom_min)
		)
	]


func remove_all_prisms() -> void:
	for prism in active_prisms:
		if is_instance_valid(prism):
			prism.call_deferred("queue_free")

	active_prisms.clear()


func stop_prism_cycle() -> void:
	cycle_running = false
	remove_all_prisms()
