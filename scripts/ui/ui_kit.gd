class_name UiKit
extends RefCounted
## 菜单 / 暂停界面共用的绘制件。坐标是 320×180 画布单位，和 HUD 同一套：
## 一个单位 = 一个游戏像素；字体在根视口按窗口分辨率渲染，所以半格字依然锐利。
## 字号规范：
##   big 24   主标题（粗宋，一个字体像素 = 2 游戏像素）
##   big 12   页面标题（粗宋，1:1）
##   text 12  主菜单 / 暂停菜单选项（缝合像素 12px，1:1）
##   text 6   正文、设置行、说明（半格，与 HUD 一致）
##   num 8    数字、英文小标（m6x11 半格）
## 颜色角色：正文 C3，强调 C4，结构线 C1 / C2，选中标记 P3（玩家品红），标题与纪录 W3，禁用 N5。

const PANEL_A := 0.78


static func now() -> float:
	return Time.get_ticks_usec() / 1000000.0


## 只含 ASCII（用 m6x11）还是含中文（用缝合像素）。不用 to_ascii_buffer：遇到中文会刷错误日志
static func is_ascii(s: String) -> bool:
	for i in s.length():
		if s.unicode_at(i) > 127:
			return false
	return true


static func width(font: Font, s: String, size: int) -> float:
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## 文字 + 右下 1 格（或半格）暗色投影
static func text(ci: CanvasItem, font: Font, at: Vector2, s: String, size: int, col: Color, shadow := 0.5) -> void:
	if shadow > 0.0:
		ci.draw_string(font, at + Vector2(shadow, shadow), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.6 * col.a))
	ci.draw_string(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


## 中文正文（半格）
static func zh(ci: CanvasItem, at: Vector2, s: String, col: Color, size := 6) -> void:
	text(ci, UiFonts.text(), at, s, size, col, 0.5 if size <= 6 else 1.0)


## 数字 / 英文（m6x11）
static func num(ci: CanvasItem, at: Vector2, s: String, col: Color, size := 8) -> void:
	text(ci, UiFonts.num(), at, s, size, col, 0.5)


## 标题：金色 W3 + 粉色 P2 投影（与关卡横幅同款）
static func title(ci: CanvasItem, at: Vector2, s: String, size: int, a := 1.0) -> void:
	var f := UiFonts.big()
	var off := 0.5 if size <= 12 else 1.0
	ci.draw_string(f, at + Vector2(off, off), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(Palette.P2, a))
	ci.draw_string(f, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(Palette.W3, a))


## 半透明暗底面板，一侧 4 级斜切（HUD 同款）；edge：下沿 C1 细线
static func panel(ci: CanvasItem, r: Rect2, slant_right := true, a := PANEL_A, edge := true) -> void:
	var c := Color(Palette.N0, a)
	ci.draw_rect(r, c)
	var steps := 4
	var h := r.size.y
	for i in steps:
		var x := r.end.x + i if slant_right else r.position.x - 1 - i
		var hh := roundf(h * (1.0 - float(i + 1) / (steps + 1)))
		ci.draw_rect(Rect2(x, r.position.y, 1, hh), c)
	if edge:
		ci.draw_rect(Rect2(r.position.x, r.end.y, r.size.x, 1), Color(Palette.C1, 0.7 * a / PANEL_A))


## 选中横带：从左往右展开（k 0..1），右端斜切
static func band(ci: CanvasItem, r: Rect2, k: float, col := Color(Palette.N3, 0.85)) -> void:
	var w := roundf(r.size.x * k)
	if w <= 0.0:
		return
	ci.draw_rect(Rect2(r.position, Vector2(w, r.size.y)), col)
	for i in 3:
		ci.draw_rect(Rect2(r.position.x + w + i, r.position.y, 1, r.size.y - (i + 1) * roundf(r.size.y / 4.0)), col)


## 四角括号（选中 / 可交互），arm 是每条边的长度
static func brackets(ci: CanvasItem, r: Rect2, c: Color, arm := 2) -> void:
	var x0 := roundf(r.position.x)
	var y0 := roundf(r.position.y)
	var x1 := roundf(r.end.x) - 1
	var y1 := roundf(r.end.y) - 1
	for p in [[x0, y0, 1, 1], [x1, y0, -1, 1], [x0, y1, 1, -1], [x1, y1, -1, -1]]:
		for i in arm + 1:
			ci.draw_rect(Rect2(p[0] + i * p[2], p[1], 1, 1), c)
			ci.draw_rect(Rect2(p[0], p[1] + i * p[3], 1, 1), c)


## 1px 实心三角箭头（dir = -1 左，1 右），尖端在 at
static func arrow(ci: CanvasItem, at: Vector2, dir: int, c: Color, size := 3) -> void:
	for k in size:
		ci.draw_rect(Rect2(at.x - dir * k, at.y - k, 1, 1 + k * 2), c)


## 分段条：n 格，亮 on 格；pop_i 那一格弹高 1px
static func segments(ci: CanvasItem, at: Vector2, on: int, n: int, col: Color, pop_i := -1, pop := 0.0) -> void:
	for i in n:
		var lit := i < on
		var h := 5.0 + (roundf(pop) if i == pop_i else 0.0)
		var c := col if lit else Color(Palette.N4, 0.9)
		ci.draw_rect(Rect2(at.x + i * 4, at.y + 5 - h, 3, h), c)
		if lit:
			ci.draw_rect(Rect2(at.x + i * 4, at.y + 5 - h, 3, 1), Color(minf(col.r * 1.4, 1), minf(col.g * 1.4, 1), minf(col.b * 1.4, 1), col.a))


## 拨动开关 15×7：k 0 = 关，1 = 开（中间值用于滑动动画）
static func switch(ci: CanvasItem, at: Vector2, k: float, a := 1.0) -> void:
	var on := k >= 0.5
	var track := Color(Palette.P2, a) if on else Color(Palette.N3, a)
	ci.draw_rect(Rect2(at + Vector2(1, 0), Vector2(13, 7)), track)
	ci.draw_rect(Rect2(at + Vector2(0, 1), Vector2(15, 5)), track)
	var kx := roundf(lerpf(1.0, 8.0, k))
	var knob := Color(Palette.C4, a) if on else Color(Palette.N6, a)
	ci.draw_rect(Rect2(at + Vector2(kx, 1), Vector2(6, 5)), knob)
	ci.draw_rect(Rect2(at + Vector2(kx, 5), Vector2(6, 1)), Color(knob.r * 0.7, knob.g * 0.7, knob.b * 0.8, a))


## 键帽：暗底 + 下沿厚度，文字居中。返回宽度，方便连排
static func keycap(ci: CanvasItem, at: Vector2, label: String, a := 1.0) -> float:
	var ascii := is_ascii(label)
	var f := UiFonts.num() if ascii else UiFonts.text()
	var fs := 8 if ascii else 6
	var w := maxf(roundf(width(f, label, fs)) + 4.0, 9.0)
	ci.draw_rect(Rect2(at, Vector2(w, 8)), Color(Palette.N4, a))
	ci.draw_rect(Rect2(at + Vector2(0, 8), Vector2(w, 1)), Color(Palette.N1, a))
	ci.draw_rect(Rect2(at, Vector2(w, 1)), Color(Palette.N6, a))
	var tx := at.x + roundf((w - width(f, label, fs)) / 2.0)
	ci.draw_string(f, Vector2(tx, at.y + (6.5 if ascii else 6.5)), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Palette.C4, a))
	return w


