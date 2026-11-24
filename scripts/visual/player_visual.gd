class_name PlayerVisual
extends Node2D
## 玩家表现层：精灵动画、挤压拉伸、围巾绳模拟、手持武器、残影，以及移动/开火时的特效。
## 只读 Player 的状态、只听它的信号，不改任何玩法数据。挂在 Player 下面。

const SHEET := preload("res://assets/chars/player.png")
const SIL := preload("res://assets/chars/player_sil.png")
const PROPS := preload("res://assets/props/props.png")
const FRAME := Vector2(16, 16)
const FEET := 5.0                       # 碰撞盒底边（原点在碰撞盒中心）
## 动画：起始帧、帧数、fps（与 tools/art/gen_chars.py 的输出一致）
const ANIM := {"idle": [0, 4, 5.0], "run": [4, 4, 12.0], "jump": [8, 1, 1.0], "fall": [9, 1, 1.0],
	"land": [10, 1, 1.0], "wall": [11, 1, 1.0], "dash": [12, 1, 1.0]}

@export var squash_return := 1.75       ## 挤压拉伸回弹速度（每秒，同 Celeste）
@export var scarf_segments := 7
@export var scarf_seg_len := 1.6
@export var ghost_interval := 0.045     ## 冲刺残影间隔（秒）

var _p: Player
var _body: Sprite2D
var _gun: Sprite2D
var _scale := Vector2.ONE
var _anim := "idle"
var _anim_t := 0.0
var _face := 1
var _land_t := 0.0
var _shot_face_t := 0.0
var _gun_kick := 0.0
var _ghost_t := 0.0
var _step_t := 0.0
var _slide_t := 0.0
var _was_dashing := false
var _scarf: PackedVector2Array = []
var _scarf_prev: PackedVector2Array = []
var _t := 0.0


func _ready() -> void:
	_p = get_parent() as Player
	_body = Sprite2D.new()
	_body.texture = SHEET
	_body.centered = false
	_body.region_enabled = true
	_body.offset = Vector2(-8, -16)
	_body.position = Vector2(0, FEET)
	add_child(_body)
	_gun = Sprite2D.new()
	_gun.texture = PROPS
	_gun.region_enabled = true
	_gun.centered = false
	add_child(_gun)
	for i in scarf_segments:
		_scarf.append(_p.global_position)
		_scarf_prev.append(_p.global_position)
	_p.jumped.connect(_on_jumped)
	_p.landed.connect(_on_landed)
	_p.shot.connect(_on_shot)
	_p.thrown.connect(_on_thrown)
	_p.teleported.connect(_on_teleported)
	_p.died.connect(_on_died)
func _process(delta: float) -> void:
	if _p.dead:
		return
	_t += delta
	var on_floor := _p.is_on_floor()
	var v := _p.velocity
	var dashing := _p._dash_timer > 0.0
	var moving_input := Input.get_axis("move_left", "move_right") != 0.0
	# 朝向：跑动时跟移动方向，站着/空中跟瞄准方向，刚开过枪的一小段时间跟弹道方向
	_shot_face_t -= delta
	if _shot_face_t > 0.0:
		pass
	elif moving_input or dashing:
		_face = _p.facing
	else:
		_face = 1 if _p._aim_dir.x >= 0.0 else -1
	# 动画状态
	_land_t -= delta
	var a := "idle"
	if dashing:
		a = "dash"
	elif on_floor:
		a = "land" if _land_t > 0.0 else ("run" if absf(v.x) > 12.0 and moving_input else "idle")
	elif _p._wall_slide_dir != 0:
		a = "wall"
		_face = _p._wall_slide_dir
	else:
		a = "jump" if v.y < 10.0 else "fall"
	if a != _anim:
		_anim = a
		_anim_t = 0.0
	_anim_t += delta * (absf(v.x) / _p.max_run if a == "run" else 1.0)
	var an: Array = ANIM[_anim]
	var f: int = an[0] + int(_anim_t * an[2]) % int(an[1])
	_body.region_rect = Rect2(f * FRAME.x, 0, FRAME.x, FRAME.y)
	_body.flip_h = _face < 0
	# 冲刺开始：沿冲刺方向拉长
	if dashing and not _was_dashing:
		var dv := _p._dash_velocity
		_scale = Vector2(1.45, 0.6) if absf(dv.x) > absf(dv.y) else Vector2(0.6, 1.45)
		Juice.dust(_p.global_position + Vector2(0, FEET - 2), 4, -dv, 35.0, 1.4)
	_was_dashing = dashing
	_scale.x = move_toward(_scale.x, 1.0, squash_return * delta)
	_scale.y = move_toward(_scale.y, 1.0, squash_return * delta)
	_body.scale = _scale
	_update_gun(delta)
	_update_trail(delta, dashing, v)
	_update_ground_fx(delta, on_floor, v, moving_input)
	_update_scarf(delta)
	queue_redraw()
