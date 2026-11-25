class_name PauseMenu
extends Control
## ESC 暂停菜单。由 Level 挂在根视口的 CanvasLayer（第 70 层：HUD 之上、转场之下）。
## 打开：场景树暂停，画面去色压暗（ScreenFx.set_pause），左侧面板滑入。
## 继续：面板滑出后才恢复游戏，期间按下的跳跃 / 开火不会漏进游戏。
## 死亡倒带、通关、转场期间不能暂停；窗口失去焦点时自动暂停。

var level: Level
var host: MenuHost
var is_open := false
var _closing := false
var _dim := 0.0
var _last := 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	host = MenuHost.new()
	add_child(host)
	_last = UiKit.now()


func can_pause() -> bool:
	return not is_open and is_instance_valid(level) and not level.is_done() \
		and Game.player != null and is_instance_valid(Game.player) and not Game.player.dead \
		and not ScreenFx.is_wiping()


func _input(event: InputEvent) -> void:
	if not is_open and event.is_action_pressed("pause") and not event.is_echo():
		if can_pause():
			get_viewport().set_input_as_handled()
			open()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and can_pause():
		open()


func open() -> void:
	is_open = true
	_closing = false
	get_tree().paused = true
	ScreenFx.set_pause(true)
	Sfx.play("pause")
	var p := PausePage.new()
	p.pm = self
	host.push(p, false, -1)


## 继续游戏：面板滑出（约 0.14 秒）后解除暂停
func resume() -> void:
	if _closing:
		return
	_closing = true
	host.locked = true
	host.clear()
	ScreenFx.set_pause(false)
	Sfx.play("resume")
	await _wait(MenuHost.OUT_TIME)
	host.locked = false
	is_open = false
	_closing = false
	get_tree().paused = false


func restart() -> void:
	host.locked = true
	get_tree().paused = false
	ScreenFx.set_pause(false)
	PixelView.reload()


## 返回主菜单：暂停状态下盖上转场（游戏不会在转场期间继续跑），再切场景
func to_menu() -> void:
	host.locked = true
	await ScreenFx.wipe_out()
	get_tree().paused = false
	ScreenFx.set_pause(false)
	Game.menu_page = ""
	PixelView.change_scene(Levels.MENU)


func _wait(sec: float) -> void:
	var t0 := UiKit.now()
	while UiKit.now() - t0 < sec:
		await get_tree().process_frame


func _process(_delta: float) -> void:
	var now := UiKit.now()
	var dt := minf(now - _last, 0.1)
	_last = now
	var want := 1.0 if is_open and not _closing else 0.0
	_dim = move_toward(_dim, want, dt / 0.14)
	queue_redraw()


## HUD 在后期层之上不吃去色，这里再压一层暗色，让暂停面板成为唯一焦点
func _draw() -> void:
	if _dim > 0.0:
		draw_rect(Rect2(0, 0, 320, 180), Color(Palette.N0, 0.4 * _dim))
