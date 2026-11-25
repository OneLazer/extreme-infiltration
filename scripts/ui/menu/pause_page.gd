class_name PausePage
extends MenuPage
## 暂停菜单首页：左侧斜边面板，标题「暂停」、四个选项、本关信息（编号、用时、守卫、最佳）。

const ITEMS := ["继续游戏", "重新开始", "设置", "返回主菜单"]
const X := 20.0
const Y0 := 64.0
const STEP := 15.0
const PANEL_W := 132.0

var pm: PauseMenu


func row_count() -> int:
	return ITEMS.size()


func row_rect(i: int) -> Rect2:
	var w := UiKit.width(UiFonts.text(), ITEMS[i], 12)
	return Rect2(X - 2, Y0 + i * STEP, w + 14, 14)


func back() -> void:
	pm.resume()


func activate(i: int) -> void:
	match i:
		0:
			pm.resume()
		1:
			confirm(func(): pm.restart())
		2:
			confirm(func(): host.push(SettingsPage.new()))
		3:
			confirm(func(): pm.to_menu(), "ui_back")


func _draw() -> void:
	_draw_panel()
	UiKit.title(self, Vector2(18, 38), "暂停", 24)
	UiKit.num(self, Vector2(70, 38), "PAUSED", Color(Palette.C1, 0.9))
	draw_rect(Rect2(18, 45, 100, 1), Color(Palette.C1, 0.6))
	draw_rect(Rect2(18, 44, 14, 2), Palette.P3)
	var lv := pm.level if pm else null
	var idx := Levels.index_of(lv.scene_file_path) if lv else -1
	var label := "关卡 " + (Levels.label(idx) if idx >= 0 else "测试")
	UiKit.zh(self, Vector2(18, 56), label, Palette.C2)
	draw_focus(row_rect(focus).size.x)
	for i in ITEMS.size():
		var r := row_rect(i)
		UiKit.text(self, UiFonts.text(), Vector2(X + shift(i), r.position.y + 11), ITEMS[i], 12, row_color(i), 1.0)
	if lv:
		_draw_stats(lv, idx)
	UiKit.hints(self, Vector2(18, 168), [[["ESC"], "继续"]])


## 左侧面板：右边是 1:8 的斜边（每 8 行收 1 像素），斜边上一条青色细线
func _draw_panel() -> void:
	var c := Color(Palette.N0, 0.93)
	for y in range(-4, 184, 4):
		var w := PANEL_W - floorf((y + 4) / 8.0)
		draw_rect(Rect2(-30, y, w + 30, 4), c)
		draw_rect(Rect2(w, y, 1, 4), Color(Palette.C1, 0.7))
	draw_rect(Rect2(-30, 0, PANEL_W + 30, 2), Palette.P3)


## 本关信息：用时、守卫、最佳
func _draw_stats(lv: Level, idx: int) -> void:
	var y := 141.0
	draw_rect(Rect2(18, y - 8, 100, 1), Color(Palette.N4, 0.8))
	UiKit.zh(self, Vector2(18, y), "用时", Color(Palette.C1, 1))
	UiKit.num(self, Vector2(42, y + 0.5), Levels.fmt_time(lv.time), Palette.C3)
	UiKit.zh(self, Vector2(18, y + 10), "守卫", Color(Palette.C1, 1))
	var gs := "%d / %d" % [lv.enemies_total - lv.enemies_left, lv.enemies_total]
	UiKit.num(self, Vector2(42, y + 10.5), gs, Palette.W3 if lv.enemies_left > 0 else LevelSelectPage.C_EXIT)
	UiKit.zh(self, Vector2(18, y + 20), "最佳", Color(Palette.C1, 1))
	var bt := Progress.best_time(idx) if idx >= 0 else -1.0
	UiKit.num(self, Vector2(42, y + 20.5), Levels.fmt_time(bt) if bt >= 0.0 else "--:--.--",
		Palette.W3 if bt >= 0.0 else Color(Palette.N5, 1))
