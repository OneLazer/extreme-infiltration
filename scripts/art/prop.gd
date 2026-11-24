@tool
class_name Prop
extends Sprite2D
## 装饰物件（不参与碰撞）。从 props.png 图集里按名字取图，锚点在底边中心。
## 发光像素（屏幕、灯管、招牌）在 props_emit.png 的同一位置，叠一层 HDR 亮度让它进辉光。
## 图集与矩形由 tools/art/gen_props.py 生成。

const ATLAS := preload("res://assets/props/props.png")
const EMIT := preload("res://assets/props/props_emit.png")
const RECTS := preload("res://assets/props/props_rects.gd")

enum Flicker { NONE, NEON, BLINK }

@export var prop_name := "desk":
	set(v):
		prop_name = v
		_apply()
@export var glow := 1.8                  ## 发光层亮度（>1 进辉光）
@export var flicker := Flicker.NONE      ## 霓虹偶发闪烁 / 指示灯慢闪

var _emit: Sprite2D
var _t := 0.0
var _seed := 0.0


func _ready() -> void:
	_apply()
	_seed = fmod(global_position.x * 0.137 + global_position.y * 0.071, 10.0)


func _apply() -> void:
	if not is_inside_tree():
		return
	var r := Prop.rect_of(prop_name)
	texture = ATLAS
	region_enabled = true
	region_rect = r
	centered = false
	offset = Vector2(-floorf(r.size.x / 2.0), -r.size.y)
	if _emit == null:
		_emit = Sprite2D.new()
		_emit.texture = EMIT
		_emit.region_enabled = true
		_emit.centered = false
		add_child(_emit, false, Node.INTERNAL_MODE_FRONT)
	_emit.region_rect = r
	_emit.offset = offset
	_emit.self_modulate = Color(glow, glow, glow)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _emit == null or flicker == Flicker.NONE:
		return
	_t += delta
	var k := 1.0
	match flicker:
		Flicker.NEON:
			# 大部分时间常亮，偶尔抽搐两下
			var ph := fmod(_t + _seed, 6.0)
			if ph > 5.55 and fmod(ph * 23.0, 1.0) < 0.5:
				k = 0.25
		Flicker.BLINK:
			k = 0.55 + 0.45 * signf(sin((_t + _seed) * 2.6))
	_emit.self_modulate = Color(glow * k, glow * k, glow * k, 1.0 if k > 0.3 else 0.0)


static func rect_of(name: String) -> Rect2:
	return RECTS.RECTS.get(name, Rect2(0, 0, 8, 8))


static func names() -> PackedStringArray:
	return PackedStringArray(RECTS.RECTS.keys())


func _validate_property(property: Dictionary) -> void:
	if property.name == "prop_name":
		property.hint = PROPERTY_HINT_ENUM_SUGGESTION
		property.hint_string = ",".join(Prop.names())
