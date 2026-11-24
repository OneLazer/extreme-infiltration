class_name Guard
extends Area2D
## 守卫基类。玩家身体碰到即死亡；只能被武器击杀（调用 kill()）。
## 场景里 collision_layer = enemy(第3层)，collision_mask = player(第2层)。
## 表现：精灵由子类在 _draw 里画；死亡特效（顿帧、闪白、碎片、火花、机油）在这里统一处理。

signal killed(guard: Guard)

const ARMOR := [Color("#262540"), Color("#55577a"), Color("#73759a"), Color("#aeb0d0")]

var dead := false
var _t := 0.0


func _ready() -> void:
	add_to_group("enemies")
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not dead and body is Player:
		(body as Player).die()


## dir：击中方向（碎片、机油往这个方向飞）。回旋镖等不传时按玩家 → 守卫的方向
func kill(dir := Vector2.ZERO) -> void:
	if dead:
		return
	dead = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if dir == Vector2.ZERO and Game.player:
		dir = (global_position - Game.player.global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.UP
	_death_fx(dir)
	killed.emit(self)
	queue_free()


func _death_fx(dir: Vector2) -> void:
	var at := global_position
	var sil := _silhouette()
	if not sil.is_empty():
		Juice.ghost(at, sil["tex"], sil["region"], sil["offset"], sil["flip"], Vector2.ONE,
			Color(3.0, 3.0, 3.0), 0.1, 1.0)
	Juice.flash(at, "kill_gold", dir.angle(), Color(1.5, 1.5, 1.5))
	Juice.debris(at, 9, dir, ARMOR, 140.0, ARMOR[3])
	Juice.debris(at, 2, dir, [_burst_color()], 120.0, Color.WHITE)
	Juice.sparks(at, 14, dir, 1.0, 200.0)
	Juice.oil(at, 10, dir, 130.0)
	Juice.smoke(at, 3, Vector2.UP, 14.0, Color(0.25, 0.22, 0.35))
	Game.hitstop(0.07)
	if Game.player:
		var cam := Game.player.get_node_or_null("Camera2D")
		if cam:
			cam.shake(2.5, 0.18)
			cam.kick(dir * 3.0)


## 子类返回当前帧的白色剪影：{tex, region, offset(帧左上角相对 global_position，按未翻转算), flip}
func _silhouette() -> Dictionary:
	return {}


func _burst_color() -> Color:
	return Palette.GUARD
