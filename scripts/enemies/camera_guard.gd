class_name CameraGuard
extends Guard
## 监控守卫：吸附在墙面 / 地面 / 天花板上的球形摄像头，朝固定角度射出一条红色监控激光（被墙截断，电块不挡）。
## 玩家受击框碰到激光立即开火击杀，没有警戒条、没有扇形视野。冲刺无敌时激光打不中（偏折特效）。
## 可以被所有武器击杀，计入关卡守卫数（清完才开出口）。身体接触不伤人。
## 节点原点 = 摄像头底座贴墙那一面的中点。运行时会沿吸附方向找 1.5 格内的墙面贴上去，
## 所以在编辑器里摆在墙边附近即可。外观和编辑器预览由子节点 CameraVisual（@tool）绘制。

## 吸附的表面：地面（摄像头立在地上）/ 天花板（倒挂）/ 左墙 / 右墙
@export_enum("地面:0", "天花板:1", "左墙:2", "右墙:3") var mount := 2
## 监控方向（度）：0 = 向右，90 = 向下，180 = 向左，270 = 向上（屏幕坐标，顺时针）
@export_range(0.0, 359.0, 1.0, "degrees") var look_angle := 20.0

const MOUNT_DIR := [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]   # 墙在哪边
const DOME := Vector2(9, 5)       # 外壳尺寸（沿墙 × 离墙）
const LASER_LEN := 1024.0

var laser_end := Vector2.ZERO     ## 激光落点（全局坐标），CameraVisual 读
var shot_flash := 0.0             ## 开火闪光 1 → 0
var graze := 0.0                  ## 激光擦过冲刺无敌的玩家 1 → 0
var _snapped := false


func _ready() -> void:
	super()
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	var n := normal()
	r.size = Vector2(DOME.x, DOME.y) if n.y != 0.0 else Vector2(DOME.y, DOME.x)
	shape.shape = r
	shape.position = n * DOME.y * 0.5
	add_child(shape)


## 离墙方向（单位向量）
func normal() -> Vector2:
	return -MOUNT_DIR[mount]


func look_dir() -> Vector2:
	return Vector2.from_angle(deg_to_rad(look_angle))


## 镜头位置（全局）：外壳中心朝监控方向偏 2px
func eye_global() -> Vector2:
	return global_position + normal() * DOME.y * 0.5 + look_dir() * 2.0


func _eye() -> Vector2:
	return eye_global() - global_position


func _base_angle() -> float:
	return deg_to_rad(look_angle)


## 沿吸附方向找 1.5 格内的墙面贴上去（第一帧物理里做：_ready 时启动场景还没移进 SubViewport，
## 物理空间不对；TileMapLayer 的碰撞也要等第一帧才建好）
func _snap_to_wall() -> void:
	var d: Vector2 = MOUNT_DIR[mount]
	var from := global_position - d * 4.0
	var q := PhysicsRayQueryParameters2D.create(from, from + d * (Game.TILE * 1.5 + 4.0), Game.LAYER_WORLD)
	var r := get_world_2d().direct_space_state.intersect_ray(q)
	if not r.is_empty():
		global_position = (r.position as Vector2).round()
	else:
		global_position = global_position.round()
	_home = global_position


func _physics_process(delta: float) -> void:
	if dead:
		return
	if not _snapped:
		_snapped = true
		_snap_to_wall()
	shot_flash = maxf(shot_flash - delta * 4.0, 0.0)
	graze = maxf(graze - delta * 6.0, 0.0)
	_t += delta
	var eye := eye_global()
	var q := PhysicsRayQueryParameters2D.create(eye, eye + look_dir() * LASER_LEN, Game.LAYER_WORLD)
	var r := get_world_2d().direct_space_state.intersect_ray(q)
	laser_end = r.position if not r.is_empty() else eye + look_dir() * LASER_LEN
	if Game.frozen:
		return
	var p := Game.player
	if p == null or p.dead:
		return
	var hit := _segment_hits_rect(eye, laser_end, p.hurt_rect())
	if hit < 0.0:
		return
	if p.is_invincible():
		graze = 1.0
		p.deflect(eye.lerp(laser_end, hit))
		return
	_fire(p)


## 立即开火：镜头闪光、激光整条爆亮、一道弹道打到玩家身上
func _fire(p: Player) -> void:
	shot_flash = 1.0
	var eye := eye_global()
	var to := p.global_position - eye
	Juice.flash(eye, "muzzle_airgun", to.angle(), Color(1.7, 1.7, 1.7))
	Juice.trace(eye, p.global_position, Palette.ALERT, 2.0, 0.2)
	Juice.sparks(p.global_position, 8, to, 0.6, 160.0, Palette.ALERT)
	Juice.ring(eye, 5.0, Palette.ALERT, 0.16)
	Sfx.play("laser", 0.04)
	p.die()


## 身体接触不伤人；刺剑冲刺照样能刺中（扫掠判定也会处理）
func _touch_player(p: Player) -> void:
	if p.is_rapier_attacking() and overlaps_body(p):
		p.rapier_kill(self)


## 线段 a→b 与矩形的第一个交点比例（0..1，Liang–Barsky），不相交返回 -1
static func _segment_hits_rect(a: Vector2, b: Vector2, r: Rect2) -> float:
	var d := b - a
	var t0 := 0.0
	var t1 := 1.0
	var ps := [-d.x, d.x, -d.y, d.y]
	var qs := [a.x - r.position.x, r.end.x - a.x, a.y - r.position.y, r.end.y - a.y]
	for i in 4:
		var pp: float = ps[i]
		var qq: float = qs[i]
		if absf(pp) < 0.000001:
			if qq < 0.0:
				return -1.0
			continue
		var t := qq / pp
		if pp < 0.0:
			t0 = maxf(t0, t)
		else:
			t1 = minf(t1, t)
		if t0 > t1:
			return -1.0
	return t0


func _burst_color() -> Color:
	return Palette.ALERT


## 死亡时 CameraVisual 不再画；外壳碎片 + 镜头红色碎片由基类 _death_fx 的 debris 负责
func _silhouette() -> Dictionary:
	return {}
