class_name Guard
extends Area2D
## 守卫基类：视野、警戒条、状态机（游荡 / 追击 / 搜索 / 回位）、游荡移动、死亡特效。
## 子类只决定「怎么动」（_try_move、_pick_wander_point）和「满条后做什么」（_on_alert_full），
## 以及精灵绘制。场景里 collision_layer = enemy(第3层)，collision_mask = player(第2层)。
##
## 警戒条（0..1）：锁定时以 1 / alert_fill_time 的速度上涨；丢锁时若高于 alert_floor（50%），
## 以上涨速度的 alert_decay_mult（1/3）降到 50%，否则不动。所以偷看一眼的进度会一直保留。
## 警戒条到过 50% 的守卫永久警戒：丢锁后一直在最后看见玩家的地方搜索，不再回原位。
##
## 视野：基础扇形（view_range / view_half_angle，半角 180 = 全向）+ 视线无遮挡即锁定；
## 锁定后不再看距离和角度，只要视线通就一直盯着（同旧版硬锁定）。搜索状态下扇形放大 search_view_mult 倍。
## 扇形只是表现：锁定后中心平滑转向玩家、半角收成一条线、长度伸到墙边。

signal killed(guard: Guard)

enum State { PATROL, CHASE, SEARCH, RETURN }

const ARMOR := [Color("#262540"), Color("#55577a"), Color("#73759a"), Color("#aeb0d0")]

@export_group("视野")
@export var view_range := 96.0          ## 视野距离（px）
@export var view_half_angle := 35.0     ## 视野半角（度），180 = 全向
@export var search_view_mult := 1.5     ## 搜索（警戒）状态下视野距离与半角的倍率
@export var cone_rays := 16             ## 视野扇形的射线数（只影响表现）

@export_group("警戒条")
@export var alert_fill_time := 1.0      ## 锁定时警戒条从 0 涨满的时间（秒）
@export var alert_floor := 0.5          ## 丢锁后高于此值时慢慢降到这里；不高于时保持不动
@export var alert_decay_mult := 1.0 / 3.0  ## 下降速度 = 上涨速度 × 此值
@export var search_time := 4.0          ## 警戒条没过 50% 的守卫丢锁后搜索多久回原位

@export_group("游荡与追击")
@export var wander := true              ## 关闭后原地不动（仍会追击）
@export var wander_tiles := Vector2i(5, 1)  ## 游荡范围（图格），以摆放位置为中心
@export var wander_speed := 20.0        ## 游荡速度（px/s）
@export var wander_pause := Vector2(1.0, 2.5)  ## 每段停顿的随机范围（秒）
@export var chase_speed := 40.0         ## 追击速度（px/s），低于玩家跑速 90
@export var search_speed := 30.0        ## 赶往最后目击点的速度
@export var chase_keep_tiles := 3.0     ## 追击时与玩家保持的距离（图格）
@export var accel := 160.0              ## 起步 / 刹车加速度（px/s²）

@export_group("锁定视觉")
@export var focus_half_angle := 0.0     ## 锁定后收窄到的视觉半角（度）；0 = 收成一条线
@export var lock_range := 8192.0        ## 锁定后的视觉长度（px），实际由墙裁切
@export var focus_speed := 9.0          ## 半角收窄 / 长度伸长的过渡速度
@export var turn_speed := 12.0          ## 扇形中心转向玩家的速度

var dead := false
var state := State.PATROL
var alert := 0.0                 # 警戒条 0..1

var _t := 0.0
var _home := Vector2.ZERO        # 摆放位置：游荡中心
var _locked := false             # 真锁定：视线通且已被发现
var _last_seen := Vector2.ZERO   # 最后看见玩家的位置（搜索中心）
var _search_left := 0.0
var _reached_seen := false       # 搜索时是否已经走到最后目击点
var _vel := Vector2.ZERO
var _target := Vector2.ZERO      # 当前游荡目标点
var _has_target := false
var _pause_left := 0.0
var _blocked_t := 0.0            # 走不动的累计时间（判定被挡住）
var _pop := 0.0                  # 头顶「!」/「?」弹出动画 1 → 0

