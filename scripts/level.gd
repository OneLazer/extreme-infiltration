class_name Level
extends Node2D
## 关卡根节点。统计守卫数量、处理死亡重开与通关、显示 HUD。
## 子节点约定：一个 TileMapLayer（墙体）、一个 Player 实例、若干守卫/拾取物/出口。
## 表现：开场转场、死亡倒带、清场慢动作、通关横幅都在这里串起来（ScreenFx 负责画）。

@export_file("*.tscn") var next_level := ""   ## 通关后进入的关卡，留空则重开本关
@export var restart_delay := 0.15            ## 死亡后到开始倒带的停顿（真实时间）

var enemies_left := 0
var time := 0.0
var _done := false
var _hud: Hud
var _hud_layer: CanvasLayer
var _banner: Banner


func _ready() -> void:
	Game.level = self
	Game.frozen = false
	Game.reset_time()
	var juice := Juice.new()
	juice.name = "Juice"
	add_child(juice)
	juice.setup(self, get_node_or_null("Walls") as TileMapLayer)
	for g in get_tree().get_nodes_in_group("enemies"):
		enemies_left += 1
		(g as Guard).killed.connect(_on_guard_killed)
	_build_hud()
	_setup_camera()
	if Game.player:
		Game.player.died.connect(_on_player_died)
	ScreenFx.wipe_in()


func _physics_process(delta: float) -> void:
	if not _done and not Game.frozen and Game.player and not Game.player.dead:
		time += delta


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		PixelView.reload()


func _on_guard_killed(_g: Guard) -> void:
	enemies_left -= 1
	ScreenFx.pulse(1.5)
	if enemies_left <= 0:
		Game.slowmo(0.25, 0.7)     # 清场最后一击：慢动作 + 闪白
		ScreenFx.pulse(3.0)
		ScreenFx.flash(0.25)
		_banner.show_text("出口已开启", "前往电梯", 1.6)


func _on_player_died() -> void:
	Game.hitstop(0.12)
	var cam := Game.player.get_node_or_null("Camera2D")
	if cam:
		cam.shake(4.0, 0.3)
	await get_tree().create_timer(restart_delay, true, false, true).timeout
	await ScreenFx.death_rewind()
	PixelView.reload()


func complete() -> void:
	if _done:
		return
	_done = true
	Game.player.set_physics_process(false)
	_banner.show_text("目标清除", "%02d:%05.2f" % [int(time / 60.0), fmod(time, 60.0)], 99.0)
	await get_tree().create_timer(1.3, true, false, true).timeout
	await ScreenFx.wipe_out()
	if next_level != "":
		PixelView.change_scene(next_level)
	else:
		PixelView.reload()


func _build_hud() -> void:
	# HUD 挂在根视口（PixelView.hud_root），按窗口分辨率渲染；关卡销毁时一起删掉
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 60          # 在后期层（50）之上：HUD 不吃色差和暗角
	PixelView.hud_root.add_child(_hud_layer)
	_hud = Hud.new()
	_hud.level = self
	_hud_layer.add_child(_hud)
	_banner = Banner.new()
	_hud_layer.add_child(_banner)


## 关卡被释放时删掉挂在根视口的 HUD（reparent 进 SubViewport 不会触发这里）
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_hud_layer):
		_hud_layer.queue_free()


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
