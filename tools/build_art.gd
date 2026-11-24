extends Node
## 美术接入工具（一次性，非游戏代码）。在工程根目录运行：
##   godot --headless --path . res://tools/build_art.tscn
## 或在编辑器里打开 build_art.tscn 按 F6。
## 1. 用 tools/art 生成的 street_tiles.png/json 建 TileSet（Terrain 自动拼接 + 碰撞）
## 2. 生成窗外视差背景场景 scenes/art/street_backdrop.tscn
## 3. 给 LEVELS 里的关卡换上新 TileSet、加背景墙、自动摆放装饰物件
##    已有 Decor 节点时不重新摆放（保留你在编辑器里的调整），要重摆请加：  -- --redress

const T := 8
const TILES_PNG := "res://assets/tiles/street_tiles.png"
const TILES_JSON := "res://assets/tiles/street_tiles.json"
const TILESET_PATH := "res://assets/tiles/street_tileset.tres"
const BACKDROP_PATH := "res://scenes/art/street_backdrop.tscn"
const LEVELS := ["res://levels/level_01.tscn"]

## 掩码位：N=1 NE=2 E=4 SE=8 S=16 SW=32 W=64 NW=128
const BIT_NEIGHBOR := {
	1: TileSet.CELL_NEIGHBOR_TOP_SIDE, 2: TileSet.CELL_NEIGHBOR_TOP_RIGHT_CORNER,
	4: TileSet.CELL_NEIGHBOR_RIGHT_SIDE, 8: TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_CORNER,
	16: TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, 32: TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_CORNER,
	64: TileSet.CELL_NEIGHBOR_LEFT_SIDE, 128: TileSet.CELL_NEIGHBOR_TOP_LEFT_CORNER,
}
const OFFS := {1: Vector2i(0, -1), 2: Vector2i(1, -1), 4: Vector2i(1, 0), 8: Vector2i(1, 1),
	16: Vector2i(0, 1), 32: Vector2i(-1, 1), 64: Vector2i(-1, 0), 128: Vector2i(-1, -1)}

var _tiles_by_mask := {}   # mask -> [[atlas, prob], ...]


func _ready() -> void:
	var ts := _build_tileset()
	_build_backdrop()
	var redress := "--redress" in OS.get_cmdline_user_args()
	for p in LEVELS:
		_dress_level(p, ts, redress)
	get_tree().quit()
# ======================= TileSet =======================

func _build_tileset() -> TileSet:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TILES_JSON))
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)   # world
	ts.set_physics_layer_collision_mask(0, 0)
	ts.add_terrain_set()
	ts.set_terrain_set_mode(0, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
	ts.add_terrain(0)
	ts.set_terrain_name(0, 0, "街区结构")
	ts.set_terrain_color(0, 0, Color(0.3, 0.7, 1.0))
	var src := TileSetAtlasSource.new()
	src.texture = load(TILES_PNG)
	src.texture_region_size = Vector2i(T, T)
	ts.add_source(src, 0)
	var h := T / 2.0
	var square := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	for e in meta["tiles"]:
		var c := Vector2i(int(e["x"]), int(e["y"]))
		var m := int(e["mask"])
		src.create_tile(c)
		var td := src.get_tile_data(c, 0)
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, square)
		td.terrain_set = 0
		td.terrain = 0
		for bit in BIT_NEIGHBOR:
			td.set_terrain_peering_bit(BIT_NEIGHBOR[bit], 0 if m & bit else -1)
		td.probability = float(e["prob"])
		if not _tiles_by_mask.has(m):
			_tiles_by_mask[m] = []
		_tiles_by_mask[m].append([c, float(e["prob"])])
	var err := ResourceSaver.save(ts, TILESET_PATH)
	print("[art] TileSet: ", TILESET_PATH, " tiles=", meta["tiles"].size(), " err=", err)
	return load(TILESET_PATH)


