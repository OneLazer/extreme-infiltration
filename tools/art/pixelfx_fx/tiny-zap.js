// Electrocution burst for 16px characters (极限潜入行动): forked bolts snap out of a white heart,
// a knot of tiny zigzags re-strikes every frame and shrinks, the light strobes as it dies.
// The halo-body-core inking reuses pixelfx's lightning/_lib (after Sprite Fusion's open-source lightning,
// https://www.spritefusion.com/pixel-art-vfx/lightning, MIT License, Copyright (c) 2026 Hugo Duprez).
import { fit, WHITE, TAU, rng } from "../../core/index.js";
import { zigzag, stroke, crackle } from "../lightning/_lib.js";

export const meta = {
  name: "Tiny zap",
  desc: "A white heart, five forked bolts snap outward and flicker, a shrinking knot of crackles re-strikes each frame, the light strobes out.",
  tags: ["lightning", "electric", "hit", "death", "one-shot", "small"],
  size: [64, 64], origin: [32, 32], duration: 0.4, loop: false, fps: 30, bg: "dark",
  options: { palette: ["#1a0410", "#3a0716", "#7a1030", "#c81e4a", "#ff2a5a", "#ff8aa8", "#ffd6e0", "#ffffff"], seed: 7 },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 8), f = Math.floor(t * 30 + 1e-4), u = t / meta.duration;
  // forked bolts out of the heart: full on the hero frames, flickering, then gone by ~0.2 s
  if (f <= 5 && f !== 4) {
    const r = rng(o.seed, 1, f >> 1);
    const k = f < 2 ? 1 : 0.6;
    for (let i = 0; i < 5; i++) {
      const a = (i / 5) * TAU + r.range(-0.4, 0.4) + 0.3, L = r.range(14, 24) * (f < 2 ? 1 : 1.15);
      stroke(p, zigzag(r, 0, 0, Math.cos(a) * L, Math.sin(a) * L, 0.3, 0.45), k, C, f < 2 ? 0.8 : 0.6, { hero: f === 0 });
    }
  }
  // the knot: tiny zigzags round the heart, re-struck each frame
  if (u < 0.85) {
    const r = rng(o.seed, 3, f), R0 = 9 * (1 - u * 0.7), m = Math.round(9 * (1 - u * 0.6));
    for (let i = 0; i < m; i++) {
      const a = r.range(0, TAU), d0 = r.range(0.5, R0 * 0.4), a2 = a + r.range(-1, 1), d1 = r.range(R0 * 0.6, R0);
      crackle(p, zigzag(r, Math.cos(a) * d0, Math.sin(a) * d0, Math.cos(a2) * d1, Math.sin(a2) * d1, 0.5, 0), 0.8 * (1 - u) + 0.2, C, 0.25);
    }
  }
  if (f <= 1) p.circle(0, 0, 4 - f * 2, WHITE);
  else if (u < 0.7) { p.circle(0, 0, 2 * (1 - u) + 0.5, C[6]); p.px(0, 0, WHITE); }
  p.glow(0, 0, 24 * (1 - u), C[4], 0.5 * Math.exp(-t * 6) * (f % 2 ? 0.6 : 1));
  if (f === 0) p.glow(0, 0, 10, WHITE, 0.4);
}
