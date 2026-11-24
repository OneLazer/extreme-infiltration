class_name Player
extends CharacterBody2D
## 玩家：移动移植自 Celeste Player.cs 的 NormalUpdate（跑、跳、墙滑、蹬墙跳、二段跳），
## 武器反冲的冲刺可被跳跃打断：super / hyper / 蹭墙跳。
## 瞄准用鼠标：玩家中心 → 光标的方向就是弹道方向，命中判定另带宽容带（见 WeaponDefs.assist_tiles）。
## 武器部分见下半段。原点在碰撞盒中心，碰撞盒 6x10。

signal died
signal weapons_changed
## 以下信号只给表现层（PlayerVisual / 特效）用，不影响玩法
enum JumpKind { GROUND, AIR, WALL, SUPER, HYPER, BOUNCE }
signal jumped(kind: int, dir: int)
signal landed(fall_speed: float)
signal shot(type: int, from: Vector2, dir: Vector2, res: Dictionary)
signal thrown(type: int, dir: Vector2)
signal teleported(from: Vector2, to: Vector2)
signal thrust(dir: Vector2)                       ## 刺剑出刺
signal thrust_hit(at: Vector2, dir: Vector2)      ## 刺剑刺中守卫
signal thrust_ended(from: Vector2, to: Vector2)   ## 刺剑冲刺结束（含被跳跃打断）

## 相机震屏组件（用 preload 显式引用，避免依赖 class_name 的全局类缓存）
const ScreenShakeScript := preload("res://scripts/screen_shake.gd")

# ---------------- 移动参数（数值取自 Celeste Player.cs） ----------------
@export_group("移动")
@export var max_run := 90.0
@export var run_accel := 1000.0
@export var run_reduce := 400.0
@export var air_mult := 0.65
@export var gravity := 900.0
@export var max_fall := 160.0
@export var half_grav_threshold := 40.0
@export var jump_speed := -105.0
@export var jump_h_boost := 40.0
@export var var_jump_time := 0.2
@export var jump_grace_time := 0.1      ## 土狼时间
@export var jump_buffer_time := 0.08    ## 跳跃缓冲
@export var wall_jump_check_dist := 3.0
@export var wall_jump_force_time := 0.16
@export var wall_slide_start_max := 20.0
@export var wall_slide_time := 1.2
@export var upward_corner_correction := 4

# ---------------- 二段跳 ----------------
@export_group("二段跳")
@export var air_jump_count := 1          ## 离地后可跳次数（1 = 二段跳，0 = 关闭）
@export var air_jump_speed := -100.0     ## 二段跳初速（比地面跳略弱）

# ---------------- 冲刺跳（武器反冲期间按跳打断） ----------------
@export_group("冲刺跳")
@export var super_speed := 260.0         ## super：水平冲刺接跳的固定水平速度
@export var hyper_speed := 260.0         ## hyper：下斜冲刺接跳的固定水平速度
@export var wall_bounce_v := -200.0      ## 蹭墙跳垂直初速
@export var wall_bounce_h := 120.0       ## 蹭墙跳离开墙面的水平速度

# ---------------- 武器参数 ----------------
@export_group("武器")
@export var aim_freeze_frames := 0      ## 开火前的全场冻结帧数。鼠标瞄准下默认 0（点下即发射）
@export var recoil_snap_deg := 12.0     ## 反冲方向吸附到 8 方向的容差（度）；0 = 完全跟随鼠标
@export var dart_air_uses := -1         ## 飞镖离地后可用次数，-1 = 无限
@export var hide_os_cursor := true      ## 隐藏系统鼠标指针，改用武器色准星

var facing := 1
var dead := false
var death_cause := ""           ## "" = 守卫，"electric" = 高压电（表现层用）

var _aim_dir := Vector2.RIGHT   # 当前瞄准方向（玩家中心 → 光标）。光标压在角色身上时保留上一帧
var _aim_len := 0.0             # 瞄准线显示长度：撞墙或到光标处截断

var _move_x := 0
var _jump_grace_timer := 0.0
var _jump_buffer_timer := 0.0
var _air_jumps_used := 0        # 本段滞空已用的二段跳次数，落地清零
var _var_jump_timer := 0.0
var _var_jump_speed := 0.0
var _force_move_x := 0
var _force_move_x_timer := 0.0
var _wall_slide_timer := 0.0
var _wall_slide_dir := 0
var _dash_timer := 0.0          # >0 时速度锁定（武器反冲）
var _dash_velocity := Vector2.ZERO
var _dash_end_mult := 1.0

