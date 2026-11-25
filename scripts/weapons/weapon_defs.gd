class_name WeaponDefs
extends RefCounted
## 武器参数表。玩法数值（射程、位移、拾取弹药）改这里。
## 回旋镖的飞行 / 回收动画节奏见 weapons/boomerang.gd 顶部的常量区。
## shake / shake_time：开火震屏强度（320x180 画布像素）与时长（秒）。
## assist_tiles：宽容判定带宽（图格，默认 3）。飞镖 / 气枪的命中判定不是一条线，
##               而是一个沿瞄准方向长 射程、垂直方向宽 assist_tiles 的矩形，矩形碰到
##               敌人就算命中；回旋镖用它决定投掷方向要不要偏折到带宽里的敌人。
##               鼠标瞄准下角度连续，所有方向同一档带宽。0 = 关闭宽容判定。
## bounce_wall_x / bounce_wall_up / bounce_floor_up（仅飞镖）：飞镖瞬移撞墙后的收尾速度。
##               撞竖直墙 → X 反向 bounce_wall_x、Y 向上 bounce_wall_up；
##               撞地板 → Y 向上 bounce_floor_up（X 不动）；撞天花板 → 不变。
##
## 反冲方式：
##   recoil_add  —— 在当前速度上叠加 -发射方向 * 数值（轻微推力）
##   recoil_dash —— 类似蔚蓝冲刺：锁定速度 dash_time 秒，忽略重力和输入，
##                  结束时速度乘 end_mult，若向上再乘 0.75（同 Celeste EndDashUpMult）

enum Type { DART, BOOMERANG, HEAVY_BOOMERANG, AIR_GUN, RAPIER }

## 徒手（无武器）：不能开火，只有一个灰色准星。关卡设置 / 武器替换区域可以把主武器设成它。
## 不放进 Type 枚举（枚举值是 0 起的武器序号），单独用 -1 表示。
const NONE := -1

## 刺剑（RAPIER）：向准心冲刺（复用反冲冲刺 apply_dash，方向取 +瞄准方向），
##   thrust_speed × dash_time ≈ 冲刺距离；冲刺期间身体 + 刀身（blade_len × blade_width）扫掠击杀，
##   对守卫无敌，结束后再无敌 invincible_grace 秒；高压电照样致死。
##   空中只能刺 air_uses 次，落地或刺杀敌人后刷新。

const DATA := {
	NONE: {
		"name": "徒手", "color": Color(0.62, 0.6, 0.78),   # 环境亮度：不发光
		"shake": 0.0, "shake_time": 0.0,
	},
	Type.DART: {
		"name": "飞镖", "color": Palette.DART,
		"range": 320.0,            # 射程
		"assist_tiles": 3.0,       # 宽容判定带宽（图格）
		"keep_velocity": false,    # 瞬移后是否保留原速度
		"bounce_wall_x": 150.0,     # 撞竖直墙：反向 X 速度
		"bounce_wall_up": 150.0,    # 撞竖直墙：向上 Y 速度
		"bounce_floor_up": 150.0,   # 撞地板：向上 Y 速度
		"shake": 2.0, "shake_time": 0.12,
	},
	Type.BOOMERANG: {
		"name": "回旋镖", "color": Palette.BOOMERANG,
		"recoil_add": 30.0,
		"out_tiles": 7.0,
		"assist_tiles": 3.0,       # 宽容判定带宽（图格）
		"catch_speed": 0.0,        # 归位时给玩家的速度（0 = 不给）
		"shake": 1.0, "shake_time": 0.08,
	},
	Type.HEAVY_BOOMERANG: {
		"name": "重型回旋镖", "color": Palette.HEAVY,
		"recoil_dash": 240.0, "dash_time": 0.15, "end_mult": 0.667,
		"out_tiles": 11.0,
		"assist_tiles": 3.0,       # 宽容判定带宽（图格）
		"catch_speed": 220.0, "catch_dash_time": 0.08,
		"shake": 3.0, "shake_time": 0.18,
	},
	Type.AIR_GUN: {
		"name": "气枪", "color": Palette.AIRGUN,
		"range": 320.0,
		"assist_tiles": 3.0,       # 宽容判定带宽（图格）
		"recoil_dash": 320.0, "dash_time": 0.12, "end_mult": 0.6,
		"shake": 2.0, "shake_time": 0.22,
	},
	Type.RAPIER: {
		"name": "刺剑", "color": Palette.RAPIER,
		"thrust_speed": 320.0, "dash_time": 0.15, "end_mult": 0.6,   # 约 48px = 6 格
		"blade_len": 12.0,         # 刀身伸出身体的长度（px）
		"blade_width": 10.0,       # 扫掠判定宽度（px），比身体（6）宽，算作宽容判定
		"invincible_grace": 0.05,  # 冲刺结束后额外无敌（秒）
		"air_uses": 1,             # 空中可用次数
		"shake": 1.5, "shake_time": 0.1,
	},
}


static func get_def(t: int) -> Dictionary:
	return DATA.get(t, DATA[NONE])


static func is_none(t: int) -> bool:
	return t == NONE


static func is_boomerang(t: int) -> bool:
	return t == Type.BOOMERANG or t == Type.HEAVY_BOOMERANG
