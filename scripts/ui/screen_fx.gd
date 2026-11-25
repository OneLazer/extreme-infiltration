extends Node
## 全局屏幕效果（Autoload: ScreenFx）。跨场景重载存活，所以死亡倒带和转场能接得上。
## 计时全部用真实时间，顿帧（time_scale = 0）期间照样动。
##   pulse(k)        色差脉冲（击杀、开火）
##   flash(k)        闪白
##   death_rewind()  死亡：去色 → 倒带干扰，结束后 await 返回（由关卡负责重载）
##   wipe_in() / wipe_out()  转场
##   crt_on() / crt_off()    显像管开关机（主菜单首次启动、退出游戏）
##   set_pause(on)           暂停时画面去色压暗

const POST := preload("res://shaders/post.gdshader")
const WIPE := preload("res://shaders/wipe.gdshader")
const CRT := preload("res://shaders/crt.gdshader")

@export var base_aberration := 0.0
@export var enabled := true                ## 关掉氛围后期（暗角、扫描线、颗粒）；死亡去色、倒带、危险暗角等玩法反馈照常

var _post: ShaderMaterial
var _wipe: ShaderMaterial
var _post_rect: ColorRect
var _label: Control
var _ab := 0.0
var _flash := 0.0
var _desat := 0.0
var _rewind := 0.0
var _wipe_p := 1.0
var _wipe_target := 1.0
var _wipe_speed := 3.2
var _last := 0.0
var _danger := 0.0          # 屏幕边缘红色危险暗角（平滑后的值）
var _danger_req := 0.0      # 本帧守卫上报的最大值，每帧清零
var _pause := 0.0
var _pause_target := 0.0
var _crt: ShaderMaterial
var _crt_rect: ColorRect
var _crt_p := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var post_layer := CanvasLayer.new()
	post_layer.layer = 50
	add_child(post_layer)
	_post_rect = ColorRect.new()
	_post_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post = ShaderMaterial.new()
	_post.shader = POST
	_post_rect.material = _post
	post_layer.add_child(_post_rect)
	var top := CanvasLayer.new()
	top.layer = 90
	add_child(top)
	var wipe_rect := ColorRect.new()
	wipe_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	wipe_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wipe = ShaderMaterial.new()
	_wipe.shader = WIPE
	wipe_rect.material = _wipe
	top.add_child(wipe_rect)
	_label = RewindLabel.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.visible = false
	top.add_child(_label)
	var crt_layer := CanvasLayer.new()
	crt_layer.layer = 100        # 盖过一切（含菜单光标）
	add_child(crt_layer)
	_crt_rect = ColorRect.new()
	_crt_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crt = ShaderMaterial.new()
	_crt.shader = CRT
	_crt_rect.material = _crt
	_crt_rect.visible = false
	crt_layer.add_child(_crt_rect)
	_last = _now()
func _process(_delta: float) -> void:
	var now := _now()
	var dt := minf(now - _last, 0.1)
	_last = now
	_ab = move_toward(_ab, 0.0, dt * 10.0)
	_flash = move_toward(_flash, 0.0, dt * 8.0)
	_wipe_p = move_toward(_wipe_p, _wipe_target, dt * _wipe_speed)
	# 危险暗角：涨得快、退得慢，避免掩体边缘来回闪
	var rate := 6.0 if _danger_req > _danger else 2.5
	_danger = move_toward(_danger, _danger_req, dt * rate)
	_danger_req = 0.0
	_post.set_shader_parameter("danger", _danger)
	_pause = move_toward(_pause, _pause_target, dt * 7.0)
	_post.set_shader_parameter("pause", _pause)
	_post.set_shader_parameter("vignette", 0.3 if enabled else 0.0)
	_post.set_shader_parameter("grain", 0.02 if enabled else 0.0)
	_post.set_shader_parameter("scanline", 0.07 if enabled else 0.0)
	_post.set_shader_parameter("aberration", base_aberration + _ab)
	_post.set_shader_parameter("flash", _flash)
	_post.set_shader_parameter("desat", _desat)
	_post.set_shader_parameter("rewind", _rewind)
	_post.set_shader_parameter("time", fmod(now, 1000.0))
	_wipe.set_shader_parameter("progress", _wipe_p)
	(_label as RewindLabel).strength = _rewind
	_label.visible = _rewind > 0.01
	_label.queue_redraw()


