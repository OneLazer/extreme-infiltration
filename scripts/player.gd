class_name Player
extends CharacterBody2D
## 玩家：移动移植自 Celeste Player.cs 的 NormalUpdate（跑、跳、墙滑、蹬墙跳），
## 武器部分见下半段。原点在碰撞盒中心，碰撞盒 6x10。

signal died
signal weapons_changed

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

# ---------------- 武器参数 ----------------
@export_group("武器")
@export var aim_freeze_frames := 4      ## 按下方向键后的冻结帧数
@export var dart_air_uses := -1         ## 飞镖离地后可用次数，-1 = 无限

var facing := 1
var dead := false

var _move_x := 0
var _jump_grace_timer := 0.0
var _jump_buffer_timer := 0.0
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
## 队列为空时使用初始武器回旋镖（无限）。
var weapon_queue: Array[Dictionary] = []
var active_boomerang: Boomerang = null

var _freeze_left := 0
var _freeze_dir := Vector2.ZERO
var _dart_air_used := 0

@onready var _shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	Game.player = self
	Game.frozen = false


func _physics_process(delta: float) -> void:
	if dead:
		return
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time

	# 瞄准冻结：全场停止，累积方向键，结束时按当时按住的方向发射
	if _freeze_left > 0:
		var held := _read_aim()
		if held != Vector2.ZERO:
			_freeze_dir = held
		_freeze_left -= 1
		if _freeze_left == 0:
			Game.frozen = false
			_fire(_freeze_dir)
		queue_redraw()
		return

	if _aim_just_pressed():
		if is_instance_valid(active_boomerang):
			active_boomerang.recall()
		elif _can_fire():
			_freeze_dir = _read_aim()
			if _freeze_dir == Vector2.ZERO:   # 同一帧内按下又松开的极短点按
				_freeze_dir = _just_pressed_aim()
			if aim_freeze_frames <= 0:
				_fire(_freeze_dir)
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
		# 武器反冲锁定中：忽略重力与输入
		velocity = _dash_velocity
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			velocity *= _dash_end_mult
			if velocity.y < 0.0:
				velocity.y *= 0.75
	else:
		if _move_x != 0:
			facing = _move_x
		_normal_update(delta, on_ground)

	_upward_corner_correction(delta)
	move_and_slide()

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

	# 起跳 / 蹬墙跳
	if _jump_buffer_timer > 0.0:
		if _jump_grace_timer > 0.0:
			_jump()
		elif _wall_check(1, wall_jump_check_dist):
			_wall_jump(-1)
		elif _wall_check(-1, wall_jump_check_dist):
			_wall_jump(1)


func _jump() -> void:
	_jump_buffer_timer = 0.0
	_jump_grace_timer = 0.0
	_var_jump_timer = var_jump_time
	_wall_slide_timer = wall_slide_time
	velocity.x += jump_h_boost * _move_x
	velocity.y = jump_speed
	_var_jump_speed = velocity.y

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


func _wall_check(dir: int, dist: float) -> bool:
	return test_move(global_transform, Vector2(dir * dist, 0.0))


## 向上撞到墙角时，横向挪最多 N 像素让玩家滑过去（Celeste UpwardCornerCorrection）
func _upward_corner_correction(delta: float) -> void:
	if velocity.y >= 0.0:
		return
	var motion := Vector2(0.0, velocity.y * delta)
	if not test_move(global_transform, motion): 		return
	var order: Array[int] = [1, -1] if velocity.x >= 0.0 else [-1, 1]
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

func _read_aim() -> Vector2:
	return Vector2(Input.get_axis("aim_left", "aim_right"), Input.get_axis("aim_up", "aim_down")).sign()


func _aim_just_pressed() -> bool:
	return _just_pressed_aim() != Vector2.ZERO


func _just_pressed_aim() -> Vector2:
	var d := Vector2.ZERO
	var any := false
	for pair in [["aim_left", Vector2.LEFT], ["aim_right", Vector2.RIGHT], ["aim_up", Vector2.UP], ["aim_down", Vector2.DOWN]]:
		if Input.is_action_just_pressed(pair[0]):
			d += pair[1]
			any = true
	if any and d == Vector2.ZERO:
		d.x = facing   # 相反方向同时按下互相抵消时，取朝向
	return d


func current_weapon() -> int:
	return weapon_queue[0]["type"] if not weapon_queue.is_empty() else WeaponDefs.Type.BOOMERANG


