class_name CreditsPage
extends MenuPage
## 致谢：暗底上缓慢向上滚动的名单，按住确认键加速，ESC 返回。
## 滚到最后「感谢游玩」停在画面中间，主角从底部跑过，几秒后自动回到主菜单。
## ending = true：通关最后一关后进来（标题换成「任务完成」）。

const SPEED := 16.0
const SHEET := preload("res://assets/chars/player.png")

const LINES := [
	["title", "极限潜入行动"], ["sub", "EXTREME INFILTRATION"], ["gap", 26],
	["head", "制作"],
	["role", "策划", "拉丝"],
	["role", "美术 & 音频", "Claude Opus 5.5"],
	["role", "程序", "Claude Opus 5.5"],
	["role", "", "Deepseek V4.1 Flash"],
	["gap", 22],
	["head", "字体"],
	["line", "缝合像素 Fusion Pixel Font — TakWolf · SIL OFL 1.1"],
	["line", "粗宋 Chusung — Poxiao Fonts · CC BY-SA 4.0"],
	["line", "m6x11 — Daniel Linssen"],
	["gap", 22],
	["head", "引擎与工具"],
	["line", "Godot Engine — MIT License"],
	["dim", "© 2014-present Godot Engine contributors"],
	["dim", "© 2007-2014 Juan Linietsky, Ariel Manzur"],
	["gap", 6],
	["line", "pixelfx — patch-gg · MIT License"],
	["dim", "特效方法参考 Hugo Duprez / Sprite Fusion"],
	["gap", 22],
	["head", "参考"],
	["line", "移动手感移植自 Celeste（Player.cs）"],
	["dim", "© 2018 Noel Berry · MIT License"],
	["gap", 60],
	["end", "感谢游玩"],
]

var ending := false
var _scroll := 0.0
var _end_y := 0.0           ## 「感谢游玩」在内容里的 y
var _height := 0.0
var _stop_t := -1.0         ## 停住后经过的时间
var _fast := false


func _ready() -> void:
	var y := 0.0
	for l in LINES:
		y += _line_h(l)
		if l[0] == "end":
			_end_y = y
	_height = y


func _line_h(l: Array) -> float:
	match l[0]:
		"title":
			return 26.0
		"sub":
			return 10.0
		"gap":
			return float(l[1])
		"head":
			return 14.0
		"role":
			return 14.0
		"end":
			return 24.0
	return 9.0


func _max_scroll() -> float:
	return 186.0 + _end_y - 98.0


func on_action(a: String) -> void:
	if a == "back":
		host.pop()


func on_click(_p: Vector2) -> void:
	pass


func on_mouse(_p: Vector2) -> void:
	pass


func update(dt: float) -> void:
	_fast = Input.is_action_pressed("ui_accept") or Input.is_action_pressed("jump") \
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if _stop_t < 0.0:
		_scroll += SPEED * dt * (4.0 if _fast else 1.0)
		if _scroll >= _max_scroll():
			_scroll = _max_scroll()
			_stop_t = 0.0
			Sfx.play("level_clear", 0.0, -4.0)
			ScreenFx.pulse(1.5)
	else:
		_stop_t += dt
		if _stop_t > 4.2 and not leaving and host.current() == self:
			host.pop(false)


func _draw() -> void:
	draw_rect(Rect2(-40, -10, 400, 200), Color(Palette.N0, 0.82))
	var top := roundf(186.0 - _scroll)
	var y := top
	var font := UiFonts.text()
	for l in LINES:
		var h := _line_h(l)
		var base := y + h
		if base > -10.0 and y < 190.0:
			match l[0]:
				"title":
					var s: String = "任务完成" if ending else l[1]
					var w := UiKit.width(UiFonts.big(), s, 24)
					UiKit.title(self, Vector2(roundf(160 - w / 2.0), base - 3), s, 24)
				"sub":
					_center_num(l[1], base - 2, Palette.C2)
				"head":
					var w2 := UiKit.width(font, l[1], 6)
					UiKit.zh(self, Vector2(roundf(160 - w2 / 2.0), base - 4), l[1], Palette.C1)
					draw_rect(Rect2(roundf(160 - w2 / 2.0) - 10, base - 7, 6, 1), Palette.P3)
					draw_rect(Rect2(roundf(160 + w2 / 2.0) + 4, base - 7, 6, 1), Palette.P3)
				"role":
					var rw := UiKit.width(font, l[1], 6)
					UiKit.zh(self, Vector2(roundf(120 - rw), base - 4), l[1], Color(Palette.C2, 0.9))
					# 名字：英文用 m6x11 原生 16（1:1，比例字宽），中文用缝合像素 12
					var nf: Font = UiFonts.num() if UiKit.is_ascii(l[2]) else font
					var ns := 16 if UiKit.is_ascii(l[2]) else 12
					UiKit.text(self, nf, Vector2(130, base - 3), l[2], ns, Palette.C4, 1.0)
				"line":
					_center_zh(l[1], base - 2, Palette.C3)
				"dim":
					_center_zh(l[1], base - 2, Color(Palette.N6, 1))
				"end":
					var w3 := UiKit.width(UiFonts.big(), l[1], 12)
					UiKit.title(self, Vector2(roundf(160 - w3 / 2.0), base - 6), l[1], 12)
		y += h
	# 上下边缘压暗（三级硬色阶）：名单从底部浮现、在顶部隐去，不和操作提示叠在一起
	for k in 3:
		var a := 0.82 - k * 0.25
		draw_rect(Rect2(-40, 158 + k * -4, 400, 4), Color(Palette.N0, a))
		draw_rect(Rect2(-40, 8 + k * 4, 400, 4), Color(Palette.N0, a))
	draw_rect(Rect2(-40, 162, 400, 30), Color(Palette.N0, 0.95))
	draw_rect(Rect2(-40, -10, 400, 18), Color(Palette.N0, 0.95))
	if _stop_t >= 0.0:
		_draw_runner()
	var ha := 0.0 if _stop_t >= 0.0 else 1.0
	if ha > 0.0:
		UiKit.hints(self, Vector2(20, 164), [[["空格"], "加速" if not _fast else "加速中"], [["ESC"], "返回"]], 0.8)


func _center_zh(s: String, y: float, c: Color) -> void:
	var w := UiKit.width(UiFonts.text(), s, 6)
	UiKit.zh(self, Vector2(roundf(160 - w / 2.0), y), s, c)


func _center_num(s: String, y: float, c: Color) -> void:
	var w := UiKit.width(UiFonts.num(), s, 8)
	UiKit.num(self, Vector2(roundf(160 - w / 2.0), y), s, c)


## 最后：主角从左往右跑过画面底部，身后拖一道品红残影
func _draw_runner() -> void:
	var x := roundf(-20.0 + _stop_t * 110.0)
	if x > 340.0:
		return
	var f := 4 + int(_stop_t * 12.0) % 4
	for k in 4:
		draw_rect(Rect2(x - 6 - k * 5, 146 - 4, 4, 1), Color(Palette.P3, 0.5 - k * 0.12))
	draw_texture_rect_region(SHEET, Rect2(x - 8, 134, 16, 16), Rect2(f * 16, 0, 16, 16))
	draw_rect(Rect2(-10, 150, 360, 1), Color(Palette.C1, 0.5))
