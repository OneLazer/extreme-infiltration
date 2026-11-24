class_name WeaponDefs
extends RefCounted
## 武器参数表。调手感只改这里。速度单位 px/s，1 图格 = 8px。
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
		"keep_velocity": false,    # 瞬移后是否保留原速度
	},
	Type.BOOMERANG: {
		"name": "回旋镖", "color": Palette.BOOMERANG,
		"recoil_add": 30.0,
		"out_tiles": 3.0, "out_speed": 260.0, "return_speed": 420.0,
		"catch_speed": 0.0,        # 归位时给玩家的速度（0 = 不给）
	},
	Type.HEAVY_BOOMERANG: {
		"name": "重型回旋镖", "color": Palette.HEAVY,
		"recoil_dash": 240.0, "dash_time": 0.15, "end_mult": 0.667,
		"out_tiles": 5.0, "out_speed": 300.0, "return_speed": 420.0,
		"catch_speed": 220.0, "catch_dash_time": 0.08,
	},
	Type.AIR_GUN: {
		"name": "气枪", "color": Palette.AIRGUN,
		"range": 320.0,
		"recoil_dash": 320.0, "dash_time": 0.12, "end_mult": 0.6,
	},
}


static func get_def(t: int) -> Dictionary:
	return DATA[t]


static func is_boomerang(t: int) -> bool:
	return t == Type.BOOMERANG or t == Type.HEAVY_BOOMERANG