## 已拾取武器队列（先进先出）。元素：{"type": WeaponDefs.Type, "ammo": int}
## 队列为空时使用初始主武器（默认飞镖，无限弹药）。
var weapon_queue: Array[Dictionary] = []
## 初始主武器：武器队列清空后回到该武器，不消耗弹药。
## 调试时可由 DebugOverlay 在检查器里覆盖。
var initial_weapon := WeaponDefs.Type.DART
var active_boomerang: Boomerang = null

var _freeze_left := 0
var _freeze_dir := Vector2.ZERO
var _dart_air_used := 0
var _rapier_active := false     # 刺剑冲刺中（攻击判定 + 无敌），冲刺结束或被跳跃打断时关闭
var _rapier_dir := Vector2.RIGHT
var _rapier_from := Vector2.ZERO
var _rapier_air_used := 0       # 本段滞空已用的刺剑次数：落地或刺杀敌人刷新
var _invincible_t := 0.0        # >0：额外的无敌宽限（刺剑冲刺结束后）

@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _camera: ScreenShakeScript = $Camera2D


func _ready() -> void:
	Game.player = self
	Game.frozen = false
	if hide_os_cursor:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


func _physics_process(delta: float) -> void:
	if dead:
		return
	# 回旋镖收回期间冻结玩家（瞄准冻结由下面的 _freeze_left 分支处理）
	if Game.frozen and _freeze_left <= 0:
		return
	_invincible_t = maxf(_invincible_t - delta, 0.0)
	_update_aim()
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time

	# 瞄准冻结（可选，默认关闭）：全场停止，冻结期间瞄准仍跟随鼠标，结束时按当前方向发射
	if _freeze_left > 0:
		_freeze_dir = _aim_dir
		_freeze_left -= 1
		if _freeze_left == 0:
			Game.frozen = false
			_fire(_freeze_dir)
		queue_redraw()
		return

	if Input.is_action_just_pressed("fire"):
		if is_instance_valid(active_boomerang):
			active_boomerang.recall()
		elif _can_fire():
			_freeze_dir = _aim_dir
			if aim_freeze_frames <= 0:
				_fire(_aim_dir)
			else:
				_freeze_left = aim_freeze_frames
				Game.frozen = true
				queue_redraw()
				return

	_update_movement(delta)
	queue_redraw()

# ======================= 移动 =======================

func _update_movement(delta: float) -> void:
	var on_ground := is_on_floor()

	# 计时器（对应 Player.Update 开头）
	if _wall_slide_dir != 0:
		_wall_slide_timer = maxf(_wall_slide_timer - delta, 0.0)
		_wall_slide_dir = 0
	if on_ground:
		_wall_slide_timer = wall_slide_time
		_jump_grace_timer = jump_grace_time
		_dart_air_used = 0
		_air_jumps_used = 0
		_rapier_air_used = 0
	elif _jump_grace_timer > 0.0:
		_jump_grace_timer -= delta
	if _jump_buffer_timer > 0.0:
		_jump_buffer_timer -= delta
	if _var_jump_timer > 0.0:
		_var_jump_timer -= delta

	_move_x = int(Input.get_axis("move_left", "move_right"))
	if _force_move_x_timer > 0.0:
		_force_move_x_timer -= delta
		_move_x = _force_move_x

	if _dash_timer > 0.0:
		if not _try_dash_jump(on_ground):
			# 武器反冲锁定中：忽略重力与输入
			velocity = _dash_velocity
			_dash_timer -= delta
			if _dash_timer <= 0.0:
				velocity *= _dash_end_mult
				if velocity.y < 0.0:
					velocity.y *= 0.75
				_end_rapier()
	else:
		if _move_x != 0:
			facing = _move_x
		_normal_update(delta, on_ground)

	_upward_corner_correction(delta)
	var fall_speed := velocity.y
	var prev_pos := global_position
	move_and_slide()
	if _rapier_active:
		_rapier_sweep(prev_pos)
	if not on_ground and is_on_floor():
		landed.emit(fall_speed)
	if Game.electric_overlaps(_hurt_rect()):
		die_electric()

