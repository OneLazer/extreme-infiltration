class_name MenuPage
extends Control
## 菜单页基类：滑入滑出、焦点（选中横带 + 品红竖条 + 角括号，弹簧跟随）、确认闪烁。
## 子类实现：row_count / row_rect / row_enabled / activate / draw_page，按需覆盖 on_action。
## 坐标是 320×180 画布单位。

var host: MenuHost
var slide := 0.0            ## 横向偏移（翻页动画）
var alpha := 1.0
var leaving := false
var t := 0.0                ## 本页显示后经过的时间（真实时间）
var focus := 0

var _in_dir := 1
var _fy := 0.0              ## 焦点框 y（弹簧）
var _fv := 0.0
var _fh := 0.0              ## 焦点框高度（弹簧，换行高不同的行时平滑过渡）
var _band := 1.0            ## 横带展开进度 0..1
var _squash := 0.0          ## 竖条挤压 1 → 0
var _shift: Array[float] = []   ## 每行文字右移量
var _blink := 0.0           ## 确认闪烁剩余时间


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func enter(dir: int) -> void:
	t = 0.0
	_in_dir = dir
	visible = true
	leaving = false
	slide = MenuHost.SLIDE * dir
	alpha = 0.0
	if row_count() > 0:
		focus = clampi(focus, 0, row_count() - 1)
		var r := row_rect(focus)
		_fy = r.position.y
		_fh = r.size.y
		_band = 0.0


func tick(dt: float) -> void:
	t += dt
	if not leaving:
		var k := clampf(t / MenuHost.IN_TIME, 0.0, 1.0)
		slide = roundf(MenuHost.SLIDE * _in_dir * (1.0 - ease(k, 0.25)))
		alpha = k
	position.x = slide
	modulate.a = alpha
	_update_focus(dt)
	update(dt)
	queue_redraw()


## 子类每帧逻辑
func update(_dt: float) -> void:
	pass

# ======================= 子类接口 =======================

func row_count() -> int:
	return 0


## 第 i 行的焦点区域（画布坐标，不含 slide）
func row_rect(_i: int) -> Rect2:
	return Rect2()


func row_enabled(_i: int) -> bool:
	return true


## 确认第 i 行
func activate(_i: int) -> void:
	pass


func back() -> void:
	host.pop()

# ======================= 输入 =======================

func on_action(a: String) -> void:
	match a:
		"up":
			move_focus(-1)
		"down":
			move_focus(1)
		"accept":
			if row_count() > 0:
				activate(focus)
		"back":
			back()


func on_mouse(p: Vector2) -> void:
	var i := row_at(p)
	if i >= 0 and i != focus and row_enabled(i):
		set_focus(i)


func on_click(p: Vector2) -> void:
	var i := row_at(p)
	if i >= 0:
		if i != focus:
			set_focus(i, false)
		activate(i)


func row_at(p: Vector2) -> int:
	for i in row_count():
		if row_rect(i).grow_individual(2, 1, 2, 1).has_point(p - Vector2(slide, 0)):
			return i
	return -1


func move_focus(d: int) -> void:
	var n := row_count()
	if n == 0:
		return
	var i := focus
	for k in n:
		i = wrapi(i + d, 0, n)
		if row_enabled(i):
			break
	if i != focus:
		set_focus(i)


func set_focus(i: int, sound := true) -> void:
	focus = i
	_band = 0.0
	_squash = 1.0
	if sound:
		Sfx.play("ui_move", 0.04)
	var r := row_rect(i)
	host.fx("ui_spark", Vector2(r.position.x - 3 + slide, r.position.y + r.size.y * 0.5), Color(1.0, 1.0, 1.0, 0.9))

# ======================= 焦点动画 =======================

func _update_focus(dt: float) -> void:
	var n := row_count()
	if _shift.size() != n:
		_shift.resize(n)
		_shift.fill(0.0)
	if n == 0:
		return
	var r := row_rect(focus)
	# 欠阻尼弹簧：到位时多冲一点再回来（约 1px）
	# 分成小步积分：第一帧或卡顿时 dt 很大，一步算会发散
	var k := 900.0
	var left := dt
	while left > 0.0:
		var h := minf(left, 1.0 / 240.0)
		_fv += (k * (r.position.y - _fy) - 2.0 * sqrt(k) * 0.62 * _fv) * h
		_fy += _fv * h
		left -= h
	_fh = move_toward(_fh, r.size.y, dt * 120.0)
	_band = minf(_band + dt / 0.11, 1.0)
	_squash = maxf(_squash - dt * 7.0, 0.0)
	_blink = maxf(_blink - dt, 0.0)
	_deny = maxf(_deny - dt * 3.5, 0.0)
	for i in n:
		var want := 3.0 if i == focus else 0.0
		_shift[i] = move_toward(_shift[i], want, dt * 40.0)


## 第 i 行文字的横向偏移（选中时右移 3px）
func shift(i: int) -> float:
	return roundf(_shift[i]) if i < _shift.size() else 0.0


## 选中行的文字颜色：确认时白 / 品红交替闪
func row_color(i: int, base := Palette.C3) -> Color:
	if not row_enabled(i):
		return Color(Palette.N5, 0.9)
	if i != focus:
		return Color(base, 0.78)
	if _blink > 0.0 and fmod(_blink, 0.08) < 0.04:
		return Palette.P3
	return Palette.C4


## 画焦点：横带（从左展开）+ 左侧品红竖条（换行时挤压）+ 括号。width 是横带宽度
func draw_focus(width: float, bar := true, brackets := true) -> void:
	if row_count() == 0:
		return
	var r := row_rect(focus)
	var y := roundf(_fy)
	var h := roundf(_fh)
	var box := Rect2(r.position.x, y, width, h)
	UiKit.band(self, box, ease(_band, 0.3))
	if bar:
		var bh := maxf(roundf(h * (1.0 - 0.35 * _squash)), 2.0)
		var bc := Palette.C4 if (_blink > 0.0 and fmod(_blink, 0.08) < 0.04) else Palette.P3
		draw_rect(Rect2(box.position.x - 3, y + roundf((h - bh) / 2.0), 2, bh), bc)
	if brackets:
		UiKit.brackets(self, box.grow_individual(0, 0, 4, 0), Color(Palette.C2, 0.9 * ease(_band, 0.4)), 1)


## 确认：闪三下、亮一下屏、播特效，结束后执行 cb
func confirm(cb: Callable, sfx := "ui_confirm") -> void:
	host.locked = true
	_blink = 0.24
	Sfx.play(sfx)
	ScreenFx.pulse(1.2)
	var r := row_rect(focus)
	host.fx("ui_burst", Vector2(r.position.x - 2 + slide, r.position.y + r.size.y * 0.5))
	var t0 := UiKit.now()
	while UiKit.now() - t0 < 0.22:
		await get_tree().process_frame
	host.locked = false
	cb.call()


## 不能选（未解锁等）：抖一下 + 低沉提示音
var _deny := 0.0


func deny() -> void:
	_deny = 1.0
	Sfx.play("ui_deny")


func deny_offset() -> float:
	return roundf(sin(_deny * 40.0) * 2.0 * _deny)

