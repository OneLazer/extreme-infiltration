@tool
class_name ElectricLayer
extends TileMapLayer
## 高压电层：用 assets/tiles/electric_tileset.tres 的那一格在编辑器里刷，和墙体瓦片一样画。
## 没有物理碰撞：不挡人、不挡视线、不挡子弹（同蔚蓝 Farewell 的电块）。
## 碰到就死（玩家每帧查 Game.electric_overlaps，刺剑无敌也挡不住）；地面守卫不会走进去，
## 无人机追击时被引进来会被电死。
## 运行时把瓦片本身隐藏，换成 ElectricRenderer 对整片区域统一渲染（内部噪声 + 边缘电弧 + 定时放电）。

var renderer: ElectricRenderer


## 登记放在 _enter_tree 而不是 _ready：启动场景（F5 / F6）会被 PixelView reparent 进 SubViewport，
## reparent 会先 _exit_tree 再 _enter_tree，但 _ready 不会再跑。以前在 _ready 里登记、
## _exit_tree 里注销，结果刚启动时电层被注销，电块形同虚设，死一次重开后才恢复。
func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		Game.register_electric(self)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	visible = false            # 隐藏后格子数据仍可查询
	renderer = ElectricRenderer.new()
	renderer.name = name + "Renderer"
	renderer.position = position
	get_parent().add_child.call_deferred(renderer)
	renderer.setup.call_deferred(self)
	_move_renderer.call_deferred()


## 渲染器排在电层原来的位置（同一绘制顺序）
func _move_renderer() -> void:
	if is_instance_valid(renderer) and renderer.get_parent() == get_parent():
		get_parent().move_child(renderer, get_index() + 1)


func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		Game.unregister_electric(self)
