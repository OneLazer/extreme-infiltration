class_name LevelSelectPage
extends MenuPage
## 选择关卡：左边 12 行编号列表（最佳用时），右边一块「监控画面」预览。
## 预览从关卡场景里直接读出来画（墙体、高压电、守卫、出口、起点、武器），改关卡后自动更新。
## 换关时像监控换台：一阵静电 + 画面上下滚一下；未解锁的关只有雪花和 NO SIGNAL。

const X := 20.0
const Y0 := 42.0
const STEP := 10.0
const LIST_W := 96.0
const VIEW := Rect2(130, 42, 170, 96)        ## 监控画面
const INFO_Y := 145.0

const C_ELECTRIC := Color("#ff2a5a")
const C_GROUND := Color("#ffb347")
const C_DRONE := Color("#ffe066")
const C_CAMERA := Color("#ff4f4f")
const C_EXIT := Color("#5dff8a")

static var _cache := {}     ## 关卡序号 → 预览数据

var menu: MainMenu
var _switch := 1.0          ## 换台动画 0 → 1
var _shown := -1            ## 预览当前显示的关
var _scan_i := 0            ## 后台逐帧预读的进度
var _rec := 0.0


func _ready() -> void:
	focus = clampi(Progress.resume_index(), 0, Levels.count() - 1)


func row_count() -> int:
	return Levels.count()


func row_rect(i: int) -> Rect2:
	return Rect2(X, Y0 + i * STEP, LIST_W, 9)


func activate(i: int) -> void:
	if not Progress.is_unlocked(i):
		deny()
		return
	confirm(func(): menu.start_game(i), "start")


func set_focus(i: int, sound := true) -> void:
	super.set_focus(i, sound)
	_switch = 0.0
	Sfx.play("ui_channel", 0.05, -4.0)


func update(dt: float) -> void:
	_switch = minf(_switch + dt / 0.18, 1.0)
	_rec += dt
	if not _cache.has(focus):
		_cache[focus] = _scan(focus)
	elif _scan_i < Levels.count():        # 每帧顺带预读一关，切换时不卡
		if not _cache.has(_scan_i):
			_cache[_scan_i] = _scan(_scan_i)
		_scan_i += 1
	if _switch >= 0.5:
		_shown = focus


## 把关卡场景实例化（不进场景树）读出预览数据：墙体 / 电块烘成 1 格 = 1 像素的小图，
## 守卫、出口、起点、武器记成图格坐标，画的时候再按比例放大
static func _scan(i: int) -> Dictionary:
	var ps := load(Levels.path(i)) as PackedScene
	if ps == null:
		return {}
	var root := ps.instantiate()
	var d := {"guards": [], "items": [], "exit": Vector2(-1, -1), "start": Vector2(-1, -1),
		"weapon": int(root.get("initial_weapon")) if root.get("initial_weapon") != null else 0,
		"dj": bool(root.get("allow_double_jump")) if root.get("allow_double_jump") != null else true}
	var walls := root.get_node_or_null("Walls") as TileMapLayer
	var electric: Array = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var p := _pos(n, root) / Game.TILE
		if n is ElectricLayer:
			electric.append(n)
		elif n is Guard:
			var sp := str(n.get_script().resource_path)
			var col := C_CAMERA if sp.contains("camera") else (C_DRONE if sp.contains("flying") else C_GROUND)
			d["guards"].append([p, col])
		elif n is Player:
			d["start"] = p
		elif n is LevelExit:
			d["exit"] = p
		elif n is WeaponPickup:
			d["items"].append([p, _flat(WeaponDefs.get_def(n.weapon_type)["color"])])
		elif n is WeaponZone or n is TimerGate:
			var col2 := _flat(Palette.TIMER) if n is TimerGate else _flat(WeaponDefs.get_def(n.weapon_type)["color"])
			d["items"].append([p + Vector2(0.5, 1.0), col2])
	var r := walls.get_used_rect() if walls else Rect2i(0, 0, 40, 23)
	d["rect"] = r
	var img := Image.create(maxi(r.size.x, 1), maxi(r.size.y, 1), false, Image.FORMAT_RGBA8)
	if walls:
		for c in walls.get_used_cells():
			var edge := false
			for o in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if walls.get_cell_source_id(c + o) < 0:
					edge = true
			img.set_pixelv(c - r.position, Palette.C2 if edge else Palette.N3)
	for e in electric:
		for c in (e as TileMapLayer).get_used_cells():
			var q: Vector2i = c - r.position
			if Rect2i(Vector2i.ZERO, r.size).has_point(q):
				img.set_pixelv(q, C_ELECTRIC if (q.x + q.y) % 2 == 0 else Color("#a8163c"))
	d["tex"] = ImageTexture.create_from_image(img)
	d["guards_n"] = d["guards"].size()
	root.free()
	return d


