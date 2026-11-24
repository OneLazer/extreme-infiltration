class_name LevelExit
extends Area2D
## 出口：电梯门。所有守卫被清除后解锁（指示灯红 → 绿，门打开透出暖光），玩家站入即通关。

const PROPS := preload("res://assets/props/props.png")
const EMIT := preload("res://assets/props/props_emit.png")

var _open := false
var _open_t := 0.0


func _physics_process(_delta: float) -> void:
	var lvl := Game.level
	var p := Game.player
	var open_now := lvl != null and lvl.enemies_left <= 0
	if open_now != _open:
		_open = open_now
		if _open:
			_open_t = 0.0
			Juice.ring(global_position + Vector2(0, -6), 14.0, Palette.EXIT_OPEN, 0.35)
			Juice.glints(global_position, 8, Palette.EXIT_OPEN)
	if _open and p and not p.dead and overlaps_body(p):
		lvl.complete()


func _process(delta: float) -> void:
	_open_t += delta
	queue_redraw()


func _draw() -> void:
	var key := "elevator_open" if _open else "elevator"
	var r := Prop.rect_of(key)
	var at := Vector2(-r.size.x / 2.0, 8 - r.size.y).round()   # 底边对齐碰撞盒底边（+8）
	draw_texture_rect_region(PROPS, Rect2(at, r.size), r)
	var k := 1.15                                      # 开门后的暖光：微微进辉光，不要过曝成白块
	if not _open:
		k = 1.2 + 0.6 * signf(sin(_open_t * 4.0))      # 锁定时红灯慢闪
	draw_texture_rect_region(EMIT, Rect2(at, r.size), r, Color(k, k, k))
	if _open:
		# 门口地面的暖光与上升的光点
		var c := Color(0.6, 0.45, 0.2, 1.0)
		draw_rect(Rect2(at.x + 2, 7, r.size.x - 4, 1), c)
		var y := fmod(_open_t * 10.0, 18.0)
		draw_rect(Rect2(-3, 6 - y, 1, 1), Color(1.6, 1.3, 0.7, 1.0 - y / 18.0))
		draw_rect(Rect2(3, 6 - fmod(y + 9.0, 18.0), 1, 1), Color(1.6, 1.3, 0.7, 1.0 - fmod(y + 9.0, 18.0) / 18.0))
