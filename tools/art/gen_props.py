"""生成室内装饰物件（不参与碰撞）。

每个物件一张小图，打包进 assets/props/props.png，props.json 记录矩形和锚点（底边中心）。
发光部分（屏幕、灯管、招牌）另存一张 props_emit.png：同位置只保留发光像素，Godot 里叠一层加亮让它进辉光。
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
from pal import N, C, P, W, V, EXIT_GREEN, hx
from px import Cv, alpha, lerp, rng
from gen_bg import glyphs

PROPS = {}   # name -> (Cv 颜色, Cv 发光)


def prop(name, w, h):
    def deco(fn):
        col, emi = Cv(w, h), Cv(w, h)
        fn(col, emi)
        PROPS[name] = (col, emi)
        return fn
    return deco


def both(col, emi, x, y, c):
    col.put(x, y, c); emi.put(x, y, c)


@prop("lamp", 16, 3)
def _lamp(c, e):
    c.hline(1, 14, 0, N[4]); c.put(0, 0, N[3]); c.put(15, 0, N[3])
    c.hline(1, 14, 1, N[5])
    for x in range(2, 14):
        both(c, e, x, 2, C[4] if 3 < x < 12 else C[3])


@prop("desk", 26, 15)
def _desk(c, e):
    # 显示器
    c.rect(8, 0, 12, 8, N[1])
    for y in range(1, 7):
        for x in range(9, 19):
            k = P[3] if y < 3 else (P[2] if y < 5 else V[3])
            if y == 4 and 11 < x < 16: k = W[3]          # 屏幕上的山形图案
            if y == 3 and 12 < x < 15: k = W[3]
            if y % 2 == 0: k = lerp(k, N[1], 0.25)       # 扫描线
            both(c, e, x, y, k)
    c.rect(13, 8, 2, 1, N[3])
    c.hline(4, 9, 8, N[3])                                # 键盘
    # 桌面
    c.hline(0, 25, 9, C[1]); c.hline(0, 25, 10, N[5])
    c.rect(1, 11, 24, 1, N[3])
    c.rect(1, 12, 2, 3, N[3]); c.rect(23, 12, 2, 3, N[3])
    c.rect(16, 11, 7, 4, N[4]); c.hline(17, 21, 12, N[5])  # 抽屉柜
@prop("vending", 14, 24)
def _vending(c, e):
    c.rect(0, 0, 14, 24, N[4]); c.vline(13, 0, 23, N[5]); c.vline(0, 0, 23, N[3])
    for x in range(1, 13):                                   # 顶部灯箱
        both(c, e, x, 1, P[3]); both(c, e, x, 2, P[2])
    c.rect(1, 4, 9, 14, C[0])                                # 玻璃橱窗
    items = [P[3], W[3], C[3], W[2], P[4], C[2]]
    for row, y in enumerate((5, 9, 13)):
        c.hline(1, 9, y + 3, N[3])
        for i, x in enumerate(range(2, 9, 2)):
            both(c, e, x, y + 1, items[(row * 2 + i) % len(items)])
            c.put(x, y + 2, lerp(items[(row * 2 + i) % len(items)], N[1], 0.4))
    for y in range(4, 18):                                   # 玻璃反光
        both(c, e, 1 + (y - 4) // 3, y, alpha(C[3], 60))
    c.rect(10, 5, 3, 6, N[2]); both(c, e, 11, 6, EXIT_GREEN); c.put(11, 8, N[5])
    c.rect(2, 19, 9, 3, N[1]); c.hline(3, 9, 20, N[2])        # 出货口
    c.hline(0, 13, 23, N[2])


@prop("server", 12, 26)
def _server(c, e):
    g = rng(3)
    c.rect(0, 0, 12, 26, N[1]); c.vline(11, 0, 25, N[3]); c.hline(0, 11, 0, N[4])
    for y in range(2, 24, 3):
        c.hline(1, 10, y, N[2]); c.hline(1, 10, y + 1, N[3])
        for x in (2, 4):
            if g.random() < 0.7:
                both(c, e, x, y + 1, g.choice((C[3], EXIT_GREEN, C[3], P[3])))
        c.hline(6, 9, y + 1, N[1])


@prop("plant", 10, 15)
def _plant(c, e):
    leaves = [(4, 0), (3, 1), (5, 1), (2, 2), (6, 2), (4, 2), (1, 3), (7, 3), (3, 3), (5, 4), (0, 4), (8, 4),
              (4, 4), (2, 5), (6, 5), (1, 6), (7, 6), (3, 6), (5, 6), (4, 7), (2, 7), (6, 7), (4, 5), (3, 8), (5, 8)]
    for x, y in leaves:
        c.put(x, y, C[1] if (x + y) % 3 else C[2])
        c.put(x, y + 1, C[0]) if c.get(x, y + 1)[3] == 0 else None
    c.vline(4, 8, 9, N[5])
    c.rect(2, 10, 6, 5, N[4]); c.hline(1, 8, 10, N[5]); c.vline(7, 11, 14, N[3])


@prop("trash", 7, 9)
def _trash(c, e):
    c.hline(0, 6, 0, C[2]); c.hline(0, 6, 1, C[1])
    c.rect(1, 2, 5, 7, C[0]); c.vline(5, 2, 8, N[4])
    for x in (2, 4):
        c.vline(x, 3, 7, C[1])
@prop("cooler", 8, 17)
def _cooler(c, e):
    c.rect(2, 0, 4, 1, C[1]); c.rect(1, 1, 6, 5, alpha(C[1], 170)); c.vline(2, 2, 4, C[3])
    c.rect(0, 6, 8, 11, N[5]); c.vline(7, 6, 16, N[4]); c.hline(0, 7, 6, N[6])
    both(c, e, 2, 9, P[3]); both(c, e, 5, 9, C[3])
    c.rect(2, 12, 4, 2, N[2])


@prop("chair", 8, 10)
def _chair(c, e):
    c.rect(1, 0, 2, 6, N[4]); c.vline(1, 0, 5, N[5])
    c.hline(1, 7, 5, N[5]); c.hline(1, 7, 6, N[3])
    c.vline(4, 7, 8, N[3]); c.hline(2, 6, 9, N[3])


def text_into(c, e, txt, x0, y0, col, emit=True):
    for y, row in enumerate(glyphs(txt)):
        for x, on in enumerate(row):
            if on:
                (both(c, e, x0 + x, y0 + y, col) if emit else c.put(x0 + x, y0 + y, col))


@prop("sign_exit", 40, 11)
def _sign_exit(c, e):
    c.rect(0, 0, 40, 11, hx("#0c2a1c")); c.hline(0, 39, 0, hx("#1d5a3a")); c.hline(0, 39, 10, hx("#06140d"))
    # 奔跑小人（通用图标）
    for x, y in ((3, 2), (4, 3), (3, 4), (4, 4), (5, 4), (3, 5), (2, 6), (4, 6), (5, 7), (1, 7)):
        both(c, e, x, y, EXIT_GREEN)
    text_into(c, e, "安全出口", 7, 2, EXIT_GREEN)


@prop("logo", 46, 12)
def _logo(c, e):
    """公司标识：菱形徽标 + 天枢集团。挂在背景墙上，青色霓虹。"""
    for i in range(5):
        for (x, y) in ((5 - i, 1 + i), (5 + i, 1 + i), (5 - i, 9 - i), (5 + i, 9 - i)):
            both(c, e, x, y, C[3])
    both(c, e, 5, 5, C[4])
    text_into(c, e, "天枢集团", 13, 2, C[3])


@prop("neon_ye", 12, 30)
def _neon_ye(c, e):
    """竖招牌：夜 · 未 · 眠，品红霓虹管。"""
    c.rect(0, 0, 12, 30, N[1])
    for x in range(12):
        both(c, e, x, 0, P[2]); both(c, e, x, 29, P[2])
    for y in range(30):
        both(c, e, 0, y, P[2]); both(c, e, 11, y, P[2])
    for i, ch in enumerate("夜未眠"):
        text_into(c, e, ch, 2, 2 + i * 9, P[3])
def _elevator(c, e, open_):
    light = EXIT_GREEN if open_ else hx("#ff2a3d")
    c.rect(0, 3, 20, 25, N[3]); c.vline(0, 3, 27, C[0]); c.vline(19, 3, 27, C[1]); c.hline(0, 19, 3, C[1])
    c.rect(4, 0, 12, 3, N[1])
    for x in (7, 8, 11, 12):
        both(c, e, x, 1, light)                               # 楼层指示灯
    if open_:
        c.rect(2, 5, 16, 23, alpha(W[3], 255))
        for y in range(5, 28):
            for x in range(2, 18):
                both(c, e, x, y, lerp(W[4], W[2], (y - 5) / 23))
        c.rect(2, 5, 3, 23, N[5]); c.rect(15, 5, 3, 23, N[5])  # 半开的门
    else:
        c.rect(2, 5, 16, 23, N[5]); c.vline(9, 5, 27, N[2]); c.vline(10, 5, 27, N[6])
        c.vline(3, 6, 26, N[6]); c.vline(16, 6, 26, N[4])
    c.hline(0, 19, 27, N[2])


prop("elevator", 20, 28)(lambda c, e: _elevator(c, e, False))
prop("elevator_open", 20, 28)(lambda c, e: _elevator(c, e, True))

WPN_ICONS = {   # 8×8 武器图标；颜色键：a 主色 b 亮 d 暗
    "dart": ["........", ".....bb.", "....bab.", "...aab..", "..aad...", ".dad....", ".dd.....", "........"],
    "boomerang": ["........", ".bbb....", ".baa....", ".a.a....", ".a..a...", "..d..aa.", "...dddb.", "........"],
    "heavy": ["bbbb....", "baaab...", "ba.daa..", "ba..dda.", ".ad..dab", "..ad.dab", "...aaaab", "....bbb."],
    "airgun": ["........", "..bbbbbb", ".baaaaab", "baaddddd", "ddda....", "..da....", "..dd....", "........"],
    "rapier": [".......b", "......ba", ".....ba.", "....ba..", ".d.ba...", "..dd....", ".dad....", "d..d...."],
}
GUNS = {        # 手持武器，9×5，握把在 (1,3)
    "dart": [".........", "....bbbb.", ".ddaaaaab", ".dda.....", ".dd......"],
    "airgun": ["...bbbbb.", ".daaaaaab", "ddaddddda", ".dda.....", ".dd......"],
}
## 刺剑手持图：护手竖在 x=2，刀身沿握把那一行（y=3）伸出，c = 刀身（发光）
RAPIER_HELD = [".........", "..b......", "..a......", "ddacccccc", "..a......"]


def _rapier_held():
    from pal import WPN
    from px import sprite
    blade = WPN["rapier"]
    keys = {"a": N[6], "b": lerp(N[6], (255, 255, 255, 255), 0.35), "d": N[3], "c": blade}
    s = sprite(RAPIER_HELD, keys)
    emi = Cv(s.w, s.h)
    for x in range(s.w):
        if RAPIER_HELD[3][x] == "c":
            emi.put(x, 3, blade)
    PROPS["gun_rapier"] = (s, emi)


def _wpn_sprites():
    _rapier_held()
    from pal import WPN
    from px import sprite
    for name, rows in WPN_ICONS.items():
        base = WPN[name]
        keys = {"a": base, "b": lerp(base, (255, 255, 255, 255), 0.55), "d": lerp(base, N[1], 0.5)}
        s = sprite(rows, keys)
        PROPS["icon_" + name] = (s, s)
    for name, rows in GUNS.items():
        accent = WPN[name]
        keys = {"a": N[6], "b": lerp(N[6], (255, 255, 255, 255), 0.35), "d": N[3]}
        s = sprite(rows, keys)
        emi = Cv(s.w, s.h)
        for x in range(s.w):                # 枪身上一条武器色指示灯
            if s.get(x, 1)[3]:
                s.put(x, 1, accent); emi.put(x, 1, accent)
        PROPS["gun_" + name] = (s, emi)


def build(out_dir):
    _wpn_sprites()
    pad = 1
    items = sorted(PROPS.items(), key=lambda kv: -kv[1][0].h)
    W_ = 128
    x = y = row_h = 0
    rects = {}
    for name, (col, _) in items:      # 简单的行式装箱
        if x + col.w > W_:
            x, y, row_h = 0, y + row_h + pad, 0
        rects[name] = (x, y, col.w, col.h)
        x += col.w + pad
        row_h = max(row_h, col.h)
    H_ = y + row_h
    sheet, emit = Cv(W_, H_), Cv(W_, H_)
    for name, (col, emi) in PROPS.items():
        rx, ry, _, _ = rects[name]
        sheet.blit(col, rx, ry); emit.blit(emi, rx, ry)
    os.makedirs(out_dir, exist_ok=True)
    sheet.save(os.path.join(out_dir, "props.png"))
    emit.save(os.path.join(out_dir, "props_emit.png"))
    with open(os.path.join(out_dir, "props.json"), "w") as f:
        json.dump({k: list(v) for k, v in rects.items()}, f, indent=0)
    with open(os.path.join(out_dir, "props_rects.gd"), "w", encoding="utf-8") as f:
        f.write("## 由 tools/art/gen_props.py 生成，勿手改。物件名 → 图集矩形。\nextends RefCounted\n\nconst RECTS := {\n")
        for k in sorted(rects):
            f.write('\t"%s": Rect2(%d, %d, %d, %d),\n' % ((k,) + tuple(rects[k])))
        f.write("}\n")
    return sheet, emit, rects


if __name__ == "__main__":
    build(os.path.join(os.path.dirname(__file__), "..", "..", "assets", "props"))
