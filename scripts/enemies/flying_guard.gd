extends Guard
## 飞行无人机：全向侦察（视野一整圈，默认半径 6 格，参数在 flying_guard.tscn 里覆盖），不开枪。
## 以摆放位置为中心在 5×5 图格内游荡；发现玩家后飞过去，保持 2.5 格距离。
## 警戒条满（默认 1.5 秒）拉响警报：alarm_radius 内的其他守卫警戒条至少拉到 60%（永久警戒），
## 并赶往玩家所在位置搜索。锁定期间每 alarm_interval 秒重报一次位置。
## 追击时不躲电块：被引进电里会被电死，算击杀。碰到玩家仍会致死。
## 表现：旋翼两帧交替、上下轻微浮动、按速度倾斜、独眼按状态变色，报警时红白闪。

@export_group("警报")
@export var alarm_radius := 160.0       ## 警报范围（px），0 = 全关
@export var alarm_interval := 1.0       ## 锁定期间重复报警的间隔（秒）

const SHEET := preload("res://assets/chars/drone.png")
const SIL := preload("res://assets/chars/drone_sil.png")
const FRAME_OFFSET := Vector2(-8, -6)
const HALF := Vector2(5, 5)

static var _box: RectangleShape2D

var _phase := 0.0
var _look := 0.0              # 未锁定时的朝向（弧度）：跟着飞行方向
var _alarm_cd := 0.0
var _siren := 0.0             # 报警闪烁 1 → 0


func _ready() -> void:
	super()
	_phase = fmod(global_position.x * 0.05, TAU)
	if _box == null:
		_box = RectangleShape2D.new()
		_box.size = HALF * 2.0


func _burst_color() -> Color:
	return Palette.FLYER


func _eye() -> Vector2:
	return Vector2(0, -1)


func _base_angle() -> float:
	return _look

# ======================= 移动 =======================

## 用碰撞盒扫掠移动，撞墙时沿墙滑
func _step(motion: Vector2) -> Vector2:
	var moved := _cast(motion)
	global_position += moved
	if moved.length() >= motion.length() - 0.001:
		return motion
	var rest := motion - moved
	var mx := _cast(Vector2(rest.x, 0.0))
	global_position += mx
	var my := _cast(Vector2(0.0, rest.y))
	global_position += my
	if absf(mx.x) < 0.001:
		_vel.x = 0.0
	if absf(my.y) < 0.001:
		_vel.y = 0.0
	return moved + mx + my


func _cast(motion: Vector2) -> Vector2:
	if motion.length_squared() < 1e-8:
		return Vector2.ZERO
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = _box
	q.transform = Transform2D(0.0, global_position)
	q.motion = motion
	q.collision_mask = Game.LAYER_WORLD
	var frac := get_world_2d().direct_space_state.cast_motion(q)
	return motion * frac[0]


## 游荡目标：一路飞过去不撞墙，沿途也不碰电块
func _point_ok(pt: Vector2) -> bool:
	var to := pt - global_position
	if _cast(to).length() < to.length() - 0.01:
		return false
	var steps := maxi(int(to.length() / 3.0), 1)
	for i in steps + 1:
		var c := global_position + to * (float(i) / steps)
		if Game.electric_overlaps(Rect2(c - HALF - Vector2.ONE, HALF * 2.0 + Vector2(2, 2))):
			return false
	return true


## 停顿时慢慢环顾（全向视野下只影响扇形接缝的位置）
func _idle(delta: float) -> void:
	_look += delta * 0.6

func _tick(delta: float) -> void:
	if _vel.length() > 2.0:
		_look = lerp_angle(_look, _vel.angle(), 1.0 - exp(-4.0 * delta))
	_alarm_cd = maxf(_alarm_cd - delta, 0.0)
	_siren = maxf(_siren - delta * 1.5, 0.0)
	# 被引进电块：电死，算击杀
	if Game.electric_overlaps(Rect2(global_position - HALF + Vector2.ONE, HALF * 2.0 - Vector2(2, 2))):
		electrocute()

# ======================= 警报 =======================

func _on_alert_full(p: Player) -> void:
	if _alarm_cd > 0.0:
		return
	_alarm_cd = alarm_interval
	_raise_alarm(p.global_position)


## 通知范围内的其他守卫，并画出「信号线」让玩家看清是谁被叫来了
func _raise_alarm(at: Vector2) -> void:
	_siren = 1.0
	var eye := global_position + _eye()
	Juice.ring(eye, 14.0, Palette.ALERT, 0.3)
	Juice.ring(eye, 30.0, Palette.ALERT * Color(0.6, 0.6, 0.6), 0.5)
	for n in get_tree().get_nodes_in_group("enemies"):
		var g := n as Guard
		if g == null or g == self or g.dead:
			continue
		if alarm_radius > 0.0 and g.global_position.distance_to(global_position) > alarm_radius:
			continue
		var first := not g.is_vigilant() and not g.is_locked()
		g.hear_alarm(at)
		if first:
			Juice.trace(eye, g.global_position + g.eye(), Palette.ALERT * Color(0.7, 0.7, 0.7), 1.0, 0.35)
	ScreenFx.pulse(2.0)
	if Game.player:
		var cam := Game.player.get_node_or_null("Camera2D")
		if cam:
			cam.shake(1.5, 0.15)

# ======================= 绘制 =======================

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _bob() -> Vector2:
	return Vector2(0, roundf(sin(_t * 2.4 + _phase) * 1.2))


## 独眼颜色：巡逻黄 / 搜索橙 / 锁定红；报警时红白快闪
func _eye_color() -> Color:
	if _siren > 0.0 and fmod(_t, 0.1) < 0.05:
		return Color(3.0, 2.6, 2.6)
	if _locked:
		return Palette.ALERT
	return Palette.SEARCH if state == State.SEARCH else Palette.FLYER


func _draw() -> void:
	var f := int(_t * 16.0) % 2
	var o := FRAME_OFFSET + _bob()
	# 按水平速度倾斜（最多约 7°），飞起来有惯性
	draw_set_transform(Vector2.ZERO, clampf(_vel.x * 0.004, -0.12, 0.12))
	draw_texture_rect_region(SHEET, Rect2(o, Vector2(16, 12)), Rect2(f * 16, 0, 16, 12))
	# 独眼（HDR）：中间两格亮、两边暗
	var ec := _eye_color()
	draw_rect(Rect2(o + Vector2(7, 5), Vector2(2, 1)), ec)
	draw_rect(Rect2(o + Vector2(6, 5), Vector2(1, 1)), ec * Color(0.6, 0.6, 0.6))
	draw_rect(Rect2(o + Vector2(9, 5), Vector2(1, 1)), ec * Color(0.6, 0.6, 0.6))
	draw_set_transform(Vector2.ZERO)
	_draw_alert(-9.0 + _bob().y)


func _silhouette() -> Dictionary:
	return {"tex": SIL, "region": Rect2(int(_t * 16.0) % 2 * 16, 0, 16, 12), "offset": FRAME_OFFSET + _bob(), "flip": false}
