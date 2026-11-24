extends Guard
## 普通守卫：站立不动，面朝 facing 方向。玩家进入视野扇形且无墙遮挡时
## 开始倒计时，倒计时结束击杀玩家。

@export_enum("左:-1", "右:1") var facing := 1
@export var view_range := 96.0          ## 视野距离（px），12 图格
@export var view_half_angle := 35.0     ## 视野半角（度）
@export var alert_time := 3.0           ## 发现后到开枪的时间
@export var reset_when_lost := true     ## 丢失视野时重置倒计时；false = 一旦发现就持续倒数

const EYE := Vector2(0, -3)
const CONE_RAYS := 16

var _cone := PackedVector2Array()

var _alert_left := -1.0     # <0 表示未发现
var _shot_flash := 0.0


func _physics_process(delta: float) -> void:
	if dead or Game.frozen:
		return
	var p := Game.player
	if p == null or p.dead:
		_alert_left = -1.0
		queue_redraw()
		return
	var sees := _can_see(p)
	if sees and _alert_left < 0.0:
		_alert_left = alert_time
	elif not sees and reset_when_lost:
		_alert_left = -1.0
	if _alert_left >= 0.0:
		_alert_left -= delta
		if _alert_left <= 0.0:
			_alert_left = -1.0
			_shot_flash = 0.2
			Fx.trace(get_parent(), global_position + EYE, p.global_position, Palette.ALERT)
			p.die()
	_shot_flash = maxf(_shot_flash - delta, 0.0)
	_update_cone()
	queue_redraw()


## 用一圈射线求出被墙挡住后的可见扇形，仅用于显示
func _update_cone() -> void:
	var space := get_world_2d().direct_space_state
	var eye := global_position + EYE
	_cone = PackedVector2Array([EYE])
	for i in CONE_RAYS + 1:
		var a := deg_to_rad(lerpf(-view_half_angle, view_half_angle, float(i) / CONE_RAYS))
		var to := eye + Vector2(facing, 0).rotated(a) * view_range
		var r := space.intersect_ray(PhysicsRayQueryParameters2D.create(eye, to, Game.LAYER_WORLD))
		_cone.append((r.position if not r.is_empty() else to) - global_position)


func _can_see(p: Player) -> bool:
	var eye := global_position + EYE
	var to := p.global_position - eye
	if to.length() > view_range:
		return false
	if absf(rad_to_deg(Vector2(facing, 0).angle_to(to))) > view_half_angle:
		return false
	var q := PhysicsRayQueryParameters2D.create(eye, p.global_position, Game.LAYER_WORLD)
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _draw() -> void:
	var alerted := _alert_left >= 0.0
	# 视野扇形（被墙体裁切，_physics_process 中计算）
	if _cone.size() >= 3:
		draw_colored_polygon(_cone, Palette.VISION_ALERT if alerted else Palette.VISION)
	# 身体
	var body_c := Palette.ALERT if (alerted or _shot_flash > 0.0) else Palette.GUARD
	draw_rect(Rect2(-4, -6, 8, 12), body_c)
	draw_rect(Rect2(facing * 1.5 - 1, -4, 2, 2), Color(0.05, 0.02, 0.1))
	# 倒计时
	if alerted:
		var txt := "%.1f" % maxf(_alert_left, 0.0)
		draw_string(ThemeDB.fallback_font, Vector2(-12, -9), txt, HORIZONTAL_ALIGNMENT_CENTER, 24, 8, Palette.ALERT)
