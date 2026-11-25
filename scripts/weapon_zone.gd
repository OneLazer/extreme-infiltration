@tool
class_name WeaponZone
extends Area2D
## 武器替换区域：玩家碰到后，把队列为空时使用的无限主武器（Player.initial_weapon）换成 weapon_type，
## 已拾取的武器队列不动。区域大小按图格设置（默认 1×3），原点在左上角，方便在编辑器里按 8px 网格对齐。
## 表现：竖直的全息扫描门（两侧光柱 + 顶部武器图标 + 向下扫的扫描线 + 上浮光点），
## 穿过时整门亮一下、光柱闪白、玩家身上一圈冲击环，HUD 弹出「主武器：xx」。
## 玩家手里已经是这把武器时门会变暗，再穿过不重复触发。
## 选「无武器」时是缴械门：灰紫色，图标是划掉的空槽，穿过后主武器变成徒手，手里的武器碎成碎片散落。

@export_enum("无武器:-1", "飞镖:0", "回旋镖:1", "重型回旋镖:2", "气枪:3", "刺剑:4") var weapon_type := 4:
	set(v):
		weapon_type = v
		_rebuild()
@export var size_tiles := Vector2i(1, 3):
	set(v):
		size_tiles = Vector2i(maxi(v.x, 1), maxi(v.y, 1))
		_rebuild()

const PROPS := preload("res://assets/props/props.png")
const ICON := {0: "icon_dart", 1: "icon_boomerang", 2: "icon_heavy", 3: "icon_airgun", 4: "icon_rapier"}
const FLARE := {0: "flare_dart", 1: "flare_boomerang", 2: "flare_heavy", 3: "flare_airgun", 4: "flare_rapier"}
const TILE := 8.0
const NONE_COLOR := Color(1.05, 1.0, 1.35)    ## 缴械门：低饱和灰紫，只微微发光

var _shape: CollisionShape2D
var _t := 0.0
var _hit := 0.0          # 换装闪光 1 → 0


func _ready() -> void:
	collision_layer = 8        # trigger
	collision_mask = 2         # player
	monitorable = false
	_rebuild()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


func _size() -> Vector2:
	return Vector2(size_tiles) * TILE


## 碰撞盒随尺寸重建（内部子节点，不存进场景）
func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _shape == null:
		_shape = CollisionShape2D.new()
		add_child(_shape, false, Node.INTERNAL_MODE_FRONT)
	var r := RectangleShape2D.new()
	r.size = _size()
	_shape.shape = r
	_shape.position = _size() * 0.5
	queue_redraw()
func _equipped() -> bool:
	if Engine.is_editor_hint() or Game.player == null:
		return false
	return Game.player.initial_weapon == weapon_type


func _on_body_entered(body: Node2D) -> void:
	var p := body as Player
	if p == null or p.dead or p.initial_weapon == weapon_type:
		return
	var old := p.initial_weapon
	p.set_main_weapon(weapon_type)
	_hit = 1.0
	var c := _color()
	var at := p.global_position
	Juice.ring(at, 10.0, c, 0.22)
	Juice.glints(at, 8, c)
	if WeaponDefs.is_none(weapon_type):
		_disarm_fx(at, old)
	else:
		Juice.flash(at, FLARE[weapon_type], -PI / 2.0, Color(1.4, 1.4, 1.4))
	for i in 6:   # 光柱上溅出光点
		var x := 0.0 if i % 2 == 0 else _size().x
		Juice.glints(global_position + Vector2(x, randf() * _size().y), 1, c, 3.0)
	ScreenFx.pulse(1.2)
	if Game.level:
		Game.level.toast("主武器：" + str(WeaponDefs.get_def(weapon_type)["name"]), c)


## 缴械：原来的武器色碎成碎片向上崩开，一圈灰色火花，镜头轻震
func _disarm_fx(at: Vector2, old: int) -> void:
	var oc: Color = WeaponDefs.get_def(old)["color"]
	var dark := Color(oc.r * 0.3, oc.g * 0.3, oc.b * 0.3)
	Juice.debris(at + Vector2(0, -1), 6, Vector2.UP, [dark, Palette.N6, oc * Color(0.6, 0.6, 0.6)], 110.0, oc)
	Juice.sparks(at, 8, Vector2.UP, PI * 0.6, 120.0, NONE_COLOR)
	Juice.smoke(at, 2, Vector2.UP, 12.0)
	var cam := Game.player.get_node_or_null("Camera2D") if Game.player else null
	if cam:
		cam.shake(1.2, 0.12)