func _update_gun(delta: float) -> void:
	var w := _p.current_weapon()
	var key := "gun_dart"
	var grip := Vector2(1, 3)
	match w:
		WeaponDefs.Type.AIR_GUN:
			key = "gun_airgun"
		WeaponDefs.Type.BOOMERANG:
			key = "icon_boomerang"
			grip = Vector2(2, 5)
		WeaponDefs.Type.HEAVY_BOOMERANG:
			key = "icon_heavy"
			grip = Vector2(2, 5)
	_gun.visible = not is_instance_valid(_p.active_boomerang)
	_gun.region_rect = Prop.rect_of(key)
	var ang := snappedf(_p._aim_dir.angle(), PI / 8.0)   # 16 向，减少像素旋转的锯齿
	var left := cos(ang) < 0.0
	_gun.flip_v = left
	var g := grip
	if left:
		g.y = _gun.region_rect.size.y - 1 - grip.y
	_gun.offset = -g
	_gun.rotation = ang
	_gun_kick = move_toward(_gun_kick, 0.0, 30.0 * delta)
	var shoulder := Vector2(_face * 1.0, FEET - 7.0 * _scale.y)
	if WeaponDefs.is_boomerang(w):
		# 回旋镖握在手里、伸出身体前方 4px，不转向（免得盖住脸）
		_gun.rotation = 0.0
		_gun.flip_v = false
		_gun.flip_h = left
		_gun.offset = -Vector2(4, 4)
		_gun.position = (shoulder + Vector2(0, 2) + Vector2.from_angle(ang) * 5.0).round()
		return
	_gun.flip_h = false
	_gun.position = (shoulder - Vector2.from_angle(ang) * _gun_kick).round()


## 冲刺 / 高速移动时的残影：洋红与青色交替
func _update_trail(delta: float, dashing: bool, v: Vector2) -> void:
	_ghost_t -= delta
	if _ghost_t > 0.0 or not (dashing or absf(v.x) > 170.0):
		return
	_ghost_t = ghost_interval
	var col := Palette.SCARF if int(_t / ghost_interval) % 2 == 0 else Palette.DART
	Juice.ghost(_body.global_position, SIL, _body.region_rect, _body.offset, _body.flip_h, _body.scale, col)


## 跑步脚步尘、急停转身、墙滑掉灰
func _update_ground_fx(delta: float, on_floor: bool, v: Vector2, moving_input: bool) -> void:
	var feet := _p.global_position + Vector2(0, FEET - 1)
	_step_t -= delta
	if on_floor and absf(v.x) > 60.0 and _step_t <= 0.0:
		_step_t = 0.22
		Juice.dust(feet, 1, Vector2(-signf(v.x), -0.4), 18.0, 1.1)
	var inp := Input.get_axis("move_left", "move_right")
	if on_floor and inp != 0.0 and signf(inp) != signf(v.x) and absf(v.x) > 50.0 and _step_t <= 0.1:
		_step_t = 0.12
		Juice.dust(feet, 2, Vector2(signf(v.x), -0.5), 30.0, 1.3)
	_slide_t -= delta
	if _p._wall_slide_dir != 0 and not on_floor and v.y > 10.0 and _slide_t <= 0.0:
		_slide_t = 0.07
		var wall := _p.global_position + Vector2(_p._wall_slide_dir * 3.0, randf_range(-3.0, 3.0))
		Juice.dust(wall, 1, Vector2(-_p._wall_slide_dir, 0.6), 12.0, 1.0)
