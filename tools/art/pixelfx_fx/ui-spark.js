// Menu cursor twinkle for 极限潜入行动: a tiny four-point star pops at the selection bar and folds away.
import { fit, WHITE } from "../../core/index.js";

export const meta = {
  name: "UI spark",
  desc: "A four-point star snaps open round a white dot, its long rays thin and pull in, two diagonal glints wink, then nothing.",
  tags: ["ui", "spark", "twinkle", "one-shot", "small"],
  size: [17, 17], origin: [8, 8], duration: 0.2, loop: false, fps: 30, bg: "dark",
  options: { palette: ["#3a1446", "#6e1f6a", "#b8327f", "#ff4f9a", "#ffa3cf", "#ffffff"], seed: 1 },
};

export function draw(p, t, o) {
  const C = fit(o.palette, 6);
  const f = Math.floor(t * 30);
  const len = [4, 6, 5, 3, 2, 1][f] ?? 0;
  if (len <= 0) return;
  // 十字：横长竖短一点，越外越暗
  for (const [dx, dy, L] of [[1, 0, len], [-1, 0, len], [0, 1, len - 1], [0, -1, len - 1]])
    for (let d = 1; d <= L; d++) p.px(dx * d, dy * d, d <= 1 ? (f < 2 ? WHITE : C[4]) : d < L ? C[3] : C[2]);
  if (f < 4) p.px(0, 0, WHITE);
  if (f === 1 || f === 2) for (const [dx, dy] of [[1, 1], [-1, -1], [1, -1], [-1, 1]]) p.px(dx * 2, dy * 2, C[3]);
  if (f === 3) for (const [dx, dy] of [[1, 1], [-1, -1]]) p.px(dx * 3, dy * 3, C[2]);
  p.glow(0, 0, 5, C[3], 0.25 * Math.exp(-t / 0.06));
}
