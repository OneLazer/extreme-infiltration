class_name ScreenShake
extends Camera2D
## 屏幕震动，写法参考「搞莫字」的 board_view.gd：
## 用两条不同频率的正/余弦波驱动 offset，幅度按剩余时间平方衰减（trauma² 手感）。
## 连续、平滑，没有逐帧随机抖动。
## 强度单位是 320x180 画布像素（窗口放大 4 倍时 1px ≈ 4 屏幕像素）。

@export var freq_x := 71.0          ## 水平抖动角速度（弧度/秒），越大抖得越快
@export var freq_y := 53.0          ## 垂直抖动角速度（弧度/秒）

var _clock := 0.0                   ## 持续累加的时间，保证波形相位连续
var _strength := 0.0
var _time_left := 0.0
var _duration := 0.1


func shake(strength: float, duration: float) -> void:
	if strength <= 0.0 or duration <= 0.0:
		return
	# 更强的一次接管；较弱的不打断正在进行的震动
	if strength >= _strength or _time_left <= 0.0:
		_strength = strength
		_duration = maxf(duration, 0.01)
		_time_left = _duration


func _process(delta: float) -> void:
	_clock += delta
	if _time_left <= 0.0:
		return
	_time_left -= delta
	var k := clampf(_time_left / _duration, 0.0, 1.0)
	var amp := _strength * k * k
	offset = Vector2(sin(_clock * freq_x), cos(_clock * freq_y)) * amp
	if _time_left <= 0.0:
		_strength = 0.0
		offset = Vector2.ZERO