func _can_fire() -> bool:
	if current_weapon() == WeaponDefs.Type.DART and dart_air_uses >= 0 and not is_on_floor():
		return _dart_air_used < dart_air_uses
	return true


func add_weapon(type: int, ammo: int) -> void:
	weapon_queue.append({"type": type, "ammo": ammo})
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
	_consume_ammo()

## 瞬时射线：返回 {"end": 终点, "enemy": Guard 或 null, "hit": 是否命中}
func _hitscan(dir: Vector2, max_range: float) -> Dictionary:
	var from := global_position
	var q := PhysicsRayQueryParameters2D.create(from, from + dir * max_range, Game.LAYER_WORLD | Game.LAYER_ENEMY, [get_rid()])
	q.collide_with_areas = true
	var r := get_world_2d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return {"end": from + dir * max_range, "enemy": null, "hit": false}
	var enemy: Guard = r.collider as Guard
	return {"end": r.position, "enemy": enemy, "hit": true}


func _fire_dart(dir: Vector2, def: Dictionary) -> void:
	var res := _hitscan(dir, def["range"])
	Fx.trace(get_parent(), global_position, res["end"], def["color"])
	if not is_on_floor():
		_dart_air_used += 1
	if not res["hit"]:
		return
	# 用碰撞盒沿射线扫掠，得到不嵌墙的落点
	var motion: Vector2 = res["end"] - global_position
	var p := PhysicsShapeQueryParameters2D.new()
	p.shape = _shape.shape
	p.transform = _shape.global_transform
	p.motion = motion
	p.collision_mask = Game.LAYER_WORLD
	p.exclude = [get_rid()]
	var frac := get_world_2d().direct_space_state.cast_motion(p)
	var enemy: Guard = res["enemy"]
	if enemy:
		enemy.kill()
	Fx.burst(get_parent(), global_position, Palette.PLAYER, 4)
	global_position += motion * frac[0]
	if not def["keep_velocity"]:
		velocity = Vector2.ZERO
	_dash_timer = 0.0
	_var_jump_timer = 0.0


func _fire_air_gun(dir: Vector2, def: Dictionary) -> void:
	var res := _hitscan(dir, def["range"])
	Fx.trace(get_parent(), global_position, res["end"], def["color"])
	var enemy: Guard = res["enemy"]
	if enemy:
		enemy.kill()
	apply_dash(-dir * def["recoil_dash"], def["dash_time"], def["end_mult"])

func _throw_boomerang(type: int, dir: Vector2, def: Dictionary) -> void:
	var b := Boomerang.new()
	b.setup(self, type, dir, def)
	get_parent().add_child(b)
	b.global_position = global_position
	active_boomerang = b
	if def.has("recoil_add"):
		velocity += -dir * def["recoil_add"]
	if def.has("recoil_dash"):
		apply_dash(-dir * def["recoil_dash"], def["dash_time"], def["end_mult"])


## 回旋镖归位时由 Boomerang 调用。move_dir：回旋镖归位瞬间的移动方向
func on_boomerang_caught(b: Boomerang, move_dir: Vector2) -> void:
	if b == active_boomerang:
		active_boomerang = null
	var def := WeaponDefs.get_def(b.type)
	if def["catch_speed"] > 0.0 and move_dir != Vector2.ZERO:
		apply_dash(move_dir * def["catch_speed"], def["catch_dash_time"], 1.0)


# ======================= 死亡与绘制 =======================

func die() -> void:
	if dead:
		return
	dead = true
	Game.frozen = false
	velocity = Vector2.ZERO
	Fx.burst(get_parent(), global_position, Palette.PLAYER, 14)
	hide()
	died.emit()


func _draw() -> void:
	draw_rect(Rect2(-3, -5, 6, 10), Palette.PLAYER)
	draw_rect(Rect2(-1 + facing * 1.5, -3, 2, 2), Color(0.05, 0.02, 0.1))
	# 头顶小方块：当前武器颜色
	var wdef := WeaponDefs.get_def(current_weapon())
	draw_rect(Rect2(-1.5, -9, 3, 2), wdef["color"])
	if _freeze_left > 0:
		var d := _freeze_dir.normalized() if _freeze_dir != Vector2.ZERO else Vector2(facing, 0)
		draw_line(d * 6.0, d * 18.0, wdef["color"], 1.0)