var _cone := PackedVector2Array()
var _aim_end := Vector2.ZERO     # 中心瞄准线的落点（本地坐标）
var _focus := 0.0                # 视觉收束程度 0..1
var _aim_angle := 0.0            # 扇形中心当前朝向（弧度）


func _ready() -> void:
	add_to_group("enemies")
	_home = global_position
	_last_seen = global_position
	_aim_angle = _base_angle()
	_pause_left = randf_range(0.2, wander_pause.y)   # 错开各守卫的起步时间


func _physics_process(delta: float) -> void:
	if dead or Game.frozen:
		return
	var p := Game.player
	var alive := p != null and not p.dead
	var los := alive and _has_los(p)
	if _locked and not los:
		_on_lost()
	elif not _locked and los and _can_spot(p):
		_on_spotted()
	if _locked:
		_last_seen = p.global_position
		alert = minf(alert + delta / alert_fill_time, 1.0)
		if alert >= 1.0:
			_on_alert_full(p)
	elif alert > alert_floor:
		alert = maxf(alert - delta / alert_fill_time * alert_decay_mult, alert_floor)
	_update_state(delta, p)
	if alive and not dead:
		_touch_player(p)
	_pop = maxf(_pop - delta * 4.0, 0.0)
	_tick(delta)
	_update_vision(delta, p if _locked else null)
	if _locked and alert > 0.5:
		ScreenFx.danger(inverse_lerp(0.5, 1.0, alert))
	queue_redraw()

# ======================= 状态 =======================

## 警戒条到过 50%：永久警戒，丢锁后不再回原位
func is_vigilant() -> bool:
	return alert >= alert_floor - 0.0001


func is_locked() -> bool:
	return _locked


func _on_spotted() -> void:
	_locked = true
	state = State.CHASE
	_has_target = false
	_pause_left = 0.0
	_pop = 1.0
	Juice.ring(global_position + _eye(), 6.0, Palette.ALERT * Color(0.6, 0.6, 0.6), 0.16)


func _on_lost() -> void:
	_locked = false
	_enter_search(_last_seen)


func _enter_search(at: Vector2) -> void:
	state = State.SEARCH
	_last_seen = at
	_reached_seen = false
	_search_left = search_time
	_has_target = false
	_pause_left = 0.0
	_pop = 1.0


## 无人机警报：没锁定的守卫赶往警报位置搜索，警戒条至少拉到 60%（因此永久警戒）
func hear_alarm(at: Vector2) -> void:
	if dead:
		return
	alert = maxf(alert, 0.6)
	if not _locked:
		_enter_search(at)
		_aim_angle = (at - global_position).angle()


func _update_state(delta: float, p: Player) -> void:
	match state:
		State.CHASE:
			if p != null and not p.dead:
				_chase(delta, p)
			else:
				_brake(delta)
		State.SEARCH:
			if not _reached_seen:
				if _move_to(_last_seen, search_speed, delta):
					_reached_seen = true
					_pause_left = randf_range(0.4, 0.8)   # 到了先愣一下、四处张望
			else:
				_wander_around(_last_seen, delta, wander_speed * 1.25)
			if not is_vigilant():
				_search_left -= delta
				if _search_left <= 0.0:
					state = State.RETURN
					_has_target = false
		State.RETURN:
			if _move_to(_home, wander_speed, delta):
				state = State.PATROL
				_pause_left = randf_range(wander_pause.x, wander_pause.y)
		_:
			_wander_around(_home, delta, wander_speed)

# ======================= 移动 =======================

