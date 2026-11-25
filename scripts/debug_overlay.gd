class_name DebugOverlay
extends Node
## 调试覆盖层。挂在关卡根节点下即可：左上角实时显示玩家状态，方便复现手感 / 瞬移类问题。
## 开局武器、是否允许二段跳已经移到关卡根节点检查器的「关卡设置」里（Level.initial_weapon 等）。

@export_group("信息面板")
@export var show_panel := true
@export var panel_position := Vector2(4, 24)

var _label: Label
var _layer: CanvasLayer
var _player: Player


## 面板挂在根视口，关卡被释放时一起删掉（关卡移进 SubViewport 时也会 exit_tree，所以不能用 tree_exiting）
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_layer):
		_layer.queue_free()


func _ready() -> void:
	if show_panel:
		_build_panel()


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
	var suffix := "∞" if p.weapon_queue.is_empty() and not WeaponDefs.is_none(p.current_weapon()) else ""
	_label.text = "POS %.1f, %.1f   VEL %.1f, %.1f\nFLR %d  AIR %d  FROZEN %d  Q %d  BMR %s  INV %d\nWPN %s%s" % [
		p.global_position.x, p.global_position.y,
		p.velocity.x, p.velocity.y,
		int(p.is_on_floor()), p.air_jumps_left(), int(Game.frozen), p.weapon_queue.size(), bmr,
		int(p.is_invincible()), wname, suffix,
	]