func _normal_update(delta: float, on_ground: bool) -> void:
	# 跑动与摩擦
	var mult := 1.0 if on_ground else air_mult
	if absf(velocity.x) > max_run and signf(velocity.x) == _move_x:
		velocity.x = move_toward(velocity.x, max_run * _move_x, run_reduce * mult * delta)
	else:
		velocity.x = move_toward(velocity.x, max_run * _move_x, run_accel * mult * delta)

	# 重力（含墙滑、跳跃顶点半重力）
	if not on_ground:
		var mf := max_fall
		if _move_x != 0 and _move_x == facing:
			if velocity.y >= 0.0 and _wall_slide_timer > 0.0 and _wall_check(facing, 1.0):
				_wall_slide_dir = facing
			if _wall_slide_dir != 0:
				mf = lerpf(max_fall, wall_slide_start_max, _wall_slide_timer / wall_slide_time)
		var g_mult := 0.5 if (absf(velocity.y) < half_grav_threshold and Input.is_action_pressed("jump")) else 1.0
		velocity.y = move_toward(velocity.y, mf, gravity * g_mult * delta)

	# 可变跳高：按住跳键期间保持起跳速度
	if _var_jump_timer > 0.0:
		if Input.is_action_pressed("jump"):
			velocity.y = minf(velocity.y, _var_jump_speed)
		else:
			_var_jump_timer = 0.0

	# 起跳 / 蹬墙跳 / 二段跳
	# 土狼时间内的跳走 _jump()，和落地跳是同一条分支，所以不消耗二段跳
	if _jump_buffer_timer > 0.0:
		if _jump_grace_timer > 0.0:
			_jump()
		elif _wall_check(1, wall_jump_check_dist):
			_wall_jump(-1)
		elif _wall_check(-1, wall_jump_check_dist):
			_wall_jump(1)
		elif _can_air_jump():
			_air_jump()


func _jump() -> void:
	_jump_buffer_timer = 0.0
	_jump_grace_timer = 0.0
	_var_jump_timer = var_jump_time
	_wall_slide_timer = wall_slide_time
	velocity.x += jump_h_boost * _move_x
	velocity.y = jump_speed
	_var_jump_speed = velocity.y
	jumped.emit(JumpKind.GROUND, _move_x)


## 二段跳。土狼时间内的跳会走 _jump()，不会到这条分支，所以不消耗次数。
func _air_jump() -> void:
	_jump_buffer_timer = 0.0
	_air_jumps_used += 1
	_var_jump_timer = var_jump_time
	_var_jump_speed = air_jump_speed
	_wall_slide_timer = wall_slide_time
	# 不覆盖更快的上升速度：蹬墙跳 / 反冲后立刻接跳时不会被拽慢
	velocity.y = minf(velocity.y, air_jump_speed)
	jumped.emit(JumpKind.AIR, _move_x)


func _can_air_jump() -> bool:
	return _air_jumps_used < air_jump_count


## 剩余二段跳次数（调试面板 / HUD 用）
func air_jumps_left() -> int:
	return maxi(air_jump_count - _air_jumps_used, 0)


## dir：跳离方向（墙在 -dir 一侧）
func _wall_jump(dir: int) -> void:
	_jump_buffer_timer = 0.0
	_jump_grace_timer = 0.0
	_var_jump_timer = var_jump_time
	_wall_slide_timer = wall_slide_time
	if _move_x != 0:
		_force_move_x = dir
		_force_move_x_timer = wall_jump_force_time
	velocity.x = (max_run + jump_h_boost) * dir
	velocity.y = jump_speed
	_var_jump_speed = velocity.y
	facing = dir
	jumped.emit(JumpKind.WALL, dir)


