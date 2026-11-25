@tool
class_name TimerGate
extends Area2D
## 计时门：玩家穿过后开始倒计时（HUD 顶部中间显示），倒计时内没通关（站进出口）就失败重开。
## 外观沿用武器替换区域的全息扫描门（两侧光柱 + 扫描线 + 上浮光点），颜色钴蓝，顶部是一个指针在转的小钟，
## 钟上方用小数字标出这扇门给的秒数。穿过后门变暗，不再触发；穿过另一扇计时门会把倒计时重置成那扇门的秒数。
## 区域大小按图格设置（默认 1×3），原点在左上角，和 WeaponZone 一样按 8px 网格对齐。

@export var seconds := 20.0:
	set(v):
		seconds = maxf(v, 1.0)
		queue_redraw()
@export var size_tiles := Vector2i(1, 3):
	set(v):
		size_tiles = Vector2i(maxi(v.x, 1), maxi(v.y, 1))
		_rebuild()

const TILE := 8.0
## 钟面：7×7 圆圈的像素（"#" 为边框）
const DIAL := ["..###..", ".#...#.", "#.....#", "#.....#", "#.....#", ".#...#.", "..###.."]

var _shape: CollisionShape2D
var _t := 0.0
var _hit := 0.0          # 触发闪光 1 → 0
var _used := false


func _ready() -> void:
	collision_layer = 8        # trigger
	collision_mask = 2         # player
	monitorable = false
	_rebuild()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


func _size() -> Vector2:
	return Vector2(size_tiles) * TILE


## 碰撞盒随尺寸重建（内部子节点，不存进场景）
func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _shape == null:
		_shape = CollisionShape2D.new()
		add_child(_shape, false, Node.INTERNAL_MODE_FRONT)
	var r := RectangleShape2D.new()
	r.size = _size()
	_shape.shape = r
	_shape.position = _size() * 0.5
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	var p := body as Player
	if p == null or p.dead or _used or Game.level == null:
		return
	_used = true
	_hit = 1.0
	Game.level.start_countdown(seconds)
	var c := Palette.TIMER
	var at := p.global_position
	Juice.ring(at, 12.0, c, 0.26)
	Juice.ring(at, 6.0, Color(2.4, 2.4, 2.8), 0.12)
	Juice.glints(at, 10, c)
	for i in 8:   # 光柱上溅出光点
		var x := 0.0 if i % 2 == 0 else _size().x
		Juice.glints(global_position + Vector2(x, randf() * _size().y), 1, c, 3.0)
	ScreenFx.pulse(1.6)
	var cam := p.get_node_or_null("Camera2D")
	if cam:
		cam.shake(1.0, 0.1)


func _process(delta: float) -> void:
	_t += delta
	_hit = maxf(_hit - delta * 3.0, 0.0)
	queue_redraw()


func _draw() -> void:
	var s := _size()
	var c := Palette.TIMER
	var dim := 0.4 if _used else 1.0                  # 已触发：整门变暗
	var k := (0.55 + 0.12 * sin(_t * 4.0)) * dim + _hit * 2.0
	var pillar := Color(c.r * k, c.g * k, c.b * k)
	draw_rect(Rect2(1, 0, s.x - 2, s.y), Color(c.r, c.g, c.b, (0.07 + _hit * 0.25) * dim))
	var cap := Color(c.r * (k + 0.5), c.g * (k + 0.5), c.b * (k + 0.5))
	for x in [0.0, s.x - 1.0]:
		draw_rect(Rect2(x, 0, 1, s.y), pillar)
		draw_rect(Rect2(x, 0, 1, 2), cap)
		draw_rect(Rect2(x, s.y - 2, 1, 2), cap)
	# 扫描线：没触发时扫得快（像在读秒），触发后慢下来
	var period := 1.0 if not _used else 2.6
	var sy := floorf(fmod(_t, period) / period * (s.y + 8.0))
	if sy < s.y:
		draw_rect(Rect2(1, sy, s.x - 2, 1), Color(c.r * 0.4 * dim, c.g * 0.4 * dim, c.b * 0.4 * dim))
	for i in int(s.x / 3.0) + 1:
		var ph := fmod(_t * 10.0 + i * 7.3, s.y)
		var px := Vector2(2.0 + i * 3.0, s.y - ph).floor()
		if px.x < s.x - 1.0:
			draw_rect(Rect2(px, Vector2.ONE), Color(c.r * 0.3 * dim, c.g * 0.3 * dim, c.b * 0.3 * dim, 0.8))
	_draw_clock(Vector2(floorf(s.x * 0.5) - 3.0, -10.0 + roundf(sin(_t * 3.0))), c, dim)
	if Engine.is_editor_hint():
		draw_rect(Rect2(Vector2.ZERO, s), Color(c.r, c.g, c.b, 0.5), false, 1.0)


## 顶部小钟：7×7 钟面 + 一根 8 向跳动的指针（没触发时一秒转一圈，触发后停在 12 点），
## 上方 3×5 小数字标出秒数
func _draw_clock(at: Vector2, c: Color, dim: float) -> void:
	var im := 1.1 * dim + _hit * 1.5
	var rim := Color(c.r * im, c.g * im, c.b * im)
	draw_rect(Rect2(at - Vector2.ONE, Vector2(9, 9)), Color(c.r * 0.05, c.g * 0.05, c.b * 0.05, 0.6))
	for y in DIAL.size():
		for x in 7:
			if DIAL[y][x] == "#":
				draw_rect(Rect2(at + Vector2(x, y), Vector2.ONE), rim)
	var center := at + Vector2(3, 3)
	var step := 0 if _used else int(_t * 8.0) % 8
	var d := Vector2.from_angle(-PI / 2.0 + step * PI / 4.0).round()
	var hand := Color(2.4 * dim + _hit, 2.4 * dim + _hit, 2.8 * dim + _hit)
	draw_rect(Rect2(center, Vector2.ONE), hand)
	draw_rect(Rect2(center + d, Vector2.ONE), hand)
	draw_rect(Rect2(center + d * 2.0, Vector2.ONE), rim)
	var label := str(int(ceil(seconds)))
	var w := label.length() * 4 - 1
	TinyDigits.draw(self, label, Vector2(center.x - floorf(w * 0.5), at.y - 7.0), Color(c.r * 0.7 * dim, c.g * 0.7 * dim, c.b * 0.7 * dim))
