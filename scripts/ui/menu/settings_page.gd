class_name SettingsPage
extends MenuPage
## 设置：四个分页（画面 / 声音 / 游戏 / 操作）。第 0 行是分页栏，←→ 或 Q / E 切换；其余行 ←→ 调整、确认键切换。
## 右边说明框显示当前行的用途。改动立即生效并保存（Settings autoload）。主菜单和暂停菜单共用这一页。

const X := 20.0
const ROW_W := 180.0
const Y0 := 54.0
const STEP := 12.0
const TAB_W := 28.0
const DESC := Rect2(212, 54, 88, 92)

const TABS := [
	{"name": "画面", "rows": [
		{"key": "fullscreen", "label": "显示模式", "type": "choice", "values": [false, true], "names": ["窗口", "全屏"],
			"desc": "全屏时画面按整数倍放大到显示器，四周可能留黑边。"},
		{"key": "window_scale", "label": "窗口大小", "type": "choice", "values": [2, 3, 4, 5, 6],
			"names": ["2×", "3×", "4×", "5×", "6×"],
			"desc": "窗口模式下的放大倍数（320×180 的整数倍）。放不进屏幕的档位会跳过。"},
		{"key": "vsync", "label": "垂直同步", "type": "toggle", "desc": "与显示器刷新率同步，避免画面撕裂。"},
		{"key": "post_fx", "label": "后期效果", "type": "toggle",
			"desc": "暗角、扫描线和胶片颗粒。死亡、警戒等玩法提示不受影响。"},
		{"key": "shake", "label": "屏幕震动", "type": "slider", "desc": "开火、击杀、落地时镜头晃动的幅度。0% 为关闭。"},
		{"key": "flash", "label": "闪光强度", "type": "slider", "desc": "击杀闪白和色差脉冲的强度。对闪光敏感可以调低。"},
		{"label": "恢复默认", "type": "reset", "keys": ["fullscreen", "window_scale", "vsync", "post_fx", "shake", "flash"],
			"desc": "把本页设置恢复为默认值。"},
	]},
	{"name": "声音", "rows": [
		{"key": "music", "label": "音乐", "type": "toggle", "desc": "背景音乐开关。当前版本还没有背景音乐，加入后即生效。"},
		{"key": "sfx", "label": "音效", "type": "toggle", "desc": "动作、武器、守卫与界面音效。"},
		{"label": "恢复默认", "type": "reset", "keys": ["music", "sfx"], "desc": "把本页设置恢复为默认值。"},
	]},
	{"name": "游戏", "rows": [
		{"key": "show_timer", "label": "显示计时", "type": "toggle", "desc": "关卡右上角的用时。关闭后通关时间照常记录。"},
		{"key": "unlock_all", "label": "解锁全部关卡", "type": "toggle",
			"desc": "不用按顺序通关，直接开放全部关卡。不改动存档里的进度。"},
		{"label": "恢复默认", "type": "reset", "keys": ["show_timer", "unlock_all"], "desc": "把本页设置恢复为默认值。"},
	]},
	{"name": "操作", "rows": [
		{"label": "移动", "type": "keys", "keys": ["A", "D"]},
		{"label": "跳跃 / 二段跳", "type": "keys", "keys": ["空格"]},
		{"label": "瞄准", "type": "keys", "keys": ["鼠标"]},
		{"label": "开火 / 收回回旋镖", "type": "keys", "keys": ["左键"]},
		{"label": "重新开始", "type": "keys", "keys": ["R"]},
		{"label": "暂停", "type": "keys", "keys": ["ESC"]},
	]},
]

var tab := 0
var _anim := {}             ## 开关滑动动画：key → 0..1
var _pop := {}              ## 分段条弹跳：key → [格子序号, 剩余]
var _tab_k := 1.0           ## 换分页时行内容淡入


func _rows() -> Array:
	return TABS[tab]["rows"]


func _row(i: int) -> Dictionary:
	return _rows()[i - 1]


func _focusable() -> bool:
	return tab != 3


func row_count() -> int:
	return 1 + (_rows().size() if _focusable() else 0)


func row_rect(i: int) -> Rect2:
	if i == 0:
		return Rect2(X, 38, TABS.size() * (TAB_W + 2) - 2, 11)
	return Rect2(X, Y0 + (i - 1) * STEP, ROW_W, 11)


func row_enabled(i: int) -> bool:
	if i == 0:
		return true
	var r := _row(i)
	if r.get("key", "") == "window_scale":
		return not Settings.get_value("fullscreen")
	return true


func switch_tab(d: int) -> void:
	tab = wrapi(tab + d, 0, TABS.size())
	_tab_k = 0.0
	Sfx.play("ui_tab", 0.03)
	if focus >= row_count():
		focus = 0
	_squash = 1.0


