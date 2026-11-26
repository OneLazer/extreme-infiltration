@tool
class_name TextBox
extends Area2D
## 文本框（提示牌）：玩家走进触发区域时，在标记上方弹出一块全息文字面板；离开后缩小消失。
## 节点原点 = 悬浮标记的中心（和武器拾取点同款的全息展示框，图标换成三行字）。
## 触发区域以原点为中心（可偏移），按图格设置；编辑器里会画出虚线框方便摆放。
## 文字在检查器里编辑，直接回车换行（也认手打的 \n）。
## 面板挂在根视口（PixelView.hud_root），和 HUD 一样按窗口分辨率渲染，文字不糊。
## 表现：弹出时从标记处带回弹放大、四角括号收拢、边框闪白、逐字打出；离开时快速缩回标记。

@export_multiline var text := "提示文字\n第二行":
	set(v):
		text = v
		queue_redraw()
@export var area_tiles := Vector2i(4, 3):        ## 触发区域大小（图格）
	set(v):
		area_tiles = Vector2i(maxi(v.x, 1), maxi(v.y, 1))
		_rebuild()
@export var area_offset := Vector2.ZERO:          ## 触发区域中心相对原点的偏移（像素）
	set(v):
		area_offset = v
		_rebuild()

const TILE := 8.0
const COLOR := Palette.SIGN

var _shape: CollisionShape2D
var _t := 0.0
var _lit := 0.0             # 玩家在区域内时标记变亮 0..1
var _inside := false
var _layer: CanvasLayer
var _bubble: TextBubble


func _ready() -> void:
	collision_layer = 8        # trigger
	collision_mask = 2         # player
	monitorable = false
	_rebuild()
	_t = fmod(global_position.x * 0.03, TAU)
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_layer = CanvasLayer.new()
	_layer.layer = 60          # 和 HUD 同层：在后期之上，暂停菜单（70）之下
	PixelView.hud_root.add_child(_layer)
	_bubble = TextBubble.new()
	_bubble.owner_box = self
	_layer.add_child(_bubble)


## 面板挂在根视口，关卡释放时一起删（reparent 进 SubViewport 也会触发 tree_exiting，所以用 PREDELETE）
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_layer):
		_layer.queue_free()


func _area_rect() -> Rect2:
	var s := Vector2(area_tiles) * TILE
	return Rect2(area_offset - s * 0.5, s)


## 碰撞盒随尺寸重建（内部子节点，不存进场景）
func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _shape == null:
		_shape = CollisionShape2D.new()
		add_child(_shape, false, Node.INTERNAL_MODE_FRONT)
	var r := RectangleShape2D.new()
	r.size = _area_rect().size
	_shape.shape = r
	_shape.position = _area_rect().get_center()
	queue_redraw()


## 显示用的文字：检查器里的回车换行，外加手打的 \n
func display_text() -> String:
	return text.replace("\\n", "\n")


## 标记在根视口画布上的位置（320×180 单位，和 HUD 同一套坐标）
func screen_anchor() -> Vector2:
	return get_global_transform_with_canvas().origin


func _on_body_entered(body: Node2D) -> void:
	var p := body as Player
	if p == null or p.dead or _inside:
		return
	_inside = true
	if _bubble.open():
		Juice.ring(global_position, 9.0, COLOR, 0.2)
		Juice.glints(global_position, 6, COLOR)
		Sfx.play("ui_channel", 0.04, -8.0)


func _on_body_exited(body: Node2D) -> void:
	if body is Player and _inside:
		_inside = false
		_bubble.close()


func _process(delta: float) -> void:
	_t += delta
	_lit = move_toward(_lit, 1.0 if _inside else 0.0, delta * 6.0)
	queue_redraw()


## 悬浮标记：和武器拾取点同款（四角括号 + 全息底 + 扫描线 + 底座光带），图标是三行字
func _draw() -> void:
	if Engine.is_editor_hint():
		_draw_area()
	var y := roundf(sin(_t * 3.0) * 1.0)
	var c := COLOR
	draw_rect(Rect2(-4, 7, 8, 1), Color(c.r * 0.15, c.g * 0.15, c.b * 0.15, 0.6))
	# 括号：平时呼吸，玩家靠近时更亮并往外撑开 1 像素
	var k := 0.65 + 0.2 * sin(_t * 5.0) + 0.5 * _lit
	var bc := Color(c.r * k, c.g * k, c.b * k)
	var spread := 6 + int(round(_lit))
	for s in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var corner := Vector2(spread * s.x - (1 if s.x > 0 else 0), spread * s.y - (1 if s.y > 0 else 0) + y)
		draw_rect(Rect2(corner, Vector2.ONE), bc)
		draw_rect(Rect2(corner - Vector2(s.x, 0), Vector2.ONE), bc)
		draw_rect(Rect2(corner - Vector2(0, s.y), Vector2.ONE), bc)
	draw_rect(Rect2(-5, -5 + y, 10, 10), Color(c.r * 0.06, c.g * 0.06, c.b * 0.06, 0.6))
	# 图标：三行长短不一的字
	var ic := Color(c.r * 0.9, c.g * 0.9, c.b * 0.9)
	for row in [[-3, 6], [-1, 4], [1, 5]]:
		draw_rect(Rect2(-3, row[0] + y, row[1], 1), ic)
	var sy := -5 + int(fmod(_t * 14.0, 10.0))
	draw_rect(Rect2(-5, sy + y, 10, 1), Color(c.r * 0.25, c.g * 0.25, c.b * 0.25, 0.5))


