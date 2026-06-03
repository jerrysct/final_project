extends Node2D

var is_parry_preparing := false
var is_absorb_preparing := false
var is_aiming := false
var bounce_collision: CollisionShape2D = null

# 接收玩家腳本傳來的滑鼠瞄準角度
var aim_angle: float = 0.0

# 接收玩家腳本傳來的大小
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
	queue_redraw()

func _draw() -> void:
	# 1. 決定圈圈的大小 (直接採用從玩家腳本傳過來的外圈大小 outer_radius)
	var radius: float = outer_radius
	
	# 定義半圓的起點與終點角度 (瞄準方向的正負 90 度)
	var start_angle: float = aim_angle - (PI / 2.0)
	var end_angle: float = aim_angle + (PI / 2.0)
	var point_count: int = 64 # 弧線的圓滑度
			
	# 2. 瞬間反彈 (Parry)：區分內圈 (傷害減半) 與外圈 (正常反彈)
	if is_parry_preparing:
		if radius > inner_radius:
			var mid_radius = (inner_radius + radius) / 2.0
			var thickness = radius - inner_radius
			
			# 【新增】畫內圈範圍 (傷害減半)：實心半圓 (用黃色調區分)
			_draw_pie_slice(inner_radius, start_angle, end_angle, Color(1.0, 1.0, 0.0, 0.2))
			
			# 畫外圈範圍 (正常反彈)：半甜甜圈形狀 (中空半圓，維持白色)
			draw_arc(Vector2.ZERO, mid_radius, start_angle, end_angle, point_count, Color(1.0, 1.0, 1.0, 0.15), thickness, true)
			
			# 畫邊緣線，讓視覺更清晰
			draw_arc(Vector2.ZERO, radius, start_angle, end_angle, point_count, Color(1.0, 1.0, 1.0, 0.8), 3.0, true)        # 外圈線 (白)
			draw_arc(Vector2.ZERO, inner_radius, start_angle, end_angle, point_count, Color(1.0, 1.0, 0.0, 0.8), 3.0, true)  # 內圈線 (黃)
			
			# 畫兩側的封口直線 - 針對外圍甜甜圈
			var inner1 = Vector2(cos(start_angle), sin(start_angle)) * inner_radius
			var outer1 = Vector2(cos(start_angle), sin(start_angle)) * radius
			draw_line(inner1, outer1, Color(1.0, 1.0, 1.0, 0.8), 3.0, true)
			
			var inner2 = Vector2(cos(end_angle), sin(end_angle)) * inner_radius
			var outer2 = Vector2(cos(end_angle), sin(end_angle)) * radius
			draw_line(inner2, outer2, Color(1.0, 1.0, 1.0, 0.8), 3.0, true)
			
			# 【新增】畫兩側的封口直線 - 針對內圍半圓
			_draw_pie_slice_lines(inner_radius, start_angle, end_angle, Color(1.0, 1.0, 0.0, 0.8), 3.0)
			
		else:
			# 防呆：如果外圈半徑小於等於內圈半徑，畫實心半圓
			_draw_pie_slice(radius, start_angle, end_angle, Color(1.0, 1.0, 1.0, 0.15))
			draw_arc(Vector2.ZERO, radius, start_angle, end_angle, point_count, Color(1.0, 1.0, 1.0, 0.8), 3.0, true)
			_draw_pie_slice_lines(radius, start_angle, end_angle, Color(1.0, 1.0, 1.0, 0.8), 3.0)

	# 3. 吸收子彈 (Absorb)：向內收縮的動態半圓波紋
	if is_absorb_preparing:
		# 畫外圍底色 (實心半圓)
		_draw_pie_slice(radius, start_angle, end_angle, Color(0.0, 0.6, 1.0, 0.2))
		draw_arc(Vector2.ZERO, radius, start_angle, end_angle, point_count, Color(0.0, 0.8, 1.0, 0.7), 3.0, true)
		_draw_pie_slice_lines(radius, start_angle, end_angle, Color(0.0, 0.8, 1.0, 0.7), 3.0)
		
		# 畫向內收縮的動畫半圓環
		for i in range(ABSORB_RING_COUNT):
			var progress = fmod(_absorb_anim_time + (float(i) / float(ABSORB_RING_COUNT)), 1.0)
			var current_radius = radius * (1.0 - progress)
			var alpha = sin(progress * PI) 
			
			if current_radius > 1.0:
				draw_arc(Vector2.ZERO, current_radius, start_angle, end_angle, point_count/2, Color(0.0, 0.8, 1.0, alpha * 0.8), 2.0, true)

	# 4. 蓄力瞄準 (Aiming)：橘紅色呼吸閃爍半圓圈
	if is_aiming:
		var pulse = (sin(Time.get_ticks_msec() * 0.01) * 0.08) + 1.0
		var current_radius = radius * pulse
		_draw_pie_slice(current_radius, start_angle, end_angle, Color(1.0, 0.3, 0.1, 0.15))
		draw_arc(Vector2.ZERO, current_radius, start_angle, end_angle, point_count, Color(1.0, 0.7, 0.0, 0.8), 3.0, true)
		_draw_pie_slice_lines(current_radius, start_angle, end_angle, Color(1.0, 0.7, 0.0, 0.8), 3.0)


# ==========================================
# 輔助繪圖函式：畫實心扇形 (半圓底色)
# ==========================================
func _draw_pie_slice(radius: float, start_angle: float, end_angle: float, color: Color) -> void:
	var points = PackedVector2Array()
	points.append(Vector2.ZERO) # 中心點
	var nb_points = 32
	for i in range(nb_points + 1):
		var t = float(i) / nb_points
		var current_angle = lerpf(start_angle, end_angle, t)
		points.append(Vector2(cos(current_angle), sin(current_angle)) * radius)
	draw_polygon(points, PackedColorArray([color]))


# ==========================================
# 輔助繪圖函式：畫扇形的兩側邊緣直線
# ==========================================
func _draw_pie_slice_lines(radius: float, start_angle: float, end_angle: float, color: Color, width: float) -> void:
	var p1 = Vector2(cos(start_angle), sin(start_angle)) * radius
	var p2 = Vector2(cos(end_angle), sin(end_angle)) * radius
	draw_line(Vector2.ZERO, p1, color, width, true)
	draw_line(Vector2.ZERO, p2, color, width, true)
