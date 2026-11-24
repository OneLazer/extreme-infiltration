class_name Juice
extends Node2D
## 游戏手感特效层：所有小粒子（尘土、烟、火花、碎片、机油、弹壳、冲击环、弹道）都在这一个节点里
## 用 _draw 画出来，不依赖粒子节点，粒子能和墙体瓦片碰撞、弹跳、停住。
## 机油和焦痕落到墙面后变成贴花（Decals 节点，排在墙体之后、实体之前）。
## 关卡 _ready 时由 Level 创建；其他脚本用静态函数 Juice.xxx(...) 调用，找不到实例时静默忽略。

enum K { DUST, SMOKE, SPARK, DEBRIS, OIL, SHELL, RING, TRACE, GHOST, FLASH, PIXEL }

class Pt:
	var k := 0
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var life := 0.0
	var max_life := 1.0
	var size := 1.0
	var color := Color.WHITE
	var color2 := Color.WHITE
	var grav := 0.0
	var drag := 0.0
	var rest := 0.0           # 静止计时（碎片落地后）
	var a := Vector2.ZERO     # 线段终点 / 附加向量
	var tex: Texture2D        # 残影 / 闪光贴图
	var region := Rect2()
	var flip := false
	var scl := Vector2.ONE
	var frames := 1
	var fps := 30.0
	var rot := 0.0

static var _inst: Juice

var walls: TileMapLayer
var decals: JuiceDecals
var _pts: Array[Pt] = []
const MAX_PTS := 900


static func get_inst() -> Juice:
	return _inst if is_instance_valid(_inst) else null


func setup(level: Node, tm: TileMapLayer) -> void:
	_inst = self
	walls = tm
	z_index = 5
	decals = JuiceDecals.new()
	decals.name = "Decals"
	level.add_child(decals)
	if tm:
		level.move_child(decals, tm.get_index() + 1)


func solid(p: Vector2) -> bool:
	if walls == null:
		return false
	return walls.get_cell_source_id(walls.local_to_map(walls.to_local(p))) >= 0


func _add(p: Pt) -> Pt:
	if _pts.size() >= MAX_PTS:
		_pts.pop_front()
	_pts.append(p)
	return p
func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	var keep: Array[Pt] = []
	for p in _pts:
		p.life += delta
		if p.life >= p.max_life:
			continue
		match p.k:
			K.DUST, K.SMOKE, K.PIXEL:
				p.vel *= exp(-p.drag * delta)
				p.vel.y += p.grav * delta
				p.pos += p.vel * delta
			K.SPARK:
				p.vel.y += p.grav * delta
				p.vel *= exp(-p.drag * delta)
				_collide(p, delta, 0.45, false)
			K.DEBRIS, K.SHELL:
				p.vel.y += p.grav * delta
				p.rot += p.vel.length() * delta * 0.3
				if _collide(p, delta, 0.35, true) and p.vel.length() < 14.0:
					p.rest += delta
			K.OIL:
				p.vel.y += p.grav * delta
				var nxt := p.pos + p.vel * delta
				if solid(nxt):
					if decals:
						decals.splat(p.pos, p.vel, p.size)
					continue
				p.pos = nxt
		keep.append(p)
	_pts = keep
	queue_redraw()


## 分轴碰撞：撞到哪个轴就在哪个轴反弹。返回本帧是否贴地。
func _collide(p: Pt, delta: float, bounce: float, friction: bool) -> bool:
	var grounded := false
	var nx := p.pos + Vector2(p.vel.x * delta, 0.0)
	if solid(nx):
		p.vel.x = -p.vel.x * bounce
	else:
		p.pos.x = nx.x
	var ny := p.pos + Vector2(0.0, p.vel.y * delta)
	if solid(ny):
		if p.vel.y > 0.0:
			grounded = true
			if friction:
				p.vel.x *= 0.7
		p.vel.y = -p.vel.y * bounce
		if absf(p.vel.y) < 12.0:
			p.vel.y = 0.0
	else:
		p.pos.y = ny.y
	return grounded
