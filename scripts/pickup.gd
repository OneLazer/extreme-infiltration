class_name WeaponPickup
extends Area2D
## 武器拾取点。玩家碰到后加入武器队列末尾（先进先出），本关内不刷新。
## 表现：悬浮的全息展示框（四角括号 + 武器图标 + 扫描线 + 弹药角标），拾取时一圈冲击环。

@export_enum("飞镖:0", "回旋镖:1", "重型回旋镖:2", "气枪:3", "刺剑:4") var weapon_type := 1
@export var ammo := 3

const PROPS := preload("res://assets/props/props.png")
const ICON := {0: "icon_dart", 1: "icon_boomerang", 2: "icon_heavy", 3: "icon_airgun", 4: "icon_rapier"}
const FLARE := {0: "flare_dart", 1: "flare_boomerang", 2: "flare_heavy", 3: "flare_airgun", 4: "flare_rapier"}

var _t := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_t = fmod(global_position.x * 0.03, TAU)


func _on_body_entered(body: Node2D) -> void:
	if body is Player and not (body as Player).dead:
		(body as Player).add_weapon(weapon_type, ammo)
		var c := _color()
		Juice.ring(global_position, 12.0, c, 0.25)
		Juice.glints(global_position, 8, c)
		Juice.flash(global_position, FLARE[weapon_type], -PI / 2.0, Color(1.4, 1.4, 1.4))
		queue_free()


func _color() -> Color:
	return WeaponDefs.get_def(weapon_type)["color"]


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var y := roundf(sin(_t * 3.0) * 1.0)
	var c := _color()
	var dim := Color(c.r * 0.35, c.g * 0.35, c.b * 0.35, 0.9)
	# 底座投影：一条淡淡的光带
	draw_rect(Rect2(-4, 7, 8, 1), Color(c.r * 0.15, c.g * 0.15, c.b * 0.15, 0.6))
	# 四角括号
	var k := 0.65 + 0.2 * sin(_t * 5.0)
	var bc := Color(c.r * k, c.g * k, c.b * k)
	for s in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var corner := Vector2(6 * s.x - (1 if s.x > 0 else 0), 6 * s.y - (1 if s.y > 0 else 0) + y)
		draw_rect(Rect2(corner, Vector2.ONE), bc)
		draw_rect(Rect2(corner - Vector2(s.x, 0), Vector2.ONE), bc)
		draw_rect(Rect2(corner - Vector2(0, s.y), Vector2.ONE), bc)
	# 全息底 + 图标
	draw_rect(Rect2(-5, -5 + y, 10, 10), Color(c.r * 0.06, c.g * 0.06, c.b * 0.06, 0.6))
	var r := Prop.rect_of(ICON[weapon_type])
	draw_texture_rect_region(PROPS, Rect2(Vector2(-4, -4 + y), r.size), r, Color(1.25, 1.25, 1.25))
	# 扫描线：一条亮线从上往下扫
	var sy := -5 + int(fmod(_t * 14.0, 10.0))
	draw_rect(Rect2(-5, sy + y, 10, 1), Color(c.r * 0.25, c.g * 0.25, c.b * 0.25, 0.5))
	TinyDigits.draw(self, "x%d" % ammo, Vector2(-3, -13 + y), dim)
