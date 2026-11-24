class_name Boomerang
extends Node2D
## 回旋镖弹体（轻型 / 重型共用）。
## OUT：沿发射方向飞行 out_tiles 格，撞墙提前停下 → IDLE：静止悬停
## RETURN：玩家再按方向键后高速飞回玩家（穿墙），归位时通知玩家。
## 全程有攻击判定（含扫掠检测，防止高速穿过敌人）。

enum State { OUT, IDLE, RETURN }

const RADIUS := 3.0

var type := WeaponDefs.Type.BOOMERANG
var state := State.OUT
var _player: Player
var _dir := Vector2.RIGHT
var _out_dist := 24.0
var _out_speed := 260.0
var _return_speed := 420.0
var _traveled := 0.0
var _color := Color.WHITE
var _spin := 0.0


func setup(player: Player, t: int, dir: Vector2, def: Dictionary) -> void:
	_player = player
	type = t
	_dir = dir
	_out_dist = def["out_tiles"] * Game.TILE
	_out_speed = def["out_speed"]
	_return_speed = def["return_speed"]
	_color = def["color"]


func recall() -> void:
	state = State.RETURN


func _physics_process(delta: float) -> void:
	if Game.frozen:
		return
	if not is_instance_valid(_player) or _player.dead:
		queue_free()
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
	queue_redraw()

func _step_out(delta: float) -> void:
	var step := minf(_out_speed * delta, _out_dist - _traveled)
	var from := global_position
	var q := PhysicsRayQueryParameters2D.create(from, from + _dir * (step + RADIUS), Game.LAYER_WORLD)
	var r := get_world_2d().direct_space_state.intersect_ray(q)
	if not r.is_empty():
		global_position = r.position - _dir * RADIUS
		state = State.IDLE
		return
	global_position = from + _dir * step
	_traveled += step
	if _traveled >= _out_dist - 0.01:
		state = State.IDLE


## 返回 true 表示已归位并销毁
func _step_return(delta: float) -> bool:
	var to_player := _player.global_position - global_position
	var step := _return_speed * delta
	if to_player.length() <= step:
		var move_dir := to_player.normalized() if to_player != Vector2.ZERO else Vector2.ZERO
		_sweep_kill(global_position, _player.global_position)
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


func _draw() -> void:
	var pts := PackedVector2Array()
	for i in 3:
		pts.append(Vector2.from_angle(_spin + i * TAU / 3.0) * 4.0)
	draw_colored_polygon(pts, _color)
