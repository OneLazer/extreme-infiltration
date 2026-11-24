class_name JuiceDecals
extends Node2D
## 贴花层：机油溅痕、弹痕。排在墙体之后、实体之前，关卡重开即清空。
## 只记录像素点，变化时重画一次。

const MAX_PX := 1500

var _px: Array = []   # [Vector2 位置, Color]


## 液滴撞到墙面：在碰撞点附近留 2~5 个像素，偶尔带一点紫色反光
func splat(at: Vector2, vel: Vector2, size: float) -> void:
	var base := (at + vel.normalized()).round()   # 往墙里挪 1px，贴在墙面上
	var n := randi_range(2, 4) + int(size)
	var along := Vector2(1, 0) if absf(vel.y) > absf(vel.x) else Vector2(0, 1)
	for i in n:
		var off := along * randi_range(-2, 2) + vel.normalized().round() * randi_range(0, 1)
		_put(base + off, Palette.OIL if randf() > 0.15 else Palette.OIL_SHEEN)
	queue_redraw()


## 弹痕：撞击点一圈焦黑，中心 1px 暗红余温（只是颜色，不发光）
func scorch(at: Vector2, normal: Vector2) -> void:
	var c := (at - normal * 0.5).round()
	for d in [Vector2.ZERO, Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		_put(c + d, Color(0.05, 0.04, 0.09, 0.85))
	_put(c, Color(0.35, 0.12, 0.12))
	queue_redraw()


func _put(p: Vector2, c: Color) -> void:
	if _px.size() >= MAX_PX:
		_px.pop_front()
	_px.append([p, c])


func _draw() -> void:
	for e in _px:
		draw_rect(Rect2(e[0], Vector2.ONE), e[1])
