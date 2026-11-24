class_name WeaponDefs
extends RefCounted
## 武器参数表。玩法数值（射程、位移、拾取弹药）改这里。
## 回旋镖的飞行 / 回收动画节奏见 weapons/boomerang.gd 顶部的常量区。
## shake / shake_time：开火震屏强度（320x180 画布像素）与时长（秒）。
## assist_tiles：宽容判定带宽（图格，默认 2）。命中判定不是一条线，而是一个
##               沿瞄准方向长 射程、垂直方向宽 assist_tiles 的矩形；矩形碰到敌人
##               就算命中。0 = 关闭宽容判定。
## assist_tiles_diagonal：斜向（45°）射击时的带宽（图格，默认 4）。斜线更难瞄，
##               单独放宽一档；不填则退回 assist_tiles。
##
## 反冲方式：
##   recoil_add  —— 在当前速度上叠加 -发射方向 * 数值（轻微推力）
##   recoil_dash —— 类似蔚蓝冲刺：锁定速度 dash_time 秒，忽略重力和输入，
##                  结束时速度乘 end_mult，若向上再乘 0.75（同 Celeste EndDashUpMult）

enum Type { DART, BOOMERANG, HEAVY_BOOMERANG, AIR_GUN }

const DATA := {
	Type.DART: {
		"name": "飞镖", "color": Palette.DART,
		"range": 320.0,            # 射程
		"assist_tiles": 2.0,       # 宽容判定带宽（图格）
		"assist_tiles_diagonal": 4.0,   # 斜向射击的带宽（图格）
		"keep_velocity": false,    # 瞬移后是否保留原速度
		"shake": 2.0, "shake_time": 0.12,
	},
	Type.BOOMERANG: {
		"name": "回旋镖", "color": Palette.BOOMERANG,
		"recoil_add": 30.0,
		"out_tiles": 7.0,
		"catch_speed": 0.0,        # 归位时给玩家的速度（0 = 不给）
		"shake": 1.0, "shake_time": 0.08,
	},
	Type.HEAVY_BOOMERANG: {
		"name": "重型回旋镖", "color": Palette.HEAVY,
		"recoil_dash": 240.0, "dash_time": 0.15, "end_mult": 0.667,
		"out_tiles": 11.0,
		"catch_speed": 220.0, "catch_dash_time": 0.08,
		"shake": 3.0, "shake_time": 0.18,
	},
	Type.AIR_GUN: {
		"name": "气枪", "color": Palette.AIRGUN,
		"range": 320.0,
		"assist_tiles": 2.0,       # 宽容判定带宽（图格）
		"assist_tiles_diagonal": 4.0,   # 斜向射击的带宽（图格）
		"recoil_dash": 320.0, "dash_time": 0.12, "end_mult": 0.6,
		"shake": 2.0, "shake_time": 0.22,
	},
}


static func get_def(t: int) -> Dictionary:
	return DATA[t]


static func is_boomerang(t: int) -> bool:
	return t == Type.BOOMERANG or t == Type.HEAVY_BOOMERANG