func on_action(a: String) -> void:
	match a:
		"tab_prev":
			switch_tab(-1)
		"tab_next":
			switch_tab(1)
		"left", "right":
			var d := -1 if a == "left" else 1
			if focus == 0:
				switch_tab(d)
			else:
				_adjust(focus, d)
		"accept":
			if focus == 0:
				switch_tab(1)
			else:
				_adjust(focus, 0)
		_:
			super.on_action(a)


func on_click(p: Vector2) -> void:
	var lp := p - Vector2(slide, 0)
	if row_rect(0).has_point(lp):
		var t := int((lp.x - X) / (TAB_W + 2))
		if t >= 0 and t < TABS.size() and t != tab:
			switch_tab(t - tab)
		focus = 0
		return
	var i := row_at(p)
	if i <= 0 or not row_enabled(i):
		return
	if i != focus:
		set_focus(i, false)
	var r := _row(i)
	match r["type"]:
		"choice":
			_adjust(i, -1 if lp.x < X + 151 else 1)
		"slider":
			var seg := int((lp.x - (X + 122)) / 4.0)
			if seg >= -1 and seg <= 10:
				_apply_value(r["key"], clampi(seg + 1, 0, 10), true)
		_:
			_adjust(i, 0)


## d = -1 / 1 左右调整；0 = 确认键（开关翻转、选项往后切）
func _adjust(i: int, d: int) -> void:
	if not row_enabled(i):
		deny()
		return
	var r := _row(i)
	match r["type"]:
		"toggle":
			_apply_value(r["key"], not bool(Settings.get_value(r["key"])))
		"choice":
			var vals: Array = r["values"]
			var idx := vals.find(Settings.get_value(r["key"]))
			var step := 1 if d == 0 else d
			for k in vals.size():
				idx = wrapi(idx + step, 0, vals.size())
				if r["key"] != "window_scale" or int(vals[idx]) <= Settings.max_scale():
					break
			_apply_value(r["key"], vals[idx])
		"slider":
			if d == 0:
				return
			var v := clampi(int(Settings.get_value(r["key"])) + d, 0, 10)
			if v == int(Settings.get_value(r["key"])):
				deny()
				return
			_apply_value(r["key"], v)
		"reset":
			Settings.reset(r["keys"])
			_blink = 0.24
			Sfx.play("ui_confirm")
			host.fx("ui_burst", Vector2(X - 2 + slide, row_rect(i).get_center().y))


func _apply_value(key: String, value: Variant, _from_click := false) -> void:
	var old: Variant = Settings.get_value(key)
	Settings.set_value(key, value)
	if value is int and old is int and key != "window_scale":
		_pop[key] = [maxi(int(value) - 1, 0), 1.0]
		Sfx.play("ui_tick", 0.0, 0.0, 0.8 + 0.05 * int(value))
	else:
		Sfx.play("ui_toggle", 0.04)
	var rr := row_rect(focus)
	host.fx("ui_spark", Vector2(X + ROW_W - 4 + slide, rr.get_center().y))


func update(dt: float) -> void:
	_tab_k = minf(_tab_k + dt / 0.15, 1.0)
	for r in _rows():
		if r.get("type", "") == "toggle":
			var want := 1.0 if Settings.get_value(r["key"]) else 0.0
			_anim[r["key"]] = move_toward(float(_anim.get(r["key"], want)), want, dt / 0.09)
	for k in _pop:
		_pop[k][1] = maxf(_pop[k][1] - dt * 6.0, 0.0)

# ======================= 绘制 =======================

func _draw() -> void:
	draw_rect(Rect2(-40, -10, 400, 200), Color(Palette.N0, 0.6))
	UiKit.title(self, Vector2(20, 27), "设置", 12)
	UiKit.num(self, Vector2(50, 27), "SETTINGS", Color(Palette.C1, 0.9))
	draw_rect(Rect2(20, 32, 280, 1), Color(Palette.C1, 0.6))
	draw_rect(Rect2(20, 31, 14, 2), Palette.P3)
	_draw_tabs()
	var rows := _rows()
	UiKit.panel(self, Rect2(X - 6, Y0 - 3, ROW_W + 8, rows.size() * STEP + 4), true, 0.6, false)
	if focus > 0:
		draw_focus(ROW_W)
	var a := ease(_tab_k, 0.4)
	for i in range(1, rows.size() + 1):
		_draw_row(i, a)
	_draw_desc()
	var hints := [[["W", "S"], "选择"], [["A", "D"], "调整"], [["Q", "E"], "分页"], [["ESC"], "返回"]]
	if not _focusable():
		hints = [[["Q", "E"], "分页"], [["ESC"], "返回"]]
	UiKit.hints(self, Vector2(20, 164), hints)