## 冲刺中按跳：贴墙 → 蹭墙跳，否则按冲刺方向区分 super / hyper；
## 空中且还有二段跳 → 用二段跳打断锁速。
## 蹭墙跳只看「离地 + 贴着墙」，不要求冲刺朝着墙，所以垂直上冲沿墙也能弹；
## 地面上的撞墙冲刺不抢跳，交给 super。
## 返回 true 表示冲刺已被跳跃打断。
func _try_dash_jump(on_ground: bool) -> bool:
	if _jump_buffer_timer <= 0.0:
		return false
	if not on_ground:
		var face := _move_x if _move_x != 0 else facing
		for d in [face, -face]:
			if not _wall_check(d, wall_jump_check_dist):
				continue
			if _dash_velocity.x * d < -0.1:   # 正在朝远离这面墙的方向冲
				continue
			_dash_wall_bounce(d)
			return true
	# super / hyper 需要地面或土狼时间；土狼时间内的跳不消耗二段跳
	if _jump_grace_timer > 0.0:
		if absf(_dash_velocity.y) < 1.0:
			_dash_super_jump()
			return true
		# 鼠标瞄准下冲刺角度是连续的：只有「不低于 45° 斜下」才算 hyper，
		# 更陡的下斜当普通跳，否则对着脚下开一枪也能白嫖一个 hyper。
		if _dash_velocity.y > 1.0 and absf(_dash_velocity.x) >= _dash_velocity.y:
			_dash_hyper_jump()
			return true
		# 陡峭下冲 / 竖直冲刺（如向上打气枪）落地前按跳：按普通跳处理，别把跳跃吞掉
		_break_dash()
		_jump()
		return true
	# 空中冲刺中按跳：用二段跳打断锁速
	if _can_air_jump():
		_break_dash()
		_air_jump()
		return true
	return false


## super：水平冲刺接跳，水平速度固定为 super_speed（方向取冲刺方向）
func _dash_super_jump() -> void:
	_break_dash()
	velocity.x = signf(_dash_velocity.x) * super_speed
	velocity.y = jump_speed
	_var_jump_timer = var_jump_time
	_var_jump_speed = velocity.y
	jumped.emit(JumpKind.SUPER, int(signf(velocity.x)))


## hyper：下斜冲刺接跳，水平速度固定为 hyper_speed
func _dash_hyper_jump() -> void:
	_break_dash()
	velocity.x = signf(_dash_velocity.x) * hyper_speed
	velocity.y = jump_speed
	_var_jump_timer = var_jump_time
	_var_jump_speed = velocity.y
	jumped.emit(JumpKind.HYPER, int(signf(velocity.x)))


## 蹭墙跳：向上弹起并向墙的反方向弹开（wall_dir = 墙所在的一侧）
func _dash_wall_bounce(wall_dir: int) -> void:
	_break_dash()
	if _move_x != 0:
		_force_move_x = -wall_dir
		_force_move_x_timer = wall_jump_force_time
	velocity.x = -wall_dir * wall_bounce_h
	velocity.y = wall_bounce_v        # 垂直速度完全由参数决定，不继承冲刺速度
	_var_jump_timer = var_jump_time
	_var_jump_speed = velocity.y
	facing = -wall_dir
	jumped.emit(JumpKind.BOUNCE, -wall_dir)


## 打断冲刺锁速，把控制权交还给普通移动
func _break_dash() -> void:
	_dash_timer = 0.0
	_jump_buffer_timer = 0.0
	_jump_grace_timer = 0.0
	_wall_slide_timer = wall_slide_time
	_end_rapier()


func _wall_check(dir: int, dist: float) -> bool:
	return test_move(global_transform, Vector2(dir * dist, 0.0))


## 向上撞到墙角时，横向挪最多 N 像素让玩家滑过去（Celeste UpwardCornerCorrection）
func _upward_corner_correction(delta: float) -> void:
	if velocity.y >= 0.0:
		return
	var motion := Vector2(0.0, velocity.y * delta)
	if not test_move(global_transform, motion):
		return
	# 注意：不要写成 `[1, -1] if ... else [-1, 1]`——三元结果是无类型 Array，
	# 赋给 Array[int] 会在运行时抛类型转换错误。
	var order: Array[int] = [1, -1]
	if velocity.x < 0.0:
		order.reverse()
	for i in range(1, upward_corner_correction + 1):
		for s in order:
			var off := Vector2(i * s, 0.0)
			var t := global_transform.translated(off)
			if not test_move(t, Vector2.ZERO) and not test_move(t, motion):
				global_position += off
				return


## 武器反冲：锁定速度一段时间（类似蔚蓝冲刺）
func apply_dash(vel: Vector2, time: float, end_mult: float) -> void:
	_dash_velocity = vel
	_dash_timer = time
	_dash_end_mult = end_mult
	_var_jump_timer = 0.0
	_force_move_x_timer = 0.0
	velocity = vel

# ======================= 武器 =======================

