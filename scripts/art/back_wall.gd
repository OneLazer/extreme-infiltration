@tool
class_name BackWall
extends Node2D
## 楼层背景墙：玻璃幕墙（竖梃、横档、斜向反光）、窗台护墙、吊顶。
## 按墙体 TileMapLayer 自动生成，关卡改了形状会跟着变。
## 比实心地形亮、但没有青色描边，避免被误读成可站立的平台。
## 窗外的城市夜景在更后面的 Parallax2D 里，透过半透明玻璃色调可见。

@export var walls_path := NodePath("../Walls"):
	set(v):
		walls_path = v
		queue_redraw()
@export var mullion_step := 48          ## 竖梃间距（px）
@export var transom_step := 48          ## 横档间距（px）
@export var wainscot_height := 18       ## 窗台护墙高度（px）
@export var glass_tint := Color(0.078, 0.067, 0.188, 0.43)
@export var reflection := Color(0.18, 0.44, 0.68, 0.16)

const T := 8


func _ready() -> void:
	queue_redraw()


func _walls() -> TileMapLayer:
	return get_node_or_null(walls_path) as TileMapLayer


func _solid(tm: TileMapLayer, c: Vector2i) -> bool:
	return tm.get_cell_source_id(c) >= 0


func _draw() -> void:
	var tm := _walls()
	if tm == null:
		return
	var r := tm.get_used_rect()
	var px := Rect2(r.position * T, r.size * T)
	draw_rect(px, glass_tint)
	_draw_reflections(px)
	# 竖梃：暗-中-亮三条，亮边朝右（月光方向）
	var x := int(px.position.x) + mullion_step / 2 + 8
	while x < px.end.x:
		draw_rect(Rect2(x, px.position.y, 1, px.size.y), Palette.N1)
		draw_rect(Rect2(x + 1, px.position.y, 1, px.size.y), Palette.N3)
		draw_rect(Rect2(x + 2, px.position.y, 1, px.size.y), Palette.N4)
		x += mullion_step
	var y := int(px.position.y) + transom_step + 14
	while y < px.end.y:
		draw_rect(Rect2(px.position.x, y, px.size.x, 1), Palette.N4)
		draw_rect(Rect2(px.position.x, y + 1, px.size.x, 1), Palette.N1)
		y += transom_step
	_draw_surfaces(tm, r)


## 斜向反光：每三个窗格里有一个带两道斜光
func _draw_reflections(px: Rect2) -> void:
	var x0 := int(px.position.x) + 32
	var pane := 0
	while x0 < px.end.x:
		if pane % 3 == 0:
			for wy in range(int(px.position.y), int(px.end.y)):
				var base := fposmod(wy * 0.6 + pane * 31.0 - x0, 70.0)
				var sx := x0 + int(base)
				while sx < x0 + mullion_step:
					draw_rect(Rect2(sx, wy, 5, 1).intersection(Rect2(x0, wy, mullion_step, 1)), reflection)
					sx += 70
		x0 += mullion_step
		pane += 1


## 地面上方画窗台护墙，天花板下方画吊顶。
## 只认「宽 ≥ 4 格、厚 ≥ 2 格」的楼板，细平台和柱顶不画，免得在空中多出一块墙。
func _draw_surfaces(tm: TileMapLayer, r: Rect2i) -> void:
	for cy in range(r.position.y, r.end.y):
		for cx in range(r.position.x, r.end.x):
			var c := Vector2i(cx, cy)
			if _solid(tm, c):
				continue
			var x := cx * T
			if _is_slab(tm, c, 1):
				var fy := (cy + 1) * T
				var h := wainscot_height
				draw_rect(Rect2(x, fy - h, T, h), Palette.N3)
				draw_rect(Rect2(x, fy - h, T, 1), Palette.N5)
				draw_rect(Rect2(x, fy - h + 1, T, 1), Palette.N4)
				draw_rect(Rect2(x, fy - 3, T, 3), Palette.N2)
				if cx % 4 == 0:
					draw_rect(Rect2(x, fy - h + 2, 1, h - 5), Palette.N2)
			if _is_slab(tm, c, -1):
				draw_rect(Rect2(x, cy * T, T, 4), Palette.N2)
				draw_rect(Rect2(x, cy * T + 4, T, 1), Palette.N4)


## c 是空格，dir=1 看下方楼板、-1 看上方楼板
func _is_slab(tm: TileMapLayer, c: Vector2i, dir: int) -> bool:
	var s := c + Vector2i(0, dir)
	if not (_solid(tm, s) and _solid(tm, s + Vector2i(0, dir))):
		return false
	var run := 1
	for side in [-1, 1]:
		var k := 1
		while k < 4 and not _solid(tm, c + Vector2i(side * k, 0)) and _solid(tm, s + Vector2i(side * k, 0)):
			k += 1
			run += 1
	return run >= 4
