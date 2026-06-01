extends Node2D

var is_parry_preparing := false
var is_absorb_preparing := false
var is_aiming := false
var bounce_collision: CollisionShape2D = null

# 【新增】接收玩家腳本傳來的大小，預設值對應你原本的設定 (100與200)
var inner_radius: float = 100.0
var outer_radius: float = 200.0

var _absorb_anim_time: float = 0.0
const ABSORB_RING_COUNT := 4
const ABSORB_ANIM_SPEED := 1.8

func _process(delta: float) -> void:
	# 處理吸收動畫的時間推移
	if is_absorb_preparing:
		_absorb_anim_time += delta * ABSORB_ANIM_SPEED
	elif _absorb_anim_time != 0.0:
		_absorb_anim_time = 0.0
		
	# 不論當下有沒有按按鍵，每幀都呼叫重繪
	# 這樣才能確保動畫會動，且「放開按鍵時圈圈會立刻消失」
	queue_redraw()

func _draw() -> void:
	# 1. 決定圈圈的大小 (直接採用從玩家腳本傳過來的外圈大小 outer_radius)
	var radius: float = outer_radius
			
	# 2. 瞬間反彈 (Parry)：改為甜甜圈形狀 (中空圓)
	if is_parry_preparing:
		if radius > inner_radius:
			var mid_radius = (inner_radius + radius) / 2.0
			var thickness = radius - inner_radius
			
			# 畫甜甜圈半透明本體 (利用極粗的圓弧)
			draw_arc(Vector2.ZERO, mid_radius, 0.0, TAU, 64, Color(1.0, 1.0, 1.0, 0.15), thickness, true)
			
			# 畫邊緣線，讓視覺更清晰
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(1.0, 1.0, 1.0, 0.8), 3.0, true)       # 外圈線
			draw_arc(Vector2.ZERO, inner_radius, 0.0, TAU, 64, Color(1.0, 1.0, 1.0, 0.8), 3.0, true) # 內圈線
		else:
			# 防呆：如果外圈半徑小於等於內圈半徑，就退回原本的畫法
			draw_circle(Vector2.ZERO, radius, Color(1.0, 1.0, 1.0, 0.15))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(1.0, 1.0, 1.0, 0.8), 3.0, true)

	# 3. 吸收子彈 (Absorb)：向內收縮的動態波紋圈
	if is_absorb_preparing:
		# 畫外圍底色
		draw_circle(Vector2.ZERO, radius, Color(0.0, 0.6, 1.0, 0.2))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(0.0, 0.8, 1.0, 0.7), 3.0, true)
		
		# 畫向內收縮的動畫圓環
		for i in range(ABSORB_RING_COUNT):
			# 計算每個環的進度 (0.0 ~ 1.0 不斷循環)
			var progress = fmod(_absorb_anim_time + (float(i) / float(ABSORB_RING_COUNT)), 1.0)
			# 讓半徑從最大慢慢縮小到 0
			var current_radius = radius * (1.0 - progress)
			# 根據進度計算透明度，讓波紋平滑淡入淡出
			var alpha = sin(progress * PI) 
			
			if current_radius > 1.0:
				draw_arc(Vector2.ZERO, current_radius, 0.0, TAU, 32, Color(0.0, 0.8, 1.0, alpha * 0.8), 2.0, true)

	# 4. 蓄力瞄準 (Aiming)：橘紅色呼吸閃爍圈
	if is_aiming:
		var pulse = (sin(Time.get_ticks_msec() * 0.01) * 0.08) + 1.0
		draw_circle(Vector2.ZERO, radius * pulse, Color(1.0, 0.3, 0.1, 0.15))
		draw_arc(Vector2.ZERO, radius * pulse, 0.0, TAU, 64, Color(1.0, 0.7, 0.0, 0.8), 3.0, true)