func _color() -> Color:
	if WeaponDefs.is_none(weapon_type):
		return NONE_COLOR
	return WeaponDefs.get_def(weapon_type)["color"]


func _process(delta: float) -> void:
	_t += delta
	_hit = maxf(_hit - delta * 3.0, 0.0)
	queue_redraw()

func _draw() -> void:
	var s := _size()
	var c := _color()
	var dim := 0.45 if _equipped() else 1.0           # 已装备：整门变暗
	var k := (0.55 + 0.12 * sin(_t * 4.0)) * dim + _hit * 2.0
	var pillar := Color(c.r * k, c.g * k, c.b * k)
	var faint := Color(c.r, c.g, c.b, (0.07 + _hit * 0.25) * dim)
	# 门内淡淡的全息底
	draw_rect(Rect2(1, 0, s.x - 2, s.y), faint)
	# 两侧光柱：1px 竖线，上下端各加亮 2px 当作发射器
	var cap := Color(c.r * (k + 0.5), c.g * (k + 0.5), c.b * (k + 0.5))
	for x in [0.0, s.x - 1.0]:
		draw_rect(Rect2(x, 0, 1, s.y), pillar)
		draw_rect(Rect2(x, 0, 1, 2), cap)
		draw_rect(Rect2(x, s.y - 2, 1, 2), cap)
	# 扫描线：从上往下扫，扫完停一下
	var period := 1.4 if dim >= 1.0 else 2.6
	var sy := floorf(fmod(_t, period) / period * (s.y + 8.0))
	if sy < s.y:
		var sl := Color(c.r * 0.4 * dim, c.g * 0.4 * dim, c.b * 0.4 * dim)
		draw_rect(Rect2(1, sy, s.x - 2, 1), sl)
	# 上浮光点：每列一颗，错开相位
	for i in int(s.x / 3.0) + 1:
		var ph := fmod(_t * 10.0 + i * 7.3, s.y)
		var px := Vector2(2.0 + i * 3.0, s.y - ph).floor()
		if px.x < s.x - 1.0:
			draw_rect(Rect2(px, Vector2.ONE), Color(c.r * 0.3 * dim, c.g * 0.3 * dim, c.b * 0.3 * dim, 0.8))
	# 顶部武器图标 + 四角括号，上下轻浮
	var bob := roundf(sin(_t * 3.0))
	var ic := Vector2(floorf(s.x * 0.5) - 4.0, -11.0 + bob)
	draw_rect(Rect2(ic - Vector2.ONE, Vector2(10, 10)), Color(c.r * 0.05, c.g * 0.05, c.b * 0.05, 0.6))
	var im := 1.25 * dim + _hit
	if WeaponDefs.is_none(weapon_type):
		_draw_empty_icon(ic, Color(c.r * 0.8 * im, c.g * 0.8 * im, c.b * 0.8 * im))
	else:
		var r := Prop.rect_of(ICON[weapon_type])
		draw_texture_rect_region(PROPS, Rect2(ic, r.size), r, Color(im, im, im))
	var bc := Color(pillar.r * 1.2, pillar.g * 1.2, pillar.b * 1.2)
	for corner in [ic - Vector2(2, 2), ic + Vector2(9, -2), ic + Vector2(-2, 9), ic + Vector2(9, 9)]:
		draw_rect(Rect2(corner, Vector2.ONE), bc)
	# 编辑器里画出区域边框，方便摆放
	if Engine.is_editor_hint():
		draw_rect(Rect2(Vector2.ZERO, s), Color(c.r, c.g, c.b, 0.5), false, 1.0)


## 缴械门图标：8×8 虚线空槽 + 一道斜杠（与 HUD 的徒手槽同款）
func _draw_empty_icon(at: Vector2, c: Color) -> void:
	var faint := Color(c.r * 0.55, c.g * 0.55, c.b * 0.6)
	for i in 8:
		if i % 2 == 0:
			for e in [Vector2(i, 0), Vector2(i, 7), Vector2(0, i), Vector2(7, i)]:
				draw_rect(Rect2(at + e, Vector2.ONE), faint)
	for i in range(1, 7):
		draw_rect(Rect2(at + Vector2(7 - i, i), Vector2.ONE), c)