## 围巾：verlet 绳。根部钉在后颈，惯性 + 重力 + 一点逆风飘动
func _update_scarf(delta: float) -> void:
	var anchor := global_position + Vector2(-_face * 3.0, FEET - 7.0 * _scale.y - 1.0)
	_scarf[0] = anchor
	_scarf_prev[0] = anchor
	# 站着时也向后飘：逆风 + 两个频率叠加的抖动，速度越快飘得越平
	var flutter := sin(_t * 7.0) * 14.0 + sin(_t * 12.3) * 7.0
	var wind := Vector2(-_face * 70.0 - _p.velocity.x * 0.35, flutter - 10.0)
	var acc := (Vector2(0, 95.0) + wind) * delta * delta
	var damp := pow(0.86, delta * 60.0)   # 按 60fps 标定，帧率无关
	for i in range(1, _scarf.size()):
		var cur := _scarf[i]
		_scarf[i] = cur + (cur - _scarf_prev[i]) * damp + acc * (1.0 + i * 0.1)
		_scarf_prev[i] = cur
	for _it in 3:
		for i in range(1, _scarf.size()):
			var d := _scarf[i] - _scarf[i - 1]
			var l := d.length()
			if l > scarf_seg_len and l > 0.0:
				_scarf[i] = _scarf[i - 1] + d / l * scarf_seg_len


func _draw() -> void:
	if _p.dead:
		return
	var col := Palette.SCARF if _p.air_jumps_left() > 0 else Palette.SCARF_USED
	var shade := Color(col.r * 0.55, col.g * 0.55, col.b * 0.6)
	for i in range(_scarf.size() - 1):
		var a := to_local(_scarf[i]).round()
		var b := to_local(_scarf[i + 1]).round()
		if i < 3:
			draw_line(a + Vector2(0, 1), b + Vector2(0, 1), shade, 1.0)
		draw_line(a, b, col, 1.0)


# ======================= 事件特效 =======================

func _feet() -> Vector2:
	return _p.global_position + Vector2(0, FEET - 1)


func _on_jumped(kind: int, dir: int) -> void:
	match kind:
		Player.JumpKind.GROUND:
			_scale = Vector2(0.65, 1.4)
			Juice.dust(_feet(), 4, Vector2.ZERO, 34.0)
		Player.JumpKind.AIR:
			_scale = Vector2(0.75, 1.3)
			Juice.ring(_feet() + Vector2(0, -1), 7.0, Palette.SCARF, 0.2)
			Juice.glints(_feet(), 5, Palette.SCARF)
		Player.JumpKind.WALL:
			_scale = Vector2(0.7, 1.35)
			Juice.dust(_p.global_position + Vector2(-dir * 3.0, 2.0), 4, Vector2(dir, -0.3), 40.0)
		_:
			# super / hyper / 蹭墙跳：更大的尘和一次残影
			_scale = Vector2(1.4, 0.7) if kind != Player.JumpKind.BOUNCE else Vector2(0.65, 1.45)
			Juice.dust(_feet(), 6, Vector2(-dir, -0.3), 55.0, 1.8)
			_ghost_t = 0.0


func _on_landed(fall_speed: float) -> void:
	var k := clampf(fall_speed / _p.max_fall, 0.0, 1.0)
	if k < 0.15:
		return
	_scale = Vector2(lerpf(1.0, 1.5, k), lerpf(1.0, 0.55, k))
	_land_t = 0.06 + 0.06 * k
	Juice.dust(_feet(), int(2 + 4 * k), Vector2.ZERO, 20.0 + 30.0 * k, 1.3 + k)
