class_name VisionCone
extends Node2D
## 守卫视野的表现：加色混合的传感锥。很淡的底色 + 亮边 + 向外扫的点阵波纹。
## 锁定后锥收成一条红色激光瞄准线，末端一个激光点。判定都在 GroundGuard 里，这里只画。

@export var fill := 0.05
@export var edge := 0.45
@export var scan := 0.35
@export var scan_speed := 46.0       ## 扫描波纹外扩速度（px/秒）
@export var scan_gap := 13.0

var _g: Node
var _t := 0.0


func _ready() -> void:
	_g = get_parent()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if _g == null or _g.dead:
		return
	var pts: PackedVector2Array = _g.cone_points()
	var locked: bool = _g.is_locked()
	var base: Color = Palette.VISION_ALERT if locked else Palette.VISION
	if pts.size() >= 3:
		draw_colored_polygon(pts, _k(base, fill))
		var e := _k(base, edge)
		draw_polyline(pts.slice(1), e, 1.0)
		draw_line(pts[0], pts[1], e, 1.0)
		draw_line(pts[0], pts[pts.size() - 1], e, 1.0)
		# 扫描点阵：每条射线上，在当前波纹距离处点一个像素（被墙截断的射线不画）
		var eye := pts[0]
		var d0 := fmod(_t * scan_speed, scan_gap)
		var d := d0 + 4.0
		while d < 200.0:
			var fade := 1.0 - d / 120.0
			if fade <= 0.0:
				break
			for i in range(1, pts.size()):
				var ray := pts[i] - eye
				if ray.length() > d:
					draw_rect(Rect2((eye + ray.normalized() * d).round(), Vector2.ONE), _k(base, scan * fade))
			d += scan_gap
	var f: float = _g.focus()
	if locked and f > 0.02:
		var eye2 := Vector2(0, -3)
		var end: Vector2 = _g.aim_end()
		draw_line(eye2, end, _k(Palette.ALERT, 0.35 * f), 1.0)
		draw_rect(Rect2(end.round() - Vector2.ONE, Vector2(2, 2)), _k(Palette.ALERT, 0.8 * f))


## 加色混合下只缩放 RGB，alpha 保持 1（否则强度会被平方）
static func _k(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, 1.0)