## 底部操作提示：[[键, 说明], ...]，从 at 往右排；right=true 时右对齐到 at.x
static func hints(ci: CanvasItem, at: Vector2, items: Array, a := 1.0, right := false) -> void:
	var total := 0.0
	var font := UiFonts.text()
	for it in items:
		for k in (it[0] as Array):
			total += _cap_w(k) + 2.0
		total += width(font, it[1], 6) + 8.0
	var x := at.x - total + 8.0 if right else at.x
	for it in items:
		for k in (it[0] as Array):
			x += keycap(ci, Vector2(x, at.y), k, a) + 2.0
		zh(ci, Vector2(x + 1, at.y + 6.5), it[1], Color(Palette.C2, 0.85 * a))
		x += width(font, it[1], 6) + 8.0


static func _cap_w(label: String) -> float:
	var ascii := is_ascii(label)
	var f := UiFonts.num() if ascii else UiFonts.text()
	return maxf(roundf(width(f, label, 8 if ascii else 6)) + 4.0, 9.0)


## 7×8 小锁
static func lock_icon(ci: CanvasItem, at: Vector2, c: Color) -> void:
	ci.draw_rect(Rect2(at + Vector2(2, 0), Vector2(3, 1)), c)
	ci.draw_rect(Rect2(at + Vector2(1, 1), Vector2(1, 3)), c)
	ci.draw_rect(Rect2(at + Vector2(5, 1), Vector2(1, 3)), c)
	ci.draw_rect(Rect2(at + Vector2(0, 3), Vector2(7, 5)), c)
	ci.draw_rect(Rect2(at + Vector2(3, 5), Vector2(1, 2)), Color(Palette.N0, c.a))


## 菜单光标：品红像素箭头，深色描边，热点在左上角
const _CURSOR := [
	"X.......", "XX......", "XoX.....", "XooX....", "XoooX...", "XooooX..",
	"XoooooX.", "XooXXXX.", "XoX.....", "XX......",
]


static func cursor(ci: CanvasItem, at: Vector2, a := 1.0) -> void:
	var p := at.round()
	for y in _CURSOR.size():
		var row: String = _CURSOR[y]
		for x in row.length():
			var ch := row[x]
			if ch == "X":
				ci.draw_rect(Rect2(p + Vector2(x, y), Vector2.ONE), Color(Palette.N0, a))
			elif ch == "o":
				var c := Palette.C4 if x == 1 else Palette.P3
				ci.draw_rect(Rect2(p + Vector2(x, y), Vector2.ONE), Color(c, a))


## 按宽度折行（中文按字、英文按词），返回行数组
static func wrap(s: String, max_w: float, font: Font, size: int) -> PackedStringArray:
	var lines := PackedStringArray()
	for para in s.split("\n"):
		var line := ""
		for ch in para:
			if width(font, line + ch, size) > max_w and line != "":
				lines.append(line)
				line = "" if ch == " " else ch
			else:
				line += ch
		lines.append(line)
	return lines
