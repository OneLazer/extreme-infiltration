class_name DebugOverlay
extends Node
## 调试覆盖层。挂在关卡根节点下即可：
##   1. 检查器「初始武器」里选武器 → 替换玩家开局主武器（走兜底通道，弹药无限）
##   2. 左上角实时显示玩家状态，方便复现手感 / 瞬移类问题
## 运行时修改检查器里的枚举会立刻生效，不需要重开关卡。

@export_group("初始武器")
@export var enabled := true                 ## 关闭后只显示信息，不改武器
@export_enum("飞镖:0", "回旋镖:1", "重型回旋镖:2", "气枪:3")
var initial_weapon: int:
	get:
		return _initial_weapon
	set(value):
		_initial_weapon = value
		if is_inside_tree() and not Engine.is_editor_hint():
			_apply.call_deferred()
@export var clear_weapon_queue := true      ## 应用时清空已拾取的武器

@export_group("信息面板")
@export var show_panel := true
@export var panel_position := Vector2(4, 24)

var _initial_weapon := WeaponDefs.Type.DART
var _label: Label
var _layer: CanvasLayer


## 面板挂在根视口，关卡被释放时一起删掉（关卡移进 SubViewport 时也会 exit_tree，所以不能用 tree_exiting）
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_layer):
		_layer.queue_free()
var _player: Player


func _ready() -> void:
	if show_panel:
		_build_panel()
	_apply.call_deferred()


## 把检查器设置写入玩家。初始武器是「队列空时的兜底武器」，天然无限弹药。
func _apply() -> void:
	_player = _find_player()
	if _player == null:
		push_warning("DebugOverlay：场景中找不到 Player")
		return
	if not enabled:
		return
	_player.initial_weapon = initial_weapon
	if clear_weapon_queue:
		_player.weapon_queue.clear()
	_player.weapons_changed.emit()


func _find_player() -> Player:
	if is_instance_valid(Game.player):
		return Game.player
	for n in get_tree().get_nodes_in_group("player"):
		if n is Player:
			return n
	return null


func _build_panel() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 61
	# 挂到根视口按窗口分辨率渲染（关卡在 320×180 的 SubViewport 里，挂在关卡下会糊）
	PixelView.hud_root.add_child(layer)
	_layer = layer
	var ls := LabelSettings.new()
	ls.font = UiFonts.text()
	ls.font_size = 6
	ls.outline_size = 1
	ls.outline_color = Color(0, 0, 0, 0.85)
	_label = Label.new()
	_label.label_settings = ls
	_label.position = panel_position
	layer.add_child(_label)


func _process(_delta: float) -> void:
	if _label == null:
		return
	if not is_instance_valid(_player):
		_player = _find_player()
	if _player == null:
		_label.text = "DEBUG  无玩家"
		return
	var p := _player
	var bmr := "-"
	if is_instance_valid(p.active_boomerang):
		bmr = ["OUT", "IDLE", "RETURN"][p.active_boomerang.state]
	var wname := str(WeaponDefs.get_def(p.current_weapon())["name"])
	var suffix := "∞" if p.weapon_queue.is_empty() else ""
	_label.text = "POS %.1f, %.1f   VEL %.1f, %.1f\nFLR %d  AIR %d  FROZEN %d  Q %d  BMR %s\nWPN %s%s" % [
		p.global_position.x, p.global_position.y,
		p.velocity.x, p.velocity.y,
		int(p.is_on_floor()), p.air_jumps_left(), int(Game.frozen), p.weapon_queue.size(), bmr,
		wname, suffix,
	]
