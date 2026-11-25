class_name MenuHost
extends Control
## 菜单宿主：管理一叠页面（主页 → 选关 / 设置 / 致谢），统一处理输入、翻页动画、UI 序列帧特效和像素光标。
## 主菜单（MainMenu）和暂停菜单（PauseMenu）各有一个。计时全部用真实时间：暂停、顿帧期间照常动。
##
## 输入映射成动作字符串交给当前页：up / down / left / right / accept / back / tab_prev / tab_next。
## 键盘 WASD、方向键都能用；空格、回车确认；ESC、鼠标右键返回；Q / E 切换设置分页。

signal emptied              ## 最后一页也被关掉（暂停菜单据此恢复游戏）

const SLIDE := 24.0         ## 翻页时页面横移的距离（游戏像素）
const IN_TIME := 0.2
const OUT_TIME := 0.14

var pages: Array[MenuPage] = []
var locked := false         ## 确认动画、转场期间不收输入
var mouse_pos := Vector2(-100, -100)
var cursor_alpha := 0.0     ## 鼠标一动就显示，键盘操作 1.5 秒后淡出

var _last := 0.0
var _cursor_idle := 99.0
var _leaving: Array = []    ## [页面, 已过时间, 方向, 结束后是否释放]
var _fx: Array = []         ## [表名, 位置, 已过时间, 颜色]
var _overlay: Control


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_last = UiKit.now()
	_overlay = Overlay.new()
	_overlay.host = self
	add_child(_overlay)


func current() -> MenuPage:
	return pages.back() if not pages.is_empty() else null


## 打开新页面：旧页往左滑出（留在栈里），新页从右滑入
func push(page: MenuPage, sound := true, dir := 1) -> void:
	var old := current()
	if old:
		_leave(old, -1, false)
	page.host = self
	pages.append(page)
	add_child(page)
	move_child(_overlay, -1)
	page.enter(dir)
	if sound and old:
		Sfx.play("ui_tab", 0.03, -2.0)


## 关掉当前页：它往右滑出后释放，下面那页从左滑回来
func pop(sound := true) -> void:
	var old := current()
	if old == null:
		return
	pages.pop_back()
	_leave(old, 1, true)
	var under := current()
	if under:
		_cancel_leave(under)
		under.visible = true
		under.enter(-1)
	else:
		emptied.emit()
	if sound:
		Sfx.play("ui_back", 0.03)


## 清空整叠页面（暂停菜单关闭时）
func clear() -> void:
	while not pages.is_empty():
		var p: MenuPage = pages.pop_back()
		if p.visible and not p.leaving:
			_leave(p, -1, true)
		else:
			_cancel_leave(p)
			p.queue_free()


func _cancel_leave(p: MenuPage) -> void:
	for i in range(_leaving.size() - 1, -1, -1):
		if _leaving[i][0] == p:
			_leaving.remove_at(i)
	p.leaving = false


func _leave(p: MenuPage, dir: int, free_after: bool) -> void:
	p.leaving = true
	_leaving.append([p, 0.0, dir, free_after])


## 在画布坐标 at 播一个 pixelfx 烘焙的序列帧（UI 层：不进辉光，颜色直接画）
func fx(sheet: String, at: Vector2, col := Color.WHITE) -> void:
	if not FxSheets.get_sheet(sheet).is_empty():
		_fx.append([sheet, at.round(), 0.0, col])


func _process(_delta: float) -> void:
	var now := UiKit.now()
	var dt := minf(now - _last, 0.1)
	_last = now
	_cursor_idle += dt
	var want := 1.0 if _cursor_idle < 1.5 else 0.0
	cursor_alpha = move_toward(cursor_alpha, want, dt * (8.0 if want > cursor_alpha else 3.0))
	for p in pages:
		if p.visible and not p.leaving:
			p.tick(dt)
	for i in range(_leaving.size() - 1, -1, -1):
		var l: Array = _leaving[i]
		var page: MenuPage = l[0]
		l[1] += dt
		var k := clampf(l[1] / OUT_TIME, 0.0, 1.0)
		page.slide = roundf(SLIDE * l[2] * ease(k, 2.0))
		page.alpha = 1.0 - k
		page.tick(dt)
		if k >= 1.0:
			_leaving.remove_at(i)
			page.leaving = false
			if l[3]:
				page.queue_free()
			else:
				page.visible = false
	for i in range(_fx.size() - 1, -1, -1):
		_fx[i][2] += dt
		var s := FxSheets.get_sheet(_fx[i][0])
		if _fx[i][2] >= float(s["frames"]) / float(s["fps"]):
			_fx.remove_at(i)
	_overlay.queue_redraw()

# ======================= 输入 =======================

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or pages.is_empty():
		return
	if event is InputEventMouse:
		mouse_pos = (make_input_local(event) as InputEventMouse).position   # 转成 320×180 画布坐标
	if event is InputEventMouseMotion:
		_cursor_idle = 0.0
		if not locked:
			current().on_mouse(mouse_pos)
		return
	if event is InputEventMouseButton and event.pressed:
		_cursor_idle = 0.0
		get_viewport().set_input_as_handled()
		if locked:
			return
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				current().on_click(mouse_pos)
			MOUSE_BUTTON_RIGHT:
				current().on_action("back")
			MOUSE_BUTTON_WHEEL_UP:
				current().on_action("up")
			MOUSE_BUTTON_WHEEL_DOWN:
				current().on_action("down")
		return
	var a := _action_of(event)
	if a == "":
		return
	get_viewport().set_input_as_handled()
	if not locked:
		if _cursor_idle < 99.0:
			_cursor_idle = maxf(_cursor_idle, 1.2)     # 用键盘时光标很快淡出
		current().on_action(a)


func _action_of(e: InputEvent) -> String:
	if not e.is_pressed():
		return ""
	var key := e as InputEventKey
	if key:
		match key.physical_keycode:
			KEY_W:
				return "up"
			KEY_S:
				return "down"
			KEY_A:
				return "left"
			KEY_D:
				return "right"
			KEY_Q:
				return "tab_prev" if not key.echo else ""
			KEY_E:
				return "tab_next" if not key.echo else ""
	for pair in [["ui_up", "up"], ["ui_down", "down"], ["ui_left", "left"], ["ui_right", "right"]]:
		if e.is_action_pressed(pair[0], true):
			return pair[1]
	if e.is_echo():
		return ""
	if e.is_action_pressed("ui_accept") or e.is_action_pressed("jump"):
		return "accept"
	if e.is_action_pressed("ui_cancel") or e.is_action_pressed("pause"):
		return "back"
	return ""


## 最上层：UI 序列帧特效 + 光标
class Overlay extends Control:
	var host: MenuHost

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for f in host._fx:
			var s := FxSheets.get_sheet(f[0])
			var frame := mini(int(f[2] * float(s["fps"])), int(s["frames"]) - 1)
			var src := Rect2(frame * s["w"], 0, s["w"], s["h"])
			draw_texture_rect_region(s["tex"], Rect2(f[1] - s["pivot"], Vector2(s["w"], s["h"])), src, f[3])
		if host.cursor_alpha > 0.01 and not host.pages.is_empty():   # 暂停菜单关掉后不留光标
			UiKit.cursor(self, host.mouse_pos, host.cursor_alpha)
