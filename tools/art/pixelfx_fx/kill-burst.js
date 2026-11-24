// Enemy-down burst for 16px characters (极限潜入行动): white hero frame, an 8-ray star, a ring that breaks into arcs.
import { fit, WHITE, Rng } from "../../core/index.js";

export const meta = {
  name: "Kill burst",
  desc: "A white disc and an eight-ray star slam in, the star thins while a ring races out and breaks into arcs, the core winks out.",
  tags: ["impact", "kill", "burst", "ring", "one-shot", "small"],
  size: [56, 56], origin: [28, 28], duration: 0.3, loop: false, fps: 30, bg: "dark",
  options: { palette: ["#4a2a10", "#a8582a", "#f2a23d", "#ffd27a", "#fff1c2", "#ffffff"], seed: 5 },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 6), R = new Rng(o.seed);
  const gaps = Array.from({ length: 6 }, (_, i) => i * Math.PI / 3 + R.range(-0.3, 0.3));
  const f = Math.floor(t * 30);
  if (f === 0) p.circle(0, 0, 6, WHITE);
  if (f <= 3) {
    const len = [14, 18, 20, 21][f], w = [2, 1.5, 1, 0.5][f];
    for (let i = 0; i < 8; i++) {
      const a = i * Math.PI / 4 + 0.2, L = i % 2 ? len * 0.55 : len;
      for (let d = f === 0 ? 0 : 4 + f * 2; d <= L; d += 0.5) {
        const u = d / L, c = u < 0.4 ? WHITE : u < 0.75 ? C[4] : C[3];
        p.px(Math.cos(a) * d, Math.sin(a) * d, c);
        if (w > 1 && u < 0.5) p.px(Math.cos(a) * d - Math.sin(a), Math.sin(a) * d + Math.cos(a), C[4]);
      }
    }
  }
  if (f >= 1 && f <= 3) p.circle(0, 0, 4 - f, WHITE);
  if (f >= 1) {
    const u = (t - 1 / 30) / (meta.duration - 1 / 30), r = 5 + 14 * (1 - Math.pow(1 - u, 2.2));
    if (u > 0.96) return;
    let n = 0;
    for (let a = 0; a < Math.PI * 2; a += 0.6 / r) {
      n++;
      if (u > 0.25 && gaps.some((g) => Math.abs(((a - g + Math.PI * 3) % (Math.PI * 2)) - Math.PI) < (u - 0.2) * 0.55)) continue;
      if (u > 0.7 && n % 2) continue;
      p.px(Math.cos(a) * r, Math.sin(a) * r, u < 0.35 ? C[4] : u < 0.7 ? C[3] : C[2]);
    }
  }
  const pop = Math.exp(-t / 0.06);
  p.glow(0, 0, 18, C[3], 0.4 * pop);
  p.glow(0, 0, 6, WHITE, 0.25 * pop);
}
