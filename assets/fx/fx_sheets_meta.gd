## 由 tools/art/bake_fx.py 生成，勿手改。
extends RefCounted

const SHEETS := {
	"flare_airgun": {"w": 48, "h": 32, "frames": 5, "fps": 30, "pivot": Vector2(14, 16)},
	"flare_boomerang": {"w": 48, "h": 32, "frames": 5, "fps": 30, "pivot": Vector2(14, 16)},
	"flare_dart": {"w": 48, "h": 32, "frames": 5, "fps": 30, "pivot": Vector2(14, 16)},
	"flare_electric": {"w": 48, "h": 32, "frames": 5, "fps": 30, "pivot": Vector2(14, 16)},
	"flare_gold": {"w": 48, "h": 32, "frames": 5, "fps": 30, "pivot": Vector2(14, 16)},
	"flare_heavy": {"w": 48, "h": 32, "frames": 5, "fps": 30, "pivot": Vector2(14, 16)},
	"flare_rapier": {"w": 48, "h": 32, "frames": 5, "fps": 30, "pivot": Vector2(14, 16)},
	"kill_dart": {"w": 56, "h": 56, "frames": 10, "fps": 30, "pivot": Vector2(28, 28)},
	"kill_gold": {"w": 56, "h": 56, "frames": 10, "fps": 30, "pivot": Vector2(28, 28)},
	"kill_magenta": {"w": 56, "h": 56, "frames": 10, "fps": 30, "pivot": Vector2(28, 28)},
	"muzzle_airgun": {"w": 28, "h": 18, "frames": 4, "fps": 30, "pivot": Vector2(2, 9)},
	"muzzle_dart": {"w": 28, "h": 18, "frames": 4, "fps": 30, "pivot": Vector2(2, 9)},
	"pierce_rapier": {"w": 64, "h": 28, "frames": 9, "fps": 30, "pivot": Vector2(22, 14)},
	"ui_burst": {"w": 72, "h": 32, "frames": 10, "fps": 30, "pivot": Vector2(16, 16)},
	"ui_spark": {"w": 17, "h": 17, "frames": 7, "fps": 30, "pivot": Vector2(8, 8)},
	"zap_electric": {"w": 64, "h": 64, "frames": 13, "fps": 30, "pivot": Vector2(32, 32)},
}
