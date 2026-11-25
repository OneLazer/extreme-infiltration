class_name MenuDrone
extends Node2D
## 主菜单背景里巡逻的无人机：每隔十几秒从右往左飞过，探照灯光锥朝下来回扫。
## 只是布景，没有玩法。光锥用加色混合（不进辉光），独眼用 HDR 琥珀色。

const SHEET := preload("res://assets/chars/drone.png")

@export var y_base := 64.0
@export var speed := 26.0
@export var interval := 16.0

var _t := 0.0
var _x := 380.0
var _wait := 3.0
var _cone: Node2D


func _ready() -> void:
	_cone = Cone.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_cone.material = mat
	_cone.show_behind_parent = true
	add_child(_cone)


func _process(delta: float) -> void:
	_t += delta
	if _wait > 0.0:
		_wait -= delta
		visible = false
		return
	visible = true
	_x -= speed * delta
	if _x < -60.0:
		_x = 380.0
		_wait = interval
	position = Vector2(roundf(_x), roundf(y_base + sin(_t * 1.7) * 3.0))
	(_cone as Cone).angle = PI * 0.5 + sin(_t * 0.8) * 0.45
	_cone.queue_redraw()
	queue_redraw()


func _draw() -> void:
	var f := int(_t * 16.0) % 2
	draw_set_transform(Vector2.ZERO, -0.08)       # 往前飞，机身前倾一点
	draw_texture_rect_region(SHEET, Rect2(Vector2(-8, -6), Vector2(16, 12)), Rect2(f * 16, 0, 16, 12))
	draw_rect(Rect2(-1, -1, 2, 1), Palette.FLYER)
	draw_rect(Rect2(-2, -1, 1, 1), Palette.FLYER * Color(0.6, 0.6, 0.6))
	draw_rect(Rect2(1, -1, 1, 1), Palette.FLYER * Color(0.6, 0.6, 0.6))
	draw_set_transform(Vector2.ZERO)


## 探照灯：三层硬色阶的扇形（与关卡里的吊灯光锥同一画法）
class Cone extends Node2D:
	var angle := PI * 0.5

	func _draw() -> void:
		var steps := [[0.11, 0.05], [0.075, 0.07], [0.045, 0.1]]
		for s in steps:
			var half: float = s[0]
			var pts := PackedVector2Array([Vector2.ZERO])
			for i in 9:
				var a: float = angle - half * 2.0 + half * 4.0 * i / 8.0
				pts.append(Vector2(cos(a), sin(a)) * 120.0)
			var k: float = s[1]
			draw_colored_polygon(pts, Color(Palette.VISION.r * k, Palette.VISION.g * k, Palette.VISION.b * k, 1.0))
