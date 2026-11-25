shader_type canvas_item;
// 显像管开关机：画面先上下收成一条亮线，再左右收成一个亮点，最后熄灭。
// progress 0 = 正常画面，1 = 全黑。开机时把 progress 从 1 走回 0（同一条曲线倒放）。

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float progress = 0.0;
uniform vec4 line_col : source_color = vec4(0.85, 0.97, 1.0, 1.0);
uniform vec2 canvas = vec2(320.0, 180.0);

void fragment() {
	if (progress <= 0.0) {
		COLOR = texture(screen_tex, SCREEN_UV);
	} else {
		vec2 uv = SCREEN_UV;
		vec2 d = (uv - 0.5) * canvas;               // 离中心的游戏像素
		float a = clamp(progress / 0.5, 0.0, 1.0);  // 阶段一：竖向收拢
		float b = clamp((progress - 0.5) / 0.32, 0.0, 1.0);   // 阶段二：横向收拢
		float c = clamp((progress - 0.82) / 0.18, 0.0, 1.0);  // 阶段三：亮点熄灭
		float half_h = max(mix(canvas.y * 0.5, 0.5, a * a * (3.0 - 2.0 * a)), 0.5);
		float half_w = mix(canvas.x * 0.5, 1.0, b * b);
		vec3 col = vec3(0.0);
		if (abs(d.y) <= half_h && abs(d.x) <= half_w) {
			if (a < 1.0) {
				// 还没收成线：把画面竖向压扁，越扁越亮
				vec2 suv = vec2(uv.x, 0.5 + (uv.y - 0.5) * (canvas.y * 0.5) / half_h);
				col = texture(screen_tex, suv).rgb;
				col = mix(col, line_col.rgb * 1.6, a * a);
			} else {
				col = line_col.rgb * mix(1.8, 2.4, b) * (1.0 - c);
			}
		} else if (a >= 1.0 && abs(d.y) <= 1.5 && abs(d.x) <= half_w + 2.0) {
			col = line_col.rgb * 0.35 * (1.0 - c);   // 亮线上下一圈淡光
		}
		COLOR = vec4(col, 1.0);
	}
}