static func _pos(n: Node, root: Node) -> Vector2:
	var p := Vector2.ZERO
	while n != null and n != root:
		if n is Node2D:
			p = (n as Node2D).transform * p
		n = n.get_parent()
	return p


## HDR 玩法色压回 0..1（UI 层没有辉光，直接用会过曝成白）
static func _flat(c: Color) -> Color:
	var m := maxf(c.r, maxf(c.g, c.b))
	return Color(c.r / m, c.g / m, c.b / m) if m > 1.0 else c

# ======================= 绘制 =======================

func _draw() -> void:
	draw_rect(Rect2(-40, -10, 400, 200), Color(Palette.N0, 0.55))
	UiKit.title(self, Vector2(20, 27), "选择关卡", 12)
	UiKit.num(self, Vector2(74, 27), "SELECT LEVEL", Color(Palette.C1, 0.9))
	draw_rect(Rect2(20, 32, 280, 1), Color(Palette.C1, 0.6))
	draw_rect(Rect2(20, 31, 14, 2), Palette.P3)
	# 列表底板
	UiKit.panel(self, Rect2(X - 6, Y0 - 3, LIST_W + 8, row_count() * STEP + 4), true, 0.6, false)
	draw_focus(LIST_W)
	for i in row_count():
		_draw_row(i)
	_draw_view()
	_draw_info()
	UiKit.hints(self, Vector2(20, 164), [[["W", "S"], "选择"], [["空格"], "进入"], [["ESC"], "返回"]])
	var done := 0
	for i in Levels.count():
		if Progress.is_cleared(i):
			done += 1
	var s := "%d/%d" % [done, Levels.count()]
	UiKit.num(self, Vector2(300 - UiKit.width(UiFonts.num(), s, 8), 27), s, Color(Palette.C2, 0.9))


func _draw_row(i: int) -> void:
	var r := row_rect(i)
	var unlocked := Progress.is_unlocked(i)
	var x := r.position.x + 4 + shift(i) + (deny_offset() if i == focus else 0.0)
	var base_y := r.position.y + 7
	var c := row_color(i)
	if not unlocked:
		c = Color(Palette.N5, 1.0) if i != focus else Color(Palette.N6, 1.0)
		UiKit.lock_icon(self, Vector2(x, r.position.y + 1), c)
		UiKit.num(self, Vector2(x + 10, base_y), Levels.label(i), c)
		return
	UiKit.num(self, Vector2(x, base_y), Levels.label(i), c)
	var bt := Progress.best_time(i)
	var ts := Levels.fmt_time(bt) if bt >= 0.0 else "--:--.--"
	var tc := Color(Palette.W3, 0.95 if i == focus else 0.7) if bt >= 0.0 else Color(Palette.N5, 1.0)
	UiKit.num(self, Vector2(r.end.x - 3 - UiKit.width(UiFonts.num(), ts, 8), base_y), ts, tc)
	if bt >= 0.0:     # 通关标记：编号后一颗小菱形
		var dx := x + UiKit.width(UiFonts.num(), "000", 8) + 3
		var dc := Color(Palette.P3, 0.9 if i == focus else 0.55)
		draw_rect(Rect2(dx + 1, r.position.y + 3, 1, 3), dc)
		draw_rect(Rect2(dx, r.position.y + 4, 3, 1), dc)


