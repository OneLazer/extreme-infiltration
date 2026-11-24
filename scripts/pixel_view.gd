extends Node
## 渲染结构（Autoload: PixelView，排在所有 autoload 最前）。
## 游戏世界在 320×180 的 SubViewport 里逐像素渲染，再按整数倍最近邻放大到窗口；
## HUD、后期、转场留在根视口，按窗口分辨率渲染（文字和 UI 不糊）。
##
## 启动时的主场景（或 F6 单独运行的关卡）会被移进 SubViewport。
## 之后切关 / 重开要用 PixelView.change_scene(path) / PixelView.reload()，
## 不要用 get_tree().reload_current_scene()：场景移进 SubViewport 后 SceneTree.current_scene 会变成 null。

const SIZE := Vector2i(320, 180)

var container: SubViewportContainer
var view: SubViewport
var hud_root: Node          ## 关卡把 HUD 用的 CanvasLayer 挂到这里（高分辨率）
var current: Node           ## 当前关卡根节点（在 SubViewport 里）


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	container = SubViewportContainer.new()
	container.name = "PixelContainer"
	container.stretch = true
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	view = SubViewport.new()
	view.name = "PixelView"
	view.size = SIZE
	view.use_hdr_2d = true
	view.snap_2d_transforms_to_pixel = true
	view.snap_2d_vertices_to_pixel = true
	view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	view.handle_input_locally = true
	container.add_child(view)
	add_child(container)
	hud_root = Node.new()
	hud_root.name = "HudRoot"
	add_child(hud_root)
	get_tree().node_added.connect(_on_node_added)
	if get_tree().current_scene:
		_adopt.call_deferred(get_tree().current_scene)


## 切换到另一个场景文件（关卡）
func change_scene(path: String) -> void:
	var ps := load(path) as PackedScene
	if ps == null:
		push_error("PixelView：无法加载 " + path)
		return
	var old := current
	if is_instance_valid(old):
		# 先移出场景树再释放：新关卡 _ready 统计守卫时不会把旧关卡的算进去
		old.get_parent().remove_child(old)
		old.queue_free()
	current = ps.instantiate()
	view.add_child(current)


## 重开当前关卡
func reload() -> void:
	if is_instance_valid(current) and current.scene_file_path != "":
		change_scene(current.scene_file_path)


func _on_node_added(n: Node) -> void:
	if n.get_parent() == get_tree().root and n != self and not _is_autoload(n):
		_adopt.call_deferred(n)


func _adopt(n: Node) -> void:
	if not is_instance_valid(n) or n.get_parent() != get_tree().root or _is_autoload(n):
		return
	n.reparent(view, false)
	current = n


func _is_autoload(n: Node) -> bool:
	return ProjectSettings.has_setting("autoload/" + n.name)
