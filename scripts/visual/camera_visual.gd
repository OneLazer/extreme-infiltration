@tool
class_name CameraVisual
extends Node2D
## 监控守卫的外观（挂在 CameraGuard 下，@tool：编辑器里也能看到摄像头和激光朝向）。
## 球形外壳：贴墙一排底座 + 半圆罩，镜头在罩上朝监控方向偏，红色 LED 每秒闪一下。
## 激光：加色混合的 1px 红线，近端更亮、沿线流动的亮点、墙上落点一个小光斑；
## 开火时整条爆亮带白芯，擦过冲刺无敌的玩家时闪白。
## 编辑器里没有物理，激光画成 64px 的虚线，只表示方向。

const MOUNT_DIR := [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]
const ARMOR := [Color("#262540"), Color("#55577a"), Color("#73759a"), Color("#aeb0d0")]

var _t := 0.0
var _laser: Node2D


func _ready() -> void:
	_laser = Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_laser.material = mat
	_laser.draw.connect(_draw_laser)
	add_child(_laser, false, Node.INTERNAL_MODE_FRONT)
	_laser.show_behind_parent = false


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _laser:
		_laser.queue_redraw()


func _mount() -> int:
	var v = get_parent().get("mount") if get_parent() else null
	return int(v) if v != null else 2


func _look() -> Vector2:
	var v = get_parent().get("look_angle") if get_parent() else null
	return Vector2.from_angle(deg_to_rad(float(v) if v != null else 20.0))


func _normal() -> Vector2:
	return -MOUNT_DIR[_mount()]


func _alive() -> bool:
	if Engine.is_editor_hint():
		return true
	var g := get_parent() as CameraGuard
	return g != null and not g.dead


## 镜头（本地坐标），与 CameraGuard.eye_global 一致
func _eye() -> Vector2:
	return _normal() * 2.5 + _look() * 2.0


## 外壳像素：u 沿墙（-4..4），v 离墙（0 = 底座那排，往外 1..4 是半圆罩）
static func _in_dome(u: int, v: int) -> bool:
	if v < 0 or v > 4 or absi(u) > 4:
		return false
	if v == 0:
		return true
	return u * u + (v - 0.5) * (v - 0.5) <= 4.4 * 4.4


## 外壳坐标 (u, v) → 本地像素格左上角。按吸附方向旋转，轴对齐所以始终落在整像素上
func _cell(u: float, v: float) -> Vector2:
	var n := _normal()
	var t := Vector2(-n.y, n.x)
	return (t * u + n * (v + 0.5) - Vector2(0.5, 0.5)).floor()


func _px(u: float, v: float, c: Color) -> void:
	draw_rect(Rect2(_cell(u, v), Vector2.ONE), c)


func _draw() -> void:
	if not _alive():
		return
	var g: CameraGuard = null if Engine.is_editor_hint() else get_parent() as CameraGuard
	var shot := g.shot_flash if g else 0.0
	for v in 5:
		for u in range(-4, 5):
			if not _in_dome(u, v):
				continue
			var edge := not (_in_dome(u - 1, v) and _in_dome(u + 1, v) and _in_dome(u, v + 1))
			var c: Color = ARMOR[1]
			if v == 0:
				c = ARMOR[0] if absi(u) < 4 else ARMOR[2]     # 底座，两端螺栓
			elif edge:
				c = ARMOR[0]
			draw_rect(Rect2(_cell(u, v), Vector2.ONE), c)
	_px(-2, 3, ARMOR[3])         # 罩子高光
	_px(-1, 4, ARMOR[2])
	# 镜头：暗色镜框 + 发光镜片，跟着监控方向在罩上偏移
	var n := _normal()
	var t := Vector2(-n.y, n.x)
	var lk := _look()
	var lu := roundf(lk.dot(t) * 1.6)
	var lv := clampf(roundf(2.0 + lk.dot(n) * 1.6), 1.0, 4.0)
	for du in [-1, 0, 1]:
		for dv in [-1, 0, 1]:
			if _in_dome(int(lu) + du, int(lv) + dv) and int(lv) + dv > 0:
				_px(lu + du, lv + dv, Palette.N0)
	var lens := 1.1 + 0.15 * sin(_t * 5.0) + shot * 2.0
	_px(lu, lv, Palette.ALERT * Color(lens, lens, lens))
	# 状态灯：每秒闪 0.12 秒
	var led_on := fmod(_t, 1.0) < 0.12 or shot > 0.0
	_px(3, 1, Palette.ALERT * Color(1.3, 1.3, 1.3) if led_on else Color("#3a0d18"))


## 激光（加色混合）：底线 + 近端加亮 + 流动亮点 + 落点光斑；开火 / 擦过时爆亮
func _draw_laser() -> void:
	if not _alive():
		return
	var eye := _eye()
	var dir := _look()
	if Engine.is_editor_hint():
		var d := 0.0
		while d < 64.0:      # 编辑器：虚线表示方向
			_laser.draw_line(eye + dir * d, eye + dir * minf(d + 3.0, 64.0), _k(Palette.ALERT, 0.6), 1.0)
			d += 5.0
		return
	var g := get_parent() as CameraGuard
	var end := g.laser_end - g.global_position
	var length := (end - eye).length()
	var hot := g.shot_flash
	var gz := g.graze
	var flicker := 0.03 * sin(_t * 47.0) + 0.02 * sin(_t * 31.0)
	_laser.draw_line(eye, end, _k(Palette.ALERT, 0.3 + flicker + gz * 0.6 + hot * 1.2), 1.0)
	_laser.draw_line(eye, eye + dir * minf(6.0, length), _k(Palette.ALERT, 0.45), 1.0)
	if hot > 0.0 or gz > 0.0:   # 白芯
		_laser.draw_line(eye, end, _k(Color(1.0, 0.9, 0.95), maxf(hot * 1.6, gz * 0.9)), 1.0)
	var s := fmod(_t * 36.0, 8.0) + 3.0
	while s < length - 1.0:
		var fade := clampf(1.0 - s / 220.0, 0.35, 1.0)
		_laser.draw_rect(Rect2((eye + dir * s).floor(), Vector2.ONE), _k(Palette.ALERT, 0.5 * fade))
		s += 8.0
	var e := end.floor()
	var pulse := 0.75 + 0.25 * sin(_t * 9.0) + hot
	_laser.draw_rect(Rect2(e, Vector2.ONE), _k(Palette.ALERT, pulse))
	for v in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		_laser.draw_rect(Rect2(e + v, Vector2.ONE), _k(Palette.ALERT, 0.3 * pulse))


## 加色混合下只缩放 RGB，alpha 保持 1
static func _k(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, 1.0)
