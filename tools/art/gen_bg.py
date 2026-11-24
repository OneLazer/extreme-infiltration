"""生成窗外视差背景：天空、远/中/近三层城市剪影。

远处更接近天空雾色（低对比），近处更暗、更饱和、窗光更暖。远景里有一座总部大楼：故事终点。
输出 assets/bg/*.png。剪影层横向可无缝平铺（宽 BW），在 Godot 里用 Parallax2D 的 repeat_size。
"""
import os, sys, math
sys.path.insert(0, os.path.dirname(__file__))
from pal import N, C, P, W, V, hx
from px import Cv, BAYER4, alpha, lerp, rng

VW, VH = 320, 180
BW = 480   # 剪影层平铺宽度


def sky():
    cv = Cv(VW, VH)
    # 天空：硬色阶 + 抖动过渡（像素风渐变，不做平滑渐变）
    stops = [(0, N[1]), (55, V[0]), (100, V[1]), (140, V[2]), (180, V[3])]
    for y in range(VH):
        for i in range(len(stops) - 1):
            y0, c0 = stops[i]; y1, c1 = stops[i + 1]
            if y0 <= y < y1:
                t = (y - y0) / (y1 - y0)
                break
        for x in range(VW):
            cv.put(x, y, c1 if BAYER4[y & 3][x & 3] < int(t * 16) else c0)
    # 月亮：右上，淡粉光晕 + 一条云带
    mx, my, r = 236, 44, 15
    for y in range(my - r - 8, my + r + 9):
        for x in range(mx - r - 8, mx + r + 9):
            d = math.hypot(x - mx, y - my)
            if r < d <= r + 7 and BAYER4[y & 3][x & 3] < int((1 - (d - r) / 7) * 7):
                cv.put(x, y, V[2])
            elif d <= r:
                lit = (x - mx) * 0.6 + (y - my) * 0.8 < r * 0.45
                cv.put(x, y, hx("#e9b9cf") if lit else V[4])
    for band_y, h in ((47, 2), (53, 1)):
        for x in range(mx - r, mx + r + 1):
            for y in range(band_y, band_y + h):
                if cv.get(x, y)[0] > 180:
                    cv.put(x, y, V[3])
    g = rng(7)
    for _ in range(40):   # 稀疏星点，只在高处
        x, y = g.randrange(VW), g.randrange(70)
        if math.hypot(x - mx, y - my) > r + 4:
            cv.put(x, y, alpha(C[4], g.choice((90, 140, 220))))
    return cv
def _wput(cv, x, y, c):
    cv.put(x % BW, y, c)


