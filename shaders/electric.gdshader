shader_type canvas_item;
// 高压电块内部：整片区域一次画完（不是逐格动画）。
// mask 是 1 像素 = 1 格的遮罩（四周各留 1 格空白），画在覆盖整片区域的矩形上。
// 内部：暗红底 + 缓慢流动的两级明暗块 + 斜向掠过的细亮纹；贴着边缘内侧两级亮边。
// 全部是环境亮度（不超过 1，不进辉光），发光的电弧由 ElectricRenderer 另外画。
// flash：放电时整体提亮。

uniform sampler2D mask : filter_nearest;
uniform vec2 cells = vec2(1.0);        // 遮罩尺寸（格）
uniform float time = 0.0;
uniform float flash = 0.0;
uniform vec4 c_base : source_color = vec4(0.165, 0.027, 0.094, 1.0);   // #2a0718
uniform vec4 c_mid : source_color = vec4(0.243, 0.039, 0.133, 1.0);    // #3e0a22
uniform vec4 c_rim2 : source_color = vec4(0.353, 0.055, 0.173, 1.0);   // #5a0e2c
uniform vec4 c_rim1 : source_color = vec4(0.541, 0.078, 0.220, 1.0);   // #8a1438
uniform vec4 c_hot : source_color = vec4(0.784, 0.118, 0.290, 1.0);    // #c81e4a

float ins(vec2 p) {
	return texture(mask, (floor(p / 8.0) + 0.5) / cells).r;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 px = floor(UV * cells * 8.0) + 0.5;     // 区域内的像素中心
	if (ins(px) < 0.5) discard;
	// 离边缘的像素距离（只看 1、2 px）
	float rim = 0.0;
	for (int d = 2; d >= 1; d--) {
		float o = float(d);
		float out_ = 4.0 - ins(px + vec2(o, 0)) - ins(px - vec2(o, 0)) - ins(px + vec2(0, o)) - ins(px - vec2(0, o));
		if (out_ > 0.5) rim = 3.0 - o;
	}
	vec2 q = floor(px / 2.0) * 2.0;              // 2px 一格量化，噪声块不碎
	float n = vnoise(q * 0.07 + vec2(time * 0.5, -time * 0.35)) * 0.65 + vnoise(q * 0.16 - vec2(time * 0.9, time * 0.2)) * 0.35;
	vec3 c = c_base.rgb;
	if (n > 0.58) c = c_mid.rgb;
	// 斜向亮纹：一条 1px 的细线沿对角线掠过，只在噪声亮处出现
	float streak = fract((px.x * 0.6 - px.y + time * 34.0) / 41.0);
	if (streak < 0.025 && n > 0.5) c = c_rim2.rgb;
	if (rim >= 1.0) c = c_rim2.rgb;
	if (rim >= 2.0) c = c_rim1.rgb;
	c = mix(c, c_hot.rgb, flash * (0.35 + 0.4 * step(1.0, rim)));
	COLOR = vec4(c, 1.0);
}
