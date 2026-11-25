// Menu confirm burst for 极限潜入行动: a white bar flash, corner brackets snap outward, sparks streak right.
import { fit, WHITE, Rng } from "../../core/index.js";

export const meta = {
  name: "UI burst",
  desc: "A white vertical bar flashes at the cursor, four corner brackets kick out from it and fade, a fan of short streaks shoots right along the menu row.",
  tags: ["ui", "confirm", "burst", "brackets", "one-shot", "small"],
  size: [72, 32], origin: [16, 16], duration: 0.3, loop: false, fps: 30, bg: "dark",
  options: { palette: ["#3a1446", "#6e1f6a", "#b8327f", "#ff4f9a", "#ffa3cf", "#ffffff"], seed: 3 },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 6), R = new Rng(o.seed);
  const f = Math.floor(t * 30);
  // 0–1 帧：竖条白闪
  if (f <= 1) for (let y = -7 + f * 2; y <= 7 - f * 2; y++) { p.px(0, y, WHITE); p.px(1, y, f ? C[4] : WHITE); }
  // 角括号往外弹：快出慢停，后半段变暗、断开
  const u = Math.min(1, t / 0.3), e = 1 - Math.pow(1 - u, 3);
  const hx = 4 + 10 * e, hy = 5 + 5 * e, arm = Math.max(1, Math.round(4 - 3 * u));
  const col = u < 0.35 ? WHITE : u < 0.65 ? C[4] : C[3];
  if (u < 0.92 && f >= 1)
    for (const [sx, sy] of [[-1, -1], [1, -1], [-1, 1], [1, 1]]) {
      const cx = Math.round(sx * hx), cy = Math.round(sy * hy);
      for (let i = 0; i <= arm; i++) { p.px(cx - sx * i, cy, col); p.px(cx, cy - sy * i, col); }
    }
  // 一束往右的短线：每条起点、速度、长度都不一样
  for (let i = 0; i < 7; i++) {
    const y = Math.round(R.range(-6, 6)), v = R.range(90, 190), L = R.range(3, 8), d0 = R.range(0, 0.05);
    const tt = t - d0;
    if (tt <= 0) continue;
    const x = 3 + v * tt, len = L * (1 - tt / 0.25);
    if (len < 0.6) continue;
    for (let k = 0; k < len; k++) p.px(Math.round(x - k), y, k < 1 ? C[4] : k < len * 0.6 ? C[3] : C[2]);
  }
  const pop = Math.exp(-t / 0.05);
  p.glow(0, 0, 10, C[3], 0.35 * pop);
}
