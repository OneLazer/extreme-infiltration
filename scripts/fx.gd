class_name Fx
extends Node2D
## 白盒特效：射线残影、碎裂方块。全部用 _draw 绘制，无需美术资源。

enum Kind { TRACE, BURST }

var kind := Kind.TRACE
var color := Color.WHITE
var life := 0.0
var max_life := 0.15
var _a := Vector2.ZERO
var _b := Vector2.ZERO
var _parts: Array = []   # [位置, 速度]


static func trace(parent: Node, a: Vector2, b: Vector2, c: Color) -> void:
	var n := Fx.new()
	n.kind = Kind.TRACE
	n.color = c
	n._a = a
	n._b = b
	n.max_life = 0.15
	parent.add_child(n)


static func burst(parent: Node, at: Vector2, c: Color, count: int) -> void:
	var n := Fx.new()
	n.kind = Kind.BURST
	n.color = c
	n.max_life = 0.45
	n.position = at
	for i in count:
		var v := Vector2.from_angle(randf() * TAU) * randf_range(40.0, 110.0)
		n._parts.append([Vector2.ZERO, v])
	parent.add_child(n)


func _process(delta: float) -> void:
	life += delta
	if life >= max_life:
		queue_free()
		return
	for p in _parts:
		p[0] += p[1] * delta
		p[1] *= 0.9
	queue_redraw()


func _draw() -> void:
	var c := color
	c.a = 1.0 - life / max_life
	if kind == Kind.TRACE:
		draw_line(_a - position, _b - position, c, 1.0)
	else:
		for p in _parts:
			draw_rect(Rect2(p[0] - Vector2.ONE, Vector2(2, 2)), c)