## 鼠标瞄准：玩家中心 → 光标。
## 光标几乎压在角色身上（< 0.5px）时保留上一帧方向，避免归一化出零向量。
## 顺带算一次瞄准线长度：到光标或撞墙处截断，给 _draw 画瞄准线用。
func _update_aim() -> void:
	var to := get_global_mouse_position() - global_position
	if to.length() > 0.5:
		_aim_dir = to.normalized()
	var reach := minf(to.length(), _aim_reach())
	_aim_len = 0.0
	if reach <= 0.0:
		return
	var r := _ray(global_position, global_position + _aim_dir * reach, Game.LAYER_WORLD)
	_aim_len = (r.position - global_position).length() if not r.is_empty() else reach


## 当前武器的最大瞄距（截断瞄准线显示用）
func _aim_reach() -> float:
	var def := WeaponDefs.get_def(current_weapon())
	if def.has("range"):
		return float(def["range"])
	if def.has("out_tiles"):
		return float(def["out_tiles"]) * Game.TILE
	if def.has("thrust_speed"):
		return float(def["thrust_speed"]) * float(def["dash_time"])
	return 320.0


## 反冲方向：鼠标瞄准是连续的，但 super / hyper / 蹭墙跳这些位移技巧依赖 8 方向冲刺。
## 瞄准方向离最近的 8 方向不超过 recoil_snap_deg 时，反冲吸附到那个方向，其余角度完全跟随鼠标。
## recoil_snap_deg = 0 表示关闭吸附。
func _recoil_dir(dir: Vector2) -> Vector2:
	if recoil_snap_deg <= 0.0:
		return dir
	var step := PI * 0.25
	var snapped := Vector2.from_angle(roundf(dir.angle() / step) * step)
	if rad_to_deg(absf(dir.angle_to(snapped))) <= recoil_snap_deg:
		return snapped
	return dir


func current_weapon() -> int:
	return weapon_queue[0]["type"] if not weapon_queue.is_empty() else initial_weapon


func _can_fire() -> bool:
	if current_weapon() == WeaponDefs.Type.RAPIER:
		return not _rapier_active and rapier_ready()
	if current_weapon() == WeaponDefs.Type.DART and dart_air_uses >= 0 and not is_on_floor():
		return _dart_air_used < dart_air_uses
	return true


func add_weapon(type: int, ammo: int) -> void:
	weapon_queue.append({"type": type, "ammo": ammo})
	weapons_changed.emit()


## 武器替换区域调用：换掉无限弹药的主武器（队列不动）
func set_main_weapon(type: int) -> void:
	initial_weapon = type
	weapons_changed.emit()


func _consume_ammo() -> void:
	if weapon_queue.is_empty():
		return
	weapon_queue[0]["ammo"] -= 1
	if weapon_queue[0]["ammo"] <= 0:
		weapon_queue.pop_front()
	weapons_changed.emit()