## 监控画面：暗底 + 边框 + 角括号，左上 CAM 编号，右上 REC 红点和时间码，画面里是关卡缩略图 + 扫描线
func _draw_view() -> void:
	var v := VIEW
	draw_rect(v, Color(Palette.N0, 0.92))
	draw_rect(Rect2(v.position, Vector2(v.size.x, 1)), Color(Palette.N4, 1))
	draw_rect(Rect2(v.position.x, v.end.y - 1, v.size.x, 1), Color(Palette.N4, 1))
	draw_rect(Rect2(v.position, Vector2(1, v.size.y)), Color(Palette.N4, 1))
	draw_rect(Rect2(v.end.x - 1, v.position.y, 1, v.size.y), Color(Palette.N4, 1))
	UiKit.brackets(self, v.grow(2), Palette.C2, 3)
	var inner := v.grow(-4)
	inner.position.y += 8
	inner.size.y -= 8
	var idx := _shown if _shown >= 0 else focus
	var roll := 0.0
	if _switch < 1.0:
		roll = roundf(sin(_switch * PI) * 6.0)
	if Progress.is_unlocked(idx) and _cache.has(idx) and not _cache[idx].is_empty():
		_draw_map(_cache[idx], inner, roll)
	else:
		_draw_static(inner, 1.0)
		var msg := "NO SIGNAL"
		var mw := UiKit.width(UiFonts.num(), msg, 8)
		var cx := inner.get_center().x
		draw_rect(Rect2(cx - mw / 2 - 6, inner.get_center().y - 10, mw + 12, 20), Color(Palette.N0, 0.85))
		UiKit.num(self, Vector2(roundf(cx - mw / 2), inner.get_center().y - 1), msg, Palette.C3)
		UiKit.lock_icon(self, Vector2(roundf(cx - 10), inner.get_center().y + 2), Palette.N6)
		UiKit.zh(self, Vector2(roundf(cx - 1), inner.get_center().y + 8), "未解锁", Color(Palette.N6, 1))
	if _switch < 1.0:
		_draw_static(inner, 1.0 - _switch)
	# 扫描线
	for y in range(int(inner.position.y), int(inner.end.y), 2):
		draw_rect(Rect2(inner.position.x, y, inner.size.x, 1), Color(0, 0, 0, 0.22))
	# 顶部信息条
	UiKit.num(self, v.position + Vector2(4, 9), "CAM-" + Levels.label(focus), Palette.C2)
	var blink := fmod(_rec, 1.0) < 0.6
	var secs := int(_rec)
	var tc := "%02d:%02d:%02d" % [secs / 3600, (secs / 60) % 60, secs % 60]
	var tw := UiKit.width(UiFonts.num(), tc, 8)
	UiKit.num(self, Vector2(v.end.x - 4 - tw, v.position.y + 9), tc, Color(Palette.C3, 0.85))
	var rx := v.end.x - 4 - tw - 22
	if blink:
		draw_rect(Rect2(rx, v.position.y + 4, 3, 3), Color("#ff3a3a"))
		draw_rect(Rect2(rx + 1, v.position.y + 3, 1, 5), Color("#ff3a3a"))
		draw_rect(Rect2(rx - 1, v.position.y + 5, 5, 1), Color("#ff3a3a"))
	UiKit.num(self, Vector2(rx + 6, v.position.y + 9), "REC", Color(Palette.C3, 0.85))


## 雪花噪点：k 是强度（换台时从 1 退到 0）
func _draw_static(r: Rect2, k: float) -> void:
	var n := int(220 * k)
	var seed := int(UiKit.now() * 30.0)
	for i in n:
		var h := hash(Vector2i(seed, i))
		var x := r.position.x + float(h % int(r.size.x))
		var y := r.position.y + float((h / 977) % int(r.size.y))
		var w := 1 + (h / 31) % 3
		var lum := 0.25 + float((h / 7) % 100) / 140.0
		draw_rect(Rect2(x, y, minf(w, r.end.x - x), 1), Color(lum * 0.8, lum * 0.85, lum, 0.85 * k))
	# 一条滚动的亮带
	var by := r.position.y + fposmod(UiKit.now() * 90.0, r.size.y)
	draw_rect(Rect2(r.position.x, by, r.size.x, 1), Color(Palette.C3, 0.25 * k))