func _on_shot(type: int, from: Vector2, dir: Vector2, res: Dictionary) -> void:
	var shot_dir: Vector2 = res["dir"]
	var muzzle := from + Vector2(0, -1) + shot_dir * 7.0
	var end: Vector2 = res["end"]
	var wall_hit: bool = res["hit"] and res["enemy"] == null
	var normal: Vector2 = res["normal"]
	_shot_face_t = 0.25
	_face = 1 if shot_dir.x >= 0.0 else -1
	_gun_kick = 3.0
	var cam := _p.get_node_or_null("Camera2D")
	if type == WeaponDefs.Type.DART:
		Juice.flash(muzzle, "muzzle_dart", shot_dir.angle(), Color(1.6, 1.6, 1.6))
		Juice.trace(muzzle, end, Palette.DART, 2.0, 0.14)
		if cam:
			cam.kick(shot_dir * 2.0)
		if wall_hit:
			Juice.flash(end, "flare_dart", normal.angle(), Color(1.5, 1.5, 1.5))
			Juice.sparks(end, 6, normal, 0.8, 120.0, Palette.DART)
			_scorch(end, normal)
		elif res["hit"]:
			Juice.flash(end, "flare_dart", (-shot_dir).angle(), Color(1.5, 1.5, 1.5))
	else:
		Juice.flash(muzzle, "muzzle_airgun", shot_dir.angle(), Color(1.7, 1.7, 1.7))
		Juice.trace(muzzle, end, Palette.AIRGUN, 3.0, 0.16)
		Juice.smoke(muzzle, 4, shot_dir, 30.0)
		Juice.sparks(muzzle, 4, shot_dir, 0.35, 180.0, Palette.AIRGUN)
		Juice.shell(from + Vector2(0, -2), Vector2(-shot_dir.x * 30.0 + randf_range(-15, 15), -110.0))
		if cam:
			cam.kick(-shot_dir * 3.0)
		if wall_hit:
			Juice.flash(end, "flare_airgun", normal.angle(), Color(1.6, 1.6, 1.6))
			Juice.sparks(end, 12, normal, 0.9, 170.0)
			Juice.dust(end, 3, normal, 30.0, 1.6)
			_scorch(end, normal)
		elif res["hit"]:
			Juice.flash(end, "flare_airgun", (-shot_dir).angle(), Color(1.6, 1.6, 1.6))


func _scorch(at: Vector2, normal: Vector2) -> void:
	var j := Juice.get_inst()
	if j and j.decals:
		j.decals.scorch(at, normal)


func _on_thrown(type: int, dir: Vector2) -> void:
	_shot_face_t = 0.25
	_face = 1 if dir.x >= 0.0 else -1
	var col: Color = WeaponDefs.get_def(type)["color"]
	Juice.glints(_p.global_position + dir * 6.0, 4, col)
	if type == WeaponDefs.Type.HEAVY_BOOMERANG:
		Juice.dust(_p.global_position, 4, -dir, 40.0, 1.6)


## 飞镖瞬移：起点到终点留一串渐隐残影，落点一圈青色冲击环
func _on_teleported(from: Vector2, to: Vector2) -> void:
	# 残影数量随距离增加但最多 4 个，越靠近起点越淡、消失越早
	var n := clampi(int(from.distance_to(to) / 28.0), 1, 4)
	for i in n:
		var k := float(i + 1) / (n + 1)
		var p := from.lerp(to, k) + Vector2(0, FEET)
		Juice.ghost(p, SIL, _body.region_rect, _body.offset, _body.flip_h, Vector2.ONE,
			Color(0.3, 1.3, 1.4, 0.25 + 0.35 * k), 0.08 + 0.08 * k)
	Juice.ring(to, 9.0, Palette.DART, 0.18)
	Juice.glints(to, 5, Palette.DART)
	var d := (to - from).normalized()
	_scale = Vector2(1.4, 0.65) if absf(d.x) > absf(d.y) else Vector2(0.65, 1.4)


func _on_died() -> void:
	var at := _p.global_position
	Juice.flash(at, "kill_magenta", 0.0, Color(1.5, 1.5, 1.5))
	Juice.debris(at, 10, Vector2.UP, [Color("#e4e0f5"), Color("#a7a1d0"), Color("#2a2250"), Palette.P3], 130.0, Color.WHITE)
	Juice.sparks(at, 10, Vector2.UP, PI, 150.0, Palette.SCARF)
	Juice.ring(at, 14.0, Palette.SCARF, 0.3)
