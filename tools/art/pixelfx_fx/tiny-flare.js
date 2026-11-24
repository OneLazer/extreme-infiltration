// Small-scale hit flare for 16px characters (极限潜入行动). Cross-flare recipe adapted from pixelfx's
// impacts/hit-spark, itself from Sprite Fusion's open-source impact (MIT, Copyright (c) 2026 Hugo Duprez).
import { fit, WHITE } from "../../core/index.js";

export const meta = {
  name: "Tiny flare",
  desc: "A small lopsided cross flare round a white diamond, one long ray along the blow; no particles (the game adds its own sparks).",
  tags: ["impact", "hit", "flare", "directional", "one-shot", "small"],
  size: [48, 32], origin: [14, 16], duration: 0.133, loop: false, fps: 30, bg: "dark",
  options: { palette: ["#123a4a", "#1f7a99", "#3fc4e0", "#8ff2ff", "#d9fbff", "#ffffff"], seed: 2 },
};

function ray(p, a, L, w, C, from = 0) {
  const c = Math.cos(a), s = Math.sin(a);
  for (let d = from * L; d <= L; d += 0.5) {
    const u = d / L, hw = w * Math.pow(1 - u, 1.6);
    const col = u < 0.3 ? WHITE : u < 0.62 ? C[4] : u < 0.88 ? C[3] : C[2];
    p.px(c * d, s * d, col);
    if (hw > 0.45) for (let o = 0.5; o <= hw; o += 0.5) for (const e of [-o, o]) p.px(c * d - s * e, s * d + c * e, u < 0.3 && o < 1 ? C[4] : C[3]);
  }
}

function diamond(p, r, C) {
  for (let dy = -r - 1; dy <= r + 1; dy++)
    for (let dx = -r - 1; dx <= r + 1; dx++) {
      const m = Math.abs(dx) + Math.abs(dy);
      if (m <= r) p.px(dx, dy, WHITE);
      else if (m === r + 1) p.px(dx, dy, C[3]);
    }
}

export function draw(p, t, o) {
  const C = fit(o.palette, 6);
  const rays = [[0, 20, 1.6], [Math.PI, 5, 1.6], [-Math.PI / 2, 9, 1.8], [Math.PI / 2, 6, 1.6], [-Math.PI / 4, 4, 0.8]];
  if (t < 1 / 30) {
    for (const [a, L, w] of rays) ray(p, a, L, w, C);
    diamond(p, 2, C);
  } else if (t < 2 / 30) {
    for (const [a, L, w] of rays) ray(p, a, L * 1.2, w * 0.5, C, 0.15);
    diamond(p, 1, C);
  } else if (t < 3 / 30) {
    ray(p, 0, 26, 0.5, [C[0], C[1], C[2], C[2], C[3], C[3]], 0.45);
  }
  const pop = Math.exp(-t / 0.04);
  if (pop > 0.03) { p.glow(0, 0, 12, C[3], 0.35 * pop); p.glow(0, 0, 4, WHITE, 0.2 * pop); }
}
