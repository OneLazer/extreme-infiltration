class_name ScreenShake
extends Camera2D
## 屏幕震动。挂在 Camera2D 上，其他脚本调用 shake(强度, 时长)。
## 强度单位是 320x180 画布像素（窗口放大 4 倍时 1px ≈ 4 屏幕像素）。
## 多次触发时取更强的一次，强度随剩余时间线性衰减。

var _strength := 0.0
var _time_left := 0.0
var _duration := 0.1


func shake(strength: float, duration: float) -> void:
	if strength <= 0.0 or duration <= 0.0:
		return
	# 更强的一次直接接管；较弱的不打断正在进行的震动
	if strength >= _strength or _time_left <= 0.0:
		_strength = strength
		_duration = maxf(duration, 0.01)
		_time_left = _duration


func _process(delta: float) -> void:
	if _time_left <= 0.0:
		return
	_time_left -= delta
	var k := clampf(_time_left / _duration, 0.0, 1.0)
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _strength * k
	if _time_left <= 0.0:
		_strength = 0.0
		offset = Vector2.ZERO
