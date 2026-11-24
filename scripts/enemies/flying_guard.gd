extends Guard
## 飞行守卫：悬停不动，不攻击。碰到玩家仍会致死。
## 表现：旋翼两帧交替、上下轻微浮动、黄色独眼发光。

const SHEET := preload("res://assets/chars/drone.png")
const SIL := preload("res://assets/chars/drone_sil.png")
const FRAME_OFFSET := Vector2(-8, -6)

var _phase := 0.0


func _ready() -> void:
	super()
	_phase = fmod(global_position.x * 0.05, TAU)


func _burst_color() -> Color:
	return Palette.FLYER


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _bob() -> Vector2:
	return Vector2(0, roundf(sin(_t * 2.4 + _phase) * 1.2))


func _draw() -> void:
	var f := int(_t * 16.0) % 2
	var o := FRAME_OFFSET + _bob()
	draw_texture_rect_region(SHEET, Rect2(o, Vector2(16, 12)), Rect2(f * 16, 0, 16, 12))
	# 独眼（HDR）：中间两格亮、两边暗
	draw_rect(Rect2(o + Vector2(7, 5), Vector2(2, 1)), Palette.FLYER)
	draw_rect(Rect2(o + Vector2(6, 5), Vector2(1, 1)), Palette.FLYER * Color(0.6, 0.6, 0.6))
	draw_rect(Rect2(o + Vector2(9, 5), Vector2(1, 1)), Palette.FLYER * Color(0.6, 0.6, 0.6))


func _silhouette() -> Dictionary:
	return {"tex": SIL, "region": Rect2(int(_t * 16.0) % 2 * 16, 0, 16, 12), "offset": FRAME_OFFSET + _bob(), "flip": false}
