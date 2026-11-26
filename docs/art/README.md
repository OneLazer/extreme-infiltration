# 美术与表现层说明

## 渲染结构

- 游戏世界在 320×180 的 SubViewport 里逐像素渲染，再按整数倍放大（`scripts/pixel_view.gd`，autoload `PixelView`）。
- HUD、后期、转场在根视口按窗口分辨率渲染，所以文字不糊。HUD 坐标仍是 320×180 画布单位。
- 切关和重开用 `PixelView.change_scene(path)` / `PixelView.reload()`，不要用 `get_tree().reload_current_scene()`。
- 发光规则：只有可交互物用大于 1 的 HDR 颜色进辉光，环境色都在 0..1 以内。配色见 `scripts/palette.gd` 与 `tools/art/pal.py`。

## 重新生成素材

素材全部由 `tools/art/` 下的 Python 脚本程序绘制（需要 Python 3 + Pillow）：

| 脚本 | 输出 |
|---|---|
| `gen_tiles.py` | `assets/tiles/street_tiles.png/json`：47 格 blob 地形 + 细节变体 |
| `gen_bg.py` | `assets/bg/`：天空、远/中/近三层城市剪影 |
| `gen_chars.py` | `assets/chars/`：玩家、守卫、无人机精灵表及白色剪影 |
| `gen_props.py` | `assets/props/`：装饰物件、武器图标、手持武器、电梯门 |
| `bake_fx.py <pixelfx 路径>` | `assets/fx/`：用 pixelfx 烘焙枪口火光、命中闪光、击杀爆闪、刺剑穿刺星芒、电击爆闪（需要 Node 18+） |
| `gen_electric.py` | `assets/tiles/electric_tile.png`：高压电块在编辑器里的预览瓦片（运行时隐藏） |
| `style_frame.py` | 风格样张合成图 |
| `key_art.py` | 16:9 宣传主视觉 `docs/art/key_art_1920x1080.png` / `key_art_3840x2160.png`（240×135 画布整数倍放大，只有标题字组） |

改完图集后在 Godot 里运行 `tools/build_art.tscn`（F6）：重建 TileSet、背景场景，并给关卡换上新墙体与背景墙。
关卡里已有 `Decor` 节点时不会重新摆放装饰；要重摆，命令行加 `-- --redress`，或者先删掉 `Decor` 节点。
只想重摆装饰、不碰墙体和背景（例如新关卡只差装饰），运行 `tools/dress_levels.tscn`：脚本里的 `TARGETS`
列出要处理的关卡，按同一套规则重摆 `Decor`。

## 装饰摆放规则

- 地面物件只摆在关卡内部的墙面上，地图外不算地板，不会出现悬空物件；矮天花板下面只放得下小件。
- 吊灯每隔 64px 挂一盏，下方空间够高才挂，光锥长度量到地面。
- 霓虹竖招牌挂在开阔的背景墙上；出口标识默认挂在出口左上，那里是墙就在出口上方挪到最近的不被遮挡的位置。

## 新关卡怎么接

1. 在编辑器里用 `assets/tiles/street_tileset.tres` 的 Terrain「街区结构」刷墙，会自动拼接。
2. 把新关卡路径加进 `tools/build_art.gd` 的 `LEVELS`，运行一次 `build_art.tscn`，自动加窗外背景、玻璃幕墙和装饰物件。
3. 装饰物件是 `Prop` 节点（`scripts/art/prop.gd`），在检查器里改 `prop_name` 换物件，`flicker` 设霓虹闪烁或指示灯慢闪。
4. 吊灯光锥 `LightCone`、加色光斑 `GlowSpot` 都可以手动添加、拖动。
5. 高压电块：加一个 TileMapLayer，挂 `scripts/hazards/electric_layer.gd`，TileSet 用 `assets/tiles/electric_tileset.tres`，像墙一样刷。
   编辑器里显示红色斜纹；运行时瓦片隐藏，由 `ElectricRenderer` 整片渲染（内部 `shaders/electric.gdshader` + 边缘电弧 + 定时放电）。
   一个关卡只放一层电层（`Game.electric` 只登记一个）。
6. 武器替换区域：实例化 `scenes/weapon_zone.tscn`，检查器里选武器和 `size_tiles`（默认 1×3），原点在左上角，按 8px 网格对齐。
7. 守卫游荡范围在检查器「游荡与追击」组（`wander_tiles`，地面 5×1、无人机 5×5），警戒条参数在「警戒条」组。
8. 测试关 `levels/level_02.tscn` 由 `tools/build_level02.tscn` 从 `tools/art/map_level02.txt` 生成，不会改动 level_01 和 street_tileset。

## 特效入口

- `scripts/fx/juice.gd`：尘土、硝烟、火花、碎片、机油、弹壳、冲击环、弹道、残影、序列帧闪光，静态函数调用。
- `scripts/visual/player_visual.gd`：玩家动画、挤压拉伸、围巾布条（位置平滑，无惯性过冲）、手持武器，以及跳跃/落地/开火/瞬移/死亡特效。
- `scripts/game.gd`：`Game.hitstop(秒)` 顿帧、`Game.slowmo(倍率, 秒)` 慢动作。
- `scripts/ui/screen_fx.gd`（autoload `ScreenFx`）：色差脉冲、闪白、死亡倒带、转场、守卫快满条时的红色危险暗角（`danger(k)`）。`enabled = false` 可关掉后期。
- `scripts/hazards/electric_fx.gd`：电击（剪影红白闪 + 电弧爆闪 + 火花），玩家和无人机被电死时用。
