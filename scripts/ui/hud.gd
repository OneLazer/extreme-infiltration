class_name Hud
extends Control
## 关卡 HUD：左上武器队列（当前武器 + 排队的武器与弹药），右上守卫剩余与计时。
## 画在根视口（按窗口分辨率渲染），坐标仍是 320×180 画布单位：图标一格 = 一个游戏像素，文字半格。

const PROPS := preload("res://assets/props/props.png")
const ICON := {0: "icon_dart", 1: "icon_boomerang", 2: "icon_heavy", 3: "icon_airgun", 4: "icon_rapier"}

var level: Level
var _t := 0.0
var _flash := 0.0          # 武器变化时当前格闪一下
var _last_sig := ""
var _toast := ""
var _toast_col := Color.WHITE
var _toast_t := 0.0        # 剩余显示时间（秒）
var _cd_t := 99.0          # 倒计时出现后经过的时间（滑入 / 闪亮动画）
var _cd_pop := 0.0         # 最后 5 秒每跳一秒弹一下 1 → 0


## 计时门触发：倒计时从顶部滑入并闪一下
func countdown_started() -> void:
	_cd_t = 0.0
	_cd_pop = 1.0


func countdown_tick() -> void:
	_cd_pop = 1.0


## 武器栏下方弹出一行小字：滑入、停留、淡出
func toast(text: String, col: Color) -> void:
	_toast = text
	_toast_col = col
	_toast_t = 1.6


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(_flash - delta * 4.0, 0.0)
	_toast_t = maxf(_toast_t - delta, 0.0)
	_cd_t += delta
	_cd_pop = maxf(_cd_pop - delta * 5.0, 0.0)
	queue_redraw()


