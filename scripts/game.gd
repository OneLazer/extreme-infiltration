extends Node
## 全局单例（Autoload: Game）。保存当前玩家/关卡引用，以及瞄准冻结状态。
## 另管顿帧（hitstop）与慢动作：都用真实时间计时，不受 Engine.time_scale 影响。

## 物理层（与 项目设置 > 层名称 一致）
const LAYER_WORLD := 1      # 第1层 world：TileMap 墙体
const LAYER_PLAYER := 2     # 第2层 player
const LAYER_ENEMY := 4      # 第3层 enemy：守卫（Area2D）
const LAYER_TRIGGER := 8    # 第4层 trigger：拾取物、出口

const TILE := 8.0           # 图格像素尺寸

var player: Player
var level: Level
## 当前关卡的高压电层（ElectricLayer 在 _enter_tree 里登记，可以有多层），没有则为空
var electric_layers: Array[TileMapLayer] = []
## 瞄准冻结期间为 true。守卫、回旋镖等在冻结时暂停逻辑。
var frozen := false
## 主菜单打开时先进哪一页："" = 主页，"credits" = 最后一关通关后的致谢
var menu_page := ""
## 本次运行是否已经播过主菜单开机动画（只在启动游戏时播一次）
var booted := false

var _stop_until := 0.0      # 顿帧结束时刻（秒，真实时间）
var _slow_until := 0.0
var _slow_scale := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func register_electric(layer: TileMapLayer) -> void:
	if not electric_layers.has(layer):
		electric_layers.append(layer)


func unregister_electric(layer: TileMapLayer) -> void:
	electric_layers.erase(layer)


## 某个点是否在高压电格里
func is_electric(p: Vector2) -> bool:
	for e in electric_layers:
		if is_instance_valid(e) and e.get_cell_source_id(e.local_to_map(e.to_local(p))) >= 0:
			return true
	return false


## 矩形（全局坐标）是否碰到任何高压电格
func electric_overlaps(r: Rect2) -> bool:
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return false
	for e in electric_layers:
		if not is_instance_valid(e):
			continue
		var a := e.local_to_map(e.to_local(r.position))
		var b := e.local_to_map(e.to_local(r.end - Vector2(0.001, 0.001)))
		for y in range(a.y, b.y + 1):
			for x in range(a.x, b.x + 1):
				if e.get_cell_source_id(Vector2i(x, y)) >= 0:
					return true
	return false


## 矩形 r 沿 motion 平移的路径上第一次碰到电格的位置比例（0..1），没碰到返回 -1。
## 按 2px 步长采样（受击框最窄 4px，不会漏掉一整格）。瞬移类位移（飞镖）用它查路径。
func electric_sweep(r: Rect2, motion: Vector2) -> float:
	if electric_layers.is_empty():
		return -1.0
	var steps := maxi(int(ceil(motion.length() / 2.0)), 1)
	for i in steps + 1:
		var f := float(i) / steps
		if electric_overlaps(Rect2(r.position + motion * f, r.size)):
			return f
	return -1.0


## 顿帧：整个游戏停 sec 秒（命中、击杀的重量感）。重叠时取更晚的结束时刻。
func hitstop(sec: float) -> void:
	_stop_until = maxf(_stop_until, _now() + sec)
	_apply()


## 慢动作：time_scale 降到 scale，持续 sec 秒（真实时间）
func slowmo(scale: float, sec: float) -> void:
	_slow_scale = scale
	_slow_until = maxf(_slow_until, _now() + sec)
	_apply()


## 回主菜单：盖上转场再切场景。page 见 menu_page
func to_menu(page := "") -> void:
	menu_page = page
	get_tree().paused = false
	await ScreenFx.wipe_out()
	PixelView.change_scene(Levels.MENU)


## 进入某个场景（关卡）：盖上转场再切
func goto_scene(path: String) -> void:
	get_tree().paused = false
	await ScreenFx.wipe_out()
	PixelView.change_scene(path)


func reset_time() -> void:
	_stop_until = 0.0
	_slow_until = 0.0
	Engine.time_scale = 1.0


func _process(_delta: float) -> void:
	_apply()


func _apply() -> void:
	var t := _now()
	if t < _stop_until:
		Engine.time_scale = 0.0
	elif t < _slow_until:
		# 慢动作最后 0.25 秒平滑回到正常速度
		var left := (_slow_until - t)
		Engine.time_scale = lerpf(1.0, _slow_scale, clampf(left / 0.25, 0.0, 1.0))
	else:
		Engine.time_scale = 1.0


func _now() -> float:
	return Time.get_ticks_usec() / 1000000.0
