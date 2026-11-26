extends "res://tools/build_art.gd"
## 装饰补全工具（一次性，非游戏代码）。在工程根目录运行：
##   godot --headless --path . res://tools/dress_levels.tscn
## 只重摆 Decor，规格与 build_art.gd 的自动摆放完全一致
## （地面物件 / 吊灯光锥 / 霓虹招牌 / 安全出口标识）。
## 关卡表直接用 build_art.gd 的 LEVELS，只跳过手工调过的 SKIP 里的关卡；
## 不动 TileSet、墙体、背景与背景墙。

const SKIP := ["res://levels/level_01.tscn", "res://levels/level_06.tscn"]


func _ready() -> void:
	for p in LEVELS:
		if p in SKIP:
			continue
		_dress_one(p)
	get_tree().quit()


func _dress_one(path: String) -> void:
	var uid := _scene_uid(path)
	var root: Node = (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var tm := root.get_node("Walls") as TileMapLayer
	var decor := root.get_node_or_null("Decor")
	if decor:
		root.remove_child(decor)
		decor.free()
		decor = null
	decor = Node2D.new()
	decor.name = "Decor"
	_add_before(root, decor, tm)
	_place_decor(root, decor, tm)
	var ps := PackedScene.new()
	ps.pack(root)
	print("[dress] ", path, " -> ", ResourceSaver.save(ps, path),
		" props=", decor.get_child_count())
	root.free()
	_tidy_file(path, uid)


## 内存里 pack 出来的场景不带 UID，存盘后把头行与 ext_resource 的 uid 补回去，
## 免得编辑器重新分配、diff 里全是 uid 行
func _scene_uid(path: String) -> String:
	var head := FileAccess.get_file_as_string(path).get_slice("\n", 0)
	var at := head.find("uid=\"")
	if at >= 0:
		return head.substr(at + 5, head.find("\"", at + 5) - at - 5)
	var rid := ResourceLoader.get_resource_uid(path)   # 头行被吞了就从 UID 表里找回来
	return "" if rid == ResourceUID.INVALID_ID else ResourceUID.id_to_text(rid)


func _tidy_file(path: String, uid: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	var lines := f.get_as_text().split("\n")
	f.close()
	for i in lines.size():
		if i == 0:
			if uid != "" and not lines[i].contains("uid=\""):
				lines[i] = lines[i].replace("[gd_scene format=4]",
					"[gd_scene format=4 uid=\"%s\"]" % uid)
		elif lines[i].begins_with("[ext_resource") and not lines[i].contains("uid=\""):
			var at := lines[i].find("path=\"")
			if at < 0:
				continue
			var p := lines[i].substr(at + 6, lines[i].find("\"", at + 6) - at - 6)
			var rid := ResourceLoader.get_resource_uid(p)
			if rid != ResourceUID.INVALID_ID:
				lines[i] = lines[i].replace("path=\"",
					"uid=\"%s\" path=\"" % ResourceUID.id_to_text(rid))
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(lines))
	f.close()
