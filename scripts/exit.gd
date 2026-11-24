class_name LevelExit
extends Area2D
## 出口。所有守卫被清除后解锁，玩家站入即通关。

var _open := false


func _physics_process(_delta: float) -> void:
	var lvl := Game.level
	var p := Game.player
	var open_now := lvl != null and lvl.enemies_left <= 0
	if open_now != _open:
		_open = open_now
		queue_redraw()
	if _open and p and not p.dead and overlaps_body(p):
		lvl.complete()


func _draw() -> void:
	var c := Palette.EXIT_OPEN if _open else Palette.EXIT_LOCKED
	draw_rect(Rect2(-4, -8, 8, 16), c, false, 1.0)
	if _open:
		draw_rect(Rect2(-2, -6, 4, 12), c)
