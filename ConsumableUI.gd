extends Control

@onready var hp_potion_label: Label = $HPPotionLabel
@onready var stamina_potion_label: Label = $StaminaPotionLabel
@onready var mp_potion_label: Label = $MPPotionLabel
@onready var invincible_label: Label = $InvincibleLabel


func _process(_delta: float) -> void:
	update_ui()

func update_ui() -> void:
	hp_potion_label.text = "x " + str(Playerdata_Globle.hp_potion)
	stamina_potion_label.text = "x " + str(Playerdata_Globle.stamina_potion)
	mp_potion_label.text = "x " + str(Playerdata_Globle.mp_potion)
	invincible_label.text = "x " + str(Playerdata_Globle.invincible)
