extends "res://tools/build_art.gd"
## 测试关 level_02 生成工具（一次性，非游戏代码）。在工程根目录运行：
##   godot --headless --path . res://tools/build_level02.tscn
## 读 tools/art/map_level02.txt 的 ASCII，生成 levels/level_02.tscn：墙体（blob 自动拼接）、高压电层、
## 实体，再套用 build_art 的窗外背景、背景墙和装饰物件。
## 与 build_art 不同：不重建 street_tileset.tres，也不碰 level_01（保留你在编辑器里的改动）。
## 关卡已存在时不覆盖，要覆盖加：  -- --force
##
## 图例：# 墙  ~ 高压电  P 玩家  G 地面守卫(朝右)  g 地面守卫(朝左)  F 无人机
##       A 气枪拾取  Z 刺剑替换区(1×3，字符在最下一格)  D 飞镖替换区  E 出口

## 子类（如 build_level06.gd）在 _init 里改这三个值，复用同一套生成流程
var map_path := "res://tools/art/map_level02.txt"
var out_path := "res://levels/level_02.tscn"
var level_name := "Level02"
const ELECTRIC_TS := "res://assets/tiles/electric_tileset.tres"


func _ready() -> void:
	if FileAccess.file_exists(out_path) and not "--force" in OS.get_cmdline_user_args():
		print("[level02] 已存在，跳过：", out_path)
		get_tree().quit()
		return
	_load_masks()
	var ts: TileSet = load(TILESET_PATH)
	var rows := FileAccess.get_file_as_string(map_path).strip_edges().split("\n")
	var root := Node2D.new()
	root.name = level_name
	root.set_script(load("res://scripts/level.gd"))
	_configure_root(root)
	_add_env(root)
	var tm := TileMapLayer.new()
	tm.name = "Walls"
	tm.tile_set = ts
	_own_add(root, root, tm)
	var el := ElectricLayer.new()
	el.name = "Electric"
	el.tile_set = load(ELECTRIC_TS)
	_own_add(root, root, el)
	var ents := Node2D.new()
	ents.name = "Entities"
	_own_add(root, root, ents)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			match row[x]:
				"#":
					tm.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
				"~":
					el.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
				".":
					pass
				var ch:
					_place_entity(root, ents, ch, x, y)
	_repaint(tm, ts)
	_dress(root, tm)
	var ps := PackedScene.new()
	ps.pack(root)
	print("[level02] ", out_path, " -> ", ResourceSaver.save(ps, out_path))
	root.free()
	get_tree().quit()

## 子类覆盖：写关卡设置等根节点属性
func _configure_root(_root: Node) -> void:
	pass


## 只读 street_tiles.json 的掩码表（_repaint 要用），不重存 TileSet
func _load_masks() -> void:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TILES_JSON))
	for e in meta["tiles"]:
		var m := int(e["mask"])
		if not _tiles_by_mask.has(m):
			_tiles_by_mask[m] = []
		_tiles_by_mask[m].append([Vector2i(int(e["x"]), int(e["y"])), float(e["prob"])])


func _own_add(root: Node, parent: Node, n: Node) -> void:
	parent.add_child(n, true)
	n.owner = root


## 辉光设置与 level_01 相同
func _add_env(root: Node) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.05
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	_own_add(root, root, we)


func _dress(root: Node, tm: TileMapLayer) -> void:
	var bd: Node = (load(BACKDROP_PATH) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	bd.name = "Backdrop"
	_add_before(root, bd, tm)
	var bw := BackWall.new()
	bw.name = "BackWall"
	_add_before(root, bw, tm)
	var decor := Node2D.new()
	decor.name = "Decor"
	_add_before(root, decor, tm)
	_place_decor(root, decor, tm)

func _place_entity(root: Node, ents: Node, ch: String, x: int, y: int) -> void:
	var cx := x * T + T / 2.0
	var floor_y := float((y + 1) * T)          # 该格底边（站立面）
	var n: Node2D
	match ch:
		"P":
			n = load("res://scenes/player.tscn").instantiate()
			n.position = Vector2(cx, floor_y - 5)
			_own_add(root, root, n)
			return
		"G", "g":
			n = load("res://scenes/ground_guard.tscn").instantiate()
			n.position = Vector2(cx, floor_y - 6)
			n.set("facing", 1 if ch == "G" else -1)
		"F":
			n = load("res://scenes/flying_guard.tscn").instantiate()
			n.position = Vector2(cx, y * T + T / 2.0)
		"d", "A":
			n = load("res://scenes/weapon_pickup.tscn").instantiate()
			n.position = Vector2(cx, y * T + T / 2.0)
			n.set("weapon_type", 0 if ch == "d" else 3)
			n.set("ammo", 3)
		"Z", "D":
			n = load("res://scenes/weapon_zone.tscn").instantiate()
			n.position = Vector2(x * T, (y - 2) * T)     # 原点在左上角，1×3 向上占 3 格
			n.set("weapon_type", 4 if ch == "Z" else 0)
		"E":
			n = load("res://scenes/exit.tscn").instantiate()
			n.position = Vector2(cx, floor_y - 8)
		_:
			push_warning("未知字符 '%s' @ (%d,%d)" % [ch, x, y])
			return
	_own_add(root, ents, n)
