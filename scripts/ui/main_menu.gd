class_name MainMenu
extends Node2D
## 主菜单场景（项目主场景）。世界部分在像素视口里：雨夜天台 —— 城市背景缓慢漂移、
## 主角站在楼沿、无人机偶尔带着探照灯飞过、楼顶「天枢集团」招牌闪烁；鼠标移动时各层有轻微视差。
## UI（MenuHost + 各页面）挂在根视口的 CanvasLayer 上，按窗口分辨率渲染。
## 本次运行第一次进入时播显像管开机 + 标题逐字闪入；从关卡回来只走普通转场。

const BACKDROP := preload("res://scenes/art/street_backdrop.tscn")
const TILESET := preload("res://assets/tiles/street_tileset.tres")

var _host: MenuHost
var _layer: CanvasLayer
var _hero: MenuHero
var _cam: Camera2D
var _busy := false


func _ready() -> void:
	Game.level = null
	Game.player = null
	Game.frozen = false
	Game.reset_time()
	get_tree().paused = false
	ScreenFx.set_pause(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	_build_world()
	_build_ui()
	if not Game.booted:
		Game.booted = true
		_boot()
	else:
		ScreenFx.wipe_in()
		Sfx.play("wipe_in", 0.0, -6.0)


func _boot() -> void:
	ScreenFx.crt_black()
	await get_tree().create_timer(0.3, true, false, true).timeout
	Sfx.play("boot")
	await ScreenFx.crt_on(0.5)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_layer):
		_layer.queue_free()


func _process(delta: float) -> void:
	# 鼠标视差：镜头最多偏 4×2 像素，远景跟着按各自比例移动
	if _cam and _host:
		var m := (_host.mouse_pos / Vector2(320, 180)).clamp(Vector2.ZERO, Vector2.ONE) - Vector2(0.5, 0.5)
		var want := m * Vector2(8, 4) if _host.cursor_alpha > 0.0 else _cam.offset
		_cam.offset = _cam.offset.lerp(want, 1.0 - exp(-3.0 * delta))


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.05
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var bd := BACKDROP.instantiate()
	add_child(bd)
	# 背景缓慢往左漂：远景慢、近景快
	for pair in [["CityFar", -2.0], ["CityMid", -5.0], ["CityNear", -9.0]]:
		var px := bd.get_node_or_null(pair[0]) as Parallax2D
		if px:
			px.autoscroll = Vector2(pair[1], 0)
	add_child(_shade())
	_cam = Camera2D.new()
	_cam.position = Vector2(160, 90)
	add_child(_cam)
	var roof := _roof()
	add_child(roof)
	_dress(roof)
	var juice := Juice.new()
	juice.name = "Juice"
	add_child(juice)
	juice.setup(self, roof)


## 左侧压暗（菜单文字底）+ 底边压暗（操作提示底）
func _shade() -> Node2D:
	var n := Node2D.new()
	var left := Polygon2D.new()
	left.polygon = PackedVector2Array([Vector2(-10, -10), Vector2(200, -10), Vector2(200, 190), Vector2(-10, 190)])
	var a := Color(Palette.N0, 0.84)
	var z := Color(Palette.N0, 0.0)
	left.vertex_colors = PackedColorArray([a, z, z, a])
	n.add_child(left)
	var bottom := Polygon2D.new()
	bottom.polygon = PackedVector2Array([Vector2(-10, 150), Vector2(330, 150), Vector2(330, 190), Vector2(-10, 190)])
	bottom.vertex_colors = PackedColorArray([z, z, Color(Palette.N0, 0.7), Color(Palette.N0, 0.7)])
	n.add_child(bottom)
	return n


## 天台：右下一大块楼顶（顶面 y = 152），靠右再立一个楼梯间（顶面 y = 128）
func _roof() -> TileMapLayer:
	var tm := TileMapLayer.new()
	tm.name = "Roof"
	tm.tile_set = TILESET
	var cells: Array[Vector2i] = []
	for y in range(19, 24):
		for x in range(27, 42):
			cells.append(Vector2i(x, y))
	for y in range(16, 19):
		for x in range(35, 42):
			cells.append(Vector2i(x, y))
	tm.set_cells_terrain_connect(cells, 0, 0, false)
	return tm


## 天台陈设：楼梯间顶上的「天枢集团」招牌（霓虹偶尔闪）、天线红灯、墙面竖招牌、近景雨、主角、无人机
func _dress(_roof_tm: TileMapLayer) -> void:
	var drone := MenuDrone.new()
	drone.y_base = 60.0
	add_child(drone)
	var deco := RoofDeco.new()
	add_child(deco)
	var logo := Prop.new()
	logo.prop_name = "logo"
	logo.flicker = Prop.Flicker.NEON
	logo.glow = 1.6
	logo.position = Vector2(292, 118)
	add_child(logo)
	var spot := GlowSpot.new()
	spot.position = Vector2(292, 112)
	spot.radius = 34.0
	spot.squash = 0.55
	spot.color = Palette.C2
	spot.strength = 0.12
	add_child(spot)
	var sign := Prop.new()
	sign.prop_name = "neon_ye"
	sign.flicker = Prop.Flicker.NEON
	sign.position = Vector2(238, 184)
	add_child(sign)
	var spot2 := GlowSpot.new()
	spot2.position = Vector2(238, 170)
	spot2.radius = 22.0
	spot2.color = Color(1.0, 0.31, 0.6)
	spot2.strength = 0.16
	add_child(spot2)
	_hero = MenuHero.new()
	_hero.position = Vector2(226, 152)
	add_child(_hero)
	var rain := RainLayer.new()
	rain.area = Vector2(340, 190)
	rain.count = 46
	rain.speed = Vector2(-55.0, 300.0)
	rain.color = Color(0.45, 0.62, 1.0, 0.42)
	rain.position = Vector2(-10, -10)
	add_child(rain)
	var splash := Splashes.new()
	splash.spans = [Vector2(216, 280), Vector2(280, 328)]
	splash.tops = [152.0, 128.0]
	add_child(splash)