func _draw() -> void:
	for p in _pts:
		var t := p.life / p.max_life
		var pos := p.pos.round()
		match p.k:
			K.DUST, K.SMOKE:
				var r := p.size * (0.6 + 0.9 * ease(t, 0.4))
				var c := p.color
				c.a *= (1.0 - t)
				draw_circle(pos, r, c, true, -1.0, false)
				if p.k == K.SMOKE and r > 1.5:
					var top := p.color2
					top.a *= (1.0 - t)
					draw_circle(pos + Vector2(-0.5, -1.0), r * 0.55, top, true, -1.0, false)
			K.SPARK:
				var c := p.color.lerp(p.color2, t)
				var tail := p.vel * 0.022
				if tail.length() < 1.0:
					tail = tail.normalized()
				draw_line(pos, (p.pos - tail).round(), c, 1.0)
			K.DEBRIS, K.SHELL:
				var c := p.color
				var fade := clampf((p.max_life - p.life) / 0.4, 0.0, 1.0)
				c.a *= fade
				var s := Vector2(p.size, p.size)
				if p.k == K.SHELL:
					s = Vector2(2, 1) if sin(p.rot) > 0.0 else Vector2(1, 2)
				draw_rect(Rect2(pos - (s / 2.0).floor(), s), c)
				if p.size >= 2.0 and sin(p.rot * 2.0) > 0.3:
					var hi := p.color2
					hi.a *= fade
					draw_rect(Rect2(pos - (s / 2.0).floor(), Vector2.ONE), hi)
			K.PIXEL:
				var c := p.color
				c.a *= (1.0 - t)
				draw_rect(Rect2(pos, Vector2.ONE), c)
			K.OIL:
				draw_rect(Rect2(pos, Vector2.ONE * p.size), p.color)
			K.RING:
				var c := p.color
				c.a *= (1.0 - t)
				var rr := p.size * (1.0 - pow(1.0 - t, 3.0))
				draw_arc(pos, maxf(rr, 1.0), 0.0, TAU, 20, c, 1.0, false)
			K.TRACE:
				var w := maxf(p.size * (1.0 - t), 1.0)
				var c := p.color
				c.a *= (1.0 - t * t)
				draw_line(pos, p.a.round(), c, roundf(w))
				if t < 0.45:
					draw_line(pos, p.a.round(), Color(2.2, 2.2, 2.2, 1.0 - t * 2.0), 1.0)
			K.GHOST:
				var c := p.color
				c.a *= (1.0 - t) * (1.0 - t) * p.size
				_draw_region(p, c, 0)
			K.FLASH:
				var f := mini(int(p.life * p.fps), p.frames - 1)
				_draw_region(p, p.color, f)


func _draw_region(p: Pt, c: Color, frame: int) -> void:
	var reg := p.region
	reg.position.x += frame * reg.size.x
	var sx := -p.scl.x if p.flip else p.scl.x
	draw_set_transform(p.pos.round(), p.rot if p.k == K.FLASH else 0.0, Vector2(sx, p.scl.y))
	draw_texture_rect_region(p.tex, Rect2(p.a, reg.size), reg, c)
	draw_set_transform(Vector2.ZERO)
# ======================= 生成接口 =======================

static func _mk(k: int, pos: Vector2, vel: Vector2, life: float) -> Pt:
	var p := Pt.new()
	p.k = k
	p.pos = pos
	p.vel = vel
	p.max_life = life
	return p


## 地面扬尘：dir 为主方向（Vector2.ZERO = 向两侧散开），spread 为扩散角
static func dust(at: Vector2, n: int, dir := Vector2.ZERO, speed := 40.0, size := 1.6) -> void:
	var j := get_inst()
	if j == null:
		return
	for i in n:
		var d := dir
		if d == Vector2.ZERO:
			d = Vector2(-1.0 if i % 2 == 0 else 1.0, -0.25)
		var v := d.normalized().rotated(randf_range(-0.45, 0.45)) * speed * randf_range(0.5, 1.2)
		var p := _mk(K.DUST, at + Vector2(randf_range(-1.5, 1.5), randf_range(-1.0, 0.0)), v, randf_range(0.28, 0.5))
		p.size = size * randf_range(0.7, 1.3)
		p.drag = 7.0
		p.grav = -14.0
		p.color = Color(Palette.DUST, 0.7)
		j._add(p)


## 硝烟：缓慢上升、膨胀变淡，顶部受光
static func smoke(at: Vector2, n: int, dir := Vector2.UP, speed := 18.0, tint := Color(0.42, 0.38, 0.62)) -> void:
	var j := get_inst()
	if j == null:
		return
	for i in n:
		var v := dir.normalized().rotated(randf_range(-0.6, 0.6)) * speed * randf_range(0.4, 1.3)
		var p := _mk(K.SMOKE, at + Vector2(randf_range(-1, 1), randf_range(-1, 1)), v, randf_range(0.5, 0.9))
		p.size = randf_range(1.5, 2.8)
		p.drag = 3.5
		p.grav = -22.0
		p.color = Color(tint, 0.55)
		p.color2 = Color(tint.lightened(0.35), 0.5)
		j._add(p)


