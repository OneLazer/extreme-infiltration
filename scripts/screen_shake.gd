class_name ScreenShake
extends Camera2D
## 屏幕震动，写法参考「搞莫字」的 board_view.gd：
## 用两条不同频率的正/余弦波驱动 offset，幅度按剩余时间平方衰减（trauma² 手感）。
## 在此基础上加了幅度包络：起震快速淡入、结束后平滑淡出，不会硬切回零。
## 强度单位是 320x180 画布像素（窗口放大 4 倍时 1px ≈ 4 屏幕像素）。

@export var freq_x := 71.0          ## 水平抖动角速度（弧度/秒），越大抖得越快
@export var freq_y := 53.0          ## 垂直抖动角速度（弧度/秒）
@export var fade_in := 0.01         ## 起震淡入时间常数（秒），越小越接近硬冲击
@export var fade_out := 0.1        ## 收尾淡出时间常数（秒），越大尾巴拖得越久

var _clock := 0.0                   ## 持续累加的时间，保证波形相位连续
var _strength := 0.0
var _time_left := 0.0
var _duration := 0.1
var _amp := 0.0                     ## 平滑后的实际幅度
var _kick := Vector2.ZERO           ## 方向性镜头推移（开火、击杀），指数衰减
@export var kick_decay := 14.0      ## 推移回弹速度


## 镜头朝某个方向推一下（单位：画布像素），叠加在震动之上
func kick(v: Vector2) -> void:
	_kick += v
	_kick = _kick.limit_length(6.0)


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
	_kick = _kick.lerp(Vector2.ZERO, 1.0 - exp(-kick_decay * delta))
	if _kick.length() < 0.05:
		_kick = Vector2.ZERO
	if _time_left <= 0.0 and _amp < 0.005:
		offset = _kick
		return
	_time_left -= delta

	var target := 0.0
	if _time_left > 0.0:
		var k := clampf(_time_left / _duration, 0.0, 1.0)
		target = _strength * k * k

	# 幅度包络：上升用 fade_in，衰减用 fade_out。指数逼近与帧率无关。
	var tau := fade_in if target > _amp else fade_out
	_amp = lerpf(_amp, target, 1.0 - exp(-delta / maxf(tau, 0.0001)))
	offset = Vector2(sin(_clock * freq_x), cos(_clock * freq_y)) * _amp + _kick

	if _time_left <= 0.0 and _amp < 0.005:
		_strength = 0.0
		_amp = 0.0
		offset = _kick