func _draw() -> void:
	if level == null or Game.player == null:
		return
	var p := Game.player
	# ---------- 左上：武器 ----------
	var slots: Array = []
	for w in p.weapon_queue:
		slots.append([w["type"], str(w["ammo"])])
	slots.append([p.initial_weapon, "" if WeaponDefs.is_none(p.initial_weapon) else "∞"])
	var sig := str(slots)
	if sig != _last_sig:
		_last_sig = sig
		_flash = 1.0
	var name_w := UiFonts.text().get_string_size(WeaponDefs.get_def(slots[0][0])["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 6).x
	var w := 22 + int(name_w) + (slots.size() - 1) * 13
	_panel(Rect2(0, 0, w, 15))
	var cur: Array = slots[0]
	var col: Color = WeaponDefs.get_def(cur[0])["color"]
	_brackets(Rect2(3, 2, 11, 11), col * (1.0 + _flash))
	_icon(cur[0], Vector2(4, 3), Color(1.2, 1.2, 1.2))
	_text_num(cur[1], Vector2(17, 8), Palette.C4)
	var wname: String = WeaponDefs.get_def(cur[0])["name"]
	draw_string(UiFonts.text(), Vector2(16, 13.5), wname, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(Palette.C3, 0.85))
	var x := 22 + int(UiFonts.text().get_string_size(wname, HORIZONTAL_ALIGNMENT_LEFT, -1, 6).x)
	for i in range(1, slots.size()):
		var s: Array = slots[i]
		_icon(s[0], Vector2(x, 3), Color(0.55, 0.55, 0.65, 0.9))
		TinyDigits.draw(self, s[1] if s[1] != "∞" else "", Vector2(x + 6, 9), Palette.N6)
		x += 13
	# ---------- 右上：守卫 + 计时 ----------
	var r := Rect2(320 - 78, 0, 78, 15)
	_panel(r, true)
	_guard_icon(Vector2(r.position.x + 6, 4))
	var gl := level.enemies_left
	_text_num(str(gl), Vector2(r.position.x + 15, 10), Palette.W3 if gl > 0 else Color(0.4, 2.0, 0.7))
	var tm := level.time
	_text_num("%02d:%04.1f" % [int(tm / 60.0), fmod(tm, 60.0)], Vector2(r.position.x + 30, 10), Palette.C3)
	if level.countdown_active():
		_draw_countdown()
	_draw_toast()
	_draw_threats()


## 顶部中间的倒计时：暗底横条（两侧斜切）+ 大号数字 + 下沿剩余进度条。
## 钴蓝；最后 5 秒变红、闪烁，每跳一秒数字上弹 1px 并加亮；通关后定格变绿。
func _draw_countdown() -> void:
	var left := level.timer_left
	var done := level.is_done()
	var appear := ease(clampf(_cd_t / 0.18, 0.0, 1.0), 0.4)
	var y0 := roundf(-18.0 * (1.0 - appear))
	var r := Rect2(160 - 25, y0, 50, 16)
	var bg := Color(Palette.N0, 0.78)
	draw_rect(r, bg)
	for i in 4:   # 两侧斜切角
		draw_rect(Rect2(r.position.x - 1 - i, y0, 1, r.size.y - i * 4), bg)
		draw_rect(Rect2(r.end.x + i, y0, 1, r.size.y - i * 4), bg)
	var low := left < 5.0 and not done
	var c := Palette.TIMER
	if done:
		c = Palette.EXIT_OPEN
	elif low:
		var blink := 1.0 if fmod(_t, 0.25) < 0.17 else 0.6
		c = Palette.ALERT * Color(blink, blink, blink)
	var k := 1.0 + _cd_pop * 0.8 + maxf(0.0, 0.3 - _cd_t) * 5.0      # 刚出现 / 跳秒时加亮
	var txt := "%05.2f" % left
	var f := UiFonts.num()
	var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var at := Vector2(roundf(160.0 - w * 0.5), y0 + 12.0 - roundf(_cd_pop))
	draw_string(f, at + Vector2(1, 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0, 0, 0, 0.6))
	draw_string(f, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(c.r * k, c.g * k, c.b * k))
	# 剩余进度：下沿一条 1px 线，亮段从右往左缩短
	var frac := clampf(left / maxf(level.timer_total, 0.01), 0.0, 1.0)
	draw_rect(Rect2(r.position.x, r.end.y, r.size.x, 1), Color(Palette.N3, 0.9))
	draw_rect(Rect2(r.position.x, r.end.y, roundf(r.size.x * frac), 1), c * Color(0.8, 0.8, 0.8))


## 屏外威胁：锁定玩家的守卫在画面外时，屏幕边缘对应方向画一个小箭头 + 警戒进度，
## 快满时闪烁。锁定视线不限距离，不提示的话会被看不见的守卫打死。
func _draw_threats() -> void:
	var xf := PixelView.view.get_canvas_transform()
	var screen := Rect2(0, 0, 320, 180)
	for n in get_tree().get_nodes_in_group("enemies"):
		var g := n as Guard
		if g == null or g.dead or not g.is_locked():
			continue
		var sp: Vector2 = xf * g.global_position
		if screen.grow(-2.0).has_point(sp):
			continue
		var center := Vector2(160, 90)
		var dir := (sp - center).normalized()
		# 沿方向射到内缩 9px 的屏幕框上
		var inner := screen.grow(-9.0)
		var tx := (inner.size.x * 0.5) / maxf(absf(dir.x), 0.001)
		var ty := (inner.size.y * 0.5) / maxf(absf(dir.y), 0.001)
		var at := (center + dir * minf(tx, ty)).round()
		var hot := g.alert > 0.75
		var blink := 1.0 if not hot or fmod(_t, 0.14) < 0.08 else 0.4
		var c: Color = Palette.GUARD.lerp(Palette.ALERT, g.alert) * Color(blink, blink, blink)
		_arrow(at, dir, c)
		# 进度：箭头后面一条 7px 的短条
		var side := Vector2(-dir.y, dir.x)
		var base := at - dir * 5.0 - side * 3.0
		for i in 7:
			var on := float(i) / 7.0 < g.alert
			draw_rect(Rect2((base + side * i).round(), Vector2.ONE), c if on else Color(0.2, 0.05, 0.08, 0.8))


## 指向 dir 的 5px 小箭头（尖端在 at）
func _arrow(at: Vector2, dir: Vector2, c: Color) -> void:
	var side := Vector2(-dir.y, dir.x)
	for k in 4:
		for s in range(-k, k + 1):
			draw_rect(Rect2((at - dir * k + side * s * 0.75).round(), Vector2.ONE), c)


func _draw_toast() -> void:
	if _toast_t <= 0.0:
		return
	var age := 1.6 - _toast_t
	var slide := (1.0 - clampf(age / 0.12, 0.0, 1.0)) * -12.0      # 0.12s 从左滑入
	var a := clampf(_toast_t / 0.3, 0.0, 1.0)                       # 最后 0.3s 淡出
	var w := UiFonts.text().get_string_size(_toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 6).x
	var at := Vector2(slide, 18)
	draw_rect(Rect2(at, Vector2(w + 8, 9)), Color(Palette.N0, 0.72 * a))
	draw_rect(Rect2(at, Vector2(1, 9)), Color(_toast_col, a))
	var k := 1.0 + maxf(0.0, 0.3 - age) * 3.0                        # 刚出现时文字亮一下
	draw_string(UiFonts.text(), at + Vector2(4, 7), _toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 6,
		Color(Palette.C4.r * k, Palette.C4.g * k, Palette.C4.b * k, a))


## 半透明暗底条 + 下沿青色细线；right=true 时斜角在左边
func _panel(r: Rect2, right := false) -> void:
	var c := Color(Palette.N0, 0.72)
	draw_rect(r, c)
	var edge := Color(Palette.C1, 0.7)
	draw_rect(Rect2(r.position.x, r.end.y, r.size.x, 1), edge)
	for i in 4:   # 斜切角
		var x := r.position.x - 1 - i if right else r.end.x + i
		draw_rect(Rect2(x, r.position.y, 1, r.size.y - i * 4), c)
		draw_rect(Rect2(x, r.end.y - i * 4, 1, 1), edge)


func _brackets(r: Rect2, c: Color) -> void:
	for corner in [r.position, Vector2(r.end.x - 1, r.position.y), Vector2(r.position.x, r.end.y - 1), r.end - Vector2.ONE]:
		var sx := 1.0 if corner.x < r.get_center().x else -1.0
		var sy := 1.0 if corner.y < r.get_center().y else -1.0
		draw_rect(Rect2(corner, Vector2.ONE), c)
		draw_rect(Rect2(corner + Vector2(sx, 0), Vector2.ONE), c)
		draw_rect(Rect2(corner + Vector2(0, sy), Vector2.ONE), c)


func _icon(type: int, at: Vector2, mod: Color) -> void:
	if WeaponDefs.is_none(type):
		_empty_icon(at, mod)
		return
	var r := Prop.rect_of(ICON.get(type, "icon_dart"))
	draw_texture_rect_region(PROPS, Rect2(at, r.size), r, mod)


## 徒手：8×8 的虚线空槽，中间一道斜杠
func _empty_icon(at: Vector2, mod: Color) -> void:
	var c := Color(0.42 * mod.r, 0.4 * mod.g, 0.55 * mod.b, mod.a)
	for i in 8:
		if i % 2 == 0:
			for e in [Vector2(i, 0), Vector2(i, 7), Vector2(0, i), Vector2(7, i)]:
				draw_rect(Rect2(at + e, Vector2.ONE), c)
	for i in range(2, 6):
		draw_rect(Rect2(at + Vector2(7 - i, i), Vector2.ONE), Color(c.r * 1.4, c.g * 1.4, c.b * 1.4, c.a))


## 数字用 m6x11（字号 8 = 原生 16px 的一半，根视口高分辨率下依然锐利）；∞ 用像素图案画
func _text_num(s: String, baseline: Vector2, c: Color) -> void:
	if s == "∞":
		for p in [Vector2(1, 0), Vector2(5, 0), Vector2(0, 1), Vector2(2, 1), Vector2(3, 1), Vector2(4, 1),
				Vector2(6, 1), Vector2(1, 2), Vector2(5, 2)]:
			draw_rect(Rect2(baseline + Vector2(0, -4) + p, Vector2.ONE), c)
		return
	draw_string(UiFonts.num(), baseline + Vector2(0.5, 0.5), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0, 0, 0, 0.6))
	draw_string(UiFonts.num(), baseline, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, c)


## 守卫小图标：头盔 + 琥珀面罩
func _guard_icon(at: Vector2) -> void:
	draw_rect(Rect2(at + Vector2(1, 0), Vector2(5, 1)), Color("#73759a"))
	draw_rect(Rect2(at + Vector2(0, 1), Vector2(7, 5)), Color("#55577a"))
	draw_rect(Rect2(at + Vector2(1, 2), Vector2(5, 1)), Palette.GUARD)
	draw_rect(Rect2(at + Vector2(0, 5), Vector2(7, 1)), Color("#262540"))
