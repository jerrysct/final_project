extends Node

@export var pattern_bullet_scene: PackedScene
@export var debug_enabled: bool = true

@export var phase2_return_weight: float = 55.0
@export var phase2_orbit_weight: float = 45.0

@export var phase3_return_weight: float = 30.0
@export var phase3_double_ring_weight: float = 20.0
@export var phase3_gap_ring_weight: float = 25.0
@export var phase3_orbit_weight: float = 25.0

@export var return_bullet_count: int = 8
@export var return_out_speed: float = 150.0
@export var return_back_speed: float = 190.0
@export var return_out_time: float = 0.75
@export var return_pause_time: float = 0.25

@export var double_ring_count: int = 10
@export var double_ring_inner_speed: float = 140.0
@export var double_ring_outer_speed: float = 210.0
@export var double_ring_angle_offset_degrees: float = 18.0
@export var double_ring_second_delay: float = 0.18

@export var gap_ring_total_slots: int = 14
@export var gap_ring_gap_slots: int = 3
@export var gap_ring_speed: float = 170.0

@export var orbit_bullet_count: int = 6
@export var orbit_radius: float = 70.0
@export var orbit_time: float = 0.8
@export var orbit_angular_speed: float = 6.0
@export var orbit_release_speed: float = 180.0

var boss: Node2D = null


func setup(boss_node: Node2D) -> void:
	boss = boss_node

	if debug_enabled:
		print("Boss2SpecialBulletPatterns setup complete")


func execute_random_pattern() -> void:
	if boss == null or not is_instance_valid(boss):
		return

	var phase: int = 1

	if boss.has_method("get_current_phase"):
		phase = boss.get_current_phase()
	elif boss.has_method("get_hp_ratio"):
		var hp_ratio: float = boss.get_hp_ratio()

		if hp_ratio > 0.75:
			phase = 1
		elif hp_ratio > 0.5:
			phase = 2
		else:
			phase = 3

	if phase <= 1:
		return

	var pattern_name: String = _roll_pattern_name(phase)

	if debug_enabled:
		print("Boss2 special pattern = ", pattern_name)

	if pattern_name == "return":
		_shoot_return_bullets()
		return

	if pattern_name == "double_ring":
		await _shoot_double_ring()
		return

	if pattern_name == "gap_ring":
		_shoot_gap_ring()
		return

	if pattern_name == "orbit":
		_shoot_orbit_bullets()
		return


func _roll_pattern_name(phase: int) -> String:
	var entries: Array[Dictionary] = []

	if phase == 2:
		entries.append({"name": "return", "weight": phase2_return_weight})
		entries.append({"name": "orbit", "weight": phase2_orbit_weight})
	else:
		entries.append({"name": "return", "weight": phase3_return_weight})
		entries.append({"name": "double_ring", "weight": phase3_double_ring_weight})
		entries.append({"name": "gap_ring", "weight": phase3_gap_ring_weight})
		entries.append({"name": "orbit", "weight": phase3_orbit_weight})

	var total_weight: float = 0.0

	for entry in entries:
		total_weight += float(entry["weight"])

	if total_weight <= 0.0:
		return "return"

	var roll: float = randf() * total_weight
	var current: float = 0.0

	for entry in entries:
		current += float(entry["weight"])

		if roll <= current:
			return String(entry["name"])

	return "return"


func _shoot_return_bullets() -> void:
	if pattern_bullet_scene == null:
		if debug_enabled:
			print("pattern_bullet_scene not assigned")
		return

	for i in range(return_bullet_count):
		var angle: float = TAU * float(i) / float(return_bullet_count)
		var fire_dir: Vector2 = Vector2.RIGHT.rotated(angle)

		var bullet: Node = _spawn_pattern_bullet()

		if bullet == null:
			continue

		if bullet.has_method("setup_return"):
			bullet.setup_return(
				boss.global_position,
				fire_dir,
				boss,
				return_out_speed,
				return_back_speed,
				return_out_time,
				return_pause_time
			)

	if debug_enabled:
		print("Boss2 return bullets count = ", return_bullet_count)


func _shoot_double_ring() -> void:
	if pattern_bullet_scene == null:
		if debug_enabled:
			print("pattern_bullet_scene not assigned")
		return

	for i in range(double_ring_count):
		var angle: float = TAU * float(i) / float(double_ring_count)
		var fire_dir: Vector2 = Vector2.RIGHT.rotated(angle)

		var bullet: Node = _spawn_pattern_bullet()

		if bullet != null and bullet.has_method("setup_straight"):
			bullet.setup_straight(
				boss.global_position,
				fire_dir,
				double_ring_inner_speed
			)

	var completed: bool = await _safe_wait(double_ring_second_delay)

	if not completed:
		return

	var offset_rad: float = deg_to_rad(double_ring_angle_offset_degrees)

	for i in range(double_ring_count):
		var angle: float = TAU * float(i) / float(double_ring_count) + offset_rad
		var fire_dir: Vector2 = Vector2.RIGHT.rotated(angle)

		var bullet: Node = _spawn_pattern_bullet()

		if bullet != null and bullet.has_method("setup_straight"):
			bullet.setup_straight(
				boss.global_position,
				fire_dir,
				double_ring_outer_speed
			)

	if debug_enabled:
		print("Boss2 double ring count = ", double_ring_count)


func _shoot_gap_ring() -> void:
	if pattern_bullet_scene == null:
		if debug_enabled:
			print("pattern_bullet_scene not assigned")
		return

	var total_slots: int = max(4, gap_ring_total_slots)
	var gap_slots: int = clamp(gap_ring_gap_slots, 1, total_slots - 1)
	var gap_start: int = randi_range(0, total_slots - 1)

	for i in range(total_slots):
		var in_gap: bool = false

		for g in range(gap_slots):
			var gap_index: int = (gap_start + g) % total_slots

			if i == gap_index:
				in_gap = true
				break

		if in_gap:
			continue

		var angle: float = TAU * float(i) / float(total_slots)
		var fire_dir: Vector2 = Vector2.RIGHT.rotated(angle)

		var bullet: Node = _spawn_pattern_bullet()

		if bullet != null and bullet.has_method("setup_straight"):
			bullet.setup_straight(
				boss.global_position,
				fire_dir,
				gap_ring_speed
			)

	if debug_enabled:
		print("Boss2 gap ring slots = ", total_slots, " gap = ", gap_slots)


func _shoot_orbit_bullets() -> void:
	if pattern_bullet_scene == null:
		if debug_enabled:
			print("pattern_bullet_scene not assigned")
		return

	for i in range(orbit_bullet_count):
		var angle: float = TAU * float(i) / float(orbit_bullet_count)

		var bullet: Node = _spawn_pattern_bullet()

		if bullet != null and bullet.has_method("setup_orbit"):
			bullet.setup_orbit(
				boss,
				angle,
				orbit_radius,
				orbit_time,
				orbit_angular_speed,
				orbit_release_speed
			)

	if debug_enabled:
		print("Boss2 orbit bullets count = ", orbit_bullet_count)


func _spawn_pattern_bullet() -> Node:
	if pattern_bullet_scene == null:
		return null

	if boss == null or not is_instance_valid(boss):
		return null

	var spawn_parent: Node = _get_spawn_parent()

	if spawn_parent == null:
		return null

	var bullet: Node = pattern_bullet_scene.instantiate()
	spawn_parent.add_child(bullet)
	return bullet


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
