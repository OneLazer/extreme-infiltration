class_name ElectricRenderer
extends Node2D
## 高压电块的整体渲染（由 ElectricLayer 运行时创建）。所有电格当成一整片来画，而不是每格一个动画：
##   Fill  —— 覆盖整片区域的矩形 + electric.gdshader：暗红底、流动明暗、内侧两级亮边（环境亮度）
##   Halo  —— 加色混合的宽光带：电弧对周围墙面的淡淡打光
##   本节点 —— 沿合并后的外轮廓画锯齿电弧（HDR 发光），每 jitter_interval 秒重新抖一次
## 定时放电：整片同时亮一下，几条大电弧横穿区域内部，两端溅火花。
## 玩家靠近（proximity 以内）时，最近的边缘会朝玩家伸出小电弧，越近越频繁。

const SHADER := preload("res://shaders/electric.gdshader")
const STEP := 4.0                 # 轮廓采样间距（px）
const GLOW := 0.58                # 电弧 HDR 亮度缩放：只压低泛光，不改色相（1 = 原始）

@export var jitter_interval := 0.07       ## 边缘电弧重抖间隔（秒）
@export var discharge_every := Vector2(1.5, 3.0)  ## 放电间隔的随机范围（秒）
@export var proximity := 16.0             ## 玩家离边缘多近时开始被电弧「够」（px）

var _layer: TileMapLayer
var _loops: Array = []            # 每条闭合轮廓：{"pts": PackedVector2Array（采样点）, "nrm": 法线, "corner": 是否拐角}
var _jit_a := PackedFloat32Array()   # 外层光晕的法向偏移（所有采样点连续存）
var _jit_b := PackedFloat32Array()   # 核心电弧的法向偏移
var _hot := PackedByteArray()        # 核心这一段是否白热
var _jit_t := 0.0
var _t := 0.0
var _next_discharge := 1.0
var _discharge := 0.0             # 放电强度 1 → 0
var _bolts: Array = []            # 放电时横穿内部的大电弧：{"a", "b", "life"}
var _reach: Array = []            # 伸向玩家的小电弧：{"a", "b", "life"}
var _fill: Node2D
var _halo: Node2D
var _mat: ShaderMaterial
var _rng := RandomNumberGenerator.new()


func setup(layer: TileMapLayer) -> void:
	_layer = layer
	z_index = layer.z_index
	_rng.seed = hash(layer.get_path())
	_build_loops()
	_build_fill()
	_halo = Node2D.new()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_halo.material = add
	_halo.draw.connect(_draw_halo)
	add_child(_halo)
	_rejitter()
	_next_discharge = _rng.randf_range(0.4, discharge_every.y)

# ======================= 轮廓 =======================

func _is_cell(c: Vector2i) -> bool:
	return _layer.get_cell_source_id(c) >= 0


## 把所有电格外露的边连成闭合轮廓（顺时针绕着电块；相邻格之间的边自然消掉），
## 再按 STEP 像素重新采样，每个采样点带一条朝外的法线
func _build_loops() -> void:
	var seg := {}      # 起点(格角坐标) -> [终点, ...]
	for c in _layer.get_used_cells():
		var x := c.x
		var y := c.y
		if not _is_cell(c + Vector2i.UP):
			_add_seg(seg, Vector2i(x, y), Vector2i(x + 1, y))
		if not _is_cell(c + Vector2i.RIGHT):
			_add_seg(seg, Vector2i(x + 1, y), Vector2i(x + 1, y + 1))
		if not _is_cell(c + Vector2i.DOWN):
			_add_seg(seg, Vector2i(x + 1, y + 1), Vector2i(x, y + 1))
		if not _is_cell(c + Vector2i.LEFT):
			_add_seg(seg, Vector2i(x, y + 1), Vector2i(x, y))
	while not seg.is_empty():
		var start: Vector2i = seg.keys()[0]
		var corners: Array[Vector2i] = [start]
		var cur := start
		while true:
			var ends: Array = seg[cur]
			var nxt: Vector2i = ends.pop_back()
			if ends.is_empty():
				seg.erase(cur)
			if nxt == start:
				break
			corners.append(nxt)
			cur = nxt
			if not seg.has(cur):
				break
		_loops.append(_resample(corners))


func _add_seg(seg: Dictionary, a: Vector2i, b: Vector2i) -> void:
	if not seg.has(a):
		seg[a] = []
	seg[a].append(b)

## 格角坐标的拐点 → 每 STEP 像素一个采样点（含法线、是否拐角）
func _resample(corners: Array[Vector2i]) -> Dictionary:
	var ts := Vector2(_layer.tile_set.tile_size)
	var n := corners.size()
	var pts := PackedVector2Array()
	var nrm := PackedVector2Array()
	var corner := PackedByteArray()
	for i in n:
		var a := Vector2(corners[i]) * ts
		var b := Vector2(corners[(i + 1) % n]) * ts
		var prev := Vector2(corners[(i - 1 + n) % n]) * ts
		var d := (b - a).normalized()
		var dp := (a - prev).normalized()
		var out := Vector2(d.y, -d.x)
		var steps := maxi(int(roundf(a.distance_to(b) / STEP)), 1)
		for s in steps:
			pts.append(a + d * (a.distance_to(b) * s / steps))
			if s == 0 and not dp.is_equal_approx(d):
				nrm.append((out + Vector2(dp.y, -dp.x)).normalized())
				corner.append(1)
			else:
				nrm.append(out)
				corner.append(0)
	return {"pts": pts, "nrm": nrm, "corner": corner}


