shader_type canvas_item;
// 全屏后期：径向色差（脉冲）、去色、闪白、倒带干扰、暗角、胶片颗粒。
// 画在根视口（窗口分辨率）上，读取的是已经放大的 320×180 游戏画面；像素单位都是游戏像素。
// 因为是高分辨率，扫描线能落在每个游戏像素行的下沿（CRT 质感），不会把整行压暗。

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float aberration = 0.0;   // 屏幕边缘的色差偏移（像素）
uniform float desat = 0.0;        // 0..1 去色（死亡）
uniform float flash = 0.0;        // 0..1 闪白
uniform float rewind = 0.0;       // 0..1 倒带干扰
uniform float danger = 0.0;       // 0..1 守卫快开枪时屏幕边缘泛红
uniform float vignette = 0.3;
uniform float grain = 0.02;
uniform float scanline = 0.07;    // 每个游戏像素行下 1/4 变暗的程度
uniform float time = 0.0;
uniform vec2 canvas = vec2(320.0, 180.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = 1.0 / canvas;
	float row = floor(uv.y * canvas.y);
	if (rewind > 0.0) {
		// 横向撕裂：按 6px 条带随机错位，越接近倒带峰值越强
		float band = floor(row / 6.0);
		float j = (hash(vec2(band, floor(time * 24.0))) - 0.5) * 10.0 * rewind;
		// 滚动的跟踪条：一条 10px 高的带子往上爬，带内错位更大
		float track_y = fract(-time * 0.8) * canvas.y;
		float in_track = step(abs(row - track_y), 5.0);
		uv.x += (j + in_track * 6.0 * rewind) * px.x;
	}
	vec2 d = uv - 0.5;
	float r2 = dot(d, d);
	vec2 off = normalize(d + 1e-5) * aberration * px * clamp(r2 * 4.0, 0.0, 1.0);
	vec3 c;
	c.r = texture(screen_tex, uv + off).r;
	c.g = texture(screen_tex, uv).g;
	c.b = texture(screen_tex, uv - off).b;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(l) * vec3(0.85, 0.88, 1.12), desat);
	if (rewind > 0.0) {
		c *= 1.0 - 0.22 * rewind * mod(row, 2.0);                       // 隔行变暗
		float noise = hash(vec2(floor(uv.x * canvas.x / 2.0), row + floor(time * 30.0)));
		float track_y = fract(-time * 0.8) * canvas.y;
		if (abs(row - track_y) < 1.5 && noise > 0.4) c += vec3(0.5) * rewind;  // 跟踪条噪点
	}
	c = mix(c, vec3(2.0), flash);
	// 危险暗角：边缘压暗并染红，接近满条时轻微脉动
	float edge = smoothstep(0.06, 0.42, r2) * danger * (0.85 + 0.15 * sin(time * 18.0));
	c = mix(c, c * vec3(0.55, 0.2, 0.25) + vec3(0.32, 0.02, 0.06), edge * 0.75);
	c *= 1.0 - vignette * smoothstep(0.1, 0.5, r2);
	c *= 1.0 - scanline * step(0.75, fract(SCREEN_UV.y * canvas.y));
	c += (hash(FRAGCOORD.xy + fract(time) * 97.0) - 0.5) * grain;
	COLOR = vec4(c, 1.0);
}
