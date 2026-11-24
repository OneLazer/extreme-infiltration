@tool
class_name LightCone
extends Node2D
## 吊灯光锥：三层嵌套梯形，加色混合，像素风的硬色阶（不做平滑渐变）。
## 光锥里飘着几粒灰尘，只在运行时出现。原点在灯管下沿。

@export var length := 150.0:
	set(v):
		length = v
		queue_redraw()
@export var top_half := 7.0
@export var bottom_half := 34.0
@export var color := Color(0.56, 0.89, 1.0):
	set(v):
		color = v
		queue_redraw()
@export var strength := 0.16
@export var motes := 5

var _motes: Array = []   # [位置, 速度, 相位]
var _t := 0.0


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	if not Engine.is_editor_hint():
		var rng := RandomNumberGenerator.new()
		rng.seed = int(global_position.x * 13.0 + global_position.y)
		for i in motes:
			var y := rng.randf_range(10.0, length)
			_motes.append([Vector2(rng.randf_range(-1.0, 1.0) * _half(y) * 0.7, y),
				Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-3.0, 3.0)), rng.randf() * TAU])


func _half(y: float) -> float:
	return lerpf(top_half, bottom_half, clampf(y / length, 0.0, 1.0))


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _motes.is_empty():
		return
	_t += delta
	for m in _motes:
		m[0] += m[1] * delta + Vector2(sin(_t * 0.7 + m[2]) * 1.5, 0.0) * delta
		if m[0].y < 6.0 or m[0].y > length - 4.0 or absf(m[0].x) > _half(m[0].y):
			m[0] = Vector2(randf_range(-0.5, 0.5) * _half(length * 0.5), randf_range(20.0, length - 10.0))
	queue_redraw()


func _draw() -> void:
	var seg := 4
	for s in seg:
		var y0 := length * s / seg
		var y1 := length * (s + 1) / seg
		var fade := 1.0 - 0.55 * (float(s) / (seg - 1))
		for n in 3:
			var w := 1.0 - n * 0.33
			var c := color * (strength / 3.0 * fade * (1.6 if n == 2 else 1.0))
			c.a = 1.0
			var h0 := _half(y0) * w
			var h1 := _half(y1) * w
			draw_colored_polygon(PackedVector2Array([
				Vector2(-h0, y0).round(), Vector2(h0, y0).round(), Vector2(h1, y1).round(), Vector2(-h1, y1).round()]), c)
	for m in _motes:
		var a := 0.5 + 0.5 * sin(_t * 2.0 + m[2])
		draw_rect(Rect2(m[0].round(), Vector2.ONE), color * (0.35 * a))
