class_name ScreenShake
extends Camera2D
## 屏幕震动。挂在 Camera2D 上，其他脚本调用 shake(强度, 时长)。
## 强度单位是 320x180 画布像素（窗口放大 4 倍时 1px ≈ 4 屏幕像素）。
## 随机目标按 update_hz 刷新，offset 用 lerp 追赶：比逐帧随机更柔和，幅度也会被压低。
## 多次触发时取更强的一次，强度随剩余时间线性衰减。

@export var update_hz := 20.0       ## 随机目标刷新频率（Hz）
@export var smoothing := 8.0        ## 追赶速度：越大越接近设定强度，越小越柔和

var _strength := 0.0
var _time_left := 0.0
var _duration := 0.1
var _target := Vector2.ZERO
var _update_left := 0.0


func shake(strength: float, duration: float) -> void:
	if strength <= 0.0 or duration <= 0.0:
		return
	# 更强的一次直接接管；较弱的不打断正在进行的震动
	if strength >= _strength or _time_left <= 0.0:
		_strength = strength
		_duration = maxf(duration, 0.01)
		_time_left = _duration
		_update_left = 0.0
		_target = Vector2.ZERO


func _process(delta: float) -> void:
	if _time_left <= 0.0:
		return
	_time_left -= delta
	var k := clampf(_time_left / _duration, 0.0, 1.0)

	# 只在 update_hz 的节拍上换随机目标
	_update_left -= delta
	while _update_left <= 0.0:
		_update_left += 1.0 / maxf(update_hz, 1.0)
		_target = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _strength * k

	# 每帧向目标插值，产生平滑拖尾（也是幅度变小的来源）
	offset = offset.lerp(_target, clampf(smoothing * delta, 0.0, 1.0))

	if _time_left <= 0.0:
		_strength = 0.0
		_target = Vector2.ZERO
		offset = Vector2.ZERO
