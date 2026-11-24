class_name ElectricFx
extends RefCounted
## 高压电相关的一次性特效（静态函数）。电块本身的常驻渲染见 hazards/electric_layer.gd。


## 电击：剪影红白交替闪 + 电弧炸开（pixelfx 烘焙的 zap_electric）+ 电色火花。
## ghost_at：剪影的锚点（Guard 用 global_position，玩家用身体精灵的位置）；sil 可为空。
## center：电弧炸开的中心，不传则同 ghost_at。
static func zap(ghost_at: Vector2, sil: Dictionary, center := Vector2.INF) -> void:
	var at := ghost_at if center == Vector2.INF else center
	if not sil.is_empty():
		for i in 3:
			var c := Palette.ELECTRIC_CORE if i % 2 == 0 else Palette.ELECTRIC
			Juice.ghost(ghost_at, sil["tex"], sil["region"], sil["offset"], sil["flip"], Vector2.ONE,
				c, 0.06 + i * 0.07, 1.0)
	Juice.flash(at, "zap_electric", randf() * TAU, Color(1.5, 1.5, 1.5))
	Juice.sparks(at, 14, Vector2.UP, PI, 220.0, Palette.ELECTRIC)
	Juice.sparks(at, 5, Vector2.UP, PI, 140.0, Palette.ELECTRIC_CORE)
	Juice.smoke(at, 2, Vector2.UP, 12.0, Color(0.3, 0.18, 0.28))
	Game.hitstop(0.09)
