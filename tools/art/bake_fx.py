"""把 tools/art/pixelfx_fx/ 里的自制特效用 pixelfx 烘焙成精灵表，按武器色出多个配色。

用法：python3 bake_fx.py <pixelfx 仓库路径>
   （仓库：git clone https://github.com/patch-gg/pixelfx ，需要 Node 18+）
输出 assets/fx/<名字>.png（帧横排）和 assets/fx/fx_sheets_meta.gd（帧尺寸、帧数、fps、锚点）。
"""
import json, os, shutil, subprocess, sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "assets", "fx")

PAL = {
    "dart": ["#123a4a", "#1f7a99", "#3fc4e0", "#8ff2ff", "#d9fbff", "#ffffff"],
    "airgun": ["#4a1712", "#c9281f", "#f2561d", "#ff8a2a", "#ffe26b", "#ffffff"],
    "heavy": ["#2a1450", "#5a2fa8", "#8a5cff", "#b8a0ff", "#e6dcff", "#ffffff"],
    "boomerang": ["#10331c", "#1f7a3d", "#3fd06a", "#8cf2a6", "#d9ffe3", "#ffffff"],
    "gold": ["#4a2a10", "#a8582a", "#f2a23d", "#ffd27a", "#fff1c2", "#ffffff"],
    "magenta": ["#3a1446", "#6e1f6a", "#b8327f", "#ff4f9a", "#ffa3cf", "#ffffff"],
    "rapier": ["#1a1f3a", "#3d4a7a", "#7f8fc8", "#b9c6f0", "#e6ecff", "#ffffff"],
    "electric": ["#1a0410", "#3a0716", "#7a1030", "#c81e4a", "#ff2a5a", "#ff8aa8", "#ffd6e0", "#ffffff"],
}
JOBS = [  # (效果, 配色, 输出名)
    *[("tiny-flare", k, "flare_" + k) for k in ("dart", "airgun", "heavy", "boomerang", "gold")],
    ("tiny-muzzle", "dart", "muzzle_dart"), ("tiny-muzzle", "airgun", "muzzle_airgun"),
    ("kill-burst", "gold", "kill_gold"), ("kill-burst", "magenta", "kill_magenta"),
    ("kill-burst", "dart", "kill_dart"),
    ("tiny-flare", "rapier", "flare_rapier"), ("tiny-pierce", "rapier", "pierce_rapier"),
    ("tiny-flare", "electric", "flare_electric"), ("tiny-zap", "electric", "zap_electric"),
    ("ui-spark", "magenta", "ui_spark"), ("ui-burst", "magenta", "ui_burst"),   # 菜单：选中火花、确认爆闪
]


def main(repo):
    dst = os.path.join(repo, "src", "fx", "custom")
    os.makedirs(dst, exist_ok=True)
    for f in os.listdir(os.path.join(HERE, "pixelfx_fx")):
        shutil.copy(os.path.join(HERE, "pixelfx_fx", f), dst)
    os.makedirs(OUT, exist_ok=True)
    metas = {}
    for fx, pal, name in JOBS:
        subprocess.run(["node", "tools/render.mjs", "custom/" + fx, "--sheet", "--opts",
                        json.dumps({"palette": PAL[pal]})], cwd=repo, check=True, stdout=subprocess.DEVNULL)
        rec = os.path.join(repo, "records", "custom", fx)
        meta = json.load(open(os.path.join(rec, fx + ".json")))["meta"]["pixelfx"]
        sheet = Image.open(os.path.join(rec, fx + ".png")).convert("RGBA")
        w, h = meta["frameSize"]
        n, cols = meta["frames"], meta["columns"]
        strip = Image.new("RGBA", (w * n, h))
        for i in range(n):
            x, y = (i % cols) * w, (i // cols) * h
            strip.paste(sheet.crop((x, y, x + w, y + h)), (i * w, 0))
        strip.save(os.path.join(OUT, name + ".png"))
        metas[name] = (w, h, n, meta["fps"], meta["pivot"])
    with open(os.path.join(OUT, "fx_sheets_meta.gd"), "w", encoding="utf-8") as f:
        f.write("## 由 tools/art/bake_fx.py 生成，勿手改。\nextends RefCounted\n\nconst SHEETS := {\n")
        for k, (w, h, n, fps, pv) in sorted(metas.items()):
            f.write('\t"%s": {"w": %d, "h": %d, "frames": %d, "fps": %d, "pivot": Vector2(%d, %d)},\n'
                    % (k, w, h, n, fps, pv[0], pv[1]))
        f.write("}\n")
    print("baked", len(metas))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/pixelfx")