func _draw_tabs() -> void:
	for t in TABS.size():
		var r := Rect2(X + t * (TAB_W + 2), 38, TAB_W, 11)
		var on := t == tab
		draw_rect(r, Color(Palette.N3, 0.95) if on else Color(Palette.N1, 0.85))
		if on:
			draw_rect(Rect2(r.position.x, r.end.y, r.size.x, 1), Palette.P3)
		var name: String = TABS[t]["name"]
		var w := UiKit.width(UiFonts.text(), name, 6)
		UiKit.zh(self, Vector2(r.position.x + roundf((TAB_W - w) / 2.0), r.position.y + 8), name,
			Palette.C4 if on else Color(Palette.C1, 1))
		if on and focus == 0:
			UiKit.brackets(self, r.grow(1), Palette.C2, 2)


func _draw_row(i: int, a: float) -> void:
	var r := _row(i)
	var rr := row_rect(i)
	var y := rr.position.y
	var en := row_enabled(i)
	var lc := row_color(i) if _focusable() else Color(Palette.C3, 0.85)
	lc.a *= a
	var dx := shift(i) if _focusable() else 0.0
	if i == focus:
		dx += deny_offset()
	UiKit.zh(self, Vector2(X + 4 + dx, y + 8), r["label"], lc)
	var vx := X + 122.0
	var vc := Color(Palette.C4 if i == focus else Palette.C3, a * (1.0 if en else 0.4))
	match r["type"]:
		"toggle":
			var k := float(_anim.get(r["key"], 1.0 if Settings.get_value(r["key"]) else 0.0))
			var on := bool(Settings.get_value(r["key"]))
			UiKit.zh(self, Vector2(vx + 30, y + 8), "开" if on else "关", vc)
			UiKit.switch(self, Vector2(X + ROW_W - 17, y + 2), k, a)
		"choice":
			var vals: Array = r["values"]
			var idx := maxi(vals.find(Settings.get_value(r["key"])), 0)
			var s: String = r["names"][idx]
			var font := UiFonts.text()
			var w := UiKit.width(font, s, 6)
			UiKit.zh(self, Vector2(roundf(vx + 29 - w / 2.0), y + 8), s, vc)
			var ac := Color(Palette.P3 if i == focus else Palette.C1, vc.a)
			UiKit.arrow(self, Vector2(vx + 2, y + 5), -1, ac)
			UiKit.arrow(self, Vector2(X + ROW_W - 4, y + 5), 1, ac)
		"slider":
			var v := int(Settings.get_value(r["key"]))
			var pop: Array = _pop.get(r["key"], [-1, 0.0])
			UiKit.segments(self, Vector2(vx, y + 2), v, 10, Color(Palette.P3 if i == focus else Palette.C2, a), pop[0], pop[1] * 2.0)
			var pct := "%d%%" % (v * 10)
			UiKit.num(self, Vector2(X + ROW_W - 2 - UiKit.width(UiFonts.num(), pct, 8), y + 8), pct, vc)
		"reset":
			UiKit.arrow(self, Vector2(X + ROW_W - 4, y + 5), 1, Color(Palette.C1, a))
		"keys":
			var x := X + ROW_W - 2
			var caps: Array = r["keys"]
			for k in range(caps.size() - 1, -1, -1):
				x -= UiKit._cap_w(caps[k])
				UiKit.keycap(self, Vector2(x, y + 1), caps[k], a)
				x -= 3


## 右侧说明框：当前行标题（金色）+ 折行说明
func _draw_desc() -> void:
	UiKit.panel(self, DESC, false, 0.8)
	var label := TABS[tab]["name"] as String
	var text := "用 A / D、Q / E 或鼠标点击切换分页。"
	if focus > 0:
		var r := _row(focus)
		label = r["label"]
		text = r.get("desc", "")
		if r.get("key", "") == "window_scale":
			var s := int(Settings.get_value("window_scale"))
			text += "\n当前 %d×%d" % [320 * s, 180 * s]
	elif not _focusable():
		text = "键位不能修改。鼠标控制瞄准方向，点击开火。"
	UiKit.zh(self, DESC.position + Vector2(5, 10), label, Palette.W3)
	draw_rect(Rect2(DESC.position.x + 5, DESC.position.y + 13, 12, 1), Color(Palette.P3, 0.8))
	var lines := UiKit.wrap(text, DESC.size.x - 10, UiFonts.text(), 6)
	for li in lines.size():
		UiKit.zh(self, DESC.position + Vector2(5, 23 + li * 9), lines[li], Color(Palette.C3, 0.9))