## 编辑器里画出触发区域（虚线框）
func _draw_area() -> void:
	var r := _area_rect()
	var c := Color(COLOR, 0.5)
	var x := r.position.x
	while x < r.end.x:
		draw_rect(Rect2(x, r.position.y, minf(2.0, r.end.x - x), 1), c)
		draw_rect(Rect2(x, r.end.y - 1, minf(2.0, r.end.x - x), 1), c)
		x += 4.0
	var yy := r.position.y
	while yy < r.end.y:
		draw_rect(Rect2(r.position.x, yy, 1, minf(2.0, r.end.y - yy)), c)
		draw_rect(Rect2(r.end.x - 1, yy, 1, minf(2.0, r.end.y - yy)), c)
		yy += 4.0


## 根视口里的文字面板。坐标是 320×180 画布单位；计时用真实时间（慢动作、顿帧期间照常动）。
class TextBubble extends Control:
	const OPEN_TIME := 0.2
	const CLOSE_TIME := 0.14
	const TYPE_DELAY := 0.12      ## 弹出后多久开始打字
	const PER_CHAR := 0.022       ## 每个字的间隔
	const FS := 6                 ## 缝合像素 12px 画在 6 单位
	const LINE_H := 8.0
	const PAD := Vector2(5, 4)

	var owner_box: TextBox
	var _p := 0.0                 # 0 = 收起，1 = 完全展开
	var _target := 0.0
	var _age := 99.0              # 本次弹出后经过的时间
	var _typed := 0
	var _last := 0.0

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_last = UiKit.now()

	## 弹出。返回 true 表示是从完全收起的状态弹出（调用方据此放音效和粒子）
	func open() -> bool:
		_target = 1.0
		if _p > 0.02:
			return false          # 正在缩回时又进来：从当前大小接着放大，不重新打字
		_age = 0.0
		_typed = 0
		return true

	func close() -> void:
		_target = 0.0

	func _process(_delta: float) -> void:
		var now := UiKit.now()
		var dt := minf(now - _last, 0.1)
		_last = now
		var t := OPEN_TIME if _target > _p else CLOSE_TIME
		_p = move_toward(_p, _target, dt / t)
		if _target > 0.0:
			_age += dt
		visible = _p > 0.0
		if visible:
			queue_redraw()

	static func _back(x: float) -> float:   # 回弹缓动：冲过 1 一点再落回
		var c1 := 1.70158
		return 1.0 + (c1 + 1.0) * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)

	func _draw() -> void:
		if not is_instance_valid(owner_box) or not owner_box.is_inside_tree():
			return
		var lines := owner_box.display_text().split("\n")
		var font := UiFonts.text()
		var tw := 0.0
		var total := 0
		for l in lines:
			tw = maxf(tw, font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x)
			total += l.length()
		var sz := Vector2(ceilf(tw) + PAD.x * 2.0, lines.size() * LINE_H + PAD.y * 2.0 - 2.0)
		# 位置：标记正上方，水平夹在屏幕内；尾巴尖始终对着标记
		var a := owner_box.screen_anchor().round()
		var tip := Vector2(clampf(a.x, 8.0, 312.0), a.y - 9.0)
		var box := Rect2(Vector2(clampf(roundf(tip.x - sz.x / 2.0), 4.0, 316.0 - sz.x), tip.y - 3.0 - sz.y), sz)
		if box.position.y < 4.0:
			box.position.y = 4.0
		# 缩放：弹出时横向先到位、纵向带回弹；收起时平滑缩回尾巴尖
		var sx: float
		var sy: float
		var alpha: float
		if _target > 0.0:
			sx = 0.3 + 0.7 * _back(clampf(_p * 1.3, 0.0, 1.0))
			sy = 0.3 + 0.7 * _back(_p)
			alpha = clampf(_p * 2.5, 0.0, 1.0)
		else:
			var s := smoothstep(0.0, 1.0, _p)
			sx = 0.3 + 0.7 * s
			sy = sx
			alpha = s
		draw_set_transform(tip, 0.0, Vector2(sx, sy))
		var r := Rect2(box.position - tip, box.size)
		_draw_panel(r, alpha)
		_draw_text(r, lines, total, font, alpha)
		draw_set_transform(Vector2.ZERO)

	## 面板：暗底 + 青色细边框（弹出瞬间闪白）+ 指向标记的小尾巴 + 暖色四角括号（从外面收拢）+ 扫描线
	func _draw_panel(r: Rect2, alpha: float) -> void:
		var opening := _target > 0.0
		var flash := clampf(1.0 - _age / 0.25, 0.0, 1.0) if opening else 0.0
		var fill := Color(Palette.N0, 0.82 * alpha)
		var edge := Color(Palette.C1, 0.8 * alpha).lerp(Color(Palette.C4, alpha), flash)
		draw_rect(r, fill)
		draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 1), edge)
		draw_rect(Rect2(r.position.x, r.end.y - 1, r.size.x, 1), edge)
		draw_rect(Rect2(r.position.x, r.position.y, 1, r.size.y), edge)
		draw_rect(Rect2(r.end.x - 1, r.position.y, 1, r.size.y), edge)
		# 尾巴（局部坐标原点就是尾巴尖）
		for i in 3:
			var w := (2 - i) * 2 + 1
			var y := -3.0 + i
			draw_rect(Rect2(-(2 - i), y, w, 1), fill)
			draw_rect(Rect2(-(2 - i) - 1, y, 1, 1), edge)
			draw_rect(Rect2(2 - i + 1, y, 1, 1), edge)
		draw_rect(Rect2(-2, -4, 5, 1), fill)     # 盖掉尾巴根部那段底边
		draw_rect(Rect2(0, 0, 1, 1), edge)
		# 四角括号：从外面 5 像素处收拢到贴边
		var snap := ease(clampf(_age / 0.22, 0.0, 1.0), 0.35) if opening else 1.0
		var g := 2.0 + roundf((1.0 - snap) * 5.0)
		var br := r.grow(g)
		var bc := Color(Palette.W3, alpha).lerp(Color(Palette.C4, alpha), flash)
		for corner in [br.position, Vector2(br.end.x - 1, br.position.y), Vector2(br.position.x, br.end.y - 1), br.end - Vector2.ONE]:
			var sx := 1.0 if corner.x < br.get_center().x else -1.0
			var sy := 1.0 if corner.y < br.get_center().y else -1.0
			draw_rect(Rect2(corner, Vector2.ONE), bc)
			draw_rect(Rect2(corner + Vector2(sx, 0), Vector2.ONE), bc)
			draw_rect(Rect2(corner + Vector2(sx * 2, 0), Vector2.ONE), bc)
			draw_rect(Rect2(corner + Vector2(0, sy), Vector2.ONE), bc)
			draw_rect(Rect2(corner + Vector2(0, sy * 2), Vector2.ONE), bc)
		# 扫描线：一条淡青色亮线从上往下慢慢扫
		var span := maxf(r.size.y - 2.0, 1.0)
		var ly := r.position.y + 1.0 + floorf(fmod(_age * 20.0, span))
		draw_rect(Rect2(r.position.x + 1, ly, r.size.x - 2, 1), Color(Palette.C2, 0.1 * alpha))

	## 文字：逐字打出（跨行连续计数），打字时行尾有闪烁光标，每两个字响一下
	func _draw_text(r: Rect2, lines: PackedStringArray, total: int, font: Font, alpha: float) -> void:
		var n := total
		if _target > 0.0:
			n = clampi(int((_age - TYPE_DELAY) / PER_CHAR), 0, total)
			if n > _typed:
				if (n >> 1) > (_typed >> 1):
					Sfx.play("ui_type", 0.12, -16.0)
				_typed = n
		var left := n
		var c := Color(Palette.C4, alpha)
		var shadow := Color(Palette.C1, 0.7 * alpha)
		for i in lines.size():
			var line: String = lines[i]
			var shown := line.substr(0, mini(left, line.length()))
			var pos := Vector2(r.position.x + PAD.x, r.position.y + PAD.y + 5.0 + i * LINE_H)
			if shown != "":
				draw_string(font, pos + Vector2(0.5, 0.5), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, FS, shadow)
				draw_string(font, pos, shown, HORIZONTAL_ALIGNMENT_LEFT, -1, FS, c)
			var typing := left >= 0 and left < line.length()
			if typing and fmod(_age, 0.3) < 0.18:
				var cx := pos.x + font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, FS).x + 0.5
				draw_rect(Rect2(cx, pos.y - 5.0, 3.0, 5.5), Color(Palette.W3, alpha))
			left -= line.length()
			if typing:
				break