## 以 center 为中心游荡：停顿 → 随机选点 → 慢慢走过去 → 停顿……
func _wander_around(center: Vector2, delta: float, speed: float) -> void:
	if not wander or _pause_left > 0.0:
		_pause_left -= delta
		_brake(delta)
		_idle(delta)
		return
	if not _has_target:
		_target = _pick_wander_point(center)
		_has_target = true
	if _move_to(_target, speed, delta):
		_has_target = false
		_pause_left = randf_range(wander_pause.x, wander_pause.y)


## 朝 target 走，返回 true 表示到了（或被墙 / 平台边缘 / 电块挡住走不动了）。
## 最后 8px 减速，起步和刹车都按 accel 平滑，走起来有重量。
func _move_to(target: Vector2, speed: float, delta: float) -> bool:
	var to := _flatten(target - global_position)
	var dist := to.length()
	if dist < 1.0:
		_brake(delta)
		return _vel.length() < 4.0
	var want := to / dist * speed * clampf(dist / 8.0, 0.3, 1.0)
	_vel = _vel.move_toward(want, accel * delta)
	var expect := _vel.length() * delta
	var moved := _step(_vel * delta)
	if expect > 0.05 and moved.length() < expect * 0.3:
		_blocked_t += delta
	else:
		_blocked_t = 0.0
	if _blocked_t > 0.12:
		_blocked_t = 0.0
		_vel = Vector2.ZERO
		return true
	return false


func _brake(delta: float) -> void:
	_vel = _vel.move_toward(Vector2.ZERO, accel * delta)
	if _vel != Vector2.ZERO:
		_step(_vel * delta)


## 追击：朝玩家走，保持 chase_keep_tiles 的距离（碰到玩家会直接杀死，贴脸追太不讲理）
func _chase(delta: float, p: Player) -> void:
	var keep := chase_keep_tiles * Game.TILE
	var to := _flatten(p.global_position - global_position)
	if to.length() <= keep:
		_brake(delta)
	else:
		_move_to(p.global_position - to.normalized() * keep, chase_speed, delta)


## 在 center 周围 wander_tiles 范围内随机选一个可达点（_point_ok 由子类判定）
func _pick_wander_point(center: Vector2) -> Vector2:
	var half := Vector2(wander_tiles - Vector2i.ONE) * 0.5 * Game.TILE
	for i in 8:
		var pt := (center + Vector2(randf_range(-half.x, half.x), randf_range(-half.y, half.y))).round()
		pt = global_position + _flatten(pt - global_position)
		if (pt - global_position).length() >= 4.0 and _point_ok(pt):
			return pt
	return global_position

# ---------------- 子类覆盖 ----------------

## 移动 motion（全局坐标），返回实际移动量。子类负责墙 / 平台边缘 / 电块检测
func _step(motion: Vector2) -> Vector2:
	global_position += motion
	return motion


## 把移动向量投影到能走的轴上（地面守卫只走 X）
func _flatten(v: Vector2) -> Vector2:
	return v


## 游荡目标点是否可达
func _point_ok(_pt: Vector2) -> bool:
	return true


## 停顿时的小动作（回头看一眼等）
func _idle(_delta: float) -> void:
	pass


## 每帧附加逻辑（开枪闪光计时等）
func _tick(_delta: float) -> void:
	pass


## 警戒条满了：地面守卫开枪，无人机拉警报
func _on_alert_full(_p: Player) -> void:
	pass


## 未锁定时视野扇形的朝向（弧度）
func _base_angle() -> float:
	return 0.0


## 眼睛位置（本地坐标）：视线和视野扇形的起点
func _eye() -> Vector2:
	return Vector2(0, -3)


func eye() -> Vector2:
	return _eye()

# ======================= 接触 =======================

## 身体接触：玩家刺剑冲刺中 → 守卫被刺死；玩家无敌 → 无事；否则玩家死。
## 每帧查重叠而不是只听 body_entered：无敌结束时还贴在一起也要判定。
func _touch_player(p: Player) -> void:
	if not overlaps_body(p):
		return
	if p.is_rapier_attacking():
		p.rapier_kill(self)
	elif not p.is_invincible():
		p.die()

