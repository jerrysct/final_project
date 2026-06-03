# GamepadCursorManager.gd
extends Node

# 手把控制游標的速度（全域生效，可在這裡調整）
var gamepad_mouse_speed: float = 1000.0

func _physics_process(delta: float) -> void:
	# 偵測右搖桿的輸入
	var aim_dir := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	
	if aim_dir.length() > 0.1:
		# 取得目前滑鼠在視窗中的座標
		var current_mouse_pos := get_viewport().get_mouse_position()
		# 計算新的滑鼠位置
		var new_mouse_pos := current_mouse_pos + (aim_dir * gamepad_mouse_speed * delta)
		# 強制移動系統的滑鼠游標
		Input.warp_mouse(new_mouse_pos)

func _input(event: InputEvent) -> void:
	# 手把模擬滑鼠左鍵點擊（這樣在主選單、商城也能用手把點擊 UI 按鈕）
	if event.is_action_pressed("gamepad_click"):
		var mouse_event := InputEventMouseButton.new()
		mouse_event.button_index = MOUSE_BUTTON_LEFT
		mouse_event.pressed = true
		mouse_event.position = get_viewport().get_mouse_position()
		Input.parse_input_event(mouse_event)
		
	elif event.is_action_released("gamepad_click"):
		var mouse_event := InputEventMouseButton.new()
		mouse_event.button_index = MOUSE_BUTTON_LEFT
		mouse_event.pressed = false
		mouse_event.position = get_viewport().get_mouse_position()
		Input.parse_input_event(mouse_event)