func _fire(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		dir = Vector2(facing, 0)
	dir = dir.normalized()
	var type := current_weapon()
	var def := WeaponDefs.get_def(type)
	match type:
		WeaponDefs.Type.DART:
			_fire_dart(dir, def)
		WeaponDefs.Type.AIR_GUN:
			_fire_air_gun(dir, def)
		WeaponDefs.Type.BOOMERANG, WeaponDefs.Type.HEAVY_BOOMERANG:
			_throw_boomerang(type, dir, def)
		WeaponDefs.Type.RAPIER:
			_fire_rapier(dir, def)
	_consume_ammo()
	_camera.shake(def.get("shake", 0.0), def.get("shake_time", 0.1))

## 瞬时射线（带宽容判定）。
## 命中判定不是一条线，而是一个矩形：沿瞄准方向长 max_range、垂直方向宽 band_tiles 图格。
## 中心线先按原逻辑判定；只有中心线真的打中敌人
## 才直接返回 —— 撞墙不算，否则关卡里几乎每枪尽头都是墙，宽容判定永远轮不到。
## 中心线没碰到敌人时，在矩形里挑最贴近瞄准线、且和玩家之间没有墙的敌人，
## 把弹道以玩家为轴心偏折过去 —— 偏折后再射一次，保证另一端真的落在敌人身上。
## 返回 {"dir": 实际弹道方向, "end": 终点, "enemy": Guard 或 null,
##       "hit": 是否命中, "normal": 命中面的法线（敌人 / 墙），没碰到则 ZERO}
func _hitscan(dir: Vector2, max_range: float, band_tiles: float) -> Dictionary:
	var from := global_position
	var r := _ray(from, from + dir * max_range, Game.LAYER_WORLD | Game.LAYER_ENEMY)
	var direct: Guard = null
	if not r.is_empty():
		direct = r.collider as Guard
	if direct != null:
		return {"dir": dir, "end": r.position, "enemy": direct, "hit": true, "normal": r.normal}
	# 中心线没打中敌人（可能先撞到墙）：墙不参与宽容判定，只用来兜底落点
	var target := _assist_target(dir, max_range, band_tiles)
	if target != null:
		# 偏折方向 = 玩家 → 敌人中心；起点仍是玩家中心，所以只是绕玩家转了一个小角度
		var shot := (target.global_position - from).normalized()
		var reach := _ray(from, from + shot * max_range, Game.LAYER_ENEMY)
		if not reach.is_empty():
			return {"dir": shot, "end": reach.position, "enemy": reach.collider as Guard, "hit": true, "normal": reach.normal}
	# 没目标（或目标在查询后消失）：退回中心线结果（墙 / 射程尽头）
	var end := from + dir * max_range
	var normal := Vector2.ZERO
	if not r.is_empty():
		end = r.position
		normal = r.normal
	return {"dir": dir, "end": end, "enemy": null, "hit": not r.is_empty(), "normal": normal}


## 宽容判定带宽（图格）。鼠标瞄准角度是连续的，所有方向统一一档，
## 不再像 8 向瞄准那样给斜向单独放宽。
func _assist_tiles(def: Dictionary) -> float:
	return float(def.get("assist_tiles", 3.0))


## 在宽容矩形里挑目标：横向偏移最小的敌人优先（更贴近玩家瞄的方向），
## 偏移相同则取更近的。和玩家之间隔着墙的敌人不算 —— 不能隔墙打。
func _assist_target(dir: Vector2, max_range: float, band_tiles: float) -> Guard:
	var half := band_tiles * Game.TILE * 0.5
	if half <= 0.0:
		return null
	var band := RectangleShape2D.new()
	band.size = Vector2(max_range, half * 2.0)
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = band
	q.transform = Transform2D(dir.angle(), global_position + dir * (max_range * 0.5))
	q.collision_mask = Game.LAYER_ENEMY
	q.collide_with_areas = true
	q.collide_with_bodies = false
	var best: Guard = null
	var best_lateral := 0.0
	var best_along := 0.0
	for hit in get_world_2d().direct_space_state.intersect_shape(q, 32):
		var g := hit["collider"] as Guard
		if g == null or g.dead:
			continue
		var to := g.global_position - global_position
		var along := to.dot(dir)                # 沿瞄准线的前后距离
		if along <= 0.0 or along > max_range:
			continue
		var lateral := absf(to.cross(dir))      # 离瞄准线的横向偏移（dir 已归一化）
		var better := best == null or lateral < best_lateral - 0.01
		if not better and absf(lateral - best_lateral) <= 0.01:
			better = along < best_along
		if not better:
			continue
		if not _ray(global_position, g.global_position, Game.LAYER_WORLD).is_empty():
			continue
		best = g
		best_lateral = lateral
		best_along = along
	return best


## 一次射线查询。碰撞区域（Area2D，敌人）也要算命中
func _ray(a: Vector2, b: Vector2, mask: int) -> Dictionary:
	var q := PhysicsRayQueryParameters2D.create(a, b, mask, [get_rid()])
	q.collide_with_areas = true
	return get_world_2d().direct_space_state.intersect_ray(q)


func _fire_dart(dir: Vector2, def: Dictionary) -> void:
	var res := _hitscan(dir, def["range"], _assist_tiles(def))
	shot.emit(WeaponDefs.Type.DART, global_position, dir, res)
	var from := global_position
	if not is_on_floor():
		_dart_air_used += 1
	if not res["hit"]:
		return
	# 命中敌人：直接落到命中点。用碰撞盒扫掠时，斜线 / 贴墙的情况会先被墙截断，
	# 玩家只走一半就停在墙面上，看起来像「打中了人却撞墙」。
	# 撞墙：仍用碰撞盒扫掠，落点贴着墙面，不会嵌进墙里。
	var enemy: Guard = res["enemy"]
	if enemy:
		enemy.kill(res["dir"])
	if enemy != null:
		global_position = res["end"]
	else:
		var motion: Vector2 = res["end"] - global_position
		var p := PhysicsShapeQueryParameters2D.new()
		p.shape = _shape.shape
		p.transform = _shape.global_transform
		p.motion = motion
		p.collision_mask = Game.LAYER_WORLD
		p.exclude = [get_rid()]
		var frac := get_world_2d().direct_space_state.cast_motion(p)
		global_position += motion * frac[0]
	if not def["keep_velocity"]:
		velocity = Vector2.ZERO
	if enemy == null:
		_apply_dart_impact(res["normal"], def)
	else:
		# 打中敌人时按「瞄准方向」套用同一套收尾手感：
		# 偏竖直 → 当成撞地板；否则 → 当成撞竖墙（反向 X 取弹道 X 的反方向）
		var fake_normal := Vector2(-signf(dir.x), 0.0)
		if absf(dir.y) > absf(dir.x):
			fake_normal = Vector2(0.0, -1.0)
		_apply_dart_impact(fake_normal, def)
	_dash_timer = 0.0
	_var_jump_timer = 0.0
	teleported.emit(from, global_position)


## 飞镖收尾速度（撞墙与命中敌人共用，敌人用一个等价法线喂进来）：
##   竖直墙 → 沿墙面法线反推一个很小的 X 速度，并给一点向上的 Y
##   地板   → 只给一点向上的 Y
##   天花板 → 不变
## 数值见 WeaponDefs.Type.DART 的 bounce_* 参数
func _apply_dart_impact(normal: Vector2, def: Dictionary) -> void:
	if absf(normal.x) > absf(normal.y):
		velocity = Vector2(normal.x * def["bounce_wall_x"], -def["bounce_wall_up"])
	elif normal.y < 0.0:
		velocity.y = -def["bounce_floor_up"]


func _fire_air_gun(dir: Vector2, def: Dictionary) -> void:
	var res := _hitscan(dir, def["range"], _assist_tiles(def))
	shot.emit(WeaponDefs.Type.AIR_GUN, global_position, dir, res)
	var enemy: Guard = res["enemy"]
	if enemy:
		enemy.kill(res["dir"])
	# 反冲方向单独做 8 方向吸附（见 _recoil_dir），不跟偏折后的弹道：
	# 宽容判定只放宽命中，不能带偏 super / hyper / 蹭墙跳这些依赖冲刺方向的位移手感。
	apply_dash(-_recoil_dir(dir) * def["recoil_dash"], def["dash_time"], def["end_mult"])

func _throw_boomerang(type: int, dir: Vector2, def: Dictionary) -> void:
	# 宽容判定：在投掷距离内、宽容带宽里挑最贴近瞄准线的敌人，把投掷方向偏折过去
	var out_range: float = def["out_tiles"] * Game.TILE
	var target := _assist_target(dir, out_range, _assist_tiles(def))
	var throw_dir := dir
	if target != null:
		throw_dir = (target.global_position - global_position).normalized()
	var b := Boomerang.new()
	b.setup(self, type, throw_dir, def)
	get_parent().add_child(b)
	b.global_position = global_position
	b.begin()
	active_boomerang = b
	thrown.emit(type, throw_dir)
	# 反冲仍按 8 方向吸附后的方向，不跟偏折后的投掷方向
	var rd := _recoil_dir(dir)
	if def.has("recoil_add"):
		velocity += -rd * def["recoil_add"]
	if def.has("recoil_dash"):
		apply_dash(-rd * def["recoil_dash"], def["dash_time"], def["end_mult"])


## 刺剑：复用反冲冲刺（apply_dash），方向朝准心（同样做 8 方向吸附，super / hyper / 蹭墙跳照常能接）。
## 冲刺期间身体 + 刀身都是攻击判定（_rapier_sweep），并且对守卫无敌。不做宽容偏折：
## 位移方向严格按输入，宽容只体现在刀身判定比身体宽。
func _fire_rapier(dir: Vector2, def: Dictionary) -> void:
	var d := _recoil_dir(dir)
	if not is_on_floor():
		_rapier_air_used += 1
	apply_dash(d * def["thrust_speed"], def["dash_time"], def["end_mult"])
	_rapier_active = true
	_rapier_dir = d
	_rapier_from = global_position
	if absf(d.x) > 0.1:
		facing = int(signf(d.x))
	thrust.emit(d)
	_rapier_sweep(global_position)     # 贴脸出刺：第一帧就判定


## 扫掠判定：从上一帧位置到当前位置，加上前方刀身，组成一个沿冲刺方向的矩形。
## 逐帧扫掠而不是只看当前位置，高速冲刺也不会穿过敌人。
func _rapier_sweep(prev: Vector2) -> void:
	var def := WeaponDefs.get_def(WeaponDefs.Type.RAPIER)
	var d := _rapier_dir
	var a := prev - d * 3.0
	var b := global_position + d * (3.0 + float(def["blade_len"]))
	var box := RectangleShape2D.new()
	box.size = Vector2(maxf((b - a).length(), 1.0), float(def["blade_width"]))
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = box
	q.transform = Transform2D(d.angle(), (a + b) * 0.5)
	q.collision_mask = Game.LAYER_ENEMY
	q.collide_with_areas = true
	q.collide_with_bodies = false
	for hit in get_world_2d().direct_space_state.intersect_shape(q, 16):
		var g := hit["collider"] as Guard
		if g != null and not g.dead:
			rapier_kill(g)


## 刺剑击杀（扫掠判定和守卫身体接触都走这里）：刺杀刷新空中次数，可以在空中连刺
func rapier_kill(g: Guard) -> void:
	if g.dead:
		return
	var at := g.global_position
	g.kill(_rapier_dir)
	_rapier_air_used = 0
	thrust_hit.emit(at, _rapier_dir)


func _end_rapier() -> void:
	if not _rapier_active:
		return
	_rapier_active = false
	_invincible_t = float(WeaponDefs.get_def(WeaponDefs.Type.RAPIER)["invincible_grace"])
	thrust_ended.emit(_rapier_from, global_position)


## 回旋镖归位时由 Boomerang 调用。move_dir：回旋镖归位瞬间的移动方向
func on_boomerang_caught(b: Boomerang, move_dir: Vector2) -> void:
	if b == active_boomerang:
		active_boomerang = null
	Game.frozen = false         # 解除收回冻结
	var def := WeaponDefs.get_def(b.type)
	if def["catch_speed"] > 0.0 and move_dir != Vector2.ZERO:
		apply_dash(move_dir * def["catch_speed"], def["catch_dash_time"], 1.0)


# ======================= 死亡与绘制 =======================

## 无敌：只防守卫（接触、开枪），不防高压电
func is_invincible() -> bool:
	return _rapier_active or _invincible_t > 0.0


## 刺剑冲刺中：身体本身也是攻击判定
func is_rapier_attacking() -> bool:
	return _rapier_active


## 刺剑冲刺方向（表现层画刀身用）
func rapier_dir() -> Vector2:
	return _rapier_dir


## 刺剑在空中还能不能用（表现层把刀调暗提示）
func rapier_ready() -> bool:
	return is_on_floor() or _rapier_air_used < int(WeaponDefs.get_def(WeaponDefs.Type.RAPIER)["air_uses"])


## 碰撞盒内缩 1px 的受击框：高压电擦边不算
func _hurt_rect() -> Rect2:
	var half := (_shape.shape as RectangleShape2D).size * 0.5 - Vector2.ONE
	return Rect2(global_position - half, half * 2.0)


## 被高压电电死（无敌也挡不住）。表现层按 death_cause 换成电击死亡特效
func die_electric() -> void:
	if dead:
		return
	death_cause = "electric"
	die()


func die() -> void:
	if dead:
		return
	dead = true
	Game.frozen = false
	velocity = Vector2.ZERO
	hide()
	died.emit()


func _draw() -> void:
	# 身体、围巾、武器由子节点 PlayerVisual 绘制；这里只画瞄准反馈
	_draw_aim_guide(WeaponDefs.get_def(current_weapon()))


## 鼠标瞄准的视觉反馈：玩家 → 光标的虚线（撞墙处截断，冻结时加亮）+ 光标处准星。
## 准星画在玩家节点里，所以和其他实体同一层，但玩家节点在关卡里排在实体之后，正常盖在上面。
func _draw_aim_guide(wdef: Dictionary) -> void:
	if dead:
		return
	var col: Color = wdef["color"]
	var dim := Color(col.r * 0.45, col.g * 0.45, col.b * 0.45, 0.55 if _freeze_left > 0 else 0.35)
	var d := 8.0
	while d < _aim_len:
		draw_rect(Rect2((_aim_dir * d).round(), Vector2.ONE), dim)
		d += 3.0
	var m := to_local(get_global_mouse_position()).round()
	for v in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_rect(Rect2(m + v * 2.0, Vector2.ONE), col)
		draw_rect(Rect2(m + v * 3.0, Vector2.ONE), col)
	draw_rect(Rect2(m, Vector2.ONE), Color(col, 0.6))
