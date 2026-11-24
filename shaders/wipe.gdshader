shader_type canvas_item;
// 关卡转场：按 6px 横条交错擦除，前沿一条青色亮线。
// progress 0 = 全黑，1 = 全开。dir = 1 从左往右揭开，-1 从右往左。

uniform float progress = 1.0;
uniform float dir = 1.0;
uniform vec4 cover : source_color = vec4(0.027, 0.024, 0.059, 1.0);
uniform vec4 edge : source_color = vec4(0.56, 0.89, 1.0, 1.0);
uniform vec2 canvas = vec2(320.0, 180.0);

void fragment() {
	float row = floor(UV.y * canvas.y / 6.0);
	float stagger = mod(row, 2.0) * 0.14 + fract(row * 0.37) * 0.06;
	float x = dir > 0.0 ? UV.x : 1.0 - UV.x;
	float t = progress * 1.25 - stagger;
	float px = 1.0 / canvas.x;
	if (x > t) {
		COLOR = cover;
	} else if (x > t - 2.0 * px && progress > 0.0 && progress < 1.0) {
		COLOR = edge;
	} else {
		COLOR = vec4(0.0);
	}
}
