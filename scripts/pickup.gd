class_name WeaponPickup
extends Area2D
## 武器拾取点。玩家碰到后加入武器队列末尾（先进先出），本关内不刷新。

@export_enum("回旋镖:1", "重型回旋镖:2", "气枪:3") var weapon_type := 1
@export var ammo := 3

var _t := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player and not (body as Player).dead:
		(body as Player).add_weapon(weapon_type, ammo)
		Fx.burst(get_parent(), global_position, _color(), 8)
		queue_free()


func _color() -> Color:
	return WeaponDefs.get_def(weapon_type)["color"]


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var y := sin(_t * 4.0) * 1.0
	draw_rect(Rect2(-3, -3 + y, 6, 6), _color(), false, 1.0)
	draw_rect(Rect2(-1, -1 + y, 2, 2), _color())
	draw_string(ThemeDB.fallback_font, Vector2(-8, -5 + y), str(ammo), HORIZONTAL_ALIGNMENT_CENTER, 16, 6, _color())
