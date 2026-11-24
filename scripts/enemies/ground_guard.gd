extends Guard
## 普通守卫：站立不动，面朝 facing 方向。
## 玩家进入视野扇形且视线无遮挡即硬锁定：锁定后不再看距离和角度，只按视线判断，
## 躲进掩体（视线被墙挡住）才脱锁，脱锁后倒计时清零。
## 视野扇形只是视觉表现：锁定后中心平滑转向玩家、半角收束成一条线（只留红色瞄准线）、
## 长度一路伸到墙边（等效无限长，实际由墙体裁切），真正的发现判定仍用基础扇形。

@export_enum("左:-1", "右:1") var facing := 1
@export var view_range := 96.0          ## 视野距离（px），12 图格
@export var view_half_angle := 35.0     ## 视野半角（度）
@export var alert_time := 1.0           ## 锁定后到开枪的时间

@export_group("锁定视觉")
@export var focus_half_angle := 0.0     ## 锁定后收窄到的视觉半角（度）；0 = 完全收成一条线，只留瞄准线
@export var lock_range := 8192.0        ## 锁定后的视觉长度（px）：远大于关卡尺寸，即无限长，实际由墙裁切
@export var focus_speed := 9.0          ## 半角收窄 / 长度伸长的过渡速度
@export var turn_speed := 12.0          ## 扇形中心转向玩家的速度

const EYE := Vector2(0, -3)
const CONE_RAYS := 16

var _cone := PackedVector2Array()
var _aim_end := EYE          # 中心瞄准线的落点（本地坐标）

var _locked := false         # 真锁定：发现后一直追到玩家进掩体
var _alert_left := -1.0      # <0 表示未锁定
var _shot_flash := 0.0
var _focus := 0.0            # 视觉收束程度 0..1
var _aim_angle := 0.0        # 扇形中心当前朝向（弧度）


func _ready() -> void:
	super()
	_aim_angle = Vector2(facing, 0).angle()


func _physics_process(delta: float) -> void:
	if dead or Game.frozen:
		return
	var p := Game.player
	if p == null or p.dead:
		_locked = false
		_alert_left = -1.0
		_shot_flash = maxf(_shot_flash - delta, 0.0)
		_update_vision(delta, null)
		queue_redraw()
		return

	# 发现：视线无遮挡 + 落在基础扇形内；锁定后只看视线，进掩体才脱锁
	var los := _has_los(p)
	if _locked:
		if not los:
			_locked = false
	elif los and _in_cone(p):
		_locked = true

	if _locked:
		if _alert_left < 0.0:
			_alert_left = alert_time
		_alert_left -= delta
		if _alert_left <= 0.0:
			_alert_left = -1.0
			_locked = false
			_shot_flash = 0.2
			var muzzle := global_position + Vector2(facing * 7.0, -1.0)
			Juice.flash(muzzle, "muzzle_airgun", (p.global_position - muzzle).angle(), Color(1.7, 1.7, 1.7))
			Juice.trace(muzzle, p.global_position, Palette.ALERT, 2.0, 0.2)
			Juice.sparks(p.global_position, 8, (p.global_position - muzzle), 0.6, 160.0, Palette.ALERT)
			p.die()
	else:
		_alert_left = -1.0
	_shot_flash = maxf(_shot_flash - delta, 0.0)
	_update_vision(delta, p)
	queue_redraw()


## 视觉更新：锁定后扇形中心转向玩家，同时收成一条线并伸长（纯表现，不参与判定）
func _update_vision(delta: float, p: Player) -> void:
	var k_turn := 1.0 - exp(-turn_speed * delta)
	var k_focus := 1.0 - exp(-focus_speed * delta)
	var target_angle := Vector2(facing, 0).angle()
	if _locked and p != null:
		var to := p.global_position - (global_position + EYE)
		if to.length_squared() > 0.0001:
			target_angle = to.angle()
	_aim_angle = lerp_angle(_aim_angle, target_angle, k_turn)
	var focus_target := 1.0 if _locked else 0.0
	_focus = lerpf(_focus, focus_target, k_focus)
	if absf(_focus - focus_target) < 0.001:
		_focus = focus_target      # 收尾吸附，锁定后严格收到 0 度
	_update_cone()


