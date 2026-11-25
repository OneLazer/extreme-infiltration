class_name MenuHero
extends Node2D
## 主菜单天台上的主角：站在楼沿望着城市，围巾被风吹向身后。
## 点「开始游戏」时 leap()：蹲一下 → 起跳冲出画面（残影、扬尘）。原点在脚底。

const SHEET := preload("res://assets/chars/player.png")
const SIL := preload("res://assets/chars/player_sil.png")
const SEGS := 7

var face := -1                  ## -1 朝左（看向城市）
var _t := 0.0
var _leap_t := -1.0             ## >=0：起跳动画进行中
var _vel := Vector2.ZERO
var _ghost_t := 0.0
var _scarf: PackedVector2Array = []


func _ready() -> void:
	for i in SEGS:
		_scarf.append(_neck() + Vector2(1, 0.3) * 1.75 * i)


func _neck() -> Vector2:
	return Vector2(-face * 3.0, -8.0)


func leap() -> void:
	_leap_t = 0.0


func _process(delta: float) -> void:
	_t += delta
	if _leap_t >= 0.0:
		var before := _leap_t
		_leap_t += delta
		if before < 0.12 and _leap_t >= 0.12:      # 蹲完，起跳
			_vel = Vector2(-150, -175)
			Juice.dust(global_position, 6, Vector2(1, -0.3), 40.0)
			Juice.ring(global_position + Vector2(0, -2), 7.0, Palette.SCARF * Color(0.7, 0.7, 0.7), 0.2)
			ScreenFx.pulse(1.6)
		if _leap_t >= 0.12:
			_vel.y += 520.0 * delta
			position += _vel * delta
			_ghost_t -= delta
			if _ghost_t <= 0.0:
				_ghost_t = 0.04
				Juice.ghost(global_position + Vector2(0, 0), SIL, _region(), Vector2(-8, -16), face < 0,
					Vector2.ONE, Palette.SCARF * Color(0.8, 0.8, 0.8), 0.22, 0.8)
	_update_scarf(delta)
	queue_redraw()


func _frame() -> int:
	if _leap_t >= 0.0:
		return 10 if _leap_t < 0.12 else (8 if _vel.y < 0.0 else 9)
	return int(_t * 5.0) % 4


func _region() -> Rect2:
	return Rect2(_frame() * 16, 0, 16, 16)


## 风从左边吹来：围巾整条往右后方飘，沿链条传一道慢波，尾端摆得最大
func _update_scarf(delta: float) -> void:
	_scarf[0] = _neck()
	var gust := 0.75 + 0.25 * sin(_t * 0.9) + 0.12 * sin(_t * 2.3)
	for i in range(1, SEGS):
		var k := float(i) / (SEGS - 1)
		# 根部顺着风往后上方，越往尾端越垂、摆得越大
		var ang := 0.05 + 0.55 * (1.0 - gust) + 0.5 * k * k + sin(_t * 5.6 - i * 0.9) * 0.45 * k
		if _leap_t >= 0.12:
			ang = (-_vel).angle() + sin(_t * 18.0 - i) * 0.2 * k   # 跳起时拖在身后
		var want := _scarf[i - 1] + Vector2(cos(ang), sin(ang)) * 1.75
		_scarf[i] = _scarf[i].move_toward(want, 140.0 * delta)
		var d := _scarf[i] - _scarf[i - 1]
		if d.length() > 2.6:
			_scarf[i] = _scarf[i - 1] + d.normalized() * 2.6


func _draw() -> void:
	var squash := Vector2.ONE
	if _leap_t >= 0.0 and _leap_t < 0.12:
		squash = Vector2(1.2, 0.8)
	elif _leap_t >= 0.12:
		squash = Vector2(0.85, 1.15)
	draw_set_transform(Vector2.ZERO, 0.0, squash)
	# 围巾在身后：先画
	var col := Palette.SCARF
	var shade := Color(col.r * 0.5, col.g * 0.5, col.b * 0.55)
	var thick := 2
	for pass_i in 2:
		for i in range(SEGS - 1):
			var a := _scarf[i].round()
			var b := _scarf[i + 1].round()
			var n := int(maxf(absf(b.x - a.x), absf(b.y - a.y)))
			for s in range(1 if i > 0 else 0, n + 1):
				var p := a.lerp(b, float(s) / maxf(n, 1)).round()
				var wide := i < thick
				if pass_i == 0 and wide:
					draw_rect(Rect2(p + Vector2(0, 2), Vector2(2, 1)), shade)
				elif pass_i == 1:
					draw_rect(Rect2(p, Vector2(2, 2) if wide else Vector2.ONE), col)
	var r := _region()
	# 精灵表默认朝右；朝左时用负宽度水平翻转
	var dst := Rect2(Vector2(8, -16), Vector2(-16, 16)) if face < 0 else Rect2(Vector2(-8, -16), Vector2(16, 16))
	draw_texture_rect_region(SHEET, dst, r)
	draw_set_transform(Vector2.ZERO)