static func _normalize(m: int) -> int:
	for t in [[2, 1, 4], [8, 16, 4], [32, 16, 64], [128, 1, 64]]:
		if not (m & t[1] and m & t[2]):
			m &= ~t[0]
	return m


## 按 blob 掩码重铺整张墙体。越界视为实心（关卡外圈不出现朝外的描边）。
## 变体用格子坐标哈希挑选，结果稳定。之后在编辑器里用 Terrain 刷子画也会自动拼接。
func _repaint(tm: TileMapLayer, ts: TileSet) -> void:
	var cells := tm.get_used_cells()
	var r := tm.get_used_rect()
	var solid := {}
	for c in cells:
		solid[c] = true
	tm.tile_set = ts
	tm.clear()
	for c in cells:
		var m := 0
		for bit in OFFS:
			var n: Vector2i = c + OFFS[bit]
			if solid.has(n) or not r.has_point(n):
				m |= bit
		m = _normalize(m)
		var opts: Array = _tiles_by_mask[m]
		var pick: Vector2i = opts[0][0]
		var hsh := float(((c.x * 73856093) ^ (c.y * 19349663)) & 0xFFFF) / 65536.0
		var acc := 0.0
		for i in range(1, opts.size()):
			acc += opts[i][1]
			if hsh < acc:
				pick = opts[i][0]
				break
		tm.set_cell(c, 0, pick)
# ======================= 窗外背景 =======================

func _build_backdrop() -> void:
	var root := Node2D.new()
	root.name = "StreetBackdrop"
	_layer(root, "Sky", "res://assets/bg/sky.png", Vector2.ZERO, 0, 0.0)
	_layer(root, "CityFar", "res://assets/bg/city_far.png", Vector2(0.1, 0.0), 480, 6.0)
	_layer(root, "CityMid", "res://assets/bg/city_mid.png", Vector2(0.25, 0.0), 480, 6.0)
	var near := _layer(root, "CityNear", "res://assets/bg/city_near.png", Vector2(0.45, 0.0), 480, 6.0)
	var rain_px := Parallax2D.new()
	rain_px.name = "Rain"
	rain_px.scroll_scale = Vector2(0.6, 0.0)
	rain_px.repeat_size = Vector2(480, 0)
	rain_px.repeat_times = 2
	root.add_child(rain_px)
	rain_px.owner = root
	var rain := RainLayer.new()
	rain.name = "RainLayer"
	rain_px.add_child(rain)
	rain.owner = root
	root.move_child(rain_px, near.get_index())   # 雨在近景楼前面会挡住窗光，放到近景后面
	var ps := PackedScene.new()
	ps.pack(root)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/art"))
	print("[art] Backdrop: ", ResourceSaver.save(ps, BACKDROP_PATH))
	root.free()


func _layer(root: Node, n: String, tex: String, scale: Vector2, repeat: int, y: float) -> Parallax2D:
	var p := Parallax2D.new()
	p.name = n
	p.scroll_scale = scale
	if repeat > 0:
		p.repeat_size = Vector2(repeat, 0)
		p.repeat_times = 2
	root.add_child(p)
	p.owner = root
	var s := Sprite2D.new()
	s.name = "Sprite"
	s.texture = load(tex)
	s.centered = false
	s.position = Vector2(0, y)
	p.add_child(s)
	s.owner = root
	return p
# ======================= 关卡装饰 =======================