# ======================= 视野 =======================

func _view_mult() -> float:
	return search_view_mult if state == State.SEARCH else 1.0


func _view_half() -> float:
	return minf(view_half_angle * _view_mult(), 180.0)


## 基础扇形判定（距离 + 角度），只在未锁定时用来发现玩家
func _can_spot(p: Player) -> bool:
	var to := p.global_position - (global_position + _eye())
	if to.length() > view_range * _view_mult():
		return false
	var half := _view_half()
	if half >= 179.9:
		return true
	return absf(rad_to_deg(angle_difference(_base_angle(), to.angle()))) <= half


## 视线是否被墙挡住（掩体）。电块不挡视线
func _has_los(p: Player) -> bool:
	var q := PhysicsRayQueryParameters2D.create(global_position + _eye(), p.global_position, Game.LAYER_WORLD)
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


## 视觉更新：锁定后扇形中心转向玩家，同时收成一条线并伸长（纯表现，不参与判定）
func _update_vision(delta: float, p: Player) -> void:
	var k_turn := 1.0 - exp(-turn_speed * delta)
	var k_focus := 1.0 - exp(-focus_speed * delta)
	var target_angle := _base_angle()
	if p != null:
		var to := p.global_position - (global_position + _eye())
		if to.length_squared() > 0.0001:
			target_angle = to.angle()
	_aim_angle = lerp_angle(_aim_angle, target_angle, k_turn)
	var focus_target := 1.0 if _locked else 0.0
	_focus = lerpf(_focus, focus_target, k_focus)
	if absf(_focus - focus_target) < 0.001:
		_focus = focus_target      # 收尾吸附，锁定后严格收到 0 度
	_update_cone()

## 用一圈射线求出被墙挡住后的可见扇形，仅用于显示。半角 180 时是一整圈
func _update_cone() -> void:
	var half := deg_to_rad(lerpf(_view_half(), focus_half_angle, _focus))
	# 半角小于约 0.1°（屏幕上不足 1px）时当作已经完全收束，不画扇形
	if half < 0.002:
		half = 0.0
	# 长度用几何插值（从视野距离倍增到 lock_range）：跨度极大时，
	# 屏幕上看起来才是持续伸长，而不是一帧就甩出画面
	var base := maxf(view_range * _view_mult(), 1.0)
	var length := base * pow(lock_range / base, _focus)
	var space := get_world_2d().direct_space_state
	var eye := global_position + _eye()
	_cone = PackedVector2Array()
	if half > 0.0:
		_cone.append(_eye())
		var n := maxi(int(ceil(cone_rays * half / deg_to_rad(maxf(_view_half(), 1.0)))), 2)
		for i in n + 1:
			var a := lerpf(-half, half, float(i) / n)
			var to := eye + Vector2.from_angle(_aim_angle + a) * length
			var r := space.intersect_ray(PhysicsRayQueryParameters2D.create(eye, to, Game.LAYER_WORLD))
			_cone.append((r.position if not r.is_empty() else to) - global_position)
	# 中心瞄准线：同样按墙裁切，锁定时画一条淡线提示已经被盯上
	var center_to := eye + Vector2.from_angle(_aim_angle) * length
	var cr := space.intersect_ray(PhysicsRayQueryParameters2D.create(eye, center_to, Game.LAYER_WORLD))
	_aim_end = (cr.position if not cr.is_empty() else center_to) - global_position


## 视野锥、瞄准线由子节点 VisionCone 用加色混合绘制，读这几个值
func cone_points() -> PackedVector2Array:
	return _cone


func cone_full() -> bool:
	return _view_half() >= 179.9 and _focus <= 0.001


func aim_end() -> Vector2:
	return _aim_end


