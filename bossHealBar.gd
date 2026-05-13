extends ProgressBar

func setup(max_hp: int) -> void:
	max_value = max_hp
	value = max_hp


func update_hp(current_hp: int) -> void:
	value = current_hp
