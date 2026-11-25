# 菜单与音效说明

## 结构

- 启动场景：`scenes/ui/main_menu.tscn`（`scripts/ui/main_menu.gd`）。世界部分（雨夜天台、主角、无人机、招牌）在像素视口里，UI 挂在根视口。
- 按 F6 单独运行关卡照常可用；从关卡回主菜单时不播开机动画。
- 新的 autoload（排在 PixelView / Game / ScreenFx 之后）：
  - `Settings`（`scripts/core/settings.gd`）：设置，存 `user://settings.cfg`，改动立即生效。
  - `Progress`（`scripts/core/progress.gd`）：解锁进度与每关最佳用时，存 `user://save.cfg`。
  - `Sfx`（`scripts/core/sfx.gd`）：音效播放，走 SFX 总线。
- 关卡表：`scripts/core/levels.gd` 的 `PATHS`。选关、通关进下一关、解锁都按这个顺序；显示编号 001–012。
  加关卡就往末尾追加路径。不在表里的关（level_temp、test_02）照旧：通关后按 `next_level` 或重开。
- 最后一关通关后进入致谢（标题换成「任务完成」），之后回主菜单。

## 界面代码

| 文件 | 内容 |
|---|---|
| `scripts/ui/ui_kit.gd` | 共用绘制件：面板、选中横带、角括号、开关、分段条、键帽、光标、折行；字号与颜色规范写在文件头 |
| `scripts/ui/menu/menu_host.gd` | 页面栈、翻页动画、输入映射（WASD / 方向键 / 空格 / 回车 / ESC / 鼠标 / Q E）、UI 序列帧特效、像素光标 |
| `scripts/ui/menu/menu_page.gd` | 页面基类：焦点弹簧、横带展开、竖条挤压、确认闪烁、不可选时抖动 |
| `main_page.gd` / `level_select_page.gd` / `settings_page.gd` / `credits_page.gd` / `pause_page.gd` | 各页面 |
| `scripts/ui/pause_menu.gd` | ESC 暂停：由 Level 创建；死亡倒带、通关、转场期间不响应；窗口失焦自动暂停 |

- 选关预览直接实例化关卡场景读数据（墙体、高压电、守卫、出口、起点、武器），改关卡后预览自动更新。
- 设置项在 `settings_page.gd` 顶部的 `TABS` 表里，加一项只要加一行字典，并在 `Settings.DEFAULTS` 里给默认值。
- 屏幕震动档位乘在 `ScreenShake.shake/kick` 上，闪光强度乘在 `ScreenFx.pulse/flash` 上；「后期效果」只关暗角、扫描线、颗粒。
- `ScreenFx` 新增 `crt_on / crt_off`（显像管开关机，`shaders/crt.gdshader`）和 `set_pause`（暂停去色，`post.gdshader` 的 `pause`）。

## 音效

- 全部由 `tools/audio/gen_sfx.py` 用代码合成（只依赖 numpy）：`python3 tools/audio/gen_sfx.py`，输出 `assets/sfx/*.wav`。
- 每个音效是脚本里的一个函数，响度在末尾 `SOUNDS` 表里调（峰值 dBFS）。
- 玩家动作音效在 `Sfx.bind_player` 里接 Player 的信号，没有改 Player / PlayerVisual。守卫、回旋镖、关卡里直接调 `Sfx.play(名字)`。
- 音乐开关对应 Music 总线；目前没有背景音乐，加入时把播放器的 `bus` 设成 `"Music"` 即可受开关控制。

## UI 特效

- `tools/art/pixelfx_fx/ui-spark.js`（选中火花）、`ui-burst.js`（确认爆闪），由 `bake_fx.py` 烘焙成 `assets/fx/ui_spark.png`、`ui_burst.png`。