func focus() -> float:
	return _focus


## 0 = 巡逻（暖黄），1 = 搜索（橙），2 = 锁定（红）
func vision_mode() -> int:
	if _locked:
		return 2
	return 1 if state == State.SEARCH else 0

# ======================= 死亡 =======================

## dir：击中方向（碎片、机油往这个方向飞）。回旋镖等不传时按玩家 → 守卫的方向
func kill(dir := Vector2.ZERO) -> void:
	if dead:
		return
	dead = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if dir == Vector2.ZERO and Game.player:
		dir = (global_position - Game.player.global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.UP
	_death_fx(dir)
	killed.emit(self)
	queue_free()


## 被高压电电死（无人机被引进电块）：先叠一层电击特效，再走普通死亡
func electrocute() -> void:
	if dead:
		return
	ElectricFx.zap(global_position, _silhouette())
	kill(Vector2.UP)


func _death_fx(dir: Vector2) -> void:
	var at := global_position
	var sil := _silhouette()
	if not sil.is_empty():
		Juice.ghost(at, sil["tex"], sil["region"], sil["offset"], sil["flip"], Vector2.ONE,
			Color(3.0, 3.0, 3.0), 0.1, 1.0)
	Juice.flash(at, "kill_gold", dir.angle(), Color(1.5, 1.5, 1.5))
	Juice.debris(at, 9, dir, ARMOR, 140.0, ARMOR[3])
	Juice.debris(at, 2, dir, [_burst_color()], 120.0, Color.WHITE)
	Juice.sparks(at, 14, dir, 1.0, 200.0)
	Juice.oil(at, 10, dir, 130.0)
	Juice.smoke(at, 3, Vector2.UP, 14.0, Color(0.25, 0.22, 0.35))
	Game.hitstop(0.07)
	if Game.player:
		var cam := Game.player.get_node_or_null("Camera2D")
		if cam:
			cam.shake(2.5, 0.18)
			cam.kick(dir * 3.0)


## 子类返回当前帧的白色剪影：{tex, region, offset(帧左上角相对 global_position，按未翻转算), flip}
func _silhouette() -> Dictionary:
	return {}


func _burst_color() -> Color:
	return Palette.GUARD

# ======================= 头顶提示 =======================

const QMARK := ["##.", "..#", ".#.", "...", ".#."]

## 头顶警戒条（50% 处有刻度，琥珀 → 红）+ 锁定时「!」/ 搜索时「?」。top：警戒条所在的 y
func _draw_alert(top: float) -> void:
	var icon_y := top - 8.0 - roundf(_pop * 2.0)
	var bright := 1.0 + _pop * 0.8
	if _locked:
		var fast := alert > 0.75
		var blink := 1.0 if (fmod(_t, 0.12 if fast else 0.2) < (0.07 if fast else 0.13)) else 0.45
		var c := Palette.ALERT * Color(blink * bright, blink * bright, blink * bright)
		draw_rect(Rect2(-1, icon_y, 2, 4), c)
		draw_rect(Rect2(-1, icon_y + 5, 2, 1), c)
	elif state == State.SEARCH:
		var c := Palette.SEARCH * Color(bright, bright, bright)
		for y in QMARK.size():
			for x in 3:
				if QMARK[y][x] == "#":
					draw_rect(Rect2(x - 1, icon_y + 1 + y, 1, 1), c)
	if alert <= 0.001:
		return
	var fill := Palette.GUARD.lerp(Palette.ALERT, alert)
	if not _locked:
		fill = fill * Color(0.6, 0.6, 0.6)
	draw_rect(Rect2(-5, top, 10, 1), Color(0.2, 0.05, 0.08))
	draw_rect(Rect2(-5, top, roundf(10.0 * alert), 1), fill)
	draw_rect(Rect2(0, top - 1, 1, 1), Color(Palette.C3, 0.5))   # 50% 刻度
