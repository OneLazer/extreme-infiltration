class_name VisionCone
extends Node2D
## 守卫视野的表现：加色混合的传感锥。很淡的底色 + 亮边 + 向外扫的点阵波纹。
## 巡逻暖黄、搜索橙、锁定红。半角 180（无人机）时是一整圈，扫描点阵变成向外扩的同心环。
## 锁定后锥收成一条红色激光瞄准线，末端一个激光点。判定都在 Guard 里，这里只画。

@export var fill := 0.05
@export var edge := 0.45
@export var scan := 0.35
@export var scan_speed := 46.0       ## 扫描波纹外扩速度（px/秒）
@export var scan_gap := 13.0

var _g: Guard
var _t := 0.0


func _ready() -> void:
	_g = get_parent() as Guard
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if _g == null or _g.dead:
		return
	var pts := _g.cone_points()
	var mode := _g.vision_mode()
	var base: Color = [Palette.VISION, Palette.VISION_SEARCH, Palette.VISION_ALERT][mode]
	if pts.size() >= 3:
		var eye := pts[0]
		var e := _k(base, edge)
		# 逐个三角形填充：一整圈时首尾两条射线重合，整体多边形三角化会失败
		var fc := _k(base, fill)
		for i in range(1, pts.size() - 1):
			draw_colored_polygon(PackedVector2Array([eye, pts[i], pts[i + 1]]), fc)
		draw_polyline(pts.slice(1), e, 1.0)
		if not _g.cone_full():
			draw_line(eye, pts[1], e, 1.0)
			draw_line(eye, pts[pts.size() - 1], e, 1.0)
		_draw_scan(pts, base)
	var f := _g.focus()
	if _g.is_locked() and f > 0.02:
		var end := _g.aim_end()
		# 快满条时瞄准线闪烁加快、变亮
		var hot := clampf((_g.alert - 0.5) * 2.0, 0.0, 1.0)
		var blink := 1.0 if hot <= 0.0 or fmod(_t, 0.16 - hot * 0.08) < 0.06 else 0.55
		draw_line(_g.eye(), end, _k(Palette.ALERT, (0.35 + hot * 0.3) * f * blink), 1.0)
		draw_rect(Rect2(end.round() - Vector2.ONE, Vector2(2, 2)), _k(Palette.ALERT, 0.8 * f))


## 扫描点阵：每条射线上，在当前波纹距离处点一个像素（被墙截断的射线不画）
func _draw_scan(pts: PackedVector2Array, base: Color) -> void:
	var eye := pts[0]
	var d := fmod(_t * scan_speed, scan_gap) + 4.0
	while d < 200.0:
		var fade := 1.0 - d / 120.0
		if fade <= 0.0:
			break
		for i in range(1, pts.size()):
			var ray := pts[i] - eye
			if ray.length() > d:
				draw_rect(Rect2((eye + ray.normalized() * d).round(), Vector2.ONE), _k(base, scan * fade))
		d += scan_gap


## 加色混合下只缩放 RGB，alpha 保持 1（否则强度会被平方）
static func _k(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, 1.0)
