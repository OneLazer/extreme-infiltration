class_name Banner
extends Control
## 屏幕中央的横幅（清场提示、通关时间）。暗色横带从左滑入，标题用粗宋像素体，副标题用 m6x11。
## 坐标是 320×180 画布单位，字体在根视口按窗口分辨率渲染：标题 12 单位 = 原生 12px 的整数倍。

var _title := ""
var _sub := ""
var _t := 0.0
var _hold := 0.0
var _last := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_last = Time.get_ticks_msec() / 1000.0


func show_text(title: String, sub: String, hold: float) -> void:
	_title = title
	_sub = sub
	_t = 0.0
	_hold = hold


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0   # 真实时间：慢动作、顿帧期间照常播放
	_t += now - _last
	_last = now
	queue_redraw()


func _draw() -> void:
	if _title == "":
		return
	var appear := clampf(_t / 0.18, 0.0, 1.0)
	var leave := clampf((_t - _hold) / 0.2, 0.0, 1.0)
	if leave >= 1.0:
		return
	var k := ease(appear, 0.3) * (1.0 - leave)
	var h := 30.0 * (1.0 - leave)
	var band := Rect2(0, 90 - h / 2.0, 320.0 * ease(appear, 0.25), h)
	draw_rect(band, Color(Palette.N0, 0.8))
	draw_rect(Rect2(band.position.x, band.position.y - 1, band.size.x, 1), Color(Palette.C1, k))
	draw_rect(Rect2(band.position.x, band.end.y, band.size.x, 1), Color(Palette.C1, k))
	if appear < 1.0:
		return
	var font := UiFonts.big()
	var n := mini(_title.length(), int((_t - 0.18) / 0.045) + 1)    # 逐字打出
	var shown := _title.substr(0, n)
	var tw := font.get_string_size(_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var x := 160.0 - tw / 2.0
	draw_string(font, Vector2(x + 0.5, 91.5), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(Palette.P2, k))
	draw_string(font, Vector2(x, 91), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(Palette.W3, k))
	if n >= _title.length() and _sub != "":
		# 纯数字用 m6x11，含中文用缝合像素 12px（画在 6 单位 = 半个游戏像素一格）
		var ascii := _sub.to_ascii_buffer().size() == _sub.length()
		var f2 := UiFonts.num() if ascii else UiFonts.text()
		var fs := 8 if ascii else 6
		var sw := f2.get_string_size(_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f2, Vector2(160.0 - sw / 2.0, 101), _sub, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Palette.C3, k))
