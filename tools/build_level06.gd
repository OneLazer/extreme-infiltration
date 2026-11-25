extends "res://tools/build_level02.gd"
## 测试关 level_06 生成工具（一次性，非游戏代码）。在工程根目录运行：
##   godot --headless --path . res://tools/build_level06.tscn  [-- --force]
## 复用 build_level02 的流程，地图见 tools/art/map_level06.txt。测试内容：
## 计时门（30 秒）、四个朝向的监控守卫、缴械门 + 刺剑门、电坑、关闭二段跳、开局气枪（反冲冲刺穿激光）。
##
## 新增图例：T 计时门(1×3，字符在最下一格)  N 缴械门(1×3)
##           v 天花板监控(朝下)  > 左墙监控(朝右)  < 右墙监控(朝左下)  ^ 地面监控(朝左上)
## 其余同 build_level02。

const CAMS := {"v": [1, 90.0], ">": [2, 0.0], "<": [3, 160.0], "^": [0, 235.0]}


func _init() -> void:
	map_path = "res://tools/art/map_level06.txt"
	out_path = "res://levels/level_06.tscn"
	level_name = "Level06"


func _configure_root(root: Node) -> void:
	root.set("initial_weapon", 3)           # 气枪
	root.set("allow_double_jump", false)


func _place_entity(root: Node, ents: Node, ch: String, x: int, y: int) -> void:
	var n: Node2D
	match ch:
		"T":
			n = load("res://scenes/timer_gate.tscn").instantiate()
			n.position = Vector2(x * T, (y - 2) * T)
			n.set("seconds", 30.0)
		"N":
			n = load("res://scenes/weapon_zone.tscn").instantiate()
			n.position = Vector2(x * T, (y - 2) * T)
			n.set("weapon_type", -1)
		"v", ">", "<", "^":
			var m: int = CAMS[ch][0]
			n = load("res://scenes/camera_guard.tscn").instantiate()
			n.set("mount", m)
			n.set("look_angle", CAMS[ch][1])
			# 原点 = 贴墙那一面的中点
			match m:
				0: n.position = Vector2(x * T + T / 2.0, (y + 1) * T)
				1: n.position = Vector2(x * T + T / 2.0, y * T)
				2: n.position = Vector2(x * T, y * T + T / 2.0)
				3: n.position = Vector2((x + 1) * T, y * T + T / 2.0)
		_:
			super(root, ents, ch, x, y)
			return
	_own_add(root, ents, n)