def skyline(seed, top_range, wrange, body, rim, win_cols, win_p, win_step, haze=None, signs=0, hq=False):
    """一层城市剪影。win_step=(窗宽,窗高,间距x,间距y)。"""
    g = rng(seed)
    cv = Cv(BW, VH)
    x = 0
    blds = []
    while x < BW:
        w = g.randint(*wrange)
        top = g.randint(*top_range)
        blds.append((x, w, top))
        x += w + g.choice((0, 0, 1, 2, 4))
    if hq:   # 总部大楼：窄高塔 + 顶部尖塔 + 红色航标
        blds.append((300, 22, 18))
    for bx, w, top in blds:
        is_hq = hq and bx == 300
        for yy in range(top, VH):
            for xx in range(bx, bx + w):
                _wput(cv, xx, yy, body)
            _wput(cv, bx + w - 1, yy, rim)        # 月光从右侧来：右缘受光
        # 屋顶细节
        r = g.random()
        if is_hq:
            for yy in range(top - 14, top):
                _wput(cv, bx + w // 2, yy, rim)
            for yy in range(top - 6, top):
                for xx in range(bx + 6, bx + w - 6):
                    _wput(cv, xx, yy, body)
            _wput(cv, bx + w // 2, top - 15, (255, 42, 61, 255))
            for yy in range(top + 4, VH, 3):          # 竖向灯带
                _wput(cv, bx + 3, yy, alpha(C[2], 200)); _wput(cv, bx + w - 4, yy, alpha(C[2], 200))
        elif r < 0.25:
            ax = bx + g.randint(1, max(1, w - 2))
            for yy in range(top - g.randint(4, 10), top):
                _wput(cv, ax, yy, body)
            _wput(cv, ax, top - 11, alpha((255, 42, 61, 255), 180))
        elif r < 0.45 and w > 8:
            for yy in range(top - 3, top):
                for xx in range(bx + 2, bx + w - 2):
                    _wput(cv, xx, yy, body)
        # 窗户
        ww, wh, sx, sy = win_step
        lit = g.choice(win_cols)
        dens = win_p * g.uniform(0.4, 1.4)
        for yy in range(top + 3, VH - 2, wh + sy):
            for xx in range(bx + 2, bx + w - 2 - ww + 1, ww + sx):
                if g.random() < dens:
                    c = lit if g.random() > 0.15 else g.choice(win_cols)
                    for j in range(wh):
                        for i in range(ww):
                            _wput(cv, xx + i, yy + j, c)
    for _ in range(signs):
        _sign(cv, g, blds, rim)
    if haze:   # 底部城市灯光雾
        hc, h0 = haze
        for yy in range(h0, VH):
            lvl = int((yy - h0) / (VH - h0) * 12)
            for xx in range(BW):
                if BAYER4[yy & 3][xx & 3] < lvl and cv.get(xx, yy)[3]:
                    cv.put(xx, yy, hc)
    return cv
FONT_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "fonts")
SIGN_WORDS = ["拉面", "酒吧", "旅馆", "电玩", "药局", "夜市", "网咖", "当铺", "营业"]


def glyphs(text, size=8, font="fusion-pixel-8px-monospaced-zh_hans.ttf"):
    """用像素字体把文字渲染成 1-bit 掩码（list of rows）。"""
    from PIL import Image, ImageDraw, ImageFont
    f = ImageFont.truetype(os.path.join(FONT_DIR, font), size)
    l, t, r, b = f.getbbox(text)
    im = Image.new("L", (r - l + 1, b - t + 1), 0)
    d = ImageDraw.Draw(im)
    d.fontmode = "1"
    d.text((-l, -t), text, font=f, fill=255)
    return [[im.getpixel((x, y)) > 127 for x in range(im.width)] for y in range(im.height)]


def _sign(cv, g, blds, rim):
    """竖向霓虹招牌，挂在楼体侧面。"""
    bx, w, top = g.choice([b for b in blds if b[1] > 10])
    word = g.choice(SIGN_WORDS)
    col = g.choice((P[3], C[3], W[3]))
    dark = lerp(col, (0, 0, 0, 255), 0.75)
    sx = bx + (w - 10 if g.random() < 0.5 else 1)
    sy = top + g.randint(6, 20)
    hgt = len(word) * 9 + 3
    for yy in range(sy, sy + hgt):
        for xx in range(sx, sx + 10):
            edge = yy in (sy, sy + hgt - 1) or xx in (sx, sx + 9)
            _wput(cv, xx, yy, col if edge else dark)
    for i, ch in enumerate(word):
        m = glyphs(ch)
        for y, row in enumerate(m):
            for x, on in enumerate(row):
                if on:
                    _wput(cv, sx + 1 + x + (8 - len(row)) // 2, sy + 2 + i * 9 + y, col)


def build(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    layers = {
        "sky": sky(),
        # 远：雾紫色、低对比、冷色小窗；有总部大楼
        "city_far": skyline(11, (60, 105), (10, 26), V[1], V[2], [V[3], P[1], C[0]], 0.35, (1, 1, 2, 2),
                            haze=(V[2], 120), hq=True),
        # 中：靛蓝，品红/青色窗，带招牌
        "city_mid": skyline(23, (80, 125), (16, 34), N[3], N[5], [P[2], C[1], W[1]], 0.3, (2, 1, 2, 2),
                            haze=(V[1], 140), signs=3),
        # 近：最暗，暖色大窗
        "city_near": skyline(37, (105, 140), (26, 48), N[1], N[3], [W[2], W[3], W[1]], 0.22, (3, 2, 3, 3),
                             signs=2),
    }
    for k, cv in layers.items():
        cv.save(os.path.join(out_dir, k + ".png"))
    return layers


if __name__ == "__main__":
    build(os.path.join(os.path.dirname(__file__), "..", "..", "assets", "bg"))
