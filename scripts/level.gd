class_name Level
extends Node2D
## 关卡根节点。统计守卫数量、处理死亡重开与通关、显示 HUD。
## 子节点约定：一个 TileMapLayer（墙体）、一个 Player 实例、若干守卫/拾取物/出口。

@export_file("*.tscn") var next_level := ""   ## 通关后进入的关卡，留空则重开本关
@export var restart_delay := 0.6

var enemies_left := 0
var time := 0.0
var _done := false
var _hud: Label
var _banner: Label


func _ready() -> void:
	Game.level = self
	Game.frozen = false
	for g in get_tree().get_nodes_in_group("enemies"):
		enemies_left += 1
		(g as Guard).killed.connect(_on_guard_killed)
	_build_hud()
	_setup_camera()
	if Game.player:
		Game.player.died.connect(_on_player_died)
		Game.player.weapons_changed.connect(_refresh_hud)
	_refresh_hud()


func _physics_process(delta: float) -> void:
	if not _done and not Game.frozen and Game.player and not Game.player.dead:
		time += delta
		_refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


func _on_guard_killed(_g: Guard) -> void:
	enemies_left -= 1
	_refresh_hud()


func _on_player_died() -> void:
	_banner.text = "失败  ·  R 重开"
	await get_tree().create_timer(restart_delay).timeout
	get_tree().reload_current_scene()


func complete() -> void:
	if _done:
		return
	_done = true
	_banner.text = "通关  %.2f 秒" % time
	Game.player.set_physics_process(false)
	await get_tree().create_timer(1.2).timeout
	if next_level != "":
		get_tree().change_scene_to_file(next_level)
	else:
		get_tree().reload_current_scene()


func _refresh_hud() -> void:
	if _hud == null or Game.player == null:
		return
	var parts: Array[String] = []
	for w in Game.player.weapon_queue:
		parts.append("%s×%d" % [WeaponDefs.get_def(w["type"])["name"], w["ammo"]])
	parts.append("回旋镖∞")
	_hud.text = "武器  %s\n守卫  %d    时间  %.1f" % [" → ".join(parts), enemies_left, time]


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var ls := LabelSettings.new()
	ls.font_size = 7
	ls.outline_size = 2
	ls.outline_color = Color(0, 0, 0, 0.8)
	_hud = Label.new()
	_hud.label_settings = ls
	_hud.position = Vector2(4, 2)
	layer.add_child(_hud)
	_banner = Label.new()
	_banner.label_settings = ls.duplicate()
	_banner.label_settings.font_size = 12
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(_banner)


func _setup_camera() -> void:
	if Game.player == null:
		return
	var cam: Camera2D = Game.player.get_node_or_null("Camera2D")
	var tiles := find_children("*", "TileMapLayer", false, false)
	if cam == null or tiles.is_empty():
		return
	var tm := tiles[0] as TileMapLayer
	var r := tm.get_used_rect()
	var ts := tm.tile_set.tile_size
	cam.limit_left = r.position.x * ts.x
	cam.limit_top = r.position.y * ts.y
	cam.limit_right = r.end.x * ts.x
	cam.limit_bottom = r.end.y * ts.y
	cam.reset_smoothing()
