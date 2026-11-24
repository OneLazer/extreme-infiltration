// Rapier pierce for 16px characters (极限潜入行动): a long thin four-point star along the thrust,
// a narrow pierce ring standing across it, speed dashes running on past the point. Faces right.
import { fit, WHITE } from "../../core/index.js";

export const meta = {
  name: "Tiny pierce",
  desc: "A white needle-star flares along the thrust, a thin ring stands across it and widens, dashes race on past the point and thin out.",
  tags: ["impact", "pierce", "thrust", "directional", "one-shot", "small"],
  size: [64, 28], origin: [22, 14], duration: 0.267, loop: false, fps: 30, bg: "dark",
  options: { palette: ["#1a1f3a", "#3d4a7a", "#7f8fc8", "#b9c6f0", "#e6ecff", "#ffffff"], seed: 4 },
};

// a ray that tapers to a point: white near the core, cooling down the ramp toward the tip
function needle(p, dir, L, w, C, from = 0) {
  for (let d = from; d <= L; d += 0.5) {
    const u = d / L, hw = w * Math.pow(1 - u, 1.4);
    const c = u < 0.35 ? WHITE : u < 0.7 ? C[4] : C[3];
    p.px(dir * d, 0, c);
    if (hw > 0.5) { p.px(dir * d, -1, u < 0.25 ? C[4] : C[3]); p.px(dir * d, 1, C[3]); }
  }
}

export function draw(p, t, o) {
  const C = fit(o.palette, 6), f = Math.floor(t * 30 + 1e-4);
  if (f === 0) {                                // hero frame: white lozenge, rays at full length
    for (let y = -2; y <= 2; y++) for (let x = -5 + Math.abs(y) * 2; x <= 5 - Math.abs(y) * 2; x++) p.px(x, y, WHITE);
    needle(p, 1, 34, 1.2, C); needle(p, -1, 14, 1.2, C);
    for (const s of [-1, 1]) for (let d = 0; d <= 6; d++) p.px(0, s * d, d < 3 ? WHITE : C[4]);
  } else if (f <= 2) {                          // rays thin and slide forward off the core
    needle(p, 1, 36 + f, 0.6, C, 4 + f * 4); needle(p, -1, 10 - f * 2, 0.4, C, 3);
    for (const s of [-1, 1]) for (let d = 2; d <= 4 - f; d++) p.px(0, s * d, C[4]);
    p.circle(0, 0, 2 - f * 0.6, WHITE);
  }
  if (f >= 1 && f <= 6) {                       // the pierce ring: a tall narrow ellipse across the thrust, widening
    const u = (f - 1) / 5, ry = 4 + 8 * (1 - Math.pow(1 - u, 2)), rx = 1 + 2.5 * u;
    for (let a = 0; a < Math.PI * 2; a += 0.5 / ry) {
      if (u > 0.5 && Math.abs(Math.sin(a)) < 0.35) continue;    // breaks at the sides last
      p.px(4 + u * 6 + Math.cos(a) * rx, Math.sin(a) * ry, u < 0.4 ? C[4] : u < 0.75 ? C[3] : C[2]);
    }
  }
  if (f >= 2 && f <= 7) {                       // speed dashes racing on past the point
    for (const [y, x0, len] of [[-3, 8, 7], [2, 14, 9], [-1, 20, 6], [4, 4, 5]]) {
      const x = x0 + (f - 2) * 6;
      if (x + len > 40) continue;
      for (let d = 0; d < len; d++) p.px(x + d, y, d > len - 3 ? C[4] : f > 5 ? C[2] : C[3]);
    }
  }
  if (f >= 1 && f <= 4) {                       // a glint hangs at the old tip and winks out
    const k = 1 - (f - 1) / 4, x = 30;
    p.px(x, 0, k > 0.5 ? WHITE : C[4]);
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) p.px(x + dx, dy, C[3]);
    if (k > 0.6) for (const [dx, dy] of [[2, 0], [-2, 0], [0, 2], [0, -2]]) p.px(x + dx, dy, C[2]);
    p.glow(x, 0, 5, C[4], 0.3 * k);
  }
  const pop = Math.exp(-t / 0.05);
  p.glow(0, 0, 16, C[3], 0.4 * pop);
  p.glow(8, 0, 6, WHITE, 0.25 * pop);
}
