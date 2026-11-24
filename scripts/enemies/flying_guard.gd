extends Guard
## 飞行守卫：悬停不动，不攻击。碰到玩家仍会致死。

func _burst_color() -> Color:
	return Palette.FLYER


func _draw() -> void:
	var pts := PackedVector2Array([Vector2(0, -5), Vector2(5, 0), Vector2(0, 5), Vector2(-5, 0)])
	draw_colored_polygon(pts, Palette.FLYER)
	draw_rect(Rect2(-1, -1, 2, 2), Color(0.05, 0.02, 0.1))