func _sample_count() -> int:
	var n := 0
	for l in _loops:
		n += (l["pts"] as PackedVector2Array).size()
	return n


## 每次重抖：外层光晕和核心电弧各一组法向偏移（略偏向外侧），拐角抖得少一点，保持形状可读
func _rejitter() -> void:
	var n := _sample_count()
	_jit_a.resize(n)
	_jit_b.resize(n)
	_hot.resize(n)
	var i := 0
	for l in _loops:
		var corner: PackedByteArray = l["corner"]
		for k in corner.size():
			var amp := 0.8 if corner[k] else 1.0
			_jit_a[i] = _rng.randf_range(-1.0, 2.5) * amp
			_jit_b[i] = _rng.randf_range(-1.5, 1.8) * amp
			_hot[i] = 1 if _rng.randf() < 0.08 + _discharge * 0.4 else 0
			i += 1

# ======================= 内部填充 =======================

## 1 像素 = 1 格的遮罩贴图（四周各留 1 格），整片区域用一个矩形 + 着色器画完
func _build_fill() -> void:
	var used := _layer.get_used_rect()
	var origin := used.position - Vector2i.ONE
	var size := used.size + Vector2i(2, 2)
	var img := Image.create(size.x, size.y, false, Image.FORMAT_L8)
	for c in _layer.get_used_cells():
		img.set_pixelv(c - origin, Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("mask", tex)
	_mat.set_shader_parameter("cells", Vector2(size))
	var ts := Vector2(_layer.tile_set.tile_size)
	var rect := Rect2(Vector2(origin) * ts, Vector2(size) * ts)
	_fill = Node2D.new()
	_fill.material = _mat
	_fill.show_behind_parent = true          # 填充在电弧下面
	_fill.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fill.draw.connect(func() -> void: _fill.draw_texture_rect(tex, rect, false))
	add_child(_fill)

# ======================= 更新 =======================

func _process(delta: float) -> void:
	if _layer == null or _loops.is_empty():
		return
	_t += delta
	_mat.set_shader_parameter("time", _t)
	_jit_t -= delta
	if _jit_t <= 0.0:
		_jit_t = jitter_interval
		_rejitter()
	_next_discharge -= delta
	if _next_discharge <= 0.0:
		_next_discharge = _rng.randf_range(discharge_every.x, discharge_every.y)
		_start_discharge()
	_discharge = maxf(_discharge - delta * 4.0, 0.0)
	_mat.set_shader_parameter("flash", _discharge)
	for arr in [_bolts, _reach]:
		for b in arr:
			b["life"] -= delta
		arr.assign(arr.filter(func(b: Dictionary) -> bool: return b["life"] > 0.0))
	var view := _view_rect()
	_ambient_sparks(view)
	_reach_player()
	queue_redraw()
	_halo.queue_redraw()


## 当前镜头看到的范围（本地坐标），火花只在画面里生成，免得占满粒子池
func _view_rect() -> Rect2:
	var inv := get_canvas_transform().affine_inverse()
	return (inv * get_viewport_rect()).grow(8.0)


## 边缘偶尔迸出一两颗电火花
func _ambient_sparks(view: Rect2) -> void:
	if _rng.randf() > 0.25 + _discharge:
		return
	var l: Dictionary = _loops[_rng.randi() % _loops.size()]
	var pts: PackedVector2Array = l["pts"]
	var k := _rng.randi() % pts.size()
	if not view.has_point(pts[k]):
		return
	Juice.sparks(to_global(pts[k]), 1 + int(_discharge * 2.0), l["nrm"][k], 0.8, 70.0, Palette.ELECTRIC)

## 放电：整片亮一下，2~4 条大电弧横穿区域内部，两端溅火花。
## 电弧起点取画面里的边缘采样点，沿内法线（随机偏转 ±75°）穿过电块，到对面边缘为止，
## 所以细长的电柱、电带也能横穿，不会画到电块外面。
func _start_discharge() -> void:
	_discharge = 1.0
	_rejitter()
	var view := _view_rect()
	var cands: Array = []          # 画面里的采样点 [点, 法线]
	for l in _loops:
		var pts: PackedVector2Array = l["pts"]
		for k in pts.size():
			if view.has_point(pts[k]):
				cands.append([pts[k], l["nrm"][k]])
	if cands.is_empty():
		return
	var want := _rng.randi_range(2, 4)
	for attempt in 16:
		if want <= 0:
			break
		var c: Array = cands[_rng.randi() % cands.size()]
		var a: Vector2 = c[0]
		var dir: Vector2 = (-(c[1] as Vector2)).rotated(_rng.randf_range(-1.3, 1.3))
		var b := _cross(a, dir)
		if a.distance_to(b) < 10.0:
			continue
		want -= 1
		_bolts.append({"a": a, "b": b, "life": _rng.randf_range(0.12, 0.22)})
		Juice.sparks(to_global(a), 3, -dir, 0.7, 110.0, Palette.ELECTRIC)
		Juice.sparks(to_global(b), 3, dir, 0.7, 110.0, Palette.ELECTRIC)


## 从边缘点 a 沿 dir 往电块里走，直到走出电块（最多 120px），返回出口点
func _cross(a: Vector2, dir: Vector2) -> Vector2:
	var p := a + dir * 1.5
	var d := 1.5
	while d < 120.0 and _is_cell(_layer.local_to_map(p)):
		d += 2.0
		p = a + dir * d
	return a + dir * (d - 1.0)


## 玩家靠近：最近的边缘朝玩家伸出小电弧（不碰到玩家），越近越频繁
func _reach_player() -> void:
	var p := Game.player
	if p == null or p.dead:
		return
	var at := to_local(p.global_position)
	var best := Vector2.ZERO
	var best_d := proximity
	for l in _loops:
		for q in (l["pts"] as PackedVector2Array):
			var d := q.distance_to(at)
			if d < best_d:
				best_d = d
				best = q
	if best_d >= proximity:
		return
	var k := 1.0 - best_d / proximity
	if _rng.randf() < 0.08 + 0.5 * k:
		var reach := minf(best_d * 0.65, 10.0)
		_reach.append({"a": best, "b": best + (at - best).normalized() * reach, "life": 0.05})
		if _rng.randf() < 0.3 * k:
			Juice.sparks(to_global(best), 1, at - best, 0.5, 90.0, Palette.ELECTRIC)

# ======================= 绘制 =======================

## 一条轮廓按某组法向偏移得到的折线（闭合，像素取整）
func _loop_line(l: Dictionary, jit: PackedFloat32Array, base: int) -> PackedVector2Array:
	var pts: PackedVector2Array = l["pts"]
	var nrm: PackedVector2Array = l["nrm"]
	var out := PackedVector2Array()
	out.resize(pts.size() + 1)
	for k in pts.size():
		out[k] = (pts[k] + nrm[k] * jit[base + k]).round()
	out[pts.size()] = out[0]
	return out


func _draw() -> void:
	if _layer == null:
		return
	var k := 1.0 + _discharge * 0.5
	var halo_c := Palette.ELECTRIC * Color(0.24 * k, 0.24 * k, 0.24 * k)
	var core_c := Palette.ELECTRIC * Color(GLOW * k, GLOW * k, GLOW * k)
	var base := 0
	for l in _loops:
		var n := (l["pts"] as PackedVector2Array).size()
		draw_polyline(_loop_line(l, _jit_a, base), halo_c, 1.0)
		var core := _loop_line(l, _jit_b, base)
		draw_polyline(core, core_c, 1.0)
		for i in n:            # 白热段：核心上一小截亮白
			if _hot[base + i]:
				draw_line(core[i], core[i + 1], Palette.ELECTRIC_CORE * Color(GLOW, GLOW, GLOW), 1.0)
		base += n
	for b in _bolts:
		_draw_bolt(b["a"], b["b"], 0.3, true)
	for b in _reach:
		_draw_bolt(b["a"], b["b"], 0.45, false)


## 锯齿电弧（中点位移），每帧重新随机 → 自然闪烁。big：放电大电弧，带外层光晕和白芯
func _draw_bolt(a: Vector2, b: Vector2, jag: float, big: bool) -> void:
	var pts := PackedVector2Array([a, b])
	var off := a.distance_to(b) * jag
	while pts.size() < 2 + a.distance_to(b) / 3.0:
		var nxt := PackedVector2Array([pts[0]])
		for i in pts.size() - 1:
			var p0 := pts[i]
			var p1 := pts[i + 1]
			var nrm := (p1 - p0).orthogonal().normalized()
			nxt.append((p0 + p1) * 0.5 + nrm * _rng.randf_range(-off, off))
			nxt.append(p1)
		pts = nxt
		off *= 0.5
	for i in pts.size():
		pts[i] = pts[i].round()
	if big:
		var side := PackedVector2Array()
		for q in pts:
			side.append(q + Vector2(0, 1))
		draw_polyline(side, Palette.ELECTRIC * Color(0.3, 0.3, 0.3), 1.0)
		draw_polyline(pts, Palette.ELECTRIC_CORE * Color(GLOW, GLOW, GLOW), 1.0)
	else:
		draw_polyline(pts, Palette.ELECTRIC * Color(GLOW, GLOW, GLOW), 1.0)


## 加色光带：沿轮廓画一条宽而淡的光，给周围墙面打一点电光
func _draw_halo() -> void:
	var k := 0.03 + _discharge * 0.06
	var c := Color(Palette.ELECTRIC.r * k, Palette.ELECTRIC.g * k, Palette.ELECTRIC.b * k, 1.0)
	for l in _loops:
		var pts: PackedVector2Array = (l["pts"] as PackedVector2Array).duplicate()
		pts.append(pts[0])
		_halo.draw_polyline(pts, c, 5.0)
