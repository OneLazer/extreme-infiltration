extends Node
## 白盒生成脚本（一次性工具，非游戏代码）。在工程根目录运行：
##   godot --headless --path . res://tools/build_whitebox.tscn
## 也可以在编辑器里打开 build_whitebox.tscn 按 F6 运行。
## 作用：写入输入映射 → 生成 TileSet → 用下方 ASCII 生成示例关卡 level_01.tscn。
## 关卡已存在时不会覆盖，需覆盖请在命令末尾加：  -- --force
##
## ASCII 图例：# 墙  P 玩家  G 普通守卫(朝右)  g 普通守卫(朝左)  F 飞行守卫
##            b 回旋镖  B 重型回旋镖  A 气枪  E 出口

const TILESET_PATH := "res://assets/tiles/neon_tileset.tres"
const TEXTURE_PATH := "res://assets/tiles/neon_tiles.png"
const LEVEL_PATH := "res://levels/level_01.tscn"
const T := 8

const MAP := [
	"################################################################################",
	"#..............................................................................#",
	"#..............................................................................#",
	"#..............................................................................#",
	"#................................................................F.............#",
	"#..............................................................................#",
	"#.................#..##........................................................#",
	"#.................#..##................................F.......................#",
	"#.................#..##.......F................................................#",
	"#.................#..##........................................................#",
	"#.................#..##........................................................#",
	"#.................#..##...............................................g......E.#",
	"#.................#..##...........................##############################",
	"#.................#..##...........................##############################",
	"#.................#..##...........................##############################",
	"#.........F.......#..##...........................##############################",
	"#.................#..##...........................##############################",
	"#.................#..##...........................##############################",
	"#.......#####.....#..##..........##...............##############################",
	"#....................##..........##...............##############################",
	"#..P..b........G.....##...B......##.....g....A....##############################",
	"################################################################################",
	"################################################################################",
]


func _ready() -> void:
	_setup_input()
	var ts := _build_tileset()
	if FileAccess.file_exists(LEVEL_PATH) and not "--force" in OS.get_cmdline_user_args():
		print("[build] 关卡已存在，跳过：", LEVEL_PATH)
	else:
		_build_level(ts)
	get_tree().quit()


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.device = -1   # 所有设备
	return e


func _setup_input() -> void:
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.device = -1
	var map := {
		"move_left": [KEY_A], "move_right": [KEY_D], "jump": [KEY_SPACE],
		"fire": [mouse],
		"restart": [KEY_R],
	}
	for action in map:
		var events: Array = []
		for e in map[action]:
			events.append(e if e is InputEvent else _key(e))
		ProjectSettings.set_setting("input/" + action, {"deadzone": 0.2, "events": events})
	ProjectSettings.save()
	print("[build] 输入映射已写入 project.godot")


func _build_tileset() -> TileSet:
	if FileAccess.file_exists(TILESET_PATH):
		print("[build] TileSet 已存在，直接使用：", TILESET_PATH)
		return load(TILESET_PATH)
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)   # world
	ts.set_physics_layer_collision_mask(0, 0)
	var src := TileSetAtlasSource.new()
	src.texture = load(TEXTURE_PATH)
	src.texture_region_size = Vector2i(T, T)
	ts.add_source(src, 0)
	var h := T / 2.0
	var square := PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	for x in 2:   # (0,0) 青色墙  (1,0) 品红墙，都带碰撞
		var c := Vector2i(x, 0)
		src.create_tile(c)
		var td := src.get_tile_data(c, 0)
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, square)
	var err := ResourceSaver.save(ts, TILESET_PATH)
	print("[build] TileSet 保存：", TILESET_PATH, " err=", err)
	return load(TILESET_PATH)


func _build_level(ts: TileSet) -> void:
	var root := Node2D.new()
	root.name = "Level01"
	root.set_script(load("res://scripts/level.gd"))

	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	_add(root, root, we)

	var tm := TileMapLayer.new()
	tm.name = "Walls"
	tm.tile_set = ts
	_add(root, root, tm)

	var ents := Node2D.new()
	ents.name = "Entities"
	_add(root, root, ents)

	var scenes := {
		"P": load("res://scenes/player.tscn"), "G": load("res://scenes/ground_guard.tscn"),
		"F": load("res://scenes/flying_guard.tscn"), "b": load("res://scenes/weapon_pickup.tscn"),
		"E": load("res://scenes/exit.tscn"),
	}
	for y in MAP.size():
		var row: String = MAP[y]
		for x in row.length():
			var ch := row[x]
			if ch == "#":
				tm.set_cell(Vector2i(x, y), 0, Vector2i(1 if x >= 50 and y >= 12 else 0, 0))
			elif ch != ".":
				_place(root, ents, scenes, ch, x, y)

	var ps := PackedScene.new()
	ps.pack(root)
	var err := ResourceSaver.save(ps, LEVEL_PATH)
	print("[build] 关卡保存：", LEVEL_PATH, " err=", err)
	ProjectSettings.set_setting("application/run/main_scene", LEVEL_PATH)
	ProjectSettings.save()
	root.free()


func _add(root: Node, parent: Node, n: Node) -> void:
	parent.add_child(n, true)
	n.owner = root


func _place(root: Node, ents: Node, scenes: Dictionary, ch: String, x: int, y: int) -> void:
	var cx := x * T + T / 2.0
	var floor_y := (y + 1) * T          # 该格底边（站立面）
	var n: Node2D
	match ch:
		"P":
			n = scenes["P"].instantiate()
			n.position = Vector2(cx, floor_y - 5)
			_add(root, root, n)     # 玩家直接挂在关卡根节点下
			return
		"G", "g":
			n = scenes["G"].instantiate()
			n.position = Vector2(cx, floor_y - 6)
			n.set("facing", 1 if ch == "G" else -1)
		"F":
			n = scenes["F"].instantiate()
			n.position = Vector2(cx, y * T + T / 2.0)
		"b", "B", "A":
			n = scenes["b"].instantiate()
			n.position = Vector2(cx, y * T + T / 2.0)
			n.set("weapon_type", {"b": 1, "B": 2, "A": 3}[ch])
			n.set("ammo", 3)
		"E":
			n = scenes["E"].instantiate()
			n.position = Vector2(cx, floor_y - 8)
		_:
			push_warning("未知字符 '%s' @ (%d,%d)" % [ch, x, y])
			return
	_add(root, ents, n)
