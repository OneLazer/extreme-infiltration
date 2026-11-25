class_name MainPage
extends MenuPage
## 主菜单首页：标题 + 五个选项（开始游戏 / 选择关卡 / 设置 / 致谢 / 退出游戏）。
## 首次启动时标题逐字闪入（RGB 错位收拢），选项依次从左滑入；之后标题每隔几秒轻微故障一下。

const TITLE := "极限潜入行动"
const SUB := "EXTREME INFILTRATION"
const ITEMS := ["开始游戏", "选择关卡", "设置", "致谢", "退出游戏"]
const X := 24.0
const Y0 := 80.0
const STEP := 16.0
const GLYPH_GAP := 0.075     ## 标题逐字间隔
const GLYPH_IN := 0.16       ## 每个字从错位到归位的时间

var menu: MainMenu
var intro := false           ## 首次启动：播标题动画
var _title_t := 99.0         ## 标题动画时间（intro 时从 0 开始）
var _typed := 0
var _glitch := 0.0
var _glitch_next := 5.0


func _ready() -> void:
	if intro:
		_title_t = -0.95       # 等显像管开机（约 0.85 秒）结束再开始打标题
		_typed = 0
	else:
		_typed = TITLE.length()


func items_at() -> float:
	return TITLE.length() * GLYPH_GAP + 0.25


func row_count() -> int:
	return ITEMS.size()


func row_rect(i: int) -> Rect2:
	var w := UiKit.width(UiFonts.text(), ITEMS[i], 12)
	return Rect2(X - 2, Y0 + i * STEP, w + 14, 14)


func update(dt: float) -> void:
	_title_t += dt
	var n := clampi(int(floor(_title_t / GLYPH_GAP)) + 1, 0, TITLE.length()) if _title_t >= 0.0 else 0
	while _typed < n:
		_typed += 1
		Sfx.play("ui_type", 0.1, 0.0, 0.9 + 0.04 * _typed)
	_glitch = maxf(_glitch - dt, 0.0)
	_glitch_next -= dt
	if _glitch_next <= 0.0:
		_glitch_next = randf_range(4.0, 7.5)
		_glitch = 0.14


## 选项 i 的入场进度 0..1（依次滑入）
func _item_k(i: int) -> float:
	var start := (items_at() if intro else 0.0) + i * 0.045
	return clampf((_title_t - start) / 0.18, 0.0, 1.0) if intro else 1.0


func _draw() -> void:
	_draw_title()
	var all_in := _item_k(ITEMS.size() - 1) >= 1.0
	if all_in:
		draw_focus(row_rect(focus).size.x)
	var font := UiFonts.text()
	for i in ITEMS.size():
		var k := _item_k(i)
		if k <= 0.0:
			continue
		var r := row_rect(i)
		var off := roundf(-12.0 * (1.0 - ease(k, 0.3)))
		var c := row_color(i)
		c.a *= k
		var at := Vector2(X + shift(i) + off, r.position.y + 11)
		UiKit.text(self, font, at, ITEMS[i], 12, c, 1.0)
		if i == 0 and Progress.has_progress():
			# 开始游戏旁边：要继续的关卡编号
			var nx := at.x + UiKit.width(font, ITEMS[0], 12) + 6
			var nc := Palette.W3 if focus == 0 else Palette.C1
			UiKit.arrow(self, Vector2(nx + 2, r.position.y + 7), 1, Color(nc, k), 3)
			UiKit.num(self, Vector2(nx + 5, r.position.y + 10), Levels.label(Progress.resume_index()), Color(nc, k))
	var foot := clampf((_title_t - items_at() - 0.3) / 0.3, 0.0, 1.0) if intro else 1.0
	UiKit.hints(self, Vector2(20, 166), [[["W", "S"], "选择"], [["空格"], "确认"]], foot)
	var ver := "v0.1"
	UiKit.num(self, Vector2(300 - UiKit.width(UiFonts.num(), ver, 8), 173), ver, Color(Palette.N6, foot))


func _draw_title() -> void:
	var f := UiFonts.big()
	var x := 20.0
	var base := Vector2(x, 50)
	var glitch_k := _glitch / 0.14
	for i in TITLE.length():
		var ch := TITLE[i]
		var w := UiKit.width(f, ch, 24)
		var age := _title_t - i * GLYPH_GAP
		if age < 0.0:
			break
		var at := base + Vector2(x - 20.0, 0)
		var k := clampf(age / GLYPH_IN, 0.0, 1.0)
		var split := roundf((1.0 - ease(k, 0.4)) * 5.0)
		if glitch_k > 0.0 and (i * 7 + int(_title_t * 30.0)) % 3 == 0:
			split = maxf(split, 2.0)
			at.x += 1
		if split > 0.0:
			draw_string(f, at + Vector2(-split, 0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(Palette.P3, 0.7))
			draw_string(f, at + Vector2(split, 0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(Palette.C2, 0.7))
		if k < 0.35:
			draw_string(f, at, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Palette.C4)   # 落位前一刻是白的
		else:
			UiKit.title(self, at, ch, 24)
		x += w
	# 副标题与分隔线：标题打完之后从左往右画出来
	var k2 := clampf((_title_t - TITLE.length() * GLYPH_GAP) / 0.3, 0.0, 1.0) if intro else 1.0
	if k2 <= 0.0:
		return
	var sx := 21.0
	var nf := UiFonts.num()
	var shown := int(ceil(SUB.length() * k2))
	for i in shown:
		var ch := SUB[i]
		UiKit.num(self, Vector2(sx, 62), ch, Color(Palette.C2, 0.9))
		sx += UiKit.width(nf, ch, 8) + 1.0
	var lw := roundf(150.0 * ease(k2, 0.3))
	draw_rect(Rect2(20, 67, lw, 1), Color(Palette.C1, 0.8))
	draw_rect(Rect2(20, 66, minf(lw, 14.0), 2), Palette.P3)


func _intro_done() -> bool:
	return not intro or _title_t >= items_at() + ITEMS.size() * 0.045 + 0.18


func on_action(a: String) -> void:
	if not _intro_done():
		_title_t = 99.0        # 开场动画期间按任意键：直接跳到结束
		_typed = TITLE.length()
		return
	super.on_action(a)


func on_click(p: Vector2) -> void:
	if _intro_done():
		super.on_click(p)


func on_mouse(p: Vector2) -> void:
	if _intro_done():
		super.on_mouse(p)


## ESC：焦点跳到「退出游戏」（再按确认才退出）
func back() -> void:
	if focus != ITEMS.size() - 1:
		set_focus(ITEMS.size() - 1)


func activate(i: int) -> void:
	match i:
		0:
			confirm(func(): menu.start_game(Progress.resume_index()), "start")
		1:
			confirm(func():
				var ls := LevelSelectPage.new()
				ls.menu = menu
				host.push(ls))
		2:
			confirm(func(): host.push(SettingsPage.new()))
		3:
			confirm(func(): host.push(CreditsPage.new()))
		4:
			confirm(func(): menu.quit_game(), "ui_back")
