extends Node2D

@onready var color_slots = [
	$Color1,
	$Color2,
	$Color3
]


func set_sequence(sequence: Array[int], current_index: int) -> void:
	for i in range(color_slots.size()):
		if i >= sequence.size():
			color_slots[i].visible = false
			continue

		color_slots[i].visible = true
		color_slots[i].color = get_color(sequence[i])

		if i < current_index:
			color_slots[i].modulate.a = 0.35
		else:
			color_slots[i].modulate.a = 1.0


func get_color(color_type: int) -> Color:
	match color_type:
		0:
			return Color.RED
		1:
			return Color.BLUE
		2:
			return Color.GREEN
		3:
			return Color.YELLOW

	return Color.WHITE
