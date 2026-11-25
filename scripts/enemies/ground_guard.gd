extends Guard
## 地面守卫：以摆放位置为中心左右游荡（默认 5×1 图格），只走 X：不下平台、不撞墙、不进电块。
## 停顿时偶尔回头看一眼。发现玩家后举枪追过去（保持 3 格距离，走到边缘就停下继续瞄），
## 警戒条满（默认 1 秒）开枪。玩家刺剑冲刺无敌时憋着不开，等无敌结束。
## 视野、警戒条、状态机都在 Guard 基类里。

@export_enum("左:-1", "右:1") var facing := 1

const SHEET := preload("res://assets/chars/guard.png")
const SIL := preload("res://assets/chars/guard_sil.png")
const FRAME_OFFSET := Vector2(-8, -10)   # 16×16 帧，脚底对齐碰撞盒底边（+6）
const HALF := Vector2(4, 6)              # 碰撞盒半尺寸
## 帧号见 assets/chars/guard.json：idle 0-3、alert 4、walk 5-8、walk_aim 9-12
const BOB_FRAMES := [6, 8, 10, 12]       # 走路过渡帧：上半身抬高 1px

var _shot_flash := 0.0
var _walk_t := 0.0


func _ready() -> void:
	super()
	_aim_angle = _base_angle()


func _base_angle() -> float:
	return Vector2(facing, 0).angle()


func _flatten(v: Vector2) -> Vector2:
	return Vector2(v.x, 0.0)


## 只走 X。前方有墙、脚下没地、或会碰到电块时不动
func _step(motion: Vector2) -> Vector2:
	var dx := motion.x
	if absf(dx) < 0.0001:
		return Vector2.ZERO
	if not _can_walk(signf(dx), absf(dx)):
		_vel.x = 0.0
		return Vector2.ZERO
	global_position.x += dx
	return Vector2(dx, 0.0)


func _can_walk(s: float, dist: float) -> bool:
	var space := get_world_2d().direct_space_state
	var reach := HALF.x + dist + 0.5
	# 墙：身体中线、脚踝各一条横向射线
	for y in [-3.0, 4.0]:
		var a := global_position + Vector2(0.0, y)
		var q := PhysicsRayQueryParameters2D.create(a, a + Vector2(s * reach, 0.0), Game.LAYER_WORLD)
		if not space.intersect_ray(q).is_empty():
			return false
	# 平台边缘：前脚下方必须有地
	var foot := Vector2(global_position.x + s * (HALF.x + dist), global_position.y + HALF.y)
	var fq := PhysicsRayQueryParameters2D.create(foot + Vector2(0, -1), foot + Vector2(0, 3), Game.LAYER_WORLD)
	if space.intersect_ray(fq).is_empty():
		return false
	# 电块：移动后的身体左右各放宽 1px 不能碰到电格
	var body := Rect2(global_position.x + s * dist - HALF.x - 1.0, global_position.y - HALF.y,
		HALF.x * 2.0 + 2.0, HALF.y * 2.0 - 0.5)
	return not Game.electric_overlaps(body)


## 追击只看水平距离：玩家在头顶平台上时走到正下方附近停住，继续瞄
func _chase(delta: float, p: Player) -> void:
	var dx := p.global_position.x - global_position.x
	var keep := chase_keep_tiles * Game.TILE
	if absf(dx) <= keep:
		_brake(delta)
	else:
		_move_to(Vector2(p.global_position.x - signf(dx) * keep, global_position.y), chase_speed, delta)


## 停顿时偶尔回头看一眼（扇形会平滑转过去）
func _idle(delta: float) -> void:
	if randf() < delta * 0.35:
		facing = -facing


func _tick(delta: float) -> void:
	var p := Game.player
	if _locked and p != null:
		var dx := p.global_position.x - global_position.x
		if absf(dx) > 1.0:
			facing = int(signf(dx))
	elif absf(_vel.x) > 2.0:
		facing = int(signf(_vel.x))
	_walk_t += delta * clampf(absf(_vel.x) / 20.0, 0.6, 1.6)
	_shot_flash = maxf(_shot_flash - delta, 0.0)

## 警戒条满：开枪（玩家无敌时憋着，警戒条保持满，等无敌一结束就开）
func _on_alert_full(p: Player) -> void:
	if p.is_invincible():
		return
	_shot_flash = 0.2
	var muzzle := global_position + Vector2(facing * 7.0, -1.0)
	Juice.flash(muzzle, "muzzle_airgun", (p.global_position - muzzle).angle(), Color(1.7, 1.7, 1.7))
	Juice.trace(muzzle, p.global_position, Palette.ALERT, 2.0, 0.2)
	Juice.sparks(p.global_position, 8, (p.global_position - muzzle), 0.6, 160.0, Palette.ALERT)
	Juice.shell(muzzle, Vector2(-facing * 40.0, -60.0))
	Sfx.play("gunshot", 0.05)
	p.die()


func _frame() -> int:
	var moving := absf(_vel.x) > 3.0
	if _locked or _shot_flash > 0.0:
		return 9 + int(_walk_t * 10.0) % 4 if moving else 4
	if moving:
		return 5 + int(_walk_t * 8.0) % 4
	return int(_t * 3.0) % 4


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var f := _frame()
	var bob := -1.0 if f in BOB_FRAMES else 0.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing, 1))
	draw_texture_rect_region(SHEET, Rect2(FRAME_OFFSET, Vector2(16, 16)), Rect2(f * 16, 0, 16, 16))
	# 面罩发光层：同一帧的面罩像素再画一遍（HDR），让它进辉光。巡逻琥珀 / 搜索橙 / 锁定红
	var visor := Palette.GUARD
	if _locked or _shot_flash > 0.0:
		visor = Palette.ALERT
	elif state == State.SEARCH:
		visor = Palette.SEARCH
	draw_rect(Rect2(FRAME_OFFSET + Vector2(6, 5 + bob), Vector2(5, 1)), visor * Color(0.75, 0.75, 0.75))
	draw_set_transform(Vector2.ZERO)
	_draw_alert(-11.0)


func _silhouette() -> Dictionary:
	return {"tex": SIL, "region": Rect2(_frame() * 16, 0, 16, 16), "offset": FRAME_OFFSET, "flip": facing < 0}