func _draw_map(d: Dictionary, inner: Rect2, roll: float) -> void:
	var rect: Rect2i = d["rect"]
	var fit := minf(inner.size.x / rect.size.x, inner.size.y / rect.size.y)
	var s := floorf(fit) if fit >= 1.0 else fit
	var size := Vector2(rect.size) * s
	var origin := (inner.position + (inner.size - size) / 2.0).round() + Vector2(0, roll)
	draw_texture_rect(d["tex"], Rect2(origin, size), false)
	var to := func(p: Vector2) -> Vector2: return (origin + (p - Vector2(rect.position)) * s).round()
	var blink := fmod(_rec, 0.8) < 0.55
	for it in d["items"]:
		draw_rect(Rect2(to.call(it[0]) - Vector2(1, 1), Vector2(2, 2)), it[1])
	if d["exit"].x >= 0.0:
		var e: Vector2 = to.call(d["exit"])
		draw_rect(Rect2(e - Vector2(1, 3), Vector2(3, 4)), C_EXIT)
	for g in d["guards"]:
		var p: Vector2 = to.call(g[0])
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), g[1] if blink else Color(g[1], 0.45))
	if d["start"].x >= 0.0:
		var p0: Vector2 = to.call(d["start"])
		draw_rect(Rect2(p0 - Vector2(1, 2), Vector2(2, 3)), Palette.P3)
		var pr := 2.0 + fmod(_rec * 6.0, 4.0)       # 起点外一圈扩散的小方框
		UiKit.brackets(self, Rect2(p0 - Vector2(pr, pr), Vector2(pr * 2, pr * 2)), Color(Palette.P3, 1.0 - (pr - 2.0) / 4.0), 0)


## 预览下方一行：守卫数、初始武器、二段跳、最佳用时
func _draw_info() -> void:
	var r := Rect2(VIEW.position.x, INFO_Y, VIEW.size.x, 12)
	UiKit.panel(self, r, false, 0.8)
	var i := focus
	if not Progress.is_unlocked(i) or not _cache.has(i) or _cache[i].is_empty():
		UiKit.zh(self, r.position + Vector2(5, 8.5), "通关上一关后解锁", Color(Palette.N6, 1))
		return
	var d: Dictionary = _cache[i]
	var x := r.position.x + 5
	_guard_icon(Vector2(x, r.position.y + 3))
	UiKit.num(self, Vector2(x + 9, r.position.y + 9), "x%d" % d["guards_n"], Palette.W3)
	x += 26
	var w: int = d["weapon"]
	var def := WeaponDefs.get_def(w)
	if WeaponDefs.is_none(w):
		UiKit.zh(self, Vector2(x, r.position.y + 8.5), "徒手", Color(Palette.C3, 0.9))
	else:
		var rr := Prop.rect_of(Hud.ICON.get(w, "icon_dart"))
		draw_texture_rect_region(Hud.PROPS, Rect2(Vector2(x, r.position.y + 2), rr.size), rr)
		UiKit.zh(self, Vector2(x + 10, r.position.y + 8.5), def["name"], Color(Palette.C3, 0.9))
	x += 48
	UiKit.zh(self, Vector2(x, r.position.y + 8.5), "二段跳", Color(Palette.C3, 0.9))
	var cx := x + 20
	if d["dj"]:
		for k in [Vector2(0, 2), Vector2(1, 3), Vector2(2, 2), Vector2(3, 1), Vector2(4, 0)]:
			draw_rect(Rect2(Vector2(cx, r.position.y + 3) + k, Vector2.ONE), C_EXIT)
	else:
		for k in 4:
			draw_rect(Rect2(cx + k, r.position.y + 3 + k, 1, 1), C_CAMERA)
			draw_rect(Rect2(cx + 3 - k, r.position.y + 3 + k, 1, 1), C_CAMERA)
	var bt := Progress.best_time(i)
	var s := Levels.fmt_time(bt) if bt >= 0.0 else "--:--.--"
	UiKit.num(self, Vector2(r.end.x - 4 - UiKit.width(UiFonts.num(), s, 8), r.position.y + 9), s,
		Palette.W3 if bt >= 0.0 else Color(Palette.N5, 1))


func _guard_icon(at: Vector2) -> void:
	draw_rect(Rect2(at + Vector2(1, 0), Vector2(5, 1)), Color("#73759a"))
	draw_rect(Rect2(at + Vector2(0, 1), Vector2(7, 5)), Color("#55577a"))
	draw_rect(Rect2(at + Vector2(1, 2), Vector2(5, 1)), C_GROUND)
	draw_rect(Rect2(at + Vector2(0, 5), Vector2(7, 1)), Color("#262540"))
