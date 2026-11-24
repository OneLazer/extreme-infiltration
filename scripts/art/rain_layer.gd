@tool
class_name RainLayer
extends Node2D
## 窗外的雨：斜向细线，屏幕空间循环。放在 Parallax2D 里，跟随视差。

@export var area := Vector2(480, 180)
@export var count := 70
@export var speed := Vector2(-40.0, 260.0)
@export var color := Color(0.3, 0.45, 0.8, 0.35)

var _drops: Array = []   # [位置, 长度, 速度倍率]


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	for i in count:
		_drops.append([Vector2(rng.randf() * area.x, rng.randf() * area.y), rng.randi_range(3, 6), rng.randf_range(0.7, 1.2)])


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	for d in _drops:
		d[0] += speed * d[2] * delta
		if d[0].y > area.y:
			d[0].y -= area.y + 6.0
		d[0].x = fposmod(d[0].x, area.x)
	queue_redraw()


func _draw() -> void:
	var dir := speed.normalized()
	for d in _drops:
		var p: Vector2 = d[0].round()
		draw_line(p, (p - dir * d[1]).round(), color * Color(1, 1, 1, d[2] * 0.8), 1.0)