func _dress_level(path: String, ts: TileSet, redress: bool) -> void:
	var root: Node = (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var tm := root.get_node("Walls") as TileMapLayer
	_repaint(tm, ts)
	for n in ["Backdrop", "BackWall"]:
		var old := root.get_node_or_null(n)
		if old:
			root.remove_child(old)
			old.free()
	var bd: Node = (load(BACKDROP_PATH) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	bd.name = "Backdrop"
	_add_before(root, bd, tm)
	var bw := BackWall.new()
	bw.name = "BackWall"
	_add_before(root, bw, tm)
	var decor := root.get_node_or_null("Decor")
	if decor and redress:
		root.remove_child(decor)
		decor.free()
		decor = null
	if decor == null:
		decor = Node2D.new()
		decor.name = "Decor"
		_add_before(root, decor, tm)
		_place_decor(root, decor, tm)
	var ps := PackedScene.new()
	ps.pack(root)
	print("[art] Level: ", path, " -> ", ResourceSaver.save(ps, path))
	root.free()


func _add_before(root: Node, n: Node, ref: Node) -> void:
	root.add_child(n, true)
	root.move_child(n, ref.get_index())
	n.owner = root


func _own(n: Node, root: Node) -> void:
	n.owner = root
	for c in n.get_children():
		_own(c, root)
## 地面物件：名称、宽、高、权重
const FLOOR_PROPS := [["desk", 26, 15, 3.0], ["vending", 14, 24, 1.5], ["server", 12, 26, 1.5],
	["plant", 10, 15, 2.0], ["cooler", 8, 17, 1.2], ["trash", 7, 9, 1.5]]


func _empty(tm: TileMapLayer, c: Vector2i) -> bool:
	return tm.get_cell_source_id(c) < 0 and tm.get_used_rect().has_point(c)


func _clear_up(tm: TileMapLayer, c: Vector2i) -> int:
	var n := 0
	while _empty(tm, c + Vector2i(0, -n - 1)) and n < 40:
		n += 1
	return n


func _place_decor(root: Node, decor: Node2D, tm: TileMapLayer) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261124
	var avoid: Array[Vector2] = []
	for n in root.find_children("*", "Area2D", true, false):
		avoid.append((n as Node2D).global_position)
	var pl := root.get_node_or_null("Player") as Node2D
	if pl:
		avoid.append(pl.global_position)
	var r := tm.get_used_rect()
	# 地面
	for cy in range(r.position.y, r.end.y):
		var cx := r.position.x
		while cx < r.end.x:
			if not (_empty(tm, Vector2i(cx, cy)) and not _empty(tm, Vector2i(cx, cy + 1))):
				cx += 1
				continue
			var start := cx
			while cx < r.end.x and _empty(tm, Vector2i(cx, cy)) and not _empty(tm, Vector2i(cx, cy + 1)):
				cx += 1
			_dress_floor(decor, tm, rng, start * T, cx * T, (cy + 1) * T, avoid)
	_place_lamps(decor, tm, r)
	_place_signs(root, decor, tm, rng, r)
	_own(decor, root)
func _dress_floor(decor: Node2D, tm: TileMapLayer, rng: RandomNumberGenerator, x0: int, x1: int, fy: int,
		avoid: Array[Vector2]) -> void:
	var x := x0 + rng.randi_range(4, 14)
	var total := 0.0
	for p in FLOOR_PROPS:
		total += p[3]
	while x < x1 - 6:
		var roll := rng.randf() * total
		var pick: Array = FLOOR_PROPS[0]
		for p in FLOOR_PROPS:
			roll -= p[3]
			if roll <= 0.0:
				pick = p
				break
		var w: int = int(pick[1]) + (14 if pick[0] == "server" else 0) + (10 if pick[0] == "desk" else 0)
		var ok := x + w <= x1 - 2
		for cx in range(x / T, (x + w - 1) / T + 1):
			if _clear_up(tm, Vector2i(cx, fy / T)) * T < pick[2] + 1:
				ok = false
		for a in avoid:
			if a.x > x - 5 and a.x < x + w + 5 and absf(a.y - fy) < 28:
				ok = false
		if not ok or rng.randf() < 0.15:
			x += 8
			continue
		var cxp: int = x + int(pick[1]) / 2
		match pick[0]:
			"desk":
				_prop(decor, "desk", cxp, fy)
				_prop(decor, "chair", x + pick[1] + 4, fy)
				_glow(decor, Vector2(cxp, fy - 11), 14.0, Palette.P3, 0.16)
			"vending":
				_prop(decor, "vending", cxp, fy, 1.6, Prop.Flicker.NEON)
				_glow(decor, Vector2(cxp, fy - 8), 22.0, Palette.P3, 0.22)
			"server":
				_prop(decor, "server", cxp, fy, 1.7, Prop.Flicker.BLINK)
				_prop(decor, "server", cxp + 13, fy, 1.7, Prop.Flicker.BLINK)
				_glow(decor, Vector2(cxp + 6, fy - 12), 16.0, Palette.C3, 0.08)
			_:
				_prop(decor, pick[0], cxp, fy)
		x += w + rng.randi_range(12, 40)


func _prop(decor: Node2D, n: String, x: float, y: float, glow := 1.8, flicker := Prop.Flicker.NONE) -> Prop:
	var p := Prop.new()
	p.name = n.to_pascal_case()
	p.prop_name = n
	p.glow = glow
	p.flicker = flicker
	p.position = Vector2(x, y)
	decor.add_child(p, true)
	return p


func _glow(decor: Node2D, at: Vector2, radius: float, c: Color, k: float) -> void:
	var g := GlowSpot.new()
	g.name = "Glow"
	g.position = at
	g.radius = radius
	g.color = c
	g.strength = k
	decor.add_child(g, true)
## 天花板下每隔 64px 一盏吊灯，下方空间够高才挂；光锥长度量到地面
func _place_lamps(decor: Node2D, tm: TileMapLayer, r: Rect2i) -> void:
	for cy in range(r.position.y, r.end.y):
		var cx := r.position.x
		while cx < r.end.x:
			var c := Vector2i(cx, cy)
			if not (_empty(tm, c) and not _empty(tm, c + Vector2i.UP)):
				cx += 1
				continue
			var start := cx
			while cx < r.end.x and _empty(tm, Vector2i(cx, cy)) and not _empty(tm, Vector2i(cx, cy - 1)):
				cx += 1
			var x := start * T + 24
			while x < cx * T - 12:
				var depth := 0
				while _empty(tm, Vector2i(x / T, cy + depth)) and depth < 40:
					depth += 1
				var x_ok := _empty(tm, Vector2i((x - 8) / T, cy)) and _empty(tm, Vector2i((x + 8) / T, cy))
				if depth >= 8 and x_ok:
					var ly := cy * T + 7
					_prop(decor, "lamp", x, ly, 2.2)
					var cone := LightCone.new()
					cone.name = "LightCone"
					cone.position = Vector2(x, ly)
					cone.length = depth * T - 7
					decor.add_child(cone, true)
				x += 64


## 霓虹竖招牌挂在开阔的背景墙上；出口上方挂安全出口标识
func _place_signs(root: Node, decor: Node2D, tm: TileMapLayer, rng: RandomNumberGenerator, r: Rect2i) -> void:
	var last := -1000
	for cx in range(r.position.x + 6, r.end.x - 6):
		if cx * T - last < 220:
			continue
		for cy in range(r.position.y + 6, r.position.y + 10):
			var free := true
			for dx in range(-2, 3):
				for dy in range(-1, 6):
					if not _empty(tm, Vector2i(cx + dx, cy + dy)):
						free = false
			if free and rng.randf() < 0.12:
				_prop(decor, "neon_ye", cx * T, (cy + 4) * T + 6, 1.9, Prop.Flicker.NEON)
				_glow(decor, Vector2(cx * T, (cy + 2) * T + 4), 20.0, Palette.P3, 0.14)
				last = cx * T
				break
	var ex := root.find_child("Exit", true, false) as Node2D
	if ex:
		_prop(decor, "sign_exit", ex.position.x - 14, ex.position.y - 28, 1.6)
		_glow(decor, ex.position + Vector2(-14, -33), 18.0, Color(0.3, 1.0, 0.55), 0.1)
