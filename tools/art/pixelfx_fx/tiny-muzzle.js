// Small muzzle flash for 16px characters (极限潜入行动): a spiky white-cored lobe, two frames and a fade.
import { fit, WHITE } from "../../core/index.js";

export const meta = {
  name: "Tiny muzzle",
  desc: "A tiny forward muzzle flash: frame 1 a fat spiky lobe with a white core and side spikes, frame 2 a thin spike, then a dim wisp.",
  tags: ["muzzle", "gun", "flash", "directional", "one-shot", "small"],
  size: [28, 18], origin: [2, 9], duration: 0.1, loop: false, fps: 30, bg: "dark",
  options: { palette: ["#123a4a", "#1f7a99", "#3fc4e0", "#8ff2ff", "#d9fbff", "#ffffff"], length: 11, seed: 1 },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 6), L = o.length;
  const lobe = (len, wid, core) => {
    for (let x = 0; x <= len; x++) {
      const u = x / len, hw = wid * Math.sin(Math.min(1, u * 1.4) * Math.PI * 0.5) * (1 - u * u);
      for (let y = -Math.ceil(hw); y <= Math.ceil(hw); y++) {
        if (Math.abs(y) > hw + 0.3) continue;
        const e = Math.abs(y) / Math.max(hw, 0.01);
        p.px(x, y, u < core && e < 0.5 ? WHITE : e < 0.7 && u < 0.7 ? C[4] : u < 0.85 ? C[3] : C[2]);
      }
    }
  };
  if (t < 1 / 30) {
    lobe(L, 3.2, 0.55);
    for (const s of [-1, 1]) for (let d = 1; d < 5; d++) p.px(2 + d, s * (2 + d), d < 3 ? C[4] : C[3]);
    p.glow(3, 0, 9, C[3], 0.5); p.glow(2, 0, 3, WHITE, 0.3);
  } else if (t < 2 / 30) {
    lobe(L * 1.15, 1.4, 0.35);
    p.glow(4, 0, 7, C[3], 0.3);
  } else if (t < 3 / 30 - 1e-6) {
    for (let x = 4; x < L; x++) if (x % 2 === 0) p.px(x, 0, C[2]);
  }
}
