class_name Boomerang
extends Node2D
## 回旋镖弹体（轻型 / 重型共用）。
## OUT：用 lerp 缓动快速飞到目标点（撞墙则停在墙面）→ IDLE：静止悬停
## RETURN：冻结全场 → 短暂停顿 → 逐渐加速飞回玩家（穿墙），归位时解冻并通知玩家。
## 全程有攻击判定（含扫掠检测，防止高速穿过敌人）。

enum State { OUT, IDLE, RETURN }

const RADIUS := 3.0

# ============ 动画手感（不导出，想调就改这里） ============
## 飞出耗时（秒）。飞行距离由 WeaponDefs 的 out_tiles 决定
const OUT_TIME_NORMAL := 0.7
const OUT_TIME_HEAVY := 1
## 飞出缓动指数：1 = 匀速；越大越「起步冲、末段缓」
const OUT_EASE_POWER := 7
## 收回：冻结后停顿（秒）→ 逐渐加速。数值越大收回越快
const RETURN_DELAY := 0.05
const RETURN_ACCEL := 3500.0
const RETURN_MAX_SPEED := 1300.0
# =======================================================

var type := WeaponDefs.Type.BOOMERANG
var state := State.OUT
var _player: Player
var _dir := Vector2.RIGHT
var _out_dist := 24.0
var _out_time := OUT_TIME_NORMAL
var _color := Color.WHITE
var _spin := 0.0

var _start_pos := Vector2.ZERO
var _target_pos := Vector2.ZERO
var _out_elapsed := 0.0
var _return_delay_left := 0.0
var _return_speed := 0.0


func setup(player: Player, t: int, dir: Vector2, def: Dictionary) -> void:
	_player = player
	type = t
	_dir = dir
	_out_dist = def["out_tiles"] * Game.TILE
	_out_time = OUT_TIME_HEAVY if t == WeaponDefs.Type.HEAVY_BOOMERANG else OUT_TIME_NORMAL
	_color = def["color"]


## 由 Player 摆好 global_position 后调用：确定起点与终点（撞墙则提前截断）。
func begin() -> void:
	_start_pos = global_position
	var far := _start_pos + _dir * (_out_dist + RADIUS)
	var q := PhysicsRayQueryParameters2D.create(_start_pos, far, Game.LAYER_WORLD)
	var r := get_world_2d().direct_space_state.intersect_ray(q)
	var dist := _out_dist
	if not r.is_empty():
		dist = maxf((r.position - _start_pos).length() - RADIUS, 0.0)   # 贴墙时不越过玩家
	_target_pos = _start_pos + _dir * dist
	_out_elapsed = 0.0


func recall() -> void:
	if state == State.RETURN:
		return
	state = State.RETURN
	_return_delay_left = RETURN_DELAY
	_return_speed = 0.0
	Game.frozen = true          # 收回期间冻结其他所有内容


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player) or _player.dead:
		queue_free()
		return
	if Game.frozen and state != State.RETURN:
		return
	var old := global_position
	match state:
		State.OUT:
			_step_out(delta)
		State.RETURN:
			if _step_return(delta):
				return
	_sweep_kill(old, global_position)
	_spin += delta * (30.0 if state != State.IDLE else 12.0)
	_trail.push_front(global_position)
	if _trail.size() > TRAIL_LEN:
		_trail.resize(TRAIL_LEN)
	queue_redraw()


## 用 lerp 从起点缓动到终点；t 走 ease-out 曲线，前段快、末段平滑落位
func _step_out(delta: float) -> void:
	_out_elapsed += delta
	var t := clampf(_out_elapsed / _out_time, 0.0, 1.0)
	var k := 1.0 - pow(1.0 - t, OUT_EASE_POWER)
	global_position = _start_pos.lerp(_target_pos, k)
	if t >= 1.0:
		state = State.IDLE


## 返回 true 表示已归位并销毁
func _step_return(delta: float) -> bool:
	if _return_delay_left > 0.0:
		_return_delay_left -= delta
		return false
	_return_speed = minf(_return_speed + RETURN_ACCEL * delta, RETURN_MAX_SPEED)
	var to_player := _player.global_position - global_position
	var step := _return_speed * delta
	if to_player.length() <= step:
		var move_dir := to_player.normalized() if to_player != Vector2.ZERO else Vector2.ZERO
		_sweep_kill(global_position, _player.global_position)
		Sfx.play("catch", 0.06)
		_player.on_boomerang_caught(self, move_dir)
		queue_free()
		return true
	global_position += to_player.normalized() * step
	return false


func _sweep_kill(a: Vector2, b: Vector2) -> void:
	var space := get_world_2d().direct_space_state
	var p := PhysicsShapeQueryParameters2D.new()
	p.collision_mask = Game.LAYER_ENEMY
	p.collide_with_areas = true
	p.collide_with_bodies = false
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	p.shape = circle
	p.transform = Transform2D(0.0, b)
	p.motion = a - b     # 从 b 向 a 扫回去，覆盖整段路径
	for hit in space.intersect_shape(p, 8):
		var g := hit["collider"] as Guard
		if g:
			g.kill()


## 表现：旋转的回旋镖精灵（8 向步进，避免像素旋转糊掉）+ 一条渐隐拖尾
const PROPS := preload("res://assets/props/props.png")
const TRAIL_LEN := 7
var _trail: Array[Vector2] = []


func _draw() -> void:
	for i in range(1, _trail.size()):
		var k := 1.0 - float(i) / TRAIL_LEN
		var c := Color(_color.r * 0.5 * k, _color.g * 0.5 * k, _color.b * 0.5 * k, k)
		draw_line(to_local(_trail[i - 1]).round(), to_local(_trail[i]).round(), c, 1.0 if i > 2 else 2.0)
	var r := Prop.rect_of("icon_heavy" if type == WeaponDefs.Type.HEAVY_BOOMERANG else "icon_boomerang")
	draw_set_transform(Vector2.ZERO, snappedf(_spin, PI / 4.0))
	draw_texture_rect_region(PROPS, Rect2(-r.size / 2.0, r.size), r, Color(1.5, 1.5, 1.5))
	draw_set_transform(Vector2.ZERO)