## 色差脉冲和闪白都乘设置里的「闪光强度」（0 = 关闭，给怕闪的玩家）
func pulse(k := 2.0) -> void:
	_ab = maxf(_ab, k * Settings.flash_mult)


func flash(k := 0.5) -> void:
	_flash = maxf(_flash, k * Settings.flash_mult)


## 守卫警戒条过半后每帧上报 0..1，屏幕边缘泛红；取当帧最危险的那个
func danger(k: float) -> void:
	_danger_req = maxf(_danger_req, clampf(k, 0.0, 1.0))


## 新关卡开始：从左往右揭开；去色和倒带清零
func wipe_in() -> void:
	_desat = 0.0
	_rewind = 0.0
	_wipe.set_shader_parameter("dir", 1.0)
	_wipe_p = 0.0
	_wipe_target = 1.0


## 通关离场：从右往左盖上，盖满后返回
func wipe_out() -> void:
	_wipe.set_shader_parameter("dir", -1.0)
	_wipe_p = 1.0
	_wipe_target = 0.0
	while _wipe_p > 0.0:
		await get_tree().process_frame


## 死亡：画面去色、色差拉满，接着 VHS 倒带干扰，完成后返回
func death_rewind() -> void:
	var t0 := _now()
	while _now() - t0 < 0.32:
		var k := (_now() - t0) / 0.32
		_desat = k * 0.85
		_ab = 3.0
		await get_tree().process_frame
	t0 = _now()
	while _now() - t0 < 0.42:
		_rewind = clampf((_now() - t0) / 0.12, 0.0, 1.0)
		_desat = 0.85
		await get_tree().process_frame


## 转场是否正在进行（暂停菜单在转场期间不响应）
func is_wiping() -> bool:
	return _wipe_p != _wipe_target or _wipe_p < 1.0 or _rewind > 0.01 or _crt_rect.visible


## 暂停菜单打开 / 关闭时调用：画面在约 0.14 秒内去色压暗（或恢复）
func set_pause(on: bool) -> void:
	_pause_target = 1.0 if on else 0.0


## 关机：收成一条线、一个点后全黑，结束后返回（之后要么退出游戏，要么由 crt_on 接上）
func crt_off(sec := 0.42) -> void:
	await _crt_run(0.0, 1.0, sec)


## 开机：从黑屏里亮出一条线，再上下展开成画面
func crt_on(sec := 0.5) -> void:
	await _crt_run(1.0, 0.0, sec)


## 直接设成全黑（开机动画开始前先盖住画面）
func crt_black() -> void:
	_crt_p = 1.0
	_crt.set_shader_parameter("progress", 1.0)
	_crt_rect.visible = true


func _crt_run(from: float, to: float, sec: float) -> void:
	_crt_rect.visible = true
	var t0 := _now()
	while true:
		var k := clampf((_now() - t0) / sec, 0.0, 1.0)
		_crt_p = lerpf(from, to, k)
		_crt.set_shader_parameter("progress", _crt_p)
		if k >= 1.0:
			break
		await get_tree().process_frame
	_crt_rect.visible = _crt_p > 0.0


func _now() -> float:
	return Time.get_ticks_usec() / 1000000.0


## 倒带时左上角的 ◀◀ REWIND 字样
class RewindLabel extends Control:
	var strength := 0.0

	func _draw() -> void:
		if strength <= 0.01:
			return
		var blink := fmod(Time.get_ticks_msec() / 1000.0, 0.5) < 0.32
		var c := Color(1.0, 1.0, 1.0, strength)
		for k in 2:   # 两个左三角
			var x := 10 + k * 7
			for i in 4:
				draw_rect(Rect2(x + i, 12 - i, 1, 1 + i * 2), c)
		if blink:
			draw_string(UiFonts.num(), Vector2(28, 17), "REWIND", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, c)
		draw_string(UiFonts.small(), Vector2(10, 168), "重新来过", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(c, strength * 0.7))