## 用一圈射线求出被墙挡住后的可见扇形，仅用于显示
func _update_cone() -> void:
	var half := deg_to_rad(lerpf(view_half_angle, focus_half_angle, _focus))
	# 半角小于约 0.1°（屏幕上不足 1px）时当作已经完全收束，不画扇形
	if half < 0.002:
		half = 0.0
	# 长度用几何插值（从 view_range 倍增到 lock_range）：跨度极大时，
	# 屏幕上看起来才是持续伸长，而不是一帧就甩出画面
	var base := maxf(view_range, 1.0)
	var length := base * pow(lock_range / base, _focus)
	var space := get_world_2d().direct_space_state
	var eye := global_position + EYE
	_cone = PackedVector2Array()
	# 收束成一条线（半角 0）时不再画扇形，只留下面的瞄准线；顺便省掉一圈射线
	if half > 0.0:
		_cone.append(EYE)
		for i in CONE_RAYS + 1:
			var a := lerpf(-half, half, float(i) / CONE_RAYS)
			var to := eye + Vector2.from_angle(_aim_angle + a) * length
			var r := space.intersect_ray(PhysicsRayQueryParameters2D.create(eye, to, Game.LAYER_WORLD))
			_cone.append((r.position if not r.is_empty() else to) - global_position)
	# 中心瞄准线：同样按墙裁切，锁定时画一条淡线提示已经被盯上
	var center_to := eye + Vector2.from_angle(_aim_angle) * length
	var cr := space.intersect_ray(PhysicsRayQueryParameters2D.create(eye, center_to, Game.LAYER_WORLD))
	_aim_end = (cr.position if not cr.is_empty() else center_to) - global_position


## 基础扇形判定（距离 + 角度），只在未锁定时用来发现玩家
func _in_cone(p: Player) -> bool:
	var to := p.global_position - (global_position + EYE)
	if to.length() > view_range:
		return false
	return absf(rad_to_deg(Vector2(facing, 0).angle_to(to))) <= view_half_angle


## 视线是否被墙挡住（掩体）
func _has_los(p: Player) -> bool:
	var q := PhysicsRayQueryParameters2D.create(global_position + EYE, p.global_position, Game.LAYER_WORLD)
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


## 身体精灵：idle 4 帧呼吸，锁定时换成举枪 + 红色面罩
const SHEET := preload("res://assets/chars/guard.png")
const SIL := preload("res://assets/chars/guard_sil.png")
const FRAME_OFFSET := Vector2(-8, -10)   # 16×16 帧，脚底对齐碰撞盒底边（+6）


func _frame() -> int:
	return 4 if (_locked or _shot_flash > 0.0) else int(_t * 3.0) % 4


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var f := _frame()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing, 1))
	draw_texture_rect_region(SHEET, Rect2(FRAME_OFFSET, Vector2(16, 16)), Rect2(f * 16, 0, 16, 16))
	# 面罩发光层：同一帧的面罩像素再画一遍（HDR），让它进辉光
	var visor := Palette.ALERT if (_locked or _shot_flash > 0.0) else Palette.GUARD
	draw_rect(Rect2(FRAME_OFFSET + Vector2(6, 5), Vector2(5, 1)), visor * Color(0.75, 0.75, 0.75))
	draw_set_transform(Vector2.ZERO)
	# 锁定提示：头顶红色「!」+ 开枪倒计时条
	if _locked:
		var k := clampf(_alert_left / alert_time, 0.0, 1.0)
		var blink := 1.0 if fmod(_t, 0.2) < 0.13 or k > 0.5 else 0.4
		var c := Palette.ALERT * Color(blink, blink, blink)
		draw_rect(Rect2(-1, -17, 2, 4), c)
		draw_rect(Rect2(-1, -12, 2, 1), c)
		draw_rect(Rect2(-5, -9, 10, 1), Color(0.2, 0.05, 0.08))
		draw_rect(Rect2(-5, -9, roundf(10.0 * k), 1), c)


func _silhouette() -> Dictionary:
	return {"tex": SIL, "region": Rect2(_frame() * 16, 0, 16, 16), "offset": FRAME_OFFSET, "flip": facing < 0}


## 视野锥、瞄准线由子节点 VisionCone 用加色混合绘制，读这几个值
func cone_points() -> PackedVector2Array:
	return _cone


func aim_end() -> Vector2:
	return _aim_end


func is_locked() -> bool:
	return _locked


func focus() -> float:
	return _focus
