extends Node2D

var color_slots: Array = []


func _ready() -> void:
	find_color_slots()


func find_color_slots() -> void:
	color_slots.clear()
	
	var color1 = get_node_or_null("Color1")
	var color2 = get_node_or_null("Color2")
	var color3 = get_node_or_null("Color3")
	
	if color1 != null:
		color_slots.append(color1)
	if color2 != null:
		color_slots.append(color2)
	if color3 != null:
		color_slots.append(color3)


func set_sequence(sequence: Array, current_index: int) -> void:
	if color_slots.is_empty():
		find_color_slots()
	
	if sequence == null:
		return
	
	if color_slots.is_empty():
		print("SequenceUI 沒有找到 Color1 / Color2 / Color3")
		return
	
	for i in range(color_slots.size()):
		if i >= sequence.size():
			color_slots[i].visible = false
			continue
		
		color_slots[i].visible = true
		color_slots[i].color = get_color(int(sequence[i]))
		
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
