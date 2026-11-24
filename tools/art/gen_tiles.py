"""生成街区主题地形图集（47 格 blob 自动拼接 + 细节变体）。

输出 assets/tiles/street_tiles.png 与 street_tiles.json（每格的邻接掩码，供 Godot 工具配置 Terrain）。
掩码位：N=1 NE=2 E=4 SE=8 S=16 SW=32 W=64 NW=128（1 = 该方向是实心）。
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
from pal import N, C
from px import Cv, BAYER4

T = 8
BITS = {"N": 1, "NE": 2, "E": 4, "SE": 8, "S": 16, "SW": 32, "W": 64, "NW": 128}


def normalize(m):
    """角位只有在两条相邻边都实心时才有意义（blob 规则）。"""
    for corner, a, b in (("NE", "N", "E"), ("SE", "S", "E"), ("SW", "S", "W"), ("NW", "N", "W")):
        if not (m & BITS[a] and m & BITS[b]):
            m &= ~BITS[corner]
    return m


def blob_masks():
    return sorted({normalize(m) for m in range(256)})


def depth_side(m, x, y):
    """返回 (到最近外露边的距离, 外露方向)。没有外露边时距离记为 99。"""
    s = lambda k: m & BITS[k]
    best = (99, None)
    cands = []
    if not s("N"): cands.append((y, "top"))
    if not s("S"): cands.append((T - 1 - y, "bot"))
    if not s("W"): cands.append((x, "side"))
    if not s("E"): cands.append((T - 1 - x, "side"))
    # 内角：两边实心、对角空
    if s("N") and s("W") and not s("NW"): cands.append((max(x, y), "inner"))
    if s("N") and s("E") and not s("NE"): cands.append((max(T - 1 - x, y), "inner"))
    if s("S") and s("W") and not s("SW"): cands.append((max(x, T - 1 - y), "innerb"))
    if s("S") and s("E") and not s("SE"): cands.append((max(T - 1 - x, T - 1 - y), "innerb"))
    order = {"top": 0, "inner": 1, "side": 2, "innerb": 3, "bot": 4}
    for d, k in cands:
        if d < best[0] or (d == best[0] and order[k] < order[best[1]]):
            best = (d, k)
    return best


RIM = {
    "top": [C[3], C[2], C[0], N[3]],
    "inner": [C[2], C[0], N[3]],
    "side": [C[2], C[0], N[3]],
    "innerb": [C[0], N[3]],
    "bot": [C[1], N[3]],
}
def fill_color(d, x, y):
    """实心体要比背景墙更暗，读作前景剪影：近边 N2，向内抖动到 N1，深处 N0/N1。"""
    if d <= 3:
        return N[2]
    if d >= 7:
        return N[1] if (d < 10 or BAYER4[y & 3][x & 3] >= 4) else N[0]
    lvl = int((d - 3) / 4 * 16)
    return N[1] if BAYER4[y & 3][x & 3] < lvl else N[2]


def draw_tile(m, variant=0):
    cv = Cv(T, T)
    s = lambda k: m & BITS[k]
    for y in range(T):
        for x in range(T):
            d, k = depth_side(m, x, y)
            ramp = RIM.get(k)
            if ramp and d < len(ramp):
                c = ramp[d]
            else:
                c = fill_color(d, x, y)
            cv.put(x, y, c)
    # 顶面外角：1px 高光点
    if not s("N") and not s("W"):
        cv.put(0, 0, C[4])
    if not s("N") and not s("E"):
        cv.put(T - 1, 0, C[4])
    # 底面外角收暗，避免方块感
    if not s("S") and not s("W"):
        cv.put(0, T - 1, C[0])
    if not s("S") and not s("E"):
        cv.put(T - 1, T - 1, C[0])
    deco(cv, m, variant)
    return cv


def deco(cv, m, v):
    full = m == 255
    top_only = m == normalize(255 & ~BITS["N"])
    if full and v == 1:      # 竖向面板缝
        cv.vline(7, 0, 7, N[0])
    elif full and v == 2:    # 铆钉
        cv.put(2, 2, N[2]); cv.put(5, 5, N[2])
    elif full and v == 3:    # 通风格栅
        for y in (2, 4):
            cv.hline(1, 6, y, N[0]); cv.hline(1, 6, y + 1, N[2])
    elif top_only and v == 1:   # 顶面螺栓
        cv.put(2, 3, N[5]); cv.put(5, 3, N[5])
    elif top_only and v == 2:   # 顶面接缝
        cv.vline(0, 2, 4, N[1])
VARIANTS = {255: [(1, 0.18), (2, 0.12), (3, 0.06)]}   # 掩码: [(变体号, 概率)]


def build(out_dir):
    masks = blob_masks()
    top_only = normalize(255 & ~BITS["N"])
    VARIANTS[top_only] = [(1, 0.15), (2, 0.15)]
    cols = 8
    entries = [(m, 0, 1.0) for m in masks]
    for m, vs in VARIANTS.items():
        for v, p in vs:
            entries.append((m, v, p))
    rows = (len(entries) + cols - 1) // cols
    sheet = Cv(cols * T, rows * T)
    meta = []
    for i, (m, v, p) in enumerate(entries):
        cx, cy = i % cols, i // cols
        sheet.blit(draw_tile(m, v), cx * T, cy * T)
        meta.append({"x": cx, "y": cy, "mask": m, "prob": p})
    os.makedirs(out_dir, exist_ok=True)
    sheet.save(os.path.join(out_dir, "street_tiles.png"))
    with open(os.path.join(out_dir, "street_tiles.json"), "w") as f:
        json.dump({"tile": T, "tiles": meta}, f, indent=0)
    return sheet, meta


def autotile(grid):
    """grid[y][x] 为 True 表示实心。返回 {(x,y): mask}，越界视为实心。"""
    h, w = len(grid), len(grid[0])
    sol = lambda x, y: True if not (0 <= x < w and 0 <= y < h) else grid[y][x]
    out = {}
    for y in range(h):
        for x in range(w):
            if not grid[y][x]:
                continue
            m = 0
            for k, (dx, dy) in {"N": (0, -1), "NE": (1, -1), "E": (1, 0), "SE": (1, 1), "S": (0, 1),
                                "SW": (-1, 1), "W": (-1, 0), "NW": (-1, -1)}.items():
                if sol(x + dx, y + dy):
                    m |= BITS[k]
            out[(x, y)] = normalize(m)
    return out


if __name__ == "__main__":
    root = os.path.join(os.path.dirname(__file__), "..", "..")
    _, meta = build(os.path.join(root, "assets", "tiles"))
    print("tiles:", len(meta), "blob:", len(blob_masks()))
