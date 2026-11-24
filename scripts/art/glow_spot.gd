@tool
class_name GlowSpot
extends Node2D
## 加色光斑：三圈硬色阶的椭圆光（售货机、屏幕、霓虹招牌周围的光晕）。
## 不是真实光源，只往画面上加亮度；强度保持在 1 以下，不会触发辉光。

@export var radius := 20.0:
	set(v):
		radius = v
		queue_redraw()
@export var squash := 0.8                ## 纵向压扁（<1 = 贴地的扁光）
@export var color := Color(1.0, 0.31, 0.6):
	set(v):
		color = v
		queue_redraw()
@export var strength := 0.2
@export var pulse := 0.0                 ## 呼吸幅度（0 = 不变）

var _t := 0.0


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat


func _process(delta: float) -> void:
	if pulse > 0.0 and not Engine.is_editor_hint():
		_t += delta
		queue_redraw()


func _draw() -> void:
	var k := strength * (1.0 + pulse * sin(_t * 3.0))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, squash))
	for n in 3:
		var c := color * (k / 3.0)
		c.a = 1.0
		draw_circle(Vector2.ZERO, radius * (1.0 - n * 0.3), c, true, -1.0, false)