## 火花：拉长的亮线，受重力、会在墙面弹跳
static func sparks(at: Vector2, n: int, dir: Vector2, spread := 0.7, speed := 160.0, col := Palette.SPARK) -> void:
	var j := get_inst()
	if j == null:
		return
	for i in n:
		var v := dir.normalized().rotated(randf_range(-spread, spread)) * speed * randf_range(0.35, 1.2)
		var p := _mk(K.SPARK, at, v, randf_range(0.12, 0.38))
		p.grav = 420.0
		p.drag = 2.5
		p.color = col
		p.color2 = Color(col.r * 0.5, col.g * 0.25, col.b * 0.2)
		j._add(p)
## 碎片：带重力、会弹跳并停在地面，几秒后淡出。colors 随机取一个
static func debris(at: Vector2, n: int, dir: Vector2, colors: Array, speed := 120.0, hi := Color.WHITE) -> void:
	var j := get_inst()
	if j == null:
		return
	for i in n:
		var v := dir.normalized().rotated(randf_range(-1.1, 1.1)) * speed * randf_range(0.4, 1.2) + Vector2(0, -50)
		var p := _mk(K.DEBRIS, at + Vector2(randf_range(-3, 3), randf_range(-4, 3)), v, randf_range(2.0, 3.5))
		p.size = [1.0, 2.0, 2.0, 3.0][randi() % 4]
		p.grav = 520.0
		p.color = colors[randi() % colors.size()]
		p.color2 = hi
		p.rot = randf() * TAU
		j._add(p)


## 义体机油：深色液滴，落到墙面变成贴花
static func oil(at: Vector2, n: int, dir: Vector2, speed := 140.0) -> void:
	var j := get_inst()
	if j == null:
		return
	for i in n:
		var v := dir.normalized().rotated(randf_range(-0.8, 0.8)) * speed * randf_range(0.3, 1.1) + Vector2(0, -40)
		var p := _mk(K.OIL, at, v, 2.0)
		p.size = 1.0 if randf() < 0.7 else 2.0
		p.grav = 420.0
		p.color = Palette.OIL
		j._add(p)


## 弹壳：小黄铜块，弹跳几下停住
static func shell(at: Vector2, vel: Vector2) -> void:
	var j := get_inst()
	if j == null:
		return
	var p := _mk(K.SHELL, at, vel, 2.2)
	p.grav = 560.0
	p.color = Color("#e8b64a")
	p.color2 = Color("#fff1c2")
	j._add(p)


## 扩散冲击环
static func ring(at: Vector2, radius: float, col: Color, life := 0.22) -> void:
	var j := get_inst()
	if j == null:
		return
	var p := _mk(K.RING, at, Vector2.ZERO, life)
	p.size = radius
	p.color = col
	j._add(p)


## 弹道：彩色外层 + 前半段白芯，迅速变细消失
static func trace(a: Vector2, b: Vector2, col: Color, width := 2.0, life := 0.14) -> void:
	var j := get_inst()
	if j == null:
		return
	var p := _mk(K.TRACE, a, Vector2.ZERO, life)
	p.a = b
	p.size = width
	p.color = col
	j._add(p)


## 闪烁小光点（拾取、命中余辉）
static func glints(at: Vector2, n: int, col: Color, radius := 8.0) -> void:
	var j := get_inst()
	if j == null:
		return
	for i in n:
		var v := Vector2.from_angle(randf() * TAU) * randf_range(10.0, 40.0)
		var p := _mk(K.PIXEL, at + v * 0.1, v, randf_range(0.25, 0.6))
		p.drag = 4.0
		p.grav = -10.0
		p.color = col
		j._add(p)
## 残影：tex 是白色剪影图集，region 为帧，offset 为帧左上角相对 pivot 的偏移
static func ghost(at: Vector2, tex: Texture2D, region: Rect2, offset: Vector2, flip: bool, scl: Vector2,
		col: Color, life := 0.22, strength := 0.55) -> void:
	var j := get_inst()
	if j == null:
		return
	var p := _mk(K.GHOST, at, Vector2.ZERO, life)
	p.size = strength
	p.tex = tex
	p.region = region
	p.a = offset
	p.flip = flip
	p.scl = scl
	p.color = col
	j._add(p)


## 序列帧闪光（pixelfx 烘焙的精灵表）。sheet 由 FxSheets 提供：{tex, w, h, frames, fps, pivot}
static func flash(at: Vector2, name: String, angle := 0.0, col := Color.WHITE, flip := false) -> void:
	var j := get_inst()
	var s: Dictionary = FxSheets.get_sheet(name)
	if j == null or s.is_empty():
		return
	var p := _mk(K.FLASH, at, Vector2.ZERO, float(s["frames"]) / float(s["fps"]))
	p.tex = s["tex"]
	p.region = Rect2(0, 0, s["w"], s["h"])
	p.a = -s["pivot"]
	p.frames = s["frames"]
	p.fps = s["fps"]
	p.rot = angle
	p.flip = flip
	p.color = col
	j._add(p)