## 楼顶的小物件（程序画）：招牌支架、天线（顶端红灯慢闪，HDR）、空调外机（风扇转）、楼梯间的门
class RoofDeco extends Node2D:
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var dark := Palette.N2
		var mid := Palette.N4
		var hi := Palette.N6
		# 招牌支架：两根立柱 + 一道斜撑
		for x in [276, 306]:
			draw_rect(Rect2(x, 118, 1, 10), hi)
			draw_rect(Rect2(x + 1, 118, 1, 10), mid)
		for i in 10:
			draw_rect(Rect2(278 + i * 3, 127 - i, 2, 1), mid)
		# 天线
		draw_rect(Rect2(318, 92, 1, 36), mid)
		draw_rect(Rect2(316, 104, 5, 1), mid)
		draw_rect(Rect2(317, 98, 3, 1), mid)
		var on := fmod(_t, 1.6) < 0.5
		draw_rect(Rect2(317, 90, 3, 2), Palette.ALERT * Color(0.8, 0.8, 0.8) if on else Color("#4a1420"))
		# 空调外机
		var ac := Rect2(252, 140, 18, 12)
		draw_rect(ac, dark)
		draw_rect(Rect2(ac.position, Vector2(ac.size.x, 1)), hi)
		draw_rect(Rect2(ac.position.x, ac.end.y - 1, ac.size.x, 1), Palette.N1)
		var c := Vector2(258, 146)
		draw_rect(Rect2(c - Vector2(4, 4), Vector2(9, 9)), Palette.N1)
		var a := _t * 9.0
		for k in 3:
			var d := Vector2(cos(a + k * TAU / 3.0), sin(a + k * TAU / 3.0))
			for r in range(1, 4):
				draw_rect(Rect2((c + d * r).round(), Vector2.ONE), mid)
		for y in 4:
			draw_rect(Rect2(264, 143 + y * 2, 4, 1), Palette.N3)
		# 楼梯间的门：门缝透出一点暖光
		draw_rect(Rect2(287, 135, 12, 17), mid)
		draw_rect(Rect2(288, 136, 10, 16), Palette.N1)
		draw_rect(Rect2(288, 136, 10, 1), hi)
		draw_rect(Rect2(293, 137, 1, 15), Color(0.6, 0.42, 0.2))
		draw_rect(Rect2(296, 143, 1, 2), Palette.N6)
		# 门上方的小灯
		draw_rect(Rect2(291, 132, 5, 1), Palette.W3 * Color(0.8, 0.8, 0.8))


## 雨点打在楼顶溅起的小水花：随机位置，三帧（一点 → 两点 → 散开变暗）
class Splashes extends Node2D:
	var spans: Array = []
	var tops: Array = []
	var _list: Array = []      # [位置, 年龄]
	var _acc := 0.0

	func _process(delta: float) -> void:
		_acc += delta * 14.0
		while _acc >= 1.0:
			_acc -= 1.0
			var i := randi() % spans.size()
			var s: Vector2 = spans[i]
			_list.append([Vector2(roundf(randf_range(s.x, s.y)), tops[i]), 0.0])
		for k in range(_list.size() - 1, -1, -1):
			_list[k][1] += delta
			if _list[k][1] > 0.15:
				_list.remove_at(k)
		queue_redraw()

	func _draw() -> void:
		for sp in _list:
			var p: Vector2 = sp[0]
			var f := int(sp[1] / 0.05)
			var c := Color(Palette.C3, 0.7 - f * 0.2)
			match f:
				0:
					draw_rect(Rect2(p + Vector2(0, -1), Vector2.ONE), c)
				1:
					draw_rect(Rect2(p + Vector2(-1, -2), Vector2.ONE), c)
					draw_rect(Rect2(p + Vector2(1, -2), Vector2.ONE), c)
				_:
					draw_rect(Rect2(p + Vector2(-2, -1), Vector2.ONE), c)
					draw_rect(Rect2(p + Vector2(2, -1), Vector2.ONE), c)


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 60
	PixelView.hud_root.add_child(_layer)
	_host = MenuHost.new()
	_layer.add_child(_host)
	var main := MainPage.new()
	main.menu = self
	main.intro = not Game.booted
	_host.push(main, false)
	if Game.menu_page == "credits":
		Game.menu_page = ""
		var cr := CreditsPage.new()
		cr.ending = true
		_host.push(cr, false)


## 开始第 i 关：主角从楼沿跃下，转场后进关
func start_game(i: int) -> void:
	if _busy or Levels.path(i) == "":
		return
	_busy = true
	_host.locked = true
	_hero.leap()
	await get_tree().create_timer(0.5, true, false, true).timeout
	await ScreenFx.wipe_out()
	PixelView.change_scene(Levels.path(i))


## 退出：显像管关机后退出程序
func quit_game() -> void:
	if _busy:
		return
	_busy = true
	_host.locked = true
	Sfx.play("power_off")
	await ScreenFx.crt_off(0.45)
	await get_tree().create_timer(0.25, true, false, true).timeout
	get_tree().quit()
