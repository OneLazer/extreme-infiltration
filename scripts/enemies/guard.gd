class_name Guard
extends Area2D
## 守卫基类。玩家身体碰到即死亡；只能被武器击杀（调用 kill()）。
## 场景里 collision_layer = enemy(第3层)，collision_mask = player(第2层)。

signal killed(guard: Guard)

var dead := false


func _ready() -> void:
	add_to_group("enemies")
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not dead and body is Player:
		(body as Player).die()


func kill() -> void:
	if dead:
		return
	dead = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	Fx.burst(get_parent(), global_position, _burst_color(), 10)
	killed.emit(self)
	queue_free()


func _burst_color() -> Color:
	return Palette.GUARD
