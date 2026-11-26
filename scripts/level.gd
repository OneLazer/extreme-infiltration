class_name Level
extends Node2D
## 关卡根节点。统计守卫数量、处理死亡重开与通关、显示 HUD。
## 子节点约定：一个 TileMapLayer（墙体）、一个 Player 实例、若干守卫/拾取物/出口。
## 表现：开场转场、死亡倒带、清场慢动作、通关横幅都在这里串起来（ScreenFx 负责画）。

@export_file("*.tscn") var next_level := ""   ## 通关后进入的关卡，留空则重开本关
@export var restart_delay := 0.15            ## 死亡后到开始倒带的停顿（真实时间）

@export_group("关卡设置")
## 玩家开局的主武器（无限弹药，武器队列打空后回到它）。无武器 = 徒手，不能开火
@export_enum("无武器:-1", "飞镖:0", "回旋镖:1", "重型回旋镖:2", "气枪:3", "刺剑:4") var initial_weapon := 0
@export var allow_double_jump := true        ## 关闭后本关不能二段跳（冲刺中也不能用二段跳打断）

var enemies_left := 0
var enemies_total := 0
var time := 0.0
## 计时门倒计时：timer_left < 0 表示没在倒计时。由 TimerGate 调 start_countdown 开始
var timer_left := -1.0
var timer_total := 0.0
var _done := false
var _hud: Hud
var _hud_layer: CanvasLayer
var _banner: Banner
var _pause_layer: CanvasLayer


func _ready() -> void:
	Game.level = self
	Game.booted = true         # 直接运行关卡（F6）后再回主菜单，不再播开机动画
	Game.frozen = false
	Game.reset_time()
	var juice := Juice.new()
	juice.name = "Juice"
	add_child(juice)
	juice.setup(self, get_node_or_null("Walls") as TileMapLayer)
	for g in get_tree().get_nodes_in_group("enemies"):
		enemies_left += 1
		(g as Guard).killed.connect(_on_guard_killed)
	enemies_total = enemies_left
	_build_hud()
	_setup_camera()
	if Game.player:
		_apply_settings(Game.player)
		Game.player.died.connect(_on_player_died)
		Sfx.bind_player(Game.player)
	ScreenFx.wipe_in()
	Sfx.play("wipe_in", 0.0, -6.0)


## 关卡设置写入玩家（Player 是子节点，这时已经 _ready 过）
func _apply_settings(p: Player) -> void:
	p.initial_weapon = initial_weapon
	p.weapon_queue.clear()
	if not allow_double_jump:
		p.air_jump_count = 0
	p.weapons_changed.emit()


func _physics_process(delta: float) -> void:
	if not _done and not Game.frozen and Game.player and not Game.player.dead:
		time += delta
		_tick_countdown(delta)


## 计时门开始（或重置）倒计时
func start_countdown(sec: float) -> void:
	if _done:
		return
	timer_total = sec
	timer_left = sec
	if _hud:
		_hud.countdown_started()
	toast("限时 %d 秒" % int(ceil(sec)), Palette.TIMER)
	Sfx.play("timer_start")


func countdown_active() -> bool:
	return timer_left >= 0.0


func is_done() -> bool:
	return _done


## 倒计时：最后 5 秒每过一整秒脉冲一下、屏幕边缘泛红越来越重；归零即超时死亡
func _tick_countdown(delta: float) -> void:
	if timer_left < 0.0:
		return
	var before := timer_left
	timer_left = maxf(timer_left - delta, 0.0)
	if timer_left < 5.0:
		ScreenFx.danger(0.35 + 0.65 * (1.0 - timer_left / 5.0))
		if ceilf(timer_left) < ceilf(before):
			ScreenFx.pulse(1.0 + (5.0 - ceilf(timer_left)) * 0.3)
			if _hud:
				_hud.countdown_tick()
			Sfx.play("timer_tick", 0.0, 0.0, 1.0 + (5.0 - ceilf(timer_left)) * 0.06)
	if timer_left <= 0.0:
		Game.player.die_timeout()


func _unhandled_input(event: InputEvent) -> void:
	# 死亡倒带途中按 R = 跳过倒带直接重开（ScreenFx 会作废旧的倒带）。
	# 通关后正在切下一关时不响应：否则重开后旧的切关协程还挂着，下次转场会突然跳关
	if event.is_action_pressed("restart") and not _done:
		PixelView.reload()


func _on_guard_killed(_g: Guard) -> void:
	enemies_left -= 1
	ScreenFx.pulse(1.5)
	if enemies_left <= 0:
		Game.slowmo(0.25, 0.7)     # 清场最后一击：慢动作 + 闪白
		ScreenFx.pulse(3.0)
		ScreenFx.flash(0.25)
		_banner.show_text("出口已开启", "前往电梯", 1.6)
		Sfx.play("clear_all")


func _on_player_died() -> void:
	Game.hitstop(0.12)
	var cam := Game.player.get_node_or_null("Camera2D")
	if cam:
		cam.shake(4.0, 0.3)
	if Game.player.death_cause == "timeout":
		_banner.show_text("时间到", "", 0.5)
	await get_tree().create_timer(restart_delay, true, false, true).timeout
	Sfx.play("rewind")
	await ScreenFx.death_rewind()
	PixelView.reload()


func complete() -> void:
	if _done:
		return
	_done = true
	Game.player.set_physics_process(false)
	# 正式关卡（在 Levels 表里）记录用时、解锁下一关
	var idx := Levels.index_of(scene_file_path)
	var record := Progress.record_clear(idx, time)
	var sub := Levels.fmt_time(time)
	if record and idx >= 0:
		sub += "  NEW BEST"
	_banner.show_text("目标清除", sub, 99.0)
	Sfx.play("level_clear")
	await get_tree().create_timer(1.3, true, false, true).timeout
	if next_level != "":
		Game.goto_scene(next_level)
	elif idx >= 0 and idx + 1 < Levels.count():
		Game.goto_scene(Levels.path(idx + 1))
	elif idx == Levels.count() - 1:
		Game.to_menu("credits")          # 最后一关：致谢
	else:
		await ScreenFx.wipe_out()
		PixelView.reload()


## 左上武器栏下方的一行小提示（换主武器等），不挡视线
func toast(text: String, col: Color) -> void:
	if _hud:
		_hud.toast(text, col)


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
	# ESC 暂停菜单：单独一层，盖在 HUD 上、转场下
	_pause_layer = CanvasLayer.new()
	_pause_layer.layer = 70
	PixelView.hud_root.add_child(_pause_layer)
	var pm := PauseMenu.new()
	pm.level = self
	_pause_layer.add_child(pm)


## 关卡被释放时删掉挂在根视口的 HUD（reparent 进 SubViewport 不会触发这里）
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if is_instance_valid(_hud_layer):
			_hud_layer.queue_free()
		if is_instance_valid(_pause_layer):
			_pause_layer.queue_free()


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
